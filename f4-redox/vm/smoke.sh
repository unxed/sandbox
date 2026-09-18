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
# poll(2) on what f4's input reader watches
run_one "/root/mnt/ptyrun -tag pp -cols 80 -rows 24 -script wait:6000,snap:pp -- /root/mnt/pollprobe" default 1 60
run_one "/root/mnt/ptyrun -tag in -cols 80 -rows 24 -script wait:1500,key:hello,wait:1500,key:x,wait:5000,snap:in -- /root/mnt/pollprobe input" default 1 60
# the whole TUI in a pty (client + session daemon, fresh state)
run_one "/root/mnt/ptyrun -tag tui -cols 100 -rows 30 -script wait:700,sig:USR1,wait:900,sig:USR1,wait:1500,sig:USR1,wait:4000,snap:t8,ctx:f4,key:\e[B,wait:500,key:\e[B,wait:800,snap:down2,key:\e[11~,wait:2500,snap:f1,ctx:f4,key:\e,wait:1000,snap:esc,wait:2000,snap:t16 -- /root/mnt/f4 --tty --attached --debug" default 1 150
echo "=== sessions"; ls -la /tmp/f4-sessions-0 2>&1 | head
echo "=== f4 files"; find /tmp/cfg /tmp/f4-sessions-0 -type f 2>/dev/null | head -20
for f in $(find /tmp/cfg -type f -name 'debug*.log' 2>/dev/null | head -3); do echo "--- $f (tail)"; tail -80 $f; done
for f in $(find /tmp/cfg/f4/crashes -type f 2>/dev/null | head -6); do echo "--- $f (size $(wc -c < $f))"; done
f=$(ls -t /tmp/cfg/f4/crashes/* 2>/dev/null | head -1); [ -n "$f" ] && { echo "--- newest crash file $f"; head -150 $f; }
echo "=== LADDER DONE"
