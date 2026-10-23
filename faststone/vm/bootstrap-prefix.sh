#!/bin/sh
# Run in the offline test guest before cloning isolated GUI prefixes.
set -eu
wine_root=${VM_WINE_ROOT-/work/prebuilt/wine-11.20-amd64-wow64}
export WINEPREFIX=${VM_GOLDEN_PREFIX-/work/guest-state/golden-prefix}
export WINESERVER=$wine_root/bin/wineserver
export WINEDEBUG=-all
export WINEDLLOVERRIDES='mscoree,mshtml,winemenubuilder.exe='
export DISPLAY=:0
case "$WINEPREFIX" in /work/guest-state/*) ;; *) echo 'Prefix must be workspace backed' >&2; exit 2 ;; esac
test ! -e "$WINEPREFIX/.initialized"
mkdir -p "$WINEPREFIX"
openbox --sm-disable >/work/evidence/guest-bootstrap-wm.log 2>&1 &
wm_pid=$!
trap 'kill "$wm_pid" 2>/dev/null || true' EXIT
"$wine_root/bin/wine" --version
timeout 240 "$wine_root/bin/wine" wineboot -i
timeout 60 "$WINESERVER" -w
test -f "$WINEPREFIX/system.reg"
test -f "$WINEPREFIX/drive_c/windows/system32/kernel32.dll"
touch "$WINEPREFIX/.initialized"
du -sh "$WINEPREFIX"
echo GOLDEN_PREFIX_READY
