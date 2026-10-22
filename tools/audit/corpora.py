#!/usr/bin/env python3
"""Fetches the corpora of the audit into a cache directory outside the repository.

The directory is $CORPORA, by default ~/.cache/tv3-corpora. The script writes there:
  references.txt  one code file of a reference corpus per line, relative to the directory
  allowed.txt     one allowed file per line: logical name, a tab, the path relative to the directory
A corpus that is already complete (marker file .done with the same pin) is not fetched again. Every fetch is
pinned and tried a few times on a network error. A git corpus is the tree of one commit. The file .changed is
written when something was fetched. Exit code 1 when a corpus could not be fetched.
"""
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import time

CODE_EXT = (".pas", ".pp", ".inc", ".lpr", ".dpr", ".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp")

FPC_PATHS = ["packages/fv", "packages/ide", "packages/fcl-base", "packages/rtl-objpas", "packages/fcl-passrc"]

GIT_REFERENCES = [
    ("fpc322", "https://github.com/fpc/FPCSource", "0d122c49534b480be9284c21bd60b53d99904346", FPC_PATHS),
    ("fpcmain", "https://github.com/fpc/FPCSource", "82197d8f98e073779c633fc7ef5b9592bb93016b", FPC_PATHS),
    ("fpide", "https://github.com/unxed/bp", "2d6891b9983b65a184ccba7d7e851231b820af3e", ["fpide"]),
    ("tvdelphi", "https://github.com/MikeFalcon77/turbovision-delphi", "6c6f66ad4c3e37a1daea9ae28449e11802a994b0", None),
    ("far2l", "https://github.com/elfmz/far2l", "5ec2011794fa0c781e6dde92c84c77b5ae02b25b", None),
    ("sigala", "https://github.com/benwbooth/tvision", "cb0849252a43be9d81ee8fa54519f778fad1a599", None),
    ("jserv", "https://github.com/jserv/tvision", "3537200715baf7de7c61c9ebbb639373b7a6b1ac", None),
    ("rhtv", "https://github.com/set-soft/tvision", "197ea6801a98faacb82d0456201d73c5a3ea5dfa", None),
    ("tv20", "https://github.com/FSharpCSharp/TurboVision", "b73b2ed7672df5d8f789c309076752ddee1c8adf", None),
]

ARCHIVES = [  # (name, url, sha256, kind of the archive)
    ("dn214", "https://web.archive.org/web/20220202202636if_/http://www.dnosp.com/files/dn2/dn2s214.rar",
     "4b8feadac86780f615d4b2a7847d81ad41f551c1962c9dd58b721806f36608c3", "rar"),
    ("dn151", "https://web.archive.org/web/20250406173244if_/https://download.ritlabs.com/dn/dn151src.zip",
     "d2d12bad4a040e751d5a6f4186a8caabd5ba8b3540e3dc7cab69a58a4f210440", "zip"),
    ("bp7tv", "https://web.archive.org/web/20231211134715if_/http://old-dos.ru/dl.php?id=9670",
     "1ba6251209ae4a56a4f6ce5926bff0eca815ea53a3dd5f57f779d52d1e1dc2fc", "rar"),
]

# inner archives of bp7tv: (path inside the outer archive, how to keep the files)
BP7_INNER = [
    ("BPASCAL.700/D11/TVSRC.ZIP", "all"),
    ("BPASCAL.700/D11/TVDEMO.ZIP", "all"),
    ("BPASCAL.700/D8/TVFM.ZIP", "all"),
    ("BPASCAL.700/D12/TVDEBUG.ZIP", "all"),
    ("_UPDATE_/BP_OBJEC.701/2/BP7ETC.ZIP", "etc"),
]

MAGIBLOT = [
    ("magiblot/tvision", "https://github.com/magiblot/tvision", "b4831e2ca16652db327fb7cc964f1c8c2d512524", "allowed-tvision"),
    ("magiblot/tvterm", "https://github.com/magiblot/tvterm", "210eb23564da06c358d2623388939bb02f7f3419", "allowed-tvterm"),
]
VTEXTS_URL = "https://raw.githubusercontent.com/unxed/far2l/8030902caf42498e1612e5a393ab7fc489048f51/VTExts.md"

TRIES = 4


def log(msg):
    print(msg, flush=True)


def retry(what, fn):
    last = None
    for attempt in range(1, TRIES + 1):
        try:
            return fn()
        except (subprocess.CalledProcessError, OSError, RuntimeError) as exc:
            last = exc
            log("%s: attempt %d failed: %s" % (what, attempt, exc))
            time.sleep(5 * attempt)
    raise RuntimeError("%s failed after %d attempts: %s" % (what, TRIES, last))


def run(cmd, cwd=None):
    subprocess.run(cmd, cwd=cwd, check=True, stdout=subprocess.DEVNULL)


def prune_to_code(root):
    """Removes .git and every file that is not a code file."""
    shutil.rmtree(os.path.join(root, ".git"), ignore_errors=True)
    for base, dirs, names in os.walk(root, topdown=False):
        for name in names:
            if not name.lower().endswith(CODE_EXT):
                try:
                    os.remove(os.path.join(base, name))
                except OSError:
                    pass
        for d in dirs:
            full = os.path.join(base, d)
            try:
                os.rmdir(full)
            except OSError:
                pass


def marker_ok(dest, signature):
    try:
        with open(os.path.join(dest, ".done")) as fh:
            return fh.read() == signature
    except OSError:
        return False


def write_marker(dest, signature):
    with open(os.path.join(dest, ".done"), "w") as fh:
        fh.write(signature)


def fetch_git(cache, name, url, sha, paths, dest_name, keep_all=False):
    dest = os.path.join(cache, dest_name)
    signature = "git %s %s %s\n" % (url, sha, ",".join(paths or ["*"]))
    if marker_ok(dest, signature):
        return False
    shutil.rmtree(dest, ignore_errors=True)
    os.makedirs(dest)

    def go():
        shutil.rmtree(dest, ignore_errors=True)
        os.makedirs(dest)
        run(["git", "init", "-q"], cwd=dest)
        run(["git", "remote", "add", "origin", url], cwd=dest)
        if paths:
            run(["git", "sparse-checkout", "set", "--no-cone"] + ["/" + p.strip("/") + "/" for p in paths], cwd=dest)
            run(["git", "fetch", "-q", "--depth", "1", "--filter=blob:none", "origin", sha], cwd=dest)
        else:
            run(["git", "fetch", "-q", "--depth", "1", "origin", sha], cwd=dest)
        run(["git", "-c", "advice.detachedHead=false", "checkout", "-q", "FETCH_HEAD"], cwd=dest)

    retry("fetch " + name, go)
    if keep_all:
        shutil.rmtree(os.path.join(dest, ".git"), ignore_errors=True)
    else:
        prune_to_code(dest)
    write_marker(dest, signature)
    log("fetched " + name)
    return True


def download(url, target):
    def go():
        run(["curl", "-fsSL", "--connect-timeout", "30", "--max-time", "1800", "-o", target, url])

    retry("download " + url, go)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def count_files(path):
    return sum(len(names) for _b, _d, names in os.walk(path))


def extract(archive, out, kind):
    """Extracts an archive (kind "rar" or "zip") with the first tool that works."""
    os.makedirs(out, exist_ok=True)
    tools = {
        "rar": [
            ["unrar", "x", "-y", "-inul", archive, out + "/"],
            ["bsdtar", "-xf", archive, "-C", out],
            ["7zz", "x", "-y", "-bd", "-o" + out, archive],
            ["7z", "x", "-y", "-bd", "-o" + out, archive],
        ],
        "zip": [
            ["7z", "x", "-y", "-bd", "-o" + out, archive],
            ["7zz", "x", "-y", "-bd", "-o" + out, archive],
            ["unzip", "-q", "-o", archive, "-d", out],
            ["bsdtar", "-xf", archive, "-C", out],
        ],
    }[kind]
    for cmd in tools:
        if shutil.which(cmd[0]) is None:
            continue
        res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if res.returncode in (0, 1) or (res.returncode == 2 and count_files(out) > 0):
            return True
        log("extraction with %s failed (exit code %d)" % (cmd[0], res.returncode))
    raise RuntimeError("cannot extract " + archive)


def find_inner(root, wanted):
    """Finds a file by its path inside an extracted archive, in any letter case."""
    wanted = wanted.lower()
    for base, _dirs, names in os.walk(root):
        for name in names:
            full = os.path.join(base, name)
            rel = os.path.relpath(full, root).replace(os.sep, "/").lower()
            if rel == wanted or rel.endswith("/" + wanted):
                return full
    return None


def fetch_archive(cache, name, url, sha, kind):
    dest = os.path.join(cache, name)
    signature = "archive %s %s\n" % (url, sha)
    if marker_ok(dest, signature):
        return False
    shutil.rmtree(dest, ignore_errors=True)
    os.makedirs(dest)
    work = tempfile.mkdtemp(prefix=name + "-", dir=cache)
    try:
        archive = os.path.join(work, "archive")

        def go():
            download(url, archive)
            got = sha256_file(archive)
            if got != sha:
                raise RuntimeError("SHA-256 of %s is %s, expected %s" % (name, got, sha))

        retry("fetch " + name, go)
        if name == "bp7tv":
            outer = os.path.join(work, "outer")
            extract(archive, outer, kind)
            for inner, mode in BP7_INNER:
                zpath = find_inner(outer, inner)
                if zpath is None:
                    raise RuntimeError("%s: no %s in the archive" % (name, inner))
                tmp = os.path.join(work, "inner-" + os.path.basename(inner).lower())
                extract(zpath, tmp, "zip")
                target = os.path.join(dest, os.path.basename(inner).lower().replace(".zip", ""))
                for base, _dirs, names in os.walk(tmp):
                    for fn in names:
                        full = os.path.join(base, fn)
                        rel = os.path.relpath(full, tmp).replace(os.sep, "/")
                        low = rel.lower()
                        if not low.endswith(".pas"):
                            continue
                        if mode == "etc" and not (low.startswith("rtl/tv/") or low == "rtl/common/objects.pas"):
                            continue
                        out = os.path.join(target, rel)
                        os.makedirs(os.path.dirname(out), exist_ok=True)
                        shutil.copyfile(full, out)
        else:
            extract(archive, dest, kind)
            prune_to_code(dest)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    write_marker(dest, signature)
    log("fetched " + name)
    return True


def fetch_vtexts(cache):
    dest = os.path.join(cache, "allowed-far2l")
    signature = "file %s\n" % VTEXTS_URL
    if marker_ok(dest, signature):
        return False
    shutil.rmtree(dest, ignore_errors=True)
    os.makedirs(dest)
    download(VTEXTS_URL, os.path.join(dest, "VTExts.md"))
    write_marker(dest, signature)
    log("fetched VTExts.md")
    return True


def walk_files(cache, sub, exts=None):
    root = os.path.join(cache, sub)
    found = []
    for base, _dirs, names in os.walk(root):
        for name in names:
            if name == ".done":
                continue
            if exts is None or name.lower().endswith(exts):
                full = os.path.join(base, name)
                found.append(os.path.relpath(full, cache).replace(os.sep, "/"))
    return sorted(found)


def main():
    cache = os.environ.get("CORPORA") or os.path.expanduser("~/.cache/tv3-corpora")
    os.makedirs(cache, exist_ok=True)
    changed_flag = os.path.join(cache, ".changed")
    if os.path.exists(changed_flag):
        os.remove(changed_flag)
    failed = []
    changed = False

    def attempt(name, fn):
        nonlocal changed
        try:
            if fn():
                changed = True
        except (RuntimeError, OSError, subprocess.CalledProcessError) as exc:
            log("FAILED %s: %s" % (name, exc))
            failed.append(name)

    for name, url, sha, paths in GIT_REFERENCES:
        attempt(name, lambda name=name, url=url, sha=sha, paths=paths: fetch_git(cache, name, url, sha, paths, name))
    for name, url, sha, kind in ARCHIVES:
        attempt(name, lambda name=name, url=url, sha=sha, kind=kind: fetch_archive(cache, name, url, sha, kind))
    for name, url, sha, dest in MAGIBLOT:
        attempt(name, lambda name=name, url=url, sha=sha, dest=dest:
                fetch_git(cache, name, url, sha, ["include", "source"], dest, keep_all=True))
    attempt("VTExts.md", lambda: fetch_vtexts(cache))

    refs = []
    for name in [g[0] for g in GIT_REFERENCES] + [a[0] for a in ARCHIVES]:
        refs.extend(walk_files(cache, name, CODE_EXT))
    with open(os.path.join(cache, "references.txt"), "w", encoding="utf-8") as fh:
        fh.write("".join(r + "\n" for r in refs))
    allowed = []
    for logical, _url, _sha, dest in [(m[0], m[1], m[2], m[3]) for m in MAGIBLOT]:
        prefix = dest + "/"
        for rel in walk_files(cache, dest):
            allowed.append((logical + ":" + rel[len(prefix):], rel))
    for rel in walk_files(cache, "allowed-far2l"):
        allowed.append(("unxed/far2l:" + rel[len("allowed-far2l/"):], rel))
    with open(os.path.join(cache, "allowed.txt"), "w", encoding="utf-8") as fh:
        fh.write("".join("%s\t%s\n" % a for a in allowed))
    if changed:
        with open(changed_flag, "w") as fh:
            fh.write("changed\n")
    for name in [g[0] for g in GIT_REFERENCES] + [a[0] for a in ARCHIVES]:
        log("corpus %s: %d code files" % (name, sum(1 for r in refs if r.startswith(name + "/"))))
    log("references: %d, allowed: %d" % (len(refs), len(allowed)))
    if failed:
        log("NOT FETCHED: " + ", ".join(failed))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
