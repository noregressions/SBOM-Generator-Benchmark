#!/usr/bin/env bash
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
# Microsoft sbom-tool: source stage only (it describes a build drop from its manifests). SPDX output.
[[ "$EV_STAGE" == source ]] || na
need sbom-tool
mkdir -p "$EV_TMP/st"
sbom-tool generate -b "$EV_INPUT" -bc "$EV_INPUT" -pn "$EV_TARGET" -pv 1.0.0 -ps criteria -nsb https://example.com/criteria -m "$EV_TMP/st" -D true || exit 1
f=$(find "$EV_TMP/st" -name manifest.spdx.json | head -1)
[[ -n "$f" ]] && cp "$f" "$EV_OUT/sbom-tool.spdx.json"
