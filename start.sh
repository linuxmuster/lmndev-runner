#!/bin/bash
#
# Starts the lmndev-runner container interactively.
#
# Usage: ./start.sh [source-directory] [shell] [home-directory] [ubuntu-version]
#   source-directory  Directory mounted as /workspace
#                     (default: current directory)
#   shell             Shell in the container: bash | zsh | ash | fish
#                     (default: DEFAULT_SHELL from config)
#   home-directory    Host directory mounted as /home/build
#                     (default: none; also settable via BUILD_HOME)
#   ubuntu-version    Image tag to use: 24.04 | 26.04 | latest
#                     (default: UBUNTU_TAG env var or "latest")
#
# Examples:
#   ./start.sh ~/src zsh ~/lmndev-home 24.04
#   UBUNTU_TAG=24.04 BUILD_HOME=~/lmndev-home ./start.sh ~/src
#
# thomas@linuxmuster.net
# 20260427
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/config"

WORKSPACE="${1:-$PWD}"
WORKSPACE="$(realpath "$WORKSPACE")"

# Shell: argument takes precedence over env var, env var over config default
SHELL_OVERRIDE="${2:-${DEFAULT_SHELL}}"

# Home volume: argument takes precedence over BUILD_HOME env var
HOME_VOLUME="${3:-${BUILD_HOME:-}}"

# Image tag: argument > UBUNTU_TAG env var > "latest"
IMAGE_TAG="${4:-${UBUNTU_TAG:-latest}}"
if [ -n "${HOME_VOLUME}" ]; then
    HOME_VOLUME="$(realpath "${HOME_VOLUME}")"
    if [ ! -d "${HOME_VOLUME}" ]; then
        echo "FEHLER: Homeverzeichnis nicht gefunden: ${HOME_VOLUME}"
        exit 1
    fi
fi

if [ ! -d "$WORKSPACE" ]; then
    echo "FEHLER: Verzeichnis nicht gefunden: $WORKSPACE"
    exit 1
fi

# Check if image is available
if ! docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" >/dev/null 2>&1; then
    echo "FEHLER: Image '${IMAGE_NAME}:${IMAGE_TAG}' nicht gefunden."
    echo "       Bitte zuerst ./build.sh [${IMAGE_TAG}] ausführen."
    exit 1
fi

echo "Starting ${IMAGE_NAME}:${IMAGE_TAG} ..."
echo "  Workspace: ${WORKSPACE} -> /workspace/build"
echo "  Shell:     ${SHELL_OVERRIDE}"
echo "  User:      ${MY_USER} (${MY_UID}:${MY_GID})"
[ -n "${HOME_VOLUME}" ] && echo "  Home:      ${HOME_VOLUME} -> /home/${MY_USER}"
echo ""

# check if home volume is given
HOME_MOUNT=""
[ -n "${HOME_VOLUME}" ] && HOME_MOUNT="-v ${HOME_VOLUME}:/home/${MY_USER}"

# check if distcc/hosts exists and is not empty, then mount it read-only
DISTCC_MOUNT=""
distcc_hosts="/etc/distcc/hosts"
if [ -s "$distcc_hosts" ]; then
    DISTCC_MOUNT="-v ${distcc_hosts}:${distcc_hosts}:ro"
fi

# run docker container interactively
docker run -it --rm \
    --name "${IMAGE_NAME}" \
    -h "${IMAGE_NAME}" \
    -u "${MY_UID}:${MY_GID}" \
    -e DEFAULT_SHELL="${SHELL_OVERRIDE}" \
    -v /etc/localtime:/etc/localtime:ro \
    -v "${WORKSPACE}:/workspace/build" \
    ${HOME_MOUNT} \
    ${DISTCC_MOUNT} \
    -w /workspace/build \
    "${IMAGE_NAME}:${IMAGE_TAG}"
