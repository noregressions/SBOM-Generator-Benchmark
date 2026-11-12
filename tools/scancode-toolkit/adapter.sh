#!/usr/bin/env bash
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
# ScanCode: source stage, opt-in because it is slow (CRITERIA_SCANCODE=1). Not in the tool image.
[[ "$EV_STAGE" == source && "${CRITERIA_SCANCODE:-0}" == 1 ]] || na
need scancode
PYTHONWARNINGS=ignore scancode -n 4 --package --strip-root --quiet --json-pp "$EV_OUT/scancode.json" --cyclonedx "$EV_OUT/scancode.cdx.json" "$EV_INPUT"
