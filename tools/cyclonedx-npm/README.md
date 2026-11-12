# @cyclonedx/cyclonedx-npm

**What it is.** CycloneDX's official Node.js generator. Reads the npm install tree (`node_modules` and the lockfile), so it
reports what npm actually installed, with scopes and the dependency graph.

**Install.** `brew install cyclonedx-npm` or `npm i -g @cyclonedx/cyclonedx-npm`
· [github.com/CycloneDX/cyclonedx-node-npm](https://github.com/CycloneDX/cyclonedx-node-npm) · Apache-2.0 · tested with 6.0.1

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 1 | Full tree (prod + dev), CycloneDX 1.6 JSON |
| 2 | `--omit dev`: production only, i.e. what you would ship |
| 3 | `--package-lock-only`: no `node_modules` needed, CI-friendly, XML output |
| 4 | `--output-reproducible`: no timestamp/serial so two builds can be diffed byte-for-byte |

## What we saw

| Output | Components | Dependencies |
|---|---|---|
| full | 323 | 339 |
| prod only | 69 | 71 |

Jest alone pulls in roughly 250 packages. The gap is exactly why "did you include dev dependencies?" is the first question to ask of any npm SBOM.

## Strengths / limits

- Strengths: faithful to npm's own resolution; workspaces support; reproducible mode; tiny install.
- Limits: npm only (sister projects exist for yarn and pnpm, plus the generic `cyclonedx-node` library); needs an installed
  tree or lockfile, cannot work from `package.json` alone.
