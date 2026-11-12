#!/usr/bin/env bash
# Syft (Anchore) — generate SBOMs from a source tree, a built jar and a container image.
# Install: brew install syft   |   https://github.com/anchore/syft
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/syft/output"; mkdir -p "$OUT"
APP="$ROOT/sample-app"

echo "== 1. Whole multi-language source tree -> CycloneDX, SPDX and Syft-native JSON (one pass, several outputs)"
syft scan "dir:$APP" \
  -o cyclonedx-json="$OUT/sample-app.cdx.json" \
  -o spdx-json="$OUT/sample-app.spdx.json" \
  -o syft-json="$OUT/sample-app.syft.json" \
  -o table="$OUT/sample-app.table.txt" \
  --source-name sbom-sample-app --source-version 1.0.0

echo "== 2. A built artifact: the Maven jar (reads embedded pom.properties, no build tool needed)"
syft scan "file:$APP/java-maven/target/sbom-sample-maven-1.0.0.jar" \
  -o cyclonedx-json="$OUT/maven-jar.cdx.json" -o table

echo "== 3. A container image straight from the registry (no Docker daemon needed) -> SPDX tag-value + CycloneDX XML"
syft scan registry:python:3.12-slim --platform linux/amd64 \
  -o spdx-tag-value="$OUT/python-3.12-slim.spdx" \
  -o cyclonedx-xml="$OUT/python-3.12-slim.cdx.xml" \
  -o table="$OUT/python-3.12-slim.table.txt"

echo "== 4. Convert between formats without rescanning"
syft convert "$OUT/sample-app.syft.json" -o spdx-json="$OUT/sample-app.converted-from-syft.spdx.json"

echo "== 5. Hand the SBOM to Grype for a vulnerability scan (SBOM as input, not source)"
if command -v grype >/dev/null; then
  grype "sbom:$OUT/sample-app.cdx.json" -o table > "$OUT/grype-from-sbom.txt" || true
  tail -n 20 "$OUT/grype-from-sbom.txt"
fi
echo "Done. Outputs in $OUT"
