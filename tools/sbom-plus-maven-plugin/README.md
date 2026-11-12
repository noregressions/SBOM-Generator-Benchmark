# SBOM+ Maven Plugin

**What it is.** A Maven plugin from noregressions that writes a CycloneDX SBOM for the **whole build**, not just the
application classpath: resolved project dependencies, every Maven build plugin with its transitive dependencies, and
imported BOMs. Alongside the SBOM it writes a scan report that records, for every artifact, where it came from
(`MAIN_BUILD`, `BUILD_TOOLING` or `BOM`), its Maven scope, and the `broughtInBy` path. It enumerates only; vulnerability,
EOL and licence annotation are left to other tools (a companion npm CLI, `@noregressions/sbom-plus-cli`, does that).

**Install.** None: run by coordinates, works on a checkout that has never been built.
· [noregressions.github.io/sbom-plus-maven-plugin](https://noregressions.github.io/sbom-plus-maven-plugin/) · Apache-2.0 · version 1.0.0 · Maven 3.9, Java 8+

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1 | `sbom-plus:scan` with output paths overridden by `-DsbomPlus.*` properties; no pom changes |
| 2 | Component count and the CycloneDX `scope` breakdown (`required` vs `excluded`) |
| 3 | Scan report rows grouped by origin |
| 4 | The build tooling the application classpath never shows, and the `broughtInBy` path for a transitive test dependency |
| 5 | Side by side with cyclonedx-maven-plugin on the same pom |

`scan-aggregate` does the same once for a multi-module reactor.

## What we saw

| Document | Components |
|---|---|
| cyclonedx-maven-plugin, compile+runtime+test | 14 |
| SBOM+ | 205 |

- The 191 extra components are the Maven plugins that build the sample (compiler, resources, jar, surefire, the
  CycloneDX plugin itself) and everything they pull in: ASM, Plexus, Guice, commons-* and so on. None of it ships, all
  of it runs on the build machine with access to the source and the artifact.
- The scopes are honest: the 6 runtime dependencies are `required`, the other 199 (8 test, 191 build) are `excluded`.
  That is the standard CycloneDX field, so any consumer can filter to "what ships" without knowing this plugin.
- The scan report has 230 rows for 205 distinct components because the same artifact can arrive through several
  plugins; each row keeps its own `broughtInBy` path, which is what you need when a build-tool CVE lands and you want
  to know which plugin to upgrade.
- Imported BOMs would appear with origin `BOM`; the sample has none.

## Why it belongs next to the CycloneDX plugin

The CycloneDX Maven plugin answers "what does my application depend on". SBOM+ answers "what did my build execute".
CISA's SBOM types call the second one a Build SBOM, and it is the document you want for build-pipeline supply-chain
incidents (compromised plugins, poisoned test libraries). The two are complementary: generate the CycloneDX plugin's
runtime SBOM for distribution, and SBOM+ for the build record. In `scope-runs/` SBOM+ is the only Maven tool whose
combined document labels every non-shipping component.

## Strengths / limits

- Strengths: build tooling and BOM imports as first-class components; standard `scope` labels; origin and path report;
  tolerates unresolved reactor siblings instead of failing; works without a prior build.
- Limits: new (first release 2026) and from a small team, so expect API change; CycloneDX 1.5 rather than 1.6/1.7;
  Maven only; no licence or hash enrichment, by design.

## Improvement list

[`SBOM-PLUS-TODO.md`](SBOM-PLUS-TODO.md) lists what SBOM+ needs to score well on both conformance and content, derived from the criteria run.
