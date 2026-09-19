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
# runtime repro candidates (each run watched separately)
i=1; while [ $i -le 6 ]; do run_one "/root/mnt/sigrepro nospawn" default $i 30; i=$((i+1)); done
i=1; while [ $i -le 6 ]; do run_one "/root/mnt/sigrepro spawn" default $i 30; i=$((i+1)); done
# the whole TUI in a pty, several times per configuration; a run "works" when F1 produces output
cat > /tmp/tui.sh <<'EOS'
cfg=$1; n=$2; shift 2
tag=$cfg-$n
export $cfg
rm -rf /tmp/cfg/f4
/root/mnt/ptyrun -tag $tag -cols 100 -rows 30 -script wait:6000,snap:t6,key:\e[B,wait:500,snap:down,key:\e[11~,wait:2500,snap:f1,key:\e,wait:800,snap:esc -- /root/mnt/f4 --tty --attached
EOS
for cfg in DEFAULT=1; do
  iter=1; while [ $iter -le 6 ]; do run_one "sh /tmp/tui.sh $cfg $iter" default 1 40; iter=$((iter+1)); done
done
# a wider scenario: viewer, editor, copy/mkdir/quit dialogs
run_one "/root/mnt/ptyrun -tag scn -cols 100 -rows 30 -script wait:6000,snap:s01-start,key:\e[B\e[B\e[B,wait:800,snap:s02-cursor,key:\e[13~,wait:2500,snap:s03-viewer,key:\e,wait:1200,key:\e[14~,wait:3000,snap:s04-editor,key:hello_from_f4_on_redox,wait:1000,snap:s05-typed,key:\e,wait:1500,snap:s06-editor-esc,key:\e,wait:1200,key:\e[15~,wait:2000,snap:s07-copy,key:\e,wait:1000,key:\e[18~,wait:2000,snap:s08-mkdir,key:\e,wait:800,key:\e[21~,wait:2000,snap:s09-quit -- /root/mnt/f4 --tty --attached" default 1 150
# one run with everything for the artifacts: debug log, SIGQUIT dump
run_one "/root/mnt/ptyrun -tag full -cols 100 -rows 30 -script wait:6000,snap:t6,key:\e[B,wait:500,snap:down,key:\e[11~,wait:2500,snap:f1,key:\e,wait:800,snap:esc,key:\e[20~,wait:2500,snap:menu,sig:QUIT,wait:2500 -- /root/mnt/f4 --tty --attached --debug" default 1 150
echo "=== f4 files"; find /tmp/cfg -type f 2>/dev/null | head -20
for f in $(ls /tmp/cfg/f4/crashes/stderr_* 2>/dev/null | head -1); do echo "=== SIGQUIT dump in $f"; echo "size: $(wc -c < $f)"; head -120 $f; done
echo "--- debug.log (tail)"; tail -40 /tmp/cfg/f4/logs/debug.log
echo "=== LADDER DONE"
