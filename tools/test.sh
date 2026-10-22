#!/bin/sh
# Builds the units of src/ with Free Pascal 3.2 (mode objfpc) and runs every tests/t_*.pas.
# A test passes when its last line starts with "ALL OK".
# Usage: tools/test.sh [build]    "build" only compiles the units.
# Environment: FPC (compiler, default fpc), TEST_OUT (output directory, default build/ in the repository).
root=$(cd "$(dirname "$0")/.." && pwd)
out=${TEST_OUT:-$root/build}
fpc=${FPC:-fpc}
mode=${1:-all}

units=""
for u in "$root"/src/*.pas; do
    [ -e "$u" ] && units="$units $u"
done
tests=""
for t in "$root"/tests/t_*.pas; do
    [ -e "$t" ] && tests="$tests $t"
done

if [ -z "$units" ]; then
    echo "no unit in src/: nothing to build"
    exit 0
fi
if [ "$mode" != build ] && [ -z "$tests" ]; then
    echo "no test in tests/: nothing to run"
fi

mkdir -p "$out"
failed=0
for u in $units; do
    name=$(basename "$u")
    if "$fpc" -Mobjfpc -Fu"$root/src" -FU"$out" -FE"$out" "$u" >"$out/$name.log" 2>&1; then
        echo "built $name"
    else
        echo "BUILD FAILED $name"
        cat "$out/$name.log"
        failed=$((failed + 1))
    fi
done
[ "$mode" = build ] && exit $((failed > 0))

for t in $tests; do
    name=$(basename "$t" .pas)
    if ! "$fpc" -Mobjfpc -Fu"$root/src" -Fi"$root/tests" -FU"$out" -FE"$out" "$t" >"$out/$name.log" 2>&1; then
        echo "BUILD FAILED $name"
        cat "$out/$name.log"
        failed=$((failed + 1))
        continue
    fi
    "$out/$name" >"$out/$name.out" 2>&1
    last=$(tail -n 1 "$out/$name.out")
    case "$last" in
        "ALL OK"*) echo "pass $name: $last" ;;
        *) echo "FAIL $name"; cat "$out/$name.out"; failed=$((failed + 1)) ;;
    esac
done
[ "$failed" -eq 0 ] && echo "all tests passed" || echo "$failed failed"
exit $((failed > 0))
