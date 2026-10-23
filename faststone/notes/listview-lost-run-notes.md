# Lost first-environment measurements — recollection only

The first workspace and QEMU guest disappeared. No raw logs, executable hashes,
or VM images from those runs survived. These notes are leads to repeat, not
reproducible evidence or a declaration that any candidate fix passed.

- Builtin Wine reported comctl32 5.81.4704. Both 32-bit and 64-bit probes ran.
- A vertical scroll of 220 changed public ICON position from [134,1214] to
  [134,994] while public origin changed [0,0] -> [0,220]. SMALLICON similarly
  changed [0,289] -> [0,69]. This is consistent with #59609.
- Directional GetNextItem results were unchanged by that scroll. Shift+Right
  selected the anchor and the right neighbor and focused the neighbor.
- The fixture did NOT establish its intended manual grid. It used
  LVM_SETITEMPOSITION32 without checking it and retained a default layout.
  Therefore its supposed horizontal-wheel and both-scrollbar tests were invalid.
  Source inspection after recovery found that Wine's initial LISTVIEW_Paint
  arranges items when bNoItemMetrics is set, even without LVS_AUTOARRANGE. That
  first paint happened after manual placement. The restored fixture finishes
  initial paint first, places items, resizes once to refresh scrollbar ranges,
  then verifies relative positions. It aborts an invalid layout.
- The attempted native cc580 run reported exactly the builtin version and same
  behavior. Native class/module selection was not established. Do not call those
  results native-reference measurements. A repeat must verify the DLL path,
  DLL version and the registered ListView class module. The restored probe logs
  GCLP_HMODULE path/version for each class instance, with an optional
  --expect-comctl 5.80 assertion for the cc580 reference.
- Builtin vertical wheel used 37 pixels for both -120 and -240, and four -30
  deltas moved 148 pixels. Zero delta moved 37 pixels too. These are observations
  of the old run only; fractional behavior of native cc580 remains unknown.

The candidate changes only external LVM_GETITEMPOSITION to view coordinates.
Private LISTVIEW_GetItemPosition is also used by LISTVIEW_SetGroupSelection and
GetNextItem -> FindItemW, whose current implementation expects client coordinates.
Changing that private helper directly, as proposed in #59609, risks regressions.
The candidate had passed git apply --check in the lost environment; it was not
runtime-tested. It must be revalidated against the recovered source and guest.

Primary API documentation:
https://learn.microsoft.com/en-us/windows/win32/controls/lvm-getitemposition
https://learn.microsoft.com/en-us/windows/win32/api/commctrl/ns-commctrl-lvfindinfow
