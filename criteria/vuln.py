#!/usr/bin/env python3
"""Can each SBOM support a security decision? Match every generated SBOM against a vulnerability database and compare
the advisories it raises with the advisories that apply to what really ships.

The reference comes from the ground truth: the advisories Grype raises for exactly the shipped components of a test
case (testcases/<name>/expected.json) are the ones a true SBOM would surface. Every component each tool's SBOM names
is looked up in the same Grype database, by package URL, and every advisory that comes back is put in one of these
groups:

  found            an advisory in the reference, raised against the right component at the right version
  missed           an advisory in the reference that this SBOM does not raise (the component is absent or misnamed)
  false alarm      raised against something known not to ship, which the SBOM does not mark as such
  filterable       raised against something known not to ship, which the SBOM does mark (a consumer can filter it)
  wrong version    raised against a shipped component at a version that does not ship
  other            raised against a shipped component but not in the reference, or against a component in neither list

Only components in the test case's ecosystems are considered, so operating-system packages in images are left out.

Usage: vuln.py  -> writes criteria/output/vulns.json
Needs grype on PATH and its database (it tries one update first, then runs offline). Without grype it leaves any
existing vulns.json alone and exits 0, so scoring and the site still work.
"""
import json, os, shutil, subprocess, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import score  # noqa: E402

OUT = score.OUT
ENV = dict(os.environ, GRYPE_DB_AUTO_UPDATE="false", GRYPE_CHECK_FOR_APP_UPDATE="false")


def run(cmd, **kw):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=600, **kw)
    except Exception as ex:                      # noqa: BLE001  a missing or hung grype must not stop the report
        return subprocess.CompletedProcess(cmd, 1, "", str(ex))


def bare(purl):
    """A package URL without qualifiers or subpath, in the encoding the tool wrote it in."""
    return purl.split("?")[0].split("#")[0]


def grype_lookup(purls, workdir):
    """One Grype run for every distinct package URL in the whole benchmark -> {purl key: [(advisory id, severity, fixed-in)]}.

    Loading the vulnerability database takes Grype several seconds, so running it once per SBOM would take a quarter
    of an hour. Instead every component any SBOM names is looked up once, by package URL, and each SBOM is then judged
    on the advisories its own components would raise. That is also the fair comparison: the same lookup for the
    ground truth and for every tool, with nothing but the identity each document gives a component.
    """
    comps = [{"type": "library", "name": score.split_key(k)[0].split("/", 1)[-1], "version": score.split_key(k)[1], "purl": raw, "bom-ref": k}
             for k, raw in sorted(purls.items())]
    f = workdir / "all-components.cdx.json"
    f.write_text(json.dumps({"bomFormat": "CycloneDX", "specVersion": "1.6", "version": 1, "components": comps}))
    r = run(["grype", f"sbom:{f}", "-o", "json", "-q"], env=ENV)
    f.unlink()
    if r.returncode != 0 or not r.stdout.strip():
        return None
    found = {}
    for m in json.loads(r.stdout).get("matches") or []:
        a, v = m.get("artifact") or {}, m.get("vulnerability") or {}
        if a.get("purl") and v.get("id"):
            found.setdefault(score.purl_key(a["purl"]), set()).add((v["id"], v.get("severity", ""), ",".join((v.get("fix") or {}).get("versions") or [])))
    return found


def db_info():
    r = run(["grype", "db", "status", "-o", "json"], env=ENV)
    try:
        j = json.loads(r.stdout)
        return {"built": (j.get("built") or "")[:10], "schema": j.get("schemaVersion") or j.get("schema") or ""}
    except Exception:                             # noqa: BLE001
        return {}


def classify(comps, advisories, exp, ecos, stage, reference):
    """Sort the advisories one SBOM's components raise into the groups described at the top of this file."""
    exact, wild = score.index_expected(exp)
    prefixes = [p for p in exp.get("not_shipped_prefixes", ()) if stage in p.get("stages", score.STAGES)]
    found, false_alarm, groups = set(), set(), {"filterable": 0, "wrong_version": 0, "other": 0}
    seen = set()
    for c in comps:
        if c.key in seen or c.key.split("/")[0].replace("pkg:", "") not in ecos:
            continue
        seen.add(c.key)
        hits = advisories.get(c.key)
        if not hits:
            continue
        entry, how = score.match(c, exact, wild, prefixes)
        for vid, sev, _fix in hits:
            if entry is None or entry.get("ships") is None:
                groups["filterable" if c.label else "other"] += 1      # e.g. build tooling the SBOM lists and marks
            elif entry["ships"]:
                if how == "exact" and (entry["purl"], vid) in reference:
                    found.add((entry["purl"], vid))
                elif how == "wrong-version":
                    groups["wrong_version"] += 1
                else:
                    groups["other"] += 1
            elif c.label:
                groups["filterable"] += 1
            else:
                false_alarm.add((c.key, vid, sev))
    missed = sorted(reference - found)
    return {"found": len(found), "total": len(reference), "missed": [list(x) for x in missed],
            "false_alarms": [list(x) for x in sorted(false_alarm)], **groups}


def main():
    if not shutil.which("grype"):
        print("vuln.py: grype is not installed; leaving vulns.json as it is")
        return
    run(["grype", "db", "update"])                # one attempt; if offline, the database already on disk is used
    db = db_info()
    version = (run(["grype", "version", "-o", "json"]).stdout or "{}")
    try:
        version = json.loads(version).get("version", "")
    except Exception:                             # noqa: BLE001
        version = ""
    # pass 1: read every document once, and collect every package URL worth looking up
    loaded, purls = {}, {}
    for ef in sorted(score.CASES.glob("*/expected.json")):
        exp = json.loads(ef.read_text())
        t = exp["target"]
        if not (OUT / t).is_dir():
            continue
        ecos = set(exp["ecosystems"])
        for e in exp["shipped"]:
            k = score.purl_key(e["purl"])
            if score.split_key(k)[1] not in ("", "*"):          # no fixed version, nothing to match an advisory against
                purls.setdefault(k, bare(e["purl"]))
        docs = {}
        for st in score.STAGES:
            d = OUT / t / st
            if not d.is_dir():
                continue
            docs[st] = []
            for p in sorted(x for x in d.iterdir() if x.name.endswith((".cdx.json", ".spdx.json"))):
                _fmt, _doc, comps = score.load_sbom(p)
                comps = [c for c in comps if c.purl and c.key.split("/")[0].replace("pkg:", "") in ecos]
                for c in comps:
                    purls.setdefault(c.key, bare(c.purl))
                docs[st].append((score.tool_name(p), comps))
        loaded[t] = (exp, ecos, docs)

    advisories = grype_lookup(purls, OUT)
    if advisories is None:
        print("vuln.py: grype could not match the components; leaving vulns.json as it is")
        return

    # pass 2: the reference for each test case, then each document against it
    result = {"database": db, "grype": version, "components_looked_up": len(purls), "cases": {}}
    for t, (exp, ecos, docs) in loaded.items():
        ref_rows, reference = [], set()
        for e in exp["shipped"]:
            for vid, sev, fix in sorted(advisories.get(score.purl_key(e["purl"]), ())):
                if (e["purl"], vid) in reference:
                    continue                      # the database can hold one advisory under two severities
                reference.add((e["purl"], vid))
                ref_rows.append({"purl": e["purl"], "id": vid, "severity": sev, "fixed_in": fix, "hidden": e.get("hidden", "")})
        result["cases"][t] = {"reference": ref_rows,
                              "stages": {st: [{"tool": tool, **classify(comps, advisories, exp, ecos, st, reference)} for tool, comps in rows]
                                         for st, rows in docs.items()}}
    (OUT / "vulns.json").write_text(json.dumps(result, indent=1) + "\n")
    n = sum(len(r) for c in result["cases"].values() for r in c["stages"].values())
    print(f"wrote {OUT / 'vulns.json'} ({n} SBOMs, {len(purls)} distinct components looked up, database built {db.get('built', '?')})")


if __name__ == "__main__":
    main()
