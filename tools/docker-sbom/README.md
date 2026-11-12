# docker sbom / docker scout / BuildKit attestations

**What it is.** Three SBOM features built into or around the Docker CLI:

1. `docker scout sbom` (Docker Scout, free tier): Docker's analyser, SPDX/CycloneDX/list output, plus `docker scout cves`.
2. `docker sbom` (plugin, [github.com/docker/sbom-cli-plugin](https://github.com/docker/sbom-cli-plugin)): Syft wrapped as a Docker command.
3. `docker buildx build --sbom=true --provenance=true`: BuildKit generates the SBOM (Syft-based scanner image) **at build time**
   and attaches it to the image as an in-toto attestation, retrievable with `imagetools inspect`.

**Install.** Docker Desktop includes Scout and buildx. · [docs](https://docs.docker.com/scout/how-tos/view-create-sboms/)

`run.sh` exits cleanly if no daemon is running.

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 0 | Build `sbom-sample:local` from `sample-app/Dockerfile` |
| 1 | `docker scout sbom --format spdx` and `--format list` |
| 2 | `docker scout quickview` (policy + vulnerability summary vs the base image) and `docker scout cves --only-severity critical,high` |
| 3 | `docker sbom --format cyclonedx-json` if the plugin is installed |
| 4 | `buildx build --sbom=true --provenance=true` with a docker-container builder, exported as an OCI tarball; the script digs the in-toto SPDX predicate out of the blobs |

## What we saw

- `docker scout sbom` wrote a 3.4 MB SPDX document for the sample image (Debian packages plus the pip packages the Dockerfile installed).
- `docker scout quickview` needs `docker login` (a free Docker ID) even for local images. Once logged in it indexed 137 packages,
  compared the image against its `python:3.12-slim` base (2 high, 8 medium, 29 low; the base accounts for almost all of them) and
  evaluated Docker's default policies: 3 of 7 met, failing on "runs as root" and "copyleft licensed packages found" (368, the Debian base).
  That is the SBOM being consumed for policy, not just CVEs.
- The `docker sbom` plugin was not installed on this machine, so step 3 printed its install link.
- The BuildKit attestation contained an SPDX 2.3 document with 109 packages, created by `syft-v1.51.0` and `buildkit-v0.34.2`.
  It is the only SBOM here produced *during* the image build and shipped inside the image's OCI index.

## Strengths / limits

- Strengths: no extra tools for teams already on Docker; attestations travel with the image in the registry.
- Limits: needs a daemon; `docker scout` output formats and free-tier limits change; `docker sbom` plugin is lightly maintained
  (use Syft directly for the same result).
