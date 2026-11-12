#!/usr/bin/env bash
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
# sbom4python: an installed Python environment.
[[ "$EV_KIND" == venv ]] || na
need sbom4python
req=$(ex .stages.source.python); [[ -n "$req" ]] || na
PATH="$EV_INPUT/bin:$PATH" sbom4python --python "$EV_INPUT/bin/python" --use-pip -r "$EV_PROJECT/$req" --sbom cyclonedx --format json -o "$EV_OUT/sbom4python.cdx.json"
