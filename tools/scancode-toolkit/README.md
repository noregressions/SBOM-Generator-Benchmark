# ScanCode Toolkit

**What it is.** nexB/AboutCode's file-level scanner. Where most tools read manifests, ScanCode reads *every file* for
licence text, copyright statements, package metadata and file types, and can export the result as SPDX (tag-value or RDF)
and CycloneDX. It is the licence-detection engine inside ORT, FOSSology workflows and many commercial products.

**Install.** `pipx install --python python3.12 scancode-toolkit` (Python 3.14 is not yet supported). If startup fails with
`did not find any 'pre_scan' hooks`, run `pipx runpip scancode-toolkit install 'pluggy==1.0.0'`.
· [github.com/aboutcode-org/scancode-toolkit](https://github.com/aboutcode-org/scancode-toolkit) · Apache-2.0 · tested with 32.5.0

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1 | `--package` only across the tree (fast): native JSON, CycloneDX JSON and SPDX tag-value in one run |
| 2 | Full `--license --copyright --package --info` scan of the Maven project: JSON, HTML report, SPDX RDF, CycloneDX XML |

## What we saw

- Package mode found 5 top-level packages but **400 dependencies** from the lockfiles: it parses `package-lock.json`,
  `Cargo.lock`, `go.sum`, `pom.xml` and `requirements.txt` as *declared* dependencies rather than resolving them.
- The full scan is where ScanCode earns its keep: per-file licence expressions and copyright holders, which no other tool here produces.
- Install is fragile outside the supported Python range; the project also publishes a Docker image.

## Strengths / limits

- Strengths: best-in-class licence and copyright detection, huge licence database, many output formats.
- Limits: slow on large trees, heavy Python dependency set, and its SBOM is a by-product of a compliance scan rather than a
  dependency-resolution SBOM.
