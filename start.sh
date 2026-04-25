#!/bin/bash
#
# Startet den lmndev-runner Container interaktiv.
#
# Verwendung: ./start.sh [quellverzeichnis]
#   quellverzeichnis  Verzeichnis, das als /workspace eingebunden wird
#                     (Standard: aktuelles Verzeichnis)
#
# thomas@linuxmuster.net
# 20260425
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/config"

WORKSPACE="${1:-$PWD}"
WORKSPACE="$(realpath "$WORKSPACE")"

if [ ! -d "$WORKSPACE" ]; then
    echo "FEHLER: Verzeichnis nicht gefunden: $WORKSPACE"
    exit 1
fi

# Prüfen ob Image vorhanden ist
if ! docker image inspect "${IMAGE_NAME}:latest" >/dev/null 2>&1; then
    echo "FEHLER: Image '${IMAGE_NAME}:latest' nicht gefunden."
    echo "       Bitte zuerst ./build.sh ausführen."
    exit 1
fi

echo "Starte ${IMAGE_NAME} ..."
echo "  Workspace: ${WORKSPACE} -> /workspace"
echo "  Shell:     ${DEFAULT_SHELL}"
echo "  User:      ${MY_USER} (${MY_UID}:${MY_GID})"
echo ""

docker run -it --rm \
    --name "${IMAGE_NAME}" \
    -h "${IMAGE_NAME}" \
    -u "${MY_UID}:${MY_GID}" \
    -v /etc/localtime:/etc/localtime:ro \
    -v "${WORKSPACE}:/workspace" \
    -w /workspace \
    "${IMAGE_NAME}:latest"
