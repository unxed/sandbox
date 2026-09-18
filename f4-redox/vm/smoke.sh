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
run_one "/root/mnt/ptyrun -tag tui -cols 100 -rows 30 -script wait:10000,snap:startup -- /root/mnt/f4 --tty --attached" default 1 150
echo "=== LADDER DONE"
