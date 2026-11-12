# Scope runs: runtime vs non-runtime vs combined

Component counts are unique purls (qualifiers stripped). *derived* = the tool cannot build that scope directly, so it is computed as combined minus runtime. *Leaked* lists known test/dev-only packages found in the RUNTIME SBOM. *Labelled* says how many of the dev packages in the COMBINED SBOM carry a marker a consumer could filter on (CycloneDX `scope`, or a tool property such as `cdx:npm:package:development`). `file`-type components are ignored throughout.

| Tool | Eco | Runtime | Non-runtime | Combined | Leaked into runtime | Dev pkgs labelled in combined | Set algebra |
|---|---|---:|---:|---:|---|---|---|
| cargo-cyclonedx | rust | 15 | n/a (n/a) | n/a | none | n/a | n/a |
| cdxgen | java | 6 | 8 (derived) | 14 | none | 8/8 via scope=optional | runtime ⊆ combined |
| cdxgen | node | 3 | 328 (derived) | 331 | none | 3/3 via scope=optional | runtime ⊆ combined |
| cdxgen | python | 17 | 0 (derived) | 17 | iniconfig, pluggy, pytest | 0/3 (no marker) | runtime ⊆ combined |
| cyclonedx-gomod | go | 3 | 3 (derived) | 6 | none | 3/3 via scope=optional | runtime ⊆ combined |
| cyclonedx-gradle-plugin | java | 7 | 8 (derived) | 15 | none | 7/7 via cdx:maven:package:test | runtime ⊆ combined |
| cyclonedx-maven-plugin | java | 6 | 1 | 14 | none | 0/8 (no marker) | runtime ⊆ combined; combined differs from runtime ∪ nonruntime by +7/-0 |
| cyclonedx-npm | node | 69 | 254 (derived) | 323 | none | 3/3 via cdx:npm:package:development | runtime ⊆ combined |
| cyclonedx-python | python | 3 | 1 | 4 | none | 0/1 (no marker) | runtime ⊆ combined; runtime ∪ nonruntime = combined |
| sbom-plus-maven-plugin | java | 6 | 199 | 205 | none | 8/8 via scope=excluded | runtime ⊆ combined; runtime ∪ nonruntime = combined |
| syft | node | 71 | 2 (derived) | 73 | none | no dev pkgs present | runtime ⊆ combined |
| trivy | node | 71 | 261 (derived) | 332 | none | 0/3 (no marker) | runtime ⊆ combined |

## What the non-runtime sets contain

- **cdxgen / java** (8): apiguardian-api, junit-jupiter, junit-jupiter-api, junit-jupiter-engine, junit-jupiter-params, junit-platform-commons, junit-platform-engine, opentest4j
- **cdxgen / node** (328): accepts, ansi-escapes, ansi-regex, ansi-styles, anymatch, argparse, array-flatten, babel-jest, babel-plugin-istanbul, babel-plugin-jest-hoist, babel-preset-current-node-syntax, babel-preset-jest … (+296)
- **cdxgen / python** (0): 
- **cyclonedx-gomod / go** (3): go-difflib, go-spew, testify
- **cyclonedx-gradle-plugin / java** (8): junit-bom, junit-jupiter, junit-jupiter-api, junit-jupiter-engine, junit-jupiter-params, junit-platform-commons, junit-platform-engine, opentest4j
- **cyclonedx-maven-plugin / java** (1): junit-jupiter
- **cyclonedx-npm / node** (254): ansi-escapes, ansi-regex, ansi-styles, anymatch, argparse, babel-jest, babel-plugin-istanbul, babel-plugin-jest-hoist, babel-preset-current-node-syntax, babel-preset-jest, babel__core, babel__generator … (+230)
- **cyclonedx-python / python** (1): pytest
- **sbom-plus-maven-plugin / java** (199): aether-api, aether-impl, aether-spi, aether-util, aircompressor, aopalliance, apiguardian-api, asm, autolink, cdi-api, commons-beanutils, commons-chain … (+164)
- **syft / node** (2): checkout, setup-node
- **trivy / node** (261): ansi-escapes, ansi-regex, ansi-styles, anymatch, argparse, babel-jest, babel-plugin-istanbul, babel-plugin-jest-hoist, babel-preset-current-node-syntax, babel-preset-jest, babel__core, babel__generator … (+231)
