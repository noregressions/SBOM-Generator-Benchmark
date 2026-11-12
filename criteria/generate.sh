#!/usr/bin/env bash
# Generate SBOMs for every test case at every stage it defines (source tree, built artefact, container image) with
# every tool that can read that stage. Outputs land in criteria/output/<test case>/<stage>/<tool>.{cdx,spdx}.json.
#
# This script knows nothing about individual tools or test cases:
#   testcases/<name>/      project/ is the code, expected.json the ground truth and stage definitions
#   tools/<tool>/adapter.sh   how one tool is run; see criteria/adapter-lib.sh for the contract
# A test case whose artefact is missing is built first with testcases/build.sh (CRITERIA_BUILD=1 forces a rebuild of
# every test case, CRITERIA_BUILD=0 never builds).
#
#   ./criteria/generate.sh                 # all test cases in testcases/
#   ./criteria/generate.sh spring-node     # one test case
#   CRITERIA_ORT=1 CRITERIA_SCANCODE=1 ./criteria/generate.sh   # also run the slow tools
#   CRITERIA_STAGES="source artefact" ./criteria/generate.sh    # skip the image stage (no Docker)
#   CRITERIA_TOOLS="sbom-plus-maven-plugin" ./criteria/generate.sh   # re-run one tool (folder name under tools/), keep the other outputs
#
# Normally run through ./evaluate, which does this inside the canonical tool image.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRIT="$ROOT/criteria"
OUT="${CRITERIA_OUT:-$CRIT/output}"; CASES="${CRITERIA_CASES:-$ROOT/testcases}"   # overridden by ./scan to point at an arbitrary tree
TMP="${TMPDIR:-/tmp}/criteria-$$"; mkdir -p "$TMP"; trap 'rm -rf "$TMP"' EXIT

log(){ printf '\n== %s\n' "$*"; }
fresh(){ [[ -z "${CRITERIA_TOOLS:-}" ]] && rm -rf "$1"; mkdir -p "$1"; }   # with a tool filter, keep the other tools' outputs
want(){ [[ -z "${CRITERIA_STAGES:-}" || " ${CRITERIA_STAGES} " == *" $1 "* ]]; }   # CRITERIA_STAGES="source image" to limit
adapters(){ # adapters <stage> <kind> <input> <outdir> : run every tool adapter; one failing never aborts the run
  local a tool rc
  for a in "$ROOT"/tools/*/adapter.sh; do
    tool=$(basename "$(dirname "$a")")
    if [[ -n "${CRITERIA_TOOLS:-}" && " ${CRITERIA_TOOLS} " != *" $tool "* ]]; then continue; fi
    rm -rf "$TMP/a"; mkdir -p "$TMP/a"
    EV_STAGE="$1" EV_KIND="$2" EV_INPUT="$3" EV_OUT="$4" EV_TARGET="$T" EV_PROJECT="$S" EV_EXPECTED="$E" EV_TMP="$TMP/a" \
      "$a" >"$TMP/log" 2>&1; rc=$?
    case $rc in
      0) printf '   %-28s ok\n' "$tool" ;;
      3) ;;                                   # not applicable to this stage/kind/test case
      *) printf '   %-28s FAILED (%s)\n' "$tool" "$(tail -1 "$TMP/log" | cut -c1-120)"; FAILED+=("$T/$1/$tool") ;;
    esac
  done
}

if [[ $# -gt 0 ]]; then TARGETS=("$@"); else TARGETS=($(cd "$CASES" && ls -d */ | tr -d /)); fi
FAILED=()

for T in "${TARGETS[@]}"; do
  E="$CASES/$T/expected.json"; [[ -f "$E" ]] || { echo "no expected.json for $T" >&2; continue; }
  S="$CASES/$T/project"
  log "TEST CASE $T"
  art=$(jq -r '.stages.artefact.path // empty' "$E")
  if [[ "${CRITERIA_BUILD:-auto}" == 1 || ( "${CRITERIA_BUILD:-auto}" == auto && -n "$art" && ! -e "$S/$art" ) ]]; then
    if "$CASES/build.sh" "$T" >"$TMP/build.log" 2>&1; then echo "   built"; else echo "   BUILD FAILED (see below)"; tail -15 "$TMP/build.log"; FAILED+=("$T build"); fi
  fi

  # ---------------------------------------------------------------- source
  # Build outputs and dependency caches inside the tree (target/, .maven-repo/, .venv/) belong to later stages, so
  # scanners get a scratch copy with the test case's `exclude` paths removed: "source" means the checkout, not the
  # checkout plus everything the build produced. (Per-tool exclude flags were tried first; they behave differently per
  # tool and Syft's only matched at the top level, so the copy is the fair, uniform route.) Build plugins use
  # EV_PROJECT, the real tree, because the build must resolve.
  if want source; then
    SRC="$S/$(jq -r .stages.source.path "$E")"; O="$OUT/$T/source"; fresh "$O"
    echo "-- source stage"
    rm -rf "$TMP/src"; RS=(-a --exclude .git)
    for g in $(jq -r '.stages.source.exclude[]? ' "$E"); do RS+=(--exclude "$g"); done   # anchored paths, e.g. /frontend/dist
    rsync "${RS[@]}" "$SRC/" "$TMP/src/"
    adapters source dir "$TMP/src" "$O"
  fi

  # ---------------------------------------------------------------- artefact
  if [[ -n "$art" ]] && want artefact; then
    A="$S/$art"; kind=$(jq -r .stages.artefact.kind "$E"); O="$OUT/$T/artefact"; fresh "$O"
    echo "-- artefact stage ($kind): $art"
    if [[ ! -e "$A" ]]; then echo "   MISSING: build the test case first (testcases/build.sh $T)"; FAILED+=("$T artefact missing")
    else adapters artefact "$kind" "$A" "$O"; fi
  fi

  # ---------------------------------------------------------------- image
  tag=$(jq -r '.stages.image.tag // empty' "$E")
  if [[ -n "$tag" ]] && want image; then
    O="$OUT/$T/image"; fresh "$O"
    echo "-- image stage: $tag"
    if ! docker info >/dev/null 2>&1; then echo "   Docker not running; skipping"; FAILED+=("$T image (no docker)")
    else
      df=$(jq -r '.stages.image.dockerfile // empty' "$E")     # no dockerfile: the image already exists under that tag
      if [[ -n "$df" ]] && ! docker build -q -f "$S/$df" -t "$tag" "$S/$(jq -r .stages.image.context "$E")" >"$TMP/log" 2>&1; then
        echo "   docker build FAILED ($(tail -1 "$TMP/log" | cut -c1-120))"; FAILED+=("$T image build")
      else adapters image image "$tag" "$O"; fi
    fi
  fi
done

echo; echo "Outputs: $OUT"; echo "Failed steps: ${FAILED[*]:-none}"
