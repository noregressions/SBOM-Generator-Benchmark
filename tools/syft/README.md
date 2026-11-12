# Syft

**What it is.** Anchore's general-purpose SBOM generator. A single Go binary that scans directories, archives,
single files and container images, and writes CycloneDX, SPDX or its own richer JSON.

**Install.** `brew install syft` · [github.com/anchore/syft](https://github.com/anchore/syft) · Apache-2.0 · tested with 1.51.0

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1 | One scan of the whole `sample-app/` tree, **several output formats from one pass** (`-o cyclonedx-json=… -o spdx-json=… -o syft-json=… -o table=…`) |
| 2 | Scanning a **built artifact** (the Maven jar) with no build tool present: Syft reads the `pom.properties` embedded in the jar |
| 3 | A **container image pulled straight from the registry** (`registry:` source), so no Docker daemon is needed; SPDX tag-value and CycloneDX XML |
| 4 | `syft convert` to re-emit an existing SBOM in a different format without rescanning |
| 5 | Feeding the SBOM to **Grype** (`grype sbom:…`) to get vulnerabilities from the document instead of the source |

## What we saw

- 198 components across all six ecosystems in one document, including the Go stdlib and the Python interpreter's own pip.
- The jar scan found only the jar's own coordinates (one component). Syft does not resolve a pom's dependencies, so for Java you
  want a fat jar, a `lib/` directory, or the Maven/Gradle plugins instead.
- The image scan took a few seconds and listed every Debian package plus pip, setuptools and wheel inside `python:3.12-slim`.
- Grype flagged real advisories against the pinned-old versions (express, jackson-databind, requests, flask), which shows the
  SBOM carries enough identity (purl + version) for a scanner to work with.

## Strengths / limits

- Strengths: breadth of ecosystems, image support without a daemon, stable CLI, widely integrated (Docker, GitHub Action).
- Limits: a *file-system scanner*, so it reports what is on disk, not what the build resolved. Scope (test vs runtime) and the
  full dependency graph are mostly absent compared with the build-tool plugins. Licence data is whatever the package metadata declares.
