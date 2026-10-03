#!/usr/bin/env bash
# Тесты Safe Pascal. Всё собирается БЕЗ опций компилятора: файлы копируются
# в одну папку с safe.pas, как у пользователя (SPEC §2).
#   test_*.pas         — рантайм; код возврата = число провалов
#   compile/*.pas      — первая строка "// EXPECT: fail|warn SAFE-Sx", "clean" или "run" (clean + код 0)
set -u
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
cp "$here/../safe.pas" "$here"/*.pas "$here"/compile/*.pas "$work/"
cd "$work"
fpc -iV
fail=0

for t in test_*.pas; do
  t=${t%.pas}
  echo "== build $t"
  if fpc "$t.pas" > build.log 2>&1; then
    grep -E 'Warning|Note|Hint' build.log | grep -v "$t.pas" || true
    echo "== run $t"
    timeout 120 "./$t" || fail=1
  else
    cat build.log; fail=1
  fi
done

echo "== compile checks"
for f in mf_*.pas; do
  read -r _ _ kind rule < "$f"
  if fpc "$f" > log 2>&1; then built=yes; else built=no; fi
  case "$kind" in
    fail)  ok=$([ $built = no ] && grep -q "$rule" log && echo 1) ;;
    warn)  ok=$([ $built = yes ] && grep -q "$rule" log && echo 1) ;;
    clean) ok=$([ $built = yes ] && ! grep -q 'SAFE-' log && echo 1) ;;
    run)   ok=$([ $built = yes ] && ! grep -q 'SAFE-' log && timeout 60 "./${f%.pas}" && echo 1) ;;
  esac
  if [ "${ok:-}" = 1 ]; then echo "ok   $f ($kind $rule)"
  else echo "FAIL $f (expected $kind $rule, built=$built):"; grep -E 'Error|Warning|Fatal' log | head -5; fail=1; fi
done
exit $fail
