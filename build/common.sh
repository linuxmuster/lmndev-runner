#!/bin/bash
#
# Gemeinsame Build-Funktionen für lmndev-runner Pro-Projekt-Skripte.
#
# Umgebungsvariablen:
#   WORKSPACE    Quellverzeichnis (Standard: GITHUB_WORKSPACE oder pwd)
#   OUTPUT_DIR   Zielverzeichnis für erzeugte .deb/.changes-Dateien
#   BUILD_FLAGS  Zusätzliche dpkg-buildpackage-Flags
#
# thomas@linuxmuster.net
# 20260425
#

# Quellverzeichnis bestimmen
get_workspace() {
    if [ -n "$GITHUB_WORKSPACE" ]; then
        echo "$GITHUB_WORKSPACE"
    elif [ -n "$WORKSPACE" ]; then
        echo "$WORKSPACE"
    else
        echo "$(pwd)"
    fi
}

# Debian-Paket bauen
build_package() {
    local src
    src="$(get_workspace)"

    cd "$src" || { echo "FEHLER: Kann nicht nach ${src} wechseln."; exit 1; }

    local pkg version
    pkg="$(dpkg-parsechangelog -S Source 2>/dev/null || basename "$src")"
    version="$(dpkg-parsechangelog -S Version 2>/dev/null || echo "unbekannt")"

    echo "=== Baue ${pkg} (${version}) in ${src} ==="

    # ccache aktivieren wenn verfügbar
    if command -v ccache >/dev/null 2>&1; then
        export PATH="/usr/lib/ccache:$PATH"
        export CCACHE_DIR="${CCACHE_DIR:-/tmp/ccache}"
        mkdir -p "$CCACHE_DIR"
    fi

    dpkg-buildpackage -us -uc -b -tc ${BUILD_FLAGS}

    echo "=== ${pkg} fertig gebaut ==="

    # Erzeugten Dateien in OUTPUT_DIR verschieben
    if [ -n "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        find "$(dirname "$src")" -maxdepth 1 \
            \( -name "*.deb" -o -name "*.changes" -o -name "*.buildinfo" \) \
            -exec mv {} "$OUTPUT_DIR/" \;
        echo "    Pakete verschoben nach: ${OUTPUT_DIR}"
    fi
}
