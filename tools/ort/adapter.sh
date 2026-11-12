#!/usr/bin/env bash
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
# ORT: source stage, opt-in because it is slow (CRITERIA_ORT=1). Runs ORT's own container, so the paths it mounts must
# exist on the Docker host: use it from a host run, not from inside the tool image.
[[ "$EV_STAGE" == source && "${CRITERIA_ORT:-0}" == 1 ]] || na
need docker
rm -rf "$EV_OUT/ort"; mkdir -p "$EV_OUT/ort"
docker run --rm -v "$EV_INPUT:/project" -v "$EV_OUT/ort:/out" ghcr.io/oss-review-toolkit/ort:latest analyze -i /project -o /out/analyzer
docker run --rm -v "$EV_OUT/ort:/out" ghcr.io/oss-review-toolkit/ort:latest report -i /out/analyzer/analyzer-result.json -o /out/reports -f CycloneDx || exit 1
f=$(find "$EV_OUT/ort/reports" -name '*.json' 2>/dev/null | head -1)
[[ -n "$f" ]] && cp "$f" "$EV_OUT/ort.cdx.json"
