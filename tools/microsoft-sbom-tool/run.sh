#!/usr/bin/env bash
# Microsoft sbom-tool — SPDX 2.2 (and 3.0) SBOMs for a *build drop*: hashes every shipped file + detects packages via Component Detection.
# Install: brew install sbom-tool   |   https://github.com/microsoft/sbom-tool
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/microsoft-sbom-tool/output"; mkdir -p "$OUT"
APP="$ROOT/sample-app"
DROP="$ROOT/sample-app/java-maven/target"   # the "build drop": binaries we are shipping

echo "== 1. Generate: -b build drop (files to hash) + -bc component path (manifests to detect packages from)"
rm -rf "$OUT/_manifest" "$DROP/_manifest"
sbom-tool generate -b "$DROP" -bc "$APP" -m "$OUT" \
  -pn sbom-sample-app -pv 1.0.0 -ps "Example Corp" -nsb https://example.com/sbom \
  2>&1 | grep -E '\[(information|error)\]' | cut -c1-200 || true
echo "Output layout (note the SPDX doc + manifest.spdx.json.sha256 integrity file):"
find "$OUT/_manifest" -type f | sed "s|$OUT/||"

echo "== 2. Validate the drop against the SBOM it describes (detects tampered/missing files)"
sbom-tool validate -b "$DROP" -o "$OUT/validation.json" -m "$OUT/_manifest" -mi SPDX:2.2 2>&1 | grep -E '\[(information|error)\]' | cut -c1-200 || true
jq '{result: .Result, errors: (.ValidationErrors|length)}' "$OUT/validation.json" 2>/dev/null || true

echo "== 3. Also emit SPDX 3.0 (if supported by this version)"
mkdir -p "$OUT/spdx3"; sbom-tool generate -b "$DROP" -bc "$APP" -m "$OUT/spdx3" -mi SPDX:3.0 \
  -pn sbom-sample-app -pv 1.0.0 -ps "Example Corp" -nsb https://example.com/sbom 2>&1 | grep -E '\[(information|error)\]' | cut -c1-200 || true
find "$OUT/spdx3" -type f | sed "s|$OUT/||" || echo "(SPDX 3.0 not supported in this build)"
echo "Done. Outputs in $OUT"
