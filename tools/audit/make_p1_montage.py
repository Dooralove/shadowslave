#!/usr/bin/env python3
"""Build P1 character contact sheets from raw Godot previews.

Usage:
  python tools/audit/make_p1_montage.py \
    --raw "$env:TEMP/opencode/p1_preview" \
    --scenes "$env:TEMP/opencode/p1_scene_preview" \
    --out docs/art/previews/p1_characters
"""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

TILE = (640, 360)
BG = (12, 14, 18)
FG = (232, 236, 242)
MUTED = (160, 170, 184)
FONT_PATH = Path("C:/Windows/Fonts/segoeui.ttf")


def font(size: int):
    try:
        return ImageFont.truetype(str(FONT_PATH), size)
    except OSError:
        return ImageFont.load_default()


def label_tile(path: Path, label: str, sublabel: str = "") -> Image.Image:
    image = Image.open(path).convert("RGB")
    image = ImageOps.fit(image, TILE, method=Image.Resampling.LANCZOS)
    draw = ImageDraw.Draw(image, "RGBA")
    draw.rectangle((0, 0, TILE[0], 48), fill=(0, 0, 0, 155))
    draw.text((14, 7), label, font=font(20), fill=FG)
    if sublabel:
        draw.text((14, 30), sublabel, font=font(14), fill=MUTED)
    return image


def montage(items, cols: int, out: Path, size=TILE) -> None:
    rows = (len(items) + cols - 1) // cols
    canvas = Image.new("RGB", (cols * size[0], rows * size[1]), BG)
    for index, (path, label, sublabel) in enumerate(items):
        if not path.exists():
            print("skip missing:", path)
            continue
        canvas.paste(label_tile(path, label, sublabel), ((index % cols) * size[0], (index // cols) * size[1]))
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out)
    print(out, canvas.size)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", required=True, type=Path)
    ap.add_argument("--scenes", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()
    raw, scenes, out = args.raw, args.scenes, args.out

    montage(
        [
            (raw / "sunny_real.png", "SUNNY В· REAL", "hoodie-era silhouette В· LOD0/1/2"),
            (raw / "sunny_nightmare.png", "SUNNY В· NIGHTMARE", "ragged tunic В· barefoot"),
            (raw / "police_desk.png", "POLICE В· DESK", "older key NPC В· grey hair"),
            (raw / "police_guard.png", "POLICE В· GUARD", "young tactical variant"),
            (raw / "hero_auro.png", "HERO / AURO", "young soldier В· leather cuirass"),
            (raw / "scholar.png", "SCHOLAR", "tall thin В· glasses В· dark suit"),
            (raw / "shifty.png", "SHIFTY", "thin ragged slave"),
            (raw / "veteran.png", "VETERAN", "old officer В· leather cuirass"),
        ],
        4,
        out / "main_cast.png",
    )
    montage(
        [
            (raw / "mass_male.png", "MASS В· MALE", "no unique face В· palette variant"),
            (raw / "mass_female.png", "MASS В· FEMALE", "no unique face В· palette variant"),
            (raw / "mass_slave.png", "MASS В· SLAVE", "ragged silhouette"),
            (raw / "mass_soldier.png", "MASS В· SOLDIER", "generic soldier"),
            (raw / "mass_police.png", "MASS В· POLICE", "generic police"),
        ],
        3,
        out / "mass_cast.png",
    )
    montage(
        [
            (scenes / "p1_scene_caravan_site.png", "CARAVAN SITE", "Hero, Shifty, Scholar, Veteran in scene"),
            (scenes / "p1_scene_station_lobby.png", "STATION LOBBY", "key police variant at desk"),
            (scenes / "p1_scene_park_street.png", "PARK STREET", "mass NPC palette variants"),
            (scenes / "p1_scene_containment_room.png", "CONTAINMENT", "scene capture (camera/lighting check)"),
        ],
        2,
        out / "integration.png",
    )
    if (raw / "mountain_king_p1.png").exists():
        out.mkdir(parents=True, exist_ok=True)
        shutil.copy2(raw / "mountain_king_p1.png", out / "mountain_king_p1.png")
        print(out / "mountain_king_p1.png")


if __name__ == "__main__":
    main()

