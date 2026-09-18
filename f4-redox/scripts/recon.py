#!/usr/bin/env python3
"""Recon for GOOS=redox: reads `go list -e -deps -json` output and reports
  1. packages that fail to load for redox (constraints exclude all files, etc.)
  2. every golang.org/x/sys/unix identifier used by non-test files that would be
     compiled for redox (the exact symbol set the x/sys shim has to provide)
  3. packages using package "syscall" identifiers that the redox syscall lacks are
     found later, by the compiler; not here.
usage: recon.py deps.json outdir"""
import json, os, re, sys, collections

raw = open(sys.argv[1]).read()
dec = json.JSONDecoder()
pkgs, i = [], 0
while i < len(raw):
    while i < len(raw) and raw[i].isspace():
        i += 1
    if i >= len(raw):
        break
    obj, j = dec.raw_decode(raw, i)
    pkgs.append(obj)
    i = j
out = sys.argv[2]
os.makedirs(out, exist_ok=True)

errs = []
for p in pkgs:
    e = p.get("Error")
    if e:
        errs.append(f'{p["ImportPath"]}: {e.get("Err","?").strip()[:300]}')
    for d in p.get("DepsErrors") or []:
        pass
open(f"{out}/pkg-errors.txt", "w").write("\n".join(errs) + "\n")

use = collections.defaultdict(set)   # symbol -> importing packages
pat = re.compile(r'\bunix\.([A-Za-z_][A-Za-z_0-9]*)')
scanned = 0
for p in pkgs:
    if "golang.org/x/sys/unix" not in (p.get("Imports") or []):
        continue
    d = p.get("Dir")
    for f in (p.get("GoFiles") or []) + (p.get("CgoFiles") or []):
        try:
            src = open(os.path.join(d, f), encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        scanned += 1
        src = re.sub(r'//[^\n]*', '', src)
        for m in pat.finditer(src):
            use[m.group(1)].add(p["ImportPath"])
lines = [f"{s}\t{','.join(sorted(v))[:200]}" for s, v in sorted(use.items())]
open(f"{out}/unix-symbols.txt", "w").write("\n".join(lines) + "\n")
imp = sorted({p["ImportPath"] for p in pkgs if "golang.org/x/sys/unix" in (p.get("Imports") or [])})
open(f"{out}/unix-importers.txt", "w").write("\n".join(imp) + "\n")
print(f"packages: {len(pkgs)}  with load errors: {len(errs)}  importing x/sys/unix: {len(imp)}  files scanned: {scanned}  distinct unix.* symbols: {len(use)}")
