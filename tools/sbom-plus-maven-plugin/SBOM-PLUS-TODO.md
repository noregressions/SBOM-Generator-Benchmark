# SBOM+ (sbom-plus-maven-plugin): what it needs to score well on both axes

Derived from the criteria run of 2026-11-10 (SBOM+ 1.0.0, sbomqs 2.1.3). SBOM+ has the best inventory in the run (93% mean
recall, 0 leaked, 8/8 hidden components, the only tool that names Maven plugins, plugin dependencies and BOM imports) and the
lowest baseline conformance (NTIA/CISA 2026 4.3, BSI v2.1 3.6, FSCT 4.3, sbomqs quality 4.6). Every component today carries
only `name`, `version`, `purl`, `bom-ref` and `scope`. Every field below is available to a Maven plugin at build time.

Numbers to re-check after each change: `python3 criteria/score.py` then `python3 compare-tools.py`.

## Status after the re-run of 2026-11-11 (local build of 1.0.0)

| | Quality | NTIA 2021 | NTIA/CISA 2026 | BSI v2.1 | FSCT | spring-node recall |
|---|---:|---:|---:|---:|---:|---:|
| before | 4.6 | 8.3 | 4.3 | 3.6 | 4.3 | 32/40 |
| after | 8.0 | 10 | 9.9 | 9.2 | 10.1 | 33/40 |

Done: 1 (MD5, SHA-1, SHA-256, SHA-512; all 30 checkable SHA-256 values match the jars in `BOOT-INF/lib`), 2 (supplier and
manufacturer from the POM organization, authors from developers), 3 (declared, with SPDX ids), 4 (vcs, website, distribution),
6 (description and copyright), 7 (`-DsbomPlus.author`, also written to manufacturer and supplier), 8, 9, 10, 14 (reactor modules
are components), 19 in part (`sbom-plus:origin` property and plugin-to-transitive edges in `dependencies`), plus the BSI
filename / executable / archive / structured properties and a `compositions` block.

Still open: 5 (no `repository_url` qualifier on purls), 12, 13, 15 to 18 (nothing opens the built artefact yet, so the jarmode jar
and the six bundled npm packages are still the only misses), 21 (no `pkg:npm` identity on `org.mvnpm` components).

Residual sbomqs failures that are not bugs: seven components whose POMs declare no licence (`plexus-i18n`, `dom4j` 1.1, `oro`,
`commons-beanutils` 1.7.0 and the reactor modules); the two reactor modules have no hash at source stage; BSI "concluded
licence" is the opt-in `concludeDeclaredLicenses` flag, off by default on purpose; BSI "creator of SBOM" needs a contact on
the author: it fails with `-DsbomPlus.author` alone and passes once `-DsbomPlus.authorEmail` is also given.

## 1. Conformance: fields sbomqs marks missing on all 268 components

| # | Add | Source at build time | Profiles it moves |
|---|---|---|---|
| 1 | `hashes` (sha256, ideally also sha1 and md5) per component | digest the resolved artifact file in the local repository | NTIA 2026 (hash value + algorithm), BSI (hash of deployable component), FSCT (checksum). The largest single gap. |
| 2 | `supplier` (or `publisher`) per component | POM `organization`, else `developers`, else group id as fallback | NTIA 2021 (its only failing component field), NTIA 2026 (producer), BSI (component creator), FSCT |
| 3 | `licenses` per component | POM `licenses`, mapped to an SPDX id where it resolves; keep the raw name otherwise | NTIA 2026, BSI (declared + concluded), FSCT |
| 4 | `externalReferences` per component: `vcs` (POM `scm`), `website` (POM `url`), `distribution` (the repository that served it) | POM plus `_remote.repositories` beside the artifact, which already records the repository id | BSI (source code URI, URI of deployable form) |
| 5 | purl `repository_url` qualifier | same `_remote.repositories` entry | not scored by sbomqs today, but it is the provenance mark we discussed; `score.py` would need a provenance column to measure it |
| 6 | `description` and `copyright` where the POM has them | POM `description`, `inceptionYear` + organization | FSCT copyright; sbomqs quality |

## 2. Conformance: document-level fields

| # | Add | Notes |
|---|---|---|
| 7 | `metadata.authors` or `metadata.manufacturer` | NTIA 2026 "Author", BSI "creator of SBOM", FSCT "SBOM Author" all fail on this. Configurable, default to the POM organization. |
| 8 | `metadata.lifecycles` = `build` | NTIA 2026 "Generation Context". Also makes it explicit that this is a build-time document. |
| 9 | `purl` on `metadata.component` | the only "Unique ID" failure; `score.py` currently matches the primary by name and version to compensate |
| 10 | CycloneDX 1.6, not 1.5 | sbomqs' BSI v2.1 profile fails "specification version" on 1.5 |
| 11 | `metadata.component.type` and `bom-ref` consistency; `serialNumber` + `version` already present | keep |
| 12 | Signature (JSF) | optional in every profile; lowest priority |

## 3. Content: what it missed

All misses are on spring-node (32/40). The other targets were 100%.

| # | Missed | Why | Fix |
|---|---|---|---|
| 13 | `lodash`, `react`, `react-dom`, `loose-envify`, `js-tokens`, `scheduler` (npm, bundled by Vite into the Boot jar) | SBOM+ is Maven-only | when a plugin execution runs npm in a module (frontend-maven-plugin, exec-maven-plugin), read that module's `package-lock.json` and emit the production npm graph as components with `pkg:npm` purls, parented to the module. No bundler knowledge needed. |
| 14 | `dev.noregressions.trace:service@1.0.0` (the reactor module itself) | only the aggregate root is emitted as the primary; `normalizer` appears because it is a dependency of `service`, `service` never appears | emit every reactor module as a component (type `application` or `library`) with its purl, under the primary |
| 15 | `org.springframework.boot:spring-boot-jarmode-tools@3.5.12` | the Boot plugin copies it out of its own resources into `BOOT-INF/lib`; it is in no dependency graph | only a post-package inspection finds it: see 16 |

## 4. The one feature that changes the category SBOM+ is in

| # | Add | What it gives |
|---|---|---|
| 16 | A `verify` goal, bound after `package`, that opens the built jar/WAR, lists every nested jar (`BOOT-INF/lib`, `WEB-INF/lib`) with sha256, matches each to the resolved graph, and reports what the graph does not explain | finds the jarmode jar (15); gives SBOM+ an artefact stage, which it lacks today, with hashes that are by construction correct; turns "declared vs shipped" from a separate script into part of the build |
| 17 | In the same goal, read `META-INF/maven/*/pom.properties` inside each nested jar and flag any coordinate not in the graph | the shaded `commons-codec` 1.17.1 inside `normalizer.jar` becomes a finding with its relocation, instead of being found by accident |
| 18 | Read the shade plugin configuration (`relocations`) and emit `pedigree` / `evidence` on the affected component | records the relocation while the information still exists; no scanner can recover it afterwards |

## 5. Keep, but surface more of what it already knows

| # | Change | Why |
|---|---|---|
| 19 | Put the origin report's `broughtInBy` chain into the SBOM `dependencies` graph (plugin → plugin-transitive) and `origin` (`BUILD_TOOLING`, `BOM_IMPORT`, ...) as a component property | the report has it, the SBOM does not; it would make SBOM+ the only document that explains why each component is present |
| 20 | Keep `scope=excluded` for build tooling and `scope=required` for runtime | this is what gave it 0 leaks; do not change it |
| 21 | Attach a `pkg:npm` identity under `evidence.identity` for `org.mvnpm` and `org.webjars.npm` artifacts | the Maven purl matches no npm advisory; the POM has enough to infer the npm name and version |

## Expected effect

- 1, 2 and 9 alone take NTIA 2021 from 8.3 to 10.
- 1 through 4 plus 7, 8 and 10 should put NTIA/CISA 2026 and FSCT in the 8 to 9 range, on a par with Trivy's artefact document (8.3), while keeping the recall and leak numbers that nothing else matches.
- 13 through 16 take spring-node from 32/40 to 40/40 and add an artefact-stage row with 100% hash correctness.
