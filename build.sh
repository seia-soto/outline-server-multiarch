#!/bin/bash
set -x

: '
# by HoJeong Go

Usage:

    ./build.sh $arch $tag $checkpoint

    $arch {string} The arch to build, like arm64
    $tag {string} The docker tag to use while building the image
    $checkpoint {string} The git branch or tag to build

About:

    This script builds Outline-Server docker image
    with specific arch by downloading compatible third_party
    automatically.
'

readonly REPO_BASE="Jigsaw-Code/outline-server"
readonly NS_BASE="outline-server"

readonly REPO_SSS="Jigsaw-Code/outline-ss-server"
readonly NS_SSS="outline-ss-server"

readonly REPO_PROM="prometheus/prometheus"
readonly NS_PROM="prometheus"

TMP=$(mktemp -d)
ARCH=${1}
TAG=${2}
CHECKPOINT=${3}

gh_releases() {
    local REPO=${1}

    echo $(
        curl -sL "https://api.github.com/repos/${REPO}/releases" | \
        jq -r '[.[] | select(.prerelease == false)][0]'
    )
}

gh_release_asset_url_by_arch() {
    local REPO=${1} ARCH=${2}

    echo $(
        gh_releases "${REPO}" | \
        jq -r "[.assets[] | select(.name | contains(\"${ARCH}\"))][0].browser_download_url"
    )
}

unpack_archive_from_url() {
    local NAME=${1} URL=${2} STRIP_LEVEL=${3}

    mkdir -p "${TMP}/${NAME}"

    curl -sL "${URL}" -o "${TMP}/${NAME}.archive"
    tar -xf "${TMP}/${NAME}.archive" -C "${TMP}/${NAME}" --strip-components=${STRIP_LEVEL}
}

# Clone outline-server
git clone "https://github.com/${REPO_BASE}.git" "${NS_BASE}"

# Download outline-ss-server
unpack_archive_from_url "${NS_SSS}" "$(gh_release_asset_url_by_arch "${REPO_SSS}" "linux_${ARCH}")" "0"
cp -f "${TMP}/${NS_SSS}/outline-ss-server" "${NS_BASE}/third_party/outline-ss-server/linux/outline-ss-server"

# Download prometheus
unpack_archive_from_url "${NS_PROM}" "$(gh_release_asset_url_by_arch "${REPO_PROM}" "linux-${ARCH}")" "1"
cp -f "${TMP}/${NS_PROM}/prometheus" "${NS_BASE}/third_party/prometheus/linux/prometheus"

# Go to repo and checkout to latest release
cd "${NS_BASE}"

[[ -z "${CHECKPOINT}" ]] && CHECKPOINT="tags/$(gh_releases "${REPO_BASE}" | jq -r '.tag_name')";

git checkout "${CHECKPOINT}"

# Build docker-image
export SB_IMAGE="${TAG}"

if [[ "${CHECKPOINT}" == "master" ]]; then
    nvm install 16
    nvm use 16

    npm install

    npm run action shadowbox/server/build
    npm run action shadowbox/docker/build
else
    nvm install 12
    nvm use 12

    yarn

    yarn do shadowbox/server/build
    yarn do shadowbox/docker/build
fi

# Clean-up
cd ..

rm -rf "${TMP}"
rm -rf "${NS_BASE}"
