#!/usr/bin/env bash
# ORT — OSS Review Toolkit. Analyzer resolves dependencies for 20+ package managers, then Reporter emits SPDX, CycloneDX, and
# human reports. Heavyweight (JVM), so we run the official container.   |   https://github.com/oss-review-toolkit/ort
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/ort/output"; mkdir -p "$OUT"
APP="$ROOT/sample-app"
ORT_IMAGE="${ORT_IMAGE:-ghcr.io/oss-review-toolkit/ort:latest}"

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon is not running (ORT is run via its container here). Alternatives:"
  echo "  - sdk install ort  (SDKMAN)  or  download the CLI from GitHub releases, then replace 'docker run ...' below with 'ort'"
  exit 0
fi

rm -rf "$OUT/analyzer" "$OUT/reports"   # ORT refuses to overwrite existing result files
echo "== 1. analyze: resolve the dependency trees of every project in the tree (Maven, Gradle, npm, pip, Go, Cargo)"
# (mounted read-write: ORT stashes node_modules in a temp dir inside the project while it resolves npm)
docker run --rm -v "$APP:/project" -v "$OUT:/out" "$ORT_IMAGE" \
  analyze -i /project -o /out/analyzer -f JSON 2>&1 | grep -E 'Found|resolved dependencies|ERROR|Error|Wrote|issues' | cut -c1-220 \
  || echo "(analyze exited non-zero: ORT returns 2 when any package manager reported an issue; the result file is still written)"

echo "== 2. report: SPDX + CycloneDX + a WebApp report from the analyzer result"
docker run --rm -v "$OUT:/out" "$ORT_IMAGE" \
  report -i /out/analyzer/analyzer-result.json -o /out/reports -f SpdxDocument,CycloneDx,WebApp,PlainTextTemplate 2>&1 | grep -E 'Successfully|ERROR|took' | cut -c1-200 || true

echo "== 3. (optional, slow) scan: licence-scan every source artifact with ScanCode and feed results into the report"
echo "   docker run --rm -v $OUT:/out $ORT_IMAGE scan -i /out/analyzer/analyzer-result.json -o /out/scanner"
find "$OUT" -type f | head -20
echo "Done. Outputs in $OUT (open reports/scan-report-web-app.html)"
