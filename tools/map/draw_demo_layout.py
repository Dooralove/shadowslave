#!/usr/bin/env python3
"""Top-down demo layout for the Forgotten Shore labyrinth fragment.

Read-only design artifact: draws zone rectangles, the high route, low routes
and key POIs from the coordinates used in docs/demo_sprint/design/poi_manifest.md.
No game files are read or modified.

    python tools/map/draw_demo_layout.py
"""

from __future__ import annotations

from pathlib import Path

OUT = Path("docs/demo_sprint/design/world_layout_map.svg")

ZONES = [
    ("Z01 Threshold", 12, -12, 45, 12),
    ("Z02 Carcass", 8, 15, 30, 38),
    ("Z03 First Fork", -12, -12, 12, 12),
    ("Z04 Mud Hollow", -45, -55, -15, -30),
    ("Z05 Bone Passage", -45, 15, -15, 40),
    ("Z06 Dry Pocket", -55, 40, -40, 52),
    ("Z07 Scout Ridge", -55, -62, 5, -48),
    ("Z08 Clearing", -80, -18, -50, 18),
    ("Z09 Blind Tunnel", -85, 18, -55, 22),
    ("Z10 Coral Hill", -125, -30, -85, 20),
    ("Z11 Tide Channel", -150, -30, -125, 30),
    ("Z12 Isthmus", -200, -25, -150, 25),
    ("Z13 Hunting Grounds", -550, -120, -200, 120),
    ("Z14 Bone Bridge", -650, -40, -550, 40),
    ("Z15 High Refuge", -750, -80, -650, 40),
    ("Z16 Pack Territory", -1050, -150, -750, 150),
    ("Z17 Storm Run", -1300, -80, -1050, 80),
    ("Z18 Cliffs", -1450, -100, -1300, 100),
]

HIGH_ROUTE = [
    (38, 0), (12, 0), (0, 0), (0, -12), (0, -48), (-25, -55),
    (-48, -55), (-55, -48), (-65, -18), (-65, 0), (-80, 0),
    (-85, 0), (-100, 18), (-112, 10), (-125, -20), (-150, -20),
    (-200, -20), (-204, -20), (-204, -90), (-375, -90), (-450, -90),
    (-450, -30), (-535, 0), (-550, 0), (-600, 0), (-650, 0),
    (-660, -20), (-680, -20), (-700, -20), (-750, -20), (-800, 40),
    (-800, 70), (-900, 90), (-1050, 85), (-1050, 10), (-1050, 0),
    (-1175, 0), (-1300, 0), (-1320, 0), (-1350, 20), (-1380, -10),
    (-1400, 0), (-1410, 0),
]

LOW_ROUTES = [
    [(-12, -7), (-20, -35), (-30, -42), (-45, -30), (-50, -15), (-55, -8)],
    [(-12, 7), (-20, 20), (-30, 21), (-45, 20), (-50, 15), (-55, 5)],
    [(-55, 19), (-70, 20), (-85, 20), (-100, 18)],
    [(-125, 0), (-137, 0), (-150, 0), (-160, 0)],
    [(-200, 0), (-300, 0), (-400, 0), (-500, 0), (-550, 2)],
    [(-550, 18), (-600, 18), (-650, 18), (-660, 2)],
    [(-750, 0), (-850, 0), (-950, 0), (-1050, 0)],
    [(-1050, 25), (-1175, 25), (-1300, 25), (-1320, 6)],
]

# (x, z, label, kind)
POIS = [
    (38, 0, "Start", "entry"),
    (30, 0, "Statue view", "vista"),
    (19, 26, "Carcass", "landmark"),
    (23, 30.5, "SQ-01 token", "side"),
    (-48.5, 48, "Teo", "npc"),
    (0, 0, "First fork", "hub"),
    (-35, -55, "Hero blade", "landmark"),
    (-65, 0, "Nephis / Cassia", "npc"),
    (-70, 20, "SQ-02 echo", "side"),
    (-100, -5, "Camp", "hub"),
    (-104, -12, "Pillar", "landmark"),
    (-137, 0, "SQ-04 box", "side"),
    (-137, -20, "Tide ledge", "safe"),
    (-420, -105, "Western spire", "landmark"),
    (-380, 0, "Giant skeleton", "landmark"),
    (-375, -90, "Hunt traverse", "combat"),
    (-600, 0, "Bone bridge", "landmark"),
    (-610, 9, "SQ-05 lair", "side"),
    (-700, -20, "Refuge", "hub"),
    (-900, 90, "Pack ridge", "safe"),
    (-1175, 0, "Storm run", "combat"),
    (-1300, 0, "Storm wall", "landmark"),
    (-1410, 0, "Cliff top", "entry"),
]


def sx(x: float) -> float:
    return 80 + (x + 1500) * 1.0


def sz(z: float) -> float:
    return 60 + (z + 160) * 1.0


def main() -> None:
    width, height = 1680, 500
    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" font-family="Segoe UI, DejaVu Sans, sans-serif">',
        '<rect width="100%" height="100%" fill="#0d1014"/>',
        '<text x="80" y="34" fill="#e8e2d6" font-size="20" font-weight="600">'
        'Forgotten Shore — Labyrinth First Fragment / demo layout</text>',
        '<text x="80" y="54" fill="#8fa0b4" font-size="12">'
        'Godot +X east (statue), −X west (cliffs), −Z north, +Z south · 1 px = 1 m · design proposal, not final art</text>',
    ]

    # Grid every 100 m.
    for x in range(-1500, 101, 100):
        px = sx(x)
        lines.append(f'<line x1="{px:.1f}" y1="65" x2="{px:.1f}" y2="470" stroke="#1b2530" stroke-width="1"/>')
        if x % 200 == 0:
            lines.append(f'<text x="{px:.1f}" y="484" fill="#52606e" font-size="10" text-anchor="middle">{x}</text>')
    for z in range(-160, 161, 50):
        pz = sz(z)
        lines.append(f'<line x1="70" y1="{pz:.1f}" x2="1640" y2="{pz:.1f}" stroke="#1b2530" stroke-width="1"/>')
        if z % 100 == 0:
            lines.append(f'<text x="64" y="{pz + 3:.1f}" fill="#52606e" font-size="10" text-anchor="end">{z}</text>')

    # Zones.
    for name, x0, z0, x1, z1 in ZONES:
        px, py = sx(x0), sz(z0)
        pw, ph = (x1 - x0), (z1 - z0)
        fill = "#17222d" if name.startswith(("Z0", "Z1")) else "#141b24"
        lines.append(
            f'<rect x="{px:.1f}" y="{py:.1f}" width="{pw:.1f}" height="{ph:.1f}" '
            f'fill="{fill}" fill-opacity="0.55" stroke="#33475a" stroke-width="1.2"/>'
        )
        lines.append(
            f'<text x="{px + 6:.1f}" y="{py + 15:.1f}" fill="#9fb3c8" font-size="11" '
            f'font-weight="600">{name}</text>'
        )

    # Low routes.
    for route in LOW_ROUTES:
        points = " ".join(f"{sx(x):.1f},{sz(z):.1f}" for x, z in route)
        lines.append(f'<polyline points="{points}" fill="none" stroke="#4f7f9a" stroke-width="2" stroke-dasharray="6 5" opacity="0.8"/>')

    # High route.
    points = " ".join(f"{sx(x):.1f},{sz(z):.1f}" for x, z in HIGH_ROUTE)
    lines.append(f'<polyline points="{points}" fill="none" stroke="#e0a45c" stroke-width="3.2" stroke-linejoin="round" opacity="0.95"/>')

    # POIs.
    colors = {
        "entry": "#f2d27a",
        "hub": "#f2d27a",
        "vista": "#8fd0ff",
        "landmark": "#c9a6ff",
        "side": "#ff9f6e",
        "npc": "#8ff0b4",
        "safe": "#8ff0b4",
        "combat": "#ff6e7a",
    }
    for x, z, label, kind in POIS:
        px, py = sx(x), sz(z)
        color = colors.get(kind, "#ffffff")
        if kind in ("hub", "entry"):
            lines.append(f'<rect x="{px - 5:.1f}" y="{py - 5:.1f}" width="10" height="10" fill="{color}" stroke="#0d1014" stroke-width="1"/>')
        elif kind == "landmark":
            lines.append(f'<polygon points="{px:.1f},{py - 6:.1f} {px + 6:.1f},{py:.1f} {px:.1f},{py + 6:.1f} {px - 6:.1f},{py:.1f}" fill="{color}" stroke="#0d1014" stroke-width="1"/>')
        elif kind == "side":
            lines.append(f'<polygon points="{px:.1f},{py - 6:.1f} {px + 6:.1f},{py:.1f} {px:.1f},{py + 6:.1f} {px - 6:.1f},{py:.1f}" fill="{color}" stroke="#0d1014" stroke-width="1"/>')
        elif kind == "combat":
            lines.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="5" fill="{color}" stroke="#0d1014" stroke-width="1"/>')
        else:
            lines.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="4" fill="{color}" stroke="#0d1014" stroke-width="1"/>')
        lines.append(
            f'<text x="{px + 8:.1f}" y="{py - 4:.1f}" fill="#dce6f2" font-size="10" '
            f'stroke="#0d1014" stroke-width="3" paint-order="stroke">{label}</text>'
        )

    # Legend.
    legend = [
        ("#e0a45c", "high route (always dry)"),
        ("#4f7f9a", "low route (tide-dependent)"),
        ("#f2d27a", "entry / hub"),
        ("#ff9f6e", "side quest"),
        ("#c9a6ff", "landmark"),
        ("#ff6e7a", "combat"),
    ]
    lx, ly = 80, 410
    for i, (color, label) in enumerate(legend):
        px = lx + (i % 3) * 250
        py = ly + (i // 3) * 20
        lines.append(f'<rect x="{px}" y="{py - 8}" width="14" height="8" fill="{color}"/>')
        lines.append(f'<text x="{px + 20}" y="{py}" fill="#b9c6d4" font-size="11">{label}</text>')

    # North arrow / scale.
    lines.append('<text x="1570" y="90" fill="#9fb3c8" font-size="12" text-anchor="middle">N</text>')
    lines.append('<line x1="1570" y1="96" x2="1570" y2="126" stroke="#9fb3c8" stroke-width="2"/>')
    lines.append('<polygon points="1570,88 1565,100 1575,100" fill="#9fb3c8"/>')
    lines.append('<text x="1570" y="145" fill="#52606e" font-size="10" text-anchor="middle">0    100 m</text>')
    lines.append('<line x1="1520" y1="152" x2="1620" y2="152" stroke="#52606e" stroke-width="2"/>')

    lines.append("</svg>")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
