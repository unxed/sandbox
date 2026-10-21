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

## Results

- 2026-10-21, step 1 (`mmx-strict-prefix`, one commit over `master` 029bd65): on `master`
  (run https://github.com/unxed/sandbox/actions/runs/39621675202) 15 SSE2 encodings of the table
  run as MMX (`ud=0`: `66 0F EF`, `66/F3 0F 6F`, `F3 0F 7E`, `66 0F 6E`, `66 0F 7F`,
  `66/F2/F3 0F 70`, `66 0F 60/FC/73/74/D5/F8`); on the branch
  (https://github.com/unxed/sandbox/actions/runs/39621762139) all 29 rows pass. Core `normal`,
  `cputype=pentium_iii`. `dynamic_x86` (32-bit hosts only) is not tested: x86-64 builds use `dynrec`,
  which has no MMX and hands such opcodes to the normal core; the matching change of
  `core_dyn_x86/decoder.h` (`decode.rep != REP_NONE || decode.big_op != cpu.code.big`) is prepared
  but not sent.
