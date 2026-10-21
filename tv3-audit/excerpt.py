#!/usr/bin/env python3
"""Turns the output of tv3's tools/audit/run.sh into a review sheet and a list of match keys.

usage: excerpt.py AUDIT_OUTPUT REPO_DIR CORPORA SHEET KEYS

Each match line of borrow-audit.py is `<type> <len>  <file>:<a>-<b>  ==  <ref>:<line>`. A file of the history is
written as /tmp/borrow-audit-*/<commit12>/<path>. The sheet shows, per match, the lines of the tv3 file and the
lines of the reference from the matched line on; the key of a match is `<type> <path> <ref without CORPORA> <line>`
(the line of the reference does not move when tv3 lines shift, so keys compare across revisions).
"""
import re
import subprocess
import sys

out, repo, corpora, sheet, keys = sys.argv[1:6]
pat = re.compile(r'^(raw|ren|lit)\s+(\d+)\s+(\S+):(\d+)-(\d+)\s+==\s+(\S+):(\d+)\s*$')
hist = re.compile(r'/borrow-audit-[^/]+/([0-9a-f]{12})/(.+)$')


def tv3_lines(path):
    m = hist.search(path)
    if m:
        data = subprocess.run(['git', '-C', repo, 'show', '%s:%s' % (m.group(1), m.group(2))],
                              capture_output=True).stdout
        return m.group(1), m.group(2), data.decode('latin-1').split('\n')
    p = path if path.startswith('/') else repo + '/' + path
    return 'tree', path, open(p, encoding='latin-1').read().split('\n')


rows, ks = [], []
section = ''
for line in open(out, encoding='utf-8', errors='replace'):
    line = line.rstrip('\n')
    if line.startswith('== '):
        section = line[3:]
        continue
    m = pat.match(line)
    if not m:
        continue
    kind, n, f, a, b, ref, rl = m.groups()
    a, b, rl = int(a), int(b), int(rl)
    where, name, tl = tv3_lines(f)
    refrel = ref[len(corpora):].lstrip('/') if ref.startswith(corpora) else ref
    try:
        rlines = open(ref, encoding='latin-1').read().split('\n')
    except OSError:
        rlines = []
    span = min(b - a + 1, 80)
    rows.append('=' * 100)
    rows.append('%s | %s %s tokens | tv3 %s @ %s lines %d-%d | ref %s:%d' % (section, kind, n, name, where, a, b, refrel, rl))
    rows.append('--- tv3')
    rows += ['%6d  %s' % (i, tl[i - 1]) for i in range(a, min(a + span, len(tl) + 1))]
    rows.append('--- ref')
    rows += ['%6d  %s' % (i, rlines[i - 1]) for i in range(rl, min(rl + span, len(rlines) + 1))]
    ks.append('%s %s %s %d' % (kind, name, refrel, rl))
open(sheet, 'w', encoding='utf-8').write('\n'.join(rows) + '\n')
open(keys, 'w', encoding='utf-8').write('\n'.join(sorted(set(ks))) + ('\n' if ks else ''))
print('%d match lines, %d distinct keys' % (len(ks), len(set(ks))))
