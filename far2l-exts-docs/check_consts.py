#!/usr/bin/env python3
"""Check constants and letters in VTExts.md against far2l headers/sources.
usage: check_consts.py VTExts.md FAR2L_SRC_DIR"""
import re, sys, os

md_path, src = sys.argv[1], sys.argv[2]
md = open(md_path, encoding='utf-8').read()
errors = []

def rd(p):
    return open(os.path.join(src, p), encoding='utf-8', errors='replace').read()

def parse_defs(text):
    d = {}
    for m in re.finditer(r'^\s*#\s*define\s+([A-Za-z_][A-Za-z0-9_]*)\s+(.+?)\s*(?://.*|/\*.*)?$', text, re.M):
        name, val = m.group(1), m.group(2).strip()
        val = val.split('//')[0].strip()
        v = None
        if re.fullmatch(r"'(.)'", val):
            v = ord(val[1])
        elif re.fullmatch(r'0[xX][0-9a-fA-F]+[uUlL]*', val):
            v = int(re.sub(r'[uUlL]+$', '', val), 16)
        elif re.fullmatch(r'\d+[uUlL]*', val):
            v = int(re.sub(r'[uUlL]+$', '', val))
        if v is not None:
            d[name] = v
    return d

farTTY = parse_defs(rd('WinPort/FarTTY.h'))
winc = parse_defs(rd('WinPort/WinCompat.h'))
defs = dict(winc); defs.update(farTTY)

def parse_md_value(tok):
    tok = tok.strip()
    m = re.fullmatch(r"0[xX]([0-9a-fA-F]+)", tok)
    if m: return int(m.group(1), 16)
    if re.fullmatch(r"\d+", tok): return int(tok)
    if len(tok) == 1: return ord(tok)
    return None

PREFIXES = ['', 'FARTTY_INTERACT_', 'FARTTY_INPUT_']
def resolve(name):
    for pf in PREFIXES:
        if pf + name in defs:
            return pf + name
    return None

def val_of(tok):
    tok = tok.strip()
    m = re.fullmatch(r"0[xX]([0-9a-fA-F]+)", tok)
    if m: return int(m.group(1), 16)
    if re.fullmatch(r"\d+", tok): return int(tok)
    return None

checked = set()
def cmp_name_value(ln_no, name, valtok, how):
    full = resolve(name)
    if not full: return
    v = val_of(valtok)
    if v is None: return
    checked.add(full)
    if v != defs[full]:
        errors.append('line %d (%s): %s documented as %s, header has 0x%x (%d)' % (ln_no, how, full, valtok, defs[full], defs[full]))

def cmp_name_char(ln_no, name, ch, how):
    full = resolve(name)
    if not full: return
    checked.add(full)
    if len(ch) != 1 or ord(ch) != defs[full]:
        errors.append("line %d (%s): %s documented as '%s', header has '%s'" % (ln_no, how, full, ch, chr(defs[full])))

for ln_no, line in enumerate(md.splitlines(), 1):
    # 1. adjacent pairs in prose or tables: `NAME` `value`  and  `NAME` = `value`
    for m in re.finditer(r'`([A-Z][A-Z0-9_]+)`(?: =)? `(0[xX][0-9a-fA-F]+|\d+)`', line):
        cmp_name_value(ln_no, m.group(1), m.group(2), 'pair')
    # 2. table rows
    if line.startswith('|'):
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        if len(cells) >= 2:
            c0 = re.findall(r'`([^`]+)`', cells[0]); c1 = re.findall(r'`([^`]+)`', cells[1])
            if len(c0) == 1 and len(c1) == 1 and resolve(c0[0]) and val_of(c1[0]) is not None:
                cmp_name_value(ln_no, c0[0], c1[0], 'row name/value')
            elif re.fullmatch(r'\d+', cells[0]) and len(c1) == 1 and resolve(c1[0]):
                cmp_name_value(ln_no, c1[0], cells[0], 'row value/name')
            elif c0 and c1 and all(len(x) == 1 for x in c0) and len(c0) == len(c1) and all(resolve(x) for x in c1):
                for a, b in zip(c0, c1):
                    cmp_name_char(ln_no, b, a, 'row letter/name')
            elif c0 and c1 and len(c0) == 1 and len(c0[0]) == 1 and resolve(c1[0]) :
                cmp_name_char(ln_no, c1[0], c0[0], 'row letter/name')
    # 3. headings "### n. `NAME` (`x`)"
    m = re.match(r'#+ [\d.]+ .*?`([A-Z_]+)` \(`(.)`\)', line)
    if m:
        cmp_name_char(ln_no, m.group(1), m.group(2), 'heading')
    # 4. "`K` / `k`" style in events table handled in 2; events heading "### 6.1. Key events: `K`, `k`" not checked

need = [n for n in farTTY if n.startswith('FARTTY_')] + [n for n in winc if re.match(r'WP_IMG', n)] \
    + ['CF_TEXT', 'CF_UNICODETEXT', 'CF_HTML', 'RIGHT_SHIFT_VSC'] \
    + ['RIGHT_ALT_PRESSED','LEFT_ALT_PRESSED','RIGHT_CTRL_PRESSED','LEFT_CTRL_PRESSED','SHIFT_PRESSED','NUMLOCK_ON','SCROLLLOCK_ON','CAPSLOCK_ON','ENHANCED_KEY',
       'FROM_LEFT_1ST_BUTTON_PRESSED','RIGHTMOST_BUTTON_PRESSED','FROM_LEFT_2ND_BUTTON_PRESSED','FROM_LEFT_3RD_BUTTON_PRESSED','FROM_LEFT_4TH_BUTTON_PRESSED',
       'MOUSE_MOVED','DOUBLE_CLICK','MOUSE_WHEELED','MOUSE_HWHEELED']
for n in need:
    if n not in checked:
        errors.append('not verified (absent in the document, or no value/letter pair found): %s = 0x%x' % (n, defs[n]))

# ---- numeric facts from the sources ----
def need_re(path, pattern, what, flags=0):
    t = rd(path)
    if not re.search(pattern, t, flags):
        errors.append('SOURCE CHANGED? %s: %s' % (path, what))

need_re('WinPort/src/Backend/TTY/TTYFar2lClipboardBackend.cpp', r'#define CHUNK_SIZE 0x4000', 'CHUNK_SIZE 0x4000')
need_re('WinPort/src/Backend/TTY/TTYFar2lClipboardBackend.cpp', r'\(i % 16\) == 0', 'wait every 16th chunk')
need_re('WinPort/src/Backend/TTY/TTYFar2lClipboardBackend.cpp', r'uint16_t\(CHUNK_SIZE >> 8\)', 'size>>8')
need_re('WinPort/src/Backend/TTY/TTYFar2lClipboardBackend.cpp', r'busy_period >= 256', 'throttle 256ms')
need_re('WinPort/src/Backend/TTY/TTYFar2lClipboardBackend.cpp', r'busy_period / 8', 'throttle /8')
need_re('WinPort/src/Backend/TTY/TTYFar2lClipboardBackend.cpp', r'tty_clipboard/me', 'client id file')
need_re('far2l/src/vt/VTFar2lExtensios.cpp', r'CLIPBOARD_READ_ALLOWANCE_EXPIRATION_MSEC\s+5000', 'allowance 5000')
need_re('far2l/src/vt/VTFar2lExtensios.cpp', r'CLIPBOARD_READ_ALLOWANCE_PROLONGS\s+3', 'prolongs 3')
need_re('far2l/src/vt/VTFar2lExtensios.cpp', r'client_id.size\(\) < 0x20 \|\| client_id.size\(\) > 0x100', 'id 32..256')
need_re('far2l/src/vt/VTFar2lExtensios.cpp', r'tty_clipboard/autheds', 'autheds file')
need_re('WinPort/src/Backend/FSClipboardBackend.cpp', r'id < 0xC000 \|\| id> 0xFFFF', 'custom format range')
need_re('WinPort/src/Backend/TTY/TTYBackend.cpp', r'_far2l_interacts_sent.size\(\) >= 0xff', '255 in flight')
need_re('WinPort/src/Backend/TTY/TTYBackend.cpp', r'v > 10 && v < 4096', 'LINES/COLUMNS 11..4095')
need_re('WinPort/src/Backend/TTY/TTYBackend.cpp', r'g_far2l_term_width = 80, g_far2l_term_height = 25', '80x25')
need_re('WinPort/src/Backend/TTY/TTYCaps.cpp', r'\\e_far2l1\\e\\\\', 'far2l1 ST')
need_re('WinPort/src/Backend/TTY/TTYCaps.cpp', r'\\e_far2lok\\a', 'far2lok BEL')
need_re('WinPort/src/Backend/TTY/TTYCaps.cpp', r'\\e_far2l0\\a', 'far2l0 BEL')
need_re('WinPort/src/Backend/TTY/TTYCaps.cpp', r'struct timeval tv = \{10, 0\}', '10 s timeout')
need_re('WinPort/src/Backend/TTY/TTYOutput.cpp', r'ESC "_far2l:"', 'request prefix with colon')
need_re('WinPort/src/Backend/TTY/TTYInputSequenceParser.cpp', r'strncmp\(s, "f2l", 3\)', 'f2l prefix')
need_re('WinPort/src/Backend/TTY/TTYInputSequenceParser.cpp', r'strncmp\(s, "far2l", 5\)', 'far2l reply prefix')
need_re('far2l/src/vt/VTFar2lExtensios.cpp', r'"\\x1b_f2l"', 'server event prefix without colon')
need_re('far2l/src/vt/vtshell.cpp', r'"\\x1b_far2lok\\x07"', 'server ack')
need_re('far2l/src/vt/vtshell.cpp', r'reply = "\\x1b_far2l";', 'server reply prefix without colon')
need_re('WinPort/src/Backend/TTY/TTYFar2lClipboardBackend.cpp', r'sizeof\(buf\)', 'client id 64 chars (buf 0x40)')
need_re('WinPort/src/Backend/TTY/TTYFar2lClipboardBackend.cpp', r'char buf\[0x40\]', 'buf 0x40')
need_re('far2l/src/vt/VTFar2lExtensios.cpp', r'id = crc64\(id', 'crc64 data id')
need_re('WinPort/WinCompat.h', r'#define CONSOLE_FKEYS_COUNT 12', '12 fkeys')
need_re('WinPort/src/Backend/TTY/TTYBackend.cpp', r'PopNum\(wgi->PixPerCell.Y\);\s*stk_ser.PopNum\(wgi->PixPerCell.X\);\s*stk_ser.PopNum\(wgi->Caps\)', 'image caps pop order Y,X,caps', re.S)
need_re('WinPort/src/Backend/TTY/TTYBackend.cpp', r'PopNum\(g_far2l_term_height\);\s*stk_ser.PopNum\(g_far2l_term_width\)', 'size event pop order height,width', re.S)
need_re('WinPort/src/Backend/TTY/TTYBackend.cpp', r'PopNum\(out.Y\);\s*stk_ser.PopNum\(out.X\)', 'maxsize pop order Y,X', re.S)
need_re('far2l/src/vt/VTFar2lExtensios.cpp', r'PushNum\(sz.X\);\s*stk_ser.PushNum\(sz.Y\)', 'server maxsize push X,Y', re.S)
need_re('far2l/src/vt/VTFar2lExtensios.cpp', r'PushNum\(wgi.Caps\);\s*stk_ser.PushNum\(wgi.PixPerCell.X\);\s*stk_ser.PushNum\(wgi.PixPerCell.Y\)', 'server caps push caps,X,Y', re.S)
need_re('far2l/src/vt/VTFar2lExtensios.cpp', r'PushNum\(\(uint16_t\)csbi.dwSize.X\);\s*stk_ser.PushNum\(\(uint16_t\)csbi.dwSize.Y\);\s*stk_ser.PushNum\(FARTTY_INPUT_TERMINAL_SIZE\)', 'server size push X,Y,code', re.S)

if errors:
    print('FAIL: %d problem(s)' % len(errors))
    for e in errors: print('  -', e)
    sys.exit(1)
print('OK: %d names/letters checked against FarTTY.h and WinCompat.h, all numeric/source facts match' % len(checked))
