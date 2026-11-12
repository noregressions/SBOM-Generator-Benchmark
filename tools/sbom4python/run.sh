#!/usr/bin/env bash
# sbom4python (Anthony Harrison's sbom4* family) — SBOM for an installed Python module incl. hidden transitive deps; SPDX or CycloneDX.
# Install: pipx install sbom4python  (needs libmagic: brew install libmagic)   |   https://github.com/anthonyharrison/sbom4python
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/sbom4python/output"; mkdir -p "$OUT"
PRJ="$ROOT/sample-app/python"
PY="$PRJ/.venv/bin/python"
export PATH="$PRJ/.venv/bin:$PATH"   # sbom4python shells out to a bare "pip"; make it the venv's

echo "== 1. From requirements.txt, resolved against the venv -> SPDX tag-value"
sbom4python -r "$PRJ/requirements.txt" --python "$PY" --use-pip --sbom spdx --format tag -o "$OUT/python.spdx"

echo "== 2. Same -> CycloneDX JSON, with dependency graph"
sbom4python -r "$PRJ/requirements.txt" --python "$PY" --use-pip --sbom cyclonedx --format json -o "$OUT/python.cdx.json" -g "$OUT/python-deps.dot"

echo "== 3. A single module and everything it drags in (flask) -> SPDX JSON"
sbom4python -m flask --python "$PY" --use-pip --sbom spdx --format json -o "$OUT/flask.spdx.json"

ls -la "$OUT"; jq '.components|length' "$OUT/python.cdx.json"
echo "Done. Outputs in $OUT"
