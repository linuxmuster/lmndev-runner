#!/bin/bash
#
# Shared build functions for lmndev-runner per-project scripts.
#
# Environment variables:
#   WORKSPACE    Source directory (default: GITHUB_WORKSPACE or pwd)
#   OUTPUT_DIR   Target directory for generated .deb/.changes files
#   BUILD_FLAGS  Additional dpkg-buildpackage flags
#
# thomas@linuxmuster.net
# 20260425
#

set -e

# Determine source directory
get_workspace() {
    if [ -n "$GITHUB_WORKSPACE" ]; then
        echo "$GITHUB_WORKSPACE"
    elif [ -n "$WORKSPACE" ]; then
        echo "$WORKSPACE"
    else
        pwd
    fi
}

# Install missing build dependencies for the current debian/control.
# Called automatically so feature branches with different build deps
# can be built without rebuilding the image.
install_missing_deps() {
    dpkg-checkbuilddeps 2>/dev/null && return 0

    echo "--- Fehlende Build-Abhängigkeiten werden nachinstalliert ..."
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get build-dep -y .
}

# Move and list generated packages into OUTPUT_DIR.
# dpkg-buildpackage writes to the parent directory of the source tree.
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

# Build Debian package
build_package() {
    local src
    src="$(get_workspace)"

    cd "$src" || { echo "FEHLER: Kann nicht nach ${src} wechseln."; exit 1; }

    local pkg version
    pkg="$(dpkg-parsechangelog -S Source 2>/dev/null || basename "$src")"
    version="$(dpkg-parsechangelog -S Version 2>/dev/null || echo "unbekannt")"

    echo "=== Baue ${pkg} (${version}) in ${src} ==="
    echo "    Elternverzeichnis (Paketausgabe): $(dirname "$src")"

    # Enable ccache if available
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
