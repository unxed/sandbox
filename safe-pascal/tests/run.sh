#!/usr/bin/env bash
# Тесты Safe Pascal. Всё собирается БЕЗ опций компилятора: файлы копируются
# в одну папку с safe.pas, как у пользователя (SPEC §2).
#   test_safe.pas      — рантайм; код возврата = число провалов
#   compile/*.pas      — первая строка "// EXPECT: fail|warn SAFE-Sx" или "// EXPECT: clean"
set -u
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
cp "$here/../safe.pas" "$here/test_safe.pas" "$here"/compile/*.pas "$work/"
cd "$work"
fpc -iV
fail=0

echo "== build test_safe"
if fpc test_safe.pas > build.log 2>&1; then
  grep -E 'Warning|Note|Hint' build.log | grep -v 'test_safe.pas' || true
  echo "== run test_safe"
  ./test_safe || fail=1
else
  cat build.log; fail=1
fi

echo "== compile checks"
for f in mf_*.pas; do
  read -r _ _ kind rule < "$f"
  if fpc "$f" > log 2>&1; then built=yes; else built=no; fi
  case "$kind" in
    fail)  ok=$([ $built = no ] && grep -q "$rule" log && echo 1) ;;
    warn)  ok=$([ $built = yes ] && grep -q "$rule" log && echo 1) ;;
    clean) ok=$([ $built = yes ] && ! grep -q 'SAFE-' log && echo 1) ;;
  esac
  if [ "${ok:-}" = 1 ]; then echo "ok   $f ($kind $rule)"
  else echo "FAIL $f (expected $kind $rule, built=$built):"; grep -E 'Error|Warning|Fatal' log | head -5; fail=1; fi
done
exit $fail
