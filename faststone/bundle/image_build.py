#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Create a separate image-viewing Wine build without changing a full build.

The original completed configuration had an identical config.h after these
module-only changes, preserving compiled objects. Verify this on each new host.
"""
import argparse
import json
from pathlib import Path
import subprocess


def flags(source):
    omitted = []
    optional = {'d2d1', 'ddraw', 'ddrawex', 'dxgi', 'dxva2', 'evr', 'dxdiagn',
                'dxcore', 'winevulkan', 'vulkan-1', 'wined3d', 'winegstreamer',
                'wmp', 'wmvcore', 'wmvdecod', 'wmphoto', 'msmpeg2vdec',
                'msmpeg2adec', 'mp3dmod', 'mp4sdecd', 'mpg123', 'msdmo',
                'amstream', 'qasf', 'qcap'}
    for path in (source / 'dlls').iterdir():
        name = path.name
        if name.startswith(('d3d', 'd3dx', 'd3dcompiler_', 'mf')) or name in optional:
            omitted.append(name)
    options = ['--enable-archs=i386,x86_64', '--prefix=/opt/faststone-wine', '--disable-tests']
    options += ['--disable-' + name for name in sorted(omitted)]
    return options, sorted(omitted)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--build', type=Path, required=True)
    p.add_argument('--reuse-build', type=Path)
    p.add_argument('--stage', type=Path)
    p.add_argument('--jobs', type=int, default=4)
    p.add_argument('--configure-only', action='store_true')
    args = p.parse_args()
    source, build = args.source.resolve(), args.build.resolve()
    if build == source or (args.reuse_build and build == args.reuse_build.resolve()):
        raise SystemExit('source, reused build and image build must be distinct')
    if args.reuse_build and not build.exists():
        subprocess.run(['cp', '-a', '--reflink=auto', str(args.reuse_build.resolve()), str(build)], check=True)
    build.mkdir(parents=True, exist_ok=True)
    config = build / 'include/config.h'
    before = config.read_bytes() if config.exists() else None
    options, omitted = flags(source)
    (build / 'image-configure.flags').write_text('\n'.join(options) + '\n')
    with (build / 'image-configure.log').open('w') as log:
        subprocess.run([str(source / 'configure'), *options], cwd=build, stdout=log, stderr=subprocess.STDOUT, check=True)
    after = config.read_bytes()
    same = before == after if before is not None else None
    (build / 'image-config-check.json').write_text(json.dumps({
        'same_config_h': same, 'disabled_modules': omitted,
        'kept_required_media_modules': ['quartz', 'avifil32', 'msvfw32', 'winmm'],
    }, indent=2) + '\n')
    print('same config.h:', same, 'disabled DLL modules:', len(omitted), flush=True)
    if args.configure_only:
        return
    with (build / 'image-build.log').open('w') as log:
        subprocess.run(['make', '-j' + str(args.jobs)], cwd=build, stdout=log, stderr=subprocess.STDOUT, check=True)
    if args.stage:
        with (build / 'image-install.log').open('w') as log:
            subprocess.run(['make', 'install', 'DESTDIR=' + str(args.stage.resolve())], cwd=build,
                           stdout=log, stderr=subprocess.STDOUT, check=True)


if __name__ == '__main__':
    main()
