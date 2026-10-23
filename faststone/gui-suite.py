#!/usr/bin/env python3
"""FastStone GUI tests with separate application copies, prefixes and displays.

Generate the synthetic JPEG/EXIF fixtures with --fixtures-only DIR before
copying to a minimal guest. Pillow is needed only for fixture generation.
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import sys
import time

SCENARIOS = ("edges", "top", "navigation", "zoom", "pan-select", "shift-zoom", "magnifier", "right-hold",
             "transforms", "crop", "resize", "draw", "copy", "move",
             "slideshow", "comment", "histogram", "save-as", "settings", "properties")


def fixtures(destination):
    from PIL import Image, ImageDraw
    destination.mkdir(parents=True, exist_ok=True)
    palette = ((230, 40, 35), (30, 190, 70), (25, 65, 230),
               (230, 180, 20), (180, 30, 210), (20, 190, 200))
    for index in range(164):
        w, h = (1800, 1200) if index == 0 else (800, 600)
        image = Image.new("RGB", (w, h), palette[index % len(palette)])
        draw = ImageDraw.Draw(image)
        for tile in range(12):
            x = tile * w // 12
            draw.rectangle((x, h // 3, (tile + 1) * w // 12, h * 2 // 3),
                           fill=palette[(index + tile + 1) % len(palette)])
            draw.line((x, 0, x, h), fill=(15, 15, 15), width=3)
        draw.rectangle((w // 8, h // 8, w // 4, h // 4), fill="white")
        draw.text((w // 8 + 8, h // 8 + 8), f"FRAME {index:03d}", fill="black")
        exif = Image.Exif()
        exif[271] = "FastStone Wine Test"
        exif[272] = "Synthetic fixture"
        exif[305] = "gui-suite.py"
        exif[306] = "2026:10:23 00:00:00"
        exif[270] = f"Synthetic image {index:03d}; no personal metadata"
        exif[274] = 1
        image.save(destination / f"image-{index:03d}.jpg", quality=87, exif=exif)
    formats = destination / "formats"
    formats.mkdir(exist_ok=True)
    image = Image.new("RGBA", (640, 480), (20, 170, 210, 120))
    ImageDraw.Draw(image).rectangle((40, 40, 300, 300), fill=(220, 30, 170, 255))
    image.save(formats / "alpha.png")
    image.convert("RGB").save(formats / "bitmap.bmp")
    image.convert("RGB").save(formats / "multipage.tiff", save_all=True,
                              append_images=[image.convert("RGB").transpose(Image.Transpose.ROTATE_90)])
    image.convert("RGB").save(formats / "webp.webp", lossless=True)
    image.convert("RGB").save(formats / "Картинка-测试.jpg", quality=90)
    manifest = {"count": 164, "primary": "image-000.jpg", "dimensions": [1800, 1200],
                "generator": "gui-suite.py", "exif_make": "FastStone Wine Test"}
    (destination / "fixtures.json").write_text(json.dumps(manifest, indent=2) + "\n")


def winepath(path):
    return "Z:" + str(path.resolve()).replace("/", "\\")


def logged(command, environment, output, timeout):
    with output.open("wb") as f:
        process = subprocess.Popen(command, env=environment, stdout=f, stderr=subprocess.STDOUT)
        try:
            return process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            return 124


def run_job(version, app, scenario, plan, args):
    root = args.results / (version + "-" + scenario)
    root.mkdir(parents=True, exist_ok=False)
    artifacts = root / "artifacts"
    artifacts.mkdir()
    shutil.copytree(app.parent, root / "app")
    shutil.copytree(args.fixtures, root / "images")
    (root / "runtime").mkdir(mode=0o700)
    env = os.environ.copy()
    env.update(WINEPREFIX=str(root / "prefix"), WINEDEBUG="-all",
               WINEDLLOVERRIDES="mscoree,mshtml=;winemenubuilder.exe=d",
               XDG_RUNTIME_DIR=str(root / "runtime"))
    if args.wineserver:
        env["WINESERVER"] = str(args.wineserver)
    start = time.monotonic()
    result = {"version": version, "scenario": scenario, "artifacts": str(artifacts),
              "input_source": args.input_source}
    status, xvfb = "error", None
    with (root / "xvfb.log").open("wb") as xlog:
        try:
            xvfb = subprocess.Popen([args.xvfb, "-displayfd", "1", "-screen", "0", args.screen,
                                     "-nolisten", "tcp", "-ac"], stdout=subprocess.PIPE, stderr=xlog)
            with selectors.DefaultSelector() as selector:
                selector.register(xvfb.stdout, selectors.EVENT_READ)
                if not selector.select(min(args.timeout, 30)):
                    raise RuntimeError("Xvfb startup timed out; inspect xvfb.log")
            number = xvfb.stdout.readline().decode("ascii").strip()
            if not number.isdigit():
                raise RuntimeError("Xvfb did not allocate a display")
            env["DISPLAY"] = ":" + number
            boot = logged([str(args.wine), "wineboot.exe", "-u"], env, root / "wineboot.log", args.timeout)
            if boot:
                raise RuntimeError(f"wineboot failed: {boot}; inspect wineboot.log")
            command = [str(args.wine), str(args.driver), "--app", winepath(root / "app" / app.name),
                       "--image", winepath(root / "images" / "image-000.jpg"),
                       "--out", winepath(artifacts), "--scenario", scenario,
                       "--timeout-ms", str(args.timeout * 1000 // 2)]
            if plan:
                shutil.copyfile(plan, root / "plan.tsv")
                result["plan_sha256"] = hashlib.sha256((root / "plan.tsv").read_bytes()).hexdigest()
                command += ["--plan", winepath(root / "plan.tsv")]
            if args.input_source == "x11":
                command = [str(args.bridge), *command, "--external-input"]
            code = logged(command, env, root / "driver.log", args.timeout)
            events = []
            path = artifacts / "assertions.jsonl"
            if path.exists():
                events = [json.loads(line) for line in path.read_text().splitlines() if line]
            summary = next((e for e in reversed(events) if e.get("event") == "summary"), None)
            result.update(exit_code=code, summary=summary, skips=[e for e in events if e.get("event") == "skip"])
            status = "passed" if code == 0 and summary and summary["failures"] == 0 else "failed"
        except Exception as error:
            result["error"] = str(error)
        finally:
            try:
                subprocess.run([str(args.wineserver or "wineserver"), "-k"], env=env,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
            except (OSError, subprocess.TimeoutExpired):
                pass
            if xvfb:
                xvfb.terminate()
                try:
                    xvfb.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    xvfb.kill()
                    xvfb.wait()
    result.update(status=status, seconds=round(time.monotonic() - start, 2))
    (root / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"{status.upper():6} {version:4} {scenario:20} {result['seconds']:7.2f}s", flush=True)
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--fixtures-only", type=Path)
    p.add_argument("--wine", type=Path)
    p.add_argument("--wineserver", type=Path)
    p.add_argument("--driver", type=Path, default=Path(__file__).with_suffix(".exe"))
    p.add_argument("--bridge", type=Path, default=Path(__file__).with_name("gui-suite-x11-bridge"))
    p.add_argument("--version", action="append", default=[], metavar="VERSION=/PATH/FSViewer.exe")
    p.add_argument("--scenario", choices=SCENARIOS, action="append")
    p.add_argument("--plan", action="append", default=[], metavar="[VERSION:]NAME=/PATH/observed-plan.tsv")
    p.add_argument("--fixtures", type=Path)
    p.add_argument("--results", type=Path)
    p.add_argument("--jobs", type=int, default=4)
    p.add_argument("--timeout", type=int, default=240)
    p.add_argument("--xvfb", default="Xvfb")
    p.add_argument("--screen", default="1280x800x24")
    p.add_argument("--input-source", choices=("win32", "x11"), default="x11")
    args = p.parse_args()
    if args.fixtures_only:
        fixtures(args.fixtures_only.resolve())
        return 0
    if not args.wine or not args.version or not args.results or args.jobs < 1:
        p.error("--wine, --version and --results are required; --jobs must be positive")
    for name in ("wine", "driver", "bridge", "results", "wineserver"):
        if getattr(args, name):
            setattr(args, name, getattr(args, name).resolve())
    args.results.mkdir(parents=True, exist_ok=True)
    if args.fixtures:
        args.fixtures = args.fixtures.resolve()
    else:
        args.fixtures = args.results / "fixtures"
        fixtures(args.fixtures)
    versions, plans = [], []
    for spec in args.version:
        version, sep, app = spec.partition("=")
        if not sep or not version or any(c not in "0123456789.-_" for c in version):
            p.error("--version must be VERSION=/PATH/FSViewer.exe")
        app = Path(app).resolve()
        if not app.is_file():
            p.error(f"application does not exist: {app}")
        if any(existing == version for existing, _ in versions):
            p.error(f"duplicate application version: {version}")
        if args.results == app.parent or app.parent in args.results.parents:
            p.error("results must be outside the application directory")
        versions.append((version, app))
    for spec in args.plan:
        name, sep, path = spec.partition("=")
        only_version, colon, short_name = name.partition(":")
        if colon:
            name = short_name
            if only_version not in {version for version, _ in versions}:
                p.error(f"plan targets an unselected version: {only_version}")
        else:
            only_version = None
        if not sep or not name or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789-_" for c in name):
            p.error("--plan must be [VERSION:]NAME=/PATH/plan.tsv with a simple ASCII name")
        path = Path(path).resolve()
        if not path.is_file():
            p.error(f"plan does not exist: {path}")
        plans.append((only_version, "e2e-" + name, path))
    scenarios = args.scenario or (() if plans else SCENARIOS)
    if len(set(scenarios)) != len(scenarios):
        p.error("duplicate scenarios would overwrite a job directory")
    jobs = [(v, app, scenario, None) for v, app in versions for scenario in scenarios]
    jobs += [(v, app, name, plan) for v, app in versions
             for only_version, name, plan in plans if only_version is None or only_version == v]
    keys = [(version, scenario) for version, _, scenario, _ in jobs]
    if len(set(keys)) != len(keys):
        p.error("duplicate plan names target the same application version")
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = [pool.submit(run_job, *job, args) for job in jobs]
        for future in concurrent.futures.as_completed(futures):
            results.append(future.result())
    results.sort(key=lambda r: (r["version"], r["scenario"]))
    summary = {"jobs": args.jobs, "screen": args.screen, "input_source": args.input_source,
               "results": results, "passed": sum(r["status"] == "passed" for r in results),
               "failed": sum(r["status"] != "passed" for r in results)}
    (args.results / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    return bool(summary["failed"])


if __name__ == "__main__":
    sys.exit(main())
