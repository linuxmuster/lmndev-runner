#!/bin/bash
#
# Sammelt Build-Abhängigkeiten aller konfigurierten Projekte und
# lädt das neueste linuxmuster-common Release herunter.
#
# Ausgabe:
#   deps.txt                 - deduplizierte Build-Deps aller Projekte
#   linuxmuster-common.deb   - neuestes Release-Paket
#
# thomas@linuxmuster.net
# 20260425
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/config"

CONTROL_BASE_URL="https://raw.githubusercontent.com/${GITHUB_ORG}"
TMPDIR_WORK="$(mktemp -d)"
trap "rm -rf $TMPDIR_WORK" EXIT

# Build-Depends aller Projekte sammeln
echo "--- Sammle Build-Abhängigkeiten ..."
> "$TMPDIR_WORK/all_deps.txt"

for project in $PROJECTS; do
    ctrl_url="${CONTROL_BASE_URL}/${project}/main/debian/control"
    ctrl_file="$TMPDIR_WORK/${project}.control"

    printf "  %-40s" "$project ..."
    if curl -sf --max-time 10 "$ctrl_url" -o "$ctrl_file"; then
        echo "OK"
        awk '/^Build-Depends:/{
            sub(/^Build-Depends: */, "")
            block = $0
            while ((getline line) > 0) {
                if (line ~ /^[ \t]/) { block = block " " line }
                else { break }
            }
            print block
        }' "$ctrl_file" >> "$TMPDIR_WORK/all_deps.txt"
    else
        echo "WARNUNG: nicht erreichbar"
    fi
done

# Paketliste normalisieren: Version-Constraints entfernen, deduplizieren,
# linuxmuster-Pakete ausschließen (werden separat installiert)
cat "$TMPDIR_WORK/all_deps.txt" \
    | sed 's/([^)]*)//g' \
    | tr ',' '\n' \
    | sed 's/|.*//' \
    | tr -d ' \t' \
    | grep -v '^$' \
    | grep -v '^linuxmuster-' \
    | sort -u \
    > "$SCRIPT_DIR/deps.txt"

echo "  -> $(wc -l < "$SCRIPT_DIR/deps.txt") eindeutige Build-Abhängigkeiten."

# Neuestes linuxmuster-common Release ermitteln und herunterladen
echo ""
echo "--- Hole neuestes ${COMMON_REPO} Release ..."
RELEASE_API="https://api.github.com/repos/${GITHUB_ORG}/${COMMON_REPO}/releases/latest"
RELEASE_JSON="$TMPDIR_WORK/release.json"

curl -sf --max-time 30 "$RELEASE_API" -o "$RELEASE_JSON"
RELEASE_TAG="$(python3 -c "import json; print(json.load(open('$RELEASE_JSON'))['tag_name'])")"

DEB_URL="$(python3 - <<'EOF'
import json, sys
data = json.load(open(sys.argv[1]))
assets = data.get("assets", [])
# bevorzuge _all.deb, dann beliebiges .deb
for suffix in ("_all.deb", ".deb"):
    hits = [a["browser_download_url"] for a in assets if a["name"].endswith(suffix)]
    if hits:
        print(hits[0])
        sys.exit(0)
sys.exit(1)
EOF
"$RELEASE_JSON")"

if [ -z "$DEB_URL" ]; then
    echo "FEHLER: Kein .deb-Paket im Release ${RELEASE_TAG} gefunden."
    exit 1
fi

DEB_FILE="$(basename "$DEB_URL")"
echo "  Version: $RELEASE_TAG"
echo "  Paket:   $DEB_FILE"
curl -Lf --max-time 120 "$DEB_URL" -o "$SCRIPT_DIR/linuxmuster-common.deb"
echo "  -> linuxmuster-common.deb heruntergeladen."
