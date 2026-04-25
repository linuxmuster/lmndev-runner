#!/bin/bash
#
# Startet den lmndev-runner Container interaktiv.
#
# Verwendung: ./start.sh [quellverzeichnis] [shell] [homeverzeichnis]
#   quellverzeichnis  Verzeichnis, das als /workspace eingebunden wird
#                     (Standard: aktuelles Verzeichnis)
#   shell             Shell im Container: bash | zsh | ash | fish
#                     (Standard: DEFAULT_SHELL aus config)
#   homeverzeichnis   Host-Verzeichnis, das als /home/build eingebunden wird
#                     (Standard: keines; auch per BUILD_HOME setzbar)
#
# Beispiele:
#   ./start.sh ~/src zsh ~/lmndev-home
#   BUILD_HOME=~/lmndev-home ./start.sh ~/src
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

# Home-Volume: Argument hat Vorrang vor Umgebungsvariable BUILD_HOME
HOME_VOLUME="${3:-${BUILD_HOME:-}}"
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
[ -n "${HOME_VOLUME}" ] && echo "  Home:      ${HOME_VOLUME} -> /home/${MY_USER}"
echo ""

HOME_MOUNT=""
[ -n "${HOME_VOLUME}" ] && HOME_MOUNT="-v ${HOME_VOLUME}:/home/${MY_USER}"

docker run -it --rm \
    --name "${IMAGE_NAME}" \
    -h "${IMAGE_NAME}" \
    -u "${MY_UID}:${MY_GID}" \
    -e DEFAULT_SHELL="${SHELL_OVERRIDE}" \
    -v /etc/localtime:/etc/localtime:ro \
    -v "${WORKSPACE}:/workspace" \
    ${HOME_MOUNT} \
    -w /workspace \
    "${IMAGE_NAME}:latest"
