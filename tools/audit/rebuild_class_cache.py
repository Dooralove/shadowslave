#!/usr/bin/env python3
"""Rebuild Godot's global_script_class_cache.cfg from class_name declarations.

Godot normally regenerates this file during editor import. In this workspace the
editor is kept open and `--import` can block on the autoload scan, so this tool
provides a deterministic fallback. It only writes `.godot/global_script_class_cache.cfg`.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / ".godot" / "global_script_class_cache.cfg"
SKIP_DIRS = {".git", ".godot", "build", "experiments", "incoming_models"}

CLASS_RE = re.compile(r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
EXTENDS_RE = re.compile(r"^extends\s+([^\s#]+)", re.M)
TOOL_RE = re.compile(r"^@tool\b", re.M)


def iter_scripts() -> list[Path]:
    result: list[Path] = []
    for path in ROOT.rglob("*.gd"):
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        result.append(path)
    return sorted(result)


def main() -> None:
    scripts = iter_scripts()
    path_to_class: dict[str, str] = {}
    parsed: list[dict[str, object]] = []
    for path in scripts:
        text = path.read_text(encoding="utf-8", errors="replace")
        match = CLASS_RE.search(text)
        if not match:
            continue
        class_name = match.group(1)
        rel = path.relative_to(ROOT).as_posix()
        path_to_class[rel] = class_name
        extends = EXTENDS_RE.search(text)
        base = extends.group(1) if extends else "RefCounted"
        base = base.strip().strip('"')
        if base.startswith("res://"):
            base = path_to_class.get(base.removeprefix("res://"), "RefCounted")
        parsed.append(
            {
                "class": class_name,
                "base": base,
                "path": f"res://{rel}",
                "tool": bool(TOOL_RE.search(text)),
            }
        )

    # Stable order makes diffs readable and mirrors Godot's sorted cache.
    parsed.sort(key=lambda item: str(item["class"]).lower())
    chunks: list[str] = []
    for item in parsed:
        chunks.append(
            "{\n"
            f'"base": &"{item["base"]}",\n'
            f'"class": &"{item["class"]}",\n'
            '"icon": "",\n'
            '"is_abstract": false,\n'
            f'"is_tool": {str(bool(item["tool"])).lower()},\n'
            '"language": &"GDScript",\n'
            f'"path": "{item["path"]}"\n'
            "}"
        )
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("list=[" + ", ".join(chunks) + "]\n", encoding="utf-8")
    print(f"class_cache: {len(parsed)} classes -> {OUT}")


if __name__ == "__main__":
    main()
