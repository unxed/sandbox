# Prebuilt runtime investigation — interrupted work

This is a recovery note, not a statement that FastStone or the proposed fixes
passed GUI tests. Work was stopped at the user's request.

## Retrieved control runtimes

Publisher: Kron4ek/Wine-Builds, vanilla `amd64-wow64` assets. Primary release
metadata, asset digests and actual downloaded SHA-256 values agreed.

| Version | Archive size | SHA-256 |
| --- | ---: | --- |
| 11.20 | 100,025,976 | `482a493c755dcea776199b86560e0fb0f969bb0275c67d88120b0b35b0df34b9` |
| 11.19 | 99,272,636 | `a1fe858b45d12c9b16b91c7601d9b934f68430f7b6b95e240212ab6e2a198d8a` |

Download URLs:

- https://github.com/Kron4ek/Wine-Builds/releases/download/11.20/wine-11.20-amd64-wow64.tar.xz
- https://github.com/Kron4ek/Wine-Builds/releases/download/11.19/wine-11.19-amd64-wow64.tar.xz

Extracted prefixes were `prebuilt/wine-11.20-amd64-wow64` and
`prebuilt/wine-11.19-amd64-wow64`. Both `wine --version` commands returned the
expected version and exit status zero. This does not exercise wineserver or GUI
initialization. The root agent actually observed immediate exit 139 during
11.20 `wineboot -i` in the disposable guest. Its empty prefix was not a pass.
The 11.19 runtime was prepared as a control; this note records no GUI result.

The publisher's 11.20 release explicitly warns about startup segmentation faults
on some systems. Its build-recipe commit is
`8bcb6d16ee58ea012034ae84018bce56ad9637a5`. The recipe downloads official WineHQ
release sources for vanilla, builds in Ubuntu Bionic chroots and uses
`-march=x86-64 -msse3 -mfpmath=sse -O3`. README requires glibc 2.27 or newer;
our scan of 41 Unix ELF objects found a highest explicit GLIBC symbol requirement
of 2.25. The runtime has i386/x86_64 PE DLLs and only x86_64 Unix modules.

A possible explanation of the startup crash was identified by the root agent:
Wine's address-space probe can misinterpret the fallback path when compiled
without `MAP_FIXED_NOREPLACE`. Bionic build headers make that plausible. Binary
confirmation and a verified workaround were not completed before interruption.
Do not describe this hypothesis as a tested fix.

## Dependency inspection

`bundle/inspect_prebuilt.py` needs no original config.h. It emits linked external
ELF paths, embedded SONAME hints, a conservative X11/font/crypto image profile,
and separate missing optional modules. A generated header can replace config.h
for the VM preparation script's SONAME scan. Embedded strings are hints, not
proof that a code path is used.

The core image profile resolved on the current host. Missing optional providers
in the initial scan were packet capture, CAPI, SANE, gphoto2, GStreamer, old
FFmpeg (`libavutil.so.56`, `libavformat.so.58`, `libavcodec.so.58`) and the native
Wayland keyboard registry. Disabling GStreamer/winedmo and selecting X11 is a
candidate for image-only tests, not evidence of verified graceful degradation.

## Packaging v2 status

The workbench now has a proposed relative `DT_RPATH` on each dynamic ELF object,
using `--force-rpath`; the glibc loader itself is excluded. PT_INTERP relocation
remains in the static bootstrap. Global `LD_LIBRARY_PATH` and `GCONV_PATH`
injection is removed so native host children do not inherit bundled code paths.
The collector supports explicit optional Unix-module omissions and records
third-party provenance. Development `.a` archives are excluded from runtime
copies. These changes passed C compilation and Python syntax checks only.
They have not yet produced or passed tests of a new real Wine bundle.

Earlier environments had successfully built an unfixed source-Wine baseline
`.run` of 190,973,508 bytes, SHA-256
`fbbcddb73ae46c45665c6ba0f1fb366c72e8b40c74f838a42218cc6253d74515`, with seven
packaging test groups passing. That binary was lost when the environment reset;
it is not the current deliverable, and its results do not validate packaging v2
or any FastStone bug fix. A recreated real baseline must be saved durably before
further long-running tests.
