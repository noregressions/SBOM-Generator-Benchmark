#!/usr/bin/env bash
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
# cdxgen: every stage except an installed Python environment.
need cdxgen
case "$EV_KIND" in
  jar|war) cdxgen -t jar -o "$EV_OUT/cdxgen.cdx.json" "$EV_INPUT" ;;
  image)   cdxgen -t docker -o "$EV_OUT/cdxgen.cdx.json" "$EV_INPUT" ;;
  venv)    na ;;
  *)       cdxgen -r -o "$EV_OUT/cdxgen.cdx.json" "$EV_INPUT" ;;
esac
