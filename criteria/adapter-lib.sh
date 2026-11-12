# Sourced by every tools/<tool>/adapter.sh. The runner (criteria/generate.sh) calls an adapter once per test case and
# stage with these variables set:
#
#   EV_STAGE     source | artefact | image
#   EV_KIND      source: dir   artefact: jar | war | dir | venv   image: image
#   EV_INPUT     what to scan: a clean copy of the checkout (source), the built artefact's path, or the image tag
#   EV_PROJECT   the real project directory (testcases/<name>/project), for tools that have to run the build
#   EV_EXPECTED  the test case's expected.json
#   EV_TARGET    the test case's name
#   EV_OUT       where to write: $EV_OUT/<tool>.cdx.json or $EV_OUT/<tool>.spdx.json
#   EV_TMP       scratch space, emptied for each adapter
#
# An adapter exits 0 when it wrote its document, non-zero when it failed, and calls `na` when it does not apply to
# this stage, kind or test case (or the tool is not installed). Versions come from tools/versions.env.
set -uo pipefail
set -a; . "$(dirname "${BASH_SOURCE[0]}")/../tools/versions.env"; set +a
export FETCH_LICENSE=false

na()   { exit 3; }                                           # not applicable here; the runner skips it silently
need() { command -v "$1" >/dev/null 2>&1 || na; }            # tool not installed: skip rather than fail
ex()   { jq -r "$1 // empty" "$EV_EXPECTED"; }               # read a field of expected.json, empty if absent

# A test case may keep its own Maven repository (maven_repo_local); every Maven invocation has to use it.
MVN_LOCAL=(); _repo=$(ex .maven_repo_local)
[[ -n "$_repo" ]] && MVN_LOCAL=(-Dmaven.repo.local="$EV_PROJECT/$_repo")
export MVN_ARGS="${MVN_LOCAL[*]:-}"                          # cdxgen and ORT honour this when they shell out to mvn
mvnq() { mvn -q -B -f "$EV_PROJECT/pom.xml" ${MVN_LOCAL[@]+"${MVN_LOCAL[@]}"} "$@"; }
