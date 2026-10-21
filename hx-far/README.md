# hx-far: Far Manager under HX DOS Extender

Goal (go2dos, `docs/UTF8-DOS.md`): the Unicode Far Manager (2.x/3.x) running under HX in DOSBox-X,
with UTF-8 long file names and the host clipboard.

`imports.py` lists what Far imports (far.exe and every plugin DLL, ordinary and delay imports)
that the HX Win32 emulation does not export: DLLs are mapped as DPMILD32 maps them
(`kernel32` -> `DKRNL32`, `user32` -> `DUSER32`, `gdi32` -> `DGDI32`, `advapi32` -> `DADVAPI`,
`ntdll` -> `DKRNL32`), exports are read from `SrcEmu/*/*.DEF` of HX. A function that HX exports
may still be a stub; this report only finds the hard blockers (the loader refuses a module whose
import is missing).

Run: `gh workflow run hx-far.yml -R unxed/sandbox [-f far=<URL of a Far x86 .7z>]`; the report is
in the job summary and in the artifact `hx-far-report`.

## Stand: Far under HX in DOSBox-X (`hx-far-run.yml`)

Ubuntu runner, Xvfb, DOSBox-X from apt (2024.03.01: LFN yes, the `DOS-UTF8` providers no), the HX
runtime of a release (`HXRT*.zip`, `HXGUI*.zip`, all `BIN` files in `C:\HX`), Far x86 in `C:\FAR`.
The system DLLs that HX does not have are replaced by empty stand-ins (`stub.c`, built with mingw),
and `DPMILDR=128` lets the loader start Far with unresolved imports; a call of such a function
stops it with "unresolved import called". `RUN.BAT` starts `HDPMI32 -r`, then `far.exe -?` (output
to `C:\OUT\HELP.TXT`), then `far.exe <args>` (default `-p`: no plugins). `run.sh` takes
screenshots of the X screen by a timetable; screenshots, `C:\OUT` and the DOSBox-X log are the
artifact `hx-far-run`.

Run: `gh workflow run hx-far-run.yml -R unxed/sandbox [-f args=... -f stubs=... -f dpmildr=...]`.

`-f hxbuild=<run id of hx-build.yml>` puts the DLLs built from a branch of `unxed/HX` (for example
`far-stand`) over those of the release. `hx-build.yml` builds `SrcEmu` directories with nmake,
JWasm 2.20 and JWlink 2.0 on `windows-latest`.

Findings so far (2026-10-21):
- Far 3.0.6745.5025 x86 loads with the stand-in DLLs, then stops in `sqlite3.dll` on SSE2
  (`66 0F 13`, MOVLPD; illegal instruction C000001D). DOSBox-X has no SSE2 (`cputype` up to
  `pentium_iii`, which has SSE only).
- Far 2.0 build 1807 x86 needs no SSE2; it stops on the first missing function, `GetProcessHeaps`
  (found with `where.py`). Branch `far-stand` of `unxed/HX` adds the DKRNL32 functions Far 2 imports.

**2026-10-21: Far 2.0 build 1807 x86 shows its panels under HX v2.23 in DOSBox-X**
(`far2-panels-2026-10-21.png`, run https://github.com/unxed/sandbox/actions/runs/39618234287).
DLLs from branch `far-stand` of `unxed/HX` (c2449c0): missing DKRNL32/DUSER32 functions,
the `\\?\` path prefix stripped in W functions, directory handles + `NtQueryDirectoryFile`
(Far lists directories only this way), `GetModuleHandle("ntdll")`. The stray "00000000 00000003"
at the bottom right comes with the debug DKRNL32.

**2026-10-21, later:** with `far-stand` f7728bb (release DLLs) Far 2 goes into a folder (Down, Enter),
back up (Ctrl+PgUp, `far2-ctrl-pgup-2026-10-21.png`), asks on F10 (`far2-quit-2026-10-21.png`) and
exits on Enter (run https://github.com/unxed/sandbox/actions/runs/39620132182). The fix that made
this work: DKRNL32 kept the 1 MB stack of every terminated thread until its handle was closed, and
Far 2 restarts a short thread (`WindowHandler::Check`) without closing the handles, so memory ran
out ("Access denied", empty panel). Now the dispatcher frees the stack when the thread ends.

**2026-10-21: Far 3.0.6745.5025 x86 on DOSBox-X with SSE2.** DOSBox-X from branch `sse2-rest` of
`unxed/dosbox-x` (`-f dosbox_run=<dosbox-x-test run> -f sse2=true`), HX DLLs from `far-stand`
(`f7728bb`), stand-in DLLs, `DPMILDR=128`:
- DOSBox-X from apt (no SSE2): Far stops in `sqlite3.dll` at `66 0F 13` (MOVLPD), "exception
  C000001D" (`far3-no-sse2-2026-10-21.png`, run https://github.com/unxed/sandbox/actions/runs/39633729020);
- DOSBox-X with SSE2 (run https://github.com/unxed/sandbox/actions/runs/39633326778): that instruction
  runs; Far stops later, at "exception C0000005 ... 7000982E", after the loader reports missing
  `api-ms-win-core-synch-l1-2-0`, `api-ms-win-core-fibers-l1-1-1/2`, `api-ms-win-core-localization-l1-2-1`
  and `kernelbase` (`far3-with-sse2-2026-10-21.png`). That is a gap in the Win32 emulation of HX, not in the
  CPU; next in the plan for Far 3 (go2dos `docs/UTF8-DOS.md`, section 7, H3).
