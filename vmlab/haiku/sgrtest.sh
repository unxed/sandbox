#!/bin/sh
# Prints every SGR form f4 uses, to see how Haiku's Terminal renders each (screenshot it).
E=$(printf '\033')
clear
echo "1 plain text"
echo "2 ${E}[38;2;166;226;46mtruecolor FG only (lime)${E}[0m then plain"
echo "3 ${E}[38;2;211;215;207;48;2;55;50;44m truecolor FG+BG pair ${E}[0m then plain"
echo "4 ${E}[48;2;55;50;44m truecolor BG only ${E}[0m then plain"
echo "5 ${E}[38;5;154m256 FG 154${E}[0m ${E}[48;5;236m 256 BG 236 ${E}[0m ${E}[38;5;250;48;5;24m 256 pair ${E}[0m"
echo "6 ${E}[7mreverse${E}[0m ${E}[2mfaint${E}[0m ${E}[1mbold${E}[0m ${E}[4munderline${E}[0m"
echo "7 fg change without reset: ${E}[38;2;230;207;112mA${E}[38;2;85;87;83mB${E}[38;2;219;211;196mC${E}[0m"
echo "8 bg then overwrite by cursor moves:"
printf '%s' "${E}[48;2;0;179;0m##########${E}[0m"
printf '%s' "${E}[10D${E}[48;2;55;50;44m          ${E}[0m"
echo
printf '%s' "${E}[48;2;0;179;0m##########${E}[0m"
printf '%s' "${E}[10D${E}[10C${E}[10D${E}[38;2;211;215;207;48;2;55;50;44m  moved   ${E}[0m"
echo
echo "9 done"
