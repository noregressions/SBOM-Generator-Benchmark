#!/usr/bin/env bash
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
# Docker Scout: image stage. SPDX output.
[[ "$EV_STAGE" == image ]] || na
docker scout version >/dev/null 2>&1 || na
docker scout sbom --format spdx --output "$EV_OUT/docker-scout.spdx.json" "$EV_INPUT"
