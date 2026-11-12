# ORT (OSS Review Toolkit)

**What it is.** A full open-source compliance pipeline: **Analyzer** (resolve dependencies for 20+ package managers),
**Scanner** (licence-scan sources with ScanCode or others), **Advisor** (vulnerabilities), **Evaluator** (policy rules),
**Reporter** (SPDX, CycloneDX, WebApp, NOTICE files, many more). Used by Bosch, HERE, Porsche and others.

**Install.** Heavyweight JVM app; run the official container `ghcr.io/oss-review-toolkit/ort`, or `sdk install ort`.
· [github.com/oss-review-toolkit/ort](https://github.com/oss-review-toolkit/ort) · Apache-2.0

`run.sh` exits cleanly if no Docker daemon is running. The analyzer mounts `sample-app` read-write because ORT temporarily
stashes `node_modules` inside the project while it resolves npm.

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1 | `ort analyze -i sample-app`: one analyzer result covering Maven, Gradle, npm, pip, Go and Cargo |
| 2 | `ort report -f SpdxDocument,CycloneDx,WebApp,PlainTextTemplate`: SBOMs and an interactive HTML report from that result |
| 3 | (printed, not run) `ort scan` to add ScanCode licence findings to the report |

## What we saw

- The analyzer found 8 projects across Cargo, Go, Gradle, Maven, npm, NuGet, pip and "Unmanaged", and resolved 389 packages in
  about four minutes, most of that spent running `npm info` for every Node package to fetch metadata.
- Gradle failed on the first run because the stock container has no JDK 17 toolchain. Adding the Foojay toolchain resolver to the
  sample's `settings.gradle.kts` fixed it: Gradle downloaded a JDK and the second run resolved the project. NuGet still fails
  (`nuget-inspector` error on the on-demand .NET project). ORT exits with code 2 when any manager reports an issue, but the result
  file is still written and the reporter still runs.
- ORT refuses to overwrite existing result files, so the script clears `output/analyzer` and `output/reports` first.
- The reporter produced SPDX (YAML), CycloneDX JSON, a NOTICE file with every licence text, and a 3 MB interactive HTML report.
  Open `output/reports/scan-report-web-app.html` to browse the dependency tree with licences and issues.

## Strengths / limits

- Strengths: the most complete picture of any tool here (resolved graphs + licences + policy + curation); multi-ecosystem in one run;
  reports are policy-aware.
- Limits: slow (minutes to hours), JVM and memory hungry, steep configuration curve; overkill if you only need an SBOM.
