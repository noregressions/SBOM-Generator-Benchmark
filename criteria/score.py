#!/usr/bin/env python3
"""Score generated SBOMs against ground truth (testcases/<name>/expected.json) and against the published baselines.

Two scores, kept apart on purpose:
  * CONTENT ACCURACY: did the document name what actually ships (recall), at the right version, without listing things that
    do not ship unlabelled (leaks), and did it record a correct hash where the bytes are available. Hidden dependencies
    (shaded, bundled, plugin-realm, hook-generated) get their own matrix.
  * BASELINE CONFORMANCE: sbomqs quality score plus its compliance profiles (NTIA 2021, CISA/NTIA 2026, BSI TR-03183-2 v2.1,
    Framing Software Component Transparency v3) and schema validity via cyclonedx-cli.

Usage: score.py  -> writes criteria/SCORECARD.md and criteria/output/scores.json
Needs only python3 + sbomqs + cyclonedx (cli) on PATH; no third-party Python modules.
"""
import hashlib, json, os, subprocess, sys, zipfile, fnmatch
from pathlib import Path

CRIT = Path(__file__).resolve().parent
OUT = Path(os.environ.get("CRITERIA_OUT") or CRIT / "output")          # generate.sh honours the same two variables
CASES = Path(os.environ.get("CRITERIA_CASES") or CRIT.parent / "testcases")
STAGES = ["source", "artefact", "image"]
PKG_TYPES = {"library", "application", "framework", None}
PROFILES = [("ntia-2021", "NTIA 2021"), ("ntia", "NTIA/CISA 2026"), ("bsi-v21", "BSI v2.1"), ("fsct", "FSCT v3")]


# ----------------------------------------------------------------------------------------------------------- helpers
def purl_key(p):
    """pkg:type/ns/name@version with qualifiers/subpath stripped; '@*' means any version."""
    p = p.split("?")[0].split("#")[0]
    p = p.replace("%40", "@").replace("%2F", "/").replace("%2f", "/")  # sbom-tool percent-encodes scoped npm names
    return p


def split_key(k):
    base, _, ver = k.rpartition("@")
    if not base or base == "pkg:npm/":  # scoped npm names start with @; version is after the last @
        return k, ""
    return base, ver


def tool_name(path):
    n = path.name
    for suf in (".cdx.json", ".spdx.json"):
        if n.endswith(suf):
            return n[: -len(suf)]
    return n


class Comp:
    __slots__ = ("key", "name", "version", "purl", "label", "hashes", "ctype", "primary")

    def __init__(self, key, name, version, purl, label, hashes, ctype, primary=False):
        self.key, self.name, self.version, self.purl, self.label, self.hashes, self.ctype = key, name, version, purl, label, hashes, ctype
        self.primary = primary


def dev_label(c):
    if c.get("scope") in ("optional", "excluded"):
        return "scope=" + c["scope"]
    for p in c.get("properties") or []:
        n, v = p.get("name", ""), str(p.get("value", "")).lower()
        if v == "true" and any(w in n.lower() for w in ("development", "dev", "test")):
            return n
    return None


def load_sbom(path):
    """Return (format, list[Comp]) for CycloneDX JSON or SPDX JSON. Non-package components are dropped."""
    doc = json.loads(path.read_text())
    comps = []
    if doc.get("bomFormat") == "CycloneDX":
        items = [(c, False) for c in doc.get("components") or []]
        meta = (doc.get("metadata") or {}).get("component")
        if meta:
            items.append((meta, True))
        for c, primary in items:
            if c.get("type") not in PKG_TYPES:
                continue
            purl = c.get("purl") or ""
            key = purl_key(purl) if purl else f'pkg:?/{c.get("group","")}/{c.get("name","")}@{c.get("version","")}'
            hashes = {h["alg"].lower().replace("-", ""): h["content"].lower() for h in c.get("hashes") or [] if "alg" in h}
            comps.append(Comp(key, c.get("name", ""), c.get("version", "") or "", purl, dev_label(c), hashes, c.get("type"), primary))
        return "cyclonedx", doc, comps
    if "spdxVersion" in doc:
        for p in doc.get("packages") or []:
            purl = ""
            for r in p.get("externalRefs") or []:
                if r.get("referenceType") == "purl":
                    purl = r.get("referenceLocator", "")
                    break
            if not purl or purl.startswith("pkg:swid/"):
                continue  # file-level or synthetic packages
            key = purl_key(purl)
            hashes = {h["algorithm"].lower().replace("-", ""): h["checksumValue"].lower() for h in p.get("checksums") or [] if "algorithm" in h}
            comps.append(Comp(key, p.get("name", ""), p.get("versionInfo", "") or "", purl, None, hashes, "library"))
        return "spdx", doc, comps
    return "unknown", doc, comps


def sh(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=300).stdout
    except Exception:
        return ""


def conformance(path, fmt):
    """sbomqs quality + compliance profiles; cyclonedx-cli validate. Cached next to the file."""
    cache = path.with_suffix(".conformance.json")
    if cache.exists() and cache.stat().st_mtime >= path.stat().st_mtime:
        return json.loads(cache.read_text())
    r = {}
    try:
        j = json.loads(sh(["sbomqs", "score", "--json", str(path)]))["files"][0]
        r["quality"] = round(j.get("sbom_quality_score", 0), 1)
        r["grade"] = j.get("grade", "")
        r["spec"] = f'{j.get("spec","")} {j.get("spec_version","")}'
    except Exception:
        r["quality"] = None
    for flag, _ in PROFILES:
        try:
            j = json.loads(sh(["sbomqs", "compliance", "--" + flag, "--json", str(path)]))
            r[flag] = round(j["summary"]["total_score"], 1)
        except Exception:
            r[flag] = None
    if fmt == "cyclonedx":
        out = sh(["cyclonedx", "validate", "--input-file", str(path), "--input-format", "json", "--fail-on-errors"])
        r["valid"] = "valid" if "BOM validated successfully" in out else ("INVALID" if out else "?")
    else:
        r["valid"] = "n/a"
    cache.write_text(json.dumps(r))
    return r


def artefact_hashes(exp, scenario):
    """sha256/sha1/md5 of every jar physically inside the artefact (BOOT-INF/lib, WEB-INF/lib) keyed by file name."""
    st = exp["stages"].get("artefact") or {}
    pre = st.get("embedded_jars")
    if not pre:
        return {}
    res = {}
    with zipfile.ZipFile(scenario / st["path"]) as z:
        for n in z.namelist():
            if n.startswith(pre) and n.endswith(".jar"):
                b = z.read(n)
                res[Path(n).name] = {"sha256": hashlib.sha256(b).hexdigest(), "sha1": hashlib.sha1(b).hexdigest(), "md5": hashlib.md5(b).hexdigest()}
    return res


# ----------------------------------------------------------------------------------------------------------- scoring
def index_expected(exp):
    """Returns dict key->entry for exact keys and dict base->entry for wildcard (@*) entries."""
    exact, wild = {}, {}
    for lst, shipped in ((exp["shipped"], True), (exp["not_shipped"], False), (exp.get("neutral", []), None)):
        for e in lst:
            e = dict(e, ships=shipped)
            for p in [e["purl"]] + e.get("alt", []):
                base, ver = split_key(purl_key(p))
                (wild if ver == "*" else exact)[purl_key(p) if ver != "*" else base] = e
    return exact, wild


def match(comp, exact, wild, prefixes=()):
    """-> (entry, kind) kind in exact | wrong-version | wrong-purl | None.
    wrong-purl: same ecosystem, artifact name and version as an expected component but a different namespace/group, which
    is what scanners produce when a jar carries no pom.properties and the group is guessed from the file name."""
    if comp.key in exact:
        return exact[comp.key], "exact"
    if comp.key.startswith("pkg:?/"):  # no purl at all (SBOM+ metadata.component, for instance): match on name@version
        for k, e in exact.items():
            b, v = split_key(k)
            if b.rsplit("/", 1)[-1] == comp.name:
                return e, ("exact" if v == comp.version else "wrong-version")
        return None, None
    base, ver = split_key(comp.key)
    if base in wild:
        return wild[base], "exact"
    for k, e in exact.items():
        if split_key(k)[0] == base:
            return e, "wrong-version"
    eco, _, _ = base.partition("/")
    leaf = base.rsplit("/", 1)[-1]
    for k, e in exact.items():
        b, v = split_key(k)
        if b.partition("/")[0] == eco and b.rsplit("/", 1)[-1] == leaf and v == ver:
            return e, "wrong-purl"
    for pre in prefixes:  # whole families known not to ship (a provided-scope API closure, a build toolchain)
        if comp.key.startswith(pre["prefix"]):
            return dict(pre, purl=comp.key, ships=False), "exact"
    return None, None


def score_file(path, exp, ecos, jar_hashes, stage):
    fmt, doc, comps = load_sbom(path)
    exact, wild = index_expected(exp)
    in_eco = [c for c in comps if c.key.split("/")[0].replace("pkg:", "") in ecos or c.primary]
    found_ship, wrong_ver, wrong_purl, leaked, labelled_ok, unexpected, extra_labelled = set(), set(), set(), set(), set(), [], []
    hits = {}  # expected purl -> (how found: exact/wrong-version, label)
    for c in in_eco:
        e, how = match(c, exact, wild, [p for p in exp.get("not_shipped_prefixes", ()) if stage in p.get("stages", STAGES)])
        if e is None:
            # a labelled (excluded/optional/dev) component we did not list is still correctly labelled non-shipping, and a
            # tool's guess at the primary component is judged by recall, not as noise
            if not c.label and not c.primary:
                unexpected.append(c.key)
            elif c.label:
                extra_labelled.append(c.key)
            continue
        if e["ships"] is None:  # neutral: a known graph node that is neither shipped nor a leak (starter POMs, parents)
            continue
        prev = hits.get(e["purl"])
        if prev is None or (prev[0] != "exact" and how == "exact"):
            hits[e["purl"]] = (how, c.label, c.version)
        if how == "wrong-version":
            wrong_ver.add(e["purl"])
            continue
        if how == "wrong-purl":
            wrong_purl.add(e["purl"])
            continue
        if e["ships"]:
            found_ship.add(e["purl"])
        elif c.label:
            labelled_ok.add(e["purl"])
        else:
            leaked.add(e["purl"])
    wrong_ver = {p for p in wrong_ver if hits[p][0] == "wrong-version"}
    wrong_purl = {p for p in wrong_purl if hits[p][0] == "wrong-purl"}
    shipped = [e["purl"] for e in exp["shipped"]]
    # hashes: compare tool hashes to real digests of jars inside the artefact (only possible for maven jars we can locate)
    h_emit = h_ok = 0
    if jar_hashes:
        for c in in_eco:
            if not c.hashes or not c.key.startswith("pkg:maven/"):
                continue
            base, ver = split_key(c.key)
            real = jar_hashes.get(f"{base.rsplit('/',1)[-1]}-{ver}.jar")
            if not real:
                continue
            h_emit += 1
            if any(c.hashes.get(a) == real[a] for a in ("sha256", "sha1", "md5")):
                h_ok += 1
    tools_meta = (doc.get("metadata") or {}).get("tools") if fmt == "cyclonedx" else None
    return {
        "file": path.name, "tool": tool_name(path), "format": fmt,
        "components": len(comps), "in_scope": len(in_eco),
        "shipped_found": len(found_ship), "shipped_total": len(shipped),
        "wrong_version": sorted(wrong_ver), "wrong_purl": sorted(wrong_purl), "leaked": sorted(leaked), "labelled": sorted(labelled_ok),
        "unexpected": sorted(set(unexpected)), "extra_labelled": len(set(extra_labelled)), "hits": hits,
        "hash_emitted": h_emit, "hash_ok": h_ok,
        "conformance": conformance(path, fmt),
    }


def short(purl):
    base, ver = split_key(purl_key(purl))
    return base.rsplit("/", 1)[-1] + ("@" + ver if ver else "")


def main():
    results = {}
    for ef in sorted(CASES.glob("*/expected.json")):
        exp = json.loads(ef.read_text())
        t = exp["target"]
        scenario = ef.parent / "project"
        try:
            jar_hashes = artefact_hashes(exp, scenario)
        except Exception:
            jar_hashes = {}
        results[t] = {"expected": exp, "stages": {}}
        for st in STAGES:
            d = OUT / t / st
            if not d.is_dir():
                continue
            files = sorted(p for p in d.iterdir() if p.name.endswith((".cdx.json", ".spdx.json")))
            results[t]["stages"][st] = [score_file(p, exp, set(exp["ecosystems"]), jar_hashes, st) for p in files]   # the jars inside the built artefact are the reference at every stage

    (OUT / "scores.json").write_text(json.dumps({t: {"stages": r["stages"]} for t, r in results.items()}, indent=1, default=list))
    write_scorecard(results)


def write_scorecard(results):
    L = []
    P = L.append
    P("# SBOM scorecard: content accuracy vs baseline conformance\n")
    P("Generated by `criteria/score.py` from `criteria/output/`. Test cases are in `testcases/`; ground truth is in "
      "`testcases/<name>/expected.json`. Every target is scanned at up to three stages: **source** (the checkout, minus build "
      "outputs and caches), **artefact** (the built jar/war/tarball/venv) and **image** (the container).\n")
    P("Column meanings: *in scope* = package components whose purl type is one of the target's ecosystems (OS packages in images are "
      "ignored). *Shipped found* = recall against the list of what is really in the artefact, version-exact. *Wrong ver* = named, but "
      "at a version that does not ship. *Wrong purl* = right artifact and version under the wrong group/namespace, so no advisory "
      "database will match it. *Leaked* = things that do not ship (test, dev, build tooling, provided, BOM imports) listed "
      "with no scope/property a consumer could filter on. *Labelled* = the same things listed **with** such a label, which is correct (a `+N` is further labelled components outside the known list, typically the rest of the build tooling). "
      "*Unexpected* = in-scope components in neither list (at image stage these are mostly the server's own libraries). *Hashes ok* = "
      "tool hashes that match the real digest of the jar inside the built artefact, over hashes the tool emitted for those jars; checked at every stage, since the shipped jar is the reference whichever stage the document came from.\n")

    # ---- 1. content accuracy per target
    P("## 1. Content accuracy\n")
    for t, r in results.items():
        exp = r["expected"]
        P(f"### {t}\n\n*{exp['title']}*  \nShipped components: {len(exp['shipped'])}; known non-shipping: {len(exp['not_shipped'])}; ecosystems: {', '.join(exp['ecosystems'])}\n")
        P("| Stage | Tool | Fmt | Comps | In scope | Shipped found | Wrong ver | Wrong purl | Leaked | Labelled | Unexpected | Hashes ok |")
        P("|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
        for st, rows in r["stages"].items():
            for x in rows:
                hashes = f'{x["hash_ok"]}/{x["hash_emitted"]}' if x["hash_emitted"] else "0/0"
                P(f'| {st} | {x["tool"]} | {x["format"][:3]} | {x["components"]} | {x["in_scope"]} | {x["shipped_found"]}/{x["shipped_total"]} | '
                  f'{len(x["wrong_version"])} | {len(x["wrong_purl"])} | {len(x["leaked"])} | {len(x["labelled"])}{"+" + str(x["extra_labelled"]) if x["extra_labelled"] else ""} | {len(x["unexpected"])} | {hashes} |')
        P("")
        # detail lines worth reading
        notes = []
        for st, rows in r["stages"].items():
            for x in rows:
                if x["wrong_version"]:
                    notes.append(f'- **{st}/{x["tool"]}** wrong version: ' + ", ".join(short(p) + "→" + x["hits"][p][2] for p in x["wrong_version"]))
                if x["wrong_purl"]:
                    notes.append(f'- **{st}/{x["tool"]}** wrong purl (group guessed): ' + ", ".join(short(p) for p in x["wrong_purl"][:6]) + (" …" if len(x["wrong_purl"]) > 6 else ""))
                if x["leaked"]:
                    notes.append(f'- **{st}/{x["tool"]}** leaked unlabelled: ' + ", ".join(short(p) for p in x["leaked"][:8]) + (" …" if len(x["leaked"]) > 8 else ""))
                if x["unexpected"] and st != "image":
                    notes.append(f'- **{st}/{x["tool"]}** unexpected ({len(x["unexpected"])}): ' + ", ".join(short(p) for p in x["unexpected"][:8]) + (" …" if len(x["unexpected"]) > 8 else ""))
        if notes:
            P("\n".join(notes) + "\n")

    # ---- 2. hidden dependency matrix
    P("## 2. Hidden dependencies: who names them, and where\n")
    P("Cells show one letter per stage the target has, in order source / artefact / image: **Y** named at the right version, "
      "**v** named at a wrong version, **p** named under a wrong purl, **n** not named, **·** tool did not run at that stage. "
      "For build-tooling rows a **Y** only counts as correct if the row is also labelled (see leaks above); here we only ask whether the tool knew it existed.\n")
    tools = []
    for r in results.values():
        for rows in r["stages"].values():
            for x in rows:
                if x["tool"] not in tools:
                    tools.append(x["tool"])
    tools.sort()
    P("| Target | Component | Mechanism | " + " | ".join(tools) + " |")
    P("|---|---|---|" + "---|" * len(tools))
    for t, r in results.items():
        exp = r["expected"]
        stages_present = [s for s in STAGES if s in r["stages"]]
        for e in exp["shipped"] + exp["not_shipped"]:
            if not e.get("hidden"):
                continue
            cells = []
            for tool in tools:
                s = ""
                for st in stages_present:
                    x = next((x for x in r["stages"][st] if x["tool"] == tool), None)
                    if x is None:
                        s += "·"
                    else:
                        h = x["hits"].get(e["purl"])
                        s += "n" if h is None else {"exact": "Y", "wrong-version": "v", "wrong-purl": "p"}[h[0]]
                cells.append(s)
            P(f'| {t} | {short(e["purl"])} | {e["hidden"]} | ' + " | ".join(cells) + " |")
    P("")

    # ---- 3. baseline conformance
    P("## 3. Baseline conformance (sbomqs)\n")
    P("Quality is sbomqs' own 0–10 score. The profile columns are sbomqs `compliance` totals (0–10) for NTIA 2021 minimum elements, "
      "the NTIA/CISA 2026 revision, BSI TR-03183-2 v2.1 and Framing Software Component Transparency v3. Valid = cyclonedx-cli schema validation (CycloneDX only).\n")
    P("| Target | Stage | Tool | Spec | Valid | Quality | " + " | ".join(n for _, n in PROFILES) + " | Shipped found |")
    P("|---|---|---|---|---|---:|" + "---:|" * len(PROFILES) + "---:|")
    for t, r in results.items():
        for st, rows in r["stages"].items():
            for x in rows:
                c = x["conformance"]
                q = "–" if c.get("quality") is None else c["quality"]
                prof = " | ".join("–" if c.get(f) is None else str(c[f]) for f, _ in PROFILES)
                P(f'| {t} | {st} | {x["tool"]} | {c.get("spec","")} | {c.get("valid","")} | {q} | {prof} | {x["shipped_found"]}/{x["shipped_total"]} |')
    P("")

    # ---- 4. the two scores side by side, per tool
    P("## 4. Per tool: conformance vs accuracy\n")
    P("Averages over every document the tool produced in this run. Recall is shipped-found divided by shipped-total, averaged per document. "
      "A high conformance score with low recall means a well-formed document about the wrong inventory.\n")
    agg = {}
    for r in results.values():
        for rows in r["stages"].values():
            for x in rows:
                a = agg.setdefault(x["tool"], {"n": 0, "q": [], "ntia": [], "bsi": [], "recall": [], "leak": 0, "label": 0, "docs": 0})
                a["docs"] += 1
                c = x["conformance"]
                if c.get("quality") is not None: a["q"].append(c["quality"])
                if c.get("ntia") is not None: a["ntia"].append(c["ntia"])
                if c.get("bsi-v21") is not None: a["bsi"].append(c["bsi-v21"])
                a["recall"].append(x["shipped_found"] / x["shipped_total"] if x["shipped_total"] else 0)
                a["leak"] += len(x["leaked"]); a["label"] += len(x["labelled"])
    avg = lambda l: f"{sum(l)/len(l):.1f}" if l else "–"
    P("| Tool | Docs | Quality | NTIA/CISA 2026 | BSI v2.1 | Mean recall | Leaked total | Labelled total |")
    P("|---|---:|---:|---:|---:|---:|---:|---:|")
    for tool, a in sorted(agg.items(), key=lambda kv: -sum(kv[1]["recall"]) / max(1, len(kv[1]["recall"]))):
        P(f'| {tool} | {a["docs"]} | {avg(a["q"])} | {avg(a["ntia"])} | {avg(a["bsi"])} | {sum(a["recall"])/len(a["recall"]):.0%} | {a["leak"]} | {a["label"]} |')
    P("")
    (CRIT / "SCORECARD.md").write_text("\n".join(L))
    print(f"wrote {CRIT / 'SCORECARD.md'}")


if __name__ == "__main__":
    main()
