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
wine_bin=${GUI_SUITE_WINE-$wine_root/wine}
wine_server=${GUI_SUITE_WINESERVER-$wine_root/server/wineserver}
test -x "$wine_bin"
test -x "$wine_server"
command -v openbox >/dev/null 2>&1 || { echo 'Openbox is required for focus/Z-order tests' >&2; exit 2; }
run_tag=${GUI_SUITE_RUN_TAG-baseline}
case "$run_tag" in *[!a-zA-Z0-9_-]*|'') echo 'Run tag must be a simple name' >&2; exit 2 ;; esac
artifacts=/work/evidence/gui-$run_tag/$version-$scenario-d$display_number
test ! -e "$artifacts"
mkdir -p "$artifacts"
# The guest RAM filesystem cannot hold a complete Wine prefix.
mkdir -p /work/guest-state/jobs
state=$(mktemp -d /work/guest-state/jobs/gui-$version-$scenario.XXXXXX)
export WINEPREFIX=$state/prefix
export WINESERVER=$wine_server
xpid=
wmpid=
cleanup() {
  "$WINESERVER" -k >/dev/null 2>&1 || true
  timeout 20 "$WINESERVER" -w >/dev/null 2>&1 || true
  test -z "$wmpid" || kill "$wmpid" >/dev/null 2>&1 || true
  test -z "$xpid" || kill "$xpid" >/dev/null 2>&1 || true
  case "$state" in /work/guest-state/jobs/gui-*) rm -rf -- "$state" ;; esac
}
trap cleanup EXIT INT TERM
mkdir -m 700 "$state/runtime"
cp -a "$app_source" "$state/app"
cp -a /work/test-fixtures "$state/images"
golden_prefix=${GUI_SUITE_GOLDEN_PREFIX-/work/guest-state/golden-prefix}
# Bootstrap once outside this wrapper. Every job receives private registries.
# Re-running wineboot -u here re-registers the complete DLL set unnecessarily.
if test -n "${GUI_SUITE_PRECLONED_PREFIX_ROOT-}"; then
  prepared_prefix=$GUI_SUITE_PRECLONED_PREFIX_ROOT/$version-$scenario
  case "$prepared_prefix" in /work/guest-state/*) ;; *) echo 'Prepared prefixes must be under /work/guest-state' >&2; exit 2 ;; esac
  test -f "$prepared_prefix/system.reg"
  test -d "$prepared_prefix/drive_c"
  mv "$prepared_prefix" "$WINEPREFIX"
  printf '%s\n' "$prepared_prefix" >"$artifacts/precloned-prefix-source.txt"
elif test -d "$golden_prefix"; then
  test -f "$golden_prefix/system.reg" || { echo 'Golden prefix is not initialized' >&2; exit 2; }
  mkdir -p "$WINEPREFIX"
  cp -a "$golden_prefix"/. "$WINEPREFIX"/
  printf '%s\n' "$golden_prefix" >"$artifacts/golden-prefix-source.txt"
elif test -f "$golden_prefix"; then
  mkdir -p "$WINEPREFIX"
  tar -xzf "$golden_prefix" -C "$WINEPREFIX"
  sha256sum "$golden_prefix" >"$artifacts/golden-prefix.sha256"
else
  echo 'Initialize GUI_SUITE_GOLDEN_PREFIX once before parallel GUI tests' >&2
  exit 2
fi
test -f "$WINEPREFIX/system.reg"
export WINEDEBUG=${GUI_SUITE_WINEDEBUG:--all,err+all}
export WINEDLLOVERRIDES='mscoree,mshtml=;winemenubuilder.exe=d'
export XDG_RUNTIME_DIR=$state/runtime
export DISPLAY=:$display_number
if test -d /work/test-bin/x11-libs; then
  export LD_LIBRARY_PATH=/work/test-bin/x11-libs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
fi
Xvfb "$DISPLAY" -displayfd 3 -screen 0 1280x800x24 -nolisten tcp -ac -extension GLX \
  3>"$state/x-ready" >"$artifacts/xvfb.log" 2>&1 &
xpid=$!
ready_attempt=0
while test ! -s "$state/x-ready"; do
  kill -0 "$xpid" 2>/dev/null || { echo 'Xvfb exited before readiness' >&2; exit 1; }
  ready_attempt=$((ready_attempt+1))
  test "$ready_attempt" -lt 150 || { echo 'Xvfb startup timed out' >&2; exit 1; }
  sleep 0.2
done
  openbox --sm-disable >"$artifacts/wm.log" 2>&1 &
  wmpid=$!
  sleep 1
  kill -0 "$wmpid" 2>/dev/null || { echo 'Openbox failed; inspect wm.log' >&2; exit 1; }
  openbox --version >"$artifacts/window-manager.txt" 2>&1
echo "ARTIFACTS=$artifacts"
printf 'initialized-template clone; explicit wineboot update skipped\n' >"$artifacts/prefix-initialization.txt"
"$wine_bin" --version >"$artifacts/wine-version.txt" 2>&1
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
timeout 180 /work/test-bin/gui-suite-x11-bridge "$wine_bin" /work/test-bin/gui-suite.exe \
  --app "$win_app" --image "$win_image" --out "$win_artifacts" \
  --scenario "$scenario" --timeout-ms 60000 --external-input "$@" >"$artifacts/driver.log" 2>&1
status=$?
set -e
echo "$status" >"$artifacts/driver.exit"
tail -20 "$artifacts/driver.log"
echo "DRIVER_EXIT=$status"
exit "$status"
