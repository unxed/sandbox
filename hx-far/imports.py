"""Imports of Far Manager (far.exe and plugins) against the exports of the
HX Win32 emulation DLLs (SrcEmu/*/*.DEF).  Usage: imports.py <far dir> <HX dir>.
Writes a Markdown report to stdout."""
import collections, glob, os, re, sys
import pefile

far, hx = sys.argv[1], sys.argv[2]

# DPMILD32 replaces these names (Src/DPMILDR/PELOAD.ASM, pReplacestrings)
REPLACE = {'kernel32': 'DKRNL32', 'advapi32': 'DADVAPI', 'user32': 'DUSER32',
           'gdi32': 'DGDI32', 'ntdll': 'DKRNL32', 'ddraw': 'DDDRAW'}

defs = {}
for d in glob.glob(os.path.join(hx, 'SrcEmu', '*', '*.[Dd][Ee][Ff]')):
    names, on = set(), False
    for line in open(d, encoding='latin-1'):
        s = line.split(';')[0].strip()
        if not s:
            continue
        # DEF directives are upper case; exports such as HeapSize are not
        if re.match(r'^EXPORTS\b', s):
            on = True
            continue
        if re.match(r'^(LIBRARY|NAME|DESCRIPTION|STACKSIZE|HEAPSIZE|IMPORTS|SECTIONS|VERSION)\b', s):
            on = False
            continue
        if on:
            names.add(re.split(r'[\s=@]', s)[0])
    key = os.path.splitext(os.path.basename(d))[0].upper()
    defs.setdefault(key, set()).update(names)

def hxdll(dll):
    b = os.path.splitext(dll.lower())[0]
    return REPLACE.get(b, b.upper())

missing = collections.defaultdict(lambda: collections.defaultdict(set))
nodll = collections.defaultdict(set)
total = collections.Counter()
info = []
pes = sorted(glob.glob(os.path.join(far, '**', '*.exe'), recursive=True) +
             glob.glob(os.path.join(far, '**', '*.dll'), recursive=True))
shipped = {os.path.basename(p).lower() for p in pes}
for path in pes:
    rel = os.path.relpath(path, far)
    try:
        pe = pefile.PE(path, fast_load=True)
        pe.parse_data_directories(directories=[
            pefile.DIRECTORY_ENTRY['IMAGE_DIRECTORY_ENTRY_IMPORT'],
            pefile.DIRECTORY_ENTRY['IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT']])
    except Exception as e:
        info.append(f'| {rel} | not a PE: {e} | | |')
        continue
    oh = pe.OPTIONAL_HEADER
    if pe.FILE_HEADER.Machine != 0x14c:
        info.append(f'| {rel} | machine {pe.FILE_HEADER.Machine:#x}, skipped | | |')
        continue
    info.append(f'| {rel} | subsystem {oh.Subsystem}, '
                f'{oh.MajorSubsystemVersion}.{oh.MinorSubsystemVersion} | '
                f'OS {oh.MajorOperatingSystemVersion}.{oh.MinorOperatingSystemVersion} | '
                f'{"delay imports" if hasattr(pe, "DIRECTORY_ENTRY_DELAY_IMPORT") else ""} |')
    entries = [(e, False) for e in getattr(pe, 'DIRECTORY_ENTRY_IMPORT', [])]
    entries += [(e, True) for e in getattr(pe, 'DIRECTORY_ENTRY_DELAY_IMPORT', [])]
    for e, delay in entries:
        dll = e.dll.decode('latin-1')
        h = hxdll(dll)
        for imp in e.imports:
            name = imp.name.decode('latin-1') if imp.name else f'#{imp.ordinal}'
            total[h] += 1
            tag = rel + (' (delay)' if delay else '')
            if dll.lower() in shipped:
                continue  # a DLL of Far itself, analysed as a file of its own
            if h not in defs:
                nodll[dll.lower()].add(tag)
            elif name not in defs[h]:
                missing[h][name].add(tag)

print('# Far Manager imports vs HX\n')
print('| file | subsystem | OS version | |\n|---|---|---|---|')
print('\n'.join(info))
print('\n## DLLs that HX does not have\n')
for dll in sorted(nodll):
    print(f'- `{dll}`: ' + ', '.join(sorted(nodll[dll])))
print('\n## Functions missing from HX DLLs\n')
for h in sorted(missing):
    print(f'### {h} ({len(missing[h])} missing)\n')
    for name in sorted(missing[h]):
        users = sorted(missing[h][name])
        short = ', '.join(users[:4]) + (f' and {len(users) - 4} more' if len(users) > 4 else '')
        print(f'- `{name}`: {short}')
    print()
n = sum(len(v) for v in missing.values())
print(f'\nTotal: {n} missing functions in {len(missing)} HX DLLs, '
      f'{len(nodll)} DLLs without an HX counterpart.')
