# Criteria: scoring SBOMs on what they contain, not only on how they are shaped

The rest of this repository runs tools against a tidy sample app, where every generator looks reasonable. This folder runs the
same tools against the test cases in [`testcases/`](../testcases), taken from the
[KCDC 2026 workshop scenarios](https://github.com/noregressions/kcdc2026workshop), which were built to
make SBOM tools fail in specific, documented ways: mixed Maven + npm builds, shaded and bundled libraries, Maven plugin realms,
npm lifecycle hooks and PEP 517 build backends. Because each scenario ships a `proof-check.sh` that asserts exactly what ends
up in the artefact, we have ground truth, and ground truth is what turns "this SBOM has 200 components" into a score.

## Two scores, kept apart

| Score | Question | Measured by |
|---|---|---|
| **Content accuracy** | Does the document name what actually ships, at the right version, without passing off test/dev/build tooling as shipped, with correct hashes? | `score.py` against `testcases/<target>/expected.json` |
| **Baseline conformance** | Does the document carry the fields the published baselines ask for? | `sbomqs score` and `sbomqs compliance` for NTIA 2021, NTIA/CISA 2026, BSI TR-03183-2 v2.1 and FSCT v3; `cyclonedx validate` |

They disagree, and the disagreement is the point. A well-formed CycloneDX 1.6 document with supplier, licence and hash on every
component can still describe the wrong inventory. A terse document with none of that can be the only one that knows a Maven
plugin injected code into your jar.

## Layout

```text
criteria/
  generate.sh              runs every tool adapter at every stage of every test case -> output/<test case>/<stage>/<tool>.*.json
  adapter-lib.sh           the contract between generate.sh and tools/<tool>/adapter.sh
  score.py                 scores output/ against the ground truth and sbomqs -> SCORECARD.md, output/scores.json
  build_site.py            builds ../docs/ (the published report) from output/scores.json
  SCORECARD.md             the result (generated; do not edit)
  ../testcases/<name>/     project/ (the code) and expected.json (ground truth: what ships, what must not, what is hidden and how)
  ../tools/<tool>/adapter.sh   how one tool is run
  ../COMPARISON.md         one row per tool across this run, scope-runs and the sample-app sbomqs table (python3 scripts/compare-tools.py)
```

Run it with `make` from the repository root, which does every step inside the tool image. The steps can also be
run one at a time on a host that has the tools installed:

```bash
testcases/build.sh                               # optional: generate.sh builds any test case that is not built yet
./criteria/generate.sh                           # ~10 min; add CRITERIA_ORT=1 / CRITERIA_SCANCODE=1 for the slow tools
python3 criteria/score.py                        # needs sbomqs and cyclonedx-cli on PATH, nothing else
python3 criteria/build_site.py                   # rebuilds docs/
```

## Stages

Each target is scanned at the stages it defines. The hidden mechanisms only show up as differences *between* stages, which is
why one scan is never enough.

| Stage | Input | Tools |
|---|---|---|
| source | the checkout, with build outputs (`target/`, `dist/`), dependency caches (`.maven-repo/`, `.venv/`) and co-located plugin source excluded | Syft, Trivy, cdxgen, sbom-tool, plus the ecosystem-native plugin for the build (CycloneDX Maven / SBOM+ / cyclonedx-npm / cyclonedx-py); ORT and ScanCode on request |
| artefact | the built jar, WAR, installed package or venv | Syft, cdxgen (`-t jar`), Trivy on the unzipped tree and on the raw file, bom, cyclonedx-py `environment`, sbom4python |
| image | the container built from the scenario's Dockerfile | Syft, Trivy, cdxgen (`-t docker`), Docker Scout, bom |

## Targets and what each one tests

| Target | Ecosystems | Hidden mechanism | Ground truth |
|---|---|---|---|
| spring-node | Maven multi-module + React/Vite, one Boot jar, Temurin image | `commons-codec` 1.17.1 **shaded** into `normalizer.jar`; `lodash`/`react` **bundled** into a static JS asset; versions decided by a BOM import | 37 shipped components from the real `BOOT-INF/lib`; 22 known non-shipping (test, dev, plugins, starters, BOM) |
| payara-mvnpm | Maven WAR + npm via mvnpm, Payara image | `lodash-es` enters through the esbuild **plugin realm** and is bundled; Jakarta API is `provided` | 3 shipped, 7 non-shipping |
| maven-plugin-hidden-content | Maven | a plugin's transitive payload generates runtime code; the project declares **zero** dependencies | 1 shipped, 4 non-shipping (2 of them the plugin and payload) |
| node-prepack | npm | `dist/` is written by the dependency's own **prepack** hook; the generator never ships | 2 shipped |
| python-pep517 | pip | a transitive sdist's **PEP 517 backend** generates the installed module | 2 shipped, pip as tooling |

## How the content score is computed

`score.py` reads CycloneDX JSON and SPDX JSON, keeps package-type components only, normalises each to a purl without
qualifiers, and compares with the target's expected lists restricted to the target's ecosystems (OS packages in images are
ignored). Per document:

- **Shipped found** — expected shipped components matched at the exact version (recall).
- **Wrong version** — matched by name only.
- **Leaked** — known non-shipping components (test, dev, build tooling, `provided`, BOM imports) present with no `scope` of
  `excluded`/`optional` and no `…dev`/`…test` property set to true. These are false positives from a consumer's point of view.
- **Labelled** — the same components present *with* such a label, which is the correct way to list them. `+N` counts further
  labelled components outside the known list (the long tail of build tooling SBOM+ records).
- **Unexpected** — unlabelled, in-scope, in neither list. At image stage these are the server's own libraries and are reported
  but not judged.
- **Hashes ok** — at artefact stage, every jar physically inside the artefact is digested and compared with the hash the tool
  emitted for that component.
- **Hidden matrix** — for every component tagged with a mechanism, one letter per stage: did this tool name it at all?

Components a tool cannot identify by purl (the published SBOM+ 1.0.0 emitted the primary component without one) are matched on name and version.
A tool's guess at the primary component is judged by recall, not counted as noise.

## Limits

- Ground truth is hand-written from the scenarios' POMs, lockfiles and the actual archive listings. If a scenario is rebuilt
  with different versions, update its `expected.json`.
- Hidden components count as "found" when the purl matches, even when the tool found it for an incidental reason (a
  `pom.properties` left behind by the shade plugin is incidental; the hidden matrix cannot tell). The scenario READMEs explain
  what each tool was relying on.
- BSI and FSCT scores reflect sbomqs' interpretation of those documents, which is an opinion, not a certificate.
- `sbom-tool`, `bom` and Docker Scout emit SPDX, so `cyclonedx validate` is not applicable to them and they show `n/a`.

## Findings from this run

Numbers are from `SCORECARD.md`; tool versions are the ones pinned in `tools/versions.env` (Syft 1.51, Trivy 0.74, cdxgen 11.3,
CycloneDX Maven 2.9.1, SBOM+ 1.0.0, sbom-tool 4.1, Scout 1.24). SBOM+ was re-run on 2026-11-11 with a local build of 1.0.0
that adds hashes, suppliers, licences, references and document metadata; finding 11 has the before and after.

1. **Nobody sees through a bundle or a plugin realm after the build.** Every tool names `lodash`, `react` and `react-dom` at
   source stage because they are in `package.json` and the lockfile. At artefact and image stage, where they exist only as
   bytes inside `index-*.js`, the hidden matrix is a solid row of `n`. The same is true of `lodash-es` in the Payara WAR.
   The only tool that names Maven plugins, their payloads and the BOM import is SBOM+, and it does so at source stage only,
   because that is where the build is.

2. **The shaded library is "found" for an incidental reason.** `commons-codec` 1.17.1, relocated to `com.acme.internal.codec`,
   is reported by Syft, Trivy and Docker Scout at every stage. They are reading the `META-INF/maven/commons-codec/pom.properties`
   the shade plugin left behind, not the bytecode. The workshop's `strip-codec-metadata.sh` shows the identification vanishing
   when that one file is removed. A `Y` in the matrix means the purl matched; it does not say why.

3. **Source stage is where the ecosystem matters most.** On the Spring + React target, Syft reads POMs without resolving them:
   15 in-scope components, 9 of 40 shipped found, and `jackson-databind` at version `UNKNOWN` because Spring's BOM chose it.
   Trivy (38/40), cdxgen (38/40) and sbom-tool (39/40) resolve the Maven tree. The first version of this exercise had Syft at
   39/40, which turned out to be Syft reading the built jar under `service/target`. Excluding build outputs from the source
   stage is what made the stages mean something.

4. **Scope is the difference between a leak and a label.** sbom-tool lists the entire test-scope closure (87 components on
   spring-node, 58 on payara) with no scope at all, and scores 10/10 on NTIA 2021 while doing it. The CycloneDX Maven plugin
   emits `provided` dependencies, the 26-component Jakarta EE API closure, indistinguishable from runtime ones. cdxgen labels
   134 test/dev/provided components `excluded` or `optional` and leaks none. cyclonedx-npm labels all 58 dev packages with a
   property. SBOM+ labels 67 and leaks none.

5. **A wrong purl is worse than a missing one.** cdxgen's `-t jar` mode on the Boot jar guesses the Maven group from the file
   name for jars that carry no `pom.properties`: `spring-boot` and `spring-boot-autoconfigure` land under `org.springframework`,
   `micrometer-*` under `micrometer-commons`. Syft does the same for `spring-boot-jarmode-tools` at every stage. Those purls match
   no advisory database. The plugins never make this mistake because they have the coordinates.

6. **Among the scanners, only Trivy hashes what it found.** At artefact and image stage Trivy emitted a hash for every one of
   the 32 nested jars and all 32 matched the real digest. Syft, cdxgen, sbom-tool and Scout emitted none for jars. The build
   plugins are the other source of hashes: the CycloneDX Maven plugin and the updated SBOM+ both hash the resolved jar at
   source stage, and all 30 match the jars that ship (the two reactor modules have no jar yet at that point). Trivy's artefact document is the best single document in
   the run: 33/40, 32/32 hashes, NTIA/CISA 2026 score 8.3. It needs the jar unzipped first; on the raw file it reports nothing.

7. **cdxgen's image mode does not open the application jar.** 218 components for the Temurin image, one of them in scope, 0/40
   shipped found. Syft, Trivy and Scout get 33–34/40 from the same image. On the Payara image all four report 378–456 Maven
   components, the server itself, which is correct and also why recall against a 3-component ground truth is the wrong
   question to ask of an image SBOM.

8. **Generated content is invisible by construction.** At source stage every tool names `trace-route-package`, and none can
   know its `dist/` was written by a prepack hook. Scanned on its own as an installed package, Syft and cdxgen return zero
   components and Trivy returns one application entry with no purl. For PEP 517, no tool sees the transitive `tracehook-demo`
   from `requirements.txt` alone; cyclonedx-py `environment` and Syft find it in the venv, sbom4python does not, Trivy finds
   nothing in a venv at all.

9. **The two scores disagree, as predicted.** Per tool, averaged over every document:

   | | NTIA/CISA 2026 | Mean recall | Leaked |
   |---|---:|---:|---:|
   | sbom-tool | 5.2 | 89% | 145 |
   | SBOM+ (published 1.0.0) | 4.3 | 93% | 0 |
   | SBOM+ (local build, 2026-11-11) | 9.9 | 94% | 0 |
   | CycloneDX Maven | 7.6 | 83% | 26 |
   | Syft | 4.6 | 70% | 2 |

   The document with the best conformance was not the one with the best inventory, and the one with the best inventory had the
   second-worst conformance because it carried no licences or hashes. Both scores are needed, and they should be reported
   side by side rather than blended. The SBOM+ re-run (finding 11) is the direct demonstration: the same inventory moved from
   4.3 to 9.9 by adding fields.

10. **Small quirks worth knowing.** cdxgen in recurse mode emits an empty document (no `metadata.component`) for a Maven
    project with zero dependencies; `--no-recurse` fixes it. sbom-tool percent-encodes scoped npm names (`%40babel%2Fcore`),
    which breaks naive purl comparison. Kubernetes `bom` cannot read an image from the local daemon, only a registry, and its
    `--file` mode on a jar yields a file entry with no packages. Syft's NTIA 2021 score on image documents is 1.9–2.3 despite
    33/40 recall, so that profile is a poor proxy for usefulness.

11. **Fields are cheap when you have the build.** SBOM+ re-run with a local build of 1.0.0 that emits, per component, MD5/SHA-1/
    SHA-256/SHA-512 hashes of the resolved jar, supplier and manufacturer from the POM organization, authors from the POM
    developers, declared licences with SPDX ids, description, copyright, vcs/website/distribution references, the BSI filename
    and executable/archive/structured properties, and an `sbom-plus:origin` property; at document level CycloneDX 1.6,
    `lifecycles` = build, authors/manufacturer/supplier (from `-DsbomPlus.author`, since the scenario POMs declare no
    organization), a purl on the primary component, a `compositions` block, and the reactor modules as components.

    | | Quality | NTIA 2021 | NTIA/CISA 2026 | BSI v2.1 | FSCT | spring-node recall |
    |---|---:|---:|---:|---:|---:|---:|
    | published 1.0.0 | 4.6 | 8.3 | 4.3 | 3.6 | 4.3 | 32/40 |
    | local build | 8.0 | 10 | 9.9 | 9.2 | 10.1 | 33/40 |

    The 30 SHA-256 values for jars that are physically in `BOOT-INF/lib` all match the real digests (`score.py` now checks
    hashes at every stage against the jars in the built artefact). The one extra shipped component is the `service` reactor module. What still fails:
    seven components whose POMs declare no licence, the two reactor modules which have no hash at source stage, BSI's
    "concluded licence" (an opt-in flag in the plugin, off by default because it only reads what the publisher declared), and
    BSI's "creator of SBOM" until an author email is supplied as well as a name. What is still missed is unchanged: the six npm
    packages Vite bundled, and `spring-boot-jarmode-tools`, which only an inspection of the built jar would find.

## Repository notes

`output/` is kept so the scorecard can be regenerated without the toolchain, except the image-stage documents (about 22 MB,
mostly Payara's 600-component inventory in four formats), which are ignored by git. Their scores are preserved in
`output/scores.json` and in `SCORECARD.md`.
