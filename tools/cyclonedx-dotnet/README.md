# CycloneDX for .NET (`dotnet CycloneDX`)

**What it is.** CycloneDX's .NET global tool. Reads `.csproj`/`.sln`/`packages.lock.json`, resolves NuGet packages and
pulls licence metadata from nuget.org.

**Install.** `dotnet tool install --global CycloneDX` (needs a .NET SDK: `brew install --cask dotnet-sdk`)
· [github.com/CycloneDX/cyclonedx-dotnet](https://github.com/CycloneDX/cyclonedx-dotnet) · Apache-2.0 · tested with 6.3.1 on .NET SDK 10

## What `run.sh` demonstrates

| Step | Capability shown |
|---|---|
| 0 | Scaffolds `sample-app/dotnet/` (console app + Newtonsoft.Json + Serilog) if it does not exist |
| 1 | SBOM from the project file, CycloneDX 1.6 JSON, name/version overridden with `-sn`/`-sv` |
| 2 | XML output with `--exclude-dev` and `--disable-package-restore` for offline CI runs |

The script adds `~/.dotnet/tools` to `PATH`, which the SDK does not do for you.

## What we saw

- 2 components for the two direct packages (neither has transitive NuGet dependencies on .NET 10).
- The tool defaults to CycloneDX **1.7**, ahead of most other generators, so pin `-spv` if downstream consumers lag.

## Strengths / limits

- Strengths: resolves through `project.assets.json`, so it matches what MSBuild restored; multi-framework aggregation.
- Limits: .NET only; licence resolution for GitHub-hosted packages needs a token.
