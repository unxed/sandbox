# Recovery record — Wine MR 10093 / bug 48872

This record was reconstructed from this agent's retained tool output after the
scratch environment was reset. The original response bytes and test logs were
lost. Re-fetch and re-run before publishing verified results.

Recovery update: the public discussion endpoint was fetched again successfully
after reconstruction, with all nine non-system comments, into
`evidence/mr10093-discussions.json`. Runtime observations below still need a new
run because their original logs remain lost.

Public MR: https://gitlab.winehq.org/wine/wine/-/merge_requests/10093

Public discussion endpoint, observed working before the reset:
https://gitlab.winehq.org/wine/wine/-/merge_requests/10093/discussions.json

The API `/api/v4/projects/wine%2Fwine/merge_requests/10093/discussions?per_page=100`
returned 401, while the public UI endpoint above returned all comments.

MR author: Maotong Zhang (`xiaotong`). At the time read, the MR was open, with
head SHA `7ff7edddac0a7b10db4c7e574d9f2c2f9e70c503`. It proposed measuring an
empty item string as a space in LISTVIEW_GetItemMetrics, and a separate change
to preserve report-view empty selection width. The original `!pszText` check
inside `is_text(pszText)` is unreachable for NULL.

## Discussion reconstructed in order (paraphrased)

1. Maotong linked the filename fix and MR 10017 concerning icon borders.
2. Nikolay Sivov requested tests, as for MR 10017.
3. Maotong announced a second version adding an empty-string test.
4. Nikolay objected that the patch paints a selection rectangle for an empty
   string, unlike Windows.
5. Maotong explained that FastStone passes an empty pszText and DrawTextW
   returns zero, preventing filename rendering.
6. Nikolay observed that Windows itself renders no label for empty text, and
   had not tested FastStone.
7. Maotong explained that the added test queries LVIR_LABEL: Windows returns
   right > left, while Wine returns left == right.
8. Nikolay repeated the distinction between query bounds and the incorrect
   painted/filled label rectangle.
9. Maotong acknowledged the comment and said further analysis was needed.

Implication: do not blindly apply MR 10093. Nonempty query geometry must not
introduce a visibly filled selection rectangle for an empty label. The current
`label-candidate.patch` is a PROVISIONAL alternative confined to the external
LVIR_LABEL query; its exact width/height still requires native measurements.

## Previous runtime observation, with logs lost

A parent-initiated QEMU run of Wine 11.20 builtin comctl32, x64 probe,
`--measure-only --view icon --font default` completed 56 records with zero
sanity failures (not a regression pass). Representative retained observations:

- Empty/null/callback-empty labels: `[46,54,46,55]`, zero width, one-pixel height.
- The measured font height was 13 pixels.
- A literal space had label `[39,54,54,68]`, 15-pixel width and 14-pixel height.
- Selected space labels contained 183 highlight-colour pixels; empty labels
  contained zero.
- Before the final settle-layout change, painting could change item layout
  between rectangle recording and hit testing, making those old hit-test
  observations unsuitable as reference evidence.

No native cc580 result completed or was read by this agent before reset.
No FastStone 7.5 visual result was obtained by this agent. There is no validated
fix yet.

## Rebuild probe

```
i686-w64-mingw32-gcc -O2 -Wall -Wextra -o label-regression32.exe \
  sandbox/faststone/label-regression.c -lcomctl32 -luser32 -lgdi32
x86_64-w64-mingw32-gcc -O2 -Wall -Wextra -o label-regression64.exe \
  sandbox/faststone/label-regression.c -lcomctl32 -luser32 -lgdi32
```

Native cc580 requires the 32-bit executable, no v6 manifest, app-local native
`comctl32.dll`, `WINEDLLOVERRIDES=comctl32=n` (no fallback), and the
`--require-native-cc580` flag. The flag refuses builtin 5.81 as a reference;
stderr also records the loaded module path and version. The same executable must be
run with builtin comctl32 for comparison. Each of the four `--view` values and
two `--font` values can be independently sharded in its own display and prefix.

The reconstructed probe adds GdiFlush before reading DIB pixels, and records
`has_focus` explicitly. This version therefore needs compiling and execution
again, even though its earlier version compiled cleanly for x86 and x64.
