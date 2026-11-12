# SBOM Generator Benchmark

Most SBOM tools look reasonable on a tidy project. This repository runs them against projects built to be awkward,
where we know what ends up in the artefact, and scores each document twice. **Content accuracy** asks whether the
document is true. **Baseline conformance** asks whether it carries the fields the published baselines want.

The two scores disagree, and that's the reason to keep them apart.

The results are published as the **SBOM Generator Index**: the site in [`docs/`](docs/index.html), served by GitHub Pages. The same numbers are in
[`criteria/SCORECARD.md`](criteria/SCORECARD.md) and [`COMPARISON.md`](COMPARISON.md).

## What's in the project

The project has three parts: a benchmark, a way to run the same tools on your own code, and a set of demos.

The **benchmark** is the main thing. It has five test cases, each a small project that hides a dependency from SBOM
tools in a documented way, with a hand-written list of what really ships. It runs eleven free SBOM generators against
them at up to three stages, scores every document, and publishes the result as the SBOM Generator Index. Two slower
tools, ORT and ScanCode, have adapters but only run when you ask for them. One container image holds the tools at
pinned versions, so a report can be reproduced from the commit that contains it.

The **scan** command points those tools at any other source tree and writes a report into it.

The **demos** came first and are still here: 22 tool folders, each showing what that tool is for on a small sample
application. They cover more tools than the benchmark does, including ones that consume SBOMs instead of generating them.

| Directory | What it holds |
|---|---|
| [`testcases/`](testcases) | The benchmark's projects. Each has `project/` (the code) and `expected.json` (what ships, what doesn't, what is hidden and how). |
| [`tools/`](tools) | One folder per SBOM tool: `adapter.sh` is how the benchmark runs it, and `run.sh`, `README.md` and `output/` are its demo. `versions.env` pins every version. |
| [`image/`](image) | The Dockerfile for the tool image, built from `tools/versions.env`. |
| [`criteria/`](criteria) | The benchmark engine: it runs the adapters, scores the SBOMs and builds the site. `output/` holds the generated SBOMs and scores, and `SCORECARD.md` is the result in Markdown. |
| [`docs/`](docs) | The SBOM Generator Index, a generated static site. Don't edit it by hand. |
| [`scripts/`](scripts) | The commands behind the Makefile: `evaluate`, `scan`, `run-all.sh` for the demos, and `compare-tools.py`. |
| [`sample-app/`](sample-app) | One small application written for Maven, Gradle, npm, pip, Go and Cargo. The demos scan it; the benchmark doesn't. |
| [`scope-runs/`](scope-runs) | A separate experiment on the sample app: how each tool separates runtime dependencies from dev and test ones. |

Three documents sit at the root beside this one. [`REPORT.md`](REPORT.md) is the narrative write-up of the first runs,
[`COMPARISON.md`](COMPARISON.md) has one row per tool across the benchmark, the demos and the scope runs, and the
`Makefile` is how you run everything.

## Run it

You need Docker, `make` and `git`.

```bash
make            # build everything and refresh the report
make clean      # remove what the build left behind
```

The first run builds a container image holding every tool at the version pinned in
[`tools/versions.env`](tools/versions.env), which takes a few minutes and about 4 GB. After that, `make` builds the
test cases, runs every tool at every stage, scores the output, and rewrites the report. A full run takes roughly
ten minutes. It ends by printing `Failed steps: none`, or the list of steps that failed.

To publish, commit what changed. GitHub Pages serves `docs/` from the main branch, so there's no build step and no
workflow to wait for.

`make clean` removes the test cases' build outputs, the container images built from them, and Python caches. It
deletes only files that `.gitignore` names, so it can't remove anything tracked. The report, the SBOMs in
`criteria/output/` and the tool image stay. `make distclean` also removes the tool image and its cache volumes.

```bash
make CASE=spring-node              # one test case; the others keep their previous scores
make STAGES="source artefact"      # skip the image stage
make evaluate TOOLS="syft trivy"   # re-run only these tools (folder names under tools/); builds a test case only if it isn't built
make report                        # re-score the SBOMs already generated and rebuild docs/; runs no tools
make image                         # build the tool image only
make build                         # build the test cases only
make shell                         # open a shell in the tool image
make help                          # every target
```

The targets call `scripts/evaluate` and `scripts/scan`, which take the same choices as options if you'd rather run them directly.

## Scan your own project

`make` scores the tools against test cases with known answers. `make scan` points the same tools at any source tree
and writes the result into it.

```bash
make scan TREE=/path/to/project
make scan TREE=/path/to/project ARTEFACT=target/app.jar      # also scan a built artefact inside the tree
make scan TREE=/path/to/project SCAN_IMAGE=myapp:latest      # also scan an image your Docker daemon has
make scan TREE=/path/to/project EXCLUDE="target node_modules"   # hide these paths from the source-stage scanners
```

The report lands in `<project>/sbom-report/`: open `report.html`, or read `report.md`. Every SBOM the tools produced
is beside it under `sboms/<stage>/`.

Your project has no ground truth, so the report can't say which tool is right. It gives each document's conformance
scores, and it shows where the tools disagree: components only one tool reported, components a tool missed that two
others found, and packages reported at conflicting versions. Those are the places to look first. If you do know what
ships, write it down in the `expected.json` format and pass `EXPECTED=<file>`; the report then adds the accuracy columns.

The scan doesn't build anything, so build the project first if you want its artefact scanned. The two Maven plugins
run Maven in your tree and write under its `target/` directory.

## How a run fits together

`make` starts the tool image, builds the test cases, runs each tool's adapter against each one, then scores the
SBOMs and rebuilds the site. These are the files that do it:

```text
testcases/<name>/project/        a project that hides something from SBOM tools
testcases/<name>/expected.json   ground truth: what ships, what doesn't, what is hidden and how
tools/<tool>/adapter.sh          how one tool is run at each stage
tools/versions.env               every tool and toolchain version, in one place
image/Dockerfile                 the tool image, built from versions.env
criteria/generate.sh             runs every adapter against every test case and stage
criteria/score.py                scores the output -> criteria/output/scores.json, criteria/SCORECARD.md
criteria/build_site.py           builds docs/ from the scores
Makefile                         the entry point: make, make clean, make scan, make help
scripts/evaluate                 does all of the above inside the tool image (what `make` runs)
scripts/scan                     runs the tools against any other source tree and reports into it (`make scan`)
```

Each test case is scanned at up to three stages: the source checkout, the built artefact, and the container image.
The hidden mechanisms only show up as differences between stages, so one scan is never enough.
[`criteria/README.md`](criteria/README.md) explains how the content score is computed and where its limits are.

## Add a test case

Put the project in `testcases/<name>/project/` and write `testcases/<name>/expected.json` beside it. The runner finds
it by folder; nothing else needs editing. [`testcases/README.md`](testcases/README.md) lists the fields.

Write the ground truth from the built artefact, not from what a tool reports.

## Add a tool

1. Pin its version in `tools/versions.env` and install it in `image/Dockerfile`. Add it to the last `RUN` line there,
   which fails the image build if any tool doesn't start.
2. Write `tools/<tool>/adapter.sh`. The runner calls it once per test case and stage, with the input and output
   locations in environment variables. The adapter writes `<tool>.cdx.json` or `<tool>.spdx.json`, or exits through
   `na` when the stage doesn't apply to it. [`criteria/adapter-lib.sh`](criteria/adapter-lib.sh) documents the
   variables, and [`tools/syft/adapter.sh`](tools/syft/adapter.sh) is a short example.
3. Add the tool to `VERSION_KEYS` in `criteria/score.py`, so the reports show its version beside its name.
4. Run `make evaluate TOOLS=<tool>`. The image rebuilds because `versions.env` changed, and the tool appears in the
   report.

To upgrade a tool, change its line in `versions.env`, run `make`, and read the diff in the scorecard.

We leave out commercial free tiers and tools with no release since 2023.

## Where the test cases came from

The first five are the scenarios from the [KCDC 2026 workshop](https://github.com/noregressions/kcdc2026workshop):
mixed Maven and npm builds, shaded and bundled libraries, Maven plugin realms, npm `prepack` hooks and PEP 517 build
backends. Each one comes with a script that asserts what ends up in the artefact, and that's what makes scoring possible.

## Tool demos

The repository began as a set of hands-on demos, and they're still here. Every tool has a folder under `tools/` with
a `run.sh` that shows what the tool is for, run against the small multi-language application in `sample-app/`. These
run on the host, not in the tool image, and they aren't part of the report.

```text
sample-app/            one app, six ways: Maven, Gradle, npm, pip, Go, Cargo (+ .NET on demand, + Dockerfile)
tools/<tool>/run.sh    the demo
tools/<tool>/README.md what the tool is for and what we saw
tools/<tool>/output/   SBOMs from the last demo run
scripts/run-all.sh     runs every demo in dependency order
scope-runs/            three SBOMs per tool (runtime / non-runtime / combined) and a comparison of them
```

## The tools

### Multi-ecosystem generators

| Folder | Project | Formats | Reads | Pre-run here |
|---|---|---|---|---|
| [`syft`](tools/syft) | Anchore | CycloneDX, SPDX, Syft JSON | dirs, files, archives, images (no daemon) | yes |
| [`trivy`](tools/trivy) | Aqua | CycloneDX, SPDX | dirs, images (no daemon), K8s; also scans SBOMs | yes |
| [`cdxgen`](tools/cdxgen) | OWASP CycloneDX | CycloneDX 1.6 | 20+ ecosystems via their build tools, images (daemon) | yes |
| [`microsoft-sbom-tool`](tools/microsoft-sbom-tool) | Microsoft | SPDX 2.2, 3.0 | build drop + source manifests; validates drops | yes |
| [`kubernetes-bom`](tools/kubernetes-bom) | Kubernetes SIG Release | SPDX 2.3, 3.0.1 (exp.) | dirs (Go), files, archives, images | yes |
| [`spdx-sbom-generator`](tools/spdx-sbom-generator) | Linux Foundation | SPDX 2.2 | per-ecosystem manifests | yes (3 of 6 ecosystems worked) |
| [`scancode-toolkit`](tools/scancode-toolkit) | AboutCode | SPDX, CycloneDX, HTML | every file: licences, copyrights, packages | yes |
| [`ort`](tools/ort) | OSS Review Toolkit | SPDX, CycloneDX, reports | 20+ ecosystems; full compliance pipeline | yes (via container) |
| [`docker-sbom`](tools/docker-sbom) | Docker | SPDX, CycloneDX | images; BuildKit build-time attestations | yes |
| [`github-dependency-graph`](tools/github-dependency-graph) | GitHub | SPDX 2.3 | any repo GitHub indexes; submission API | yes |

### Ecosystem-native generators (the CycloneDX family and friends)

| Folder | Ecosystem | Notable capability | Pre-run here |
|---|---|---|---|
| [`cyclonedx-maven-plugin`](tools/cyclonedx-maven-plugin) | Maven | build-resolved graph, scopes, aggregate multi-module | yes |
| [`cyclonedx-gradle-plugin`](tools/cyclonedx-gradle-plugin) | Gradle | per-configuration selection | yes |
| [`sbom-plus-maven-plugin`](tools/sbom-plus-maven-plugin) | Maven | whole-build SBOM: dependencies **plus build plugins and imported BOMs**, with an origin report | yes |
| [`cyclonedx-npm`](tools/cyclonedx-npm) | npm | prod vs dev, lockfile-only, reproducible | yes |
| [`cyclonedx-python`](tools/cyclonedx-python) | pip / Pipenv / Poetry | requirements vs installed environment | yes |
| [`cyclonedx-gomod`](tools/cyclonedx-gomod) | Go | module vs application vs binary views, stdlib | yes |
| [`cargo-cyclonedx`](tools/cargo-cyclonedx) | Rust | per-target, per-binary | yes |
| [`cyclonedx-dotnet`](tools/cyclonedx-dotnet) | .NET / NuGet | project.assets-based, CycloneDX 1.7 | yes |
| [`sbom4python`](tools/sbom4python) | Python | hidden transitives, DOT graph, SPDX or CycloneDX | yes |
| [`jbom`](tools/jbom) | Java (artifacts + running JVMs) | attach to a live process | no (jar download blocked in sandbox; run it yourself) |

### Working with the results (not generators)

| Folder | Project | What it adds |
|---|---|---|
| [`cyclonedx-cli`](tools/cyclonedx-cli) | CycloneDX | validate, convert, merge, diff, analyze |
| [`sbomqs`](tools/sbomqs) | Interlynk | quality and NTIA/BSI compliance scoring; used here to compare every generator |

Grype (Anchore) and `trivy sbom` appear inside the Syft and Trivy demos as consumers that turn an SBOM into a vulnerability report.

## Running the demos on the host

```bash
# toolchains the sample app needs: java 17+, maven, gradle, node, python3, go, cargo  (dotnet optional)
brew install syft trivy cdxgen grype cyclonedx-cli cyclonedx-npm cyclonedx-python cyclonedx-gomod cargo-cyclonedx \
             spdx-sbom-generator sbom-tool bom sbomqs libmagic gh
pipx install sbom4python
pipx install --python python3.12 scancode-toolkit

./tools/syft/run.sh          # or any other tool
scripts/run-all.sh           # everything, in dependency order (cyclonedx-cli and sbomqs run last)
```

Each `run.sh` is self-contained and prints what it is doing; outputs land in that tool's `output/`.

The demos run on your machine, and SBOM tools record the absolute path they scanned. `scripts/run-all.sh` finishes by
replacing those paths with `/workspace` and `/home/user`. After running a single demo, run `make scrub` before you
commit, or your user name and directory layout go into the repository.

## How the generators compare on the same code

One representative SBOM per tool, scored with sbomqs (see [`tools/sbomqs`](tools/sbomqs) for the full table):

| Generator | Components found | sbomqs score | NTIA score |
|---|---|---|---|
| cdxgen (whole tree) | 399 | 6.8 | 8.1 |
| Microsoft sbom-tool (whole tree) | 396 | 5.3 | 4.3 |
| Syft (whole tree, CycloneDX) | 198 | 5.3 | 5.0 |
| Trivy (whole tree, CycloneDX / SPDX) | 120 | 4.7 / 7.0 | 5.1 |
| cyclonedx-npm (prod only) | 71 | 5.1 | 6.7 |
| cargo-cyclonedx | 17 | 6.6 | 9.1 |
| cyclonedx-python (environment) | 15 | 4.8 | 5.8 |
| cyclonedx-gradle-plugin | 8 | 6.4 | 7.7 |
| cyclonedx-maven-plugin | 7 | 6.7 | 8.1 |
| sbom-plus-maven-plugin (deps + build plugins; local build of 2026-11-11) | 206 | 7.3 | 9.9 |
| cyclonedx-gomod (app) | 5 | 6.1 | 6.4 |
| bom (Go dir) | 5 | 5.0 | 5.6 |
| sbom4python | 4 | 7.2 | 7.3 |
| cyclonedx-cli merge of the five native SBOMs | 116 | 6.0 | 7.0 |
| ORT CycloneDX report (whole tree) | 396 | 5.2 | **9.4** |
| spdx-sbom-generator (Maven) | n/a | unparseable | |

## Runtime vs non-runtime vs combined

[`scope-runs/`](scope-runs) builds three SBOMs with every tool that can express scope, then checks set algebra, whether known
test-only packages leaked into the runtime SBOM, and whether dev packages in the combined SBOM are labelled so a consumer can
filter them. Results and interpretation are in [`scope-runs/RESULTS.md`](scope-runs/RESULTS.md) and [`scope-runs/README.md`](scope-runs/README.md).

## Scoring on content, not only on fields

[`criteria/`](criteria) runs the tools against the test cases in [`testcases/`](testcases), which started as the
[KCDC 2026 workshop scenarios](https://github.com/noregressions/kcdc2026workshop):
mixed Maven + npm builds, shaded and bundled libraries, Maven plugin realms, npm `prepack` hooks and PEP 517 build backends,
each with a known list of what really ships. Every target is scanned at source, artefact and image stage, and every document
gets two scores: **content accuracy** against that ground truth (recall, wrong versions, leaked test/dev/build tooling, hash
correctness, a hidden-dependency matrix) and **baseline conformance** from sbomqs (NTIA 2021, NTIA/CISA 2026, BSI TR-03183-2,
FSCT). Results are in [`criteria/SCORECARD.md`](criteria/SCORECARD.md); the method and findings are in [`criteria/README.md`](criteria/README.md).

## Report and comparison

[`REPORT.md`](REPORT.md) is the narrative write-up: what was run, how it was measured, the results and the conclusions.

### One table for everything

[`COMPARISON.md`](COMPARISON.md) puts the three runs side by side, one row per generator: baseline conformance (shape), content accuracy
against ground truth (truth), hidden-dependency coverage by mechanism, and runtime/dev scope handling. It is generated by
`scripts/compare-tools.py` from the outputs of `scripts/run-all.sh`, `scope-runs/run.sh` and `criteria/score.py`.

## What the exercise taught us

- **Scanners and build plugins answer different questions.** Syft, Trivy and sbom-tool report what is on disk; cdxgen and
  the CycloneDX build plugins report what the build resolved, including scope and the dependency graph. The component counts
  differ by an order of magnitude on the same code, and both are "correct".
- **Dev dependencies dominate.** The Node sample is 69 packages in production and 323 with Jest installed. Every tool has a
  switch for this (`--omit dev`, `--required-only`, `--include-dev-deps`, `includeTestScope`); know which default you got.
- **Ecosystem-native tools score higher on NTIA minimum elements** because the registry hands them supplier, licence and hashes.
  Scanners find more but know less about each component.
- **Container images need no daemon** for Syft, Trivy and bom (they pull from the registry); cdxgen, Docker Scout and ORT do.
  BuildKit can generate the SBOM during `docker build` and ship it inside the image as an attestation.
- **Format matters as much as tool.** Trivy's SPDX scored 7.0 and its CycloneDX 4.7 from the same scan.
- **Image SBOMs differ in granularity, not just accuracy.** The same `python:3.12-slim` image yields 90 components from Trivy
  (packages only), 381 from cdxgen (packages plus files), 745 from bom (plus layers) and 2756 from Syft's XML (every file).
  See the sbomqs folder for the side-by-side.
- **Validate everything.** spdx-sbom-generator produced a tag-value file that sbomqs could not parse; cyclonedx-cli's `validate`
  and sbomqs are cheap gates to put in CI.
- **Build tooling is invisible to every tool but one.** SBOM+ lists 191 Maven plugin artifacts that run on the build
  machine and never ship; the CycloneDX Maven plugin, by design, lists none of them. You need both documents.
- **Conformance and accuracy are different scores.** Against the KCDC workshop scenarios, sbom-tool scores 10/10 on NTIA 2021
  while listing 145 test-scope components as if they shipped; SBOM+ 1.0.0 as published scored lowest on NTIA/CISA 2026 (4.3)
  with the best recall and the only sightings of Maven plugins. A local build that adds hashes, suppliers, licences and
  references scores 9.9 on the same inventory, which is the proof that the two axes are independent. See `criteria/SCORECARD.md`.
- **Nothing sees through a bundle after the build.** Every tool names `lodash` and `react` in the source tree; none names them
  inside the built jar or the image, where they are bytes in `index-*.js`. The shaded `commons-codec` is only "found" because
  the shade plugin left a `pom.properties` behind.
- **Scanners guess Maven groups from file names** when a jar has no `pom.properties`: cdxgen files `spring-boot` under
  `org.springframework`, Syft files `spring-boot-jarmode-tools` under its own name. A wrong purl matches no advisory.
- **One SBOM for a polyglot repo** is practical: generate per ecosystem with the native tools, then `cyclonedx merge --hierarchical`.

## Not covered (yet)

Commercial free tiers (Snyk, FOSSA, Mend, Sonatype) are deliberately excluded, as are tools with no release since 2023
(VMware's Tern, for example: its layer-by-layer attribution idea lives on in `bom` and in BuildKit attestations). Candidates for new folders: `distro2sbom` and the
rest of the `sbom4*` family, `sbom-rs`, Yarn/pnpm CycloneDX generators, `cyclonedx-php-composer`, `cyclonedx-ruby`,
Dependency-Track as a consumer, and `osv-scanner` as another SBOM consumer.
