#!/usr/bin/env bash
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
# Syft: every stage. Directories and images as they are, archives as a single file.
need syft
case "$EV_KIND" in
  jar|war|binary) src="file:$EV_INPUT" ;;
  image)   src="$EV_INPUT" ;;
  *)       src="dir:$EV_INPUT" ;;
esac
syft scan -q "$src" -o "cyclonedx-json=$EV_OUT/syft.cdx.json"
