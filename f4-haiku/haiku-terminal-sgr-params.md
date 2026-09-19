# Haiku Terminal: SGR sequences with more than 10 parameters are misparsed

**Ready to paste into https://dev.haiku-os.org/newticket** (needs an account: https://dev.haiku-os.org/register).

| Field | Value |
|---|---|
| Summary | Terminal: escape sequences with more than 10 parameters are misparsed (24-bit colour SGR gets a wrong background) |
| Component | Applications/Terminal |
| Type | bug |
| Version | R1/Development (hrev60122, x86_64, nightly `haiku-master-hrev60122-x86_64-anyboot`) |
| Tested on | QEMU/KVM guest (vmlab, GitHub Actions); Terminal with default settings, TERM=xterm-256color |
| Related | ticket #6227 mentions `TermParse::EscParse()`; search the tracker for `NPARAM` before filing to avoid a duplicate |
| Attachment | screenshot of the four repro lines (`vmlab/haiku/sgrtest2.sh` output; run artifacts of the `vmlab-haiku` workflow in github.com/unxed/sandbox) |

Draft of an upstream bug report (for dev.haiku-os.org / the Haiku issue tracker), found while
running f4 (https://github.com/unxed/f4) on Haiku hrev60122 x86_64 in QEMU/KVM.

## Summary

`src/apps/terminal/TermParse.cpp` keeps at most `NPARAM` (10) parameters per escape sequence:

```c
#define NPARAM 10		// Max parameters
...
if (nparam < NPARAM)
    param[nparam++] = DEFAULT;
```

A `;` beyond the 10th parameter is silently ignored, so the digits of the 11th parameter are
appended to the 10th (`param[nparam - 1] = 10 * row + (c - '0')`). A sequence such as

    ESC [ 0 ; 38;2;238;238;236 ; 48;2;55;50;44 m        (11 parameters)

which resets attributes and then sets a 24-bit foreground and background, therefore sets a
garbage background colour (the 10th parameter `50` followed by `;44` becomes `5044`; here the
cell ends up solid green). The same colours sent as 10 parameters (without the leading `0;`) or as
separate sequences render correctly. xterm accepts up to 30 parameters (`MAXPARAMS`), and f4,
which packs a reset and two true-colour components into one SGR as its "minimal transition"
encoding, works unmodified in the other terminals it targets (kitty, iTerm2, Windows Terminal,
Konsole); Haiku's Terminal is the one where it breaks.

## Reproduction

Run in Terminal (see `vmlab/haiku/sgrtest2.sh` in this repository):

```sh
E=$(printf '\033')
echo "11 params: ${E}[0;38;2;238;238;236;48;2;55;50;44m cfg ${E}[0m|"   # green background (wrong)
echo "10 params: ${E}[38;2;238;238;236;48;2;55;50;44m cfg ${E}[0m|"     # dark grey (correct)
echo "split:     ${E}[0m${E}[38;2;238;238;236m${E}[48;2;55;50;44m cfg ${E}[0m|"  # correct
echo "11 params, bg first: ${E}[0;48;2;55;50;44;38;2;238;238;236m cfg ${E}[0m|" # yellow text (wrong)
```

Expected: all four lines show light text on a dark background. Actual: lines 1 and 4 are wrong
as described above.

## Suggested fix

Raise `NPARAM` (e.g. to 32; the array is on the stack of `TermParse::EscParse()`), or make the
parser drop the digits of surplus parameters instead of appending them to the last one.

## Workaround used in f4 (until Terminal is fixed)

`vtui-haiku.patch` in this repository caps the number of parameters per SGR sequence at 10 on
`GOOS=haiku` only (`sgr_limit_haiku.go`) and starts a new sequence before a colour component that
would exceed it.
