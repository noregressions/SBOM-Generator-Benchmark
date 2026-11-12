# Trivy

**What it is.** Aqua Security's all-in-one scanner. Vulnerabilities, misconfigurations and secrets are its headline features,
but `--format cyclonedx|spdx|spdx-json` turns any scan into an SBOM, and `trivy sbom` scans an SBOM you already have.

**Install.** `brew install trivy` · [github.com/aquasecurity/trivy](https://github.com/aquasecurity/trivy) · Apache-2.0 · tested with 0.74.0

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1-2 | `trivy fs` over the source tree, emitting CycloneDX JSON, SPDX JSON and SPDX tag-value |
| 3 | `trivy image` on `python:3.12-slim` pulled from the registry (no daemon), CycloneDX with OS and pip packages |
| 4 | `trivy sbom <file>`: **consume** the CycloneDX document and report CVEs per package |
| 5 | A plain JSON report with `--list-all-pkgs` to see exactly what Trivy's analysers detected |

## What we saw

- 120 components from the tree. Fewer than Syft (198) because Trivy **suppresses dev/test dependencies by default**
  (use `--include-dev-deps` to keep them) and skips some file types.
- Scanning its own SBOM reproduced the same advisories as scanning the source, which is the point: an SBOM is a
  sufficient input for ongoing vulnerability monitoring.
- Secret scanning runs by default on `fs` scans and slows things down; add `--scanners vuln` or `--scanners none` for pure SBOM runs.

## Strengths / limits

- Strengths: one binary for SBOM plus scanning, excellent image/OS package coverage, Kubernetes and IaC awareness, huge adoption in CI.
- Limits: SBOM generation is secondary to scanning, so output is less rich (fewer hashes/licences) than dedicated generators.
  Pin and verify releases: the project's distribution channel was reportedly compromised in early 2026.
