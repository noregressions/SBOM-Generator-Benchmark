#!/usr/bin/env bash
# CycloneDX for .NET reads a project or solution, restores it, and lists the resolved NuGet graph. It runs in the real
# tree (EV_PROJECT), like the Maven plugins, because it needs the restore to succeed. Source stage only.
. "$(dirname "$0")/../../criteria/adapter-lib.sh"
[[ "$EV_STAGE" == source ]] || na
proj=$(ex .stages.source.dotnet); [[ -n "$proj" ]] || na
need dotnet-CycloneDX
dotnet CycloneDX "$EV_PROJECT/$proj" -o "$EV_TMP" -fn out.json -F Json -spv 1.6 || exit 1
cp "$EV_TMP/out.json" "$EV_OUT/cyclonedx-dotnet.cdx.json"
