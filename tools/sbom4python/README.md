# sbom4python

**What it is.** One of Anthony Harrison's `sbom4*` family (`sbom4python`, `sbom4files`, `sbom4rust`, `distro2sbom`…).
Builds an SBOM for an installed Python module or requirements file and, unusually, reports the *hidden* transitive
dependencies pip pulled in. Output in SPDX or CycloneDX, tag-value/JSON/YAML, plus a Graphviz dependency graph.

**Install.** `pipx install sbom4python` (needs `brew install libmagic`)
· [github.com/anthonyharrison/sbom4python](https://github.com/anthonyharrison/sbom4python) · Apache-2.0 · tested with 0.12.6

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1 | `-r requirements.txt --use-pip`: SPDX tag-value resolved against the sample venv |
| 2 | Same input as CycloneDX JSON plus `-g` dependency graph in DOT format |
| 3 | `-m flask`: a single module and everything it drags in |

The script prepends the venv's `bin/` to `PATH` because the tool shells out to a bare `pip`.

## What we saw

- Works, and the DOT graph is a nice extra, but with `--use-pip` on this venv it listed 3 components for the requirements
  run, so check its output against `cyclonedx-py environment` (14) before relying on it.

## Strengths / limits

- Strengths: both SPDX and CycloneDX, graph output, part of a consistent family that also covers files, Rust, and whole Linux distros.
- Limits: single-maintainer project; pip-dependent; less battle-tested than the CycloneDX official tool.
