#!/usr/bin/env bash
# CycloneDX for .NET — `dotnet CycloneDX` global tool; reads .csproj/.sln/packages.lock.json and NuGet metadata.
# Install: dotnet tool install --global CycloneDX   |   https://github.com/CycloneDX/cyclonedx-dotnet
# This repo's sample app has no .NET project and this machine has no dotnet SDK, so the script scaffolds one on demand.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/cyclonedx-dotnet/output"; mkdir -p "$OUT"
PRJ="$ROOT/sample-app/dotnet"

export PATH="$PATH:$HOME/.dotnet/tools"
command -v dotnet >/dev/null 2>&1 || { echo "dotnet SDK not installed (brew install --cask dotnet-sdk). Nothing generated."; exit 0; }
dotnet tool list -g | grep -qi cyclonedx || dotnet tool install --global CycloneDX

if [ ! -d "$PRJ" ]; then
  echo "== 0. Scaffold a tiny console app with a few NuGet packages"
  dotnet new console -o "$PRJ" -n SbomSampleDotnet --force >/dev/null
  ( cd "$PRJ" && dotnet add package Newtonsoft.Json --version 13.0.3 >/dev/null && dotnet add package Serilog --version 4.0.0 >/dev/null )
fi

echo "== 1. SBOM from the project file (resolves transitive NuGet deps, licences from nuget.org) -> JSON"
dotnet CycloneDX "$PRJ/SbomSampleDotnet.csproj" -o "$OUT" -fn dotnet.cdx.json -F Json -spv 1.6 -sn sbom-sample-dotnet -sv 1.0.0

echo "== 2. Exclude dev dependencies + disable network licence lookups (offline/CI)"
dotnet CycloneDX "$PRJ/SbomSampleDotnet.csproj" -o "$OUT" -fn dotnet.offline.cdx.xml -F Xml --exclude-dev --disable-package-restore
ls -la "$OUT"
echo "Done. Outputs in $OUT"
