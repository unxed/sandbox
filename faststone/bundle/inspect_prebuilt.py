#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Inspect an installed Wine runtime without its original config.h.

Embedded library names are a conservative hint, not proof of a code path. The
image-viewing profile below names the X11, fonts and crypto entry points. Optional
hardware and multimedia providers are reported separately rather than silently
being treated as requirements for image viewing.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess

CORE_MODULES = {'winex11.so', 'win32u.so', 'dwrite.so', 'crypt32.so', 'secur32.so'}
OPTIONAL_NAMES = {'libGL.so.1', 'libEGL.so.1', 'libvulkan.so.1', 'libxkbregistry.so.0'}


def inspect(prefix):
    prefix = prefix.resolve()
    unix = prefix / 'lib/wine/x86_64-unix'
    if not unix.is_dir():
        unix = prefix / 'lib64/wine/x86_64-unix'
    env = dict(os.environ, LD_LIBRARY_PATH=str(unix))
    available = {}
    cache = subprocess.check_output(['ldconfig', '-p'], text=True)
    for line in cache.splitlines():
        match = re.match(r'\s*(\S+)\s+\([^)]*x86-64[^)]*\)\s+=>\s+(\S+)', line)
        if match:
            available.setdefault(match[1], match[2])
    embedded, missing, paths, versions = {}, {}, set(), set()
    modules = [*unix.glob('*.so'), unix/'wine', unix/'wine-preloader', prefix/'bin/wine', prefix/'bin/wineserver']
    for path in modules:
        if not path.is_file():
            continue
        names = sorted(set(m.decode('ascii') for m in re.findall(rb'lib[A-Za-z0-9_+.-]+\.so(?:\.[0-9]+)*', path.read_bytes())))
        embedded[path.name] = names
        p = subprocess.run(['ldd', str(path)], env=env, text=True, capture_output=True)
        unresolved = [line.strip() for line in p.stdout.splitlines() if 'not found' in line]
        if unresolved:
            missing[path.name] = unresolved
        for name in re.findall(r'(?:=>\s+)?(/[^\s]+)\s+\(', p.stdout):
            file = Path(name)
            if file.is_file() and not file.is_relative_to(prefix):
                paths.add(str(file))
        readelf = subprocess.run(['readelf', '--version-info', str(path)], text=True, capture_output=True)
        versions.update(re.findall(r'GLIBC_[0-9.]+', readelf.stdout))
    required = set()
    for module in CORE_MODULES:
        required.update(embedded.get(module, []))
    required -= OPTIONAL_NAMES
    optional = set().union(*(set(names) for names in embedded.values())) - required
    optional.update(OPTIONAL_NAMES)
    return {
        'prefix': str(prefix), 'unix_directory': str(unix),
        'required_dlopen': sorted(required), 'optional_dlopen': sorted(optional),
        'available_soname_paths': {name: available[name] for name in sorted(required|optional) if name in available},
        'missing_required_dlopen': sorted(required - available.keys()),
        'missing_optional_dlopen': sorted(optional - available.keys()),
        'linked_dependency_paths': sorted(paths), 'missing_dt_needed_by_module': missing,
        'embedded_library_names': embedded,
        'glibc_versions': sorted(versions, key=lambda s: [int(n) for n in s[6:].split('.')]),
        'note': 'SONAME extraction is a hint. Missing optional providers do not prove safe degradation; GUI tests are required.',
    }


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--wine-prefix', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--header', type=Path)
    args = p.parse_args()
    data = inspect(args.wine_prefix)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, indent=2)+'\n')
    if args.header:
        lines = ['/* Inferred image profile for a prebuilt Wine; not the original config.h. */']
        for index, name in enumerate(data['required_dlopen']):
            lines.append(f'#define SONAME_PREBUILT_{index} "{name}"')
        args.header.parent.mkdir(parents=True, exist_ok=True)
        args.header.write_text('\n'.join(lines)+'\n')
    print(json.dumps({key: data[key] for key in ('missing_required_dlopen', 'missing_dt_needed_by_module')}, indent=2))


if __name__ == '__main__':
    main()
