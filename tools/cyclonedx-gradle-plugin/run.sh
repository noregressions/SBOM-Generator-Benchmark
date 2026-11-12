#!/usr/bin/env bash
# cyclonedx-gradle-plugin — build-time SBOM from Gradle's resolved configurations.
# No install: applied in sample-app/java-gradle/build.gradle.kts   |   https://github.com/CycloneDX/cyclonedx-gradle-plugin
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/cyclonedx-gradle-plugin/output"; mkdir -p "$OUT"
PRJ="$ROOT/sample-app/java-gradle"

echo "== 1. cyclonedxBom task (configured for runtimeClasspath only, schema 1.6, JSON + XML)"
( cd "$PRJ" && gradle -q --no-daemon cyclonedxBom )
cp "$PRJ/build/reports/bom.json" "$OUT/bom.json"
cp "$PRJ/build/reports/bom.xml"  "$OUT/bom.xml"

echo "== 2. Summary"
jq '{components: (.components|length), dependencies: (.dependencies|length), root: .metadata.component.name, tool: [.metadata.tools.components[]?.name // .metadata.tools[]?.name]}' "$OUT/bom.json"
echo "Done. Outputs in $OUT"
