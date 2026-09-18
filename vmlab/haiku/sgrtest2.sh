#!/bin/sh
# Haiku Terminal SGR parameter-count / reset-prefix experiment (screenshot it).
E=$(printf '\033')
clear
echo "A 0; + fg + bg   (11 params, what f4 sends): ${E}[0;38;2;238;238;236;48;2;55;50;44m A cfg ${E}[0m|"
echo "B fg + bg        (10 params):               ${E}[38;2;238;238;236;48;2;55;50;44m B cfg ${E}[0m|"
echo "C separate seqs:                            ${E}[0m${E}[38;2;238;238;236m${E}[48;2;55;50;44m C cfg ${E}[0m|"
echo "D 0; + fg only   (6 params):                ${E}[0;38;2;238;238;236m D cfg ${E}[0m|"
echo "E 1; + fg + bg   (bold prefix, 11 params):  ${E}[1;38;2;238;238;236;48;2;55;50;44m E cfg ${E}[0m|"
echo "F 0; + bg only   (6 params):                ${E}[0;48;2;55;50;44m F cfg ${E}[0m|"
echo "G 0;bg;fg order  (11 params):               ${E}[0;48;2;55;50;44;38;2;238;238;236m G cfg ${E}[0m|"
echo "H 7 params 0;38;5;250;48;5;236:             ${E}[0;38;5;250;48;5;236m H cfg ${E}[0m|"
echo "done"
