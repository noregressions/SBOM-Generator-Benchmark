#!/usr/bin/env python3
"""Report on an arbitrary source tree (./scan): the same tools and the same conformance scoring as the evaluator, but
with no ground truth unless you supply one. Without ground truth nobody can say which tool is right, so the report
shows where the tools disagree instead.

  tree_report.py detect <tree> <name> <expected.json>    work out what the tree is and write the stage definitions
  tree_report.py report <expected.json> <sboms-dir> <report-dir>    write report.md, report.html and scores.json

`detect` reads SCAN_ARTEFACT, SCAN_IMAGE, SCAN_EXCLUDE (space separated), SCAN_OUT and SCAN_EXPECTED from the environment.
Standard library only; `report` needs sbomqs and cyclonedx (cli) on PATH, like score.py.
"""
import datetime, html, json, os, sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import score          # noqa: E402  load_sbom, conformance, score_file
import build_site     # noqa: E402  CSS and table helpers

STAGES = score.STAGES
SKIP_DIRS = {"node_modules", "target", "build", "dist", ".git", ".venv", "venv", ".gradle", ".maven-repo", "__pycache__"}
e = html.escape


# ------------------------------------------------------------------------------------------------------------ detect
def find_first(tree, filename, depth=2):
    """Shallowest directory (relative to tree) holding `filename`, ignoring build and cache directories."""
    level = [tree]
    for _ in range(depth + 1):
        nxt = []
        for d in sorted(level):
            if (d / filename).is_file():
                return d.relative_to(tree).as_posix() or "."
            try:
                nxt += [c for c in d.iterdir() if c.is_dir() and c.name not in SKIP_DIRS and not c.name.startswith(".")]
            except OSError:
                pass
        level = nxt
    return None


def detect(tree, name, out):
    env = os.environ.get
    report_dir = env("SCAN_OUT") or "sbom-report"
    source = {"path": ".", "exclude": ["/" + report_dir] + ["/" + x.strip("/") for x in (env("SCAN_EXCLUDE") or "").split()]}
    found = []
    if (tree / "pom.xml").is_file():
        source["maven"] = "aggregate" if "<modules>" in (tree / "pom.xml").read_text(errors="replace") else "single"
        found.append(f"Maven ({source['maven']})")
    npm = find_first(tree, "package.json")
    if npm:
        source["npm"] = npm
        found.append(f"npm ({npm}/package.json)")
    req = find_first(tree, "requirements.txt")
    if req:
        source["python"] = (req + "/requirements.txt").removeprefix("./")
        found.append(f"Python ({source['python']})")
    exp = {"target": name, "title": f"Scan of {name}", "stages": {"source": source}, "shipped": [], "not_shipped": [], "ecosystems": []}

    art = env("SCAN_ARTEFACT")
    if art:
        p = tree / art
        if not p.exists():
            sys.exit(f"--artefact {art}: not found inside the tree")
        kind = ("war" if p.suffix == ".war" else "jar") if p.is_file() else ("venv" if (p / "bin" / "python").exists() else "dir")
        exp["stages"]["artefact"] = {"path": art, "kind": kind}
        found.append(f"artefact {art} ({kind})")
    if env("SCAN_IMAGE"):
        exp["stages"]["image"] = {"tag": env("SCAN_IMAGE")}       # no dockerfile: the image already exists
        found.append(f"image {env('SCAN_IMAGE')}")

    truth = env("SCAN_EXPECTED")
    if truth:
        t = json.loads((tree / truth).read_text())
        for k in ("shipped", "not_shipped", "not_shipped_prefixes", "ecosystems", "maven_repo_local"):
            if k in t:
                exp[k] = t[k]
        for st in ("artefact",):                                  # embedded_jars lets hashes be checked against the real archive
            if st in exp["stages"] and "embedded_jars" in (t.get("stages", {}).get(st) or {}):
                exp["stages"][st]["embedded_jars"] = t["stages"][st]["embedded_jars"]
        exp["has_truth"] = True
        found.append(f"ground truth from {truth}")
    Path(out).write_text(json.dumps(exp, indent=2) + "\n")
    print("   detected: " + ("; ".join(found) if found else "no build files the native generators know; scanners only"))


# ------------------------------------------------------------------------------------------------------------ report
def ptype(key):
    return (key.split("/")[0].replace("pkg:", "") if key.startswith("pkg:") else "") .replace("?", "") or "no purl"


def base_of(key):
    return score.split_key(key)[0]


def analyse(exp, sboms):
    """Load every document, score it, and work out where the tools agree and where they do not."""
    truth = bool(exp.get("has_truth"))
    jar_hashes = {}
    stages = {}
    for st in STAGES:
        d = sboms / st
        if not d.is_dir():
            continue
        docs = []
        for p in sorted(d.iterdir()):
            if not p.name.endswith((".cdx.json", ".spdx.json")):
                continue
            fmt, _, comps = score.load_sbom(p)
            comps = [c for c in comps if not c.primary]
            doc = {"tool": score.tool_name(p), "file": f"sboms/{st}/{p.name}", "format": fmt, "components": len(comps),
                   "keys": {c.key for c in comps}, "types": defaultdict(int),
                   "labelled": sum(1 for c in comps if c.label), "hashed": sum(1 for c in comps if c.hashes),
                   "conformance": score.conformance(p, fmt)}
            for c in comps:
                doc["types"][ptype(c.key)] += 1
            if truth:
                doc["accuracy"] = score.score_file(p, exp, set(exp.get("ecosystems") or []), jar_hashes, st)
            docs.append(doc)
        if not docs:
            continue
        # A tool takes part in an ecosystem at this stage if it reported anything of that purl type. A component is
        # "missed" by a tool only within ecosystems it takes part in, so a Maven plugin is not blamed for npm packages.
        finders = defaultdict(set)
        for doc in docs:
            for k in doc["keys"]:
                finders[k].add(doc["tool"])
        for doc in docs:
            mine = set(doc["types"])
            doc["unique"] = sorted(k for k in doc["keys"] if len(finders[k]) == 1)
            doc["missed"] = sorted(k for k, who in finders.items() if doc["tool"] not in who and len(who) >= 2 and ptype(k) in mine)
        versions = defaultdict(lambda: defaultdict(set))          # package -> version -> tools
        for k, who in finders.items():
            b, v = score.split_key(k)
            versions[b][v or "(none)"] |= who
        # Several versions from one tool means several versions are present; it is a disagreement only when no single
        # tool reports them all.
        conflicts = {b: {v: sorted(t) for v, t in vs.items()} for b, vs in versions.items()
                     if len(vs) > 1 and not set.intersection(*vs.values())}
        stages[st] = {"docs": docs, "finders": {k: sorted(v) for k, v in finders.items()}, "conflicts": conflicts}
    return stages


def conf(doc, key):
    v = doc["conformance"].get(key)
    return "–" if v is None else f"{v:.1f}"


def short(key):
    b, v = score.split_key(key)
    return b.replace("pkg:", "", 1) + ("@" + v if v else "")


def write_markdown(exp, stages, out, meta):
    L = []; P = L.append
    truth = bool(exp.get("has_truth"))
    P(f"# SBOM report: {exp['target']}\n")
    P(f"Generated {meta['date']} by the SBOM evaluator's `scan` command. The documents are in `sboms/<stage>/`.\n")
    if not truth:
        P("There is no ground truth for this tree, so nothing here says which tool is right. The conformance columns say whether "
          "each document has the fields the baselines ask for; the agreement columns say where the tools differ, which is where to look first.\n")
    for st, s in stages.items():
        P(f"## {st.capitalize()} stage\n")
        head = "| Tool | Format | Valid | Components | Unique | Missed | Labelled | With hashes | Quality | NTIA 2021 | NTIA/CISA 2026 | BSI v2.1 |"
        sep = "|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
        if truth:
            head += " Shipped found | Leaked | Wrong purl |"; sep += "---:|---:|---:|"
        P(head); P(sep)
        for d in s["docs"]:
            row = (f'| {d["tool"]} | {d["conformance"].get("spec") or d["format"]} | {d["conformance"].get("valid", "")} | {d["components"]} | '
                   f'{len(d["unique"])} | {len(d["missed"])} | {d["labelled"]} | {d["hashed"]} | {conf(d, "quality")} | {conf(d, "ntia-2021")} | {conf(d, "ntia")} | {conf(d, "bsi-v21")} |')
            if truth:
                a = d["accuracy"]
                row += f' {a["shipped_found"]}/{a["shipped_total"]} | {len(a["leaked"])} | {len(a["wrong_purl"])} |'
            P(row)
        P("")
        P("*Unique*: components only this tool reported. *Missed*: components at least two other tools reported and this one did not, "
          "counted only in ecosystems where this tool reported something. *Labelled*: components marked as dev, test, optional or excluded.\n")
        types = sorted({t for d in s["docs"] for t in d["types"]})
        if len(types) > 1:
            P("| Tool | " + " | ".join(types) + " |"); P("|---|" + "---:|" * len(types))
            for d in s["docs"]:
                P(f'| {d["tool"]} | ' + " | ".join(str(d["types"].get(t, 0)) for t in types) + " |")
            P("")
        if s["conflicts"]:
            P(f"### Version disagreements ({len(s['conflicts'])})\n")
            P("The same package at different versions, where no single tool reports them all. One tool is wrong, or each is seeing part of the picture.\n")
            for b in sorted(s["conflicts"])[:40]:
                P(f"- `{b.replace('pkg:', '', 1)}`: " + "; ".join(f"**{v}** ({', '.join(t)})" for v, t in sorted(s["conflicts"][b].items())))
            if len(s["conflicts"]) > 40:
                P(f"- … and {len(s['conflicts']) - 40} more in `scores.json`")
            P("")
        for d in s["docs"]:
            if d["unique"]:
                more = f" … and {len(d['unique']) - 12} more" if len(d["unique"]) > 12 else ""
                P(f'- **{d["tool"]}** alone reports: ' + ", ".join(f"`{short(k)}`" for k in d["unique"][:12]) + more)
        P("")
    (out / "report.md").write_text("\n".join(L))


def write_html(exp, stages, out, meta):
    truth = bool(exp.get("has_truth"))
    B = [f"<h1>SBOM report: {e(exp['target'])}</h1>"]
    B.append('<p class="lede">Every applicable SBOM generator, run against this tree, with the documents scored for conformance and compared with each other.</p>')
    B.append('<dl class="meta">' + "".join(f"<dt>{e(k)}</dt><dd>{v}</dd>" for k, v in [
        ("Generated", e(meta["date"])), ("Stages", e(", ".join(stages))), ("Documents", str(sum(len(s["docs"]) for s in stages.values()))),
        ("Tool image", f'<code>{e(meta.get("image", "")[:19])}</code>'), ("Ground truth", "supplied" if truth else "none")]) + "</dl>")
    if not truth:
        B.append("<p>There is no ground truth for this tree, so nothing here says which tool is right. The conformance columns say whether each document "
                 "has the fields the baselines ask for. The agreement columns say where the tools differ, and that is where to look first.</p>")
    for st, s in stages.items():
        B.append(f"<h2>{e(st.capitalize())} stage</h2>")
        headers = [("Tool", ""), ("Format", ""), ("Valid", ""), ("Components", "num"), ("Unique", "num"), ("Missed", "num"), ("Labelled", "num"),
                   ("With hashes", "num"), ("Quality", "num"), ("NTIA 2021", "num"), ("NTIA/CISA 2026", "num"), ("BSI v2.1", "num"), ("FSCT v3", "num")]
        if truth:
            headers += [("Shipped found", "num"), ("Leaked", "num"), ("Wrong purl", "num")]
        rows = []
        for d in s["docs"]:
            valid = d["conformance"].get("valid", "")
            r = (f'<tr><td><a href="{e(d["file"])}">{e(d["tool"])}</a></td><td>{e(d["conformance"].get("spec") or d["format"])}</td>'
                 f'<td class="{"bad" if valid == "INVALID" else ""}">{e(valid)}</td><td class="num">{d["components"]}</td>'
                 f'<td class="num">{len(d["unique"])}</td>' + build_site.count(len(d["missed"]), bad=True)
                 + f'<td class="num">{d["labelled"]}</td><td class="num">{d["hashed"]}</td>'
                 + "".join(f'<td class="num">{conf(d, k)}</td>' for k in ("quality", "ntia-2021", "ntia", "bsi-v21", "fsct")))
            if truth:
                a = d["accuracy"]
                r += build_site.bar(a["shipped_found"], a["shipped_total"]) + build_site.count(len(a["leaked"]), bad=True) + build_site.count(len(a["wrong_purl"]), bad=True)
            rows.append(r + "</tr>")
        B.append(build_site.table(headers, rows))
        B.append('<ul class="notes"><li><b>Unique</b>: components only this tool reported.</li>'
                 "<li><b>Missed</b>: components at least two other tools reported and this one did not, counted only in ecosystems where this tool reported something.</li>"
                 "<li><b>Labelled</b>: components marked as dev, test, optional or excluded, so a consumer can filter them.</li>"
                 "<li><b>Quality</b> is sbomqs' own score; the baseline columns are <code>sbomqs compliance</code> totals out of 10. They measure fields, not truth.</li></ul>")
        types = sorted({t for d in s["docs"] for t in d["types"]})
        if len(types) > 1:
            B.append("<h3>Components by ecosystem</h3>")
            B.append(build_site.table([("Tool", "")] + [(e(t), "num") for t in types],
                                      [f'<tr><td>{e(d["tool"])}</td>' + "".join(f'<td class="num">{d["types"].get(t, 0)}</td>' for t in types) + "</tr>" for d in s["docs"]]))
        if s["conflicts"]:
            B.append(f"<h3>Version disagreements ({len(s['conflicts'])})</h3><p>The same package at different versions, where no single tool reports them all. One tool is wrong, or each is seeing part of the picture.</p>")
            rows = [f'<tr><td><code>{e(b.replace("pkg:", "", 1))}</code></td><td class="wrap">'
                    + "; ".join(f"<b>{e(v)}</b> <span class='muted'>({e(', '.join(t))})</span>" for v, t in sorted(s["conflicts"][b].items())) + "</td></tr>"
                    for b in sorted(s["conflicts"])[:200]]
            B.append(build_site.table([("Package", ""), ("Versions reported", "")], rows))
        tools = [d["tool"] for d in s["docs"]]
        disputed = sorted(k for k, who in s["finders"].items() if 1 < len(who) < len(tools) or (len(who) == 1 and len(tools) > 1))
        if disputed:
            cap = 400
            rows = [f'<tr><td><code>{e(short(k))}</code></td>' + "".join(
                        f'<td><span class="cell"><i class="{"Y" if t in s["finders"][k] else "n"}">{"Y" if t in s["finders"][k] else "n"}</i></span></td>' for t in tools) + "</tr>"
                    for k in disputed[:cap]]
            note = f" Showing the first {cap}; the full list is in <code>scores.json</code>." if len(disputed) > cap else ""
            B.append(f"<details><summary><b>Components the tools disagree on ({len(disputed)})</b></summary><p class='muted'>Reported by some tools at this stage and not others.{note}</p>"
                     + build_site.table([("Component", "")] + [(e(t), "") for t in tools], rows) + "</details>")
    body = "\n".join(B)
    (out / "report.html").write_text(f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>SBOM report: {e(exp['target'])}</title>
<style>{build_site.CSS}
details {{ margin:16px 0; }} summary {{ cursor:pointer; }}</style></head>
<body><main>
{body}
</main><footer>Generated by the SBOM evaluator's <code>scan</code> command. Tool versions are in <code>run.json</code>.</footer></body></html>
""")


def report(expected, sboms, out):
    exp = json.loads(Path(expected).read_text())
    sboms, out = Path(sboms), Path(out)
    stages = analyse(exp, sboms)
    versions = {}
    vf = Path(__file__).resolve().parent.parent / "tools" / "versions.env"
    if vf.exists():
        versions = dict(l.split("=", 1) for l in vf.read_text().splitlines() if l and not l.startswith("#"))
    meta = {"date": datetime.date.today().isoformat(), "image": os.environ.get("EVALUATOR_IMAGE_ID", ""), "versions": versions}
    (out / "run.json").write_text(json.dumps(meta, indent=2) + "\n")
    slim = {st: {"documents": [{k: (sorted(v) if isinstance(v, set) else dict(v) if isinstance(v, defaultdict) else v) for k, v in d.items() if k != "keys"} for d in s["docs"]],
                 "components": s["finders"], "version_conflicts": s["conflicts"]} for st, s in stages.items()}
    (out / "scores.json").write_text(json.dumps(slim, indent=1, default=list))
    write_markdown(exp, stages, out, meta)
    write_html(exp, stages, out, meta)
    for p in sboms.rglob("*.conformance.json"):      # score.py's cache files; not part of the report
        p.unlink()
    print(f"   {sum(len(s['docs']) for s in stages.values())} documents scored")


if __name__ == "__main__":
    if len(sys.argv) == 5 and sys.argv[1] == "detect":
        detect(Path(sys.argv[2]), sys.argv[3], sys.argv[4])
    elif len(sys.argv) == 5 and sys.argv[1] == "report":
        report(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        sys.exit(__doc__)
