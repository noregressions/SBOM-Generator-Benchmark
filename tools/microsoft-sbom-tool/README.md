# Microsoft sbom-tool

**What it is.** Microsoft's SPDX generator, used for its own products. Built for a *build drop*: it hashes every file you
are shipping and uses Component Detection to find packages in the source tree, then writes a manifest plus a SHA-256
integrity file. It can also **validate** a drop against the manifest later.

**Install.** `brew install sbom-tool` · [github.com/microsoft/sbom-tool](https://github.com/microsoft/sbom-tool) · MIT · tested with 4.1.13

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1 | `generate -b <drop> -bc <source> -pn -pv -ps -nsb`: SPDX 2.2 JSON under `_manifest/spdx_2.2/` with `.sha256` sidecar |
| 2 | `validate`: re-hash the drop and compare against the manifest, JSON result |
| 3 | `-mi SPDX:3.0`: the same build as SPDX 3.0 |

## What we saw

- 396 packages and 483 relationships detected from the source tree (Maven, Gradle, npm, pip, Go, Cargo lockfiles), plus
  SPDX `File` entries with hashes for everything in `java-maven/target`.
- Validation returned `Success` with 2 recorded differences (files the build wrote after the SBOM was generated), which is the
  tamper/drift detection the tool is designed for.
- SPDX 3.0 output worked in this version.

## Strengths / limits

- Strengths: file-level integrity, both SPDX 2.2 and 3.0, deterministic layout suited to release pipelines, Azure DevOps and GitHub Actions wrappers.
- Limits: SPDX only (no CycloneDX); package detection relies on lockfiles being present; the `-m` path semantics differ between `generate` and `validate` (see script).
