#!/usr/bin/env python3
"""vtdump: replay ptyrun PTYSNAP blocks through a tiny terminal emulator (stdlib only,
no pyte/PIL needed) and print the resulting screen text for every snapshot.

  vtdump.py LOG [cols rows]

It understands what a TUI like f4 needs to be readable as text: cursor movement,
erase, scroll, alt screen ignored (one grid), SGR/modes ignored. Colours are not shown.
For pixel-exact renders use f4-redox/scripts/render_screens.py (pyte) in CI.
"""
import base64, re, sys, unicodedata

cols = int(sys.argv[2]) if len(sys.argv) > 2 else 100
rows = int(sys.argv[3]) if len(sys.argv) > 3 else 30


class Screen:
    def __init__(self):
        self.g = [[" "] * cols for _ in range(rows)]
        self.x = self.y = 0
        self.top, self.bot = 0, rows - 1
        self.saved = (0, 0)
        self.buf = b""

    def scroll_up(self):
        del self.g[self.top]
        self.g.insert(self.bot, [" "] * cols)

    def scroll_down(self):
        del self.g[self.bot]
        self.g.insert(self.top, [" "] * cols)

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
        for k in range(1, w):
            if self.x + k < cols:
                self.g[self.y][self.x + k] = ""
        self.x += w

    def csi(self, params, inter, final):
        nums = [int(p) if p.isdigit() else 0 for p in params.split(";")] if params and not params[0] in "?>=<" else []
        n = lambda i=0, d=1: (nums[i] if i < len(nums) and nums[i] else d)
        if params[:1] in "?>=<":
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
