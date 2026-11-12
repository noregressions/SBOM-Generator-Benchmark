#!/usr/bin/env bash
# cyclonedx-py (cyclonedx-bom) — CycloneDX's own Python generator; works from requirements, an environment, Pipenv or Poetry.
# Install: brew install cyclonedx-python   or   pipx install cyclonedx-bom   |   https://github.com/CycloneDX/cyclonedx-python
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/cyclonedx-python/output"; mkdir -p "$OUT"
PRJ="$ROOT/sample-app/python"
[ -x "$PRJ/.venv/bin/python" ] || { python3 -m venv "$PRJ/.venv" && "$PRJ/.venv/bin/pip" -q install -r "$PRJ/requirements.txt"; }

echo "== 1. From requirements.txt only (declared, direct deps; no transitive resolution) -> JSON"
cyclonedx-py requirements "$PRJ/requirements.txt" --pyproject "$PRJ/pyproject.toml" --mc-type application \
  --spec-version 1.6 --of JSON -o "$OUT/python.requirements.cdx.json"

echo "== 2. From the installed virtualenv (what is REALLY installed, incl. transitive deps + licences from metadata) -> JSON"
cyclonedx-py environment "$PRJ/.venv/bin/python" --pyproject "$PRJ/pyproject.toml" --mc-type application \
  --spec-version 1.6 --of JSON -o "$OUT/python.environment.cdx.json"

echo "== 3. Same environment -> XML, reproducible"
cyclonedx-py environment "$PRJ/.venv/bin/python" --output-reproducible --of XML -o "$OUT/python.environment.cdx.xml"

for f in "$OUT"/*.json; do printf "%-36s components=%s\n" "$(basename "$f")" "$(jq '.components|length' "$f")"; done
echo "Note the difference between 1 and 2: requirements lists only what you asked for; environment lists what pip actually installed."
echo "Done. Outputs in $OUT"
