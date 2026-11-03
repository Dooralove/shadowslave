#!/usr/bin/env python3
"""Fail if an equipment texture is still a Git LFS pointer, not a real image.

Usage:
  python tools/audit/check_equipment_lfs.py
  # or from PowerShell:
  py tools/audit/check_equipment_lfs.py
"""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
EQUIPMENT = ROOT / "assets" / "characters" / "equipment"
POINTER = b"version https://git-lfs.github.com/spec/v1"


def main() -> int:
    broken: list[pathlib.Path] = []
    for path in EQUIPMENT.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in {".png", ".jpg", ".jpeg"}:
            continue
        try:
            head = path.read_bytes()[:96]
        except OSError as exc:
            print(f"cannot read {path}: {exc}", file=sys.stderr)
            broken.append(path)
            continue
        if POINTER in head:
            broken.append(path)
    if broken:
        print("LFS texture pointers found; run:")
        print("  git lfs install")
        print("  git lfs pull")
        print("  git lfs checkout")
        for path in broken:
            print(" -", path.relative_to(ROOT))
        return 1
    print("equipment textures are materialized (no LFS pointers)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
