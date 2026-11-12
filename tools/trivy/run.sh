#!/usr/bin/env bash
# Trivy (Aqua Security) — SBOM generation from filesystem and image, then scan the SBOM for vulns.
# Install: brew install trivy   |   https://github.com/aquasecurity/trivy
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/trivy/output"; mkdir -p "$OUT"
APP="$ROOT/sample-app"

echo "== 1. Filesystem scan of the source tree -> CycloneDX JSON"
trivy fs --format cyclonedx --output "$OUT/sample-app.cdx.json" "$APP"

echo "== 2. Same tree -> SPDX JSON (and tag-value)"
trivy fs --format spdx-json --output "$OUT/sample-app.spdx.json" "$APP"
trivy fs --format spdx --output "$OUT/sample-app.spdx" "$APP"

echo "== 3. Container image from the registry -> CycloneDX (OS packages + pip packages inside the image)"
trivy image --platform linux/amd64 --format cyclonedx --output "$OUT/python-3.12-slim.cdx.json" python:3.12-slim

echo "== 4. Scan the generated SBOM for vulnerabilities (SBOM as input)"
trivy sbom --format table --output "$OUT/vulns-from-sbom.txt" "$OUT/sample-app.cdx.json" || true
tail -n 30 "$OUT/vulns-from-sbom.txt" || true

echo "== 5. Human-readable listing of what Trivy found (JSON report with package list)"
trivy fs --list-all-pkgs --format json --output "$OUT/sample-app.trivy-report.json" "$APP"
echo "Done. Outputs in $OUT"
