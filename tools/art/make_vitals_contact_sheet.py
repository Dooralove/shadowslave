"""Build a contact sheet for the coral vitals sprite kit."""

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "ui" / "vitals"
OUT = ROOT / "docs" / "art" / "previews" / "vitals" / "vitals_sprite_kit.png"


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    windows_dir = Path(os.environ.get("WINDIR", ""))
    font_path = windows_dir / "Fonts" / "segoeui.ttf"
    try:
        return ImageFont.truetype(str(font_path), size)
    except OSError:
        return ImageFont.load_default()


def main() -> None:
    width, height = 1600, 900
    image = Image.new("RGBA", (width, height), (16, 18, 21, 255))
    draw = ImageDraw.Draw(image)

    try:
        font = load_font(22)
        small = load_font(16)
        title = load_font(30)
    except OSError:
        font = ImageFont.load_default()
        small = font
        title = font

    draw.text((40, 30), "CORAL VITALS — SPRITE KIT", font=title, fill=(220, 205, 180, 255))
    draw.text((40, 66), "Forgotten Shore / ShadowSlave · generated 2026-11-03", font=small, fill=(150, 145, 135, 255))

    frame = Image.open(SRC / "hp_frame.png").convert("RGBA")
    frame.thumbnail((1040, 270), Image.Resampling.LANCZOS)
    image.alpha_composite(frame, (40, 100))

    medallion = Image.open(SRC / "hp_medallion.png").convert("RGBA")
    medallion = medallion.resize((260, 260), Image.Resampling.LANCZOS)
    image.alpha_composite(medallion, (1110, 90))

    draw.text((40, 380), "hp_frame.png  ·  1536×377  ·  bronze / bone / crimson coral", font=small, fill=(180, 170, 155, 255))
    draw.text((1110, 360), "hp_medallion.png  ·  512²", font=small, fill=(180, 170, 155, 255))

    def strip(name: str, x: int, y: int, w: int, h: int) -> None:
        source = Image.open(SRC / name).convert("RGBA").resize((w, h), Image.Resampling.LANCZOS)
        image.alpha_composite(source, (x, y))

    strip("hp_fill.png", 40, 470, 720, 90)
    draw.text((40, 566), "hp_fill.png · grayscale, tinted by health state", font=small, fill=(180, 170, 155, 255))
    strip("hp_plate.png", 40, 610, 720, 90)
    draw.text((40, 706), "hp_plate.png · abyss plate", font=small, fill=(180, 170, 155, 255))

    glow = Image.open(SRC / "hp_glow.png").convert("RGBA").resize((220, 220), Image.Resampling.LANCZOS)
    image.alpha_composite(glow, (820, 470))
    draw.text((820, 696), "hp_glow.png · 512²", font=small, fill=(180, 170, 155, 255))

    shine = Image.open(SRC / "hp_shine.png").convert("RGBA").resize((400, 50), Image.Resampling.LANCZOS)
    image.alpha_composite(shine, (820, 610))
    draw.text((820, 666), "hp_shine.png · gloss", font=small, fill=(180, 170, 155, 255))

    notch = Image.open(SRC / "hp_notch.png").convert("RGBA").resize((64, 128), Image.Resampling.LANCZOS)
    image.alpha_composite(notch, (1260, 560))
    draw.text((1240, 470), "hp_notch.png · bone divider", font=small, fill=(180, 170, 155, 255))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(OUT, optimize=True)
    print(f"WROTE {OUT}")


if __name__ == "__main__":
    main()
