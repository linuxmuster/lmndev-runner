#!/bin/bash
#
# Builds the lmndev-runner Docker image(s) locally.
# Calls collect-deps.sh and then builds the image(s).
#
# Usage: ./build.sh [--no-collect] [<ubuntu-version>|all]
#   --no-collect      Do not regenerate deps.txt and linuxmuster-common.deb
#   <ubuntu-version>  Build for a specific Ubuntu version (e.g. 24.04, 26.04)
#   all               Build all versions defined in UBUNTU_VERSIONS (config)
#                     Default: build UBUNTU_VERSION from config
#
# thomas@linuxmuster.net
# 20260427
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

. ./config

NO_COLLECT=false
BUILD_TARGET=""

for arg in "$@"; do
    case "$arg" in
        --no-collect) NO_COLLECT=true ;;
        *)            BUILD_TARGET="$arg" ;;
    esac
done

# Determine list of versions to build
if [ "$BUILD_TARGET" = "all" ]; then
    VERSIONS="$UBUNTU_VERSIONS"
elif [ -n "$BUILD_TARGET" ]; then
    VERSIONS="$BUILD_TARGET"
else
    VERSIONS="$UBUNTU_VERSION"
fi

echo "=== lmndev-runner Build ==="
echo "  Versions:  ${VERSIONS}"
echo "  Image:     ${IMAGE_NAME}"
echo "  Shell:     ${DEFAULT_SHELL}"
[ -n "$EXTRA_PACKAGES" ] && echo "  Extras:    ${EXTRA_PACKAGES}"
echo ""

# Collect dependencies once (shared across all versions)
if [ "$NO_COLLECT" = false ]; then
    bash "$SCRIPT_DIR/collect-deps.sh"
    echo ""
else
    echo "--- Skipping collect-deps.sh (--no-collect)"
    [ -f deps.txt ] || { echo "ERROR: deps.txt not found."; exit 1; }
    [ -f linuxmuster-common.deb ] || { echo "ERROR: linuxmuster-common.deb not found."; exit 1; }
fi

EXTRA_PACKAGES_ARGS=()
[ -n "${EXTRA_PACKAGES}" ] && EXTRA_PACKAGES_ARGS=(--build-arg "EXTRA_PACKAGES=${EXTRA_PACKAGES}")

for VERSION in $VERSIONS; do
    # Check availability, fall back to UBUNTU_FALLBACK if needed
    UBUNTU_TAG="$VERSION"
    if ! docker pull "ubuntu:${VERSION}" >/dev/null 2>&1; then
        echo "WARNING: ubuntu:${VERSION} not available, using fallback: ${UBUNTU_FALLBACK}"
        UBUNTU_TAG="$UBUNTU_FALLBACK"
    fi

    # Version-specific tags
    EXTRA_TAGS=(-t "${IMAGE_NAME}:${VERSION}" -t "${GHCR_IMAGE}:${VERSION}")
    # Primary version also gets :latest
    if [ "$VERSION" = "$UBUNTU_VERSION" ]; then
        EXTRA_TAGS+=(-t "${IMAGE_NAME}:latest" -t "${GHCR_IMAGE}:latest")
    fi

    echo "--- Building Docker image for Ubuntu ${VERSION} ..."
    docker build \
        --build-arg UBUNTU_VERSION="${UBUNTU_TAG}" \
        --build-arg DEFAULT_SHELL="${DEFAULT_SHELL}" \
        "${EXTRA_PACKAGES_ARGS[@]}" \
        --build-arg MY_USER="${MY_USER}" \
        --build-arg MY_UID="${MY_UID}" \
        --build-arg MY_GID="${MY_GID}" \
        "${EXTRA_TAGS[@]}" \
        .
    echo "--- Done: ${IMAGE_NAME}:${VERSION}"
    echo ""
done

rm -f deps.txt linuxmuster-common.deb

echo "=== All images built ==="
