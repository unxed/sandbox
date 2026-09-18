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
run_one "/root/mnt/ptyrun -tag tui -cols 100 -rows 30 -script wait:6000,snap:t6,ctx:f4,wait:6000,snap:t12,ctx:f4 -- /root/mnt/f4 --tty --attached --debug" default 1 150
echo "=== f4 logs"; find /tmp/cfg /root -type f \( -name '*.log' -o -name '*crash*' \) 2>/dev/null | head
for f in $(find /tmp/cfg /root -type f -name '*.log' 2>/dev/null | head -5); do echo "--- $f"; tail -60 $f; done
echo "=== LADDER DONE"
