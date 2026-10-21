"""Which imported function does a call return to <VA> go to?
Usage: where.py <PE file> <VA> [<VA>...]   (VA in hex, e.g. 43F22B)
Looks for `call [IAT]` (FF 15) or `call rel32` to a `jmp [IAT]` stub (FF 25)
just before each return address."""
import struct, sys
import pefile
try:
    import capstone
except ImportError:
    capstone = None

pe = pefile.PE(sys.argv[1])
base = pe.OPTIONAL_HEADER.ImageBase
iat = {}
for e in getattr(pe, 'DIRECTORY_ENTRY_IMPORT', []):
    for imp in e.imports:
        iat[imp.address] = '%s!%s' % (e.dll.decode(), imp.name.decode() if imp.name else '#%d' % imp.ordinal)

def read(va, n):
    try:
        return pe.get_data(va - base, n)
    except Exception:
        return b''

def slot(va):
    b = read(va, 6)
    if b[:2] == b'\xff\x25':
        return struct.unpack('<I', b[2:6])[0]
    return None

# symbols from a linker map next to the PE (MSVC format: "0001:... name rva+base f obj")
import glob, os, re
syms = []
for m in glob.glob(os.path.join(os.path.dirname(sys.argv[1]) or '.', '*.map')):
    for line in open(m, encoding='latin-1'):
        f = line.split()
        if len(f) >= 3 and re.match(r'^[0-9a-fA-F]{4}:[0-9a-fA-F]{8}$', f[0]) and re.match(r'^[0-9a-fA-F]{8}$', f[2]):
            syms.append((int(f[2], 16), f[1]))
syms.sort()

def symbol(va):
    import bisect
    i = bisect.bisect_right(syms, (va, '\uffff')) - 1
    return '%s+%X' % (syms[i][1], va - syms[i][0]) if i >= 0 else '?'

for a in sys.argv[2:]:
    ret = int(a, 16)
    if syms:
        print('%08X: in %s' % (ret, symbol(ret)))
    b6 = read(ret - 6, 6)
    b5 = read(ret - 5, 5)
    what = 'no call before it'
    if b6[:2] == b'\xff\x15':
        t = struct.unpack('<I', b6[2:6])[0]
        what = 'call [%08X] -> %s' % (t, iat.get(t, 'not an import slot'))
    elif b5[:1] == b'\xe8':
        dest = (ret + struct.unpack('<i', b5[1:5])[0]) & 0xffffffff
        s = slot(dest)
        what = 'call %08X' % dest + (' -> jmp [%08X] -> %s' % (s, iat.get(s, '?')) if s else '')
    print('%08X: %s' % (ret, what))

    if capstone and what == 'no call before it':
        # linear sweep from the start offset that ends exactly at ret
        md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
        for back in range(48, 0, -1):
            code = read(ret - back, back)
            ins = list(md.disasm(code, ret - back))
            if ins and ins[-1].address + ins[-1].size == ret and sum(i.size for i in ins) == back:
                for i in ins[-12:]:
                    note = ''
                    for k, v in iat.items():
                        if ('0x%x' % k) in i.op_str:
                            note = '   ; ' + v
                    print('    %08X  %-8s %s%s' % (i.address, i.mnemonic, i.op_str, note))
                break
