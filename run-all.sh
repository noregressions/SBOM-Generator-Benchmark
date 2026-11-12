#!/usr/bin/env bash
# Run every tool demo in sequence. Each tools/<name>/run.sh is independent, except cyclonedx-cli and sbomqs,
# which consume the other tools' outputs and therefore run last.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
ORDER=(syft trivy cdxgen cyclonedx-maven-plugin sbom-plus-maven-plugin cyclonedx-gradle-plugin cyclonedx-npm cyclonedx-python cyclonedx-gomod
       cargo-cyclonedx cyclonedx-dotnet spdx-sbom-generator microsoft-sbom-tool kubernetes-bom sbom4python scancode-toolkit
       jbom github-dependency-graph docker-sbom ort cyclonedx-cli sbomqs)
pass=(); fail=()
for t in "${ORDER[@]}"; do
  echo; echo "################ $t ################"
  if "$ROOT/tools/$t/run.sh"; then pass+=("$t"); else fail+=("$t"); fi
done
echo; echo "OK:     ${pass[*]}"; echo "FAILED: ${fail[*]:-none}"
echo; echo "Scope runs (scope-runs/) and the criteria scorecard (criteria/) are separate: ./scope-runs/run.sh and ./evaluate"
echo "./evaluate rebuilds COMPARISON.md from all three; after a scope run alone, use python3 compare-tools.py."
