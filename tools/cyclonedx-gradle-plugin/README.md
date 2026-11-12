# cyclonedx-gradle-plugin

**What it is.** The CycloneDX Gradle plugin, the Gradle counterpart of the Maven plugin. Generates the SBOM from the
resolved configurations you choose.

**Install.** None: applied in `sample-app/java-gradle/build.gradle.kts` (`id("org.cyclonedx.bom")`).
· [github.com/CycloneDX/cyclonedx-gradle-plugin](https://github.com/CycloneDX/cyclonedx-gradle-plugin) · Apache-2.0 · tested with 2.3.1 on Gradle 9.3

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1 | `gradle cyclonedxBom` configured for `runtimeClasspath` only, schema 1.6, JSON + XML into `build/reports/` |
| 2 | A `jq` summary showing component and dependency counts and the `metadata.tools` entry |

## What we saw

- 7 components, 8 dependency entries, matching the Maven plugin's view of the same declared dependencies.
- The `includeConfigs`/`skipConfigs` knobs are how you decide whether test or compile-only dependencies appear; the sample
  deliberately limits itself to what ships at runtime.

## Strengths / limits

- Strengths: build-accurate; works per-project or aggregated across a multi-project build; Kotlin and Groovy DSL.
- Limits: JVM/Gradle only; configuration API has changed between major versions, so pin the plugin version.
