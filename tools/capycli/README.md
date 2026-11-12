# CaPyCLI

[CaPyCLI](https://github.com/sw360/capycli) is Siemens' command-line tool for creating and handling CycloneDX SBOMs,
written to feed the SW360 component catalogue. It can also compare, merge, filter and validate SBOMs, and map their
components to SW360 releases. MIT licence.

It is in the benchmark only; there is no host demo for it. `adapter.sh` runs it at the source stage.

## How it finds dependencies

CaPyCLI has one `getdependencies` command per ecosystem, and each reads a different input:

| Command | Reads |
|---|---|
| `getdependencies mavenlist` | the text output of `mvn dependency:list` |
| `getdependencies mavenpom` | `pom.xml`, without resolving it |
| `getdependencies javascript` | `package-lock.json` |
| `getdependencies python` | `requirements.txt` |
| `getdependencies nuget`, `rust` | project files for .NET and Rust (not used here) |

The adapter runs every command that applies to a test case and joins the component lists into one document. For Maven
it uses `mavenlist`, which is the route CaPyCLI's documentation describes; `mavenpom` returned no components for the
multi-module test case.

## Things to know

- It reads what a build tool or lockfile already wrote down, so it sees neither a built artefact nor a container image.
- `mvn dependency:list` reports the scope of each dependency, but the SBOM CaPyCLI writes from it carries no scope, so
  test dependencies are listed as if they shipped.
- It supports Python 3.11 to 3.14 and pins older versions of libraries that `cyclonedx-py` also uses. The tool image
  gives it a separate environment with its own interpreter, installed by `uv`.
