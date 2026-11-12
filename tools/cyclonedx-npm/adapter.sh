#!/usr/bin/env bash
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
# cyclonedx-npm: source stage of test cases that name an npm directory.
[[ "$EV_STAGE" == source ]] || na
dir=$(ex .stages.source.npm); [[ -n "$dir" ]] || na
need cyclonedx-npm
cyclonedx-npm --output-format JSON --output-file "$EV_OUT/cyclonedx-npm.cdx.json" "$EV_INPUT/$dir/package.json"
