#!/bin/sh
# Run Far under HX in DOSBox-X on Xvfb and take screenshots (hx-far/README.md).
# Usage: run.sh <C: drive dir> <output dir> <seconds> <shots...>
set -u
cdrive=$1 out=$2 total=$3; shift 3
mkdir -p "$out"
cat > "$out/dosbox-x.conf" <<CONF
[sdl]
output=surface
[dosbox]
memsize=256
[cpu]
core=dynamic
cputype=pentium
cycles=max
[dos]
lfn=true
[autoexec]
mount c "$cdrive"
c:
call C:\\RUN.BAT
CONF
Xvfb :99 -screen 0 1024x768x24 & xpid=$!
sleep 2
DISPLAY=:99 SDL_AUDIODRIVER=dummy dosbox-x -conf "$out/dosbox-x.conf" -nopromptfolder -fastlaunch \
  > "$out/dosbox-x.log" 2>&1 & dpid=$!
t=0
for s in "$@"; do
  sleep $((s - t)); t=$s
  DISPLAY=:99 import -window root "$out/shot-$(printf %03d "$s")s.png" || true
done
sleep $((total - t))
kill $dpid 2>/dev/null; sleep 1; kill -9 $dpid 2>/dev/null; kill $xpid 2>/dev/null
exit 0
