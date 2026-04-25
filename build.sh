#!/bin/bash
#
# Erstellt das lmndev-runner Docker-Image lokal.
# Ruft collect-deps.sh auf und baut dann das Image.
#
# Verwendung: ./build.sh [--no-collect]
#   --no-collect  deps.txt und linuxmuster-common.deb nicht neu generieren
#
# thomas@linuxmuster.net
# 20260425
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

. ./config

NO_COLLECT=false
if [ "$1" = "--no-collect" ]; then
    NO_COLLECT=true
fi

echo "=== lmndev-runner Build ==="
echo "  Ubuntu:  ${UBUNTU_VERSION} (Fallback: ${UBUNTU_FALLBACK})"
echo "  Image:   ${IMAGE_NAME}"
echo "  Shell:   ${DEFAULT_SHELL}"
[ -n "$EXTRA_PACKAGES" ] && echo "  Extras:  ${EXTRA_PACKAGES}"
echo ""

# Ubuntu-Version prüfen, ggf. Fallback
UBUNTU_TAG="$UBUNTU_VERSION"
if ! docker pull "ubuntu:${UBUNTU_VERSION}" >/dev/null 2>&1; then
    echo "WARNUNG: ubuntu:${UBUNTU_VERSION} nicht verfügbar, nutze Fallback: ${UBUNTU_FALLBACK}"
    UBUNTU_TAG="$UBUNTU_FALLBACK"
fi

# Abhängigkeiten sammeln (ausser --no-collect)
if [ "$NO_COLLECT" = false ]; then
    bash "$SCRIPT_DIR/collect-deps.sh"
    echo ""
else
    echo "--- Überspringe collect-deps.sh (--no-collect)"
    [ -f deps.txt ] || { echo "FEHLER: deps.txt nicht vorhanden."; exit 1; }
    [ -f linuxmuster-common.deb ] || { echo "FEHLER: linuxmuster-common.deb nicht vorhanden."; exit 1; }
fi

# Docker Image bauen
echo "--- Baue Docker Image: ${IMAGE_NAME} ..."
docker build \
    --build-arg UBUNTU_VERSION="${UBUNTU_TAG}" \
    --build-arg DEFAULT_SHELL="${DEFAULT_SHELL}" \
    --build-arg EXTRA_PACKAGES="${EXTRA_PACKAGES}" \
    --build-arg MY_USER="${MY_USER}" \
    --build-arg MY_UID="${MY_UID}" \
    --build-arg MY_GID="${MY_GID}" \
    -t "${IMAGE_NAME}:latest" \
    -t "${GHCR_IMAGE}:latest" \
    .

# Temporäre Dateien entfernen
rm -f deps.txt linuxmuster-common.deb

echo ""
echo "=== Fertig: ${IMAGE_NAME}:latest ==="
