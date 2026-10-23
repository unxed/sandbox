# FastStone GUI tests: scope and execution evidence

The test sources were reconstructed after the execution environment was reset.
Old logs and screenshots were lost. **No runtime pass is claimed here.** Build
success is separate from application test success. Only the current run's
`summary.json`, per-job `result.json`, `artifacts/assertions.jsonl` and BMP
screenshots are evidence of execution.

Expected interactions were read from **Viewing Images / Mouse & Keyboard Use**
in the CHM help shipped with FastStone 5.6 and 8.5 before the reset. Both describe
the top thumbnail browser, left file/edit tools, right properties/EXIF panel,
bottom control bar, and bottom-right Windows Taskbar corner. The help also
documents wheel-over-bottom-toolbar zoom, Ctrl+wheel, Shift+mouse zoom,
hold-LMB magnifier/pan, Ctrl+drag select-and-zoom, editing shortcuts and undo.

## Priority: real click / nested-window E2E

`gui-suite.c --plan observed.tsv` executes actual mouse input. It never replaces
a failed click with a keyboard shortcut. Plans must be grounded in control
labels or coordinates observed on the corresponding application's screenshots
and window tree. An unknown label or failed expectation stops that plan at
the first failing step and retains an `e2e-first-failure.bmp` screenshot.

The first priority plans are:

| Application | Real interaction chain | Required observations |
| --- | --- | --- |
| 5.6 | Fullscreen → left edge → click Draw Board → click text tool → text/font/color subdialog → close → Draw Board → close → fullscreen | Dialog visibility, foreground, application thread active/focus window, Z-order above parent and fullscreen; text input reaches an actual clicked Edit; closing restores the expected parent. |
| 8.5 | The same Draw Board chain, using this version's actual controls | The same assertions; do not assume 5.6 coordinates or window captions apply. |
| Both | Left edge → crop/resize tool → nested size/options/save dialog → cancel → tool → fullscreen | Parent stack and focus restoration at each nesting level; no tool is hidden beneath the fullscreen image. |

The source implements those assertions and plan operations. **Concrete plans
still require fresh application observations and execution.** A plan template
or compiled driver is not a passed E2E test.

Wine bug **#41438** is a specific regression target: Enter fullscreen, press X
and observe whether the crop window is hidden behind the fullscreen image.
The original report reproduced this in Wine1.6.2/1.8/1.9.20, with a later
confirmation on3.7. Its January2026 comments say it no longer reproduced with
Wine11 and FastStone5.6. The `crop` shortcut scenario reproduces the reported
trigger and now asserts foreground/input/Z-order; the left-edge click E2E adds
the interaction path requested here. Neither historical resolution nor a
shortcut-only pass establishes nested-dialog coverage in8.5.

Plans are tab-separated, one operation per line:

| Operation | Arguments | Meaning |
| --- | --- | --- |
| `edge` | `left`, `right`, `top`, `bottom` | Move to the real screen edge. |
| `click-text` | observed control caption | Find a visible application-owned control and click its rectangle. Fail if absent. |
| `click-at` | observed x, y | Click coordinates derived from a current screenshot; valid only for its recorded resolution/version. |
| `expect` | observed dialog-title substring | Wait for the window; push it onto the expected parent stack and check visibility, foreground, active/focus and Z-order. |
| `edit` | lowercase ASCII marker | Click a visible Edit in the current dialog, verify focus, type the marker and verify its actual text. |
| `close` | none | Press Escape, verify that the current dialog is closed/hidden and that its expected parent regains foreground/input focus. |
| `return` | none | After an actual click on OK/Cancel, wait for the nested window to close, pop its parent stack and assert parent input focus/Z-order. It sends no extra input. |
| `active` | none | Assert foreground, active/focus and Z-order for the current expected dialog. |
| `remember` | unique baseline name | Save the current logical window's rendering for comparison after nested dialogs have closed. |
| `changed` | matching baseline name | Require a return to that same logical window and changed interior pixels after accepting an operation. Complement with an output-content oracle when pixels alone are insufficient. |
| `capture` | artifact name | Capture pixels and visible application window tree. |

The trace records `GetWindow(GW_OWNER)` chains. Delphi can own modal dialogs
through a hidden application window, so direct owner equality is not imposed
as an unsupported assumption. Foreground and visible Z-order relative to the
expected logical parent are asserted independently.

## Input routes and isolation

The default Python runner uses `--input-source x11` and the native
`gui-suite-x11-bridge.c` XTEST helper. The driver requests real X11 key/button
events over stdin/stdout; the helper injects them into that job's private
display. This exercises Wine's X11 input route, including raw button handling.
`--input-source win32` uses SendInput directly and is useful for separating an
application/control failure from an X11-driver failure. A SendInput-only pass
cannot rule out Wine bug #60301's duplicated raw button events.

Every job gets a separate Xvfb, Wine prefix, application copy, image copy and
results directory. `--jobs` bounds concurrency. Jobs therefore cannot fight
for the pointer, share a FastStone mutex or overwrite each other's settings.
All input must target the disposable test display, never the user's desktop.

## Existing independent scenarios

| Scenario | Assertions | Limits |
| --- | --- | --- |
| `edges` | All four panels visibly appear and hide; fullscreen remains active. | Pixel/window-tree evidence is not proof that every panel command works. |
| `top` | At least164 thumbnails; wheel increases horizontal scroll; fixture-colored thumbnails remain painted after three screen widths; clicking an item selected from real ListView bounds selects that item. | Pixel coverage oracle assumes the supplied deliberately colorful fixtures. |
| `navigation` | Next/previous/first/last shortcuts change displayed pixels and retain fullscreen. | Exact filename semantics need additional checks. |
| `zoom` | Actual-size/best-fit, Ctrl+wheel and bottom-toolbar wheel change image rendering. | Selected-image identity is checked when the version exposes a ListView; otherwise explicitly skipped. |
| `pan-select` | Drag pans an oversized image; Ctrl+drag selects/zooms; image identity is preserved when observable. | Primary fixture is1800×1200 for the default1280×800 display. |
| `shift-zoom` | Shift+LMB/RMB zoom in/out and retain image/fullscreen. | Requires the documented mouse configuration. |
| `magnifier` | Holding LMB changes rendering and retains fullscreen. | Captures held/released states. |
| `right-hold` | Holding RMB must not prematurely exit fullscreen and should magnify under the chosen bindings. | Use X11 input to investigate #60301; native/reference behavior must be established. |
| `transforms` | Rotate/flip alter rendering; undo restores original pixels and redo restores edited pixels. | In-memory edits; saved file pixels not yet checked. |
| `crop`, `resize`, `draw`, `copy`, `move`, `slideshow`, `comment`, `histogram`, `save-as`, `settings`, `properties` | Shortcut opens the expected dialog; focus/Z-order is correct; cancelling restores its parent. | These are explicitly shortcut smoke tests. They do **not** satisfy the left-edge-click/nested-tool E2E requirement. |

Still required beyond those scenarios: actual crop/resize/draw save/reopen
results; file operation results; all toolbar modes and selection shapes;
semantic EXIF/histogram contents; image format decode correctness, Unicode,
HiDPI, multiple monitors, Wayland, and host integration. The lower-right
Taskbar corner is skipped on shell-less Xvfb. Videos/audio are outside the
requested viewing scope; unsupported media must not hang or crash browsing.
Shutdown correctness is separate: disposable test processes are terminated
after results to prevent save prompts from blocking the worker.

## Build and run

```sh
i686-w64-mingw32-gcc -std=c99 -O2 -Wall -Wextra -Werror \
  gui-suite.c -o gui-suite.exe -luser32 -lgdi32
cc -std=c99 -O2 -Wall -Wextra -Werror gui-suite-x11-bridge.c \
  -o gui-suite-x11-bridge -lX11 -ldl
python3 gui-suite.py --fixtures-only /absolute/path/fixtures
```

Pillow is required only to generate the164 JPEG/EXIF fixtures and the separate
PNG/BMP/TIFF/WebP/Unicode samples. The runner itself uses Python's standard
library. Minimal guests can run the native bridge and PE driver directly.

```sh
python3 gui-suite.py --wine /absolute/path/wine \
  --wineserver /absolute/path/wineserver \
  --driver /absolute/path/gui-suite.exe \
  --bridge /absolute/path/gui-suite-x11-bridge \
  --version 5.6=/absolute/path/FastStone56/FSViewer.exe \
  --version 8.5=/absolute/path/FastStone85/FSViewer.exe \
  --fixtures /absolute/path/fixtures --results /absolute/path/results \
  --scenario edges --scenario top \
  --plan 5.6:draw-nested=/absolute/path/observed-56.tsv \
  --plan 8.5:draw-nested=/absolute/path/observed-85.tsv \
  --jobs 4 --input-source x11
```

Use unused result paths; job directories are never silently overwritten.
Increase `--timeout` for TCG and reduce concurrency if guest memory pressure
causes infrastructure failures. A missing summary, timeout or launch error
cannot count as a pass.

Version-qualified plans prevent an observed 5.6 coordinate map from being
silently replayed against 8.5. A plan without a version applies to all selected
versions and should therefore use labels known to be shared. The exact plan is
copied into its job directory and its SHA-256 is recorded in `result.json`.
