#!/bin/sh
# Run only inside the disposable Linux guest. All prefixes/results are host-backed.
# MODE=builtin64|builtin32|native32|all (default all), MAX_JOBS=2.
# A completed baseline is a measurement, not a declaration that assertions pass.
set -eu
WINE=${WINE:-/work/prebuilt/wine-11.20-amd64-wow64/bin/wine}
WINE_SERVER=${WINE_SERVER:-/work/prebuilt/wine-11.20-amd64-wow64/bin/wineserver}
GOLDEN_PREFIX=${GOLDEN_PREFIX:-/work/guest-state/golden-prefix}
TEST_BIN=${TEST_BIN:-/work/test-bin}
NATIVE_DLL=${NATIVE_DLL:-/work/test-bin/native/comctl32.dll}
MODE=${MODE:-all}
MAX_JOBS=${MAX_JOBS:-2}
RUN_ID=${RUN_ID:-baseline-$(date -u +%Y%m%dT%H%M%SZ)-$$}
STATE_DIR=${STATE_DIR:-/work/guest-state}
RESULTS_DIR=${RESULTS_DIR:-/work/evidence/listview-$RUN_ID}
DISPLAY_BASE=${DISPLAY_BASE:-112}
BUILTIN_DLL=${BUILTIN_DLL:-comctl32.dll}
BUILTIN_OVERRIDE=${BUILTIN_OVERRIDE:-b}
case "$RUN_ID" in ''|*[!A-Za-z0-9_.-]*) echo 'Invalid RUN_ID' >&2; exit 2;; esac
case "$MAX_JOBS" in 1|2|3) ;; *) echo 'MAX_JOBS must be 1, 2 or 3' >&2; exit 2;; esac
case "$MODE" in builtin64|builtin32|native32|all) ;; *) echo 'Unknown MODE' >&2; exit 2;; esac
test -x "$WINE"
test -x "$WINE_SERVER"
test -f "$GOLDEN_PREFIX/system.reg"
mkdir -p "$RESULTS_DIR" "$STATE_DIR"
"$WINE" --version > "$RESULTS_DIR/wine-version.txt" 2>&1

run_one()
(
    mode=$1
    display=$2
    prefix="$STATE_DIR/listview-$RUN_ID-$mode"
    log="$RESULTS_DIR/$mode.log"
    test ! -e "$prefix" || { echo "Prefix already exists: $prefix" >&2; exit 2; }
    if [ -n "${PREFIX_POOL:-}" ]; then
        prepared="$PREFIX_POOL/$mode"
        case "$prepared" in /work/guest-state/*) ;; *) echo 'Prefix pool must be under /work/guest-state' >&2; exit 2;; esac
        test -f "$prepared/system.reg"
        mv "$prepared" "$prefix"
    else
        cp -a "$GOLDEN_PREFIX" "$prefix"
    fi
    export WINEPREFIX="$prefix" DISPLAY=:$display WINESERVER="$WINE_SERVER"
    export WINEDEBUG=${PROBE_WINEDEBUG:--all,err+all,+loaddll}
    unset WINEBOOTSTRAPMODE
    xpid=
    cleanup()
    {
        "$WINE_SERVER" -k >/dev/null 2>&1 || true
        if [ -n "$xpid" ]; then kill "$xpid" >/dev/null 2>&1 || true; fi
    }
    trap cleanup EXIT HUP INT TERM
    Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp -ac -extension GLX > "$RESULTS_DIR/$mode-xvfb.log" 2>&1 &
    xpid=$!
    attempts=0
    while [ ! -S "/tmp/.X11-unix/X$display" ]; do
        attempts=$((attempts+1))
        [ "$attempts" -lt 100 ] || { echo 'Xvfb did not become ready' >&2; exit 2; }
        sleep 0.2
    done
    status=0
    case "$mode" in
        builtin64) executable="$TEST_BIN/listview-regression64.exe";;
        builtin32|native32) executable="$TEST_BIN/listview-regression32.exe";;
    esac
    test -f "$executable"
    if [ "$mode" = native32 ]; then
        test -f "$NATIVE_DLL"
        # Known-DLL lookup wins over an explicit Z: path for class registration
        # (CI run 40649390375: the ListView stayed builtin). Replace the 32-bit
        # system comctl32 inside this private, discarded prefix instead.
        cp "$NATIVE_DLL" "$prefix/drive_c/windows/syswow64/comctl32.dll"
        dll_win='C:\windows\syswow64\comctl32.dll'
        export WINEDLLOVERRIDES='mscoree,mshtml=;comctl32=n,b'
        sha256sum "$NATIVE_DLL" > "$RESULTS_DIR/native-reference-sha256.txt"
        timeout 180 "$WINE" "$executable" --dll "$dll_win" --expect-comctl 5.80 --measure > "$log" 2>&1 || status=$?
    else
        export WINEDLLOVERRIDES="mscoree,mshtml=;comctl32=$BUILTIN_OVERRIDE"
        timeout 180 "$WINE" "$executable" --dll "$BUILTIN_DLL" > "$log" 2>&1 || status=$?
    fi
    printf '%s\n' "$status" > "$RESULTS_DIR/$mode.program-exit"
    # Normalize CRLF so that downstream readers can parse one JSON object/line.
    tr -d '\r' < "$log" | sed -n '/^{/p' > "$RESULTS_DIR/$mode.ndjson"
    grep '"type":"summary"' "$RESULTS_DIR/$mode.ndjson" > "$RESULTS_DIR/$mode.summary.json" || {
        printf 'infrastructure-failed\n' > "$RESULTS_DIR/$mode.status"
        exit 2
    }
    if [ "$mode" = native32 ]; then
        # Explicit loaded-module path is in stderr and loader trace. Independently
        # require every registered control class to report the reference version.
        grep 'comctl32 module:' "$log" > "$RESULTS_DIR/native-loaded-module.txt" || exit 2
        grep -Fi "comctl32 module: $dll_win" "$log" >/dev/null || {
            printf 'wrong-native-loaded-path\n' > "$RESULTS_DIR/$mode.status"
            exit 2
        }
        grep 'ListView class module' "$log" > "$RESULTS_DIR/native-class-modules.txt" || exit 2
        if grep '"name":"class-module-is-selected-module","pass":false' "$RESULTS_DIR/$mode.ndjson" >/dev/null; then
            printf 'wrong-native-class-module\n' > "$RESULTS_DIR/$mode.status"
            exit 2
        fi
        if grep '"name":"class-module-has-required-reference-version","pass":false' "$RESULTS_DIR/$mode.ndjson" >/dev/null; then
            printf 'wrong-native-reference\n' > "$RESULTS_DIR/$mode.status"
            exit 2
        fi
        grep '"name":"class-module-has-required-reference-version","pass":true' "$RESULTS_DIR/$mode.ndjson" >/dev/null || exit 2
    fi
    printf 'measured\n' > "$RESULTS_DIR/$mode.status"
    # Return success for a complete baseline measurement even if it reproduces
    # the target defects; the program-exit and summary preserve those failures.
)

if [ "$MODE" != all ]; then
    run_one "$MODE" "$DISPLAY_BASE"
else
    failed=0
    if [ "$MAX_JOBS" = 1 ]; then
        run_one builtin64 "$DISPLAY_BASE" || failed=1
        run_one builtin32 "$((DISPLAY_BASE+1))" || failed=1
        run_one native32 "$((DISPLAY_BASE+2))" || failed=1
    else
        run_one builtin64 "$DISPLAY_BASE" & p1=$!
        run_one native32 "$((DISPLAY_BASE+2))" & p2=$!
        if [ "$MAX_JOBS" = 3 ]; then run_one builtin32 "$((DISPLAY_BASE+1))" & p3=$!; fi
        wait "$p1" || failed=1
        wait "$p2" || failed=1
        if [ "$MAX_JOBS" = 3 ]; then wait "$p3" || failed=1
        else run_one builtin32 "$((DISPLAY_BASE+1))" || failed=1; fi
    fi
    exit "$failed"
fi
