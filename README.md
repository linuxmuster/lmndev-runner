# lmndev-runner

Docker-based build environment for [linuxmuster.net](https://linuxmuster.net) Debian packages.

The image can be used both as a container in a **GitHub Actions workflow** and as a
**local build system** on a Linux machine.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Directory Structure](#directory-structure)
3. [Configuration](#configuration)
4. [Building the Image](#building-the-image)
5. [Local Usage](#local-usage)
6. [Usage as a GitHub Actions Runner](#usage-as-a-github-actions-runner)
7. [Release Workflows](#release-workflows)
8. [Per-Project Build Scripts](#per-project-build-scripts)
9. [Publishing the Image (GHCR)](#publishing-the-image-ghcr)

---

## Prerequisites

For **local use** the following are required:

- Docker
- `bash`, `curl`, `python3` (for `collect-deps.sh` and `build.sh`)
- Internet access (GitHub API, Ubuntu package repositories)

For **GitHub Actions use** no local prerequisites are needed — the image is pulled
from GHCR.

---

## Directory Structure

```text
lmndev-runner/
├── config                        # Central configuration
├── Dockerfile                    # Image definition
├── build.sh                      # Local image build
├── collect-deps.sh               # Collects build dependencies, downloads linuxmuster-common
├── start.sh                      # Starts the container interactively
├── build/                        # Per-project build scripts (installed in image at /opt/lmndev/build/)
│   ├── common.sh                 # Shared build functions
│   ├── linuxmuster-api.sh
│   ├── linuxmuster-base7.sh
│   ├── linuxmuster-cli7.sh
│   ├── linuxmuster-common.sh
│   ├── linuxmuster-fileserver.sh
│   ├── linuxmuster-linbo7.sh
│   ├── linuxmuster-linbo-gui.sh
│   ├── linuxmuster-linuxclient7.sh
│   ├── linuxmuster-prepare.sh
│   ├── linuxmuster-tools.sh
│   ├── linuxmuster-webui7.sh
│   └── sophomorix4.sh
├── workflows/                    # Sample release workflows for project repositories
│   ├── linuxmuster-api.release.yml
│   ├── linuxmuster-base7.release.yml
│   └── ...                       # one .release.yml per project
└── .github/workflows/
    └── build-push.yml            # Builds and pushes the image itself to GHCR
```

---

## Configuration

All settings are located in the `config` file. It is sourced by `build.sh`,
`collect-deps.sh`, and `start.sh`.

```sh
# Ubuntu version of the base image
UBUNTU_VERSION="26.04"
UBUNTU_FALLBACK="24.04"   # fallback if the primary version is not available

# Docker image names
IMAGE_NAME="lmndev-runner"
GHCR_IMAGE="ghcr.io/linuxmuster/lmndev-runner"

# Default shell in the container: bash | zsh | ash | fish
DEFAULT_SHELL="bash"

# Additional packages for local use only (leave empty for GitHub Actions)
EXTRA_PACKAGES=""

# Build user in the container
MY_USER="build"
MY_UID="1000"
MY_GID="1000"

# Supported projects (space-separated)
PROJECTS="linuxmuster-api linuxmuster-base7 ..."
```

### Configuration Parameters at a Glance

| Parameter | Description | Default |
| --- | --- | --- |
| `UBUNTU_VERSION` | Ubuntu base version | `26.04` |
| `UBUNTU_FALLBACK` | Fallback version | `24.04` |
| `DEFAULT_SHELL` | Shell in the container | `bash` |
| `EXTRA_PACKAGES` | Additional local packages | *(empty)* |
| `MY_UID` / `MY_GID` | UID/GID of the build user | `1000` / `1000` |
| `PROJECTS` | Projects to support | all 12 projects |

### Shell Options

| Value | Package | Shell Path |
| --- | --- | --- |
| `bash` | `bash` | `/bin/bash` |
| `zsh` | `zsh` | `/bin/zsh` |
| `ash` | `busybox` | `/bin/ash` |
| `fish` | `fish` | `/usr/bin/fish` |

### Customising the Project List

To support only specific projects, shorten the `PROJECTS` variable in `config`
accordingly. Build dependencies will then only be collected for the listed projects,
reducing the image size.

---

## Building the Image

### 1. Collect build dependencies and build the image

```sh
./build.sh
```

This command automatically performs the following steps:

1. **Check the Ubuntu version** — if `ubuntu:26.04` is not available, it falls back
   to `ubuntu:24.04`.
2. **Call `collect-deps.sh`** — fetches the `debian/control` file for each configured
   project from GitHub and extracts all `Build-Depends` fields. The deduplicated
   package list is written to `deps.txt`.
3. **Download the latest `linuxmuster-common`** — the most recent `.deb` package is
   determined via the GitHub Releases API and saved locally.
4. **Run `docker build`** — the image is built with the configured build arguments.
   The temporary files (`deps.txt`, `linuxmuster-common.deb`) are deleted afterwards.

### 2. Skip dependency collection and build from existing files

If `deps.txt` and `linuxmuster-common.deb` are already present (e.g. after a failed
build), the download step can be skipped:

```sh
./build.sh --no-collect
```

### How `collect-deps.sh` works

The script downloads the `debian/control` file for each project listed in `PROJECTS`
directly from GitHub:

```text
https://raw.githubusercontent.com/linuxmuster/PROJECT/main/debian/control
```

All package names are extracted from the `Build-Depends` field. During this process:

- Version constraints (e.g. `debhelper (>= 10)`) are stripped
- Alternatives (`package-a | package-b`) are reduced to the first option
- `linuxmuster-*` packages are excluded (installed separately)
- Duplicates are removed

The `linuxmuster-common` package is fetched separately via the GitHub Releases API
and installed with `gdebi` to automatically resolve its dependencies.

---

## Local Usage

### Start the container interactively

```sh
./start.sh [directory]
```

The specified directory (default: current directory) is mounted into the container
as `/workspace`. The configured shell starts automatically.

**Example:** Build the `linuxmuster-base7` source:

```sh
cd ~/src/linuxmuster-base7
/path/to/lmndev-runner/start.sh .
# Inside the container:
linuxmuster-base7.sh
```

### Build a package in a single command

```sh
docker run --rm \
  -v "$PWD:/workspace" \
  -w /workspace \
  lmndev-runner:latest \
  /opt/lmndev/build/linuxmuster-base7.sh
```

### Specifying an output directory

The environment variable `OUTPUT_DIR` causes the generated `.deb` files to be moved
to a specific directory:

```sh
docker run --rm \
  -v "$PWD:/workspace" \
  -v "$HOME/packages:/output" \
  -w /workspace \
  -e OUTPUT_DIR=/output \
  lmndev-runner:latest \
  /opt/lmndev/build/linuxmuster-base7.sh
```

---

## Usage as a GitHub Actions Runner

The image can be used as a job container in any GitHub Actions workflow. All build
dependencies of the supported projects are already included in the image.

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/linuxmuster/lmndev-runner:latest
      options: --user root

    steps:
      - uses: actions/checkout@v4
      - run: /opt/lmndev/build/linuxmuster-base7.sh
        env:
          OUTPUT_DIR: ${{ github.workspace }}/packages
```

The build scripts are installed in the container at `/opt/lmndev/build/` and can be
called directly by name via `$PATH`.

---

## Release Workflows

For each supported project a ready-to-use sample file `PROJECT.release.yml` is
provided in the `workflows/` directory. It can be copied directly into the respective
project repository and used as a GitHub Actions release workflow.

### How to use

1. Copy the matching file from `workflows/` into the project repository:

   ```sh
   cp workflows/linuxmuster-base7.release.yml \
      ~/src/linuxmuster-base7/.github/workflows/release.yml
   ```

2. Add three secrets to the project repository
   (`Settings → Secrets and variables → Actions`):

   | Secret | Description |
   | --- | --- |
   | `REPO_HOST` | Hostname of the APT repository server |
   | `REPO_USER` | SSH username on the server |
   | `REPO_SSH_KEY` | Private SSH key (without passphrase) |

3. Push a release tag — the workflow starts automatically:

   ```sh
   git tag v7.3.5-0
   git push origin v7.3.5-0
   ```

### Release workflow steps

The workflow consists of three sequential jobs:

```text
build ──→ release ──→ publish
```

| Job | Description |
| --- | --- |
| **build** | Builds the package inside the `lmndev-runner` container. Version and distribution are read automatically from the first line of `debian/changelog` (e.g. `linuxmuster-base7 (7.3.5-0) lmn73; urgency=medium`). |
| **release** | Creates a GitHub Release with the generated `.deb` files. |
| **publish** | Transfers the packages to the APT repository server via SSH and updates the repository index (`repo-update lmn73` or `repo-update lmn74`). |

The target distribution (`lmn73` or `lmn74`) is determined **automatically** from
`debian/changelog` — no manual selection is required.

### Tag format

The workflow triggers on tags matching the pattern `v[0-9]*`, for example:

```text
v7.3.5-0
v7.4.0-1
```

---

## Per-Project Build Scripts

Each project has its own build script at `build/PROJECT.sh`. Inside the container
these are installed at `/opt/lmndev/build/` and can be called directly by name.

All scripts use the shared `build_package()` function from `build/common.sh`.

### Environment Variables

| Variable | Description | Default |
| --- | --- | --- |
| `WORKSPACE` | Source directory | `$GITHUB_WORKSPACE` or current directory |
| `OUTPUT_DIR` | Target directory for `.deb` files | *(unset, files remain in parent directory)* |
| `BUILD_FLAGS` | Additional `dpkg-buildpackage` flags | *(empty)* |
| `CCACHE_DIR` | ccache directory | `/tmp/ccache` |

`ccache` is activated automatically when available in the container.

### Special case: `linuxmuster-linbo7`

The Linbo build is very resource-intensive (kernel, network drivers, Busybox). The
script `build/linuxmuster-linbo7.sh` automatically sets:

```sh
MAKEFLAGS="-j$(nproc)"
DEB_BUILD_OPTIONS="parallel=$(nproc)"
```

---

## Publishing the Image (GHCR)

The included workflow `.github/workflows/build-push.yml` automatically builds the
image on every push to `main` and pushes it to:

```text
ghcr.io/linuxmuster/lmndev-runner:latest
```

### Repository requirements

In the lmndev-runner repository under `Settings → Actions → General`, the following
must be set:

> **Workflow permissions:** Read and write permissions

This allows the workflow to write the image to the GitHub Container Registry.

### Manual build and push

```sh
# Build locally
./build.sh

# Push manually (after gh auth login or docker login ghcr.io)
docker push ghcr.io/linuxmuster/lmndev-runner:latest
```

---

## License

This project is part of the [linuxmuster.net](https://linuxmuster.net) development environment.
