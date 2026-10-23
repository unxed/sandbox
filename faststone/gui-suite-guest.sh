#!/bin/sh
# One isolated GUI job inside the disposable QEMU Linux guest.
# Usage: gui-suite-guest.sh VERSION SCENARIO DISPLAY [OBSERVED_PLAN_TSV]
set -eu
version=${1:?version required}
scenario=${2:?scenario required}
display_number=${3:?private X display required}
plan_file=${4-}
case "$version" in
  5.6) app_source=/work/downloads/FastStone56 ;;
  7.5) app_source=/work/downloads/FastStone75 ;;
  8.5) app_source=/work/downloads/FastStone85/FSViewer85 ;;
  *) echo "Unsupported test version: $version" >&2; exit 2 ;;
esac
case "$display_number" in *[!0-9]*|'') echo 'Display must be numeric' >&2; exit 2 ;; esac
case "$scenario" in *[!a-z0-9-]*|'') echo 'Scenario must be a simple name' >&2; exit 2 ;; esac
test -f "$app_source/FSViewer.exe"
test -f /work/test-fixtures/image-000.jpg
test -x /work/test-bin/gui-suite-x11-bridge
wine_root=${GUI_SUITE_WINE_ROOT-/work/wine-image-build}
test -x "$wine_root/wine"
test -x "$wine_root/server/wineserver"
run_tag=${GUI_SUITE_RUN_TAG-baseline}
case "$run_tag" in *[!a-zA-Z0-9_-]*|'') echo 'Run tag must be a simple name' >&2; exit 2 ;; esac
artifacts=/work/evidence/gui-$run_tag/$version-$scenario-d$display_number
test ! -e "$artifacts"
mkdir -p "$artifacts"
state=$(mktemp -d /tmp/gui-$version-$scenario.XXXXXX)
mkdir -m 700 "$state/runtime"
cp -a "$app_source" "$state/app"
cp -a /work/test-fixtures "$state/images"
export WINEPREFIX=$state/prefix
golden_prefix=${GUI_SUITE_GOLDEN_PREFIX-/work/guest-state/golden-prefix.tar.gz}
if test -f "$golden_prefix"; then
  mkdir -p "$WINEPREFIX"
  tar -xzf "$golden_prefix" -C "$WINEPREFIX"
  sha256sum "$golden_prefix" >"$artifacts/golden-prefix.sha256"
fi
export WINESERVER=$wine_root/server/wineserver
export WINEDEBUG=-all
export WINEDLLOVERRIDES='mscoree,mshtml=;winemenubuilder.exe=d'
export XDG_RUNTIME_DIR=$state/runtime
export DISPLAY=:$display_number
if test -d /work/test-bin/x11-libs; then
  export LD_LIBRARY_PATH=/work/test-bin/x11-libs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
fi
xpid=
wmpid=
cleanup() {
  "$WINESERVER" -k >/dev/null 2>&1 || true
  test -z "$wmpid" || kill "$wmpid" >/dev/null 2>&1 || true
  test -z "$xpid" || kill "$xpid" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM
Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp -ac -extension GLX >"$artifacts/xvfb.log" 2>&1 &
xpid=$!
sleep 1
if command -v openbox >/dev/null 2>&1; then
  openbox --sm-disable >"$artifacts/wm.log" 2>&1 &
  wmpid=$!
  echo openbox >"$artifacts/window-manager.txt"
else
  echo 'none: focus/z-order results apply to unmanaged Xvfb only' >"$artifacts/window-manager.txt"
fi
echo "ARTIFACTS=$artifacts"
timeout 240 "$wine_root/wine" wineboot.exe -u >"$artifacts/wineboot.log" 2>&1
win_app="Z:$(printf '%s' "$state/app/FSViewer.exe" | sed 's|/|\\|g')"
win_image="Z:$(printf '%s' "$state/images/image-000.jpg" | sed 's|/|\\|g')"
win_artifacts="Z:$(printf '%s' "$artifacts" | sed 's|/|\\|g')"
if test -n "$plan_file"; then
  cp "$plan_file" "$artifacts/observed-plan.tsv"
  win_plan="Z:$(printf '%s' "$artifacts/observed-plan.tsv" | sed 's|/|\\|g')"
  set -- --plan "$win_plan"
else
  set --
fi
set +e
timeout 360 /work/test-bin/gui-suite-x11-bridge "$wine_root/wine" /work/test-bin/gui-suite.exe \
  --app "$win_app" --image "$win_image" --out "$win_artifacts" \
  --scenario "$scenario" --timeout-ms 180000 --external-input "$@" >"$artifacts/driver.log" 2>&1
status=$?
set -e
echo "$status" >"$artifacts/driver.exit"
tail -20 "$artifacts/driver.log"
echo "DRIVER_EXIT=$status"
exit "$status"
