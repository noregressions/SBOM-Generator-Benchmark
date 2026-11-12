#!/usr/bin/env bash
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
# CaPyCLI (Siemens): source stage. It has one command per ecosystem, each reading a different input, so every command
# that applies to the test case is run and the component lists are joined into one document.
#   Maven       the output of `mvn dependency:list` (CaPyCLI's documented route; its pom.xml reader does not resolve)
#   JavaScript  package-lock.json
#   Python      requirements.txt
[[ "$EV_STAGE" == source ]] || na
need capycli
parts=()

if [[ -n "$(ex .stages.source.maven)" ]]; then
  # `compile` lets a multi-module build resolve its own modules; the scopes are left as Maven reports them
  mvnq compile dependency:list -DoutputFile="$EV_TMP/mvn-list.txt" -DappendOutput=true || exit 1
  capycli getdependencies mavenlist -i "$EV_TMP/mvn-list.txt" -o "$EV_TMP/maven.json" || exit 1
  parts+=("$EV_TMP/maven.json")
fi
dir=$(ex .stages.source.npm)
if [[ -n "$dir" && -f "$EV_INPUT/$dir/package-lock.json" ]]; then
  capycli getdependencies javascript -i "$EV_INPUT/$dir/package-lock.json" -o "$EV_TMP/npm.json" || exit 1
  parts+=("$EV_TMP/npm.json")
fi
req=$(ex .stages.source.python)
if [[ -n "$req" ]]; then
  capycli getdependencies python -i "$EV_INPUT/$req" -o "$EV_TMP/python.json" || exit 1
  parts+=("$EV_TMP/python.json")
fi

[[ ${#parts[@]} -gt 0 ]] || na
jq -s '.[0] + {components: (map(.components // []) | add)}' "${parts[@]}" > "$EV_OUT/capycli.cdx.json"
