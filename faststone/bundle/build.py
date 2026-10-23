#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Create a static ELF .run containing an installed Wine runtime, never FastStone.

Use a completed make-install DESTDIR and its matching source/config.h.
"""
import argparse
import glob
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tarfile
import tempfile

HERE = Path(__file__).resolve().parent
TRAILER_BYTES = 256
INTERPRETER = "/" + "F" * 510
EXCLUDED_SONAMES = {"libodbc.so"}  # Optional database provider, unused by image viewing.


def run(*args, **kwargs):
    return subprocess.run([str(a) for a in args], check=True, **kwargs)


def output(*args):
    return subprocess.check_output([str(a) for a in args], text=True)


def is_elf(path):
    try:
        with open(path, "rb") as f:
            return f.read(4) == b"\x7fELF"
    except OSError:
        return False


def dependencies(path, runtime):
    # ldd is used only on trusted, locally built/runtime package binaries.
    wine_unix = [runtime / "wine/lib/wine/x86_64-unix", runtime / "wine/lib64/wine/x86_64-unix"]
    env = dict(os.environ, LD_LIBRARY_PATH=":".join(str(p) for p in wine_unix))
    p = subprocess.run(["ldd", str(path)], text=True, capture_output=True, env=env)
    text = p.stderr + p.stdout
    if p.returncode and ("not a dynamic executable" in text or "statically linked" in text):
        return []
    if p.returncode or "not found" in p.stdout:
        raise RuntimeError(f"ldd failed for {path}: {text}")
    return [Path(name) for name in re.findall(r"(?:=>\s+)?(/[^\s]+)\s+\(", p.stdout)]


def library_map():
    result = {}
    for line in output("ldconfig", "-p").splitlines():
        m = re.match(r"\s*(\S+)\s+\([^)]*x86-64[^)]*\)\s+=>\s+(\S+)", line)
        if m:
            result.setdefault(m[1], Path(m[2]))
    for directory in ("/lib/x86_64-linux-gnu", "/usr/lib/x86_64-linux-gnu"):
        for path in Path(directory).glob("*.so*"):
            if path.is_file():
                result.setdefault(path.name, path)
    return result


def copy_real(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source.resolve(), destination)


def copy_wine(prefix, destination, omitted_unix):
    for name in ("lib/wine", "lib64/wine", "share/wine"):
        source = prefix / name
        if source.exists():
            for link in source.rglob("*"):
                if link.is_symlink() and not link.resolve().is_relative_to(prefix.resolve()):
                    raise RuntimeError(f"Wine install symlink escapes prefix: {link}")
            def ignore(directory, names):
                # Import archives are development files, never runtime libraries.
                ignored = [entry for entry in names if entry.endswith(".a")]
                if Path(directory).name in ("x86_64-unix", "i386-unix"):
                    ignored += [entry for entry in names if entry in omitted_unix]
                return ignored
            shutil.copytree(source, destination / name, symlinks=True, ignore=ignore)
    for name in ("wine", "wine64", "wineserver", "wine-preloader", "wine64-preloader"):
        source = prefix / "bin" / name
        if source.exists():
            copy_real(source, destination / "bin" / name)
    if not (destination / "bin/wine").is_file():
        raise RuntimeError("the installed prefix has no bin/wine")


def build(args):
    destination = args.output.resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    prefix = args.wine_prefix.resolve()
    if not prefix.is_dir():
        raise RuntimeError(f"not an installed Wine prefix: {prefix}")
    with tempfile.TemporaryDirectory(prefix="fswine-build-") as tmp:
        tmp = Path(tmp)
        root = tmp / "runtime"
        root.mkdir()
        copy_wine(prefix, root / "wine", set(args.omit_unix_module))
        for name in ("bin", "lib", "licenses"):
            (root / name).mkdir(exist_ok=True)
        copy_real(args.busybox, root / "bin/busybox")
        for name, source in (("curl", args.curl), ("7z", args.sevenzip), ("flock", args.flock)):
            copy_real(source, root / "bin" / name)
        plugin = args.sevenzip.resolve().with_name("7z.so")
        if plugin.exists():
            copy_real(plugin, root / "bin/7z.so")
        shutil.copy2(HERE / "launch.sh", root / "launch.sh")
        # Independently generated marker bitmap, not copied from FastStone.
        marker = struct.pack("<2sIHHI", b"BM", 454, 0, 0, 54)
        marker += struct.pack("<IiiHHIIiiII", 40, 10, 10, 1, 32, 0, 400, 0, 0, 0, 0)
        marker += bytes((255, 255, 255, 255)) * 100
        (root / "portable-marker.bmp").write_bytes(marker)
        libraries = library_map()
        requested = set(re.findall(r'^#define SONAME_\w+ "([^"]+)"', args.config.read_text(), re.MULTILINE)) - EXCLUDED_SONAMES
        missing = requested - libraries.keys()
        if missing:
            raise RuntimeError(f"configured dlopen libraries are missing: {sorted(missing)}")
        queue = [p for p in root.rglob("*") if p.is_file() and is_elf(p)]
        queue += [libraries[name] for name in sorted(requested)]
        queue += [Path(p) for p in glob.glob("/lib/x86_64-linux-gnu/libnss_*.so.2")]
        seen, recorded = set(), {}
        while queue:
            path = queue.pop()
            identity = str(path.resolve())
            if identity in seen:
                continue
            seen.add(identity)
            queue.extend(dependencies(path, root))
            if not path.is_relative_to(root):
                dest = root / "lib" / path.name
                if dest.exists() and hashlib.sha256(dest.read_bytes()).digest() != hashlib.sha256(path.read_bytes()).digest():
                    raise RuntimeError(f"library basename collision: {path}")
                copy_real(path, dest)
                recorded[path.name] = str(path.resolve())
        copy_real(Path("/lib64/ld-linux-x86-64.so.2"), root / "lib/ld-linux-x86-64.so.2")
        gconv = Path("/usr/lib/x86_64-linux-gnu/gconv")
        if gconv.is_dir():
            shutil.copytree(gconv, root / "lib/gconv", symlinks=False)
        interpreters = []
        for path in root.rglob("*"):
            if path.is_symlink() or not path.is_file():
                continue
            if is_elf(path):
                if not args.no_strip:
                    run("strip", "--strip-debug", path, stdout=subprocess.DEVNULL)
                dynamic = subprocess.run([str(args.patchelf), "--print-needed", str(path)], text=True, capture_output=True)
                if dynamic.returncode == 0 and path.name != "ld-linux-x86-64.so.2":
                    relative = os.path.relpath(root / "lib", path.parent)
                    search = "$ORIGIN" if relative == "." else "$ORIGIN:$ORIGIN/" + relative
                    # DT_RPATH, unlike DT_RUNPATH, covers transitive dependencies.
                    # Every dependency also receives its own relative search path.
                    run(args.patchelf, "--force-rpath", "--set-rpath", search, path)
                p = subprocess.run([str(args.patchelf), "--print-interpreter", str(path)], text=True, capture_output=True)
                if p.returncode == 0 and p.stdout.strip():
                    run(args.patchelf, "--set-interpreter", INTERPRETER, path)
                    interpreters.append(path.relative_to(root).as_posix())
            elif path.suffix.lower() in (".dll", ".exe") and not args.no_strip:
                run(args.pe_strip, "--strip-debug", path, stdout=subprocess.DEVNULL)
        (root / "elf-interpreters.txt").write_text("\n".join(sorted(interpreters)) + "\n")
        (root / "runtime.json").write_text(json.dumps({
            "format": 1, "wine_revision": args.wine_revision, "architecture": "linux-x86_64",
            "wine_architectures": ["i386", "x86_64"], "applications_embedded": False,
            "configuration_header_sha256": hashlib.sha256(args.config.read_bytes()).hexdigest(),
            "configured_dlopen_libraries": sorted(requested), "excluded_optional_sonames": sorted(EXCLUDED_SONAMES),
            "bundled_libraries": recorded,
            "elf_library_search": "relative-DT_RPATH-on-each-object",
            "injected_environment_code_paths": False,
            "omitted_unix_modules": sorted(set(args.omit_unix_module)),
            "prebuilt_provenance": json.loads(args.provenance.read_text()) if args.provenance else None,
        }, indent=2) + "\n")
        sources = set(recorded.values()) | {str(args.curl.resolve()), str(args.sevenzip.resolve()), str(args.flock.resolve()), str(args.busybox.resolve())}
        packages = set()
        for source in sorted(sources):
            p = subprocess.run(["dpkg-query", "-S", source], text=True, capture_output=True)
            if p.returncode == 0:
                for line in p.stdout.splitlines():
                    packages.add(line.split(": ", 1)[0].split(":", 1)[0])
        for package in packages:
            notice = Path("/usr/share/doc") / package / "copyright"
            if notice.exists():
                copy_real(notice, root / "licenses" / (package + ".copyright"))
        for name in ("COPYING.LIB", "LICENSE", "AUTHORS"):
            notice = args.wine_source / name
            if notice.exists():
                copy_real(notice, root / "licenses" / ("wine-" + name))
        notice = args.busybox.resolve().parents[1] / "share/doc/busybox-static/copyright"
        if notice.exists():
            copy_real(notice, root / "licenses/busybox-static.copyright")
        for name in ("bootstrap.c", "launch.sh", "build.py", "LICENSE"):
            copy_real(HERE / name, root / "bundle-source" / name)
        versions = []
        for package in sorted(packages):
            p = subprocess.run(["dpkg-query", "-W", "-f", "${binary:Package}\t${Version}\t${source:Package}\t${source:Version}\n", package], text=True, capture_output=True)
            if p.returncode == 0:
                versions.append(p.stdout)
        (root / "licenses/runtime-packages.tsv").write_text("".join(versions))
        (root / "licenses/README.txt").write_text(
            "Wine is LGPL-2.1-or-later. Preserve notices and supply exact Wine source and patches\n"
            "when redistributing. Other bundled libraries have their own notices here. Provide\n"
            "corresponding sources/build information required by those licenses. FastStone is\n"
            "downloaded separately and is not included.\n")
        archive = tmp / "payload.tar.gz"
        with tarfile.open(archive, "w:gz", compresslevel=6) as tar:
            for path in sorted(root.iterdir()):
                tar.add(path, arcname=path.name)
        payload_hash = hashlib.sha256(archive.read_bytes()).hexdigest()
        stub = tmp / "bootstrap"
        run(args.cc, "-Os", "-static", "-Wall", "-Wextra", "-Werror", "-s", "-o", stub, HERE / "bootstrap.c")
        stub_size, busy_size, payload_size = stub.stat().st_size, args.busybox.stat().st_size, archive.stat().st_size
        trailer = f"FSWINE-BUNDLE-1 {stub_size} {busy_size} {stub_size+busy_size} {payload_size} {payload_hash}\n".encode()
        if len(trailer) > TRAILER_BYTES:
            raise RuntimeError("payload trailer is too large")
        partial = destination.with_suffix(destination.suffix + ".part")
        with partial.open("wb") as f:
            for source in (stub, args.busybox, archive):
                with source.open("rb") as inp:
                    shutil.copyfileobj(inp, f)
            f.write(trailer.ljust(TRAILER_BYTES, b"\0"))
        partial.chmod(0o755)
        partial.replace(destination)
        print(json.dumps({"output": str(destination), "size": destination.stat().st_size,
                          "sha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
                          "payload_sha256": payload_hash, "library_count": len(recorded),
                          "interpreter_count": len(interpreters)}, indent=2))


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--wine-prefix", type=Path, required=True)
    p.add_argument("--wine-source", type=Path, required=True)
    p.add_argument("--config", type=Path, required=True)
    p.add_argument("--wine-revision", required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--busybox", type=Path, required=True)
    p.add_argument("--patchelf", type=Path, required=True)
    p.add_argument("--curl", type=Path, default=Path("/usr/bin/curl"))
    p.add_argument("--sevenzip", type=Path, default=Path("/usr/lib/7zip/7z"))
    p.add_argument("--flock", type=Path, default=Path("/usr/bin/flock"))
    p.add_argument("--cc", default="gcc")
    p.add_argument("--pe-strip", default="x86_64-w64-mingw32-strip")
    p.add_argument("--no-strip", action="store_true")
    p.add_argument("--omit-unix-module", action="append", default=[],
                   help="Explicit optional Unix provider filename to leave out; record in metadata")
    p.add_argument("--provenance", type=Path,
                   help="JSON describing a third-party baseline runtime, when used")
    build(p.parse_args())
