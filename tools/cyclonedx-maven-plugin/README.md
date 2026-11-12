# cyclonedx-maven-plugin

**What it is.** The CycloneDX Maven plugin. Generates the SBOM *inside the build* from Maven's resolved dependency graph,
so scope, exclusions, dependency management and the actual transitive tree are exactly what the build used.

**Install.** None: declared in `sample-app/java-maven/pom.xml`. Any Maven project can also run it unconfigured with the
fully-qualified goal. · [github.com/CycloneDX/cyclonedx-maven-plugin](https://github.com/CycloneDX/cyclonedx-maven-plugin) · Apache-2.0 · tested with 2.9.1

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1 | `mvn cyclonedx:makeBom` using the configuration in the pom (schema 1.6, JSON + XML, licence text off) |
| 2 | Zero-config `org.cyclonedx:cyclonedx-maven-plugin:2.9.1:makeAggregateBom` with `-D` overrides (test scope on, schema 1.5) |
| 3 | A `jq` summary showing the component **and dependency-graph** counts |

Gotcha we hit: values set explicitly in the pom's `<configuration>` win over `-D` properties, so the pom leaves
`outputName` and `includeTestScope` unset to keep them overridable.

## What we saw

- 6 components and a complete `dependencies` graph for runtime scope; 14 with test scope on (JUnit's tree appears).
- Every component carries purl, group, hashes and declared licences from Maven Central metadata.
- sbomqs NTIA score 8.1, the joint best in the comparison, from a 7-component document.

## Strengths / limits

- Strengths: most accurate Java SBOM possible; `makeAggregateBom` handles multi-module builds; `makePackageBom` attaches the SBOM
  as a build artifact for publishing to Maven repositories.
- Limits: Java/Maven only; needs the build to run (dependency resolution), so not usable on a bare jar.
