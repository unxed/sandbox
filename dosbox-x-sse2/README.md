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

- 2026-10-21, step 2 (`sse2-skeleton`, one commit over `mmx-strict-prefix`): option `[cpu] enable sse2`
  (default false), `CPU_SSE2()`, CPUID.1 EDX bit 26 (SSE2), bit 19 (CLFLUSH) and EBX[15:8]=8 with
  the option, `0F AE /5 LFENCE`, `/6 MFENCE`, `/7 CLFLUSH m` run with it and are #UD without it
  (`0F AE /6 m` stays #UD). Runs https://github.com/unxed/sandbox/actions/runs/39624069371 (default:
  bit 26 = 0, 34 of 34 rows pass, nothing changed) and https://github.com/unxed/sandbox/actions/runs/39624091997
  (`-f sse2=true`: bit 26 = 1, 34 of 34 pass).

- 2026-10-21, step 3 (`sse2-double`, one commit over `sse2-skeleton`): double precision with the 66
  (packed) and F2 (scalar) prefixes: `MOVUPD/MOVAPD/MOVSD/MOVLPD/MOVHPD/MOVNTPD/UNPCK[LH]PD/SHUFPD/
  MOVMSKPD`, `AND/ANDN/OR/XORPD`, `ADD/SUB/MUL/DIV/SQRT/MIN/MAX` (PD and SD), `COMISD/UCOMISD`,
  `CMPPD/CMPSD`, `CVTSI2SD/CVTTSD2SI/CVTSD2SI/CVTSS2SD/CVTSD2SS/CVTPS2PD/CVTPD2PS`. Run
  https://github.com/unxed/sandbox/actions/runs/39625343645 (`-f sse2=true -f sse2double=true`):
  `sse2.asm` 58 of 58 results match (including NaN rules of MIN/MAX/CMP, "integer indefinite" and
  MXCSR rounding of CVTSD2SI), `ud.asm` 34 of 34. Not implemented in this step: MXCSR exception
  flags and #XM, directed rounding of the arithmetic, `CVTPI2PD`, `CVTPD2PI`, `CVTDQ2PD` and the
  other conversions of `0F E6`/`0F 5B`.

- 2026-10-21, step 4 (`sse2-int`, one commit over `sse2-double`): integer SSE2 on XMM registers
  (the 66 prefix on the MMX opcodes): `MOVDQA/MOVDQU/MOVD/MOVQ/MOVNTDQ`, `PSHUFD/PSHUFLW/PSHUFHW`,
  `PUNPCK[LH]BW/WD/DQ/QDQ`, `PACKSSWB/PACKUSWB/PACKSSDW`, `PADD/PSUB B/W/D/Q`, saturating `PADDS/
  PADDUS/PSUBS/PSUBUS B/W`, `PMULLW/PMULHW/PMADDWD/PMULUDQ`, `PAND/PANDN/POR/PXOR`, `PCMPEQ/PCMPGT
  B/W/D`, shifts by xmm or imm8 and `PSLLDQ/PSRLDQ`. Lane-wise functions in `support.h`
  (`SSE2_PINT`), shared by register and memory forms. Run
  https://github.com/unxed/sandbox/actions/runs/39626974121 (`-f sse2=true -f sse2double=true
  -f sse2int=true`): `sse2int.asm` 190 of 190 (expected values from an independent Python model,
  `gen_sse2int.py`), `sse2.asm` 58 of 58, `ud.asm` 34 of 34.

- 2026-10-21, step 5 (`sse2-rest`, one commit over `sse2-int`): the rest of the instruction set:
  `CVTDQ2PS/CVTPS2DQ/CVTTPS2DQ` (`0F 5B`), `CVTDQ2PD/CVTPD2DQ/CVTTPD2DQ` (`0F E6`), `CVTPI2PD`,
  `CVTPD2PI`, `CVTTPD2PI`, `MASKMOVDQU`, `MOVQ2DQ`, `MOVDQ2Q`, `MOVNTI`, and `PADDQ/PSUBQ/PMULUDQ` on
  MMX registers. Run https://github.com/unxed/sandbox/actions/runs/39627770080: `sse2int.asm` 225 of
  225, `sse2.asm` 58 of 58, `ud.asm` 34 of 34 (x86-64 build, core `normal`). Not done: MXCSR
  exception flags and #XM (the host floating point is used, as for the old SSE), `cputype`
  (see below).
- `cputype`: left out on purpose. A new CPU identity (Pentium 4 is family 15, Pentium M family 6
  model 9) changes what operating systems and programs do with CPUID, which is the maintainer's
  decision; `[cpu] enable sse2` works with the existing `pentium_iii` and `experimental`.
- `dynamic_x86` (branch `dynx86-strict-prefix`, one commit over `master`; `test-dynx86` is it over
  `mmx-strict-prefix`): the decoder of `core_dyn_x86` compiles the MMX opcodes without looking at the
  66/F2/F3 prefix; the change sends such an opcode to the normal core. **Not verified**: a 32-bit
  build (`-f m32=true`, `config.h` has `C_DYNAMIC_X86`) with `core=dynamic` gives the same result
  with and without the change, on `pentium_iii` and on `pentium_mmx` (runs 39630884289,
  39632005227, 39632035102): the "MMX with a prefix" rows already pass with only the normal-core
  fix, so the test does not show that the dynamic core compiles these opcodes. Do not send it
  upstream until a run shows the difference.

## Next steps (each is a separate upstream PR, tests first)

3. (done, see above) Scalar and packed double and the moves (enough for Far 3 and sqlite3): `MOVLPD/MOVHPD`
   (`66 0F 12/13/16/17`), `MOVSD` (`F2 0F 10/11`), `MOVAPD/MOVUPD`, `AND/ANDN/OR/XORPD`,
   `ADD/SUB/MUL/DIV/SQRT/MIN/MAX SD+PD`, `COMISD/UCOMISD`, `CMPSD/CMPPD`, `CVTSI2SD`,
   `CVTTSD2SI`, `CVTSD2SI`, `CVTSS2SD/CVTSD2SS`, `CVTPS2PD/CVTPD2PS`. Use the existing `f64[2]`
   of `XMM_Reg`; MIN/MAX/CMP with the NaN and +-0 rules of the SDM; "integer indefinite"
   (0x80000000) in `CVTT*`. Each form gets a result-checking row in the guest test.
4. (done, see above) Integer XMM: `MOVD/MOVQ xmm`, `MOVDQA/MOVDQU/MOVNTDQ/MOVNTI`, `PXOR/PAND/POR/PANDN`,
   `PUNPCK*`, `PSHUFD/HW/LW`, `PADDQ/PSUBQ`, `PSLLQ/PSRLQ/PSLLDQ/PSRLDQ`, `PCMPEQ*`, `PADD/PSUB`.
   First move the MMX operations of `prefix_0f_mmx.h` into functions on `uint64_t` so that the
   XMM forms can apply them to both halves.
5. (done, see above) The rest of SSE2. Left: the debugger disassembler, MXCSR flags and #XM, `cputype`.
6. `dynamic_x86` (32-bit hosts, unverified, see above): the same prefix guard
   (`decode.rep != REP_NONE || decode.big_op != cpu.code.big` before `dyn_mmx_*`), prepared in
   the `go2dos` notes, untested here.
