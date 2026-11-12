# jbom (Contrast Security)

**What it is.** A Java-specific generator that works from *artifacts and running processes* rather than build files:
scan a directory of jars (including nested/shaded jars), a single jar, or attach to a live JVM by PID and report the
libraries actually loaded. Output is CycloneDX JSON.

**Install.** No package manager. `run.sh` downloads the latest release jar into `bin/` on first run (the jar is git-ignored).
· [github.com/Contrast-Security-OSS/jbom](https://github.com/Contrast-Security-OSS/jbom) · Apache-2.0

> Not pre-run in this repo: downloading and executing a third-party jar was blocked by the sandbox used to build these demos.
> Run `./run.sh` yourself to populate `output/`.

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 0 | Fetch the release jar with `gh release view` + `curl` |
| 1 | `-d <dir>`: scan every jar in the Maven `target/` directory |
| 2 | `-f <jar>`: scan a single jar |
| 3 | `-p <pid>`: start the sample app with its runtime classpath, attach to the JVM, report loaded libraries |

## Why it is interesting

- Runtime attach is unique in this collection: it answers "what is loaded in production right now?", which catches
  libraries added by agents, app servers or shaded jars that no build-time SBOM lists.
- Pairs well with a build-time SBOM from the Maven/Gradle plugins: diff the two with cyclonedx-cli.

## Strengths / limits

- Strengths: no build needed, runtime truth, handles fat/shaded jars.
- Limits: Java only; attach can fail across JDK vendors/versions; the project is updated infrequently, so check the release date.
