#!/usr/bin/env bash
# spdx-sbom-generator (OpenSBOM / Linux Foundation) — SPDX 2.x tag-value from package-manager manifests; one doc per ecosystem.
# Install: brew install spdx-sbom-generator   |   https://github.com/opensbom-generator/spdx-sbom-generator
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/spdx-sbom-generator/output"; mkdir -p "$OUT"
APP="$ROOT/sample-app"

echo "== 1. One run per project directory; emits bom-<ecosystem>.spdx (tag-value) per detected package manager"
# The generator looks for a manifest in the directory you point it at (it does not walk a mixed tree), so loop.
for d in java-maven java-gradle node python go rust; do
  echo "--- $d"
  spdx-sbom-generator -p "$APP/$d" -o "$OUT" -s 2.2 2>&1 | grep -E 'Running generator|generated output|FATA|ERRO' || true
done

echo "== 2. JSON variant for one ecosystem"
spdx-sbom-generator -p "$APP/go" -o "$OUT" -f json 2>&1 | grep -E "generated output|FATA" || true
ls -la "$OUT"
echo "Done. Outputs in $OUT"
