#!/usr/bin/env bash
# cdxgen (OWASP CycloneDX Generator) — the CycloneDX project's own multi-ecosystem generator.
# Install: brew install cdxgen   or   npm i -g @cyclonedx/cdxgen   |   https://github.com/CycloneDX/cdxgen
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/cdxgen/output"; mkdir -p "$OUT"
APP="$ROOT/sample-app"
export FETCH_LICENSE=false   # avoid network round-trips to registries for licence lookups in a demo

echo "== 1. Whole tree, recursive, all ecosystems auto-detected -> CycloneDX 1.6 JSON"
cdxgen -r -o "$OUT/sample-app.cdx.json" --spec-version 1.6 "$APP"

echo "== 2. One ecosystem at a time with -t (shows the per-language analysers)"
cdxgen -t java   -o "$OUT/java-maven.cdx.json" "$APP/java-maven"
cdxgen -t npm    -o "$OUT/node.cdx.json"       "$APP/node"
cdxgen -t python -o "$OUT/python.cdx.json"     "$APP/python"
cdxgen -t go     -o "$OUT/go.cdx.json"         "$APP/go"
cdxgen -t rust   -o "$OUT/rust.cdx.json"       "$APP/rust"

echo "== 3. Deep mode + evidence: records *where* each component was found (occurrences / callstack)"
cdxgen -t npm --deep --evidence -o "$OUT/node.deep-evidence.cdx.json" "$APP/node"

echo "== 4. Only required (runtime) dependencies, dropping dev/test scope"
cdxgen -t npm --required-only -o "$OUT/node.required-only.cdx.json" "$APP/node"

echo "== 5. Container image (cdxgen needs a running Docker/Podman daemon for this, unlike Syft/Trivy)"
if docker info >/dev/null 2>&1; then cdxgen -t docker -o "$OUT/python-3.12-slim.cdx.json" python:3.12-slim; else echo "(skipped: Docker daemon not running)"; fi

echo "Done. Outputs in $OUT"
