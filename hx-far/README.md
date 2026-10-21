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
