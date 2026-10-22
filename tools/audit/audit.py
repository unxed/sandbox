#!/usr/bin/env python3
"""The audit: compares every version of every tracked file of the history of HEAD with the reference corpora.

Three comparisons (the parameters are the profile, fixed by tools/audit/run.sh):
  raw  the tokens of a file against the Pascal references; a chain of RAW tokens or more in common.
  ren  the same with every identifier made one token and every literal another; a chain of REN tokens or more,
       of which at least REN_IDENT_PERCENT percent are identifiers and keywords.
  lit  the literals of a file alone against the C and C++ references; a run of LIT literals or more in common
       with LIT_DISTINCT different significant values (numbers of 32 and more, strings of two characters
       and more) that is not a count.
A window that also occurs in an allowed source does not count. Consecutive windows in common make one match;
a match is identified by the SHA-256 of its comparison, its path and its tokens.

A match is proved by an entry of tools/audit/proofs.txt (tools/audit/prove.py). Output: a JSON report and the
line AUDIT PASS or AUDIT FAIL; exit code 0 or 1.
"""
import argparse
import hashlib
import json
import multiprocessing
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import prove  # noqa: E402
import tokens as T  # noqa: E402

G = {}  # shared with the worker processes (fork)


def git(repo, *args, data=None):
    return subprocess.run(["git", "-C", repo] + list(args), check=True, input=data,
                          stdout=subprocess.PIPE).stdout


def history_blobs(repo):
    """Returns (commits, [(blob, path)]): every distinct blob of every tracked file in the history of HEAD."""
    commits = git(repo, "rev-list", "HEAD").decode().split()
    raw = git(repo, "log", "--format=", "--root", "--raw", "--no-abbrev", "--no-renames", "-z", "HEAD")
    parts = raw.split(b"\0")
    seen = {}
    order = []
    i = 0
    while i < len(parts):
        p = parts[i]
        if p.startswith(b":") and i + 1 < len(parts):
            fields = p[1:].split()
            path = parts[i + 1].decode("utf-8", "surrogateescape")
            i += 2
            if len(fields) >= 5:
                new_mode, new_sha = fields[1].decode(), fields[3].decode()
                if new_sha.strip("0") and new_mode != "160000" and new_sha not in seen:
                    seen[new_sha] = path
                    order.append((new_sha, path))
            continue
        i += 1
    return commits, order


def read_blobs(repo, shas):
    out = git(repo, "cat-file", "--batch", data=("\n".join(shas) + "\n").encode() if shas else b"")
    blobs = {}
    pos = 0
    while pos < len(out):
        nl = out.index(b"\n", pos)
        header = out[pos:nl].split()
        size = int(header[2])
        blobs[header[0].decode()] = out[nl + 1:nl + 1 + size]
        pos = nl + 1 + size + 1
    return blobs


def decode(data):
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return data.decode("latin-1")


class Stream:
    """The three comparison streams of one file."""

    def __init__(self, text, lang):
        self.toks = T.tokenize(text, lang)
        self.keys = {"raw": T.raw_keys(self.toks), "ren": T.ren_keys(self.toks)}
        self.keys["lit"], self.litidx = T.lit_stream(self.toks)


def scan_ref(rel):
    """Worker: the windows of one reference file that occur in the files under audit."""
    try:
        with open(os.path.join(G["corpora"], rel), "rb") as fh:
            data = fh.read()
    except OSError:
        return []
    if len(data) > 40 * 1024 * 1024:
        return []
    lang = T.language(rel)
    toks = T.tokenize(decode(data), lang)
    streams = []
    if lang == "pascal":
        streams = [("raw", T.raw_keys(toks)), ("ren", T.ren_keys(toks))]
    elif lang == "c":
        streams = [("lit", T.lit_stream(toks)[0])]
    hits = {}
    for comp, keys in streams:
        width = G["width"][comp]
        index = G["index"][comp]
        for start, h in T.window_hashes(keys, width):
            cand = index.get(h)
            if not cand:
                continue
            window = keys[start:start + width]
            for fid, rs in cand:
                if G["files"][fid].keys[comp][rs:rs + width] == window:
                    hits.setdefault((comp, fid, rs), rel)
    return list(hits.items())


def allowed_hashes(allowed, width):
    sets = {"raw": set(), "ren": set(), "lit": set()}
    for logical in sorted(allowed.files):
        toks = allowed.tokens(logical)
        if toks is None:
            continue
        keys = {"raw": T.raw_keys(toks), "ren": T.ren_keys(toks), "lit": T.lit_stream(toks)[0]}
        for comp in sets:
            for _s, h in T.window_hashes(keys[comp], width[comp]):
                sets[comp].add(h)
    return sets


def groups(starts):
    """Consecutive runs of sorted integers as (first, last)."""
    out = []
    for s in starts:
        if out and out[-1][1] + 1 == s:
            out[-1][1] = s
        else:
            out.append([s, s])
    return out


def build_match(comp, entry, a, b, width, ref, args):
    """Builds the match of the window starts a..b of a file, or None when its conditions fail."""
    st = entry["stream"]
    last = b + width[comp] - 1
    if comp == "lit":
        ks = [k[1:] for k in st.keys["lit"][a:last + 1]]
        sig = set(k for k in ks if T.significant(k))
        if len(sig) < args.lit_distinct or T.is_count(ks):
            return None
        toks = [st.toks[st.litidx[k]] for k in range(a, last + 1)]
    else:
        toks = st.toks[a:last + 1]
        if comp == "ren":
            words = sum(1 for t in toks if t[0] in ("w", "i"))
            if words * 100 < args.ren_ident_percent * len(toks):
                return None
    digest = hashlib.sha256()
    digest.update((comp + "\n" + entry["path"] + "\n").encode())
    digest.update("\n".join(t[0] + t[1] for t in toks).encode("utf-8", "replace"))
    return {
        "comparison": comp,
        "id": digest.hexdigest(),
        "path": entry["path"],
        "blobs": [entry["blob"]],
        "lines": [toks[0][2], toks[-1][2]],
        "ntokens": len(toks),
        "tokens": [[t[0], t[1]] for t in toks],
        "reference": ref,
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--corpora", default=os.environ.get("CORPORA") or os.path.expanduser("~/.cache/tv3-corpora"))
    ap.add_argument("--repo", default=".")
    ap.add_argument("--raw", type=int, default=16)
    ap.add_argument("--ren", type=int, default=60)
    ap.add_argument("--ren-ident-percent", type=int, default=40)
    ap.add_argument("--lit", type=int, default=12)
    ap.add_argument("--lit-distinct", type=int, default=6)
    ap.add_argument("--proofs", default=None)
    ap.add_argument("--api-names", default=None)
    ap.add_argument("--out", default="audit.json")
    ap.add_argument("--workers", type=int, default=os.cpu_count() or 2)
    args = ap.parse_args(argv)

    t0 = time.time()
    width = {"raw": args.raw, "ren": args.ren, "lit": args.lit}
    repo = args.repo
    proofs_file = args.proofs or os.path.join(repo, "tools/audit/proofs.txt")
    apidoc = args.api_names or os.path.join(repo, "docs/API-NAMES.md")

    commits, blobs = history_blobs(repo)
    contents = read_blobs(repo, [b for b, _p in blobs])
    files = []
    for blob, path in blobs:
        text = contents[blob].decode("utf-8", "replace")
        files.append({"blob": blob, "path": path, "stream": Stream(text, T.language(path))})

    # references and allowed sources
    refs = []
    listing = os.path.join(args.corpora, "references.txt")
    if os.path.exists(listing):
        with open(listing, encoding="utf-8") as fh:
            refs = [ln.rstrip("\n") for ln in fh if ln.strip()]
    corpora = {}
    for rel in refs:
        name = rel.split("/", 1)[0]
        corpora[name] = corpora.get(name, 0) + 1
    allowed = prove.Allowed(args.corpora, os.path.join(repo, "tools/audit/facts"))
    skip = allowed_hashes(allowed, width)

    index = {"raw": {}, "ren": {}, "lit": {}}
    for fid, f in enumerate(files):
        for comp in index:
            for start, h in T.window_hashes(f["stream"].keys[comp], width[comp]):
                index[comp].setdefault(h, []).append((fid, start))
    G["corpora"] = args.corpora
    G["width"] = width
    G["index"] = index
    G["files"] = [f["stream"] for f in files]

    hits = {}
    if refs:
        ctx = multiprocessing.get_context("fork")
        with ctx.Pool(max(1, args.workers)) as pool:
            for res in pool.imap_unordered(scan_ref, refs, chunksize=16):
                for key, rel in res:
                    old = hits.get(key)
                    if old is None or rel < old:
                        hits[key] = rel

    # matches
    per_file = {}
    for (comp, fid, start), rel in hits.items():
        per_file.setdefault((comp, fid), {})[start] = rel
    matches = {}
    for (comp, fid), starts in sorted(per_file.items()):
        keys = files[fid]["stream"].keys[comp]
        good = []
        for s in sorted(starts):
            window = keys[s:s + width[comp]]
            # recompute the hash of the window to compare it with the allowed sources
            for st, h in T.window_hashes(window, width[comp]):
                if h not in skip[comp]:
                    good.append(s)
        for a, b in groups(good):
            m = build_match(comp, files[fid], a, b, width, starts[a], args)
            if m is None:
                continue
            key = (m["comparison"], m["id"])
            if key in matches:
                if files[fid]["blob"] not in matches[key]["blobs"]:
                    matches[key]["blobs"].append(files[fid]["blob"])
            else:
                matches[key] = m
    match_list = [matches[k] for k in sorted(matches)]

    # proofs
    names = prove.api_names(apidoc)
    invalid = []
    by_key = {(m["comparison"], m["id"], m["path"]): m for m in match_list}
    for m in match_list:
        m["proved"] = False
        m["proof"] = None
    for no, comp, mid, path, proof in prove.load_proofs(proofs_file):
        where = "%s:%d" % (os.path.relpath(proofs_file, repo), no)
        if comp is None:
            invalid.append({"line": where, "reason": "malformed line"})
            continue
        m = by_key.get((comp, mid, path))
        if m is None:
            invalid.append({"line": where, "reason": "no such match"})
            continue
        ok, why = prove.check_proof(m, proof, allowed, names)
        if ok:
            m["proved"] = True
            m["proof"] = proof
        else:
            invalid.append({"line": where, "reason": why})

    unproved = [m for m in match_list if not m["proved"]]
    head = git(repo, "rev-parse", "HEAD").decode().strip()
    report = {
        "profile": {"raw": args.raw, "ren": args.ren, "ren_ident_percent": args.ren_ident_percent,
                    "lit": args.lit, "lit_distinct": args.lit_distinct},
        "corpora": sorted(corpora),
        "corpus_files": corpora,
        "references": len(refs),
        "allowed": len(allowed.files),
        "head": head,
        "commits": len(commits),
        "scope": "history",
        "versions": len(files),
        "matches": match_list,
        "invalid_proofs": invalid,
        "seconds": round(time.time() - t0, 1),
        "pass": bool(refs) and not unproved and not invalid,
    }
    with open(args.out, "w") as fh:
        json.dump(report, fh, indent=1)
    for m in unproved:
        print("MATCH %s %s lines %d-%d (%d tokens) id %s reference %s" % (
            m["comparison"], m["path"], m["lines"][0], m["lines"][1], m["ntokens"], m["id"], m["reference"]))
    for e in invalid:
        print("INVALID PROOF %s: %s" % (e["line"], e["reason"]))
    print("references %d, allowed %d, versions %d, matches %d, unproved %d" % (
        len(refs), len(allowed.files), len(files), len(match_list), len(unproved)))
    print("AUDIT PASS" if report["pass"] else "AUDIT FAIL")
    return 0 if report["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
