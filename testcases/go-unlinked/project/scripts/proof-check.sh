#!/usr/bin/env bash
# Assert what is, and is not, compiled into the release binary. The Go toolchain records the modules it linked inside
# the binary itself; `go version -m` reads that record back. This is the evidence the ground truth is written from.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -x bin/app ]] || { echo "bin/app is missing: run scripts/build.sh first" >&2; exit 1; }
info="$(go version -m bin/app)"
fail=0
linked()   { grep -q "dep[[:space:]]*$1[[:space:]]" <<<"$info" && echo "ok    linked:      $1" || { echo "FAIL  expected $1 to be linked"; fail=1; }; }
unlinked() { grep -q "dep[[:space:]]*$1[[:space:]]" <<<"$info" && { echo "FAIL  $1 is linked and should not be"; fail=1; } || echo "ok    not linked:  $1"; }
linked   github.com/google/uuid
linked   golang.org/x/text
unlinked gopkg.in/yaml.v3              # imported by the tests only
unlinked github.com/dgrijalva/jwt-go   # imported by debug.go, which needs -tags debug
unlinked golang.org/x/tools            # required by golang.org/x/text's go.mod; no package of it is imported
grep -q "^go.sum\|gopkg.in/yaml.v3" go.mod && echo "ok    go.mod still requires the unlinked modules"
exit $fail
