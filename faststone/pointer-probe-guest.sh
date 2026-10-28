#!/bin/sh
# Run inside the offline guest. Usage: pointer-probe-guest.sh OUTDIR PREFIX DISPLAY
set -eu
out=$1; prefix=$2; display_number=$3
wine_bin=${GUI_SUITE_WINE:?}; wine_server=${GUI_SUITE_WINESERVER:?}
mkdir -p "$out"
export WINEPREFIX=$prefix WINESERVER=$wine_server DISPLAY=:$display_number
export WINEDEBUG=${GUI_SUITE_WINEDEBUG:--all,err+all}
export WINEDLLOVERRIDES='mscoree,mshtml=;winemenubuilder.exe=d'
mkdir -p /work/guest-state/probe-runtime; chmod 700 /work/guest-state/probe-runtime
export XDG_RUNTIME_DIR=/work/guest-state/probe-runtime
xpid= wmpid=
cleanup() {
  "$WINESERVER" -k >/dev/null 2>&1 || true
  test -z "$wmpid" || kill "$wmpid" >/dev/null 2>&1 || true
  test -z "$xpid" || kill "$xpid" >/dev/null 2>&1 || true
}
trap cleanup EXIT
Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp -ac -extension GLX >"$out/xvfb.log" 2>&1 &
xpid=$!
sleep 2
if test "${POINTER_PROBE_WM:-openbox}" = openbox; then
  openbox --sm-disable >"$out/wm.log" 2>&1 &
  wmpid=$!
  sleep 1
fi
"$wine_bin" --version >"$out/wine-version.txt" 2>&1
set +e
timeout 240 /work/test-bin/gui-suite-x11-bridge "$wine_bin" /work/test-bin/pointer-delivery-probe.exe >"$out/probe.log" 2>&1
echo $? >"$out/probe.exit"
