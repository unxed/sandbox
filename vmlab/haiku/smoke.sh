#!/bin/sh
# Runs inside the Haiku guest. Fetches f4 (+ the ptyrun harness) from the vmlab
# host (10.0.2.2:8000), probes f4 non-interactively, then drives it on a pty
# and uploads everything as smoke.log (the host renders the PTYSNAP blocks).
H=http://10.0.2.2:8000
mkdir -p /tmp/t && cd /tmp/t || exit 1
{
echo "== uname";      uname -a
echo "== date";       date
echo "== fetch"
curl -sf -o f4 $H/f4-haiku-amd64 && chmod +x f4 && ls -l f4 || echo "FETCH f4 FAILED"
curl -sf -o ptyrun $H/ptyrun-haiku && chmod +x ptyrun && ls -l ptyrun || echo "FETCH ptyrun FAILED"
echo "== f4 --version"; ./f4 --version;            echo "rc=$?"
echo "== f4 --help (head)"; ./f4 --help 2>&1 | head -6
mkdir -p demo/subdir demo/docs
echo "hello haiku" > demo/readme.txt; echo "second file" > demo/docs/notes.txt
cd demo
export HOME=/tmp/t XDG_CONFIG_HOME=/tmp/t/cfg
mkdir -p $XDG_CONFIG_HOME
echo "== ptyrun: f4 in tty mode (two snapshots, then Down + snapshot)"
../ptyrun -tag tui -cols 100 -rows 30 \
  -script 'wait:6000,snap:t6,key:\e[B,wait:1000,snap:down,key:\r,wait:1500,snap:enter' \
  -- ../f4 --tty --attached --debug
echo "== f4 logs"
find /tmp/t -name '*.log' -o -name '*crash*' 2>/dev/null | head
for f in $(find /tmp/t -name 'debug.log' 2>/dev/null | head -2); do echo "--- $f"; tail -40 "$f"; done
echo "== SMOKE DONE"
} > /tmp/t/smoke.log 2>&1
curl -s -T /tmp/t/smoke.log $H/upload/smoke.log
