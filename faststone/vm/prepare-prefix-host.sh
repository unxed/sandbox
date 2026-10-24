#!/bin/sh
# Seed a NEW prefix with Wine PE files on the host before guest wineboot.
# This avoids slow copying through emulated 9p. It does not replace wineboot.
set -eu
runtime=${1:?installed Wine runtime required}
prefix=${2:?new prefix path required}
test -x "$runtime/bin/wine"
test ! -e "$prefix" || { echo 'Refusing to overwrite an existing prefix' >&2; exit 2; }
library=$runtime/lib/wine
test -d "$library/x86_64-windows" || library=$runtime/lib64/wine
test -d "$library/x86_64-windows"
test -d "$library/i386-windows"
mkdir -p "$prefix/drive_c/windows/system32" "$prefix/drive_c/windows/syswow64"
cp -a --reflink=auto "$library/x86_64-windows"/. "$prefix/drive_c/windows/system32"/
cp -a --reflink=auto "$library/i386-windows"/. "$prefix/drive_c/windows/syswow64"/
echo 'PE files seeded; run guest wineboot before cloning this prefix.'
