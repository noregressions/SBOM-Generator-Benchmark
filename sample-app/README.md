# sample-app — the thing every tool scans

One deliberately small application written six ways, so you can compare what each SBOM generator sees
when pointed at the *same* dependencies.

| Directory | Ecosystem | Direct dependencies | Lockfile / resolved state |
|---|---|---|---|
| `java-maven/` | Maven | jackson-databind, commons-lang3, slf4j-api, slf4j-simple (runtime), junit-jupiter (test) | none — Maven resolves at build; `target/*.jar` after `mvn package` |
| `java-gradle/` | Gradle (Kotlin DSL) | same as Maven | none — Gradle resolves at build; `build/libs/*.jar` |
| `node/` | npm | express, lodash, uuid; jest (dev) | `package-lock.json`, `node_modules/` |
| `python/` | pip | requests, flask, pyyaml | `.venv/` created by the cyclonedx-python demo |
| `go/` | Go modules | gorilla/mux, google/uuid, yaml.v3 | `go.sum` |
| `rust/` | Cargo | serde, serde_json, uuid | `Cargo.lock` |
| `dotnet/` | NuGet | Newtonsoft.Json, Serilog | scaffolded on demand by `tools/cyclonedx-dotnet/run.sh` |
| `Dockerfile` | container | `python:3.12-slim` + the Python app | built only by the Docker-based demos |

The Java projects pre-configure the CycloneDX build plugins so those demos work with zero extra setup.

Versions were chosen to be slightly old on purpose: several carry published advisories, which lets the
Syft and Trivy demos show an SBOM being fed straight into a vulnerability scanner.

## Rebuild from scratch

```bash
(cd java-maven  && mvn -q package -DskipTests)
(cd java-gradle && gradle -q --no-daemon build -x test)
(cd node        && npm install)
(cd python      && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt)
(cd go          && go mod tidy && go build ./...)
(cd rust        && cargo generate-lockfile)
```
