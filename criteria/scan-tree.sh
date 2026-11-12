#!/usr/bin/env bash
# The in-image half of ./scan: treat the tree mounted at /tree as a one-off test case, run every adapter against it,
# and write the report into the tree. See ./scan for the options (passed here as SCAN_* variables).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="${SCAN_NAME:-tree}"; TREE="${SCAN_TREE:-/tree}"; REPORT="$TREE/${SCAN_OUT:-sbom-report}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/cases/$NAME" && ln -s "$TREE" "$W/cases/$NAME/project"

echo "== $NAME"
python3 "$HERE/tree_report.py" detect "$TREE" "$NAME" "$W/cases/$NAME/expected.json" || exit 1
CRITERIA_CASES="$W/cases" CRITERIA_OUT="$W/out" CRITERIA_BUILD=0 "$HERE/generate.sh" "$NAME" | grep -v '^Outputs:\|^== TEST CASE\|^$'

rm -rf "$REPORT/sboms"; mkdir -p "$REPORT/sboms"
[[ -d "$W/out/$NAME" ]] && cp -R "$W/out/$NAME/." "$REPORT/sboms/"
echo "-- report"
python3 "$HERE/tree_report.py" report "$W/cases/$NAME/expected.json" "$REPORT/sboms" "$REPORT"
