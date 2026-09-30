#!/usr/bin/env python3
"""Extract wire examples from VTExts.md into a TSV: name<TAB>kind<TAB>base64.
Also verifies that the 'Stack bytes, bottom to top' hex line under each example equals the decoded base64."""
import re, sys, base64
md = open(sys.argv[1], encoding='utf-8').read()
out = []
bad = 0
pat = re.compile(r'<!-- ex:([a-z0-9-]+) -->\n```\n(.*?)\n```\nStack bytes, bottom to top: `([0-9a-f ]+)`', re.S)
for m in pat.finditer(md):
    name, wire, hexs = m.group(1), m.group(2), m.group(3)
    w = re.fullmatch(r'\\x1b_(far2l:|far2l|f2l)([A-Za-z0-9+/=]*)\\x07', wire.strip())
    if not w:
        print('BAD WIRE FORMAT for', name, repr(wire)); bad += 1; continue
    kind = {'far2l:': 'request', 'far2l': 'reply', 'f2l': 'event'}[w.group(1)]
    raw = base64.b64decode(w.group(2) + '=' * (-len(w.group(2)) % 4))
    if raw.hex(' ') != hexs:
        print('HEX MISMATCH for', name, raw.hex(' '), '!=', hexs); bad += 1
    out.append('%s\t%s\t%s' % (name, kind, w.group(2)))
open(sys.argv[2], 'w').write('\n'.join(out) + '\n')
print('extracted %d examples' % len(out))
sys.exit(1 if bad else 0)
