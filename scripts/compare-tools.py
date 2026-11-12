#!/usr/bin/env python3
"""Build COMPARISON.md: one row per generator, every axis the repo measures, side by side.

Sources (all produced by other scripts in this repo; nothing is re-scanned here):
  tools/sbomqs/output/scores.txt   shape of one representative sample-app SBOM per tool (sbomqs quality, NTIA, component count)
  criteria/output/scores.json      content accuracy + conformance against testcases/ (criteria/score.py)
  testcases/*/expected.json       which components are "hidden" and by what mechanism
  scope-runs/output/               runtime / combined SBOMs per tool and ecosystem (scope-runs/compare.py is imported for its helpers)

Usage: python3 scripts/compare-tools.py   -> writes COMPARISON.md at the repository root. Stdlib only.
"""
import importlib.util
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STAGES = ("source", "artefact", "image")

# Editorial roster. Numbers come from the data files; the text here is hand-written and should be revised when findings change.
# criteria = tool name used in criteria/output; scope = folder in scope-runs/output; sbomqs = row in tools/sbomqs/output/scores.txt.
ROSTER = [
    # folder, kind, criteria name, scope-runs name, sbomqs row, "best used for"
    ("syft", "multi-ecosystem scanner", "syft", "syft", "syft/output/sample-app.cdx.json",
     "fast inventory of directories, archives and images; parses POMs without resolving, so Maven versions can be UNKNOWN and groups guessed"),
    ("trivy", "multi-ecosystem scanner", "trivy", "trivy", "trivy/output/sample-app.cdx.json",
     "unzipped artefacts and images: correct hashes for every nested jar; emits nothing for a raw jar file"),
    ("trivy", "multi-ecosystem scanner (raw jar, no unzip)", "trivy-rawfile", None, None,
     "shown separately: `trivy fs` on the jar file itself finds nothing; unzip first"),
    ("cdxgen", "multi-ecosystem, build-tool driven", "cdxgen", "cdxgen", "cdxgen/output/sample-app.cdx.json",
     "source stage with the build tools present: best recall and labels test/dev/provided; weak on built artefacts and images"),
    ("microsoft-sbom-tool", "multi-ecosystem (SPDX)", "sbom-tool", None, "microsoft-sbom-tool/output/_manifest/spdx_2.2/manifest.spdx.json",
     "high recall at source because it runs the Maven dependency tree, but test scope is included unlabelled; NTIA 2021 perfect, 2026 revision poor"),
    ("kubernetes-bom", "multi-ecosystem (SPDX)", "bom", None, "kubernetes-bom/output/go.spdx.json",
     "Go directories and registry images; `--file` on a jar yields no packages, local image tags are not readable"),
    ("docker-sbom", "image (Docker Scout, BuildKit)", "docker-scout", None, "docker-sbom/output/sbom-sample.scout.spdx.json",
     "image stage only; found the shaded codec via leftover pom.properties, SPDX output"),
    ("spdx-sbom-generator", "multi-ecosystem (SPDX)", None, None, "spdx-sbom-generator/output/bom-Java-Maven.spdx",
     "not in the criteria run; its Maven output was unparseable by sbomqs"),
    ("scancode-toolkit", "source scanner (licences, copyrights)", None, None, None,
     "optional in criteria (CRITERIA_SCANCODE=1); the only tool that would see vendored or copied source"),
    ("ort", "compliance pipeline", None, None, "ort/output/reports/bom.cyclonedx.json",
     "optional in criteria (CRITERIA_ORT=1); highest NTIA score on sample-app"),
    ("github-dependency-graph", "hosted (GitHub)", None, None, None,
     "manifest-based, repository-level; not part of either comparison run"),
    ("cyclonedx-maven-plugin", "build plugin (Maven)", "cyclonedx-maven-plugin", "cyclonedx-maven-plugin", "cyclonedx-maven-plugin/output/bom.json",
     "resolved Maven graph with scopes; leaks provided scope unlabelled; cannot see plugins or BOM imports"),
    ("sbom-plus-maven-plugin", "build plugin (Maven, whole build)", "sbom-plus-maven-plugin", "sbom-plus-maven-plugin", "sbom-plus-maven-plugin/output/sbom-plus-cyclonedx.json",
     "the only tool that names build plugins, plugin dependencies and BOM imports, all labelled scope=excluded; the 2026-11-11 local build adds hashes, suppliers, licences and references and leads on both axes; Maven-only, so bundled npm packages and the Boot jarmode jar are missed"),
    ("cyclonedx-gradle-plugin", "build plugin (Gradle)", None, "cyclonedx-gradle-plugin", "cyclonedx-gradle-plugin/output/bom.json",
     "per-configuration selection; labels test deps via cdx:maven:package:test"),
    ("cyclonedx-npm", "ecosystem CLI (npm)", "cyclonedx-npm", "cyclonedx-npm", "cyclonedx-npm/output/node.prod-only.cdx.json",
     "lockfile-faithful npm graph with dev labels; cannot see what a bundler or prepack hook did"),
    ("cyclonedx-python", "ecosystem CLI (pip, Poetry, Pipenv)", "cyclonedx-python", "cyclonedx-python", "cyclonedx-python/output/python.environment.cdx.json",
     "environment mode sees everything installed, including PEP 517 backend outputs; requirements mode sees only what is declared"),
    ("cyclonedx-gomod", "ecosystem CLI (Go)", None, "cyclonedx-gomod", "cyclonedx-gomod/output/go.app.cdx.json",
     "module vs application vs binary views; needs a git commit for version detection"),
    ("cargo-cyclonedx", "ecosystem CLI (Rust)", None, "cargo-cyclonedx", "cargo-cyclonedx/output/rust.host-target.cdx.json",
     "per-target, per-binary; dev-dependencies excluded by construction"),
    ("cyclonedx-dotnet", "ecosystem CLI (.NET)", None, None, None,
     "project.assets based; sample-app .NET build is on demand so no scores here"),
    ("sbom4python", "ecosystem CLI (Python)", "sbom4python", None, "sbom4python/output/python.cdx.json",
     "installed-environment walk with a DOT graph; missed the PEP 517 generated module in this run"),
    ("jbom", "Java (jars and live JVMs)", None, None, None,
     "attach to a running JVM; not pre-run here (jar download blocked in the sandbox)"),
]


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def read_sbomqs_table():
    """tools/sbomqs/output/scores.txt -> {row path: (score, ntia, comps)}"""
    out = {}
    f = ROOT / "tools/sbomqs/output/scores.txt"
    if not f.exists():
        return out
    for line in f.read_text().splitlines()[1:]:
        m = re.match(r"^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*$", line)
        if not m:
            continue
        path, score, ntia, comps = m.groups()
        out[path] = (score, ntia, comps)
    return out


def read_criteria():
    """criteria/output/scores.json + expected -> per tool aggregates and the hidden-mechanism coverage."""
    f = ROOT / "criteria/output/scores.json"
    if not f.exists():
        return {}, {}, []
    scores = json.loads(f.read_text())
    expected = {t: json.loads((ROOT / "testcases" / t / "expected.json").read_text()) for t in scores}
    mechanisms = sorted({e["hidden"] for t in expected for e in expected[t]["shipped"] + expected[t]["not_shipped"] if e.get("hidden")})

    agg, hidden = {}, {}
    for t, r in scores.items():
        # which tools ran at any stage of this target
        ran = {x["tool"] for rows in r["stages"].values() for x in rows}
        # purl types each tool matched anywhere in this target; a hidden Maven component is not "applicable" to an npm-only tool
        ecos_seen = {}
        for rows in r["stages"].values():
            for x in rows:
                ecos_seen.setdefault(x["tool"], set()).update(k.split("/")[0] for k in x["hits"])
        for e in expected[t]["shipped"] + expected[t]["not_shipped"]:
            if not e.get("hidden"):
                continue
            for tool in ran:
                if ecos_seen[tool] and e["purl"].split("/")[0] not in ecos_seen[tool]:
                    continue
                found = any(x["hits"].get(e["purl"], [None])[0] == "exact"
                            for rows in r["stages"].values() for x in rows if x["tool"] == tool)
                h = hidden.setdefault(tool, {}).setdefault(e["hidden"], [0, 0])
                h[1] += 1
                h[0] += int(found)
        for st, rows in r["stages"].items():
            for x in rows:
                a = agg.setdefault(x["tool"], {"docs": 0, "recall": [], "stage": {s: [] for s in STAGES}, "wrong_purl": 0, "wrong_ver": 0,
                                               "leaked": 0, "labelled": 0, "extra": 0, "hash_ok": 0, "hash_emitted": 0,
                                               "q": [], "ntia": [], "ntia2021": [], "bsi": []})
                a["docs"] += 1
                rec = x["shipped_found"] / x["shipped_total"] if x["shipped_total"] else 0.0
                a["recall"].append(rec)
                a["stage"][st].append(rec)
                a["wrong_purl"] += len(x["wrong_purl"])
                a["wrong_ver"] += len(x["wrong_version"])
                a["leaked"] += len(x["leaked"])
                a["labelled"] += len(x["labelled"])
                a["extra"] += x["extra_labelled"]
                a["hash_ok"] += x["hash_ok"]
                a["hash_emitted"] += x["hash_emitted"]
                c = x["conformance"]
                for k, src in (("q", "quality"), ("ntia", "ntia"), ("ntia2021", "ntia-2021"), ("bsi", "bsi-v21")):
                    if c.get(src) is not None:
                        a[k].append(c[src])
    return agg, hidden, mechanisms


def read_scope_runs():
    """scope-runs/output -> {tool: {eco: {"runtime": n, "combined": n, "leaked": [...], "labelled": "k/n"}}}"""
    out = {}
    cmp_path = ROOT / "scope-runs/compare.py"
    base = ROOT / "scope-runs/output"
    if not cmp_path.exists() or not base.exists():
        return out
    cmp = load_module(cmp_path, "scope_compare")
    for tool_dir in sorted(p for p in base.iterdir() if p.is_dir()):
        for eco in sorted({f.name.split(".")[0] for f in tool_dir.glob("*.cdx.json")}):
            f_rt, f_cb = tool_dir / f"{eco}.runtime.cdx.json", tool_dir / f"{eco}.combined.cdx.json"
            rt = cmp.load(f_rt) if f_rt.exists() else None
            cb = cmp.load(f_cb) if f_cb.exists() else None
            leaked = sorted(cmp.dev_hits(rt.keys(), eco)) if rt is not None else []
            labelled = "–"
            if cb is not None:
                marks = [c for k, c in cb.items() if cmp.dev_hits([k], eco)]
                if marks:
                    labelled = f"{sum(1 for c in marks if cmp.dev_label(c))}/{len(marks)}"
                else:
                    labelled = "0 present"
            out.setdefault(tool_dir.name, {})[eco] = {
                "runtime": len(rt) if rt is not None else None, "combined": len(cb) if cb is not None else None,
                "leaked": leaked, "labelled": labelled}
    return out


def avg(l, fmt="{:.1f}"):
    return fmt.format(sum(l) / len(l)) if l else "–"


def pct(l):
    return f"{sum(l) / len(l):.0%}" if l else "–"


def main():
    sbomqs = read_sbomqs_table()
    agg, hidden, mechanisms = read_criteria()
    scope = read_scope_runs()

    L = []
    P = L.append
    P("# Tool comparison: every axis, one row per generator\n")
    P("Generated by `scripts/compare-tools.py` from the outputs of the three runs in this repo. Re-run those first if you change a tool "
      "version (`scripts/run-all.sh`, `scope-runs/run.sh`, `make`). `make` rebuilds this file; after the other two, run `python3 scripts/compare-tools.py`.\n")
    P("The three runs measure different things and the columns keep them apart:\n")
    P("- **Shape** (sbomqs on one representative sample-app SBOM per tool, and the mean sbomqs scores over every document the tool "
      "produced in the criteria run): does the document have the fields a baseline asks for. Says nothing about whether the inventory is right.")
    P("- **Truth** (criteria run against `testcases/`, ground truth in `testcases/<name>/expected.json`): did the tool name what actually ships, "
      "at the right version, under the right purl, without passing off test/dev/build tooling as shipped, with correct hashes.")
    P("- **Hidden** (same run): of the components that only exist because of shading, bundling, Maven plugin realms, BOM imports, "
      "npm `prepack` or PEP 517 backends, how many did the tool name at any stage it ran.")
    P("- **Scope** (scope-runs on sample-app): can the tool emit a runtime-only SBOM, did known test packages leak into it, and are dev "
      "packages in the combined SBOM labelled so a consumer can filter them.\n")
    P("Columns are blank where a tool was not part of a run. Full tables: [`criteria/SCORECARD.md`](criteria/SCORECARD.md), "
      "[`scope-runs/RESULTS.md`](scope-runs/RESULTS.md), [`tools/sbomqs/output/scores.txt`](tools/sbomqs/output/scores.txt).\n")

    # ---- 1. shape
    P("## 1. Shape: baseline conformance\n")
    P("sample-app columns are one document per tool (the one the top-level README uses). Criteria columns are averages over every "
      "document the tool produced at every stage of every target, so they are comparable across tools but lower than a single good document.\n")
    P("| Tool | Kind | sample-app comps | sample-app quality | sample-app NTIA | criteria docs | criteria quality | NTIA 2021 | NTIA/CISA 2026 | BSI v2.1 |")
    P("|---|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for folder, kind, cname, sname, srow, _ in ROSTER:
        s = sbomqs.get(srow) if srow else None
        a = agg.get(cname) if cname else None
        label = f"[`{folder}`](tools/{folder})" if cname != "trivy-rawfile" else "`trivy` (raw jar)"
        if s and s[0] == "unparseable":
            s = ("unparseable", "", "")
        P(f"| {label} | {kind} | {s[2] if s else ''} | {s[0] if s else ''} | {s[1] if s else ''} | "
          f"{a['docs'] if a else ''} | {avg(a['q']) if a else ''} | {avg(a['ntia2021']) if a else ''} | {avg(a['ntia']) if a else ''} | {avg(a['bsi']) if a else ''} |")
    P("")

    # ---- 2. truth
    P("## 2. Truth: content accuracy against ground truth\n")
    P("*Recall* = shipped components found at the exact version, averaged per document; the per-stage columns average only the documents "
      "produced at that stage. *Wrong purl* = right artifact and version under a guessed group. *Leaked* = non-shipping components listed with no "
      "scope or property to filter on. *Labelled* = non-shipping components that do carry such a label (the `+N` is labelled build tooling "
      "beyond the known list). *Hashes* = emitted hashes that match the digest of the jar inside the built artefact, checked at every stage. Sorted by mean recall.\n")
    P("| Tool | Docs | Recall (mean) | Source | Artefact | Image | Wrong purl | Wrong version | Leaked | Labelled | Hashes ok |")
    P("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    rows = []
    for folder, kind, cname, sname, srow, _ in ROSTER:
        a = agg.get(cname) if cname else None
        if not a:
            continue
        label = f"[`{folder}`](tools/{folder})" if cname != "trivy-rawfile" else "`trivy` (raw jar)"
        hashes = f"{a['hash_ok']}/{a['hash_emitted']}" if a["hash_emitted"] else "0 emitted"
        rows.append((sum(a["recall"]) / len(a["recall"]), f"| {label} | {a['docs']} | {pct(a['recall'])} | {pct(a['stage']['source'])} | "
                     f"{pct(a['stage']['artefact'])} | {pct(a['stage']['image'])} | {a['wrong_purl']} | {a['wrong_ver']} | {a['leaked']} | "
                     f"{a['labelled']}{'+' + str(a['extra']) if a['extra'] else ''} | {hashes} |"))
    for _, line in sorted(rows, key=lambda x: -x[0]):
        P(line)
    P("")

    # ---- 3. hidden
    P("## 3. Hidden: components that no manifest declares\n")
    P("Cells are found/applicable, where applicable counts the hidden components in every target the tool ran against, restricted to "
      "purl types the tool produced for that target (an npm-only tool is not asked about Maven plugins). A component counts as "
      "found if the tool named it at the exact version at any stage. Mechanisms: *shaded* = relocated bytecode inside another jar; *bundled* = "
      "Vite/esbuild output inside the jar; *plugin-realm* = Maven plugin or plugin dependency; *plugin-realm+bundled* = a plugin dependency "
      "that is also bundled; *bom-import* = an imported BOM; *prepack-generated* / *pep517-generated* = files written by a hook or build backend.\n")
    P("| Tool | " + " | ".join(mechanisms) + " | Total |")
    P("|---|" + "---:|" * (len(mechanisms) + 1))
    hrows = []
    for folder, kind, cname, sname, srow, _ in ROSTER:
        h = hidden.get(cname) if cname else None
        if not h:
            continue
        label = f"[`{folder}`](tools/{folder})" if cname != "trivy-rawfile" else "`trivy` (raw jar)"
        cells, tf, ta = [], 0, 0
        for m in mechanisms:
            f_, a_ = h.get(m, (0, 0))
            cells.append(f"{f_}/{a_}" if a_ else "–")
            tf += f_
            ta += a_
        hrows.append((tf / ta if ta else 0, f"| {label} | " + " | ".join(cells) + f" | {tf}/{ta} |"))
    for _, line in sorted(hrows, key=lambda x: -x[0]):
        P(line)
    P("")

    # ---- 4. scope
    P("## 4. Scope: runtime-only output and dev labelling (sample-app)\n")
    P("One cell per ecosystem the tool was run on: runtime component count / combined count, then whether known test packages leaked into "
      "the runtime SBOM, and how many of the dev packages in the combined SBOM carry a filterable label.\n")
    P("| Tool | Ecosystem | Runtime / combined | Leaked into runtime | Dev labelled in combined |")
    P("|---|---|---:|---|---:|")
    for folder, kind, cname, sname, srow, _ in ROSTER:
        sc = scope.get(sname) if sname else None
        if not sc:
            continue
        for eco, v in sc.items():
            rc = f"{v['runtime'] if v['runtime'] is not None else '–'} / {v['combined'] if v['combined'] is not None else '–'}"
            P(f"| [`{folder}`](tools/{folder}) | {eco} | {rc} | {', '.join(v['leaked']) or 'none'} | {v['labelled']} |")
    P("")

    # ---- 5. editorial
    P("## 5. Where each tool fits\n")
    P("Hand-written from the numbers above; revise when the runs change.\n")
    P("| Tool | Kind | Best used for |")
    P("|---|---|---|")
    for folder, kind, cname, sname, srow, note in ROSTER:
        label = f"[`{folder}`](tools/{folder})" if cname != "trivy-rawfile" else "`trivy` (raw jar)"
        P(f"| {label} | {kind} | {note} |")
    P("")
    P("`cyclonedx-cli` and `sbomqs` are consumers, not generators, and are not scored. Grype and `trivy sbom` appear inside the Syft and "
      "Trivy demos as vulnerability consumers.\n")
    P("## Reading the table\n")
    P("- Shape and truth are independent axes. As published, the highest-recall tools (SBOM+ 1.0.0, sbom-tool) had the lowest conformance because "
      "they emitted no hashes, licences or suppliers; the SBOM+ re-run with those fields added scores 9.9 on NTIA/CISA 2026 with the same inventory. "
      "The best-conforming scanner documents (cyclonedx-maven-plugin, Trivy on an unzipped artefact) still miss whole categories of content.")
    P("- Recall at image stage is low for everyone except the image-native tools, and near zero for cdxgen, because the Spring Boot jar is not opened.")
    P("- Only the build plugins see the plugin realm; only the source-stage tools see bundled npm packages; nothing sees a shaded library once "
      "its leftover `pom.properties` is gone. Those three facts are the argument for recording at build time rather than scanning afterwards "
      "(see [`criteria/README.md`](criteria/README.md)).")
    (ROOT / "COMPARISON.md").write_text("\n".join(L))
    print(f"wrote {ROOT / 'COMPARISON.md'}")


if __name__ == "__main__":
    main()
