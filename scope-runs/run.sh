#!/usr/bin/env bash
# Three SBOMs per tool: RUNTIME (what ships), NONRUNTIME (test/dev/build only), COMBINED (everything).
# Where a tool cannot express one of the three directly, compare.py derives it and labels it as derived.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/sample-app"
OUT="$ROOT/scope-runs/output"; rm -rf "$OUT"; mkdir -p "$OUT"
export FETCH_LICENSE=false
log(){ printf '\n== %s\n' "$*"; }

log "cyclonedx-maven-plugin (java): scope flags on the plugin"
M="$OUT/cyclonedx-maven-plugin"; mkdir -p "$M"; P="$APP/java-maven/pom.xml"
mvn -q -B -f "$P" cyclonedx:makeBom -DoutputFormat=json -DincludeTestScope=false && cp "$APP/java-maven/target/bom.json" "$M/java.runtime.cdx.json"
mvn -q -B -f "$P" cyclonedx:makeBom -DoutputFormat=json -DincludeCompileScope=false -DincludeRuntimeScope=false -DincludeProvidedScope=false -DincludeSystemScope=false -DincludeTestScope=true && cp "$APP/java-maven/target/bom.json" "$M/java.nonruntime.cdx.json"
mvn -q -B -f "$P" cyclonedx:makeBom -DoutputFormat=json -DincludeTestScope=true && cp "$APP/java-maven/target/bom.json" "$M/java.combined.cdx.json"

log "sbom-plus-maven-plugin (java): one whole-build SBOM, scopes via CycloneDX scope labels"
B="$OUT/sbom-plus-maven-plugin"; mkdir -p "$B"
mvn -q -B -f "$P" dev.noregressions:sbom-plus-maven-plugin:1.0.0:scan \
  -DsbomPlus.sbomOutputFile="$B/java.combined.cdx.json" -DsbomPlus.outputFile="$B/java.report.json"
# The plugin emits a single document covering dependencies AND build plugins, labelling what ships as scope=required and
# everything else (test deps, build tooling) as scope=excluded. Runtime / non-runtime are derived from those labels:
jq '.components |= map(select(.scope == "required"))' "$B/java.combined.cdx.json" > "$B/java.runtime.cdx.json"
jq '.components |= map(select(.scope == "excluded"))' "$B/java.combined.cdx.json" > "$B/java.nonruntime.cdx.json"

log "cyclonedx-gradle-plugin (java): choose resolved configurations"
G="$OUT/cyclonedx-gradle-plugin"; mkdir -p "$G"
( cd "$APP/java-gradle" && gradle -q --no-daemon cyclonedxBom -PsbomConfigs=runtimeClasspath -PsbomOutput=bom-runtime \
  && gradle -q --no-daemon cyclonedxBom -PsbomConfigs=testRuntimeClasspath -PsbomOutput=bom-combined )
cp "$APP/java-gradle/build/reports/bom-runtime.json" "$G/java.runtime.cdx.json"
cp "$APP/java-gradle/build/reports/bom-combined.json" "$G/java.combined.cdx.json"
# nonruntime: Gradle has no "test-only" configuration -> derived

log "cyclonedx-npm (node): --omit dev"
N="$OUT/cyclonedx-npm"; mkdir -p "$N"
cyclonedx-npm --omit dev --output-format JSON --output-file "$N/node.runtime.cdx.json" "$APP/node/package.json"
cyclonedx-npm --output-format JSON --output-file "$N/node.combined.cdx.json" "$APP/node/package.json"
# nonruntime: npm has no "only dev" -> derived

log "cyclonedx-py (python): one requirements file per scope"
Y="$OUT/cyclonedx-python"; mkdir -p "$Y"
cyclonedx-py requirements "$APP/python/requirements.txt"     --of JSON -o "$Y/python.runtime.cdx.json"
cyclonedx-py requirements "$APP/python/requirements-dev.txt" --of JSON -o "$Y/python.nonruntime.cdx.json"
cat "$APP/python/requirements.txt" "$APP/python/requirements-dev.txt" | cyclonedx-py requirements - --of JSON -o "$Y/python.combined.cdx.json"
# bonus: the installed environment (runtime + dev extras, with transitives) as a second "combined"
cyclonedx-py environment "$APP/python/.venv/bin/python" --of JSON -o "$Y/python.combined-environment.cdx.json"

log "cyclonedx-gomod (go): mod vs mod -test"
O="$OUT/cyclonedx-gomod"; mkdir -p "$O"
cyclonedx-gomod mod -json -output "$O/go.runtime.cdx.json" "$APP/go" 2>/dev/null
cyclonedx-gomod mod -json -test -output "$O/go.combined.cdx.json" "$APP/go" 2>/dev/null
# nonruntime: derived

log "cargo-cyclonedx (rust): no dev-dependency switch at all"
R="$OUT/cargo-cyclonedx"; mkdir -p "$R"
cargo cyclonedx -q --manifest-path "$APP/rust/Cargo.toml" -f json && mv "$APP"/rust/*.cdx.json "$R/rust.runtime.cdx.json"
# combined/nonruntime: not expressible (dev-dependencies are always excluded)

log "cdxgen (node, java, python): --required-only"
C="$OUT/cdxgen"; mkdir -p "$C"
for eco in node:npm java-maven:java python:python; do d="${eco%%:*}"; t="${eco##*:}"; name="${d%%-*}"
  cdxgen -t "$t" --required-only -o "$C/$name.runtime.cdx.json"  "$APP/$d" >/dev/null 2>&1
  cdxgen -t "$t"                 -o "$C/$name.combined.cdx.json" "$APP/$d" >/dev/null 2>&1
done
# nonruntime: derived

log "trivy (node): --include-dev-deps"
T="$OUT/trivy"; mkdir -p "$T"
trivy fs -q --format cyclonedx --output "$T/node.runtime.cdx.json" "$APP/node"
trivy fs -q --include-dev-deps --format cyclonedx --output "$T/node.combined.cdx.json" "$APP/node"
# nonruntime: derived

log "syft (node): a scanner has no scope flag; scope = what you point it at"
S="$OUT/syft"; mkdir -p "$S"
TMP="$(mktemp -d)"; cp "$APP/node/package.json" "$APP/node/package-lock.json" "$APP/node/index.js" "$TMP/"
( cd "$TMP" && npm ci --omit=dev --ignore-scripts --no-audit --no-fund >/dev/null 2>&1 )
syft scan -q "dir:$TMP" -o cyclonedx-json="$S/node.runtime.cdx.json"
syft scan -q "dir:$APP/node" -o cyclonedx-json="$S/node.combined.cdx.json"
rm -rf "$TMP"
# nonruntime: derived

log "compare"
python3 "$ROOT/scope-runs/compare.py" "$OUT" > "$ROOT/scope-runs/RESULTS.md" && cat "$ROOT/scope-runs/RESULTS.md"
