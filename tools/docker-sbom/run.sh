#!/usr/bin/env bash
# docker sbom / docker scout — SBOMs built into the Docker CLI. `docker sbom` is a Syft-powered plugin; `docker scout sbom` is Docker's
# newer (free-tier) analyser. Both need a running Docker daemon.   |   https://docs.docker.com/scout/how-tos/view-create-sboms/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/docker-sbom/output"; mkdir -p "$OUT"
IMG=sbom-sample:local

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon is not running. Start Docker Desktop (or colima) and re-run. Nothing generated."; exit 0
fi

echo "== 0. Build the sample image from sample-app/Dockerfile"
docker build -q -t "$IMG" "$ROOT/sample-app" >/dev/null

echo "== 1. docker scout sbom (built into Docker Desktop) -> SPDX JSON and a human list"
docker scout sbom --format spdx  --output "$OUT/sbom-sample.scout.spdx.json" "$IMG"
docker scout sbom --format list "$IMG" | head -30

echo "== 2. docker scout quickview + cves straight from the image (consumes its own SBOM; needs 'docker login', free Docker ID)"
docker scout quickview "$IMG" 2>&1 | tee "$OUT/scout-quickview.txt" | grep -v -E '^\s*(i |\.\.\.|✓)' | head -20 || true
docker scout cves --only-severity critical,high "$IMG" > "$OUT/scout-cves-high.txt" 2>&1 || true
grep -v -E '^\s*(i |\.\.\.|✓)' "$OUT/scout-cves-high.txt" | head -20

echo "== 3. docker sbom plugin (Syft under the hood) -> CycloneDX JSON, if the plugin is installed"
if docker info --format '{{json .ClientInfo.Plugins}}' 2>/dev/null | grep -q '"Name":"sbom"'; then
  docker sbom --format cyclonedx-json --output "$OUT/sbom-sample.docker-sbom.cdx.json" "$IMG"
else
  echo "(docker sbom plugin not installed: https://github.com/docker/sbom-cli-plugin)"
fi

echo "== 4. BuildKit attestations: generate the SBOM *at build time* and attach it to the image"
# Attestations need the docker-container driver and the image must be pushed or kept in the build cache; we use a local
# registry-free path: build to an OCI tarball and read the attestation manifest out of it.
docker buildx inspect sbom-demo >/dev/null 2>&1 || docker buildx create --name sbom-demo --driver docker-container >/dev/null
if docker buildx build --builder sbom-demo --sbom=true --provenance=true -t "$IMG-attested" \
     --output "type=oci,dest=$OUT/attested-image.oci.tar" "$ROOT/sample-app" >/dev/null 2>&1; then
  mkdir -p "$OUT/oci" && tar -xf "$OUT/attested-image.oci.tar" -C "$OUT/oci"
  # find the in-toto SPDX predicate among the blobs
  for b in "$OUT"/oci/blobs/sha256/*; do
    if grep -q '"predicateType":"https://spdx.dev/Document"' "$b" 2>/dev/null; then
      jq '.predicate' "$b" > "$OUT/buildkit-attestation.spdx.json"; break
    fi
  done
  rm -rf "$OUT/oci" "$OUT/attested-image.oci.tar"
  jq '{spdxVersion, packages: (.packages|length), creator: .creationInfo.creators}' "$OUT/buildkit-attestation.spdx.json"
else
  echo "(buildx attestation build failed)"
fi
echo "Done. Outputs in $OUT"
