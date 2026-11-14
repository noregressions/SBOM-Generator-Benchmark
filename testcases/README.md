# Test cases

Each folder is one project with a known answer. `project/` is the code, and `expected.json` is the ground truth: what
ships, what must not be reported as shipped, which components are hidden and by what mechanism, and which stages
(source, artefact, image) the project can be scanned at.

| Test case | Ecosystems | What it hides |
|---|---|---|
| `spring-node` | Maven multi-module + React/Vite | a shaded `commons-codec`, bundled `lodash`/`react`, versions set by a BOM import |
| `payara-mvnpm` | Maven WAR + npm via mvnpm | `lodash-es` enters through a plugin realm and is bundled |
| `maven-plugin-hidden-content` | Maven | a plugin's transitive payload generates runtime code |
| `node-prepack` | npm | `dist/` is written by a dependency's `prepack` hook |
| `python-pep517` | pip | a transitive sdist's PEP 517 backend generates the installed module |
| `go-unlinked` | Go | nothing: `go.mod` requires four modules and the binary contains two, plus a standard library no file mentions |

## Running

```bash
make                      # build every test case, run every tool, score, rebuild the report
make CASE=<name>          # the same for one test case
make build CASE=<name>    # only build it
```

## Adding a test case

1. Create `testcases/<name>/project/` with the code and a script that builds it. Add a `.gitignore` for its build outputs.
2. Write `testcases/<name>/expected.json`. Copy the closest existing one; the fields are:
   - `target`, `title`, `ecosystems` (purl types that are in scope, e.g. `maven`, `npm`, `pypi`)
   - `build`: the command that builds the project, run from `project/`
   - `stages.source`: `path`, `exclude` (anchored paths hidden from scanners at source stage), and which native
     generators apply (`maven`: `single` or `aggregate`; `npm`: directory; `python`: requirements file; `go`: module
     directory, with `go_main` naming the main package)
   - `stages.artefact`: `path` and `kind` (`jar`, `war`, `dir`, `venv`, `binary`); `embedded_jars` if nested jars should be hash-checked
   - `stages.image`: `dockerfile`, `context`, `tag` (optional)
   - `shipped` and `not_shipped`: lists of `{purl, note}`, with `hidden` naming the mechanism where one applies
3. Run `make CASE=<name>`. The new case appears in the report without further changes.

Write the ground truth from the built artefact (the archive listing, the lockfile, the installed environment), not
from what any SBOM tool reports.

## Origin

Five of the cases were copied from the `scenarios/` directory of the
[KCDC 2026 workshop](https://github.com/noregressions/kcdc2026workshop) at commit `e0b955c` (2026-10-25), Apache-2.0.
Each of those has a `project/LESSON.md`, the workshop's walkthrough of the scenario.

`go-unlinked` was written for this benchmark. Its ground truth comes from the binary itself: the Go toolchain records
the modules it linked, and `scripts/proof-check.sh` reads that record back with `go version -m`.

Every case has a `scripts/proof-check.sh` that asserts what ends up in the artefact.

## Deliberately old dependencies

Several test cases pin old versions with published advisories, so that the security view has something to find.
`go-unlinked` goes further and puts vulnerable modules where they do not ship (a test-only import, a build tag). These
are fixtures and are never deployed. Expect GitHub's Dependabot to raise alerts for them; they are the test, not a
problem to fix.
