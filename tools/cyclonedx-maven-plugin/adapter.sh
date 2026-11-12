#!/usr/bin/env bash
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
# CycloneDX Maven plugin: source stage of Maven test cases. Runs in the real tree, because the build has to resolve.
[[ "$EV_STAGE" == source ]] || na
mode=$(ex .stages.source.maven); [[ -n "$mode" ]] || na
[[ "$mode" == aggregate ]] && goal=makeAggregateBom || goal=makeBom
mvnq "$CYCLONEDX_MAVEN_PLUGIN:$goal" -DoutputFormat=json -DoutputName=criteria-bom -DincludeTestScope=false || exit 1
cp "$EV_PROJECT/target/criteria-bom.json" "$EV_OUT/cyclonedx-maven-plugin.cdx.json"
