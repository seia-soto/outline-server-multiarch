# outline-server-multiarch

The multi-arch distribution of [Jigsaw's Outline-Server](https://github.com/Jigsaw-Code/outline-server) project for AArch servers.

| Version | Update Interval                              | Target          | Supported OS/Arch                                    |
|---------|----------------------------------------------|-----------------|------------------------------------------------------|
| master  | daily                                        | upstream/master | linux/amd64, linux/arm64, linux/arm/v7, linux/arm/v6 |
| latest  | checked daily, released as upstream releases | Latest release  | linux/amd64, linux/arm64, linux/arm/v7, linux/arm/v6 |

## Usage

To install outline-server on your server using this docker image, paste following code before install:

```bash
# master release, updated daily
export SB_IMAGE="ghcr.io/seia-soto/shadowbox:master"

# latest release, updated irregularly
export SB_IMAGE="ghcr.io/seia-soto/shadowbox:latest"

# run install script
curl -sL "https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh" | bash
```

### Local build

To build local image, you can use following command with prepared environment:

- For **single-arch** build, you just need to install:
  - `jq`
  - `git`
  - `curl`
  - `tar`
  - `npm` from Node.JS (use v12 for `latest` build, otherwise use v16)
  - Docker with Buildx and BuildKit support
- For **multi-arch** build, you also need to install:
  - QEMU emulator for cross-platform build

```bash
# clone this repo
git clone https://github.com/seia-soto/outline-server-multiarch.git

# go to repo
cd outline-server-multiarch

: '
# by HoJeong Go

Usage:

    ./build.sh $arch $tag $checkpoint

    $arch {string} The arch to build, using docker platform style
    $tag {string} The docker tag to use while building the image
    $checkpoint {string} The git branch or tag to build, using `latest` will automatically use latest release tag

About:

    This script builds Outline-Server docker image
    with specific arch by downloading compatible third_party
    automatically.
'

# set local image name to use
export SB_IMAGE="shadowbox-local"

PLATFORM="linux/amd64" # use one of linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6, or all
CHECKPOINT="latest" # or `master`

# build latest
bash ./build.sh "${PLATFORM}" "${SB_IMAGE}" "${CHECKPOINT}"

# run install script
curl -sL "https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh" | bash
```

# LICENSE

This repository contains, modified and uses the hard work by Outline-Server Authors.
The following files are originally from Outline-Server Authors and modified for personal use.

- `extra/scripts/build.action.sh`

Also, the build script which named `/build.sh` will clone the Outline-Server repository and modify for personal use.

Other files which created by HoJeong Go (a.k.a Seia-Soto) has been licensed with [MIT License](./LICENSE).

```
MIT License Copyright 2022 HoJeong Go

Permission is hereby granted, free of
charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to the
following conditions:

The above copyright notice and this permission notice
(including the next paragraph) shall be included in all copies or substantial
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```
