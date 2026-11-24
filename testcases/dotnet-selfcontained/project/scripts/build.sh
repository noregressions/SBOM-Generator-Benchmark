#!/usr/bin/env bash
# Publish self-contained for the machine's own runtime (linux-x64 or linux-arm64 in the tool image), so the .NET 6
# runtime pack ships inside bin/publish. Any current SDK can build net6.0; it warns that the target is out of support.
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf bin/publish
dotnet publish -c Release --self-contained --use-current-runtime -o bin/publish -nologo -v quiet
echo "Built bin/publish. Packages in LegacyApp.deps.json:"
python3 - <<'PY'
import json
d = json.load(open("bin/publish/LegacyApp.deps.json"))
for k, v in d["libraries"].items():
    if v["type"] != "project":
        print(f"  {k}  ({v['type']})")
PY
