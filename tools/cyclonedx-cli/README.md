# cyclonedx-cli

**What it is.** Not a generator: the CycloneDX project's command-line utility for working with SBOMs that other tools
produced. Validate, convert (incl. to SPDX and CSV), merge, diff and analyze.

**Install.** `brew install cyclonedx-cli` · [github.com/CycloneDX/cyclonedx-cli](https://github.com/CycloneDX/cyclonedx-cli) · Apache-2.0 · tested with 0.33.1

Run the generator demos first; this script reads their `output/` directories.

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1 | `validate` five SBOMs from five different generators against the schema |
| 2 | `convert` the Maven SBOM to XML, SPDX JSON and CSV |
| 3 | `merge --hierarchical` the Maven, npm, Python, Go and Rust SBOMs into one document with five nested assemblies |
| 4 | `diff` the Maven SBOM with and without test scope (shows the JUnit tree appearing) |
| 5 | `diff` two *generators* on the same Node project (cyclonedx-npm vs cdxgen) |
| 6 | `analyze --multiple-component-versions`: finds `ms` and `uuid` present twice at different versions in the Syft output |

## What we saw

- All five generator outputs validated.
- The hierarchical merge is the practical way to publish one SBOM for a polyglot repo while keeping per-ecosystem provenance.

## Strengths / limits

- Strengths: the only tool here that does merge/diff/analyze; cross-platform single binary.
- Limits: CycloneDX-centric (SPDX only as a conversion target).
