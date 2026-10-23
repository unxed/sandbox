#!/usr/bin/env python3
"""Compare public label geometry against a verified native cc580 probe run.

Native comctl32 hosted by Wine is a control-library reference, not a claim
that an entire native Windows environment was tested. The default is discovery;
--strict turns observed differences into a failing regression check.
"""
import argparse
import json
from pathlib import Path
import re
import sys


def records(path):
    result = {}
    for number, line in enumerate(Path(path).read_text().splitlines(), 1):
        if not line.strip():
            continue
        item = json.loads(line)
        key = tuple(item[k] for k in ("view", "api", "font", "images", "text", "focus"))
        if key in result:
            raise ValueError(f"{path}:{number}: duplicate record {key}")
        result[key] = item
    if not result:
        raise ValueError(f"{path}: no measurement records")
    return result


def fields(item):
    icon = item["icon"]
    result = {name: item[name] for name in ("font_height", "space_size", "hit_item", "hit_flags", "has_focus")}
    for name in ("label", "selection", "bounds"):
        rect = item[name]
        result[name + "_size"] = [rect[2] - rect[0], rect[3] - rect[1]]
        result[name + "_relative_to_icon"] = [rect[0] - icon[0], rect[1] - icon[1], rect[2] - icon[0], rect[3] - icon[1]]
    if item["text"] in ("empty", "null", "callback-empty", "callback-null"):
        result["highlight_pixels"] = item["highlight_pixels"]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("native_records")
    parser.add_argument("actual_records")
    parser.add_argument("--native-log", required=True)
    parser.add_argument("--output")
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()
    log = Path(args.native_log).read_text(errors="replace")
    if not re.search(r"^comctl32=5\.80\.\d+\s*$", log, re.M):
        raise ValueError("Reference refused: native cc580 5.80 version not established")
    module = re.search(r"^comctl32_module=(.+)$", log, re.M)
    cls = re.search(r"^listview_class_module=(.+?) listview_proc_module=(.*)$", log, re.M)
    summary = re.search(r"^RESULT records=(\d+) failures=0 mode=measure-only\s*$", log, re.M)
    if not module or not cls or not summary or module[1].strip().lower() != cls[1].strip().lower():
        raise ValueError("Reference refused: loaded DLL/class identity or successful probe completion not established")
    native, actual = records(args.native_records), records(args.actual_records)
    if native.keys() != actual.keys():
        raise ValueError("Reference and actual runs cover different cases")
    if len(native) != int(summary[1]):
        raise ValueError("Reference JSON record count does not match its completion log")
    differences = []
    for key in native:
        want, got = fields(native[key]), fields(actual[key])
        changed = {name: {"native": value, "actual": got[name]} for name, value in want.items() if got[name] != value}
        if changed:
            differences.append({"case": dict(zip(("view", "api", "font", "images", "text", "focus"), key)), "differences": changed})
    report = {"reference_kind": "native comctl32 5.80 hosted by Wine", "reference_module": module[1].strip(),
              "reference_class_module": cls[1].strip(), "reference_proc_module": cls[2].strip(),
              "records": len(native), "different_records": len(differences), "differences": differences}
    encoded = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        Path(args.output).write_text(encoded)
        print(f"records={len(native)} different_records={len(differences)} output={args.output}")
    else:
        print(encoded, end="")
    return 1 if args.strict and differences else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(2)
