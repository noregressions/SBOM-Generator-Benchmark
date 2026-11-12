#!/usr/bin/env bash
# sbomqs (Interlynk) — scores SBOM *quality* (NTIA minimum elements, BSI TR-03183, etc). Use it to compare what each generator produced.
# Install: brew install sbomqs   |   https://github.com/interlynk-io/sbomqs
# Expects the generator demos to have run first.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/sbomqs/output"; mkdir -p "$OUT"
T="$ROOT/tools"

# One representative "whole sample-app or main ecosystem" SBOM per generator.
declare -a FILES=(
  "syft/output/sample-app.cdx.json"
  "syft/output/sample-app.spdx.json"
  "trivy/output/sample-app.cdx.json"
  "trivy/output/sample-app.spdx.json"
  "cdxgen/output/sample-app.cdx.json"
  "cyclonedx-maven-plugin/output/bom.json"
  "cyclonedx-gradle-plugin/output/bom.json"
  "sbom-plus-maven-plugin/output/sbom-plus-cyclonedx.json"
  "cyclonedx-npm/output/node.prod-only.cdx.json"
  "cyclonedx-python/output/python.environment.cdx.json"
  "cyclonedx-gomod/output/go.app.cdx.json"
  "cargo-cyclonedx/output/rust.host-target.cdx.json"
  "microsoft-sbom-tool/output/_manifest/spdx_2.2/manifest.spdx.json"
  "kubernetes-bom/output/go.spdx.json"
  "sbom4python/output/python.cdx.json"
  "cyclonedx-cli/output/merged-all-ecosystems.cdx.json"
  "ort/output/reports/bom.cyclonedx.json"
  "docker-sbom/output/sbom-sample.scout.spdx.json"
  "docker-sbom/output/buildkit-attestation.spdx.json"
  "cdxgen/output/python-3.12-slim.cdx.json"
  "syft/output/python-3.12-slim.cdx.xml"
  "trivy/output/python-3.12-slim.cdx.json"
  "kubernetes-bom/output/python-3.12-slim.spdx.json"
)

echo "== 1. Overall quality score per generator output (0-10)"
{
  printf "%-62s %6s %6s %s\n" "SBOM" "score" "NTIA" "comps"
  for rel in "${FILES[@]}"; do
    f="$T/$rel"; [ -f "$f" ] || continue
    score=$(sbomqs score --basic "$f" 2>/dev/null | awk '$1 ~ /^[0-9]+\.[0-9]+$/ {print $1; exit}' || true)
    [ -n "$score" ] || score="unparseable"   # a document sbomqs cannot parse still gets a row
    ntia=$(sbomqs compliance --ntia --basic "$f" 2>/dev/null | grep -o 'Score:[0-9.]*' | head -1 | cut -d: -f2 || true)
    comps=$(sbomqs score --json "$f" 2>/dev/null | jq -r '.files[0].num_components // "?"' 2>/dev/null || echo "?")
    printf "%-62s %6s %6s %s\n" "$rel" "${score:-?}" "${ntia:-?}" "${comps:-?}"
  done
} | tee "$OUT/scores.txt"

echo "== 2. Detailed breakdown for two very different generators (scanner vs build plugin)"
sbomqs score --detailed "$T/syft/output/sample-app.cdx.json" > "$OUT/detail-syft.txt" 2>&1 || true
sbomqs score --detailed "$T/cyclonedx-maven-plugin/output/bom.json" > "$OUT/detail-maven-plugin.txt" 2>&1 || true
head -40 "$OUT/detail-maven-plugin.txt"

echo "== 3. NTIA minimum-elements compliance report (JSON) for the merged SBOM"
sbomqs compliance --ntia --json "$T/cyclonedx-cli/output/merged-all-ecosystems.cdx.json" > "$OUT/ntia-merged.json" 2>&1 || true
echo "Done. Outputs in $OUT"
