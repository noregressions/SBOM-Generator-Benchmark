#!/usr/bin/env bash
# @cyclonedx/cyclonedx-npm — CycloneDX's own Node.js generator; reads the npm install tree (node_modules + lockfile).
# Install: brew install cyclonedx-npm   or   npm i -g @cyclonedx/cyclonedx-npm   |   https://github.com/CycloneDX/cyclonedx-node-npm
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/cyclonedx-npm/output"; mkdir -p "$OUT"
PRJ="$ROOT/sample-app/node"

echo "== 1. Full install tree (prod + dev) -> CycloneDX 1.6 JSON"
cyclonedx-npm --spec-version 1.6 --output-format JSON --output-file "$OUT/node.full.cdx.json" "$PRJ/package.json"

echo "== 2. Production only: --omit dev (what you would actually ship)"
cyclonedx-npm --omit dev --output-format JSON --output-file "$OUT/node.prod-only.cdx.json" "$PRJ/package.json"

echo "== 3. Lockfile only, no node_modules needed (CI-friendly) -> XML"
cyclonedx-npm --package-lock-only --output-format XML --output-file "$OUT/node.lock-only.cdx.xml" "$PRJ/package.json"

echo "== 4. Reproducible output (no timestamp/serial) so SBOMs can be diffed between builds"
cyclonedx-npm --output-reproducible --omit dev --output-format JSON --output-file "$OUT/node.reproducible.cdx.json" "$PRJ/package.json"

for f in "$OUT"/*.json; do printf "%-32s components=%s dependencies=%s\n" "$(basename "$f")" "$(jq '.components|length' "$f")" "$(jq '.dependencies|length' "$f")"; done
echo "Done. Outputs in $OUT"
