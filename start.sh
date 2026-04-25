#!/bin/bash
#
# Startet den lmndev-runner Container interaktiv.
#
# Verwendung: ./start.sh [quellverzeichnis] [shell]
#   quellverzeichnis  Verzeichnis, das als /workspace eingebunden wird
#                     (Standard: aktuelles Verzeichnis)
#   shell             Shell im Container: bash | zsh | ash | fish
#                     (Standard: DEFAULT_SHELL aus config)
#
# Die Shell kann auch per Umgebungsvariable gesetzt werden:
#   DEFAULT_SHELL=zsh ./start.sh
#
# thomas@linuxmuster.net
# 20260425
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/config"

WORKSPACE="${1:-$PWD}"
WORKSPACE="$(realpath "$WORKSPACE")"

# Shell: Argument hat Vorrang vor Umgebungsvariable, diese vor config-Default
SHELL_OVERRIDE="${2:-${DEFAULT_SHELL}}"

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
echo "  Shell:     ${SHELL_OVERRIDE}"
echo "  User:      ${MY_USER} (${MY_UID}:${MY_GID})"
echo ""

docker run -it --rm \
    --name "${IMAGE_NAME}" \
    -h "${IMAGE_NAME}" \
    -u "${MY_UID}:${MY_GID}" \
    -e DEFAULT_SHELL="${SHELL_OVERRIDE}" \
    -v /etc/localtime:/etc/localtime:ro \
    -v "${WORKSPACE}:/workspace" \
    -w /workspace \
    "${IMAGE_NAME}:latest"
