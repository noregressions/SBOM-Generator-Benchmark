# sbomqs (SBOM quality score)

**What it is.** Interlynk's quality scorer. Reads SPDX or CycloneDX and scores structure, identification, integrity and
compliance against profiles such as NTIA minimum elements (2021 and the 2026 CISA revision), BSI TR-03183 and OpenChain Telco.
Not a generator; use it to compare what the generators in this repo produced.

**Install.** `brew install sbomqs` · [github.com/interlynk-io/sbomqs](https://github.com/interlynk-io/sbomqs) · Apache-2.0

Run the generator demos first; this script reads their `output/` directories.

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1 | Overall score (0-10), NTIA score and component count for one representative SBOM per generator, saved to `output/scores.txt` |
| 2 | `--detailed` breakdowns for a scanner (Syft) and a build plugin (Maven) |
| 3 | NTIA compliance JSON for the merged all-ecosystems SBOM |

## What we saw

| SBOM | Score | NTIA | Components |
|---|---|---|---|
| cargo-cyclonedx (Rust) | 6.6 | **9.1** | 17 |
| cdxgen (whole tree) | 6.8 | 8.1 | 399 |
| cyclonedx-maven-plugin | 6.7 | 8.1 | 7 |
| cyclonedx-gradle-plugin | 6.4 | 7.7 | 8 |
| sbom-plus-maven-plugin (whole build) | 4.6 | 4.3 | 206 |
| Trivy SPDX | **7.0** | 5.1 | 120 |
| cyclonedx-npm (prod) | 5.1 | 6.7 | 71 |
| Syft SPDX | 6.5 | 5.6 | 149 |
| cyclonedx-gomod (app) | 6.1 | 6.4 | 5 |
| cyclonedx-python (env) | 4.8 | 5.8 | 15 |
| Syft CycloneDX | 5.3 | 5.0 | 198 |
| Microsoft sbom-tool (SPDX) | 5.3 | 4.3 | 396 |
| bom (Go dir, SPDX) | 5.0 | 5.6 | 5 |
| sbom4python (CycloneDX) | 7.2 | 7.3 | 4 |
| Trivy CycloneDX | 4.7 | 5.1 | 120 |
| cyclonedx-cli merge of the five native SBOMs | 6.0 | 7.0 | 116 |

SBOM+ scores low on purpose: it enumerates build tooling and ships no licences or hashes, leaving enrichment to other
tools, so sbomqs penalises it on exactly the fields it chose not to fill. A reminder that these scores measure
completeness of metadata, not usefulness of the component list.

Pattern: **ecosystem-native tools score higher on NTIA** because registries hand them supplier, licence and hashes for every
component; **file-system scanners find more components but know less about each**. The same tool can score differently per
format (Trivy SPDX 7.0 vs CycloneDX 4.7), so check the format you will actually publish.

### The same container image through six tools

`python:3.12-slim` (or the sample image built on it) as seen by each image-capable generator:

| SBOM | Score | NTIA | Components |
|---|---|---|---|
| bom (Kubernetes) SPDX | **7.3** | 5.6 | 745 |
| Docker Scout SPDX (sample image) | 5.6 | **7.1** | 138 |
| BuildKit attestation SPDX (sample image, Syft inside BuildKit) | 6.4 | 6.4 | 109 |
| cdxgen CycloneDX | 5.4 | 6.0 | 381 |
| Trivy CycloneDX | 4.9 | 5.6 | 90 |
| Syft CycloneDX XML | 4.5 | 4.3 | 2756 |

The component counts are not comparable at face value: bom lists every layer and file, Syft's XML includes per-file entries,
cdxgen adds `file` components, while Trivy and Scout report packages only. Decide what granularity you want before picking a tool.

ORT's CycloneDX report scored 9.4 on NTIA, the highest of everything in this repo, because the analyzer fetches full metadata
(supplier, licences, VCS, hashes) for every package from the registries.

See `output/scores.txt` for the full run.
