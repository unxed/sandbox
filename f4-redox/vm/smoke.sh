# Runs inside the Redox VM (sourced files are in /root/mnt).
. /root/mnt/common.sh
export HOME=/root TERM=xterm-256color
mkdir -p /tmp/cfg && export XDG_CONFIG_HOME=/tmp/cfg
echo "=== files"; ls -la /root/mnt
mkdir -p /tmp/demo/subdir /tmp/demo/docs && echo "hello redox" > /tmp/demo/readme.txt && echo "second file" > /tmp/demo/docs/notes.txt
cd /tmp/demo
run_one "/root/mnt/f4 --version" default 1 90
run_one "/root/mnt/f4 --help" default 1 90
run_one "/root/mnt/f4 --list-mounts" default 1 120
# 1) the session daemon on its own: how long until it binds its socket?
mkdir -p /tmp/sess
( /root/mnt/f4 --server /tmp/sess/d.sock --debug > /tmp/sess/d.out 2>&1 ; echo "daemon exit=$?" >> /tmp/sess/d.out ) &
i=0; while [ ! -e /tmp/sess/d.sock ] && [ $i -lt 90 ]; do sleep 1; i=$((i+1)); done
echo "=== daemon socket after ${i}s: $(ls -la /tmp/sess/d.sock 2>&1)"
grep f4 /scheme/sys/context | head -20
echo "--- daemon stdout/stderr"; tail -20 /tmp/sess/d.out
echo "--- daemon debug.log"; tail -40 /tmp/cfg/f4/logs/debug.log
for f in $(find /tmp/cfg -type f -name 'stderr_*' 2>/dev/null | head -3); do echo "--- $f (head)"; head -50 $f; done
pkill f4 2>/dev/null; sleep 1
rm -rf /tmp/cfg/f4
# 2) the whole TUI in a pty
run_one "/root/mnt/ptyrun -tag tui -cols 100 -rows 30 -script wait:12000,snap:t12,ctx:f4,wait:20000,snap:t32,ctx:f4 -- /root/mnt/f4 --tty --attached --debug" default 1 150
echo "=== f4 logs"; find /tmp/cfg /root /tmp/f4-sessions-0 -type f 2>/dev/null | head -20
for f in $(find /tmp/cfg -type f -name 'stderr_*' 2>/dev/null | head -3); do echo "--- $f (head)"; head -60 $f; done
echo "--- debug.log"; tail -60 /tmp/cfg/f4/logs/debug.log
echo "=== LADDER DONE"
