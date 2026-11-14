#!/usr/bin/env bash
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
# Kubernetes bom: Go source trees, built archives and Go binaries. (It reads images from a registry only, not the local daemon, so not the image stage.) SPDX output.
need bom
if [[ "$EV_STAGE" == source ]]; then
  dir=$(ex .stages.source.go); [[ -n "$dir" ]] || na          # at the source stage bom understands Go modules only
  bom generate --dirs "$EV_INPUT/$dir" --name "$EV_TARGET" --namespace "https://example.com/criteria/$EV_TARGET" --format json --output "$EV_OUT/bom.spdx.json"
  exit $?
fi
case "$EV_KIND" in jar|war|binary) ;; *) na ;; esac
bom generate --file "$EV_INPUT" --name "$EV_TARGET" --namespace "https://example.com/criteria/$EV_TARGET" --format json --output "$EV_OUT/bom.spdx.json"
