#!/usr/bin/env bash
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
# SBOM+: source stage of Maven test cases. Runs in the real tree, because the build has to resolve.
[[ "$EV_STAGE" == source ]] || na
mode=$(ex .stages.source.maven); [[ -n "$mode" ]] || na
[[ "$mode" == aggregate ]] && goal=scan-aggregate || goal=scan
# A test case with its own Maven repository keeps its own copy of the plugin, which must be the same build the other
# test cases use. Normally that is the published one, so any earlier copy is removed and Maven fetches it from Central.
# With SBOM_PLUS_LOCAL=1 the local build is copied in instead (Maven would otherwise fetch the published one here only).
repo=$(ex .maven_repo_local); dir="dev/noregressions/sbom-plus-maven-plugin/${SBOM_PLUS_MAVEN_PLUGIN##*:}"
if [[ -n "$repo" ]]; then
  rm -rf "$EV_PROJECT/$repo/$dir"
  if [[ "${SBOM_PLUS_LOCAL:-0}" == 1 && -d "$HOME/.m2/repository/$dir" ]]; then
    mkdir -p "$EV_PROJECT/$repo/$dir" && rsync -a "$HOME/.m2/repository/$dir/" "$EV_PROJECT/$repo/$dir/"
  fi
fi
# author: the test-case POMs declare no organization, and BSI wants a contact (the same role as sbom-tool's -ps/-nsb)
mvnq "$SBOM_PLUS_MAVEN_PLUGIN:$goal" \
  -DsbomPlus.sbomOutputFile="$EV_OUT/sbom-plus-maven-plugin.cdx.json" -DsbomPlus.outputFile="$EV_OUT/sbom-plus-maven-plugin.report.json" \
  -DsbomPlus.author=criteria -DsbomPlus.authorEmail=criteria@example.com
