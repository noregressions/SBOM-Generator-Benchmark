# Sourced by scripts/evaluate and scripts/scan (needs ROOT; honours REBUILD_IMAGE=1 and BENCHMARK_IMAGE).
# Makes sure the tool image exists and matches tools/versions.env, then sets:
#   IMAGE   the image tag
#   RUN     the `docker run` prefix every command in the image shares
IMAGE="${BENCHMARK_IMAGE:-sbom-generator-benchmark:local}"
docker info >/dev/null 2>&1 || { echo "Docker is not running" >&2; exit 1; }

# The image is labelled with a digest of versions.env + Dockerfile, so a version bump is noticed without being asked.
_want=$(cat "$ROOT/tools/versions.env" "$ROOT/image/Dockerfile" | shasum -a 256 | cut -c1-16)
_have=$(docker image inspect -f '{{ index .Config.Labels "benchmark.inputs" }}' "$IMAGE" 2>/dev/null || true)
if [[ "${REBUILD_IMAGE:-0}" == 1 || "$_have" != "$_want" ]]; then
  echo "== building $IMAGE from tools/versions.env"
  _args=(); while IFS='=' read -r k v; do [[ "$k" =~ ^[A-Z0-9_]+$ ]] && _args+=(--build-arg "$k=$v"); done < "$ROOT/tools/versions.env"
  docker build "${_args[@]}" --label "benchmark.inputs=$_want" -t "$IMAGE" "$ROOT/image"
fi

# The Docker socket lets the image stage build and read images through the host's daemon. Maven's repository and the
# scanners' databases live in named volumes so they survive between runs.
RUN=(docker run --rm
     -v /var/run/docker.sock:/var/run/docker.sock
     -v sbom-benchmark-m2:/root/.m2 -v sbom-benchmark-cache:/root/.cache
     -e DOCKER_SCOUT_HUB_USER -e DOCKER_SCOUT_HUB_PASSWORD
     -e BENCHMARK_IMAGE_ID="$(docker image inspect -f '{{.Id}}' "$IMAGE")")
# SBOM+ comes from Maven Central like every other Maven plugin. To evaluate a build that is not published yet, set
# SBOM_PLUS_LOCAL=1: the copy in your ~/.m2 is then made visible to Maven inside the image (read-only), and the report
# says that an unpublished build was used.
_plus="$HOME/.m2/repository/dev/noregressions/sbom-plus-maven-plugin"
if [[ "${SBOM_PLUS_LOCAL:-0}" == 1 ]]; then
  [[ -d "$_plus" ]] || { echo "SBOM_PLUS_LOCAL=1 but there is no SBOM+ in $_plus" >&2; exit 1; }
  RUN+=(-v "$_plus:/root/.m2/repository/dev/noregressions/sbom-plus-maven-plugin:ro" -e SBOM_PLUS_LOCAL=1)
  echo "== note: using the LOCAL SBOM+ build from $_plus (the report will say so)"
fi
