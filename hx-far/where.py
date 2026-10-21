"""Which imported function does a call return to <VA> go to?
Usage: where.py <PE file> <VA> [<VA>...]   (VA in hex, e.g. 43F22B)
Looks for `call [IAT]` (FF 15) or `call rel32` to a `jmp [IAT]` stub (FF 25)
just before each return address."""
import struct, sys
import pefile

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

for a in sys.argv[2:]:
    ret = int(a, 16)
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
