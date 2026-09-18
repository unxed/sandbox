#!/usr/bin/env python3
"""Make Redox join the OS lists where illumos/solaris sit, in the first
`//go:build` line of every .go file under DIR (the same mechanical rule the Haiku
port used by hand): positive `... illumos ...` gets `|| redox` right after it,
negative `!illumos` gets `&& !redox` right after it; files that already mention
redox are left alone. Prints the changed files.
usage: redox_tags.py DIR [DIR...]"""
import os, re, sys

pos = re.compile(r'(?<![!\w])illumos(?!\w)')
neg = re.compile(r'!illumos(?!\w)')

def fix(line):
    if 'redox' in line:
        return line
    # negative form first (so the positive regex does not see "!illumos")
    if neg.search(line):
        return neg.sub(lambda m: m.group(0) + ' && !redox', line, count=1)
    if pos.search(line):
        return pos.sub(lambda m: m.group(0) + ' || redox', line, count=1)
    return line

changed = 0
for root_dir in sys.argv[1:]:
    for d, _, files in os.walk(root_dir):
        for f in files:
            if not f.endswith('.go') or 'solaris' in f or 'illumos' in f:
                continue
            p = os.path.join(d, f)
            try:
                src = open(p, encoding='utf-8').read().split('\n')
            except (OSError, UnicodeDecodeError):
                continue
            for i, line in enumerate(src[:40]):
                if line.startswith('//go:build '):
                    new = fix(line)
                    if new != line:
                        src[i] = new
                        # legacy // +build lines are ignored by go1.26 when //go:build exists
                        open(p, 'w', encoding='utf-8').write('\n'.join(src))
                        print(f'{p}: {line}  ->  {new}')
                        changed += 1
                    break
print(f'redox_tags: {changed} files changed', file=sys.stderr)
