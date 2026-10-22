#!/usr/bin/env python3
"""Checks the provenance records (provenance/<path>.json, one per tracked file).

Every tracked file has a record except the files under provenance/ and VERDICT.md. A record has the fields
path, kind, sources, inputs, implementer, proofs and versions (see docs/CLEANROOM.md).

  kind translation    sources: {source, commit, file, lines "A-B"}
  kind specification  sources: {specification}
  kind standard       sources: {document, url}
  kind verbatim       sources: one {source, commit, file, blob}
  kind new            no sources

Checks: the fields and their forms; the notice of a translated Pascal file; a verbatim file equals the blob of
its source; the named commit of a version holds the blob at the path; the proofs of a record are the lines of
tools/audit/proofs.txt of its path; provenance/INDEX.md is current. With --history every version of every file
in every commit of HEAD must be listed. Errors and missing versions give exit code 1; pending versions (a
version without commit, pull request or audit run) are reported, not errors.

Usage: provenance_lint.py [--repo DIR] [--history] [--write-index] [--json FILE]
"""
import argparse
import json
import os
import re
import subprocess
import sys

PINNED = {
    "magiblot/tvision": "b4831e2ca16652db327fb7cc964f1c8c2d512524",
    "magiblot/tvterm": "210eb23564da06c358d2623388939bb02f7f3419",
}
NOTICE_POINTER = {"magiblot/tvision": "COPYRIGHT.magiblot", "magiblot/tvterm": "COPYRIGHT.tvterm"}
FAR2L = "unxed/far2l@8030902caf42498e1612e5a393ab7fc489048f51:VTExts.md"
KINDS = ("translation", "specification", "standard", "verbatim", "new")
PASCAL_EXT = (".pas", ".pp", ".inc", ".lpr", ".dpr")
EXEMPT_FILES = ("VERDICT.md",)
HEX40 = re.compile(r"^[0-9a-f]{40}$")
HEX64 = re.compile(r"^[0-9a-f]{64}$")
LINES = re.compile(r"^[0-9]+-[0-9]+$")
INDEX_HEADER = [
    "# Provenance index",
    "",
    "| file | kind | sources | versions | pending versions | proofs |",
    "| --- | --- | --- | --- | --- | --- |",
]


def git(repo, *args):
    return subprocess.run(["git", "-C", repo] + list(args), check=True,
                          stdout=subprocess.PIPE).stdout


def exempt(path):
    return path.startswith("provenance/") or path in EXEMPT_FILES


def tracked(repo):
    raw = git(repo, "ls-files", "-z")
    return [p.decode("utf-8", "surrogateescape") for p in raw.split(b"\0") if p]


def blob_of(repo, path):
    return git(repo, "hash-object", os.path.join(repo, path)).decode().strip()


def source_text(src):
    """The 'sources' column of the index for a record."""
    kind = src.get("kind")
    items = src.get("sources") or []
    try:
        if kind == "translation":
            return "; ".join("%s:%s:%s" % (s["source"], s["file"], s["lines"]) for s in items)
        if kind == "specification":
            return "; ".join("specification:" + s["specification"] for s in items)
        if kind == "standard":
            return "; ".join(s["document"] for s in items)
        if kind == "verbatim":
            return "; ".join("%s:%s@%s" % (s["source"], s["file"], s["blob"][:7]) for s in items)
    except (KeyError, TypeError):
        return "?"
    return "-"


def is_pending(v):
    return v.get("commit") is None or v.get("pr") is None or v.get("audit_run") is None


def index_text(records):
    lines = list(INDEX_HEADER)
    for rel in sorted(records):
        r = records[rel]
        versions = r.get("versions") or []
        lines.append("| `%s` | %s | %s | %d | %d | %d |" % (
            r.get("path"), r.get("kind"), source_text(r), len(versions),
            sum(1 for v in versions if is_pending(v)), len(r.get("proofs") or [])))
    return "\n".join(lines) + "\n"


def load_proof_lines(repo):
    """Returns {path: set(match ids)} from tools/audit/proofs.txt."""
    result = {}
    p = os.path.join(repo, "tools/audit/proofs.txt")
    if os.path.exists(p):
        with open(p, encoding="utf-8") as fh:
            for line in fh:
                line = line.rstrip("\n")
                if not line.strip() or line.startswith("#"):
                    continue
                cols = line.split("\t")
                if len(cols) == 4:
                    result.setdefault(cols[2], set()).add(cols[1])
    return result


def check_origin(origin, kind, errors, where):
    outside = origin == FAR2L
    for src, commit in PINNED.items():
        if re.match(r"^%s@%s:.+$" % (re.escape(src), commit), origin):
            outside = True
    if outside:
        if kind == "new":
            errors.append("%s: kind new takes no outside source: %s" % (where, origin))
        return
    for prefix in ("repository:", "standard:", "specification:"):
        if origin.startswith(prefix) and len(origin) > len(prefix):
            return
    errors.append("%s: input origin not allowed: %s" % (where, origin))


def check_record(rec, rel, errors):
    """Checks the form of a record; returns True when it is usable for further checks."""
    where = rel
    for field in ("path", "kind", "sources", "inputs", "implementer", "proofs", "versions"):
        if field not in rec:
            errors.append("%s: field %s is missing" % (where, field))
            return False
    kind = rec["kind"]
    if kind not in KINDS:
        errors.append("%s: kind %r is not one of %s" % (where, kind, ", ".join(KINDS)))
        return False
    if not isinstance(rec["implementer"], str) or not rec["implementer"].strip():
        errors.append("%s: implementer is empty" % where)
    srcs = rec["sources"]
    if not isinstance(srcs, list):
        errors.append("%s: sources is not a list" % where)
        return False
    if kind == "new" and srcs:
        errors.append("%s: kind new has sources" % where)
    if kind != "new" and not srcs:
        errors.append("%s: kind %s has no sources" % (where, kind))
    if kind == "verbatim" and len(srcs) != 1:
        errors.append("%s: kind verbatim takes exactly one source" % where)
    for s in srcs:
        if not isinstance(s, dict):
            errors.append("%s: a source is not an object" % where)
            continue
        if kind in ("translation", "verbatim"):
            src = s.get("source")
            if src not in PINNED:
                errors.append("%s: source %r is not magiblot/tvision or magiblot/tvterm" % (where, src))
            elif s.get("commit") != PINNED[src]:
                errors.append("%s: commit of %s is not the pinned one" % (where, src))
            if not isinstance(s.get("file"), str) or not s.get("file"):
                errors.append("%s: source without file" % where)
            if kind == "translation" and not (isinstance(s.get("lines"), str) and LINES.match(s["lines"])):
                errors.append("%s: lines of a source are not of the form A-B" % where)
            if kind == "verbatim" and not (isinstance(s.get("blob"), str) and HEX40.match(s["blob"])):
                errors.append("%s: blob of the source is not a git blob id" % where)
        elif kind == "specification":
            if not isinstance(s.get("specification"), str) or not s.get("specification"):
                errors.append("%s: source without specification id" % where)
        elif kind == "standard":
            if not isinstance(s.get("document"), str) or not isinstance(s.get("url"), str):
                errors.append("%s: source without document and url" % where)
    inputs = rec["inputs"]
    if not isinstance(inputs, list):
        errors.append("%s: inputs is not a list" % where)
        return False
    origins = set()
    for i in inputs:
        if not isinstance(i, dict) or not isinstance(i.get("origin"), str) or not HEX64.match(str(i.get("sha256"))):
            errors.append("%s: an input is not {origin, sha256}" % where)
            continue
        origins.add(i["origin"])
        check_origin(i["origin"], kind, errors, where)
    if kind == "translation":
        for s in srcs:
            if isinstance(s, dict) and s.get("source") in PINNED:
                want = "%s@%s:%s" % (s["source"], PINNED[s["source"]], s.get("file"))
                if want not in origins:
                    errors.append("%s: source file is not among the inputs: %s" % (where, want))
    if kind == "specification":
        for s in srcs:
            if isinstance(s, dict) and ("specification:" + str(s.get("specification"))) not in origins:
                errors.append("%s: specification %s is not among the inputs" % (where, s.get("specification")))
    if not isinstance(rec["proofs"], list) or not all(isinstance(p, str) and HEX64.match(p) for p in rec["proofs"]):
        errors.append("%s: proofs is not a list of SHA-256 values" % where)
    vers = rec["versions"]
    if not isinstance(vers, list) or not vers:
        errors.append("%s: versions is empty" % where)
        return False
    seen = set()
    for v in vers:
        if not isinstance(v, dict) or any(k not in v for k in ("blob", "commit", "pr", "audit_run")):
            errors.append("%s: a version is not {blob, commit, pr, audit_run}" % where)
            return False
        if not (isinstance(v["blob"], str) and HEX40.match(v["blob"])):
            errors.append("%s: a version has a bad blob id" % where)
            return False
        if v["blob"] in seen:
            errors.append("%s: blob %s is listed twice" % (where, v["blob"]))
        seen.add(v["blob"])
        if v["commit"] is not None and not (isinstance(v["commit"], str) and HEX40.match(v["commit"])):
            errors.append("%s: a version has a bad commit" % where)
        for k in ("pr", "audit_run"):
            if v[k] is not None and not isinstance(v[k], str):
                errors.append("%s: %s of a version is not a link" % (where, k))
    return True


def run(repo, history=False, write_index=False):
    errors = []
    missing = []
    pending = []
    files = [p for p in tracked(repo) if not exempt(p)]
    records = {}
    prov_dir = os.path.join(repo, "provenance")
    for base, _dirs, names in os.walk(prov_dir):
        for name in names:
            if not name.endswith(".json"):
                continue
            full = os.path.join(base, name)
            rel = os.path.relpath(full, repo).replace(os.sep, "/")
            try:
                with open(full, encoding="utf-8") as fh:
                    records[rel] = json.load(fh)
            except (ValueError, OSError) as exc:
                errors.append("%s: not readable: %s" % (rel, exc))
    by_path = {}
    for rel, rec in sorted(records.items()):
        path = rec.get("path") if isinstance(rec, dict) else None
        if not isinstance(path, str) or rel != "provenance/%s.json" % path:
            errors.append("%s: path field does not match the name of the record" % rel)
            continue
        by_path[path] = rec
    proof_lines = load_proof_lines(repo)

    for path in files:
        if path not in by_path:
            errors.append("%s: no provenance record" % path)

    history_paths = {}
    commits = 0
    if history:
        revs = git(repo, "rev-list", "HEAD").decode().split()
        commits = len(revs)
        for c in revs:
            raw = git(repo, "ls-tree", "-r", "-z", c)
            for ent in raw.split(b"\0"):
                if not ent:
                    continue
                meta, _, p = ent.partition(b"\t")
                fields = meta.split()
                if fields[0] == b"160000":
                    continue
                p = p.decode("utf-8", "surrogateescape")
                if exempt(p):
                    continue
                history_paths.setdefault(p, {}).setdefault(fields[2].decode(), c)

    for path, rec in sorted(by_path.items()):
        rel = "provenance/%s.json" % path
        if not check_record(rec, rel, errors):
            continue
        in_tree = path in files
        if history and not in_tree and path not in history_paths:
            errors.append("%s: record of a file that is not in the history" % rel)
        listed = {v["blob"]: v for v in rec["versions"]}
        for v in rec["versions"]:
            if is_pending(v):
                pending.append("%s %s" % (path, v["blob"]))
            if v["commit"] is not None:
                try:
                    got = subprocess.run(["git", "-C", repo, "rev-parse", "%s:%s" % (v["commit"], path)], stdout=subprocess.PIPE,
                                         stderr=subprocess.DEVNULL, check=True).stdout.decode().strip()
                except subprocess.CalledProcessError:
                    got = None
                if got != v["blob"]:
                    errors.append("%s: commit %s does not hold blob %s at %s" % (rel, v["commit"][:12], v["blob"], path))
        if in_tree:
            cur = blob_of(repo, path)
            if cur not in listed:
                errors.append("%s: the current version %s of %s is not listed" % (rel, cur, path))
            if rec["kind"] == "verbatim":
                want = rec["sources"][0].get("blob") if rec["sources"] else None
                for v in rec["versions"]:
                    if v["blob"] != want:
                        errors.append("%s: version %s differs from the blob of its source" % (rel, v["blob"]))
                if cur != want:
                    errors.append("%s: the file differs from the blob of its source" % path)
            if rec["kind"] == "translation" and path.lower().endswith(PASCAL_EXT):
                with open(os.path.join(repo, path), encoding="utf-8", errors="replace") as fh:
                    text = fh.read()
                for s in rec["sources"]:
                    if not isinstance(s, dict) or s.get("source") not in PINNED:
                        continue
                    commit = PINNED[s["source"]]
                    pattern = r"Translated from %s @ (%s)" % (re.escape(s["source"]), "|".join(
                        re.escape(commit[:n]) for n in range(40, 6, -1)))
                    if not re.search(pattern, text):
                        errors.append("%s: no notice 'Translated from %s @ %s'" % (path, s["source"], commit[:7]))
                    if NOTICE_POINTER[s["source"]] not in text:
                        errors.append("%s: no pointer to %s" % (path, NOTICE_POINTER[s["source"]]))
            if rec["kind"] != "translation" and path.lower().endswith(PASCAL_EXT):
                with open(os.path.join(repo, path), encoding="utf-8", errors="replace") as fh:
                    if re.search(r"Translated from magiblot/tv(ision|term) @", fh.read()):
                        errors.append("%s: carries a translation notice but the record is kind %s" % (path, rec["kind"]))
        wanted = proof_lines.get(path, set())
        if set(rec["proofs"]) != wanted:
            errors.append("%s: proofs differ from the lines of tools/audit/proofs.txt" % rel)
        if history:
            for blob, c in sorted(history_paths.get(path, {}).items()):
                if blob not in listed:
                    missing.append("%s %s (commit %s)" % (path, blob, c[:12]))
    for path in proof_lines:
        if path not in by_path:
            errors.append("tools/audit/proofs.txt: proof for %s, which has no record" % path)

    text = index_text({rel: rec for rel, rec in records.items() if isinstance(rec, dict)})
    index_path = os.path.join(repo, "provenance/INDEX.md")
    if write_index:
        os.makedirs(os.path.dirname(index_path), exist_ok=True)
        with open(index_path, "w", encoding="utf-8") as fh:
            fh.write(text)
    else:
        try:
            with open(index_path, encoding="utf-8") as fh:
                current = fh.read()
        except OSError:
            current = None
        if current != text:
            errors.append("provenance/INDEX.md is not current")
    head = git(repo, "rev-parse", "HEAD").decode().strip()
    return {"head": head, "history": history, "commits": commits, "files": len(files),
            "records": len(by_path), "errors": errors, "missing_versions": missing,
            "pending_versions": pending}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--repo", default=".")
    ap.add_argument("--history", action="store_true")
    ap.add_argument("--write-index", action="store_true")
    ap.add_argument("--json")
    args = ap.parse_args(argv)
    report = run(args.repo, args.history, args.write_index)
    if args.json:
        with open(args.json, "w") as fh:
            json.dump(report, fh, indent=1)
    for e in report["errors"]:
        print("ERROR " + e)
    for m in report["missing_versions"]:
        print("MISSING VERSION " + m)
    print("files %d, records %d, errors %d, missing versions %d, pending versions %d" % (
        report["files"], report["records"], len(report["errors"]), len(report["missing_versions"]),
        len(report["pending_versions"])))
    bad = report["errors"] or report["missing_versions"]
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
