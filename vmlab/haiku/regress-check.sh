#!/bin/sh
# Runs inside the Haiku guest after the haiku-regress scenario has driven f4 through the Terminal
# window. Checks the effects on disk; the host fails the workflow on any "FAIL" line.
r=PASS
if [ "$(head -c 1 /boot/home/t/a.txt 2>/dev/null)" = X ]; then echo "ok   editor: F4 edit + F2 save reached the file (arrows/F3/F4/F2 keys work)"
else echo "FAIL editor: a.txt was not edited: $(head -c 40 /boot/home/t/a.txt 2>&1)"; r=FAIL; fi
if cmp -s /boot/home/t/a.txt /boot/home/a.txt; then echo "ok   copy: F5 copied a.txt into the other panel"
else echo "FAIL copy: /boot/home/a.txt missing or different"; r=FAIL; fi
if [ -f /boot/home/t/moved.txt ] && [ ! -f /boot/home/t/b.txt ]; then echo "ok   rename: F6 renamed b.txt to moved.txt"
else echo "FAIL rename: b.txt/moved.txt state wrong: $(ls /boot/home/t 2>&1 | tr '\n' ' ')"; r=FAIL; fi
if [ ! -e /boot/home/t/c.txt ]; then echo "ok   delete: F8 removed c.txt"
else echo "FAIL delete: c.txt still exists"; r=FAIL; fi
echo "--- /boot/home/t:"; ls -l /boot/home/t
echo "RESULT $r"
