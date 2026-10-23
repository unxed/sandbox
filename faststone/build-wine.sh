#!/bin/sh
# Image-viewer build: keep required AVI/Quartz imports but omit 3D shader stacks.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
cd "$root"
mkdir -p wine-image-build evidence
set -- --enable-archs=i386,x86_64 --prefix=/opt/faststone-wine \
 --disable-tests --enable-silent-rules --without-vulkan --without-opengl \
 --without-gstreamer --without-wayland --without-alsa --without-pulse
for directory in wine/dlls/*; do
 name=${directory##*/}
 case "$name" in
  d3d8|d3d9|d3d10*|d3d11|d3d12*|d3dcompiler_*|d3dx9_*|d3dx10_*|d3dx11_*|wined3d|winevulkan)
   set -- "$@" "--disable-$name";;
 esac
done
printf '%s\n' "$@" > evidence/wine-image-configure.flags
cd wine-image-build
CFLAGS='-O2 -g0' ../wine/configure "$@" > configure.log 2>&1
make -j"${JOBS:-8}" > build.log 2>&1
