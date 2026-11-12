# spdx-sbom-generator

**What it is.** A Linux Foundation / OpenSBOM project that emits SPDX 2.2 (tag-value or JSON) from package-manager
manifests. One plugin per ecosystem (npm, yarn, pip/pyenv, Maven, Gradle, Go modules, Cargo, Composer, NuGet, Swift…).

**Install.** `brew install spdx-sbom-generator` · [github.com/opensbom-generator/spdx-sbom-generator](https://github.com/opensbom-generator/spdx-sbom-generator) · Apache-2.0

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1 | One run per project directory producing `bom-<plugin>.spdx` tag-value documents |
| 2 | `-f json` for the Go module |

## What we saw (this is the honest part)

| Project | Result |
|---|---|
| java-maven | OK (`bom-Java-Maven.spdx`) |
| go | OK |
| rust | OK |
| node | plugin ran but **wrote no file** |
| python | `Unable to fetch package details` |
| java-gradle | `No module manager found` (looks for a Groovy `build.gradle`, not `build.gradle.kts`) |

Pointing it at the top-level directory fails with `No module manager found`: it does not walk a mixed tree. And sbomqs
could not parse the Maven output because of a malformed relationship line, so validate anything it produces.

## Strengths / limits

- Strengths: native SPDX output, simple CLI, single binary.
- Limits: the project has had little maintenance recently, plugin coverage is patchy and output validity is not guaranteed.
  Included here for completeness; prefer Syft, Trivy, bom or sbom-tool for SPDX today.
