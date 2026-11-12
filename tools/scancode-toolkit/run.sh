#!/usr/bin/env bash
# ScanCode Toolkit (nexB / AboutCode) — deep *file-level* licence, copyright and package detection; exports SPDX and CycloneDX.
# Install: pipx install --python python3.12 scancode-toolkit   (Python 3.14 is not yet supported; if you hit a pluggy
#          'pre_scan hooks' error run: pipx runpip scancode-toolkit install 'pluggy==1.0.0')   |   https://github.com/aboutcode-org/scancode-toolkit
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/scancode-toolkit/output"; mkdir -p "$OUT"
APP="$ROOT/sample-app"
N="${SCANCODE_PROCESSES:-4}"

echo "== 1. Package manifests only (fast): what does ScanCode's package detection see across the tree?"
scancode -n "$N" --package --strip-root --quiet \
  --ignore '*/node_modules/*' --ignore '*/.venv/*' --ignore '*/target/*' --ignore '*/build/*' --ignore '*/.gradle/*' \
  --json-pp "$OUT/packages.scancode.json" \
  --cyclonedx "$OUT/packages.cdx.json" \
  --spdx-tv "$OUT/packages.spdx" \
  "$APP"
jq '{files_scanned: .headers[0].extra_data.files_count, packages: (.packages|length), dependencies: (.dependencies|length)}' "$OUT/packages.scancode.json"

echo "== 2. Full licence + copyright + package scan of ONE small project (this is what ScanCode is really for)"
scancode -n "$N" --license --copyright --package --info --strip-root --quiet \
  --ignore '*/target/*' \
  --json-pp "$OUT/java-maven.full.scancode.json" \
  --html "$OUT/java-maven.full.html" \
  --spdx-rdf "$OUT/java-maven.full.spdx.rdf" \
  --cyclonedx-xml "$OUT/java-maven.full.cdx.xml" \
  "$APP/java-maven"
jq -r '.files[] | select(.detected_license_expression != null) | "\(.path): \(.detected_license_expression)"' "$OUT/java-maven.full.scancode.json" | head
# ScanCode appends a random ?uuid=... to every package id. Beside an npm package name such as js-tokens, GitHub's
# secret scanning reads one as an old-style npm access token and blocks the push, so the suffixes are removed from the
# output that gets committed. The ids stay consistent within each file because every occurrence is changed the same way.
sed -i.bak -E 's/\?uuid=[0-9a-f-]{36}//g' "$OUT"/*.scancode.json && rm -f "$OUT"/*.scancode.json.bak
echo "Done. Outputs in $OUT (open java-maven.full.html in a browser)"
