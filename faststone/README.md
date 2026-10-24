# FastStone / Wine validation workbench

Work in progress. This checkpoint is **not a verified Wine fix or a release**.

**Start with [HANDOFF.md](HANDOFF.md).** It contains the complete user request,
current measured blockers, pinned downloads, clean-room recovery instructions,
saved artifact identity, next actions and acceptance criteria. It supersedes
older contradictory status statements below and in historical notes.

Primary application: FastStone Image Viewer 5.6. Additional target: current 8.5;
7.5 is included in the validation plan for Wine bug 48872. Video is optional.
Wine baseline: `840a939ee526137639665ff5f587224d6a36403f` (11.20),
https://github.com/unxed/wine.

The workbench contains public Win32 API regression probes, parallel GUI test
orchestration and an XTEST bridge for the actual X11 input path. E2E scope
includes all four fullscreen edge panels, tools opened by clicking the left
panel, nested dialogs, foreground/focus, visible stacking, actual input and
return to the parent/fullscreen image. Read [the test matrix](docs/test-matrix.md)
for implemented checks and remaining coverage; a written scenario is not a pass.

`patch-candidates/` contains unverified candidates for the coordinate and empty
label issues. Do not submit them as confirmed fixes. The original label MR
10093 has a painting regression concern; the original coordinate proposal can
break internal selection/navigation. These are documented in `notes/`.

[Portable bundle documentation](docs/bundle.md) explains the one-file bootstrap,
bundled Wine and runtime, immutable payload checks and relocation. The tests in
`notes/packaging-synthetic-tests.txt` used a substitute executable for Wine;
they validate packaging only. A full Wine bundle and its GUI verification are
still outstanding.

## Reproducing the workspace

Place a Wine source checkout in `WORKSPACE/wine` and this repository in
`WORKSPACE/sandbox`. Run `faststone/build-wine.sh` from this repository for the
recorded image-viewer configuration. It builds a new WoW64 Wine supporting
32-bit Windows applications without 32-bit Linux libraries. No application
binary is modified.

The host execution environment denies local Unix sockets, so the test workbench
uses a disposable QEMU TCG guest with Xvfb/Openbox. `vm/prepare.py`, `vm/init.sh`,
`vm/worker.sh` and `vm/run.sh` are the current infrastructure. The guest has no
network and shares only the selected workspace over virtio-9p. It uses Ubuntu
kernel 6.8.0-138-generic. Use CPU `qemu64`; `max` exposed an emulator/kernel
failure during Wine startup. The `vm-queue-live` directory holds atomic shell
job requests and their response/exit/done files. Each test needs its own Wine
prefix and X display. Limit concurrent jobs to guest CPU/memory capacity.

FastStone downloads must be from the pinned web.archive.org captures in
`bundle/launch.sh`; never fetch directly from 2g0.ru. Keep the application
archives and Microsoft cc580 reference DLL outside git. The bundle downloads
FastStone on first use rather than redistributing it. Native reference tests
must verify the loaded DLL and registered ListView class; a prior attempted
reference accidentally used Wine's builtin library and is not evidence.

The scratch environment was lost once; older incomplete run logs are gone.
Current passing packaging tests and pending GUI verification are distinguished
explicitly in the notes. No credentials are stored in this workbench.
