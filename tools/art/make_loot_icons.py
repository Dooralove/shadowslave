"""Generate category icons for the generic loot catalog.

The icons are intentionally simple, high-contrast silhouettes so they read at
32-64 px in a future inventory grid. Output: assets/ui/loot/icons/*.png (RGBA).

Run from the project root:
    python tools/art/make_loot_icons.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/ui/loot/icons"
SCALE = 4
SIZE = 128
CANVAS = SIZE * SCALE

CORAL_DARK = (74, 28, 34, 255)
CORAL = (140, 74, 74, 255)
CORAL_LIGHT = (190, 110, 100, 255)
BONE = (216, 207, 192, 255)
BONE_DIM = (170, 160, 146, 255)
MUD = (20, 16, 24, 255)
AZURE = (47, 127, 168, 255)
AZURE_LIGHT = (120, 210, 230, 255)
FIRE = (255, 138, 60, 255)
GOLD = (210, 170, 90, 255)
PURPLE = (120, 96, 170, 255)


def _canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    margin = 8 * SCALE
    radius = 18 * SCALE
    draw.rounded_rectangle(
        (margin, margin, CANVAS - margin, CANVAS - margin),
        radius=radius,
        fill=(26, 20, 20, 255),
        outline=CORAL,
        width=3 * SCALE,
    )
    inner = margin + 4 * SCALE
    draw.rounded_rectangle(
        (inner, inner, CANVAS - inner, CANVAS - inner),
        radius=radius - 2 * SCALE,
        outline=(216, 207, 192, 36),
        width=1 * SCALE,
    )
    return image, draw


def _shadow(draw: ImageDraw.ImageDraw, shape, fill):
    offset = 3 * SCALE
    if shape == "polygon":
        draw.polygon([(x + offset, y + offset) for x, y in fill], fill=(0, 0, 0, 90))
    elif shape == "ellipse":
        draw.ellipse(
            (fill[0] + offset, fill[1] + offset, fill[2] + offset, fill[3] + offset),
            fill=(0, 0, 0, 90),
        )
    elif shape == "rounded":
        draw.rounded_rectangle(
            (fill[0] + offset, fill[1] + offset, fill[2] + offset, fill[3] + offset),
            radius=fill[4],
            fill=(0, 0, 0, 90),
        )


def icon_currency(draw: ImageDraw.ImageDraw) -> None:
    crystal = [(64, 18), (92, 48), (80, 104), (48, 104), (36, 48)]
    crystal = [(x * SCALE, y * SCALE) for x, y in crystal]
    _shadow(draw, "polygon", crystal)
    draw.polygon(crystal, fill=AZURE, outline=AZURE_LIGHT)
    inner = [(64, 30), (80, 52), (72, 92), (56, 92), (48, 52)]
    inner = [(x * SCALE, y * SCALE) for x, y in inner]
    draw.polygon(inner, fill=AZURE_LIGHT)
    draw.line([(64 * SCALE, 30 * SCALE), (64 * SCALE, 92 * SCALE)], fill=(235, 255, 255, 180), width=2 * SCALE)


def icon_material(draw: ImageDraw.ImageDraw) -> None:
    plate = [(28, 44), (52, 22), (96, 30), (106, 62), (82, 104), (44, 96), (24, 70)]
    plate = [(x * SCALE, y * SCALE) for x, y in plate]
    _shadow(draw, "polygon", plate)
    draw.polygon(plate, fill=CORAL_DARK, outline=CORAL_LIGHT)
    ridge = [(40, 54), (58, 38), (88, 44), (94, 66), (76, 90), (48, 82)]
    ridge = [(x * SCALE, y * SCALE) for x, y in ridge]
    draw.polygon(ridge, fill=(110, 56, 54, 255), outline=BONE_DIM)
    for x, y in [(50, 58), (68, 50), (82, 64), (64, 78), (48, 72)]:
        draw.ellipse((x * SCALE - 3 * SCALE, y * SCALE - 3 * SCALE, x * SCALE + 3 * SCALE, y * SCALE + 3 * SCALE), fill=BONE_DIM)


def icon_consumable(draw: ImageDraw.ImageDraw) -> None:
    body = (38, 54, 90, 108)
    _shadow(draw, "ellipse", body)
    draw.ellipse(body, fill=(58, 34, 32, 255), outline=CORAL_LIGHT, width=2 * SCALE)
    draw.rectangle((54 * SCALE, 26 * SCALE, 74 * SCALE, 58 * SCALE), fill=(58, 34, 32, 255), outline=CORAL_LIGHT, width=2 * SCALE)
    draw.ellipse((48 * SCALE, 20 * SCALE, 80 * SCALE, 34 * SCALE), fill=BONE_DIM, outline=BONE)
    liquid = (46, 72, 82, 102)
    draw.ellipse(liquid, fill=(160, 52, 48, 255))
    draw.arc((48 * SCALE, 66 * SCALE, 80 * SCALE, 96 * SCALE), 200, 340, fill=FIRE, width=2 * SCALE)


def icon_tool(draw: ImageDraw.ImageDraw) -> None:
    for i, color in enumerate([BONE, BONE_DIM, BONE]):
        offset = i * 4 * SCALE
        draw.arc(
            (28 * SCALE, 30 * SCALE + offset, 100 * SCALE, 102 * SCALE + offset),
            200,
            340,
            fill=color,
            width=5 * SCALE,
        )
    draw.line([(36 * SCALE, 74 * SCALE), (92 * SCALE, 98 * SCALE)], fill=BONE, width=3 * SCALE)
    draw.ellipse((58 * SCALE, 44 * SCALE, 70 * SCALE, 56 * SCALE), fill=CORAL_LIGHT)


def icon_equipment(draw: ImageDraw.ImageDraw) -> None:
    blade = [(64, 14), (72, 24), (72, 76), (64, 88), (56, 76), (56, 24)]
    blade = [(x * SCALE, y * SCALE) for x, y in blade]
    _shadow(draw, "polygon", blade)
    draw.polygon(blade, fill=(190, 198, 205, 255), outline=(235, 240, 245, 255))
    draw.line([(64 * SCALE, 18 * SCALE), (64 * SCALE, 82 * SCALE)], fill=(245, 250, 255, 180), width=2 * SCALE)
    draw.rectangle((40 * SCALE, 84 * SCALE, 88 * SCALE, 94 * SCALE), fill=CORAL_DARK, outline=CORAL_LIGHT, width=2 * SCALE)
    draw.rectangle((58 * SCALE, 94 * SCALE, 70 * SCALE, 112 * SCALE), fill=(70, 44, 34, 255), outline=BONE_DIM, width=2 * SCALE)
    draw.ellipse((60 * SCALE, 108 * SCALE, 68 * SCALE, 116 * SCALE), fill=GOLD)


def icon_memory(draw: ImageDraw.ImageDraw) -> None:
    shard = [(64, 14), (86, 46), (78, 100), (50, 100), (42, 46)]
    shard = [(x * SCALE, y * SCALE) for x, y in shard]
    _shadow(draw, "polygon", shard)
    draw.polygon(shard, fill=PURPLE, outline=(190, 170, 230, 255))
    inner = [(64, 28), (76, 50), (70, 88), (58, 88), (52, 50)]
    inner = [(x * SCALE, y * SCALE) for x, y in inner]
    draw.polygon(inner, fill=(170, 150, 220, 255))
    draw.line([(64 * SCALE, 34 * SCALE), (64 * SCALE, 86 * SCALE)], fill=(240, 235, 255, 220), width=2 * SCALE)


def icon_key(draw: ImageDraw.ImageDraw) -> None:
    _shadow(draw, "ellipse", (28 * SCALE, 28 * SCALE, 68 * SCALE, 68 * SCALE))
    draw.ellipse((28 * SCALE, 28 * SCALE, 68 * SCALE, 68 * SCALE), fill=GOLD, outline=(245, 220, 160, 255), width=2 * SCALE)
    draw.ellipse((38 * SCALE, 38 * SCALE, 58 * SCALE, 58 * SCALE), fill=(26, 20, 20, 255))
    draw.rectangle((60 * SCALE, 54 * SCALE, 104 * SCALE, 66 * SCALE), fill=GOLD)
    draw.rectangle((90 * SCALE, 64 * SCALE, 100 * SCALE, 84 * SCALE), fill=GOLD)
    draw.rectangle((78 * SCALE, 64 * SCALE, 86 * SCALE, 78 * SCALE), fill=GOLD)


def icon_relic(draw: ImageDraw.ImageDraw) -> None:
    base = [(30, 92), (44, 44), (64, 24), (84, 44), (98, 92), (82, 104), (46, 104)]
    base = [(x * SCALE, y * SCALE) for x, y in base]
    _shadow(draw, "polygon", base)
    draw.polygon(base, fill=CORAL_DARK, outline=CORAL_LIGHT)
    for x, y, r in [(44, 56, 10), (64, 40, 12), (84, 56, 10)]:
        draw.ellipse(
            ((x - r) * SCALE, (y - r) * SCALE, (x + r) * SCALE, (y + r) * SCALE),
            fill=CORAL_LIGHT,
            outline=BONE,
            width=2 * SCALE,
        )
    draw.rectangle((40 * SCALE, 88 * SCALE, 88 * SCALE, 96 * SCALE), fill=GOLD, outline=(245, 220, 160, 255), width=2 * SCALE)


ICONS = {
    "currency": icon_currency,
    "material": icon_material,
    "consumable": icon_consumable,
    "tool": icon_tool,
    "equipment": icon_equipment,
    "memory": icon_memory,
    "key": icon_key,
    "relic": icon_relic,
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, painter in ICONS.items():
        image, draw = _canvas()
        painter(draw)
        image = image.resize((SIZE, SIZE), Image.LANCZOS)
        # Soft outer glow, then crisp icon on top.
        glow = image.filter(ImageFilter.GaussianBlur(3))
        result = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        result.alpha_composite(glow)
        result.alpha_composite(image)
        path = OUT / f"loot_{name}.png"
        result.save(path)
        print(f"WROTE {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
