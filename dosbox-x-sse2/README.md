# dosbox-x-sse2: preparing SSE2 for DOSBox-X

Why: Far Manager 3 (x86) and its sqlite3.dll use SSE2 (`66 0F 13`, MOVLPD); DOSBox-X emulates a CPU
only up to the Pentium III (MMX, SSE). Plan and estimate: go2dos `docs/UTF8-DOS.md` section 7.

Work is in the fork https://github.com/unxed/dosbox-x (one branch per upstream PR); checks run only
here, in CI (`dosbox-x-test.yml`): the fork is built on Ubuntu and `ud.asm` is run in the guest.

`ud.asm` executes one instruction at a time with the `INT 6` (#UD) handler installed and reports
whether it raised #UD (`ud=1`) or ran (`ud=0`) against the expected value. The table has two parts:
MMX/SSE instructions that must run, and SSE2 encodings that must be #UD while SSE2 is not emulated
(before step 1 they silently ran as MMX). When SSE2 forms are implemented, their rows move from
"must be #UD" to "must run" (and get result checks).
