#!/usr/bin/env bash
# bom (Kubernetes SIG Release) — SPDX generator used to produce Kubernetes' own release SBOMs; dirs, files, images, archives.
# Install: brew install bom   or   go install sigs.k8s.io/bom/cmd/bom@latest   |   https://github.com/kubernetes-sigs/bom
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/kubernetes-bom/output"; mkdir -p "$OUT"
APP="$ROOT/sample-app"

echo "== 1. Directory with a Go module -> SPDX 2.3 JSON (resolves go.mod deps + licences)"
bom generate --dirs "$APP/go" --name sbom-sample-go --namespace https://example.com/sbom/go --format json --output "$OUT/go.spdx.json"

echo "== 2. Same, tag-value"
bom generate --dirs "$APP/go" --name sbom-sample-go --namespace https://example.com/sbom/go --format tag-value --output "$OUT/go.spdx"

echo "== 3. Container image from the registry (OS packages + layers), SPDX JSON"
bom generate --image python:3.12-slim --name python-3.12-slim --namespace https://example.com/sbom/img --format json --output "$OUT/python-3.12-slim.spdx.json"

echo "== 4. Single file with hashes (jar as an SPDX File)"
bom generate --file "$APP/java-maven/target/sbom-sample-maven-1.0.0.jar" --name maven-jar --namespace https://example.com/sbom/jar --format json --output "$OUT/maven-jar.spdx.json"

echo "== 5. Inspect: bom document outline (a built-in SPDX viewer)"
bom document outline "$OUT/go.spdx.json" | head -40

echo "== 6. Experimental SPDX 3.0.1 JSON-LD"
bom generate --dirs "$APP/go" --name sbom-sample-go --namespace https://example.com/sbom/go --format spdx3-json --output "$OUT/go.spdx3.jsonld" || echo "(spdx3 not available)"
echo "Done. Outputs in $OUT"
