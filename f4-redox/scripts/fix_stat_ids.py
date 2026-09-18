#!/usr/bin/env python3
"""syscall.Stat_t.Uid/Gid are int32 on redox (relibc's uid_t/gid_t are C ints);
everywhere else in the Go world they are uint32, and third-party code assumes that.
Wrap direct uses of <stat-var>.Uid/.Gid in uint32(...) (valid for both).
usage: fix_stat_ids.py DIR [DIR...]"""
import os, re, sys
pat = re.compile(r'(?<![\w.])(?<!uint32\()(?<!int\()(?<!int64\()(?<!uint64\()(stat|statt|sys|st|fst|lst)\.(Uid|Gid)\b(?!\s*=[^=])')
n = 0
for root in sys.argv[1:]:
    for d, _, files in os.walk(root):
        for f in files:
            if not f.endswith('.go') or f.endswith('_test.go') or 'windows' in f or 'plan9' in f:
                continue
            p = os.path.join(d, f)
            try:
                src = open(p, encoding='utf-8').read()
            except (OSError, UnicodeDecodeError):
                continue
            if 'Stat_t' not in src:
                continue
            new = pat.sub(lambda m: f'uint32({m.group(1)}.{m.group(2)})', src)
            if new != src:
                open(p, 'w', encoding='utf-8').write(new)
                print(f'{p}: wrapped {len(pat.findall(src))} use(s)')
                n += 1
print(f'fix_stat_ids: {n} files changed', file=sys.stderr)
