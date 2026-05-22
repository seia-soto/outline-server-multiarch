#!/usr/bin/env bash
set -euo pipefail

: '
# by HoJeong Go
# updated by Jen Sean Foo

Usage:

    ./build.sh $platforms $tag $checkpoint

Arguments:

    $platforms   Comma-separated Docker platforms. Supported: linux/amd64,linux/arm64
    $tag         Docker image tag to build, for example ghcr.io/example/shadowbox:latest
    $checkpoint  Upstream Outline Server branch or tag. Use "latest" for the latest release.

Environment:

    AB_LEAVE_BASE_DIRECTORY  If non-empty, keep the upstream checkout in ./workspace/outline-server.
    BUILD_OUTPUT             "push" (default) or "load". "load" supports one platform only.
    UPSTREAM_REPOSITORY      Upstream repository, default Jigsaw-Code/outline-server.

About:

    This script builds the upstream Outline Server Shadowbox image for supported
    platforms with Docker Buildx. The upstream source is patched only enough to
    expose Docker Buildx flags from its Taskfile build.
'

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UPSTREAM_REPOSITORY="${UPSTREAM_REPOSITORY:-Jigsaw-Code/outline-server}"
readonly BUILD_OUTPUT="${BUILD_OUTPUT:-push}"

PLATFORMS=""
IMAGE_TAG=""
CHECKPOINT=""
PATCH_SET="release"
REQUESTED_PLATFORMS=()

TMP_DIR=""
CHECKOUT_DIR=""

cleanup() {
  if [[ -n "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}

log() {
  printf '==> %s\n' "$*"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

check_tooling() {
  local node_major

  require_command curl
  require_command docker
  require_command git
  require_command go
  require_command jq
  require_command node
  require_command npm

  node_major="$(node -p 'process.versions.node.split(".")[0]')"
  if [[ "${node_major}" != "24" ]]; then
    echo "Node.js 24.x is required by this build." >&2
    echo "Current Node.js version: $(node --version)" >&2
    exit 1
  fi
}

latest_release_tag() {
  local -a curl_args
  curl_args=(-fsSL)

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi

  curl "${curl_args[@]}" "https://api.github.com/repos/${UPSTREAM_REPOSITORY}/releases/latest" | jq -r '.tag_name'
}

platform_to_target_arch() {
  case "$1" in
    linux/amd64) echo "x86_64" ;;
    linux/arm64)
      if [[ "${PATCH_SET}" == "master" ]]; then
        echo "aarch64"
      else
        echo "arm64"
      fi
      ;;
    *)
      echo "Unsupported platform: $1" >&2
      echo "Supported platforms: linux/amd64, linux/arm64" >&2
      return 1
      ;;
  esac
}

platform_suffix() {
  case "$1" in
    linux/amd64) echo "amd64" ;;
    linux/arm64) echo "arm64" ;;
    *) return 1 ;;
  esac
}

reject_digest_image_ref() {
  local image="$1"

  if [[ "${image}" == *@* ]]; then
    echo "Digest-qualified image refs cannot be used as build output tags: ${image}" >&2
    return 1
  fi
}

append_tag_suffix() {
  local image="$1"
  local suffix="$2"
  local basename="${image##*/}"

  reject_digest_image_ref "${image}" || return 1

  if [[ "${basename}" == *":"* ]]; then
    echo "${image}-${suffix}"
  else
    echo "${image}:${suffix}"
  fi
}

normalize_image_ref() {
  local image="$1"
  local basename
  local digest=""
  local name
  local repository
  local tag=""

  name="${image}"
  if [[ "${name}" == *@* ]]; then
    digest="@${name#*@}"
    name="${name%@*}"
  fi

  basename="${name##*/}"
  repository="${name}"
  if [[ "${basename}" == *":"* ]]; then
    tag=":${basename##*:}"
    repository="${name%${tag}}"
  fi

  printf '%s%s%s\n' "$(printf '%s' "${repository}" | tr '[:upper:]' '[:lower:]')" "${tag}" "${digest}"
}

trim_whitespace() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "${value}"
}

split_platforms() {
  local raw="$1"
  local old_ifs="${IFS}"
  local -a raw_platforms=()
  local platform

  REQUESTED_PLATFORMS=()
  if [[ "${raw}" =~ (^|,)[[:space:]]*(,|$) ]]; then
    echo "Empty platform entry in platform list: ${raw}" >&2
    return 1
  fi

  IFS=,
  read -r -a raw_platforms <<<"${raw}"
  IFS="${old_ifs}"

  for platform in "${raw_platforms[@]}"; do
    platform="$(trim_whitespace "${platform}")"
    REQUESTED_PLATFORMS+=("${platform}")
  done
}

checkout_target_for_checkpoint() {
  local checkpoint="$1"

  if git -C "${CHECKOUT_DIR}" show-ref --verify --quiet "refs/remotes/origin/${checkpoint}"; then
    printf 'origin/%s\n' "${checkpoint}"
  else
    printf '%s\n' "${checkpoint}"
  fi
}

prepare_checkout() {
  local checkout_target

  if [[ -n "${AB_LEAVE_BASE_DIRECTORY:-}" ]]; then
    CHECKOUT_DIR="${ROOT_DIR}/workspace/outline-server"
    mkdir -p "${ROOT_DIR}/workspace"
  fi

  if [[ ! -d "${CHECKOUT_DIR}/.git" ]]; then
    log "Cloning ${UPSTREAM_REPOSITORY}"
    git clone "https://github.com/${UPSTREAM_REPOSITORY}.git" "${CHECKOUT_DIR}"
  else
    if [[ -n "$(git -C "${CHECKOUT_DIR}" status --porcelain)" ]]; then
      echo "Upstream checkout has local changes: ${CHECKOUT_DIR}" >&2
      echo "Clean it or unset AB_LEAVE_BASE_DIRECTORY to use a temporary checkout." >&2
      exit 1
    fi
    log "Fetching ${UPSTREAM_REPOSITORY}"
    git -C "${CHECKOUT_DIR}" fetch --tags --prune origin
  fi

  if [[ "${CHECKPOINT}" == "latest" ]]; then
    CHECKPOINT="$(latest_release_tag)"
  fi
  if [[ "${CHECKPOINT}" == "master" ]]; then
    PATCH_SET="master"
  fi

  checkout_target="$(checkout_target_for_checkpoint "${CHECKPOINT}")"
  log "Checking out ${checkout_target}"
  git -C "${CHECKOUT_DIR}" checkout --detach "${checkout_target}"
}

apply_patches() {
  local patch
  local patch_dir="${ROOT_DIR}/patches/${PATCH_SET}"
  local nullglob_was_set=0
  local -a patches=()

  if [[ ! -d "${patch_dir}" ]]; then
    echo "Patch directory not found: ${patch_dir}" >&2
    exit 1
  fi

  if shopt -q nullglob; then
    nullglob_was_set=1
  else
    shopt -s nullglob
  fi
  patches=("${patch_dir}"/*.patch)
  if [[ "${nullglob_was_set}" -eq 0 ]]; then
    shopt -u nullglob
  fi

  if [[ "${#patches[@]}" -eq 0 ]]; then
    echo "No patch files found in ${patch_dir}" >&2
    exit 1
  fi

  for patch in "${patches[@]}"; do
    log "Applying ${patch##*/}"
    git -C "${CHECKOUT_DIR}" apply "${patch}"
  done
}

install_dependencies() {
  log "Installing upstream dependencies"
  (
    cd "${CHECKOUT_DIR}"
    npm ci
  )
}

build_version() {
  if [[ "${CHECKPOINT}" == "master" ]]; then
    printf 'master-%s' "$(git -C "${CHECKOUT_DIR}" rev-parse --short HEAD)"
  else
    printf '%s' "${CHECKPOINT}"
  fi
}

build_one_platform() {
  local platform="$1"
  local image="$2"
  local version="$3"
  local build_args
  local target_arch
  local build_output_arg

  target_arch="$(platform_to_target_arch "${platform}")"
  case "${BUILD_OUTPUT}" in
    push) build_output_arg="--push" ;;
    load) build_output_arg="--load" ;;
    *)
      echo "Unsupported BUILD_OUTPUT: ${BUILD_OUTPUT}" >&2
      echo "Supported values: push, load" >&2
      exit 1
      ;;
  esac
  if grep -q "DOCKER_PLATFORM" "${CHECKOUT_DIR}/src/shadowbox/Taskfile.yml"; then
    build_args="${build_output_arg}"
  else
    build_args="--platform=${platform} ${build_output_arg}"
  fi

  log "Building ${image} for ${platform}"
  (
    cd "${CHECKOUT_DIR}"
    ./task shadowbox:docker:build \
      IMAGE_NAME="${image}" \
      IMAGE_VERSION="${version}" \
      TARGET_ARCH="${target_arch}" \
      DOCKER_BUILD_COMMAND="buildx build" \
      DOCKER_BUILD_ARGS="${build_args}" \
      DOCKER_CONTENT_TRUST=0
  )
}

create_manifest() {
  local image="$1"
  shift

  log "Creating manifest ${image}"
  docker buildx imagetools create -t "${image}" "$@"
}

main() {
  if [[ "$#" -ne 3 ]]; then
    echo "usage: ./build.sh <platforms> <tag> <checkpoint>" >&2
    exit 1
  fi

  PLATFORMS="$1"
  IMAGE_TAG="$2"
  CHECKPOINT="$3"
  PATCH_SET="release"
  TMP_DIR="$(mktemp -d)"
  CHECKOUT_DIR="${TMP_DIR}/outline-server"
  trap cleanup EXIT

  local version
  local platform
  local suffix
  local arch_image
  local arch_images=()
  local normalized_image_tag

  split_platforms "${PLATFORMS}"
  if [[ "${#REQUESTED_PLATFORMS[@]}" -eq 0 ]]; then
    echo "At least one platform is required." >&2
    exit 1
  fi
  if [[ "${BUILD_OUTPUT}" == "load" && "${#REQUESTED_PLATFORMS[@]}" -ne 1 ]]; then
    echo "BUILD_OUTPUT=load supports exactly one platform." >&2
    exit 1
  fi
  case "${BUILD_OUTPUT}" in
    push | load) ;;
    *)
      echo "Unsupported BUILD_OUTPUT: ${BUILD_OUTPUT}" >&2
      echo "Supported values: push, load" >&2
      exit 1
      ;;
  esac
  for platform in "${REQUESTED_PLATFORMS[@]}"; do
    platform_to_target_arch "${platform}" >/dev/null
  done
  reject_digest_image_ref "${IMAGE_TAG}" || exit 1

  check_tooling
  normalized_image_tag="$(normalize_image_ref "${IMAGE_TAG}")"
  if [[ "${normalized_image_tag}" != "${IMAGE_TAG}" ]]; then
    log "Normalizing image repository to lowercase: ${normalized_image_tag}"
    IMAGE_TAG="${normalized_image_tag}"
  fi
  prepare_checkout
  apply_patches
  install_dependencies
  version="$(build_version)"

  if [[ "${BUILD_OUTPUT}" == "load" ]]; then
    build_one_platform "${REQUESTED_PLATFORMS[0]}" "${IMAGE_TAG}" "${version}"
    return
  fi

  for platform in "${REQUESTED_PLATFORMS[@]}"; do
    suffix="$(platform_suffix "${platform}")"
    arch_image="$(append_tag_suffix "${IMAGE_TAG}" "${suffix}")"
    build_one_platform "${platform}" "${arch_image}" "${version}"
    arch_images+=("${arch_image}")
  done

  create_manifest "${IMAGE_TAG}" "${arch_images[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
