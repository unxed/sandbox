"""Temporary tracing for the probe: print every private-mode switch and RIS the
ConPTY output makes f4's terminal emulator handle. Applied to a throwaway
checkout of f4 in CI only; nothing here is meant for f4 itself."""
import sys

p = sys.argv[1] + "/internal/terminal/ansi.go"
s = open(p, encoding="utf-8").read()

old = '''			s = strings.TrimLeft(s, "?")
			switch s {
			case "1":
				p.term.ApplicationCursorKeys = isSet'''
new = '''			s = strings.TrimLeft(s, "?")
			println("MODEPROBE private mode", s, "set =", isSet)
			switch s {
			case "1":
				p.term.ApplicationCursorKeys = isSet'''
assert s.count(old) == 1, "private mode handler moved"
s = s.replace(old, new)

old = '''	case 'c': // RIS - Reset to Initial State
		p.term.ResetBuffer(p.term.Width, p.term.Height)'''
new = '''	case 'c': // RIS - Reset to Initial State
		println("MODEPROBE RIS (ESC c)")
		p.term.ResetBuffer(p.term.Width, p.term.Height)'''
assert s.count(old) == 1, "RIS handler moved"
s = s.replace(old, new)
open(p, "w", encoding="utf-8").write(s)
print("patched", p)
