#!/usr/bin/env bash
# Build test cases so that every stage has something to scan. Each testcases/<name>/expected.json names its own build
# command ("build", relative to project/); this script only finds and runs it.
#
#   testcases/build.sh                # every test case
#   testcases/build.sh spring-node    # one
set -uo pipefail
CASES="$(cd "$(dirname "$0")" && pwd)"
if [[ $# -gt 0 ]]; then NAMES=("$@"); else NAMES=($(cd "$CASES" && ls -d */ | tr -d /)); fi
failed=()
for n in "${NAMES[@]}"; do
  e="$CASES/$n/expected.json"; [[ -f "$e" ]] || { echo "no such test case: $n" >&2; failed+=("$n"); continue; }
  cmd=$(jq -r '.build // empty' "$e")
  [[ -n "$cmd" ]] || { echo "== $n: no build step"; continue; }
  echo "== $n: $cmd"
  (cd "$CASES/$n/project" && bash -c "$cmd") || failed+=("$n")
done
echo; echo "Build failures: ${failed[*]:-none}"
[[ ${#failed[@]} -eq 0 ]]
