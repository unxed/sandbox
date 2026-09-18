#!/usr/bin/env python3
"""vmlab: drive a QEMU guest (keyboard, mouse, screenshots, VM snapshots)
from a text scenario ("run") or interactively through a git-branch command
queue ("session"). Meant to run inside a GitHub Actions job; stdlib only.

Scenario language: one step per line, '#' starts a comment.

  wait SEC                    sleep
  shot NAME                   screenshot -> out/NAME.png
  key CHORD [CHORD...]        press chords, e.g.  key ctrl-alt-t   key ret
  type TEXT                   type literal text (escapes: \\n \\t \\\\)
  typeln TEXT                 type TEXT then Enter
  click X Y [right|double]    absolute pointer click (guest pixel coords)
  move X Y                    move pointer
  drag X1 Y1 X2 Y2            press at 1, release at 2
  stable SEC [TIMEOUT]        wait until the screen has not changed for SEC s
  waittext REGEX [TIMEOUT]    wait until OCR of the screen matches REGEX
  save NAME / load NAME       VM snapshot (RAM + disk) in the qcow2 overlay
  hmp CMD                     raw QEMU human-monitor command
"""
import argparse
import glob
import hashlib
import http.server
import json
import os
import pathlib
import re
import shutil
import socket
import struct
import subprocess
import sys
import threading
import time
import urllib.request
import zipfile

WORK = pathlib.Path(os.environ.get("VMLAB_WORK", "/tmp/vmlab"))


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


# ---------------------------------------------------------------- keyboard
BASE = {" ": "spc", "\n": "ret", "\t": "tab", "-": "minus", "=": "equal",
        "[": "bracket_left", "]": "bracket_right", "\\": "backslash",
        ";": "semicolon", "'": "apostrophe", "`": "grave_accent",
        ",": "comma", ".": "dot", "/": "slash"}
SHIFTED = {"_": "minus", "+": "equal", "{": "bracket_left", "}": "bracket_right",
           "|": "backslash", ":": "semicolon", '"': "apostrophe", "~": "grave_accent",
           "<": "comma", ">": "dot", "?": "slash", "!": "1", "@": "2", "#": "3",
           "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0"}
ALIAS = {"ctrl": "ctrl", "alt": "alt", "shift": "shift", "meta": "meta_l",
         "win": "meta_l", "enter": "ret", "return": "ret", "escape": "esc",
         "space": "spc", "del": "delete", "pgup": "pgup", "pgdn": "pgdn"}


def char_keys(c):
    if c in BASE:
        return [BASE[c]]
    if c in SHIFTED:
        return ["shift", SHIFTED[c]]
    if c.isascii() and c.isalpha():
        return ["shift", c.lower()] if c.isupper() else [c]
    if c.isascii() and c.isdigit():
        return [c]
    raise ValueError("cannot type character %r" % c)


# ---------------------------------------------------------------- QMP
class QMP:
    def __init__(self, path, timeout=60):
        self.s = socket.socket(socket.AF_UNIX)
        end = time.time() + timeout
        while True:
            try:
                self.s.connect(str(path))
                break
            except OSError:
                if time.time() > end:
                    raise
                time.sleep(0.3)
        self.f = self.s.makefile("rw")
        self.f.readline()  # greeting
        self.cmd("qmp_capabilities")

    def cmd(self, name, **args):
        self.f.write(json.dumps({"execute": name, "arguments": args}) + "\n")
        self.f.flush()
        while True:
            line = self.f.readline()
            if not line:
                raise EOFError("QMP closed (qemu died?)")
            msg = json.loads(line)
            if "return" in msg:
                return msg["return"]
            if "error" in msg:
                raise RuntimeError("%s: %s" % (name, msg["error"]["desc"]))

    def hmp(self, line):
        return self.cmd("human-monitor-command", **{"command-line": line})


# ---------------------------------------------------------------- guest VM
def fetch_image(guest, work):
    """Download + unpack the guest base image once; returns path of the raw disk."""
    img = work / "base.img"
    if img.exists():
        return img
    url = guest["image_url"]
    log("downloading", url)
    dl = work / "download"
    urllib.request.urlretrieve(url, dl)
    if guest.get("image_kind") == "zip":
        with zipfile.ZipFile(dl) as z:
            z.extractall(work / "unz")
        found = sorted(glob.glob(str(work / "unz" / "**" / guest.get("image_glob", "*.iso")),
                                 recursive=True))
        if not found:
            raise SystemExit("no %s inside %s" % (guest.get("image_glob"), url))
        shutil.move(found[0], img)
        shutil.rmtree(work / "unz")
        dl.unlink()
    else:
        shutil.move(dl, img)
    return img


def start_qemu(guest, work, loadvm=None):
    base = fetch_image(guest, work)
    overlay = work / "overlay.qcow2"
    if not overlay.exists():
        subprocess.run(["qemu-img", "create", "-q", "-f", "qcow2", "-F", "raw",
                        "-b", str(base), str(overlay)], check=True)
    kvm = os.access("/dev/kvm", os.R_OK | os.W_OK)
    log("KVM available:", kvm)
    args = ["qemu-system-x86_64",
            "-machine", "pc-i440fx-8.2,accel=" + ("kvm" if kvm else "tcg"),
            "-cpu", "host" if kvm else "max",
            "-m", str(guest.get("ram", 2048)), "-smp", str(guest.get("smp", 2)),
            "-display", "none", "-vga", "std",
            "-drive", "file=%s,format=qcow2,if=ide,index=0" % overlay,
            "-usb", "-device", "usb-tablet",
            "-nic", "user,model=%s" % guest.get("nic", "e1000"),
            "-qmp", "unix:%s,server=on,wait=off" % (work / "qmp.sock"),
            "-serial", "file:%s" % (work / "serial.log"),
            "-monitor", "none", "-no-reboot"]
    args += guest.get("qemu_extra", [])
    extra_drive = work / "payload.iso"
    if extra_drive.exists():
        args += ["-drive", "file=%s,media=cdrom,if=ide,index=2,readonly=on" % extra_drive]
    if loadvm:
        args += ["-loadvm", loadvm]
    log("qemu:", " ".join(args))
    proc = subprocess.Popen(args, stdout=open(work / "qemu.log", "w"), stderr=subprocess.STDOUT)
    return proc, QMP(work / "qmp.sock")


def snapshot_names(work):
    overlay = work / "overlay.qcow2"
    if not overlay.exists():
        return []
    out = subprocess.run(["qemu-img", "snapshot", "-l", str(overlay)],
                         capture_output=True, text=True).stdout
    return [l.split()[1] for l in out.splitlines()[2:] if l.strip()]


# ---------------------------------------------------------------- scenario steps
class Lab:
    def __init__(self, qmp, outdir):
        self.q, self.out = qmp, pathlib.Path(outdir)
        self.out.mkdir(parents=True, exist_ok=True)
        self.size = None
        self.saved = False

    # -- screen
    def _dump(self, path):
        self.q.cmd("screendump", filename=str(path), format="png")
        with open(path, "rb") as f:
            hdr = f.read(24)
        self.size = struct.unpack(">II", hdr[16:24])
        return path

    def shot(self, name):
        p = self._dump(self.out / (re.sub(r"[^\w.-]", "_", name) + ".png"))
        return "%s (%dx%d)" % (p.name, *self.size)

    def _hash(self):
        tmp = self.out / ".tmp.png"
        self._dump(tmp)
        return hashlib.sha1(tmp.read_bytes()).hexdigest()

    # -- input
    def press(self, keys, hold=40):
        self.q.cmd("send-key", keys=[{"type": "qcode", "data": k} for k in keys],
                   **{"hold-time": hold})

    def do_key(self, rest):
        for chord in rest.split():
            keys = [ALIAS.get(k, k) for k in chord.split("-") if k]
            if chord.endswith("--"):  # e.g. ctrl-- => ctrl + minus
                keys = [ALIAS.get(k, k) for k in chord[:-2].split("-") if k] + ["minus"]
            self.press(keys)
            time.sleep(0.15)

    def do_type(self, rest, enter=False):
        text = rest.encode().decode("unicode_escape") if "\\" in rest else rest
        for c in text + ("\n" if enter else ""):
            self.press(char_keys(c), hold=25)
            time.sleep(0.03)

    def do_typeln(self, rest):
        self.do_type(rest, enter=True)

    def _abs(self, x, y):
        if not self.size:
            self._dump(self.out / ".tmp.png")
        w, h = self.size
        ev = [{"type": "abs", "data": {"axis": "x", "value": int(int(x) * 32767 / (w - 1))}},
              {"type": "abs", "data": {"axis": "y", "value": int(int(y) * 32767 / (h - 1))}}]
        self.q.cmd("input-send-event", events=ev)

    def _btn(self, name, down):
        self.q.cmd("input-send-event", events=[{"type": "btn", "data": {"button": name, "down": down}}])

    def do_move(self, rest):
        x, y = rest.split()[:2]
        self._abs(x, y)

    def do_click(self, rest):
        p = rest.split()
        self._abs(p[0], p[1])
        time.sleep(0.15)
        btn = "right" if "right" in p[2:] else "left"
        for _ in range(2 if "double" in p[2:] else 1):
            self._btn(btn, True)
            time.sleep(0.08)
            self._btn(btn, False)
            time.sleep(0.12)

    def do_drag(self, rest):
        x1, y1, x2, y2 = rest.split()[:4]
        self._abs(x1, y1)
        time.sleep(0.1)
        self._btn("left", True)
        time.sleep(0.15)
        self._abs(x2, y2)
        time.sleep(0.2)
        self._btn("left", False)

    # -- waiting
    def do_wait(self, rest):
        time.sleep(float(rest))

    def do_stable(self, rest):
        p = rest.split()
        need, timeout = float(p[0]), float(p[1]) if len(p) > 1 else 120
        end, last, since = time.time() + timeout, None, time.time()
        while time.time() < end:
            h = self._hash()
            if h != last:
                last, since = h, time.time()
            elif time.time() - since >= need:
                return "stable after %.0fs" % (time.time() - (end - timeout))
            time.sleep(1)
        raise TimeoutError("screen not stable for %ss within %ss" % (need, timeout))

    def ocr(self):
        tmp = self.out / ".ocr.png"
        self._dump(tmp)
        r = subprocess.run(["tesseract", str(tmp), "-", "--psm", "6"], capture_output=True, text=True)
        return r.stdout

    def do_waittext(self, rest):
        parts = rest.rsplit(None, 1)
        timeout = 60.0
        if len(parts) == 2 and re.fullmatch(r"\d+(\.\d+)?", parts[1]):
            rest, timeout = parts[0], float(parts[1])
        end, text = time.time() + timeout, ""
        while time.time() < end:
            text = self.ocr()
            if re.search(rest, text, re.I | re.S):
                return "matched %r" % rest
            time.sleep(2)
        raise TimeoutError("text %r not seen; last OCR: %r" % (rest, text[:300]))

    # -- VM state
    def do_save(self, rest):
        r = self.q.hmp("savevm " + rest.strip())
        self.saved = True
        return r.strip() or "saved"

    def do_load(self, rest):
        return self.q.hmp("loadvm " + rest.strip()).strip() or "loaded"

    def do_hmp(self, rest):
        return self.q.hmp(rest).strip()

    def do_shot(self, rest):
        return self.shot(rest.strip() or "shot")

    # -- dispatcher
    def step(self, line):
        line = line.strip()
        if not line or line.startswith("#"):
            return None
        name, _, rest = line.partition(" ")
        fn = getattr(self, "do_" + name, None)
        if fn is None:
            raise ValueError("unknown step %r" % name)
        t0 = time.time()
        res = fn(rest if name in ("type", "typeln") else rest.strip())
        return "%s%s  [%.1fs]" % (line[:80], (" -> " + str(res)) if res else "", time.time() - t0)


def run_lines(lab, lines, stop_on_error=True):
    ok = True
    for line in lines:
        try:
            r = lab.step(line)
            if r:
                log("ok  ", r)
        except Exception as e:  # noqa: BLE001 - report every failure, keep session alive
            ok = False
            log("FAIL", line.strip()[:80], "->", repr(e))
            if stop_on_error:
                break
    return ok


# ---------------------------------------------------------------- payload/upload HTTP server
def start_http(payload_dir, upload_dir, port=8000):
    payload_dir, upload_dir = pathlib.Path(payload_dir), pathlib.Path(upload_dir)
    payload_dir.mkdir(parents=True, exist_ok=True)
    upload_dir.mkdir(parents=True, exist_ok=True)

    class H(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **k):
            super().__init__(*a, directory=str(payload_dir), **k)

        def do_PUT(self):
            name = pathlib.PurePosixPath(self.path).name or "upload"
            n = int(self.headers.get("Content-Length", 0))
            (upload_dir / name).write_bytes(self.rfile.read(n))
            self.send_response(200)
            self.end_headers()

        do_POST = do_PUT

        def log_message(self, *a):
            pass

    srv = http.server.ThreadingHTTPServer(("0.0.0.0", port), H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    log("http: serving %s, uploads -> %s on :%d (guest sees host as 10.0.2.2)" % (payload_dir, upload_dir, port))


# ---------------------------------------------------------------- git bus (session mode)
class Bus:
    """Commands come from branch vmlab-cmd (cmd/<run>/<n>.txt, written by ctl.py);
    results go to branch vmlab-out (out/<n>/...). Single writer per branch."""

    def __init__(self, run_id):
        self.run, self.dir = run_id, WORK / "bus"
        shutil.rmtree(self.dir, ignore_errors=True)
        self.dir.mkdir(parents=True)
        tok, repo = os.environ["GITHUB_TOKEN"], os.environ["GITHUB_REPOSITORY"]
        self.g("init", "-q", "-b", "out")
        self.g("remote", "add", "origin", "https://x-access-token:%s@github.com/%s.git" % (tok, repo))
        self.g("config", "user.name", "vmlab")
        self.g("config", "user.email", "vmlab@users.noreply.github.com")
        (self.dir / "SESSION").write_text(str(run_id) + "\n")
        self.publish("session %s start" % run_id, force=True)
        self.done = set()

    def g(self, *a, check=True):
        return subprocess.run(["git", *a], cwd=self.dir, capture_output=True, text=True, check=check)

    def publish(self, msg, force=False):
        self.g("add", "-A")
        self.g("commit", "-q", "--allow-empty", "-m", msg)
        r = self.g("push", "-q", *(["-f"] if force else []), "origin", "out:vmlab-out", check=False)
        if r.returncode:
            log("push failed:", r.stderr.strip()[:300])

    def pending(self):
        r = self.g("fetch", "-q", "--depth", "1", "origin", "vmlab-cmd:refs/remotes/origin/vmlab-cmd", check=False)
        if r.returncode:
            return []
        ls = self.g("ls-tree", "-r", "--name-only", "refs/remotes/origin/vmlab-cmd",
                    "cmd/%s/" % self.run, check=False).stdout.split()
        ids = sorted(int(pathlib.PurePosixPath(p).stem) for p in ls if pathlib.PurePosixPath(p).stem.isdigit())
        return [i for i in ids if i not in self.done]

    def read(self, i):
        return self.g("show", "refs/remotes/origin/vmlab-cmd:cmd/%s/%04d.txt" % (self.run, i)).stdout


class Tee:
    def __init__(self):
        self.lines = []

    def write(self, s):
        self.lines.append(s)
        sys.__stdout__.write(s)

    def flush(self):
        sys.__stdout__.flush()


def session(args, guest):
    run_id = os.environ.get("GITHUB_RUN_ID", "local")
    work = WORK
    proc, q = start_qemu(guest, work, loadvm=args.loadvm)
    lab = Lab(q, work / "shots")
    start_http(work / "payload", work / "upload")
    bus = Bus(run_id)
    outroot = bus.dir / "out"
    deadline = time.time() + args.minutes * 60
    idle_deadline = time.time() + args.idle * 60
    log("session %s ready; deadline in %d min" % (run_id, args.minutes))

    def emit(n, lines, ok, logtxt):
        d = outroot / ("%04d" % n)
        d.mkdir(parents=True, exist_ok=True)
        (d / "log.txt").write_text(logtxt)
        for p in lab.out.glob("*.png"):
            if not p.name.startswith("."):
                shutil.move(str(p), d / p.name)
        for p in (work / "upload").glob("*"):
            shutil.move(str(p), d / ("upload-" + p.name))
        (d / "status").write_text("ok\n" if ok else "fail\n")
        bus.publish("cmd %04d %s" % (n, "ok" if ok else "FAIL"))

    if args.scenario:
        tee = Tee(); sys.stdout = tee
        ok = run_lines(lab, pathlib.Path(args.scenario).read_text().splitlines(), stop_on_error=True)
        sys.stdout = sys.__stdout__
        emit(0, [], ok, "".join(tee.lines))
    else:
        emit(0, [], True, "vm started, no scenario replayed\n" + lab.shot("start") + "\n")
    stop = False
    while not stop and time.time() < deadline and time.time() < idle_deadline and proc.poll() is None:
        for n in bus.pending():
            lines = bus.read(n).splitlines()
            bus.done.add(n)
            idle_deadline = time.time() + args.idle * 60
            if any(l.strip() == "stop" for l in lines):
                stop = True
                lines = [l for l in lines if l.strip() != "stop"]
            tee = Tee(); sys.stdout = tee
            try:
                ok = run_lines(lab, lines, stop_on_error=True)
            finally:
                sys.stdout = sys.__stdout__
            emit(n, lines, ok, "".join(tee.lines))
        time.sleep(1.5)
    log("session ending (stop=%s, qemu alive=%s)" % (stop, proc.poll() is None))
    if lab.saved:
        (work / "SAVED").write_text("1")
    try:
        q.cmd("quit")
    except Exception:  # noqa: BLE001
        pass
    proc.wait(timeout=30)


def batch(args, guest):
    work = WORK
    loadvm = args.loadvm if args.loadvm in snapshot_names(work) else None
    proc, q = start_qemu(guest, work, loadvm=loadvm)
    lab = Lab(q, work / "shots")
    start_http(work / "payload", work / "upload")
    ok = run_lines(lab, pathlib.Path(args.scenario).read_text().splitlines(), stop_on_error=True)
    lab.shot("final")
    if lab.saved:
        (work / "SAVED").write_text("1")
    try:
        q.cmd("quit")
    except Exception:  # noqa: BLE001
        pass
    proc.wait(timeout=30)
    sys.exit(0 if ok else 1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["session", "run"])
    ap.add_argument("--guest", required=True)
    ap.add_argument("--scenario")
    ap.add_argument("--minutes", type=int, default=30)
    ap.add_argument("--idle", type=int, default=10)
    ap.add_argument("--loadvm")
    args = ap.parse_args()
    WORK.mkdir(parents=True, exist_ok=True)
    guest = json.load(open(args.guest))
    (session if args.mode == "session" else batch)(args, guest)


if __name__ == "__main__":
    main()
