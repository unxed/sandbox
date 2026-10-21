# hx-utf8: UTF-8 in the Win32 emulation of HX DOS Extender

Checks for the change proposed in https://github.com/Baron-von-Riedesel/HX/issues/75
(branch `dkrnl32-cp-utf8` of https://github.com/unxed/HX): `MultiByteToWideChar`,
`WideCharToMultiByte` and `GetCPInfo` of DKRNL32 with `CP_UTF8`.

`test.c` is a differential test: `WC2MB.ASM` and `GETCPINF.ASM` are assembled by JWasm 2.20
with the flags of `SrcEmu/DKRNL32/MAKEFILE` (release and `_DEBUG`), linked into a Win32 test
program, and every case is run through them and through kernel32 of the Windows runner; result,
output and last error must match. Cases: valid UTF-8 and UTF-16 (all length boundaries,
surrogate pairs, embedded 0), ill-formed input (overlong, surrogates, > U+10FFFF, truncated,
stray continuation bytes, unpaired surrogates) with and without `MB_ERR_INVALID_CHARS` /
`WC_ERR_INVALID_CHARS`, length -1, size queries and too small buffers. Other code pages are
checked to keep their old behaviour (bytes 1:1 to 0000h-00FFh). The same test is run against
upstream `master` as a baseline (failures there are expected).

Run: `gh workflow run hx-utf8.yml -R unxed/sandbox [-f repo=unxed/HX -f ref=<branch>]`.
Only in CI (GitHub Actions, `windows-latest`), nothing is built locally.
