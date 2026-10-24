#!/bin/sh
# Run in the disposable Linux guest after the golden Wine prefix is ready.
# Each concurrent invocation needs a unique LABEL_PREFIX and LABEL_DISPLAY.
set -eu

: "${LABEL_WINE:?Set LABEL_WINE to the Wine executable in the guest}"
: "${LABEL_WINESERVER:?Set LABEL_WINESERVER to the matching wineserver executable}"
: "${LABEL_GOLDEN:?Set LABEL_GOLDEN to a stopped, initialized Wine prefix}"
: "${LABEL_PREFIX:?Set LABEL_PREFIX to a NEW host-backed path under /work/guest-state}"
: "${LABEL_OUTPUT:?Set LABEL_OUTPUT to the results directory}"
: "${LABEL_PROBE32:?Set LABEL_PROBE32 to the 32-bit builtin probe executable}"
: "${LABEL_PROBE64:?Set LABEL_PROBE64 to the 64-bit builtin probe executable}"
: "${LABEL_NATIVE_PROBE:?Set LABEL_NATIVE_PROBE to the 32-bit probe beside native comctl32.dll}"
LABEL_DISPLAY=${LABEL_DISPLAY:-:11}
LABEL_VIEW=${LABEL_VIEW:-icon}
LABEL_FONT=${LABEL_FONT:-default}
LABEL_TIMEOUT=${LABEL_TIMEOUT:-120}

case "$LABEL_PREFIX" in /work/guest-state/*) ;; *) echo 'Prefix must be under /work/guest-state, outside the limited guest tmpfs' >&2; exit 2;; esac
[ "$LABEL_PREFIX" != "$LABEL_GOLDEN" ] || { echo 'A private prefix is required' >&2; exit 2; }
[ ! -e "$LABEL_PREFIX" ] || { echo 'Private prefix already exists; refusing to overwrite it' >&2; exit 2; }
[ -f "$LABEL_GOLDEN/user.reg" ] || { echo 'Golden prefix is not initialized' >&2; exit 2; }
[ -f "$(dirname "$LABEL_NATIVE_PROBE")/comctl32.dll" ] || { echo 'Missing app-local native comctl32.dll' >&2; exit 2; }
mkdir -p "$LABEL_OUTPUT"
if [ -n "${LABEL_PRECLONED_PREFIX_SOURCE:-}" ]; then
    prepared=$(cd "$LABEL_PRECLONED_PREFIX_SOURCE" && pwd -P)
    golden=$(cd "$LABEL_GOLDEN" && pwd -P)
    mkdir -p "$(dirname "$LABEL_PREFIX")"
    destination=$(cd "$(dirname "$LABEL_PREFIX")" && pwd -P)/$(basename "$LABEL_PREFIX")
    case "$destination" in /work/guest-state/*) ;; *) echo 'Destination must be under /work/guest-state' >&2; exit 2;; esac
    case "$prepared" in /work/guest-state/*) ;; *) echo 'Prepared clone must be under /work/guest-state' >&2; exit 2;; esac
    case "$prepared/" in "$golden/"*|"$destination/"*) echo 'Prepared clone overlaps golden/destination' >&2; exit 2;; esac
    case "$golden/" in "$prepared/"*) echo 'Prepared clone contains golden' >&2; exit 2;; esac
    case "$destination/" in "$prepared/"*) echo 'Prepared clone contains destination' >&2; exit 2;; esac
    test -f "$prepared/user.reg"
    mv "$prepared" "$LABEL_PREFIX"
else
    cp -a "$LABEL_GOLDEN" "$LABEL_PREFIX"
fi
export DISPLAY="$LABEL_DISPLAY" WINEPREFIX="$LABEL_PREFIX" WINESERVER="$LABEL_WINESERVER"
export WINEDEBUG=${LABEL_WINEDEBUG:--all,err+all,+loaddll}
export WINEDLLOVERRIDES='mscoree,mshtml='
xpid= wmpid=

cleanup()
{
    "$LABEL_WINESERVER" -k >/dev/null 2>&1 || true
    timeout 15 "$LABEL_WINESERVER" -w >/dev/null 2>&1 || true
    [ -z "$wmpid" ] || kill "$wmpid" 2>/dev/null || true
    [ -z "$xpid" ] || kill "$xpid" 2>/dev/null || true
    if [ "${LABEL_KEEP_PREFIX:-0}" != 1 ]; then rm -rf "$LABEL_PREFIX"; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp >"$LABEL_OUTPUT/xvfb.log" 2>&1 &
xpid=$!
sleep 1
kill -0 "$xpid" || { echo 'Private Xvfb did not start' >&2; exit 2; }
if command -v openbox >/dev/null 2>&1; then
    openbox >"$LABEL_OUTPUT/openbox.log" 2>&1 &
    wmpid=$!
fi
"$LABEL_WINE" --version >"$LABEL_OUTPUT/wine-version.txt" 2>&1
sha256sum "$(dirname "$LABEL_NATIVE_PROBE")/comctl32.dll" >"$LABEL_OUTPUT/native-dll.sha256"

# Apply native-only loading to this executable, not to explorer/shell32 or
# service processes. Native cc580 cannot replace Wine's system comctl32 globally.
native_exe=${LABEL_NATIVE_PROBE##*/}
override_key="HKCU\\Software\\Wine\\AppDefaults\\$native_exe\\DllOverrides"
timeout "$LABEL_TIMEOUT" "$LABEL_WINE" reg.exe add "$override_key" /v comctl32 /t REG_SZ /d native /f >"$LABEL_OUTPUT/native-override.log" 2>&1

run_probe()
{
    kind=$1
    executable=$2
    shift 2
    if [ "$LABEL_VIEW" != all ]; then set -- "$@" --view "$LABEL_VIEW"; fi
    if [ "$LABEL_FONT" != all ]; then set -- "$@" --font "$LABEL_FONT"; fi
    if timeout "$LABEL_TIMEOUT" "$LABEL_WINE" "$executable" --measure-only "$@" >"$LABEL_OUTPUT/$kind.jsonl" 2>"$LABEL_OUTPUT/$kind.log"; then
        probe_rc=0
    else
        probe_rc=$?
    fi
    printf '%s\n' "$probe_rc" >"$LABEL_OUTPUT/$kind.exit"
    printf '%s=%s\n' "$kind" "$probe_rc"
}

run_probe native32 "$LABEL_NATIVE_PROBE" --require-native-cc580
# Environment load order precedes the per-executable registry entry. These
# comparisons must use builtin controls even if the executable names coincide.
export WINEDLLOVERRIDES='comctl32=b;*comctl32=b;mscoree,mshtml='
run_probe builtin32 "$LABEL_PROBE32"
run_probe builtin64 "$LABEL_PROBE64"

test "$(cat "$LABEL_OUTPUT/native32.exit")" = 0
test "$(cat "$LABEL_OUTPUT/builtin32.exit")" = 0
test "$(cat "$LABEL_OUTPUT/builtin64.exit")" = 0
