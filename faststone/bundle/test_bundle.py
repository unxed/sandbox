#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Test bootstrap isolation, concurrent extraction, corruption and offline preparation.
This needs no wineserver socket and does not replace application GUI tests.
"""
import argparse
import concurrent.futures
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def invoke(bundle, env, *args, good=True):
    p = subprocess.run([str(bundle), *args], env=env, text=True,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
    if good and p.returncode:
        raise AssertionError(f"{args}: exit={p.returncode}\n{p.stdout}\n{p.stderr}")
    if not good and not p.returncode:
        raise AssertionError(f"{args}: unexpectedly succeeded")
    return p


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("bundle", type=Path)
    p.add_argument("--archive56", type=Path)
    p.add_argument("--archive85", type=Path)
    args = p.parse_args()
    bundle = args.bundle.resolve()
    with tempfile.TemporaryDirectory(prefix="faststone bundle test ") as tmp:
        tmp = Path(tmp)
        env = dict(os.environ, FASTSTONE_CACHE_HOME=str(tmp / "shared cache"),
                   FASTSTONE_DATA_HOME=str(tmp / "private data"), HOME=str(tmp / "home"))
        env.pop("DISPLAY", None)
        env.pop("FASTSTONE_ARCHIVE", None)
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda _: invoke(bundle, env, "--self-test"), range(4)))
        assert all("Runtime loader, downloader and extractor: OK" in r.stdout for r in results)
        assert len(list((tmp / "shared cache").glob("*/.ready"))) == 1
        assert not (tmp / "home/.wine").exists()
        print("PASS: four concurrent starts; one complete runtime; no default Wine prefix")
        moved = tmp / "a different name.run"
        shutil.copy2(bundle, moved)
        assert "FastStone + patched Wine" in invoke(moved, env, "--help").stdout
        invoke(moved, env, "--wine", "--version")
        print("PASS: relocation, filename spaces and private Wine diagnostics")
        failed = invoke(bundle, env, good=False)
        assert "DISPLAY" in failed.stderr
        print("PASS: missing display fails before application download")
        for version, archive, expected in (
            ("5.6", args.archive56, "8d56e55ce519f6e178bb85837258c78a68481448f67c9c9fd251c4b7fdb9dd81"),
            ("8.5", args.archive85, "05c877e57b25c37e75b8c2a07a5f0ecc31e3b1bb8d12aeb9554c93dcde4ce621"),
        ):
            if not archive:
                continue
            prep_env = dict(env, FASTSTONE_ARCHIVE=str(archive.resolve()))
            flags = ["--prepare"] + (["--latest"] if version == "8.5" else [])
            invoke(bundle, prep_env, *flags)
            exe = tmp / "private data" / version / "app/FSViewer.exe"
            assert hashlib.sha256(exe.read_bytes()).hexdigest() == expected
            before = exe.read_bytes()
            invoke(bundle, prep_env, *flags)
            assert exe.read_bytes() == before
            print(f"PASS: offline {version} preparation and unchanged vendor executable")
        bad = tmp / "wrong.exe"
        bad.write_bytes(b"not the pinned vendor archive")
        badenv = dict(env, FASTSTONE_ARCHIVE=str(bad), FASTSTONE_DATA_HOME=str(tmp / "bad archive data"))
        invoke(bundle, badenv, "--prepare", good=False)
        assert not (tmp / "bad archive data/5.6/app").exists()
        print("PASS: wrong application archive is rejected without publishing an app")
        damaged = tmp / "corrupted.run"
        shutil.copy2(bundle, damaged)
        with damaged.open("r+b") as f:
            f.seek(-256, 2)
            parts = f.read(256).rstrip(b"\0").split()
            payload_start, payload_size = int(parts[3]), int(parts[4])
            f.seek(payload_start + payload_size // 2)
            byte = f.read(1)
            f.seek(-1, 1)
            f.write(bytes([byte[0] ^ 1]))
        broken_env = dict(env, FASTSTONE_CACHE_HOME=str(tmp / "damaged cache"))
        failed = invoke(damaged, broken_env, "--self-test", good=False)
        assert "checksum" in failed.stderr
        print("PASS: corrupted payload is rejected before extraction")


if __name__ == "__main__":
    main()
