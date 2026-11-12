#!/usr/bin/env bash
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
# SBOM+: source stage of Maven test cases. Runs in the real tree, because the build has to resolve.
[[ "$EV_STAGE" == source ]] || na
mode=$(ex .stages.source.maven); [[ -n "$mode" ]] || na
[[ "$mode" == aggregate ]] && goal=scan-aggregate || goal=scan
# A test case with its own Maven repository cannot see a locally built SBOM+ in ~/.m2; copy it across so the same
# plugin build is evaluated everywhere (otherwise Maven silently fetches the published one for that test case only).
repo=$(ex .maven_repo_local); dir="dev/noregressions/sbom-plus-maven-plugin/${SBOM_PLUS_MAVEN_PLUGIN##*:}"
if [[ -n "$repo" && -d "$HOME/.m2/repository/$dir" ]]; then
  mkdir -p "$EV_PROJECT/$repo/$dir" && rsync -a --delete "$HOME/.m2/repository/$dir/" "$EV_PROJECT/$repo/$dir/"
fi
# author: the test-case POMs declare no organization, and BSI wants a contact (the same role as sbom-tool's -ps/-nsb)
mvnq "$SBOM_PLUS_MAVEN_PLUGIN:$goal" \
  -DsbomPlus.sbomOutputFile="$EV_OUT/sbom-plus-maven-plugin.cdx.json" -DsbomPlus.outputFile="$EV_OUT/sbom-plus-maven-plugin.report.json" \
  -DsbomPlus.author=criteria -DsbomPlus.authorEmail=criteria@example.com
