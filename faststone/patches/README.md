# Wine patches and ticket paragraphs (state 28-10-2026)

`wine-840a939-listview-0001-0003.patch` is a `git am` series (three commits) for
`dlls/comctl32/listview.c` on unxed/wine `840a939ee526137639665ff5f587224d6a36403f`
(Wine 11.20). Apply with `git -C wine switch -c faststone-listview 840a939... && git -C wine am wine-840a939-listview-0001-0003.patch`.
The author is the repository owner; no `Signed-off-by` is present and must be added by the person who submits
upstream. Nothing was sent to Wine or WineHQ. No Wine test-suite change is included and the upstream
`dlls/comctl32/tests/listview.c` was not run against these commits.

Evidence: CI run 40669702797 (unxed/sandbox#7), public-API probes `faststone/listview-regression.c`, identical
checks for Wine builtin 32 and 64 bit and for the Microsoft comctl32 5.80 loaded inside Wine (a control-library
reference, not a Windows desktop). Wine 11.20 builtin: 68 checks, 5 failures; all three commits together:
68 checks, 0 failures in both bit widths; each commit alone removes only its own failures and adds none.

## One paragraph per ticket

**5129.** Not reproduced or re-verified here. The January 2026 comment says the main window scrolling no longer
reproduced with Wine 11 and FastStone 5.6 and moved the fullscreen problems to 59251. FastStone fullscreen
scenarios have not passed yet in this workbench, so no new claim is made.

**59251.** The horizontal-wheel part is reproduced on the public API and fixed by commit 0002: the wheel in icon and
small-icon views always scrolled vertically, so a view with only a horizontal scroll bar ignored it; it now follows
the available axis, with vertical priority when both bars exist (checks fail before, pass after, native passes).
The other reported symptom, thumbnails disappearing after the scroll bar moves past the screen width, was not
examined and remains open.

**59609.** Reproduced on the public API and fixed by commit 0001: after scrolling, LVM_GETITEMPOSITION returned
client coordinates for icon and small-icon views, so the item position moved with the scroll origin; native keeps
view coordinates. The change is only at the public message boundary so internal selection and navigation, which
need client coordinates, are untouched. A related small-icon defect, Shift+Right selecting one item too many
(item bounds wider than the grid step), is fixed separately by commit 0003.

**48872.** The mechanism is reproduced on the public API but not fixed. For icon items with an empty label
(32 of 32 cases) Wine returns a zero-width label rectangle and a hit test of the label centre finds nothing;
native 5.80 returns a non-empty rectangle and finds the item (0 of 32 failures). The proposed "empty string becomes
a space" idea (`patch-candidates/label-listview-840a939.patch`) removes the zero width in 28 of 32 cases but not the
hit-test failure, so it is insufficient and is not part of the series. Painting, focus and selection geometry were
not measured, FastStone 7.5 was not run, and Wine's own item bounds being smaller than its label rectangle without
an image list is a second unresolved difference.

**41438.** Not reproduced here. The fullscreen-to-Crop path needs the left edge panel, which does not open in the
current FastStone runs (the application receives the pointer motion, the cause is unknown), so the regression
was not exercised.

**60301.** Not examined. It needs a real X11 press-and-hold of the right button with a screenshot while held;
the XTEST bridge exists, but no FastStone scenario has reached that step.
