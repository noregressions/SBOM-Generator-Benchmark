# cyclonedx-py (cyclonedx-bom)

**What it is.** CycloneDX's official Python generator. Four input modes: a `requirements.txt`, an installed (virtual)
environment, a Pipenv lockfile or a Poetry lockfile.

**Install.** `brew install cyclonedx-python` or `pipx install cyclonedx-bom`
· [github.com/CycloneDX/cyclonedx-python](https://github.com/CycloneDX/cyclonedx-python) · Apache-2.0 · tested with 8.0.1

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1 | `requirements` mode: only what the file declares, no transitive resolution (3 components) |
| 2 | `environment` mode pointed at the sample's `.venv`: everything pip actually installed, with licences from package metadata (14 components) |
| 3 | XML output with `--output-reproducible` |

`--pyproject` is passed so the root component gets the project's own name, version and licence.

## What we saw

- Requirements vs environment is the Python version of npm's dev/prod gap: 3 declared packages become 14 installed ones
  (Werkzeug, Jinja2, MarkupSafe, certifi, urllib3 and friends).
- The requirements-only SBOM is flagged by the library itself as having an incomplete dependency graph.

## Strengths / limits

- Strengths: reads real installed metadata (dist-info), so names, versions and licences are accurate; Pipenv/Poetry support.
- Limits: environment mode needs the environment to exist, so create the venv in CI first; no container or OS package support.
