#!/usr/bin/env bash
# Assert what is, and isn't, in the publish output. LegacyApp.deps.json is the runtime's own list of what it loads,
# and obj/project.assets.json is the resolved graph the project file asked for; the ground truth comes from both.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f bin/publish/LegacyApp.deps.json ]] || { echo "bin/publish is missing: run scripts/build.sh first" >&2; exit 1; }
python3 - <<'PY'
import json, os, sys
deps = json.load(open("bin/publish/LegacyApp.deps.json"))
assets = json.load(open("obj/project.assets.json"))
shipped = {k.split("/")[0]: (k.split("/")[1], v["type"]) for k, v in deps["libraries"].items() if v["type"] != "project"}
graph = {k.split("/")[0]: k.split("/")[1] for k in assets["libraries"]}
files = set(os.listdir("bin/publish"))
fail = 0
def check(ok, msg):
    global fail
    print(("ok    " if ok else "FAIL  ") + msg)
    fail |= not ok
for name, ver, dll in [("Newtonsoft.Json", "12.0.1", "Newtonsoft.Json.dll"), ("log4net", "2.0.8", "log4net.dll"),
                       ("SharpZipLib", "1.2.0", "ICSharpCode.SharpZipLib.dll")]:
    check(shipped.get(name, ("",))[0] == ver and dll in files, f"ships:        {name} {ver} ({dll})")
rp = [n for n, (v, t) in shipped.items() if t == "runtimepack"]
check(len(rp) == 1 and rp[0].startswith("runtimepack.Microsoft.NETCore.App.Runtime.linux-")
      and shipped[rp[0]][0] == "6.0.36" and "System.Private.CoreLib.dll" in files,
      f"ships:        the .NET runtime as {rp[0] if rp else '(none)'} {shipped[rp[0]][0] if rp else ''}")
for name, ver in [("System.Text.Encodings.Web", "4.5.0"), ("System.Net.Http", "4.3.0"),
                  ("System.Text.RegularExpressions", "4.3.0"), ("StyleCop.Analyzers", "1.1.118")]:
    check(graph.get(name) == ver and name not in shipped, f"not shipped:  {name} {ver} (in the restore graph, not in deps.json)")
check(not any(f.startswith("StyleCop") for f in files), "not shipped:  no StyleCop DLL in the output")
print(f"      restore graph: {len(graph)} packages; deps.json: {len(shipped)}")
sys.exit(fail)
PY
