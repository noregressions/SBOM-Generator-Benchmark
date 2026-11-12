#!/usr/bin/env bash
# Replace this machine's paths in generated demo output with neutral ones, so a commit does not publish your user name
# or directory layout. SBOM tools record the absolute path they scanned (as document names, namespaces, bom-refs and
# file ids), and the tool demos run on the host, so their output is full of them.
#
#   scripts/scrub-paths.sh                 # tools/*/output and scope-runs/output
#   scripts/scrub-paths.sh some/dir ...    # these directories instead
#   scripts/scrub-paths.sh --check         # change nothing; list files that still contain a local path, exit 1 if any
#
#   <repository root>  ->  /workspace          <home directory>  ->  /home/user
#
# scripts/run-all.sh and scope-runs/run.sh call this when they finish. Run it yourself after running a single demo.
# The benchmark's own output (criteria/output) is produced inside the tool image and contains no host paths.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
check=0; dirs=()
for a in "$@"; do if [[ "$a" == --check ]]; then check=1; else dirs+=("$a"); fi; done
if [[ ${#dirs[@]} -eq 0 ]]; then dirs=("$ROOT"/tools/*/output "$ROOT/scope-runs/output"); fi

# Some tools write the path without its leading slash, or build an identifier from it ("/" -> "-", "_" -> "C95").
root_bare="${ROOT#/}"; root_id="${root_bare//\//-}"; root_id="${root_id//_/C95}"
home_bare="${HOME#/}"; user="$(basename "$HOME")"

files=()
while IFS= read -r f; do files+=("$f"); done < <(grep -rIl -e "$ROOT" -e "$HOME" -e "$root_bare" -e "$root_id" "${dirs[@]}" 2>/dev/null || true)

if [[ $check == 1 ]]; then
  if [[ ${#files[@]} -gt 0 ]]; then printf 'local path in: %s\n' "${files[@]#"$ROOT"/}"; exit 1; fi
  echo "no local paths in the demo output"; exit 0
fi
[[ ${#files[@]} -gt 0 ]] || { echo "scrub-paths: nothing to change"; exit 0; }
R="$ROOT" H="$HOME" RB="$root_bare" RI="$root_id" HB="$home_bare" perl -pi -e '
  s/\Q$ENV{R}\E/\/workspace/g;  s/\Q$ENV{H}\E/\/home\/user/g;
  s/\Q$ENV{RI}\E/workspace/g;   s/\Q$ENV{RB}\E/workspace/g;  s/\Q$ENV{HB}\E/home\/user/g;' "${files[@]}"
echo "scrub-paths: rewrote local paths in ${#files[@]} files"
