# Interoperability with the terminal ecosystem: OSC 52, kitty protocols, win32 input mode, far2l extensions, switchable overlay/embedded terminal, Far keys

Hi! I'm Ivan Sorokin, aka [unxed](https://github.com/unxed). I'm currently the top committer of [far2l](https://github.com/elfmz/far2l), the author of [vtui](https://github.com/unxed/vtui) and [f4](https://github.com/unxed/f4), and a contributor to [mcommander](https://github.com/blue-panels/mcommander). I'm also the author of a modern cross-platform Unicode version of DOS Navigator on top of FreePascal ([dn3l](https://github.com/unxed/dn3l)) and of a recreation of Turbo Vision based on the current fork of the C version.

I'd like to propose a set of ideas aimed at near-perfect interoperability between rcmd and the rest of the terminal/file-manager ecosystem. I checked the README, `CHANGELOG.md` and `docs/ORTHODOX-DIFF.md`; items that are already implemented are checked below with the version where they landed.

**General requirement:** every protocol below must work both when rcmd talks to an **external terminal** (rcmd is the application) and inside rcmd's **embedded terminal** (rcmd is the terminal, and the programs run in it can use the protocols). Supporting only one side breaks nesting (rcmd in far2l in rcmd, over SSH, in tmux-less setups) and is exactly where the seams show.

## Protocols

- [ ] **OSC 52 (clipboard write)**
  - Spec: [xterm ctlseqs, OSC 52](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html).
  - Why: the only clipboard path that works over SSH, in containers and in headless sessions. rcmd's own copy (path, editor selection, viewer) lands in the user's local clipboard, and programs inside the embedded terminal (vim, tmux, fish) can do the same through rcmd.
  - Status: I found no mention of it in the docs; please tick the box if it exists.

- [x] **Bracketed paste** — implemented in 4.32.0 (a paste is one event, not keystrokes).
  - Spec: [xterm ctlseqs](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html).
  - Remaining check: the embedded terminal should also *emit* the `ESC[200~ … ESC[201~` wrapping to programs that enabled mode 2004, and forward it from an outer terminal to the inner one unchanged.

- [x] **Kitty keyboard protocol** — implemented in 4.38.0 / 4.48.0 for the terminal build (`kitty_keyboard = true`).
  - Spec: [kitty keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/).
  - Remaining check: support in the embedded terminal, so inner applications that request the protocol get it (and the outer keyboard flags are translated, not swallowed).

- [ ] **Kitty graphics protocol (images)**
  - Spec: [kitty graphics protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/).
  - Why: F3 / quick view of PNG/JPEG/GIF/WebP in the terminal build, not only in rcmd-egui (4.39.0). Inside the embedded terminal it lets `kitten icat` and other image viewers work.
  - Note: `docs/ORTHODOX-DIFF.md` §9 lists in-terminal images as declined because of detection, cell geometry and redraw cost. I'd like to ask to revisit it as an opt-in, kitty-protocol-only feature (query support, fall back to nothing when absent), which avoids most of the sixel/iterm2 matrix.

- [ ] **win32 input mode (ConPTY, Konsole)**
  - Spec: [Win32 input mode](https://github.com/microsoft/terminal/blob/main/doc/specs/%234999%20-%20Improved%20keyboard%20handling%20in%20Conpty.md).
  - Why: full key events (separate press/release, exact modifiers, scancodes) where kitty keyboard isn't available, notably Windows Terminal/ConPTY and Konsole. It is also what makes Far-style key combinations (Ctrl+digits, Alt+F-keys, Shift+Enter) reliable there.

- [ ] **far2l terminal extensions**
  - Reference: [far2l](https://github.com/elfmz/far2l). The extension channel gives exact key events, clipboard access, window/cursor queries and more, in the terminal and over SSH.
  - Why: far2l ↔ rcmd nesting works without losing keys or clipboard, and the extension channel is the foundation for the next item.

- [ ] **Drag and drop over the far2l extensions (as in f4)**
  - Spec: [far2l PR #3647, `WinPort/DND.md`](https://github.com/elfmz/far2l/pull/3647): BIND / INPUT_DND / LIST / READ / CLOSE, nothing travels unasked, so the same protocol serves a local session and SSH without a second connection.
  - Reference implementation of the application side: [f4](https://github.com/unxed/f4).
  - Why: rcmd-egui already copies files dropped on a panel (4.39.0). This brings the same behaviour to the terminal build and to remote sessions, and lets files be dragged from rcmd's panels out into other windows.

## Overlay and embedded terminal as switchable modes

Please make the two ways of running commands a setting:

1. **Overlay** (as in Far and mc): the panels are hidden to show the shell's own screen; the user sees the real output of the external terminal.
2. **Embedded terminal** (as in [far2l](https://github.com/elfmz/far2l) / far2m): commands run in a pane inside rcmd (today `Ctrl+O` does this in rcmd-egui).
3. **Pipe fallback** (what [f4](https://github.com/unxed/f4) does): where neither is possible, e.g. a GUI window on an old Windows without ConPTY, run the command with output going to a pipe and print the result in a window. Same approach is possible here.

Why: no single mode fits all platforms and terminals. Overlay gives true terminal fidelity, embedded gives panels that stay visible and the full set of protocols above handled by rcmd itself, pipe is the only thing that works on legacy systems. Making it a setting avoids guessing.

## Far-compatible keys (opt-in)

rcmd has `keymap = "mc"` and `"modern"`. I'd like an additional **Far Manager keymap**, **off by default** (a checkbox / `keymap = "far"`). rcmd's `docs/ORTHODOX-DIFF.md` already tracks many Far keys; a dedicated preset makes them consistent. I have equivalent work open for mcommander:

- [Far Manager compatibility mode (#370)](https://github.com/blue-panels/mcommander/pull/370)
- [Far mode: listing modes and the keys of the command line (#369)](https://github.com/blue-panels/mcommander/pull/369)
- [Far mode: Far keys in the editor and the viewer (#362)](https://github.com/blue-panels/mcommander/pull/362)
- [Far mode: Shift-gray, PgDn, Shift-Enter in dialogs, folder shortcuts, Ctrl-[ and Ctrl-] (#376)](https://github.com/blue-panels/mcommander/pull/376)
- [Terminal input: support the far2l keyboard extensions (#360)](https://github.com/blue-panels/mcommander/pull/360)
- [all my PRs there](https://github.com/blue-panels/mcommander/pulls?q=is%3Apr+author%3Aunxed)

## What this gives together

- **Seamless nesting:** rcmd inside far2l/f4/mc and any of them inside rcmd's embedded terminal, locally or over SSH, without lost keys, clipboard or drag and drop.
- **Better UX:** clipboard and paste behave as users expect everywhere; key combos are exact; images and drops work in a plain terminal.
- **Ecosystem boost:** orthodox file managers share the same set of protocols and one dialect for the extensions, so users switch tools without relearning and each project gets the others' features for free.

I'm happy to send PRs for some of these, starting with the smaller ones (OSC 52, the embedded-terminal side of bracketed paste/kitty keyboard) if you'd like.
