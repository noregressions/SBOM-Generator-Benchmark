#!/usr/bin/env bash
# cyclonedx-maven-plugin — build-time SBOM from Maven's own resolved dependency graph.
# No install: declared in sample-app/java-maven/pom.xml   |   https://github.com/CycloneDX/cyclonedx-maven-plugin
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/cyclonedx-maven-plugin/output"; mkdir -p "$OUT"
PRJ="$ROOT/sample-app/java-maven"

echo "== 1. makeBom: SBOM for this module (plugin is pre-configured in the pom: JSON + XML, schema 1.6)"
mvn -q -B -f "$PRJ/pom.xml" cyclonedx:makeBom
cp "$PRJ/target/bom.json" "$OUT/bom.json"
cp "$PRJ/target/bom.xml"  "$OUT/bom.xml"

echo "== 2. Zero-config invocation on any Maven project (fully-qualified goal, no pom changes required)"
mvn -q -B -f "$PRJ/pom.xml" org.cyclonedx:cyclonedx-maven-plugin:2.9.1:makeAggregateBom \
  -DoutputName=bom-aggregate -DoutputFormat=json -DschemaVersion=1.5 -DincludeTestScope=true
cp "$PRJ/target/bom-aggregate.json" "$OUT/bom-aggregate-with-test-scope.json"

echo "== 3. What the plugin captures that scanners can't: the dependency *graph*"
jq '{components: (.components|length), dependencies: (.dependencies|length), root: .metadata.component.name, scopes: [.components[].scope]|unique}' "$OUT/bom.json"
echo "Done. Outputs in $OUT"
