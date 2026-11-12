# bom (Kubernetes SIG Release)

**What it is.** The SPDX tool the Kubernetes project uses to publish SBOMs for its own releases. Handles directories,
files, archives and container images, resolves Go modules, and ships a built-in SPDX viewer.

**Install.** `brew install bom` or `go install sigs.k8s.io/bom/cmd/bom@latest`
· [github.com/kubernetes-sigs/bom](https://github.com/kubernetes-sigs/bom) · Apache-2.0 · tested with 0.8.0

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1-2 | Go module directory to SPDX 2.3 JSON and tag-value, with dependency relationships and licences |
| 3 | `--image python:3.12-slim`: image pulled from the registry, every layer as a package with its OS packages |
| 4 | `--file <jar>`: a single artifact as an SPDX File with hashes |
| 5 | `bom document outline`: a tree view of any SPDX document |
| 6 | `--format spdx3-json`: experimental SPDX 3.0.1 JSON-LD via protobom |

## What we saw

- The Go SBOM shows the module `DEPENDS_ON` its three dependencies plus `stdlib@1.21`, and `CONTAINS` each source file.
- The image SBOM represents each of the layers as a package with ~90 relationships to the Debian packages it contains, the most
  layer-faithful image SBOM of the tools here.
- `document outline` is a handy way to eyeball any SPDX file from any generator.

## Strengths / limits

- Strengths: proven at Kubernetes scale, layer-aware images, Go binary introspection, in-toto provenance export.
- Limits: SPDX only; no language ecosystems beyond Go; the `--namespace` must be a URI you own.
