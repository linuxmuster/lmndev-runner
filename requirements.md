# lmndev runner

## Build environment for linuxmuster.net Debian packages

- Docker images based on Ubuntu shall be created – by default for Ubuntu 24.04 and 26.04 in
  parallel.
- The supported Ubuntu versions shall be configurable. The primary image (currently 26.04)
  additionally receives the `:latest` tag; each version is tagged separately as `:<version>`
  (e.g. `:24.04`, `:26.04`).
- The build dependencies of projects under <https://github.com/orgs/linuxmuster/> shall be satisfied.
- The supported projects shall be configurable. The defaults are:
  - linuxmuster-api
  - linuxmuster-base7
  - linuxmuster-cli7
  - linuxmuster-common
  - linuxmuster-fileserver
  - linuxmuster-linbo7
  - linuxmuster-linbo-gui
  - linuxmuster-linuxclient7
  - linuxmuster-prepare
  - linuxmuster-tools
  - linuxmuster-webui7
  - sophomorix4
- As an additional dependency, the latest release of the linuxmuster-common package
  (see <https://github.com/linuxmuster/linuxmuster-common/releases>) shall be included.
- The Docker image shall be usable both as a runner in a GitHub workflow and locally as
  a Docker image on a Linux system.
- For use as a local build system, additional packages to be installed shall be configurable.
- Likewise, the shell shall be configurable (bash, zsh, ash, fish).
- For each project:
  - a dedicated build script shall be created.
  - a sample release.yml file shall be placed in the workflows subdirectory, which can be
    used as a GitHub workflow for the distributions lmn73 and lmn74.
