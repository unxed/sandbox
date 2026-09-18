#!/usr/bin/env python3
"""Replay ptyrun snapshots from a redoxer log through a terminal emulator (pyte).
Writes <outdir>/<tag>-<name>.txt (screen text) and .png (rendered screen), prints the text.
usage: render_screens.py LOG OUTDIR [cols rows]"""
import base64, os, re, sys

log, outdir = sys.argv[1], sys.argv[2]
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 100
rows = int(sys.argv[4]) if len(sys.argv) > 4 else 30
os.makedirs(outdir, exist_ok=True)
import pyte
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    Image = None

text = open(log, errors='replace').read().replace('\r', '')
pat = re.compile(r'=====PTYSNAP (\S+) (\S+) BEGIN bytes=\d+=====\n(.*?)\n=====PTYSNAP \1 \2 END=====', re.S)
screens, streams = {}, {}
COLORS = {'black': (0, 0, 0), 'red': (205, 49, 49), 'green': (13, 188, 121), 'brown': (229, 229, 16),
          'blue': (36, 114, 200), 'magenta': (188, 63, 188), 'cyan': (17, 168, 205), 'white': (229, 229, 229),
          'default': None}

def color(c, default):
    if c in COLORS and COLORS[c] is not None:
        return COLORS[c]
    if c == 'default':
        return default
    if len(c) == 6:
        try:
            return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))
        except ValueError:
            pass
    return default

font = None
if Image:
    for f in ('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', '/usr/share/fonts/dejavu/DejaVuSansMono.ttf'):
        if os.path.exists(f):
            font = ImageFont.truetype(f, 14)
            break
    if font is None:
        font = ImageFont.load_default()

def render_png(scr, path):
    cw, ch = 9, 18
    img = Image.new('RGB', (cols * cw, rows * ch), (0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(rows):
        line = scr.buffer[y]
        for x in range(cols):
            c = line[x]
            fg, bg = color(c.fg, (204, 204, 204)), color(c.bg, (0, 0, 0))
            if c.reverse:
                fg, bg = bg, fg
            d.rectangle([x * cw, y * ch, (x + 1) * cw - 1, (y + 1) * ch - 1], fill=bg)
            if c.data.strip():
                d.text((x * cw, y * ch), c.data, font=font, fill=fg)
    img.save(path)

count = 0
for m in pat.finditer(text):
    tag, name, b64 = m.group(1), m.group(2), re.sub(r'\s+', '', m.group(3))
    try:
        data = base64.b64decode(b64)
    except Exception as e:
        print(f'{tag}/{name}: bad base64: {e}')
        continue
    if tag not in screens:
        screens[tag] = pyte.Screen(cols, rows)
        streams[tag] = pyte.ByteStream(screens[tag])
        streams[tag].use_utf8 = True
    streams[tag].feed(data)
    scr = screens[tag]
    body = '\n'.join(l.rstrip() for l in scr.display).rstrip('\n')
    base = os.path.join(outdir, f'{tag}-{name}')
    open(base + '.txt', 'w').write(body + '\n')
    open(base + '.raw', 'wb').write(data)
    if Image:
        render_png(scr, base + '.png')
    print(f'===== screen {tag}/{name} ({len(data)} new bytes) =====')
    print(body)
    count += 1
print(f'render_screens: {count} snapshot(s)')
