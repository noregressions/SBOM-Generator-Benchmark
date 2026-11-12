# cyclonedx-gomod

**What it is.** CycloneDX's Go generator. Three sub-commands for three questions: `mod` (what could the module pull in),
`app` (what is actually compiled into this binary, build constraints evaluated) and `bin` (what does an existing binary say about itself).

**Install.** `brew install cyclonedx-gomod` or `go install github.com/CycloneDX/cyclonedx-gomod/cmd/cyclonedx-gomod@latest`
· [github.com/CycloneDX/cyclonedx-gomod](https://github.com/CycloneDX/cyclonedx-gomod) · Apache-2.0 · tested with 1.12.0

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1 | `mod -licenses`: module graph with licence detection |
| 2 | `app -std -main .`: application view including the Go standard library as a component |
| 3 | `bin`: SBOM recovered from the compiled binary's embedded build info, no source needed |

Gotcha we hit: the tool derives the main module's version from git tags/commits. In a checkout with no commit it fails,
so the script falls back to a scratch copy with a throwaway commit. Once this repo has a commit the fallback is skipped.

## What we saw

- `app` reported 4 components (3 modules + stdlib), `mod` 3, `bin` 3. Small numbers, but every one carries a purl with the
  exact pseudo-version and the Go toolchain version, which is what Go vulnerability databases key on.
- Grype later matched the stdlib component against a dozen Go stdlib advisories for 1.21.13, which is only possible because `-std` was used.

## Strengths / limits

- Strengths: build-constraint aware, binary introspection, stdlib tracking, pure Go.
- Limits: Go only; licence detection is heuristic; depends on git for version metadata.
