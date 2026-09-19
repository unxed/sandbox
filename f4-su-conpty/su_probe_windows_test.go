//go:build windows

package app

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"
	"unicode"

	"github.com/unxed/f4/internal/keymap"
	"github.com/unxed/f4/internal/panel"
	"github.com/unxed/vtinput"
)

// A probe for f4 #207 / #1197: after `su diskpart` and `exit` inside f4-gui's
// embedded terminal, Enter and Backspace stop working. It drives f4's own
// ConPTY panel the way the GUI does -- keys go through keymap.TranslateInput
// with the terminal's current keyboard mode -- and reports, stage by stage,
// which keys still reach the shell and which keyboard mode f4 thinks it is in.
// It never fails early: the point is the matrix it prints.

func suProbeText(pf *panel.PanelsFrame) string {
	return string(pf.TermView.GetAllLogBytes())
}

func suProbeHasLine(text, want string) bool {
	for _, l := range strings.Split(strings.ReplaceAll(text, "\r", ""), "\n") {
		if strings.TrimSpace(l) == want {
			return true
		}
	}
	return false
}

func suProbeState(t *testing.T, pf *panel.PanelsFrame, stage string) {
	tv := pf.TermView
	t.Logf("STATE %-34s win32InputMode=%v kittyFlags=%d appCursorKeys=%v altScreen=%v", stage, tv.Win32InputMode, tv.KittyFlags, tv.ApplicationCursorKeys, tv.UseAltScreen)
}

func suProbeTail(t *testing.T, pf *panel.PanelsFrame, why string) {
	lines := strings.Split(strings.ReplaceAll(suProbeText(pf), "\r", ""), "\n")
	if len(lines) > 25 {
		lines = lines[len(lines)-25:]
	}
	t.Logf("SCREEN TAIL (%s):\n| %s", why, strings.Join(lines, "\n| "))
}

func suProbeWait(pf *panel.PanelsFrame, ok func(string) bool, d time.Duration) bool {
	deadline := time.Now().Add(d)
	for time.Now().Before(deadline) {
		drainFrameTasks()
		if ok(suProbeText(pf)) {
			return true
		}
		time.Sleep(50 * time.Millisecond)
	}
	return false
}

func suProbeKey(t *testing.T, pf *panel.PanelsFrame, vk uint16, ch rune, log bool) {
	tv := pf.TermView
	for _, down := range []bool{true, false} {
		e := &vtinput.InputEvent{Type: vtinput.KeyEventType, VirtualKeyCode: vk, Char: ch, KeyDown: down, RepeatCount: 1}
		seq := keymap.TranslateInput(e, tv.Win32InputMode, tv.KittyFlags, tv.ApplicationCursorKeys)
		if log {
			t.Logf("   key vk=0x%02x down=%v -> %q (win32=%v kitty=%d)", vk, down, seq, tv.Win32InputMode, tv.KittyFlags)
		}
		if seq != "" {
			_, _ = pf.GetActivePTY().Write([]byte(seq))
		}
		time.Sleep(15 * time.Millisecond)
	}
}

func suProbeType(t *testing.T, pf *panel.PanelsFrame, s string) {
	for _, r := range s {
		vk := uint16(0)
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9':
			vk = uint16(unicode.ToUpper(r))
		case r == ' ':
			vk = vtinput.VK_SPACE
		}
		suProbeKey(t, pf, vk, r, false)
	}
}

func suProbeEnter(t *testing.T, pf *panel.PanelsFrame)     { suProbeKey(t, pf, vtinput.VK_RETURN, '\r', true) }
func suProbeBackspace(t *testing.T, pf *panel.PanelsFrame) { suProbeKey(t, pf, vtinput.VK_BACK, 0x08, true) }

// suProbeRound checks that a typed command runs (Enter) and that Backspace
// edits the line, and says which of the two failed.
func suProbeRound(t *testing.T, pf *panel.PanelsFrame, tag string) {
	suProbeType(t, pf, "echo "+tag+"1")
	suProbeEnter(t, pf)
	enter := suProbeWait(pf, func(s string) bool { return suProbeHasLine(s, tag+"1") }, 8*time.Second)
	t.Logf("RESULT %-8s Enter runs the line:        %v", tag, enter)

	suProbeType(t, pf, "echo "+tag+"XY")
	suProbeBackspace(t, pf)
	suProbeType(t, pf, "Z")
	suProbeEnter(t, pf)
	bs := suProbeWait(pf, func(s string) bool { return suProbeHasLine(s, tag+"XZ") }, 8*time.Second)
	t.Logf("RESULT %-8s Backspace edits the line:   %v", tag, bs)
	suProbeState(t, pf, tag+" (after round)")
	if !enter || !bs {
		suProbeTail(t, pf, tag+" round failed")
	}
}

func TestSuConPTYProbe(t *testing.T) {
	su := os.Getenv("SU_EXE")
	if su == "" {
		t.Skip("SU_EXE is not set")
	}
	pf := startLocalConPTY(t)
	defer pf.Close()
	suProbeState(t, pf, "shell started")

	suProbeRound(t, pf, "BASE")

	t.Logf("=== su diskpart")
	suProbeType(t, pf, fmt.Sprintf("\"%s\" diskpart", su))
	suProbeEnter(t, pf)
	inDiskpart := suProbeWait(pf, func(s string) bool { return strings.Contains(s, "DISKPART>") }, 90*time.Second)
	t.Logf("RESULT su: DISKPART prompt reached: %v", inDiskpart)
	suProbeState(t, pf, "inside diskpart")
	if !inDiskpart {
		suProbeTail(t, pf, "diskpart never showed its prompt")
	}

	t.Logf("=== exit")
	suProbeType(t, pf, "exit")
	suProbeEnter(t, pf)
	time.Sleep(3 * time.Second)
	suProbeState(t, pf, "after exit")
	suProbeTail(t, pf, "after exit")

	suProbeRound(t, pf, "AFTER")

	// Which encoding does the shell still understand? Send both by hand.
	pty := pf.GetActivePTY()
	t.Logf("=== raw probes")
	suProbeType(t, pf, "echo RAWCR")
	_, _ = pty.Write([]byte("\r"))
	t.Logf("RESULT raw CR runs the line:        %v", suProbeWait(pf, func(s string) bool { return suProbeHasLine(s, "RAWCR") }, 8*time.Second))
	suProbeType(t, pf, "echo W32")
	_, _ = pty.Write([]byte("\x1b[13;28;13;1;0;1_\x1b[13;28;13;0;0;1_"))
	t.Logf("RESULT win32-input-mode Enter runs: %v", suProbeWait(pf, func(s string) bool { return suProbeHasLine(s, "W32") }, 8*time.Second))
	suProbeTail(t, pf, "end")
}
