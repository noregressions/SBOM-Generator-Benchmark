#!/usr/bin/env bash
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
# Trivy: every stage. It reports nothing for a raw jar/war, so archives are scanned twice: unzipped (trivy.cdx.json,
# the fair reading) and as the raw file (trivy-rawfile.cdx.json, what you get if you do not know that).
need trivy
case "$EV_KIND" in
  image)   trivy image -q --format cyclonedx --output "$EV_OUT/trivy.cdx.json" "$EV_INPUT" ;;
  jar|war) unzip -q -o "$EV_INPUT" -d "$EV_TMP/x"
           trivy rootfs -q --format cyclonedx --output "$EV_OUT/trivy.cdx.json" "$EV_TMP/x"; rc=$?
           trivy fs -q --format cyclonedx --output "$EV_OUT/trivy-rawfile.cdx.json" "$EV_INPUT" || rc=$?
           exit $rc ;;
  binary)  mkdir -p "$EV_TMP/b" && cp "$EV_INPUT" "$EV_TMP/b/"      # trivy reads Go binaries it finds in a filesystem
           trivy rootfs -q --format cyclonedx --output "$EV_OUT/trivy.cdx.json" "$EV_TMP/b" ;;
  *)       trivy fs -q --format cyclonedx --output "$EV_OUT/trivy.cdx.json" "$EV_INPUT" ;;
esac
