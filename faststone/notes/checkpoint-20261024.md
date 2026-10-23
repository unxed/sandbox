# Interrupted checkpoint — 2026-10-24

User requested an immediate interruption and git-am export. This checkpoint includes all workbench sources and UNVERIFIED fix candidates; it is not a finished Wine fix.

Authoritative workbench is faststone/ in this repository (unxed/sandbox base45c9a2d34e0123b6de52616eb7f8f1534911605e). Wine source base840a939ee526137639665ff5f587224d6a36403f was cloned clean, not modified. Full Wine compilation was interrupted by request before completion.

New work: verified FastStone5.6/7.5/8.5 archives downloaded from Wayback; GUI/probe executables compiled, native comctl32 5.80 extracted and hash checked; isolated GUI runner uses workspace-backed private prefixes and Openbox; initial parallel4-job plan covers5.6/8.5 edges and actual left-panel crop/draw. Native API runners validate DLL/class identity and save comparison records. No end-to-end GUI pass or API comparison has completed in this restored environment.

Offline QEMU guest reached GUEST_WORKER_READY. Prebuilt Kron4ek vanilla11.20 archive SHA256482a493c755dcea776199b86560e0fb0f969bb0275c67d88120b0b35b0df34b9; direct wineboot -i failed139 before creating a prefix. Debug log reports host addr space limit0xffffffffffff0000. The release itself warns of startup segfaults. Hypothesis: old build headers use anon_mmap_tryfixed fallback whose EEXIST result is misread by the new address-space probe. This is not yet a verified cause/fix. A temporary48-bit-QEMU-only LD_PRELOAD diagnostic shim is preserved in vm/diagnostic-address-probe-shim.c. It was not integrated into the launcher and must not be distributed as a general fix. Shim bootstrap had not produced a final result when interrupted. Wine11.19 prebuilt was downloaded as a control, not tested.

Portable bootstrap/runtime changes are work in progress. Existing synthetic bundle smoke results are not real FastStone verification. No patched portable executable is ready. No GitHub push was completed. Credentials and proprietary application binaries are excluded from the patch.

Resume with completed source build and a valid golden prefix, then run actual baseline/native/patched comparisons and GUI tests. Keep any diagnostic preload explicitly labelled in results. VM init references /work/patch-export/faststone; adapt this if checkout directory changes. Original historical notes remain for continuity and are superseded by this status where contradictory.
