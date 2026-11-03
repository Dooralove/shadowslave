#!/usr/bin/env python3
"""Собирает P0 style-gate montages и contact sheet из raw PNG.

Запуск:
  python tools/audit/make_p0_montage.py \
    --raw C:/.../p0_style_gate_raw \
    --baseline-root C:/.../opencode \
    --out docs/art/previews/p0_style_gate

Только чтение raw PNG и запись montage PNG; проектные сцены не меняются.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

TILE = (640, 360)
BG = (12, 14, 18)
FG = (232, 236, 242)
MUTED = (160, 170, 184)
FONT_PATH = Path("C:/Windows/Fonts/segoeui.ttf")


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    try:
        return ImageFont.truetype(str(FONT_PATH), size)
    except OSError:
        return ImageFont.load_default()


def tile(path: Path, label: str, sublabel: str = "") -> Image.Image:
    image = Image.open(path).convert("RGB")
    image = ImageOps.fit(image, TILE, method=Image.Resampling.LANCZOS)
    draw = ImageDraw.Draw(image, "RGBA")
    draw.rectangle((0, 0, TILE[0], 48), fill=(0, 0, 0, 150))
    draw.text((14, 7), label, font=font(20), fill=FG)
    if sublabel:
        draw.text((14, 30), sublabel, font=font(14), fill=MUTED)
    return image


def montage(items: list[tuple[Path, str, str]], cols: int, out: Path) -> None:
    rows = (len(items) + cols - 1) // cols
    canvas = Image.new("RGB", (cols * TILE[0], rows * TILE[1]), BG)
    for index, (path, label, sublabel) in enumerate(items):
        if not path.exists():
            print(f"skip missing: {path}")
            continue
        x = (index % cols) * TILE[0]
        y = (index // cols) * TILE[1]
        canvas.paste(tile(path, label, sublabel), (x, y))
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out)
    print(out, canvas.size)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", required=True, type=Path)
    parser.add_argument("--baseline-root", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    raw = args.raw
    base = args.baseline_root

    montage(
        [
            (raw / "park_a_procedural.png", "PARK A", "procedural overcast · exp 0.95"),
            (raw / "park_b_hdri_misty.png", "PARK B", "HDRI misty morning · exp 0.90"),
            (raw / "park_c_hdri_contrast.png", "PARK C", "HDRI misty · exp 0.70 · more fog"),
        ],
        3,
        args.out / "style_gate_park.png",
    )
    montage(
        [
            (raw / "rock_a_moon.png", "ROCK A", "moon · exp 1.0 · fog 0.004"),
            (raw / "rock_b_fog.png", "ROCK B", "moon · exp 1.2 · fog 0.008"),
            (raw / "rock_c_cold.png", "ROCK C", "moon · exp 1.4 · fog 0.012"),
        ],
        3,
        args.out / "style_gate_rock.png",
    )
    montage(
        [
            (raw / "char_a_soft_group.png", "CHAR A · GROUP", "soft key · neutral"),
            (raw / "char_a_soft_face.png", "CHAR A · FACE", "soft key · neutral"),
            (raw / "char_b_lowkey_group.png", "CHAR B · GROUP", "low key · dark"),
            (raw / "char_b_lowkey_face.png", "CHAR B · FACE", "low key · dark"),
            (raw / "char_c_warmcool_group.png", "CHAR C · GROUP", "warm key · cool rim"),
            (raw / "char_c_warmcool_face.png", "CHAR C · FACE", "warm key · cool rim"),
        ],
        2,
        args.out / "style_gate_characters.png",
    )
    montage(
        [
            (raw / "king_a_silhouette.png", "KING A", "silhouette · fog · backlight"),
            (raw / "king_b_reveal.png", "KING B", "3/4 reveal · fill"),
        ],
        2,
        args.out / "style_gate_king.png",
    )

    baseline = [
        (base / "g1_park2/bench_shot.png", "PARK · BENCH", "current baseline"),
        (base / "g1_lobby/desk_shot.png", "LOBBY · DESK", "current baseline"),
        (base / "g1_cell/room_shot.png", "CELL · ROOM", "current baseline"),
        (base / "g1_vision/orbit.png", "VISION · ORBIT", "current baseline"),
        (base / "g1_camp_pass/player_view.png", "ROAD · PLAYER", "current baseline"),
        (base / "g1_camp_site/cam_wagon_camera.png", "SITE · WAGON CAM", "current baseline"),
        (base / "g1_camp_site/cam_night_montage_camera.png", "SITE · NIGHT CAM", "current baseline"),
        (base / "g1_camp_path/player_view.png", "PATH · PLAYER", "current baseline"),
        (base / "g1_camp_sanctuary/player_view.png", "SANCTUARY · PLAYER", "current baseline"),
        (base / "g1_park2/doze_shot.png", "PARK · DOZE", "current baseline"),
        (base / "g1_lobby/alarm_shot.png", "LOBBY · ALARM", "current baseline"),
        (base / "g1_cell/door_shot.png", "CELL · DOOR", "current baseline"),
    ]
    montage(baseline, 4, args.out / "baseline_contact_sheet.png")


if __name__ == "__main__":
    main()
