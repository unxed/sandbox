# FastStone / Wine work in progress — 2026-10-23

This is a recovery checkpoint, NOT a completed fix or a tested release.

## User scope and constraints
- Wine fork https://github.com/unxed/wine, base 840a939ee526137639665ff5f587224d6a36403f (11.20).
- Fix and actually verify FastStone bugs5129,59251,48872; related59609 and60301 matter.
- FastStone5.6 is primary; latest confirmed official8.5 is a separate supported target;7.5 needed to check48872.
- Download FastStone ONLY from web.archive.org; NEVER direct2g0.ru. Archive links are in bundle/launch.sh.
- Deliver git-am patch archive, one paragraph per ticket explaining verified cause/fix, one-file portable Wine+FastStone launcher. GitHub token invalid, plugin unavailable, user explicitly accepts patches instead of push. Do not include credentials.
- Do not modify FSViewer.exe. License permits personal/educational copies, prohibits modifying program; bundle first-run downloader chosen to avoid public redistribution uncertainty.
- Video not required; graceful degradation allowed. Image viewer must remain usable.
- All fullscreen edges must be tested against docs, including top thumbnails, left operations, right EXIF/properties, bottom controls and corner Windows taskbar as applicable.
- E2E focus and z-order: left edge -> draw/crop/resize/etc -> nested dialog -> return; confirm visible foreground and actual input, not only hotkey smoke.
- Parallelize independent GUI tests with isolated prefixes/displays. User explicitly authorized agents for parallel work.

## Environment caveats
- Scratch was reset between turns; all original files and incomplete logs lost. Sources are being reconstructed by agents. Historical claims are not durable test evidence.
- Host AF_UNIX socket() denied, so native Wine fails wineserver. Escalation explicitly denied by environment approval policy. Do not request again.
- Successful safer test approach: QEMU TCG Linux guest (no network, virtio9p mount only selected workspace). Ubuntu kernel6.8.0-138-generic + static busybox initramfs + Xvfb + host dynamic libs/fonts. Guest /work maps workspace. Guest socket creation works.
- Use CPU qemu64: cpu=max caused QEMU8.2 SMEP/IRET kernel oops when Wine booted. qemu64 ran Win32 tests.
- Initial prior VM had RpcSs delays/missing DLLs; prefix bootstrap became usable after building coml2/userenv/wow64{,cpu,win},rpcss,actxprxy,atl,boot drivers and bringing guest loopback up. Copy all actual Wine .so dependencies AFTER build, not only config SONAME. Create writable fontconfig caches.
- Queue worker: host atomically writes vm-queue-live/NAME.request; guest executes sh concurrently to NAME.response, then NAME.exit and NAME.done. Give every test its own DISPLAY and WINEPREFIX. Ensure bounded concurrency (guest4CPU).
- Do not use stale STOP file after reboot; use per-run queue directory/control.

## Diagnostic findings (need re-verification)
-5129 main-window scrolling no longer reproduced in Wine11 by reporter; residual fullscreen bug tracked59251.
-59251 combines missing horizontal wheel scrolling and thumbnails vanishing after horizontal scrollbar displacement.
-59609 proposed changing LISTVIEW_GetItemPosition globally is too broad: internal Shift-selection/navigation expect client coordinates. Candidate changes only public LVM_GETITEMPOSITION.
-48872 MR10093 by Maotong Zhang remains open; Sivov says substituting space in all internal metrics paints spurious empty-label selection. Need distinguish externally queried geometry from internal painting; no blind cherry-pick.
-Prior 'native' probe printed5.81.4704 and matched builtin => native reference was NOT established. Need verify loaded DLL actual path/hash before comparing.
-Prior SetItemPosition32 fixture did not arrange icons correctly. New regression source uses legacy message with explicit position checks. Do not trust old horizontal wheel measurements.
-60301 is X11 physical/raw duplicate mouse button regression startingWine11.17. SendInput-only Win32 tests bypass physical X11 path, so use XTEST bridge to reproduce held-right-button bug.

## Current agent ownership
-listview_regressions: standalone API test + candidate coordinate/wheel patch. No edits toWine source until reviewed and measured.
-label_regression: label API/paint tests and candidate48872 fix, MR discussion.
-gui_autotests: documented edge, navigation, image actions and focus/subdialog E2E tests; XTEST bridge.
-portable_bundle: static bootstrap ELF with payload, bundled glibc loader, PT_INTERP relocation, download/extraction launch scripts, synthetic bundle tests. No full Wine artifact yet.
-root: tooling, Wine build, QEMU infrastructure, actual patch integration and verification, final artifacts.
