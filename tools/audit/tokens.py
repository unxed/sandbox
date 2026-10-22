"""Tokens and comparison streams of the audit (see docs/CLEANROOM.md and tools/audit/audit.py).

A token is a tuple (cls, text, line):
  cls 'w'  keyword (text in lower case)
  cls 'i'  identifier or plain word (text in lower case)
  cls 'l'  literal; text is "n<value>" for a number or a character, "f<text>" for a real number,
           "s<text>" for a string of two or more characters
  cls 'p'  punctuation
  cls 'h'  Pascal routine heading; it matches nothing
Comments and layout are not tokens.
"""
import re

PASCAL_EXT = (".pas", ".pp", ".inc", ".lpr", ".dpr")
C_EXT = (".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp")

PASCAL_KEYWORDS = frozenset("""
and array as asm begin case class const constructor destructor div do downto else end except exports file
finalization finally for function goto if implementation in inherited initialization inline interface is label
library mod nil not object of on operator or out packed procedure program property raise record repeat
resourcestring set shl shr string then threadvar to try type unit until uses var while with xor
""".split())

C_KEYWORDS = frozenset("""
alignas alignof and and_eq asm auto bitand bitor bool break case catch char class compl concept const consteval
constexpr constinit const_cast continue co_await co_return co_yield decltype default delete do double
dynamic_cast else enum explicit export extern false final float for friend goto if inline int long mutable
namespace new noexcept not not_eq nullptr operator or or_eq override private protected public register
reinterpret_cast requires return short signed sizeof static static_assert static_cast struct switch template
this thread_local throw true try typedef typeid typename union unsigned using virtual void volatile wchar_t
while xor xor_eq
""".split())

HEADING_WORDS = frozenset(["procedure", "function", "constructor", "destructor", "operator"])

DIRECTIVES = frozenset("""
virtual override overload abstract cdecl stdcall register pascal safecall inline forward external reintroduce
static dynamic message deprecated platform experimental assembler nostackframe export alias public varargs
noreturn compilerproc interrupt far near local unimplemented final winapi syscall mwpascal vectorcall
""".split())


def language(path):
    p = path.lower()
    if p.endswith(PASCAL_EXT):
        return "pascal"
    if p.endswith(C_EXT):
        return "c"
    return "plain"


def is_code(path):
    return language(path) != "plain"


def _num(value):
    return "n%d" % value


def _str(text):
    if len(text) == 1:
        return _num(ord(text))
    return "s" + text


PAS_RE = re.compile(r"""
 (?P<ws>\s+)
|(?P<lc>//[^\n]*)
|(?P<bc>\{[^}]*\})
|(?P<pc>\(\*.*?\*\))
|(?P<str>'(?:[^'\n]|'')*')
|(?P<chr>\#(?:\$[0-9A-Fa-f]+|[0-9]+))
|(?P<hex>\$[0-9A-Fa-f]+)
|(?P<bin>%[01]+)
|(?P<oct>&[0-7]+)
|(?P<real>[0-9]+(?:\.[0-9]+[eE][+-]?[0-9]+|\.[0-9]+|[eE][+-]?[0-9]+))
|(?P<num>[0-9]+)
|(?P<id>&?[A-Za-z_][A-Za-z0-9_]*)
|(?P<op>:=|<>|<=|>=|\.\.|\*\*|><|\+=|-=|\*=|/=)
|(?P<other>.)
""", re.X | re.S)

C_RE = re.compile(r"""
 (?P<ws>\s+)
|(?P<lc>//[^\n]*)
|(?P<bc>/\*.*?\*/)
|(?P<raw>(?:u8|u|U|L)?R"(?P<delim>[^()\s\\"]{0,16})\(.*?\)(?P=delim)")
|(?P<str>(?:u8|u|U|L)?"(?:[^"\\\n]|\\.)*")
|(?P<chr>(?:u8|u|U|L)?'(?:[^'\\\n]|\\.)+')
|(?P<hex>0[xX][0-9a-fA-F']+[uUlLzZ]*)
|(?P<bin>0[bB][01']+[uUlLzZ]*)
|(?P<num>(?:[0-9][0-9']*\.?[0-9']*|\.[0-9][0-9']*)(?:[eE][+-]?[0-9]+)?[fFlLuUzZ]*)
|(?P<id>[A-Za-z_][A-Za-z0-9_]*)
|(?P<op><<=|>>=|\.\.\.|->\*|<=>|::|->|\+\+|--|<<|>>|<=|>=|==|!=|&&|\|\||\+=|-=|\*=|/=|%=|&=|\|=|\^=|\.\*)
|(?P<other>.)
""", re.X | re.S)

PLAIN_RE = re.compile(r"""
 (?P<ws>\s+)
|(?P<str>"[^"\n]{0,300}")
|(?P<str2>(?<![A-Za-z0-9_])'[^'\n]{0,300}'(?![A-Za-z0-9_]))
|(?P<hex>0[xX][0-9A-Fa-f]+)
|(?P<num>[0-9]+(?:\.[0-9]+)?)
|(?P<id>[^\W\d]\w*)
|(?P<other>.)
""", re.X | re.S)

_ESC = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v", "0": "\0",
        "\\": "\\", "'": "'", '"': '"', "?": "?"}


def _c_unescape(body):
    out = []
    i = 0
    n = len(body)
    while i < n:
        ch = body[i]
        if ch != "\\" or i + 1 >= n:
            out.append(ch)
            i += 1
            continue
        nxt = body[i + 1]
        if nxt == "x":
            j = i + 2
            while j < n and body[j] in "0123456789abcdefABCDEF":
                j += 1
            out.append(chr(int(body[i + 2:j] or "0", 16) & 0x10ffff))
            i = j
        elif nxt in "01234567":
            j = i + 1
            while j < n and j < i + 4 and body[j] in "01234567":
                j += 1
            out.append(chr(int(body[i + 1:j], 8)))
            i = j
        else:
            out.append(_ESC.get(nxt, nxt))
            i += 2
    return "".join(out)


def _c_number(text):
    t = text.replace("'", "").lower()
    if t.startswith("0x"):
        return _num(int(t[2:].rstrip("ulz") or "0", 16))
    if t.startswith("0b"):
        return _num(int(t[2:].rstrip("ulz") or "0", 2))
    if "." in t or "e" in t:
        return "f" + t.rstrip("fl")
    t = t.rstrip("ulz") or "0"
    if len(t) > 1 and t[0] == "0":
        try:
            return _num(int(t, 8))
        except ValueError:
            pass
    return _num(int(t))


def _split_prefix(text):
    i = 0
    while text[i] not in "'\"":
        i += 1
    return text[i:]


def tokenize_pascal(text):
    toks = []
    line = 1
    pending = None  # (parts, line) of a literal being assembled from adjacent strings and #nn constants
    prev_end = -1
    for m in PAS_RE.finditer(text):
        kind = m.lastgroup
        s = m.group()
        start = m.start()
        if kind in ("str", "chr"):
            if kind == "str":
                part = s[1:-1].replace("''", "'")
            else:
                code = int(s[2:], 16) if s[1] == "$" else int(s[1:])
                part = chr(code) if code <= 0x10ffff else "?"
            if pending is not None and start == prev_end:
                pending[0].append(part)
            else:
                if pending is not None:
                    toks.append(("l", _str("".join(pending[0])), pending[1]))
                pending = ([part], line)
            prev_end = m.end()
            line += s.count("\n")
            continue
        if pending is not None:
            toks.append(("l", _str("".join(pending[0])), pending[1]))
            pending = None
        if kind == "ws" or kind == "lc" or kind == "bc" or kind == "pc":
            line += s.count("\n")
            continue
        if kind == "id":
            if s[0] == "&":
                low = s[1:].lower()
                toks.append(("i", low, line))
            else:
                low = s.lower()
                toks.append(("w" if low in PASCAL_KEYWORDS else "i", low, line))
        elif kind == "hex":
            toks.append(("l", _num(int(s[1:], 16)), line))
        elif kind == "bin":
            toks.append(("l", _num(int(s[1:], 2)), line))
        elif kind == "oct":
            toks.append(("l", _num(int(s[1:], 8)), line))
        elif kind == "num":
            toks.append(("l", _num(int(s)), line))
        elif kind == "real":
            toks.append(("l", "f" + s.lower(), line))
        else:
            toks.append(("p", s, line))
    if pending is not None:
        toks.append(("l", _str("".join(pending[0])), pending[1]))
    return _headings(toks)


def _headings(toks):
    """Makes every routine heading (up to its semicolon, with the directives after it) one token."""
    out = []
    i = 0
    n = len(toks)
    while i < n:
        t = toks[i]
        if t[0] == "w" and t[1] in HEADING_WORDS:
            j = i + 1
            depth = 0
            while j < n:
                c = toks[j]
                if c[0] == "p":
                    if c[1] in ("(", "["):
                        depth += 1
                    elif c[1] in (")", "]"):
                        depth -= 1
                    elif c[1] == ";" and depth <= 0:
                        break
                j += 1
            j = min(j + 1, n)
            while j < n and toks[j][0] in ("i", "w") and toks[j][1] in DIRECTIVES:
                k = j
                while k < n and not (toks[k][0] == "p" and toks[k][1] == ";"):
                    k += 1
                j = min(k + 1, n)
            out.append(("h", "", t[2]))
            i = j
            continue
        out.append(t)
        i += 1
    return out


def tokenize_c(text):
    toks = []
    line = 1
    for m in C_RE.finditer(text):
        kind = m.lastgroup
        if kind == "delim":
            kind = "raw"
        s = m.group()
        if kind in ("ws", "lc", "bc"):
            line += s.count("\n")
            continue
        if kind == "id":
            toks.append(("w" if s in C_KEYWORDS else "i", s.lower(), line))
        elif kind == "str":
            toks.append(("l", _str(_c_unescape(_split_prefix(s)[1:-1])), line))
        elif kind == "raw":
            body = s[s.index('"') + 1:-1]
            body = body[body.index("(") + 1:body.rindex(")")]
            toks.append(("l", _str(body), line))
        elif kind == "chr":
            body = _c_unescape(_split_prefix(s)[1:-1])
            toks.append(("l", _num(ord(body[0])) if len(body) == 1 else _str(body), line))
        elif kind in ("hex", "bin", "num"):
            try:
                toks.append(("l", _c_number(s), line))
            except ValueError:
                toks.append(("l", "f" + s.lower(), line))
        else:
            toks.append(("p", s, line))
        line += s.count("\n")
    return toks


def tokenize_plain(text):
    toks = []
    line = 1
    for m in PLAIN_RE.finditer(text):
        kind = m.lastgroup
        s = m.group()
        if kind == "ws":
            line += s.count("\n")
            continue
        if kind in ("str", "str2"):
            toks.append(("l", _str(s[1:-1]), line))
        elif kind == "hex":
            toks.append(("l", _num(int(s, 16)), line))
        elif kind == "num":
            if "." in s:
                toks.append(("l", "f" + s, line))
            else:
                toks.append(("l", _num(int(s)), line))
        elif kind == "id":
            toks.append(("i", s.lower(), line))
        else:
            toks.append(("p", s, line))
        line += s.count("\n")
    return toks


def tokenize(text, lang):
    if lang == "pascal":
        return tokenize_pascal(text)
    if lang == "c":
        return tokenize_c(text)
    return tokenize_plain(text)


# ---- comparison streams -------------------------------------------------------------------------
# A stream is a list of keys (strings), or None for a position that breaks every window.

def raw_keys(toks):
    return [None if t[0] == "h" else t[0] + t[1] for t in toks]


def ren_keys(toks):
    out = []
    for t in toks:
        c = t[0]
        if c == "h":
            out.append(None)
        elif c == "i":
            out.append("@i")
        elif c == "l":
            out.append("@l")
        else:
            out.append(c + t[1])
    return out


def lit_stream(toks):
    """Returns (keys, index): the keys of the literals (None at a heading) and the token index of each."""
    keys = []
    index = []
    for k, t in enumerate(toks):
        if t[0] == "l":
            keys.append("l" + t[1])
            index.append(k)
        elif t[0] == "h":
            keys.append(None)
            index.append(k)
    return keys, index


MASK = (1 << 61) - 1
BASE = 1000003934607  # any fixed odd multiplier below MASK


def window_hashes(keys, width):
    """Returns a list of (start, hash) for every window of `width` keys that holds no None."""
    n = len(keys)
    if n < width:
        return []
    ths = [None if k is None else hash(k) & MASK for k in keys]
    bw = pow(BASE, width, MASK)
    out = []
    h = 0
    run = 0
    for i in range(n):
        t = ths[i]
        if t is None:
            run = 0
            h = 0
            continue
        if run < width:
            h = (h * BASE + t) % MASK
            run += 1
        else:
            h = (h * BASE + t - ths[i - width] * bw) % MASK
        if run >= width:
            out.append((i - width + 1, h))
    return out


def significant(key):
    """Whether a literal key (without the leading 'l') is a significant value for the literal comparison."""
    c = key[0]
    if c == "n":
        return int(key[1:]) >= 32
    if c == "s":
        return len(key) - 1 >= 2
    return False


def is_count(keys):
    """Whether most neighbours of a run of literal keys are numbers one apart."""
    if len(keys) < 2:
        return False
    ones = 0
    for a, b in zip(keys, keys[1:]):
        if a[0] == "n" and b[0] == "n" and abs(int(a[1:]) - int(b[1:])) == 1:
            ones += 1
    return ones * 2 > len(keys) - 1
