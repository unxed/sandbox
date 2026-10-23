#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
cd "$root"
mkdir -p test-bin/upstream
for pair in 'x86_64 64' 'i686 32'; do
 set -- $pair
 compiler=$1-w64-mingw32
 bits=$2
 case "$bits" in 64) arch=x86_64-windows;;32) arch=i386-windows;;esac
 "$compiler-windres" -D_WIN32 -DRC_INVOKED -Iwine-image-build/include -Iwine/include -Iwine/dlls/comctl32/tests \
  -i wine/dlls/comctl32/tests/rsrc.rc -o test-bin/upstream/rsrc$bits.o
 "$compiler-gcc" -DSTANDALONE -D__WINESRC__ -D__WINE_PE_BUILD -D_MSVCR_VER=0 -O2 -g0 \
  -Iwine-image-build/include -Iwine/include -Iwine/include/msvcrt -Iwine/dlls/comctl32/tests \
  -c wine/dlls/comctl32/tests/listview.c -o test-bin/upstream/listview$bits.o
 "$compiler-gcc" -o test-bin/upstream/listview$bits.exe test-bin/upstream/listview$bits.o test-bin/upstream/rsrc$bits.o \
  -Lwine-image-build/libs/winecrt0/$arch -lwinecrt0 \
  -lole32 -luser32 -lgdi32 -ladvapi32 -limm32 -luxtheme -loleacc -loleaut32 -lntdll
done
