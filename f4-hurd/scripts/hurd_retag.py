#!/usr/bin/env python3
"""Treat GOOS=hurd like solaris in //go:build constraints of a source tree.

  !solaris   ->  (!solaris && !hurd)      (code/stubs excluded on solaris are excluded on hurd)
  solaris    ->  (solaris || hurd)        (solaris-only code/stubs also apply on hurd)

Only //go:build lines that mention `solaris` and not yet `hurd` are touched.
File-name based constraints (*_solaris.go) cannot be handled this way and are
reported at the end. Usage: hurd_retag.py DIR [DIR...]
"""
import os, re, sys

changed, byname = [], []
for root_dir in sys.argv[1:]:
    for dp, dn, fn in os.walk(root_dir):
        if '/.git' in dp or 'golang.org/x/sys' in dp or 'golang.org/x/net' in dp:
            continue   # x/sys/unix is replaced by a hurd shim; x/net builds on it
        for f in fn:
            if not f.endswith('.go'):
                continue
            p = os.path.join(dp, f)
            if re.search(r'_solaris(_[a-z0-9]+)?\.go$', f):
                byname.append(p)
            try:
                s = open(p, encoding='utf-8').read()
            except Exception:
                continue
            m = re.search(r'^//go:build (.*)$', s, re.M)
            if not m or 'solaris' not in m.group(1) or re.search(r'\bhurd\b', m.group(1)):
                continue
            c = m.group(1)
            n = re.sub(r'!solaris\b', '(!solaris && !hurd)', c)
            n = re.sub(r'(?<![!\w(])solaris\b(?! && !hurd)', '(solaris || hurd)', n)
            if n != c:
                open(p, 'w', encoding='utf-8').write(s.replace(m.group(0), '//go:build ' + n, 1))
                changed.append(p)
print('retagged %d files' % len(changed))
for p in changed:
    print('  tag ', p)
print('name-based *_solaris*.go files (need hurd counterparts if used): %d' % len(byname))
for p in byname:
    print('  name', p)
