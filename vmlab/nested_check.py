#!/usr/bin/env python3
"""One-shot diagnostic: what does '-cpu host' under KVM actually expose to an
L2 guest on *this* runner? Starts a throwaway, stopped (-S) QEMU instance with
no disk/display, asks it over QMP (query-cpu-model-expansion) what the "host"
CPU model resolves to, and prints the flags relevant to nested virtualization
(SVM/VMX, nested paging) -- the precondition for Hyper-V (and thus WSL2)
running inside a Windows guest that vmlab itself boots. stdlib only, meant to
run inside the GitHub Actions job right after the KVM/qemu apt step.
"""
import json
import socket
import subprocess
import sys
import time

SOCK = "/tmp/qmp-diag.sock"
PIDFILE = "/tmp/qmp-diag.pid"


def main():
    subprocess.run(["rm", "-f", SOCK, PIDFILE])
    subprocess.run([
        "qemu-system-x86_64", "-machine", "pc,accel=kvm", "-cpu", "host",
        "-m", "256", "-display", "none", "-daemonize",
        "-qmp", "unix:%s,server=on,wait=off" % SOCK,
        "-monitor", "none", "-S", "-no-reboot", "-pidfile", PIDFILE,
    ], check=True)
    try:
        s = socket.socket(socket.AF_UNIX)
        end = time.time() + 15
        while True:
            try:
                s.connect(SOCK)
                break
            except OSError:
                if time.time() > end:
                    raise
                time.sleep(0.2)
        f = s.makefile("rw")
        f.readline()  # greeting
        f.write(json.dumps({"execute": "qmp_capabilities"}) + "\n")
        f.flush()
        f.readline()
        f.write(json.dumps({
            "execute": "query-cpu-model-expansion",
            "arguments": {"type": "full", "model": {"name": "host"}},
        }) + "\n")
        f.flush()
        reply = json.loads(f.readline())
        if "error" in reply:
            print("QMP error:", reply["error"])
            return 1
        props = reply["return"]["model"]["props"]
        print("props -cpu host would expose to an L2 guest on this runner:")
        interesting = ("svm", "vmx", "npt", "ept", "svm-npt", "nested-hvm")
        seen = False
        for k in interesting:
            if k in props:
                print(" ", k, "=", props[k])
                seen = True
        if not seen:
            print("  (none of %s present in the model; full prop list follows)" % (interesting,))
            for k, v in sorted(props.items()):
                print(" ", k, "=", v)
        return 0
    finally:
        try:
            with open(PIDFILE) as fh:
                pid = int(fh.read().strip())
            subprocess.run(["kill", str(pid)])
        except Exception as e:  # noqa: BLE001
            print("(cleanup: could not kill diagnostic qemu:", e, ")")


if __name__ == "__main__":
    sys.exit(main())
