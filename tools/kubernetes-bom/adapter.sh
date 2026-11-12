#!/usr/bin/env bash
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
# Kubernetes bom: built archives. (It reads images from a registry only, not the local daemon, so not the image stage.) SPDX output.
case "$EV_KIND" in jar|war) ;; *) na ;; esac
need bom
bom generate --file "$EV_INPUT" --name "$EV_TARGET" --namespace "https://example.com/criteria/$EV_TARGET" --format json --output "$EV_OUT/bom.spdx.json"
