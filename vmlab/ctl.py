#!/usr/bin/env python3
"""vmlab ctl: drive a running vmlab-session workflow from anywhere (needs only
HTTPS + a GitHub token in $GH_TOKEN). Every command you send is appended to
vmlab-history.txt, so a good interactive run can be turned into a scenario.

  ctl.py start [--guest haiku] [--minutes 30] [--scenario NAME] [--loadvm SNAP]   dispatch a session
  ctl.py do "shot a" "key ctrl-alt-t" ...                         run steps, fetch screenshots
  ctl.py put FILE [NAME]                                          publish a file to the guest (http://10.0.2.2:8000/NAME)
  ctl.py sh COMMAND...                                            run COMMAND through the guest agent (redox), print its output
  ctl.py stop                                                     end the session

State (session run id, command counter) lives in ./.vmlab-session.
"""
import argparse, base64, json, os, pathlib, shutil, sys, time, urllib.error, urllib.request

REPO = os.environ.get("VMLAB_REPO", "unxed/sandbox")
TOK = os.environ["GH_TOKEN"]
# Own command bus (branches <BUS>-cmd / <BUS>-out) so that sessions of different guests do not
# clobber each other; must match the "bus" input of the running session. Default = original branches.
BUS = os.environ.get("VMLAB_BUS", "vmlab")
# File extension of guest-agent jobs: ion (redox), sh (haiku, ...)
AGENT_EXT = os.environ.get("VMLAB_AGENT_EXT", "ion")
STATE = pathlib.Path(".vmlab-session")
OUT = pathlib.Path(os.environ.get("VMLAB_LOCAL_OUT", "vmlab-out"))


def api(method, path, body=None, raw=False, ok404=False):
    req = urllib.request.Request("https://api.github.com/repos/%s/%s" % (REPO, path),
                                 method=method, data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": "Bearer " + TOK,
                                          "Accept": "application/vnd.github.raw" if raw else "application/vnd.github+json"})
    try:
        with urllib.request.urlopen(req) as r:
            data = r.read()
            return data if raw else (json.loads(data) if data else {})
    except urllib.error.HTTPError as e:
        if e.code == 404 and ok404:
            return None
        raise SystemExit("API %s %s -> %s %s" % (method, path, e.code, e.read()[:300]))


def load():
    return json.loads(STATE.read_text())


def start(a):
    shutil.rmtree(OUT, ignore_errors=True)  # results of earlier sessions
    sha = api("GET", "git/ref/heads/main")["object"]["sha"]
    if api("GET", "git/ref/heads/%s-cmd" % BUS, ok404=True) is None:
        api("POST", "git/refs", {"ref": "refs/heads/%s-cmd" % BUS, "sha": sha})
    t0 = time.time()
    api("POST", "actions/workflows/vmlab-session.yml/dispatches",
        {"ref": "main", "inputs": {"guest": a.guest, "minutes": str(a.minutes), "scenario": a.scenario or "",
                    "loadvm": a.loadvm or "", "bus": BUS}})
    print("dispatched, waiting for run id ...")
    while True:
        time.sleep(3)
        runs = api("GET", "actions/workflows/vmlab-session.yml/runs?event=workflow_dispatch&per_page=3")["workflow_runs"]
        runs = [r for r in runs if time.mktime(time.strptime(r["created_at"], "%Y-%m-%dT%H:%M:%SZ")) - time.timezone >= t0 - 30]
        if runs:
            run = runs[0]
            STATE.write_text(json.dumps({"run": run["id"], "n": 0}))
            print("run", run["id"], run["html_url"])
            return


def do(a):
    st = load()
    st["n"] += 1
    n = st["n"]
    lines = [l for arg in a.steps for l in arg.split("\n")]
    with open("vmlab-history.txt", "a") as h:  # payload data is not recorded, only the fact
        h.write("\n".join(l if not l.startswith("payload ") else "# " + " ".join(l.split()[:2]) + " <data>"
                          for l in lines) + "\n")
    api("PUT", "contents/cmd/%d/%04d.txt" % (st["run"], n),
        {"message": "cmd %d" % n, "branch": "%s-cmd" % BUS,
         "content": base64.b64encode(("\n".join(lines) + "\n").encode()).decode()})
    STATE.write_text(json.dumps(st))
    t0 = time.time()
    while True:  # results of an older session may still be on the branch: wait for our own session
        cur = api("GET", "contents/SESSION?ref=vmlab-out", raw=True, ok404=True)
        if cur is not None and cur.decode().strip() == str(st["run"]):
            break
        if time.time() - t0 > a.timeout:
            raise SystemExit("session %s never published (job not started or failed?)" % st["run"])
        time.sleep(2)
    while True:
        s = api("GET", "contents/out/%04d/status?ref=%s-out" % (n, BUS), raw=True, ok404=True)
        if s is not None:
            break
        if time.time() - t0 > a.timeout:
            raise SystemExit("timeout waiting for result of command %d" % n)
        time.sleep(1.5)
    d = OUT / ("%04d" % n)
    d.mkdir(parents=True, exist_ok=True)
    for f in api("GET", "contents/out/%04d?ref=%s-out" % (n, BUS)):
        # fetch by blob sha: the sha comes from the listing, and blobs are immediately consistent
        # (a by-path GET of a fresh file can 404 for tens of seconds)
        (d / f["name"]).write_bytes(api("GET", "git/blobs/" + f["sha"], raw=True))
    print((d / "log.txt").read_text(), end="")
    print("status:", s.decode().strip(), "| %.1fs round-trip" % (time.time() - t0))
    for p in sorted(d.glob("*.png")):
        print(p.resolve())


def put(a):
    name = a.name or os.path.basename(a.file)
    a.steps = ["payload %s %s" % (name, base64.b64encode(open(a.file, "rb").read()).decode())]
    a.timeout = 120
    do(a)


def sh(a):
    """Run a command in the guest through the agent (vmlab/guests/*-agent.*; VMLAB_AGENT_EXT selects ion/sh): no typing, text output."""
    body = "# %d\n%s\n" % (time.time() * 1000, " ".join(a.command))
    a.steps = ["payload job.%s " % AGENT_EXT + base64.b64encode(body.encode()).decode(), "waitupload job.out %d" % a.guest_timeout]
    a.timeout = a.guest_timeout + 60
    do(a)
    d = OUT / ("%04d" % load()["n"])
    out = d / "upload-job.out"
    print("---- guest output ----")
    print(out.read_text(errors="replace") if out.exists() else "(none)")


def stop(a):
    a.steps, a.timeout = ["stop"], 120
    do(a)


def main():
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest="cmd", required=True)
    s = sp.add_parser("start"); s.add_argument("--guest", default="haiku"); s.add_argument("--minutes", type=int, default=30); s.add_argument("--scenario", default=""); s.add_argument("--loadvm", default="")
    d = sp.add_parser("do"); d.add_argument("steps", nargs="+"); d.add_argument("--timeout", type=int, default=300)
    u = sp.add_parser("put"); u.add_argument("file"); u.add_argument("name", nargs="?")
    r = sp.add_parser("sh"); r.add_argument("command", nargs="+"); r.add_argument("--guest-timeout", type=int, default=120)
    sp.add_parser("stop")
    a = ap.parse_args()
    {"start": start, "do": do, "stop": stop, "put": put, "sh": sh}[a.cmd](a)


if __name__ == "__main__":
    main()
