#!/usr/bin/env python3
"""The verdict: reads the reports of the audit, of the provenance check (with --history) and of the text check,
all of the same HEAD, and prints exactly one of two outputs and nothing else.

  TASK SOLVED: ...   when every item holds
  NOT READY:         followed by one line per unmet item

Usage: verdict.py --audit audit.json --provenance provenance.json --text text.json --dossier LINK
Exit code 0 for TASK SOLVED, 1 for NOT READY.
"""
import argparse
import json
import sys

PROFILE = {"raw": 16, "ren": 60, "ren_ident_percent": 40, "lit": 12, "lit_distinct": 6}
CORPORA = ["bp7tv", "dn151", "dn214", "far2l", "fpc322", "fpcmain", "fpide", "jserv", "rhtv", "sigala", "tv20",
           "tvdelphi"]

SOLVED = ("TASK SOLVED: the code of unxed/tv3 is clean: every file of every version of the history is translated "
          "from magiblot/tvision or magiblot/tvterm or written from a specification without access to other code; "
          "there are no matches with the known implementations of Turbo Vision except the mechanically proved "
          "translation; dossier: %s.")


def load(path):
    try:
        with open(path) as fh:
            return json.load(fh), None
    except (OSError, ValueError) as exc:
        return None, "%s: cannot be read (%s)" % (path, exc)


def judge(audit, prov, text):
    """Returns the list of unmet items (empty when every item holds). Each report may be None."""
    items = []
    if audit is None:
        items.append("audit: no report")
    if prov is None:
        items.append("provenance check: no report")
    if text is None:
        items.append("text check: no report")
    if items:
        return items

    heads = {"audit": audit.get("head"), "provenance check": prov.get("head"), "text check": text.get("head")}
    if len(set(heads.values())) != 1 or None in heads.values():
        items.append("reports of different commits: " + ", ".join("%s %s" % (k, str(v)[:12]) for k, v in heads.items()))

    # the audit
    if audit.get("scope") != "history":
        items.append("audit: scope is not the whole history")
    if audit.get("profile") != PROFILE:
        items.append("audit: profile %s is not %s" % (audit.get("profile"), PROFILE))
    present = set(audit.get("corpora") or [])
    for name in CORPORA:
        if name not in present:
            items.append("audit: corpus %s is missing" % name)
    if not audit.get("references"):
        items.append("audit: no reference files")
    for m in audit.get("matches") or []:
        if not m.get("proved"):
            items.append("audit: unproved match %s %s %s lines %s-%s" % (
                m.get("comparison"), m.get("path"), m.get("id"), (m.get("lines") or ["?", "?"])[0],
                (m.get("lines") or ["?", "?"])[1]))
    for e in audit.get("invalid_proofs") or []:
        items.append("audit: invalid proof at %s: %s" % (e.get("line"), e.get("reason")))
    if not audit.get("pass"):
        if not any(i.startswith("audit:") for i in items):
            items.append("audit: the audit did not pass")

    # the provenance check
    if not prov.get("history"):
        items.append("provenance check: not run with --history")
    for e in prov.get("errors") or []:
        items.append("provenance check: " + e)
    for m in prov.get("missing_versions") or []:
        items.append("provenance check: missing version " + m)
    for p in prov.get("pending_versions") or []:
        items.append("provenance check: pending version " + p)

    # the text check
    if not text.get("commits"):
        items.append("text check: the messages of the commits were not checked")
    for f in text.get("findings") or []:
        items.append("text check: %s: %s %s" % (f.get("where"), f.get("rule"), f.get("detail")))
    if not text.get("pass") and not text.get("findings"):
        items.append("text check: did not pass")

    # one history for all
    counts = {audit.get("commits"), prov.get("commits"), text.get("commits")}
    if len(counts) != 1:
        items.append("reports cover different numbers of commits: audit %s, provenance check %s, text check %s" % (
            audit.get("commits"), prov.get("commits"), text.get("commits")))
    return items


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--audit", required=True)
    ap.add_argument("--provenance", required=True)
    ap.add_argument("--text", required=True)
    ap.add_argument("--dossier", required=True, help="link to provenance/INDEX.md at the commit")
    args = ap.parse_args(argv)
    reports = []
    missing = []
    for p in (args.audit, args.provenance, args.text):
        data, err = load(p)
        reports.append(data)
        if err:
            missing.append(err)
    items = missing + judge(*reports) if not missing else missing
    if items:
        print("NOT READY:")
        for i in items:
            print(i)
        return 1
    print(SOLVED % args.dossier)
    return 0


if __name__ == "__main__":
    sys.exit(main())
