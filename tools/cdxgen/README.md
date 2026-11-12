# cdxgen (OWASP CycloneDX Generator)

**What it is.** The CycloneDX project's own polyglot generator (Node.js). Covers 20+ ecosystems, container images,
OS packages and even "SaaSBOM"/evidence features, and is the reference producer for the newest CycloneDX spec versions.

**Install.** `brew install cdxgen` or `npm i -g @cyclonedx/cdxgen` · [github.com/CycloneDX/cdxgen](https://github.com/CycloneDX/cdxgen) · Apache-2.0 · tested with 11.3.2

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1 | Recursive (`-r`) scan of the whole tree, all ecosystems auto-detected, CycloneDX 1.6 |
| 2 | `-t <type>` to run a single analyser (java, npm, python, go, rust) and compare per-ecosystem output |
| 3 | `--deep --evidence`: records *where* each component was found (occurrences); "atom" slicing for reachability where supported |
| 4 | `--required-only` to drop dev/test scope |
| 5 | `-t docker` image scan of `python:3.12-slim` (needs a Docker/Podman daemon, unlike Syft/Trivy; skipped automatically when none is running) |

`FETCH_LICENSE=false` is exported to stop cdxgen calling package registries for licence lookups during the demo.

## What we saw

- 399 components from the tree, the most of any tool, because cdxgen **runs the build tools** (Maven, npm, pip, go, cargo)
  to resolve full dependency trees and includes dev/test scope by default.
- The per-ecosystem Java SBOM includes a real `dependencies` graph, something file-system scanners cannot produce.
- Highest NTIA score among the multi-ecosystem tools in our sbomqs comparison (8.1).
- The image scan produced 380 components and, unlike Syft/Trivy, also emits `file` components for the image's notable files.

## Strengths / limits

- Strengths: breadth, depth (graphs, evidence, scope), fast adoption of new CycloneDX features, official OWASP project.
- Limits: needs the ecosystem toolchains installed and will execute them; Node.js runtime; container scanning needs a daemon;
  output can be noisy and large.
