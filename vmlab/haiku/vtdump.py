#!/usr/bin/env python3
"""vtdump: replay ptyrun PTYSNAP blocks through a tiny terminal emulator (stdlib only,
no pyte/PIL needed) and print the resulting screen text for every snapshot.

  vtdump.py LOG [cols rows]

It understands what a TUI like f4 needs to be readable as text: cursor movement,
erase, scroll, alt screen ignored (one grid), SGR/modes ignored. Colours are not shown.
For pixel-exact renders use f4-redox/scripts/render_screens.py (pyte) in CI.
"""
import base64, re, sys, unicodedata

_a = [a for a in sys.argv[1:] if not a.startswith('--')]
cols = int(_a[1]) if len(_a) > 1 else 100
rows = int(_a[2]) if len(_a) > 2 else 30


class Screen:
    def __init__(self):
        self.g = [[" "] * cols for _ in range(rows)]
        self.bg = [[None] * cols for _ in range(rows)]  # background colour per cell (None = default)
        self.pen_bg = None
        self.x = self.y = 0
        self.top, self.bot = 0, rows - 1
        self.saved = (0, 0)
        self.buf = b""

    def scroll_up(self):
        del self.g[self.top]; del self.bg[self.top]
        self.g.insert(self.bot, [" "] * cols); self.bg.insert(self.bot, [None] * cols)

    def scroll_down(self):
        del self.g[self.bot]; del self.bg[self.bot]
        self.g.insert(self.top, [" "] * cols); self.bg.insert(self.top, [None] * cols)

    def lf(self):
        if self.y == self.bot:
            self.scroll_up()
        elif self.y < rows - 1:
            self.y += 1

    def put(self, ch):
        if unicodedata.combining(ch):
            return
        w = 2 if unicodedata.east_asian_width(ch) in "WF" else 1
        if self.x + w > cols:
            self.x = 0
            self.lf()
        self.g[self.y][self.x] = ch
        self.bg[self.y][self.x] = self.pen_bg
        for k in range(1, w):
            if self.x + k < cols:
                self.g[self.y][self.x + k] = ""
                self.bg[self.y][self.x + k] = self.pen_bg
        self.x += w

    def csi(self, params, inter, final):
        nums = [int(p) if p.isdigit() else 0 for p in params.split(";")] if params and not params[0] in "?>=<" else []
        n = lambda i=0, d=1: (nums[i] if i < len(nums) and nums[i] else d)
        if params[:1] in "?>=<":
            return
        if final == "m":
            self.sgr(params)
            return
        if final in "Hf":
            self.y = min(rows - 1, n(0) - 1)
            self.x = min(cols - 1, n(1) - 1)
        elif final == "A": self.y = max(0, self.y - n())
        elif final == "B": self.y = min(rows - 1, self.y + n())
        elif final == "C": self.x = min(cols - 1, self.x + n())
        elif final == "D": self.x = max(0, self.x - n())
        elif final == "E": self.y = min(rows - 1, self.y + n()); self.x = 0
        elif final == "F": self.y = max(0, self.y - n()); self.x = 0
        elif final in "G`": self.x = min(cols - 1, n() - 1)
        elif final == "d": self.y = min(rows - 1, n() - 1)
        elif final == "J":
            m = nums[0] if nums else 0
            if m == 0:
                self.g[self.y][self.x:] = [" "] * (cols - self.x)
                for r in range(self.y + 1, rows): self.g[r] = [" "] * cols
            elif m == 1:
                self.g[self.y][:self.x + 1] = [" "] * (self.x + 1)
                for r in range(0, self.y): self.g[r] = [" "] * cols
            else:
                self.g = [[" "] * cols for _ in range(rows)]
        elif final == "K":
            m = nums[0] if nums else 0
            if m == 0: self.g[self.y][self.x:] = [" "] * (cols - self.x)
            elif m == 1: self.g[self.y][:self.x + 1] = [" "] * (self.x + 1)
            else: self.g[self.y] = [" "] * cols
        elif final == "X":
            for k in range(n()):
                if self.x + k < cols: self.g[self.y][self.x + k] = " "
        elif final == "P":
            k = n(); row = self.g[self.y]
            del row[self.x:self.x + k]; row.extend([" "] * (cols - len(row)))
        elif final == "@":
            k = n(); row = self.g[self.y]
            row[self.x:self.x] = [" "] * k; del row[cols:]
        elif final == "L":
            for _ in range(n()):
                del self.g[self.bot]; self.g.insert(self.y, [" "] * cols)
        elif final == "M":
            for _ in range(n()):
                del self.g[self.y]; self.g.insert(self.bot, [" "] * cols)
        elif final == "S":
            for _ in range(n()): self.scroll_up()
        elif final == "T":
            for _ in range(n()): self.scroll_down()
        elif final == "r":
            self.top = n(0) - 1
            self.bot = (nums[1] - 1) if len(nums) > 1 and nums[1] else rows - 1
            self.x = self.y = 0
        elif final == "s": self.saved = (self.x, self.y)
        elif final == "u": self.x, self.y = self.saved

    def sgr(self, params):
        v = [int(x) if x.isdigit() else 0 for x in params.replace(":", ";").split(";")] if params else [0]
        i = 0
        while i < len(v):
            c = v[i]
            if c == 0 or c == 49: self.pen_bg = None
            elif 40 <= c <= 47: self.pen_bg = ("basic", c - 40)
            elif 100 <= c <= 107: self.pen_bg = ("basic", c - 100 + 8)
            elif c in (38, 48):
                kind = v[i + 1] if i + 1 < len(v) else 0
                if kind == 5 and i + 2 < len(v):
                    val = ("idx", v[i + 2]); i += 2
                elif kind == 2 and i + 4 < len(v):
                    val = ("rgb", v[i + 2], v[i + 3], v[i + 4]); i += 4
                else:
                    val = None
                if c == 48: self.pen_bg = val
            i += 1

    def feed(self, data):
        s = (self.buf + data).decode("utf-8", errors="replace")
        self.buf = b""
        i = 0
        while i < len(s):
            c = s[i]
            if c == "\x1b":
                if i + 1 >= len(s): break
                d = s[i + 1]
                if d == "[":
                    m = re.compile(r"[0-?]*[ -/]*[@-~]").match(s, i + 2)
                    if not m: break
                    seq = m.group(0)
                    j = len(seq) - 1
                    while j > 0 and not (0x30 <= ord(seq[j - 1]) <= 0x3f): j -= 1
                    k = 0
                    while k < len(seq) and 0x30 <= ord(seq[k]) <= 0x3f: k += 1
                    self.csi(seq[:k], seq[k:-1], seq[-1])
                    i = m.end()
                elif d in "]PX^_":
                    m = re.compile(r"\x07|\x1b\\").search(s, i + 2)
                    if not m: break
                    i = m.end()
                elif d in "()*+#%":
                    i += 3
                elif d == "7": self.saved = (self.x, self.y); i += 2
                elif d == "8": self.x, self.y = self.saved; i += 2
                elif d == "D": self.lf(); i += 2
                elif d == "M":
                    if self.y == self.top: self.scroll_down()
                    elif self.y > 0: self.y -= 1
                    i += 2
                elif d == "E": self.x = 0; self.lf(); i += 2
                elif d == "c":
                    self.__init__(); i += 2
                else:
                    i += 2
            elif c == "\r": self.x = 0; i += 1
            elif c == "\n": self.lf(); i += 1
            elif c == "\b": self.x = max(0, self.x - 1); i += 1
            elif c == "\t": self.x = min(cols - 1, (self.x // 8 + 1) * 8); i += 1
            elif c in "\x07\x0e\x0f\x00": i += 1
            elif ord(c) < 32: i += 1
            else: self.put(c); i += 1
        self.buf = s[i:].encode("utf-8")

    def bgmap(self):
        def cls(b):
            if b is None: return "."
            if b[0] == "rgb":
                r, g, bl = b[1:]
            elif b[0] == "idx":
                n = b[1]
                if n < 16:
                    r, g, bl = [(0,0,0),(205,0,0),(0,205,0),(205,205,0),(0,0,238),(205,0,205),(0,205,205),(229,229,229),(127,127,127),(255,0,0),(0,255,0),(255,255,0),(92,92,255),(255,0,255),(0,255,255),(255,255,255)][n]
                elif n < 232:
                    n -= 16; lv = [0, 95, 135, 175, 215, 255]
                    r, g, bl = lv[n // 36], lv[(n // 6) % 6], lv[n % 6]
                else:
                    r = g = bl = 8 + (n - 232) * 10
            else:
                r, g, bl = [(0,0,0),(205,0,0),(0,205,0),(205,205,0),(0,0,238),(205,0,205),(0,205,205),(229,229,229)][b[1] % 8]
            if g > 150 and r < 120 and bl < 80: return "G"
            if r > 200 and g > 130 and bl < 130: return "o"
            if r > 170 and g > 170 and bl > 150: return "w"
            if r < 90 and g < 90 and bl < 90: return "."
            return "?"
        return "\n".join("".join(cls(c) for c in row).rstrip(".") for row in self.bg).rstrip("\n")

    def text(self):
        return "\n".join("".join(r).rstrip() for r in self.g).rstrip("\n")


text = open(sys.argv[1], errors="replace").read().replace("\r", "")
pat = re.compile(r"=====PTYSNAP (\S+) (\S+) BEGIN bytes=\d+=====\n(.*?)\n?=====PTYSNAP \1 \2 END=====", re.S)
screens = {}
for m in pat.finditer(text):
    tag, name = m.group(1), m.group(2)
    data = base64.b64decode(re.sub(r"\s+", "", m.group(3)))
    scr = screens.setdefault(tag, Screen())
    scr.feed(data)
    print("===== %s/%s (%d new bytes) =====" % (tag, name, len(data)))
    print(scr.text())
    if "--bg" in sys.argv:
        print("--- background map (G=green o=orange w=light .=dark/default ?=other) ---")
        print(scr.bgmap())
