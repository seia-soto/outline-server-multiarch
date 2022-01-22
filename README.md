# outline-server-multiarch

> The project is not completed!

The multi-arch distribution of [Jigsaw's Outline-Server](https://github.com/Jigsaw-Code/outline-server) project.

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
