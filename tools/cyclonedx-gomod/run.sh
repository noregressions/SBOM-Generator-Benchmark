#!/usr/bin/env bash
# cyclonedx-gomod — CycloneDX's Go generator: module graph, application graph (build constraints evaluated), or a compiled binary.
# Install: brew install cyclonedx-gomod   or   go install github.com/CycloneDX/cyclonedx-gomod/cmd/cyclonedx-gomod@latest
# https://github.com/CycloneDX/cyclonedx-gomod
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/cyclonedx-gomod/output"; mkdir -p "$OUT"
PRJ="$ROOT/sample-app/go"

echo "== 1. mod: every module the go.mod could pull in, with licence detection"
cyclonedx-gomod mod -json -licenses -output "$OUT/go.mod.cdx.json" "$PRJ"

echo "== 2. app: only what is compiled into the binary, incl. the Go stdlib as a component"
# cyclonedx-gomod derives the main module's version from git (tags/commit). If this checkout has no commit yet,
# fall back to a scratch copy with a throwaway commit so the demo still runs.
if git -C "$PRJ" rev-parse HEAD >/dev/null 2>&1; then
  cyclonedx-gomod app -json -std -main . -output "$OUT/go.app.cdx.json" "$PRJ"
else
  echo "(no git commit in this repo yet; using a scratch copy with a throwaway commit so version detection works)"
  TMP="$(mktemp -d)"; cp -R "$PRJ"/. "$TMP"/; rm -f "$TMP/sbom-sample-go"
  ( cd "$TMP" && git init -q && git add -A && git -c user.name=demo -c user.email=demo@example.com commit -qm "demo" && git tag v1.0.0 )
  cyclonedx-gomod app -json -std -main . -output "$OUT/go.app.cdx.json" "$TMP"
  rm -rf "$TMP"
fi

echo "== 3. bin: SBOM recovered from an already-built binary's embedded build info (no source needed)"
( cd "$PRJ" && go build -o "$OUT/sbom-sample-go" . )
cyclonedx-gomod bin -json -output "$OUT/go.bin.cdx.json" "$OUT/sbom-sample-go"
rm -f "$OUT/sbom-sample-go"

for f in "$OUT"/*.json; do printf "%-20s components=%s\n" "$(basename "$f")" "$(jq '.components|length' "$f")"; done
echo "Done. Outputs in $OUT"
