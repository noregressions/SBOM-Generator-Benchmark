#!/usr/bin/env python3
"""Compare RUNTIME / NONRUNTIME / COMBINED SBOMs per tool and ecosystem.

Reads scope-runs/output/<tool>/<eco>.<scope>.cdx.json, normalises every component to a
purl without qualifiers, and reports set sizes, set algebra and whether known test/dev-only
packages leaked into the runtime SBOM or are labelled with a scope in the combined one.
"""
import json
import sys
from pathlib import Path

# Packages we KNOW are test/dev-only in sample-app. If one of these is in a RUNTIME SBOM, it leaked.
DEV_MARKERS = {
    "java":   {"junit-jupiter", "junit-jupiter-api", "junit-jupiter-engine", "junit-jupiter-params",
               "junit-platform-commons", "junit-platform-engine", "opentest4j", "apiguardian-api"},
    "node":   {"jest", "jest-cli", "babel-jest", "@jest/core"},
    "python": {"pytest", "pluggy", "iniconfig"},
    "go":     {"github.com/stretchr/testify", "github.com/davecgh/go-spew", "github.com/pmezard/go-difflib"},
    "rust":   {"pretty_assertions", "diff", "yansi"},
}


def purl_key(c):
    p = c.get("purl") or ""
    if p:
        return p.split("?")[0]
    return f'{c.get("group","")}/{c.get("name","")}@{c.get("version","")}'


# Component types that represent packages. Scanners such as Syft also emit `file` components (lockfiles, workflow
# files) whose identity is a filesystem path, which would differ between runs for reasons unrelated to scope.
PACKAGE_TYPES = {"library", "application", "framework", None}


def load(path):
    bom = json.loads(Path(path).read_text())
    comps = {}
    for c in bom.get("components", []):
        if c.get("type", None) in PACKAGE_TYPES:
            comps[purl_key(c)] = c
    return comps


def dev_label(c):
    """How (if at all) a component is marked as non-runtime. Returns a short mechanism string or None."""
    if c.get("scope") in ("optional", "excluded"):
        return f"scope={c['scope']}"
    for p in c.get("properties", []) or []:
        n, v = p.get("name", ""), str(p.get("value", "")).lower()
        if v == "true" and any(w in n.lower() for w in ("development", "dev", "test")):
            return n
    return None


def name_of(key):
    k = key.split("@")[0]
    k = k.replace("pkg:maven/", "").replace("pkg:npm/", "").replace("pkg:pypi/", "").replace("pkg:golang/", "").replace("pkg:cargo/", "")
    return k.split("/")[-1] if "pkg:maven" in key or k.count("/") == 1 and not k.startswith("github.com") else k


def dev_hits(keys, eco):
    markers = DEV_MARKERS.get(eco, set())
    hits = set()
    for k in keys:
        n = k.split("@")[0]
        for part in (n, n.split("/")[-1], n.replace("pkg:golang/", "").replace("pkg:npm/", "").replace("pkg:pypi/", "").replace("pkg:cargo/", "")):
            if part in markers:
                hits.add(part)
    return hits


def main(out_dir):
    out = Path(out_dir)
    rows = []
    for tool_dir in sorted(p for p in out.iterdir() if p.is_dir()):
        ecos = sorted({f.name.split(".")[0] for f in tool_dir.glob("*.cdx.json")})
        for eco in ecos:
            files = {s: tool_dir / f"{eco}.{s}.cdx.json" for s in ("runtime", "nonruntime", "combined")}
            have = {s: f.exists() for s, f in files.items()}
            rt = load(files["runtime"]) if have["runtime"] else None
            cb = load(files["combined"]) if have["combined"] else None
            nr = load(files["nonruntime"]) if have["nonruntime"] else None
            nr_src = "built"
            if nr is None and rt is not None and cb is not None:
                nr = {k: v for k, v in cb.items() if k not in rt}
                nr_src = "derived"
            elif nr is None:
                nr_src = "n/a"

            def n(d):
                return "n/a" if d is None else str(len(d))

            # set algebra
            algebra = ""
            if rt is not None and cb is not None:
                missing_from_cb = set(rt) - set(cb)
                algebra = "runtime ⊆ combined" if not missing_from_cb else f"{len(missing_from_cb)} runtime pkgs NOT in combined"
                if nr_src == "built":
                    union = set(rt) | set(nr)
                    extra = set(cb) - union
                    miss = union - set(cb)
                    if not extra and not miss:
                        algebra += "; runtime ∪ nonruntime = combined"
                    else:
                        algebra += f"; combined differs from runtime ∪ nonruntime by +{len(extra)}/-{len(miss)}"
                    overlap = set(rt) & set(nr)
                    if overlap:
                        algebra += f"; {len(overlap)} shared"

            leaked = dev_hits(rt.keys(), eco) if rt is not None else set()
            # scope labels on dev markers in the combined SBOM
            labelled = "n/a"
            if cb is not None:
                marks = [c for k, c in cb.items() if dev_hits([k], eco)]
                if marks:
                    mechs = [dev_label(c) for c in marks]
                    tagged = [m for m in mechs if m]
                    how = sorted(set(tagged))
                    labelled = f"{len(tagged)}/{len(marks)}" + (f" via {', '.join(how)}" if how else " (no marker)")
                else:
                    labelled = "no dev pkgs present"

            rows.append({
                "tool": tool_dir.name, "eco": eco,
                "runtime": n(rt), "nonruntime": n(nr) + ("" if nr_src == "built" else f" ({nr_src})"),
                "combined": n(cb), "leaked": ", ".join(sorted(leaked)) or ("none" if rt is not None else "n/a"),
                "labelled": labelled, "algebra": algebra or "n/a",
            })

    print("# Scope runs: runtime vs non-runtime vs combined\n")
    print("Component counts are unique purls (qualifiers stripped). *derived* = the tool cannot build that scope "
          "directly, so it is computed as combined minus runtime. *Leaked* lists known test/dev-only packages found in "
          "the RUNTIME SBOM. *Labelled* says how many of the dev packages in the COMBINED SBOM carry a marker a consumer could filter on (CycloneDX `scope`, or a tool property such as `cdx:npm:package:development`). `file`-type components are ignored throughout.\n")
    print("| Tool | Eco | Runtime | Non-runtime | Combined | Leaked into runtime | Dev pkgs labelled in combined | Set algebra |")
    print("|---|---|---:|---:|---:|---|---|---|")
    for r in rows:
        print(f"| {r['tool']} | {r['eco']} | {r['runtime']} | {r['nonruntime']} | {r['combined']} | {r['leaked']} | {r['labelled']} | {r['algebra']} |")

    # detail: what exactly is in each non-runtime set
    print("\n## What the non-runtime sets contain\n")
    for tool_dir in sorted(p for p in out.iterdir() if p.is_dir()):
        for eco in sorted({f.name.split(".")[0] for f in tool_dir.glob("*.cdx.json")}):
            f_rt, f_cb, f_nr = (tool_dir / f"{eco}.{s}.cdx.json" for s in ("runtime", "combined", "nonruntime"))
            if f_nr.exists():
                nr = load(f_nr)
            elif f_rt.exists() and f_cb.exists():
                rt, cb = load(f_rt), load(f_cb)
                nr = {k: v for k, v in cb.items() if k not in rt}
            else:
                continue
            names = sorted({k.split("@")[0].split("/")[-1] for k in nr})
            shown = ", ".join(names[:12]) + (f" … (+{len(names)-12})" if len(names) > 12 else "")
            print(f"- **{tool_dir.name} / {eco}** ({len(nr)}): {shown}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "output")
