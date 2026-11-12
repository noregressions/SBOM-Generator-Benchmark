# Scope runs: runtime, non-runtime, combined

The question: when a tool builds an SBOM, does it know (and tell you) which components ship and which exist only to
build and test the software? We asked each tool for three documents against the same sample app:

1. **Runtime**: what the deliverable needs.
2. **Non-runtime**: test, dev and build-time dependencies only.
3. **Combined**: everything.

Then `compare.py` normalises every component to a purl and checks: is runtime a subset of combined; does
runtime ∪ non-runtime equal combined; did any of the packages we *know* are test-only (JUnit, Jest, pytest, testify,
pretty_assertions) leak into the runtime document; and in the combined document, are the dev packages labelled so a
consumer could filter them out?

`./run.sh` rebuilds everything and regenerates [`RESULTS.md`](RESULTS.md).

## Which tools can express which scope

| Tool | Runtime | Non-runtime | Combined | Mechanism |
|---|---|---|---|---|
| cyclonedx-maven-plugin | yes | yes (but see below) | yes | `-DincludeTestScope`, `-DincludeCompileScope` … per Maven scope |
| sbom-plus-maven-plugin | from labels | from labels | yes | one whole-build document; `scope=required` vs `scope=excluded` on every component |
| cyclonedx-gradle-plugin | yes | derived | yes | choose resolved configurations (`runtimeClasspath` vs `testRuntimeClasspath`) |
| cyclonedx-npm | yes | derived | yes | `--omit dev` |
| cyclonedx-py (requirements mode) | yes | yes | yes | one requirements file per scope; `environment` mode is always combined |
| cyclonedx-gomod | yes | derived | yes | `mod` vs `mod -test` |
| cargo-cyclonedx | yes | no | no | dev-dependencies are always excluded; there is no switch |
| cdxgen | yes | derived | yes | `--required-only` |
| Trivy | yes | derived | yes | `--include-dev-deps` (npm, yarn, gradle lockfiles only) |
| Syft | by input | derived | by input | no flag; scan a production-only install vs the full tree |
| sbom-tool, bom, spdx-sbom-generator, ScanCode, GitHub | no | no | whatever is on disk | no scope concept |

"Derived" means the tool has no way to emit *only* the non-runtime set, so we compute it as combined minus runtime.
Most tools are in that position: they can include or exclude dev dependencies, but not isolate them.

## What the comparison showed

**1. No tool leaked test dependencies into a runtime SBOM, with one exception.** cdxgen's Python analyser reads
`requirements-dev.txt` alongside `requirements.txt` and marks everything as required, so pytest, pluggy and iniconfig
appear in its "runtime" document with no marker. Every other runtime set was clean.

**2. `--required-only` in cdxgen does not mean what you would hope for npm.** It produced 3 components (express, lodash,
uuid) because cdxgen marks only the *directly declared* production dependencies as `required` and express's own 66
runtime transitives as `optional`. Those transitives ship with the application. cyclonedx-npm's `--omit dev` gives
the correct 69. Read the flag as "direct declared dependencies", not "what ships".

**3. The Maven plugin's test-only mode drops transitives.** Asking for test scope alone yielded one component
(junit-jupiter) while the combined run has all eight JUnit packages. The plugin filters the resolved tree by the scope
of each node and the transitive test packages do not survive that filter, so runtime ∪ non-runtime is seven components
short of combined. Derive the non-runtime set from the two good documents instead.

**4. Labelling varies by tool, and two tools do not label at all.** In the combined SBOMs:

| Tool | How dev packages are marked |
|---|---|
| cdxgen, cyclonedx-gomod | CycloneDX `scope: optional` (standard field, any consumer can filter) |
| sbom-plus-maven-plugin | CycloneDX `scope: excluded` for test deps *and* build tooling; `required` for what ships |
| cyclonedx-npm | property `cdx:npm:package:development=true` (tool-specific, but documented) |
| cyclonedx-gradle-plugin | property `cdx:maven:package:test=true` |
| cyclonedx-maven-plugin | nothing: every component is `scope: required`, JUnit included |
| cyclonedx-py, Trivy | nothing |

A consumer given the Maven plugin's combined SBOM cannot tell JUnit from Jackson. That is the failure mode discussed in
the criteria: present *and* unlabelled. The same plugin produces an excellent runtime-only SBOM, so the fix is to ship
that one, or to ship both documents and say which is which.

**4b. The only Maven document where the arithmetic works.** SBOM+ emits one SBOM with 205 components: 6 `required`,
199 `excluded` (8 test dependencies plus 191 build plugins and their transitives). Filtering on the standard `scope`
field gives a runtime set identical to the CycloneDX plugin's, a non-runtime set that includes the build tooling nobody
else lists, and runtime ∪ non-runtime = combined exactly. That is what a labelled Build SBOM looks like.

**5. The dev tail dwarfs the product.** Node: 69 runtime vs 254 dev-only. Java: 6 vs 8. Python: 3 vs 1 (requirements
mode, no transitives) but 14 vs 4 once installed. Go: 3 vs 3. For npm the SBOM you publish is a quarter of the size of
the one the build sees, and the vulnerability noise differs accordingly.

**6. Scanners follow the disk.** Syft had no flag to flip. Pointed at a `npm ci --omit=dev` install it produced the
same 69 packages as cyclonedx-npm's runtime set (plus the root and two GitHub Actions it found inside a package's
bundled workflow file). Pointed at the full tree it saw everything. Scope control for a scanner is a build-pipeline
decision: produce the runtime SBOM from the artifact you ship, not from the developer checkout.

**7. Cargo is the odd one out.** cargo-cyclonedx cannot include dev-dependencies at all. For "what ships" that is the
right default; for a build SBOM it is a gap, and the derived set is empty because there is nothing to subtract.

## Takeaways for the criteria

- Score "scope honesty" on two things: nothing test-only in the runtime document, and every non-runtime package in
  the combined document carrying a filterable marker. Tools pass the first almost universally and the second rarely.
- Prefer the standard `scope` field over tool properties where you have a choice; cdxgen and cyclonedx-gomod use it.
- Treat "combined" SBOMs as build SBOMs and label them so. CISA's SBOM types (Source, Build, Deployed, Runtime…)
  exist for exactly this distinction.
- For npm, do not use cdxgen `--required-only` to produce a shipping SBOM; use `--omit dev` in cyclonedx-npm or
  scan a production install.
