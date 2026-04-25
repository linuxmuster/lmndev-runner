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

set -e

# Quellverzeichnis bestimmen
get_workspace() {
    if [ -n "$GITHUB_WORKSPACE" ]; then
        echo "$GITHUB_WORKSPACE"
    elif [ -n "$WORKSPACE" ]; then
        echo "$WORKSPACE"
    else
        pwd
    fi
}

# Fehlende Build-Abhängigkeiten der aktuellen debian/control nachinstallieren.
# Wird automatisch aufgerufen, damit Feature-Branches mit abweichenden
# Build-Deps ohne Image-Rebuild gebaut werden können.
install_missing_deps() {
    dpkg-checkbuilddeps 2>/dev/null && return 0

    echo "--- Fehlende Build-Abhängigkeiten werden nachinstalliert ..."
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get build-dep -y .
}

# Erzeugte Pakete in OUTPUT_DIR verschieben und auflisten.
# dpkg-buildpackage schreibt in das Elternverzeichnis des Quellbaums.
collect_output() {
    local src="$1"
    local parent_dir
    parent_dir="$(dirname "$src")"

    echo "--- Suche erzeugte Pakete in: ${parent_dir}"

    local count=0
    while IFS= read -r f; do
        echo "    -> ${f}"
        mv "$f" "$OUTPUT_DIR/"
        count=$((count + 1))
    done < <(find "$parent_dir" -maxdepth 1 \
        \( -name "*.deb" -o -name "*.dsc" -o -name "*.tar.*" \
        -o -name "*.changes" -o -name "*.buildinfo" \) \
        2>/dev/null | sort)

    if [ "$count" -eq 0 ]; then
        echo "WARNUNG: Keine erzeugten Pakete in ${parent_dir} gefunden."
        echo "         Inhalt von ${parent_dir}:"
        ls -la "$parent_dir" | grep -v '^total' | head -20
        return 1
    fi

    echo "    ${count} Datei(en) verschoben nach: ${OUTPUT_DIR}"
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
    echo "    Elternverzeichnis (Paketausgabe): $(dirname "$src")"

    # ccache aktivieren wenn verfügbar
    if command -v ccache >/dev/null 2>&1; then
        export PATH="/usr/lib/ccache:$PATH"
        export CCACHE_DIR="${CCACHE_DIR:-/tmp/ccache}"
        mkdir -p "$CCACHE_DIR"
    fi

    install_missing_deps

    dpkg-buildpackage -us -uc -tc ${BUILD_FLAGS}

    echo "=== ${pkg} (${version}) erfolgreich gebaut ==="

    if [ -n "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        collect_output "$src"
    fi
}
