#!/usr/bin/env python3
"""Build the P2 real-world contact sheet from read-only Godot captures."""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

TILE = (640, 360)
BG = (12, 14, 18)
FG = (232, 236, 242)
MUTED = (160, 170, 184)
FONT = Path("C:/Windows/Fonts/segoeui.ttf")


def font(size: int):
    try:
        return ImageFont.truetype(str(FONT), size)
    except OSError:
        return ImageFont.load_default()


def tile(path: Path, label: str, sub: str) -> Image.Image:
    image = ImageOps.fit(Image.open(path).convert("RGB"), TILE, method=Image.Resampling.LANCZOS)
    draw = ImageDraw.Draw(image, "RGBA")
    draw.rectangle((0, 0, TILE[0], 48), fill=(0, 0, 0, 160))
    draw.text((14, 6), label, font=font(20), fill=FG)
    draw.text((14, 29), sub, font=font(14), fill=MUTED)
    return image


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()
    raw, out = args.raw, args.out
    out.mkdir(parents=True, exist_ok=True)

    items = [
        ("p1_scene_park_street_art.png", "PARK · MORNING", "HDRI sky, facades, island trees, wet pavement"),
        ("p1_scene_station_lobby_art.png", "LOBBY · NORMAL", "strong counter, lockers, ducts, markings"),
        ("p1_scene_station_lobby_art_alarm.png", "LOBBY · CODE BLACK", "red alarm state, stronger counter light"),
        ("containment_sunny_pose.png", "ISOLATION · POSE", "Sunny seated, straps, hard top light"),
        ("containment_sunny_wide.png", "ISOLATION · WIDE", "wet floor, drain, observation wall"),
        ("p1_scene_containment_room_art.png", "ISOLATION · ROOM", "room without player, wet/reading check"),
    ]
    cols = 3
    rows = 2
    canvas = Image.new("RGB", (cols * TILE[0], rows * TILE[1]), BG)
    for i, (name, label, sub) in enumerate(items):
        path = raw / name
        if not path.exists():
            print("missing", path)
            continue
        canvas.paste(tile(path, label, sub), ((i % cols) * TILE[0], (i // cols) * TILE[1]))
        shutil.copy2(path, out / name)
    canvas.save(out / "p2_contact_sheet.png")
    print(out / "p2_contact_sheet.png", canvas.size)


if __name__ == "__main__":
    main()
