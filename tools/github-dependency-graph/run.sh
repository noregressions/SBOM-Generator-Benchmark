#!/usr/bin/env bash
# GitHub Dependency Graph — GitHub generates an SPDX SBOM for any repo it indexes; export it via REST API / gh CLI (free on public repos).
# Install: brew install gh && gh auth login   |   https://docs.github.com/en/rest/dependency-graph/sboms
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/github-dependency-graph/output"; mkdir -p "$OUT"
REPO="${1:-CycloneDX/cyclonedx-maven-plugin}"   # pass owner/repo to export a different one; needs read access

echo "== 1. Export the SPDX SBOM GitHub already computed for $REPO"
gh api -H "Accept: application/vnd.github+json" "repos/$REPO/dependency-graph/sbom" --jq '.sbom' > "$OUT/$(echo "$REPO" | tr '/' '_').spdx.json"
jq '{name: .name, spdxVersion: .spdxVersion, creators: .creationInfo.creators, packages: (.packages|length)}' "$OUT/$(echo "$REPO" | tr '/' '_').spdx.json"

echo "== 2. What ecosystems did GitHub detect? (from package URLs)"
jq -r '[.packages[].externalRefs[]? | select(.referenceType=="purl") | .referenceLocator | split("/")[0]] | group_by(.) | map({(.[0]): length}) | add' \
  "$OUT/$(echo "$REPO" | tr '/' '_').spdx.json"

echo "== 3. Dependency *submission* API (for build-time graphs GitHub can't infer from manifests, e.g. Maven/Gradle resolved trees)"
cat <<'TXT'
  In CI, generate an SBOM with any CycloneDX/SPDX tool and push it with one of the official actions, e.g.
    - advanced-security/maven-dependency-submission-action   (Maven)
    - mikepenz/gradle-dependency-submission                  (Gradle)
    - advanced-security/spdx-dependency-submission-action    (any SPDX file)
  Then Dependabot alerts and this export cover transitive, *resolved* dependencies instead of manifest guesses.
  See .github/workflows/sbom.yml in this repo for a working example.
TXT
echo "Done. Outputs in $OUT"
