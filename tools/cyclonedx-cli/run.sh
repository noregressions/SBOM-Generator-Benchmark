#!/usr/bin/env bash
# cyclonedx-cli — not a generator, but the Swiss-army knife for SBOMs other tools produced: validate, convert, merge, diff, analyze.
# Install: brew install cyclonedx-cli   |   https://github.com/CycloneDX/cyclonedx-cli
# Expects the other tool demos (syft, cdxgen, cyclonedx-npm, cyclonedx-maven-plugin, cyclonedx-gomod ...) to have run first.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/cyclonedx-cli/output"; mkdir -p "$OUT"
T="$ROOT/tools"

echo "== 1. Validate SBOMs from several generators against the CycloneDX schema"
for f in "$T/syft/output/sample-app.cdx.json" "$T/cdxgen/output/sample-app.cdx.json" "$T/trivy/output/sample-app.cdx.json" \
         "$T/cyclonedx-maven-plugin/output/bom.json" "$T/cyclonedx-npm/output/node.prod-only.cdx.json"; do
  [ -f "$f" ] || continue
  printf "%-55s " "${f#$T/}"; cyclonedx validate --input-file "$f" --input-format json --fail-on-errors >/dev/null 2>&1 && echo VALID || echo INVALID
done

echo "== 2. Convert: CycloneDX JSON -> XML -> SPDX JSON -> CSV (lossy, but handy for spreadsheets)"
cyclonedx convert --input-file "$T/cyclonedx-maven-plugin/output/bom.json" --output-file "$OUT/maven.cdx.xml"  --output-format xml
cyclonedx convert --input-file "$T/cyclonedx-maven-plugin/output/bom.json" --output-file "$OUT/maven.spdx.json" --output-format spdxjson
cyclonedx convert --input-file "$T/cyclonedx-maven-plugin/output/bom.json" --output-file "$OUT/maven.csv"       --output-format csv
head -5 "$OUT/maven.csv"

echo "== 3. Merge the per-ecosystem SBOMs from the CycloneDX language tools into one hierarchical SBOM"
cyclonedx merge --hierarchical --name sbom-sample-app --version 1.0.0 --group com.example \
  --input-files "$T/cyclonedx-maven-plugin/output/bom.json" "$T/cyclonedx-npm/output/node.prod-only.cdx.json" \
                "$T/cyclonedx-python/output/python.environment.cdx.json" "$T/cyclonedx-gomod/output/go.app.cdx.json" \
                "$T/cargo-cyclonedx/output/rust.host-target.cdx.json" \
  --output-file "$OUT/merged-all-ecosystems.cdx.json" --output-format json
jq '{components: (.components|length), nested_assemblies: [.components[] | select(.components) | .name]}' "$OUT/merged-all-ecosystems.cdx.json"

echo "== 4. Diff: what changed between the Maven SBOM with and without test scope?"
cyclonedx diff "$T/cyclonedx-maven-plugin/output/bom.json" "$T/cyclonedx-maven-plugin/output/bom-aggregate-with-test-scope.json" \
  --component-versions --output-format text | tee "$OUT/diff-maven-test-scope.txt" | head -30

echo "== 5. Diff two *generators* on the same Node project: cdxgen vs cyclonedx-npm"
cyclonedx diff "$T/cyclonedx-npm/output/node.prod-only.cdx.json" "$T/cdxgen/output/node.required-only.cdx.json" \
  --component-versions --output-format text > "$OUT/diff-npm-vs-cdxgen.txt" || true
grep -c . "$OUT/diff-npm-vs-cdxgen.txt" | xargs echo "lines of diff:"

echo "== 6. Analyze: find components that appear more than once with different versions"
cyclonedx analyze --input-file "$T/syft/output/sample-app.cdx.json" --multiple-component-versions --output-format text | head -20

echo "Done. Outputs in $OUT"
