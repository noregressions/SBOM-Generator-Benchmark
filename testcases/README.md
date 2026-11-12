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
     generators apply (`maven`: `single` or `aggregate`; `npm`: directory; `python`: requirements file)
   - `stages.artefact`: `path` and `kind` (`jar`, `war`, `dir`, `venv`); `embedded_jars` if nested jars should be hash-checked
   - `stages.image`: `dockerfile`, `context`, `tag` (optional)
   - `shipped` and `not_shipped`: lists of `{purl, note}`, with `hidden` naming the mechanism where one applies
3. Run `make CASE=<name>`. The new case appears in the report without further changes.

Write the ground truth from the built artefact (the archive listing, the lockfile, the installed environment), not
from what any SBOM tool reports.

## Origin

The five cases here were copied from the `scenarios/` directory of the
[KCDC 2026 workshop](https://github.com/noregressions/kcdc2026workshop) at commit `e0b955c` (2026-10-25), Apache-2.0.
Each `project/LESSON.md` is the workshop's walkthrough of that scenario, and the `scripts/` beside it include the
workshop's own `proof-check.sh`, which asserts what ends up in the artefact.
