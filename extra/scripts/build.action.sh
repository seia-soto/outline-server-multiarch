#!/bin/bash -eu
#
# Copyright 2018 The Outline Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This file is originally created by Outline Authors
cat << EOF

#####################################
  The build script has been patched
#####################################

EOF

export DOCKER_CONTENT_TRUST=0 # Disable content trust
export DOCKER_BUILDKIT=1 # Enable buildkit

export NODE_IMAGE="${NODE_IMAGE:-node:12-alpine}"

docker pull "${NODE_IMAGE}"
docker buildx build \
    --push \
    --platform="${DOCKER_PLATFORMS}" \
    --force-rm \
    --build-arg NODE_IMAGE="${NODE_IMAGE}" \
    --build-arg GITHUB_RELEASE="${TRAVIS_TAG:-none}" \
    -f src/shadowbox/docker/Dockerfile \
    -t "${SB_IMAGE:-outline/shadowbox}" \
    "${ROOT_DIR}"
