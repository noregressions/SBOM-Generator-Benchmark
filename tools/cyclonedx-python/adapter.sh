#!/usr/bin/env bash
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
# cyclonedx-py: the requirements file at source stage, the installed environment at artefact stage.
need cyclonedx-py
if [[ "$EV_STAGE" == source ]]; then
  req=$(ex .stages.source.python); [[ -n "$req" ]] || na
  cyclonedx-py requirements "$EV_INPUT/$req" --mc-type application -o "$EV_OUT/cyclonedx-python.cdx.json"
elif [[ "$EV_KIND" == venv ]]; then
  cyclonedx-py environment "$EV_INPUT/bin/python" --mc-type application -o "$EV_OUT/cyclonedx-python.cdx.json"
else na; fi
