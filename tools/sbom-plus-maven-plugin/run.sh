#!/usr/bin/env bash
# SBOM+ Maven Plugin (noregressions) — CycloneDX SBOM that covers the *whole build*: resolved project dependencies,
# every Maven build plugin and its transitive dependencies, and imported BOMs. Plus a scan report that says where each
# artifact came from (MAIN_BUILD / BUILD_TOOLING / BOM) and the path that brought it in.
# No install: run by coordinates.   |   https://noregressions.github.io/sbom-plus-maven-plugin/   |   Apache-2.0
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/sbom-plus-maven-plugin/output"; mkdir -p "$OUT"
PRJ="$ROOT/sample-app/java-maven"
PLUGIN="dev.noregressions:sbom-plus-maven-plugin:1.0.0"

echo "== 1. scan: CycloneDX 1.5 SBOM + JSON scan report, no pom changes, works on an unbuilt checkout"
mvn -q -B -f "$PRJ/pom.xml" "$PLUGIN:scan" \
  -DsbomPlus.sbomOutputFile="$OUT/sbom-plus-cyclonedx.json" \
  -DsbomPlus.outputFile="$OUT/sbom-plus-report.json"

echo "== 2. What is in the SBOM, by scope"
jq '{components: (.components|length), dependencies: (.dependencies|length), spec: .specVersion,
     scopes: ([.components[].scope] | group_by(.) | map({(.[0]): length}) | add)}' "$OUT/sbom-plus-cyclonedx.json"

echo "== 3. The scan report: where did each artifact come from? (rows, per module)"
jq '[.modules[].dependencies[]] | group_by(.origin) | map({(.[0].origin): length}) | add' "$OUT/sbom-plus-report.json"

echo "== 4. Build tooling that never appears on the application classpath (first 15 of the distinct coordinates)"
jq -r '[.modules[].dependencies[] | select(.origin == "BUILD_TOOLING") | "\(.coordinate.groupId):\(.coordinate.artifactId):\(.coordinate.version)"] | unique | .[:15][]' "$OUT/sbom-plus-report.json"

echo "== 4b. How did junit get in? (broughtInBy path from the report)"
jq -c '.modules[].dependencies[] | select(.coordinate.artifactId == "junit-platform-commons") | {scope, origin, broughtInBy: [.broughtInBy[] | .artifactId? // .]}' "$OUT/sbom-plus-report.json" | head -2

echo "== 5. Compare with the CycloneDX Maven plugin on the same pom (components only)"
if [ -f "$ROOT/tools/cyclonedx-maven-plugin/output/bom-aggregate-with-test-scope.json" ]; then
  A=$(jq '.components|length' "$ROOT/tools/cyclonedx-maven-plugin/output/bom-aggregate-with-test-scope.json")
  B=$(jq '.components|length' "$OUT/sbom-plus-cyclonedx.json")
  echo "cyclonedx-maven-plugin (compile+runtime+test): $A components   sbom-plus (incl. build plugins): $B components"
fi
echo "Done. Outputs in $OUT"
