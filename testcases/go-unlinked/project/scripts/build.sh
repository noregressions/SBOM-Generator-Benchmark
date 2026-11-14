#!/usr/bin/env bash
# Build the release binary: static, no debug tag, no VCS stamp (so the result does not depend on the repository it sits in).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p bin
CGO_ENABLED=0 go build -trimpath -buildvcs=false -o bin/app ./cmd/app
echo "Built bin/app. Modules linked into it:"
go version -m bin/app | awk '$1 == "dep" || $1 == "mod" {print "  " $2, $3}'
