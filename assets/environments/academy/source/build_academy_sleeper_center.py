"""Sleeper Center — standalone interior location.

Builds the building interior with the canon layout: entry vestibule, dormitory
with 12 capsules, common room, showers, observation post, medical corridor,
Hollow gallery, dream ward and a residential corridor with room 07. No gameplay,
no NPCs, no quests.

Run:
  blender -b --python assets/environments/academy/source/build_academy_sleeper_center.py
"""
from __future__ import annotations

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import bpy  # noqa: E402

import academy_kit as K  # noqa: E402


K.reset()
M = K.materials()
OBJECTS: list = []


def add(obj):
    if obj is not None:
        OBJECTS.append(obj)
    return obj


def b(name, center, size, material, bevel=0.0):
    return add(K.box(name, center, size, material, bevel))


def br(name, center, size, material, rot_y=0.0, bevel=0.0):
    return add(K.box_rot(name, center, size, material, rot_y, bevel))


def c(name, center, radius, depth, material, axis="Y", segments=20, bevel=0.0):
    return add(K.cyl(name, center, radius, depth, material, axis, segments, bevel))


# ---------------------------------------------------------------------------
# furniture
# ---------------------------------------------------------------------------

def capsule(prefix: str, x: float, z: float):
    # Base and mattress
    b(prefix + "_base", (x, 0.22, z), (1.30, 0.44, 2.55), M["metal"], 0.02)
    b(prefix + "_mattress", (x, 0.52, z), (1.10, 0.18, 2.25), M["fabric"], 0.03)
    b(prefix + "_pillow", (x, 0.64, z - 0.94), (0.85, 0.14, 0.42), M["white_dirty"], 0.04)
    # Head and foot boards
    b(prefix + "_head", (x, 0.90, z - 1.24), (1.32, 1.30, 0.14), M["metal_light"], 0.015)
    b(prefix + "_foot", (x, 0.55, z + 1.24), (1.32, 0.55, 0.14), M["metal"], 0.015)
    # Side rails
    for side in (-1, 1):
        b(prefix + "_rail_%d" % side, (x + side * 0.66, 0.78, z), (0.08, 0.16, 2.30), M["metal_light"], 0.006)
        for i in range(3):
            b(prefix + "_rail_post_%d_%d" % (side, i), (x + side * 0.66, 0.55, z - 0.8 + i * 0.8), (0.08, 0.55, 0.08), M["metal"], 0.004)
    # Canopy / half shell
    b(prefix + "_canopy", (x, 1.62, z), (1.42, 0.10, 2.40), M["white_dirty"], 0.02)
    for side in (-1, 1):
        b(prefix + "_canopy_side_%d" % side, (x + side * 0.70, 1.42, z), (0.08, 0.30, 2.40), M["white_dirty"], 0.01)
    b(prefix + "_canopy_glass", (x, 1.55, z), (1.10, 0.03, 2.10), M["glass"], 0.004)
    # Harness straps
    for i in range(2):
        b(prefix + "_strap_%d" % i, (x, 0.70, z - 0.35 + i * 0.7), (1.18, 0.06, 0.12), M["fabric_blue"], 0.006)
    # Status light and small screen
    b(prefix + "_status", (x, 1.68, z - 1.10), (0.16, 0.06, 0.16), M["lamp_cold"], 0.004)
    b(prefix + "_screen", (x, 1.48, z + 1.10), (0.50, 0.28, 0.04), M["screen"], 0.004)
    # Cable to the floor
    c(prefix + "_cable", (x + 0.58, 0.12, z + 1.05), 0.035, 0.24, M["dark"], "Y", 8, 0.002)


def locker(prefix: str, x: float, z: float, facing=(0.0, 0.0, 1.0)):
    fx = float(facing[0]) * 0.26
    fz = float(facing[2]) * 0.26
    # side vector on the door plane
    sx = float(facing[2])
    sz = -float(facing[0])
    b(prefix + "_body", (x, 0.95, z), (0.50 if abs(fx) > 0.01 else 0.60, 1.90, 0.60 if abs(fx) > 0.01 else 0.50), M["metal"], 0.012)
    b(prefix + "_door", (x + fx, 0.95, z + fz), (0.54 if abs(fx) < 0.01 else 0.03, 1.74, 0.03 if abs(fx) < 0.01 else 0.54), M["metal_light"], 0.006)
    b(prefix + "_handle", (x + fx + sx * 0.18, 0.95, z + fz + sz * 0.18), (0.04, 0.16, 0.04), M["dark"], 0.003)
    for i in range(3):
        b(prefix + "_vent_%d" % i, (x + fx + sx * 0.0, 1.55 + i * 0.07, z + fz), (0.36 if abs(fx) < 0.01 else 0.03, 0.02, 0.03 if abs(fx) < 0.01 else 0.36), M["dark"], 0.002)
    b(prefix + "_plate", (x + fx + sx * -0.18, 1.35, z + fz + sz * -0.18), (0.12, 0.10, 0.02), M["screen_warm"], 0.002)


def bench(prefix: str, x: float, z: float, facing=(0.0, 0.0, 1.0)):
    fx = float(facing[0]) * -0.22
    fz = float(facing[2]) * -0.22
    along_x = abs(float(facing[2])) > 0.5
    b(prefix + "_seat", (x, 0.46, z), (2.8 if along_x else 0.50, 0.10, 0.50 if along_x else 2.8), M["wood_light"], 0.012)
    b(prefix + "_back", (x + fx, 0.76, z + fz), (2.8 if along_x else 0.08, 0.40, 0.08 if along_x else 2.8), M["wood_light"], 0.01)
    for side in (-1, 1):
        lx = x + side * 1.05 if along_x else x
        lz = z if along_x else z + side * 1.05
        b(prefix + "_leg_%d" % side, (lx, 0.23, lz), (0.08, 0.46, 0.44), M["metal"], 0.006)


def table(prefix: str, x: float, z: float, sx: float = 2.6, sz: float = 1.2):
    b(prefix + "_top", (x, 0.76, z), (sx, 0.08, sz), M["wood_light"], 0.012)
    for side_x in (-1, 1):
        for side_z in (-1, 1):
            b(prefix + "_leg_%d_%d" % (side_x, side_z), (x + side_x * (sx * 0.42), 0.38, z + side_z * (sz * 0.38)), (0.08, 0.76, 0.08), M["metal"], 0.004)


def chair(prefix: str, x: float, z: float, facing=(0.0, 0.0, 1.0)):
    fx = float(facing[0]) * -0.22
    fz = float(facing[2]) * -0.22
    b(prefix + "_seat", (x, 0.46, z), (0.46, 0.06, 0.46), M["wood"], 0.008)
    b(prefix + "_back", (x + fx, 0.74, z + fz), (0.46, 0.48, 0.06), M["wood"], 0.008)
    for side_x in (-1, 1):
        for side_z in (-1, 1):
            b(prefix + "_leg_%d_%d" % (side_x, side_z), (x + side_x * 0.18, 0.23, z + side_z * 0.18), (0.05, 0.46, 0.05), M["metal"], 0.003)


def desk(prefix: str, x: float, z: float, sx: float = 2.2, rot_y: float = 0.0):
    br(prefix + "_top", (x, 0.76, z), (sx, 0.08, 0.78), M["wood_light"], rot_y, 0.01)
    for side in (-1, 1):
        br(prefix + "_side_%d" % side, (x + side * (sx * 0.44), 0.38, z), (0.08, 0.76, 0.68), M["metal"], rot_y, 0.006)
    br(prefix + "_drawer", (x, 0.55, z + 0.30), (0.48, 0.22, 0.06), M["metal_light"], rot_y, 0.004)


def sofa(prefix: str, x: float, z: float, rot_y: float = 0.0):
    br(prefix + "_base", (x, 0.35, z), (2.4, 0.45, 0.90), M["fabric_blue"], rot_y, 0.04)
    br(prefix + "_back", (x, 0.78, z - 0.40), (2.4, 0.60, 0.22), M["fabric_blue"], rot_y, 0.04)
    for side in (-1, 1):
        br(prefix + "_arm_%d" % side, (x + side * 1.12, 0.55, z), (0.18, 0.55, 0.90), M["fabric_blue"], rot_y, 0.04)
    for i in range(2):
        br(prefix + "_cushion_%d" % i, (x - 0.55 + i * 1.1, 0.58, z + 0.08), (0.90, 0.16, 0.70), M["fabric_blue"], rot_y, 0.04)


def vending(prefix: str, x: float, z: float, rot_y: float = 0.0):
    br(prefix + "_body", (x, 1.0, z), (1.10, 2.0, 0.90), M["dark"], rot_y, 0.02)
    br(prefix + "_glass", (x, 1.15, z + 0.46), (0.88, 1.45, 0.03), M["glass_clear"], rot_y, 0.004)
    br(prefix + "_glow", (x, 1.18, z + 0.48), (0.72, 1.22, 0.02), M["screen_warm"], rot_y, 0.003)
    br(prefix + "_panel", (x + 0.32, 1.55, z + 0.50), (0.22, 0.28, 0.03), M["screen"], rot_y, 0.003)
    br(prefix + "_slot", (x, 0.55, z + 0.48), (0.55, 0.12, 0.04), M["metal"], rot_y, 0.003)


def monitor(prefix: str, x: float, y: float, z: float, rot_y: float = 0.0, warm: bool = False):
    br(prefix + "_frame", (x, y, z), (0.72, 0.44, 0.06), M["dark"], rot_y, 0.006)
    br(prefix + "_screen", (x, y, z + 0.035), (0.64, 0.36, 0.02), M["screen_warm"] if warm else M["screen"], rot_y, 0.003)
    br(prefix + "_stand", (x, y - 0.30, z), (0.08, 0.18, 0.08), M["metal"], rot_y, 0.004)


def terminal(prefix: str, x: float, z: float, rot_y: float = 0.0):
    br(prefix + "_body", (x, 1.0, z), (1.2, 2.0, 0.55), M["metal"], rot_y, 0.02)
    br(prefix + "_screen", (x, 1.35, z + 0.29), (0.86, 0.52, 0.03), M["screen"], rot_y, 0.004)
    br(prefix + "_keyboard", (x, 0.92, z + 0.42), (0.78, 0.06, 0.28), M["dark"], rot_y, 0.003)


def shower_stall(prefix: str, x: float, z: float, facing=(0.0, 0.0, 1.0)):
    fx = float(facing[0])
    fz = float(facing[2])
    side_x = fz
    side_z = -fx
    b(prefix + "_back", (x - fx * 0.46, 1.15, z - fz * 0.46), (1.00 if abs(fx) < 0.5 else 0.08, 2.30, 0.08 if abs(fx) < 0.5 else 1.00), M["tile"], 0.008)
    for side in (-1, 1):
        b(prefix + "_side_%d" % side, (x - fx * 0.46 + side * side_x * 0.46, 1.15, z - fz * 0.46 + side * side_z * 0.46), (0.08 if abs(fx) < 0.5 else 0.90, 2.30, 0.90 if abs(fx) < 0.5 else 0.08), M["tile"], 0.006)
    b(prefix + "_glass", (x + fx * 0.90, 1.15, z + fz * 0.90), (0.90 if abs(fx) < 0.5 else 0.03, 2.10, 0.03 if abs(fx) < 0.5 else 0.90), M["glass_clear"], 0.003)
    b(prefix + "_door_bar", (x + fx * 0.94, 1.15, z + fz * 0.94), (0.06 if abs(fx) < 0.5 else 0.05, 2.10, 0.05 if abs(fx) < 0.5 else 0.06), M["metal_light"], 0.003)
    c(prefix + "_head", (x + fx * 0.12, 2.05, z + fz * 0.12), 0.07, 0.12, M["metal_light"], "Y", 10, 0.003)
    b(prefix + "_drain", (x + fx * 0.25, 0.03, z + fz * 0.25), (0.34, 0.02, 0.34), M["metal"], 0.0)


def sink(prefix: str, x: float, z: float, rot_y: float = 0.0):
    br(prefix + "_counter", (x, 0.82, z), (1.0, 0.10, 0.55), M["tile"], rot_y, 0.01)
    br(prefix + "_basin", (x, 0.84, z), (0.56, 0.08, 0.36), M["metal_light"], rot_y, 0.01)
    c(prefix + "_faucet", (x, 1.02, z - 0.18), 0.035, 0.28, M["metal"], "Y", 10, 0.003)
    br(prefix + "_mirror", (x, 1.55, z - 0.24), (0.80, 0.62, 0.03), M["glass"], rot_y, 0.004)


def bed(prefix: str, x: float, z: float, canopy: bool = False):
    b(prefix + "_frame", (x, 0.30, z), (2.0, 0.22, 3.4), M["metal"], 0.02)
    b(prefix + "_mattress", (x, 0.48, z), (1.80, 0.18, 3.10), M["white_dirty"], 0.03)
    b(prefix + "_pillow", (x, 0.61, z - 1.20), (1.20, 0.14, 0.50), M["white"], 0.04)
    b(prefix + "_blanket", (x, 0.58, z + 0.35), (1.70, 0.08, 1.70), M["fabric_blue"], 0.02)
    b(prefix + "_head", (x, 0.85, z - 1.65), (2.0, 1.2, 0.12), M["metal_light"], 0.015)
    if canopy:
        # An open frame, not a solid slab: the camera must see the capsule,
        # not a black ceiling panel.
        for side in (-1, 1):
            b(prefix + "_canopy_x_%d" % side, (x, 3.38, z + side * 1.85), (4.2, 0.10, 0.12), M["metal"], 0.008)
            b(prefix + "_canopy_z_%d" % side, (x + side * 2.05, 3.38, z), (0.12, 0.10, 3.8), M["metal"], 0.008)
            b(prefix + "_post_x_%d" % side, (x + side * 1.9, 1.7, z - 1.7), (0.10, 3.4, 0.10), M["metal_light"], 0.006)
            b(prefix + "_post_z_%d" % side, (x + side * 1.9, 1.7, z + 1.7), (0.10, 3.4, 0.10), M["metal_light"], 0.006)
        add(K.torus(prefix + "_ring", (x, 0.12, z), 1.55, 0.08, M["screen"], (0, 0, 0)))


def hollow_chair(prefix: str, x: float, z: float, rot_y: float = 0.0):
    # Reclined chair with a draped, faceless body.
    br(prefix + "_seat", (x, 0.44, z), (0.86, 0.10, 1.65), M["metal_light"], rot_y, 0.008)
    br(prefix + "_back", (x, 0.80, z - 0.72), (0.86, 0.90, 0.10), M["metal_light"], rot_y, 0.008)
    for side in (-1, 1):
        br(prefix + "_leg_%d" % side, (x + side * 0.34, 0.22, z ), (0.06, 0.44, 1.20), M["metal"], rot_y, 0.004)
        br(prefix + "_arm_%d" % side, (x + side * 0.44, 0.55, z - 0.36), (0.08, 0.10, 0.60), M["metal_light"], rot_y, 0.004)
    # Body under a sheet: torso, head, legs, sheet.
    br(prefix + "_torso", (x, 0.62, z - 0.10), (0.52, 0.28, 0.78), M["hollow"], rot_y, 0.04)
    add(K.sphere(prefix + "_head", (x, 0.84, z - 0.58), 0.18, M["hollow"], 16, 8))
    for side in (-1, 1):
        br(prefix + "_leg_%d" % side, (x + side * 0.16, 0.56, z + 0.58), (0.18, 0.14, 0.78), M["hollow"], rot_y, 0.04)
    br(prefix + "_sheet", (x, 0.78, z + 0.10), (0.80, 0.06, 1.65), M["white_dirty"], rot_y, 0.03)
    br(prefix + "_sheet_head", (x, 0.96, z - 0.60), (0.40, 0.04, 0.50), M["white_dirty"], rot_y, 0.02)


def gurney(prefix: str, x: float, z: float):
    b(prefix + "_frame", (x, 0.55, z), (0.9, 0.12, 2.0), M["metal_light"], 0.012)
    b(prefix + "_pad", (x, 0.66, z), (0.78, 0.12, 1.80), M["white_dirty"], 0.03)
    for side_x in (-1, 1):
        for side_z in (-1, 1):
            c(prefix + "_wheel_%d_%d" % (side_x, side_z), (x + side_x * 0.32, 0.16, z + side_z * 0.72), 0.12, 0.08, M["dark"], "X", 12, 0.003)
    for side in (-1, 1):
        b(prefix + "_rail_%d" % side, (x + side * 0.46, 0.92, z), (0.05, 0.10, 1.70), M["metal"], 0.003)


def light_strip(prefix: str, x: float, y: float, z: float, sx: float = 3.0, warm: bool = False):
    b(prefix, (x, y, z), (sx, 0.06, 0.16), M["lamp"] if warm else M["lamp_cold"], 0.003)


def floor_grid(prefix: str, center: tuple[float, float, float], size: tuple[float, float, float], spacing: float = 2.0):
    cx, cy, cz = center
    w, _, d = size
    lines_x = max(1, int(w / spacing))
    lines_z = max(1, int(d / spacing))
    for i in range(lines_x + 1):
        x = cx - w * 0.5 + i * (w / lines_x)
        b("%s_grid_x%d" % (prefix, i), (x, cy + 0.035, cz), (0.012, 0.006, d), M["grid"], 0.0)
    for j in range(lines_z + 1):
        z = cz - d * 0.5 + j * (d / lines_z)
        b("%s_grid_z%d" % (prefix, j), (cx, cy + 0.035, z), (w, 0.006, 0.012), M["grid"], 0.0)


def baseboard(prefix: str, center: tuple[float, float, float], size: tuple[float, float, float], sides: list[str]):
    cx, cy, cz = center
    w, _, d = size
    for side in sides:
        if side == "north":
            b(prefix + "_north", (cx, 0.10, cz - d * 0.5 + 0.04), (w, 0.20, 0.05), M["concrete_dark"], 0.004)
        elif side == "south":
            b(prefix + "_south", (cx, 0.10, cz + d * 0.5 - 0.04), (w, 0.20, 0.05), M["concrete_dark"], 0.004)
        elif side == "west":
            b(prefix + "_west", (cx - w * 0.5 + 0.04, 0.10, cz), (0.05, 0.20, d), M["concrete_dark"], 0.004)
        elif side == "east":
            b(prefix + "_east", (cx + w * 0.5 - 0.04, 0.10, cz), (0.05, 0.20, d), M["concrete_dark"], 0.004)


def vent(prefix: str, x: float, y: float, z: float, sx: float = 0.8):
    b(prefix + "_frame", (x, y, z), (sx, 0.35, 0.05), M["metal"], 0.004)
    for i in range(5):
        b(prefix + "_slat_%d" % i, (x, y + 0.13 - i * 0.06, z + 0.03), (sx * 0.85, 0.025, 0.02), M["dark"], 0.001)


def pipe(prefix: str, start, end, radius: float = 0.08):
    sx, sy, sz = start
    ex, ey, ez = end
    dx, dy, dz = ex - sx, ey - sy, ez - sz
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length < 0.01:
        return
    mid = ((sx + ex) * 0.5, (sy + ey) * 0.5, (sz + ez) * 0.5)
    if abs(dx) > abs(dz):
        obj = c(prefix, mid, radius, length, M["metal_light"], "X", 10, 0.003)
    elif abs(dz) > abs(dx):
        obj = c(prefix, mid, radius, length, M["metal_light"], "Z", 10, 0.003)
    else:
        obj = c(prefix, mid, radius, length, M["metal_light"], "Y", 10, 0.003)
    return obj


# ---------------------------------------------------------------------------
# rooms
# ---------------------------------------------------------------------------

def build_entry():
    K.room_shell(
        "Entry",
        (0, 0, 10),
        (8, 3.6, 6),
        3.6,
        M["white"],
        M["tile_wet"],
        M["white"],
        doors=[
            {"side": "south", "center": 0, "width": 3.2, "height": 3.0},
            {"side": "north", "center": 0, "width": 3.2, "height": 3.0},
        ],
    )
    # Glass entrance and canopy.
    b("EntryGlass", (0, 1.55, 13.02), (3.4, 3.0, 0.08), M["glass"], 0.006)
    for side in (-1, 1):
        b("EntryGlassMullion%d" % side, (side * 0.85, 1.55, 13.06), (0.06, 3.0, 0.06), M["metal"], 0.003)
    b("EntryHandleL", (-0.35, 1.15, 13.12), (0.05, 0.45, 0.05), M["metal_light"], 0.002)
    b("EntryHandleR", (0.35, 1.15, 13.12), (0.05, 0.45, 0.05), M["metal_light"], 0.002)
    b("EntryCanopy", (0, 3.55, 14.2), (8.0, 0.18, 2.6), M["concrete_dark"], 0.02)
    b("EntryCanopyGlow", (0, 3.44, 14.2), (6.8, 0.04, 2.0), M["lamp"], 0.003)
    for side in (-1, 1):
        c("EntryCanopyPost%d" % side, (side * 3.2, 1.75, 14.2), 0.10, 3.5, M["metal"], "Y", 10, 0.004)
    b("EntrySignFrame", (0, 2.9, 13.25), (3.0, 0.55, 0.08), M["metal"], 0.008)
    b("EntrySignGlow", (0, 2.9, 13.30), (2.6, 0.38, 0.02), M["screen"], 0.003)
    baseboard("EntryBase", (0, 0, 10), (8, 0.1, 6), ["east", "west"])
    # Reception, lockers, bench. The desk is offset so the doorway stays clear.
    desk("EntryDesk", -2.2, 9.6, 3.0, 0.0)
    monitor("EntryMonitor", -1.8, 1.15, 9.6, 0.0, True)
    terminal("EntryTerminal", -2.8, 9.6, 0.0)
    locker("EntryLockerA", -3.3, 8.8, (1.0, 0.0, 0.0))
    locker("EntryLockerB", -3.3, 9.8, (1.0, 0.0, 0.0))
    bench("EntryBench", 3.2, 10.2, (-1.0, 0.0, 0.0))
    b("EntryFloorMat", (0, 0.02, 11.8), (2.4, 0.04, 1.4), M["fabric"], 0.0)
    floor_grid("EntryGrid", (0, 0, 10), (8, 0.1, 6), 2.0)
    light_strip("EntryLight", 0, 3.45, 10.0, 4.0, True)
    vent("EntryVent", -2.6, 3.0, 13.0, 0.8)


def build_dormitory():
    K.room_shell(
        "Dorm",
        (0, 0, 0),
        (26, 4.2, 14),
        4.2,
        M["white"],
        M["tile"],
        M["white"],
        doors=[
            {"side": "south", "center": 0, "width": 3.2, "height": 3.0},
            {"side": "north", "center": 0, "width": 3.0, "height": 3.0},
            {"side": "west", "center": 0, "width": 3.0, "height": 3.0},
            {"side": "east", "center": 0, "width": 3.0, "height": 3.0},
        ],
    )
    baseboard("DormBase", (0, 0, 0), (26, 0.1, 14), ["north", "south"])
    # 12 capsules, 4 rows x 3 columns.
    idx = 1
    for row_x in (-7.8, -3.7, 3.7, 7.8):
        for col_z in (-4.6, 0.0, 4.6):
            capsule("Capsule%02d" % idx, row_x, col_z)
            idx += 1
    # Central aisle and floor markings.
    b("DormAisle", (0, 0.02, 0), (2.6, 0.04, 12.6), M["tile_wet"], 0.0)
    floor_grid("DormGrid", (0, 0, 0), (26, 0.1, 14), 2.0)
    for i in range(5):
        b("DormAisleMark%d" % i, (0, 0.05, -5.0 + i * 2.5), (0.10, 0.02, 1.4), M["metal_light"], 0.0)
    # Status board, lockers, benches.
    b("DormBoardFrame", (-8.0, 2.45, -6.55), (4.2, 1.5, 0.10), M["metal"], 0.015)
    b("DormBoardScreen", (-8.0, 2.45, -6.48), (3.8, 1.25, 0.03), M["screen"], 0.006)
    for i in range(5):
        b("DormBoardRow%d" % i, (-9.6 + i * 0.8, 2.45, -6.43), (0.04, 1.0, 0.01), M["screen_warm"], 0.0)
    for i in range(5):
        locker("DormLocker%d" % i, -10.0 + i * 1.0, 6.1, (0.0, 0.0, -1.0))
    bench("DormBenchA", -4.0, 5.2, (0.0, 0.0, -1.0))
    bench("DormBenchB", 4.0, 5.2, (0.0, 0.0, -1.0))
    # Ceiling strips and pipes.
    for i in range(5):
        x = -10.0 + i * 5.0
        light_strip("DormLightA%d" % i, x, 4.10, -3.2, 2.6)
        light_strip("DormLightB%d" % i, x, 4.10, 3.2, 2.6)
    for i in range(3):
        pipe("DormPipe%d" % i, (-12.0, 4.02, 6.0 + i * 0.18), (12.0, 4.02, 6.0 + i * 0.18), 0.06)
    for i in range(3):
        vent("DormVent%d" % i, -8.0 + i * 8.0, 3.2, 6.9, 0.7)


def build_connector(prefix: str, x: float):
    K.room_shell(
        prefix,
        (x, 0, 0),
        (2, 3.2, 4),
        3.2,
        M["white"],
        M["tile"],
        M["white"],
        doors=[
            {"side": "west", "center": 0, "width": 2.6, "height": 2.8},
            {"side": "east", "center": 0, "width": 2.6, "height": 2.8},
        ],
    )
    light_strip(prefix + "_light", x, 3.05, 0, 1.0)


def build_common():
    K.room_shell(
        "Common",
        (-20, 0, 0),
        (10, 3.6, 12),
        3.6,
        M["white"],
        M["wood_light"],
        M["white"],
        doors=[
            {"side": "east", "center": 0, "width": 2.6, "height": 2.8},
            {"side": "west", "center": 0, "width": 2.6, "height": 2.8},
        ],
    )
    baseboard("CommonBase", (-20, 0, 0), (10, 0.1, 12), ["north", "south"])
    table("CommonTable", -20, 0, 3.0, 1.3)
    for i in range(4):
        chair("CommonChairN%d" % i, -21.2 + i * 0.8, -1.2, (0.0, 0.0, 1.0))
        chair("CommonChairS%d" % i, -21.2 + i * 0.8, 1.2, (0.0, 0.0, -1.0))
    # Kitchenette on the north wall.
    b("CommonKitchenTop", (-20, 0.86, -5.3), (4.6, 0.10, 0.72), M["tile"], 0.01)
    b("CommonKitchenBase", (-20, 0.42, -5.3), (4.6, 0.84, 0.68), M["wood"], 0.01)
    b("CommonKitchenShelf", (-20, 2.35, -5.75), (4.2, 0.10, 0.32), M["wood"], 0.008)
    for i in range(4):
        c("CommonCup%d" % i, (-21.4 + i * 0.9, 1.02, -5.3), 0.07, 0.07, M["white"], "Y", 10, 0.002)
    b("CommonCooker", (-21.5, 1.02, -5.3), (0.55, 0.06, 0.45), M["dark"], 0.006)
    vending("CommonVending", -17.0, 4.8, 0.0)
    sofa("CommonSofa", -18.2, -4.6, 0.0)
    b("CommonTVFrame", (-18.2, 1.9, 5.9), (1.6, 0.9, 0.08), M["dark"], 0.01)
    b("CommonTVScreen", (-18.2, 1.9, 5.84), (1.45, 0.75, 0.02), M["screen"], 0.004)
    b("CommonRug", (-20, 0.03, 2.5), (4.0, 0.04, 2.2), M["fabric_blue"], 0.0)
    # A false window into a snowy park, matching the dorm's screen-window motif.
    b("CommonWindowFrame", (-24.96, 1.9, 0.0), (0.06, 1.8, 3.6), M["metal"], 0.006)
    b("CommonWindow", (-24.92, 1.9, 0.0), (0.02, 1.55, 3.25), M["screen"], 0.003)
    for i in range(3):
        b("CommonWindowMullion%d" % i, (-24.90, 1.9, -1.2 + i * 1.2), (0.02, 1.55, 0.05), M["metal"], 0.002)
    floor_grid("CommonGrid", (-20, 0, 0), (10, 0.1, 12), 2.0)
    light_strip("CommonLight", -20, 3.45, 0, 4.0, True)
    vent("CommonVent", -20, 3.0, -5.9, 0.8)


def build_showers():
    K.room_shell(
        "Showers",
        (20, 0, 0),
        (10, 3.6, 12),
        3.6,
        M["tile"],
        M["tile_wet"],
        M["tile"],
        doors=[{"side": "west", "center": 0, "width": 2.6, "height": 2.8}],
    )
    baseboard("ShowerBase", (20, 0, 0), (10, 0.1, 12), ["north", "south", "east"])
    for i in range(4):
        z = -4.2 + 2.8 * i
        shower_stall("ShowerWest%d" % i, 17.2, z, (1.0, 0.0, 0.0))
        shower_stall("ShowerEast%d" % i, 22.8, z, (-1.0, 0.0, 0.0))
    sink("ShowerSinkA", 20.0, 5.4, 0.0)
    sink("ShowerSinkB", 21.2, 5.4, 0.0)
    bench("ShowerBench", 20.0, -5.2, (0.0, 0.0, -1.0))
    locker("TowelLockerA", 16.6, 5.4, (1.0, 0.0, 0.0))
    locker("TowelLockerB", 16.6, 4.4, (1.0, 0.0, 0.0))
    for i in range(4):
        b("ShowerDrain%d" % i, (20, 0.03, -4.2 + i * 2.8), (0.5, 0.02, 0.5), M["metal"], 0.0)
    floor_grid("ShowerGrid", (20, 0, 0), (10, 0.1, 12), 2.0)
    light_strip("ShowerLight", 20, 3.45, 0, 4.0)
    vent("ShowerVent", 20, 3.05, 5.9, 0.8)


def build_observation():
    K.room_shell(
        "Observation",
        (0, 0, -10),
        (12, 3.4, 6),
        3.4,
        M["white"],
        M["concrete_dark"],
        M["concrete"],
        doors=[
            {"side": "south", "center": 0, "width": 3.0, "height": 3.0},
            {"side": "north", "center": 0, "width": 2.6, "height": 2.8},
        ],
    )
    baseboard("ObsBase", (0, 0, -10), (12, 0.1, 6), ["east", "west"])
    desk("ObsDesk", 0, -10.4, 7.0, 0.0)
    chair("ObsChairA", -2.2, -9.1, (0.0, 0.0, -1.0))
    chair("ObsChairB", 2.2, -9.1, (0.0, 0.0, -1.0))
    for i in range(2):
        monitor("ObsMonitor%d" % i, -2.2 + 4.4 * i, 1.25, -10.4, 0.0)
    # Two window bays into the dormitory, flanking the central door.
    for side in (-1, 1):
        wx = side * 3.7
        b("ObsWindow%d" % side, (wx, 1.65, -7.02), (3.4, 1.8, 0.06), M["glass"], 0.006)
        b("ObsWindowFrameT%d" % side, (wx, 2.62, -7.04), (3.6, 0.12, 0.08), M["metal"], 0.006)
        b("ObsWindowFrameB%d" % side, (wx, 0.68, -7.04), (3.6, 0.12, 0.08), M["metal"], 0.006)
        for i in range(3):
            b("ObsWindowMullion%d%d" % (side, i), (wx - 1.1 + i * 1.1, 1.65, -7.05), (0.06, 1.8, 0.05), M["metal"], 0.003)
    # Wall screen and lockers.
    b("ObsScreenFrame", (0, 2.35, -12.9), (7.2, 1.5, 0.08), M["dark"], 0.01)
    b("ObsScreenGlow", (0, 2.35, -12.84), (6.8, 1.2, 0.02), M["dark"], 0.004)
    b("ObsScreenLine", (0, 1.82, -12.80), (6.4, 0.05, 0.02), M["screen"], 0.002)
    for i in range(4):
        monitor("ObsFeed%d" % i, -2.55 + i * 1.7, 2.35, -12.80, 0.0)
    locker("ObsLocker", 5.3, -12.2, (-1.0, 0.0, 0.0))
    floor_grid("ObsGrid", (0, 0, -10), (12, 0.1, 6), 2.0)
    light_strip("ObsLight", 0, 3.25, -10, 4.0)
    vent("ObsVent", 0, 3.05, -12.9, 0.8)


def build_medical():
    K.room_shell(
        "Medical",
        (0, 0, -16),
        (4, 3.2, 6),
        3.2,
        M["white"],
        M["tile_wet"],
        M["white"],
        doors=[
            {"side": "south", "center": 0, "width": 2.6, "height": 2.8},
            {"side": "north", "center": 0, "width": 2.6, "height": 2.8},
            {"side": "east", "center": -2.0, "width": 2.0, "height": 2.6},
        ],
    )
    baseboard("MedBase", (0, 0, -16), (4, 0.1, 6), ["west"])
    gurney("MedGurney", -0.7, -16.0)
    b("MedCabinet", (1.6, 0.95, -14.1), (0.55, 1.9, 0.45), M["white_dirty"], 0.01)
    b("MedCabinetGlass", (1.6, 1.15, -13.86), (0.42, 1.1, 0.02), M["glass"], 0.003)
    for i in range(3):
        b("MedShelf%d" % i, (1.6, 0.75 + i * 0.42, -14.1), (0.46, 0.03, 0.34), M["metal"], 0.002)
    b("MedSanitizer", (1.9, 1.25, -13.0), (0.18, 0.35, 0.12), M["white"], 0.004)
    b("MedSignFrame", (0, 2.5, -19.05), (2.0, 0.35, 0.06), M["metal"], 0.006)
    b("MedSignGlow", (0, 2.5, -19.0), (1.7, 0.24, 0.02), M["screen"], 0.003)
    floor_grid("MedGrid", (0, 0, -16), (4, 0.1, 6), 2.0)
    light_strip("MedLight", 0, 3.05, -16, 2.0)
    vent("MedVent", 0, 2.95, -18.9, 0.6)


def build_hollow_gallery():
    K.room_shell(
        "Hollow",
        (8, 0, -20),
        (12, 3.6, 8),
        3.6,
        M["white"],
        M["tile"],
        M["white"],
        doors=[{"side": "west", "center": 2.0, "width": 2.0, "height": 2.6}],
    )
    baseboard("HollowBase", (8, 0, -20), (12, 0.1, 8), ["north", "east", "south"])
    # 4 x 4 reclined chairs with draped bodies.
    idx = 0
    for row in range(4):
        for col in range(4):
            x = 4.0 + col * 2.5
            z = -22.4 + row * 1.7
            hollow_chair("HollowChair%02d" % idx, x, z, 0.0)
            idx += 1
    # Central aisle.
    b("HollowAisle", (8, 0.02, -20), (1.4, 0.04, 7.6), M["tile_wet"], 0.0)
    # Memorial wall and screen.
    b("HollowMemorial", (13.85, 1.6, -20), (0.08, 2.4, 7.0), M["white_dirty"], 0.006)
    for i in range(8):
        b("HollowPlaque%d" % i, (13.78, 0.9 + (i % 4) * 0.55, -22.2 + (i // 4) * 3.8 + (i % 4) * 0.2), (0.02, 0.30, 0.70), M["metal"], 0.002)
    b("HollowScreenFrame", (8, 2.4, -23.9), (6.0, 1.4, 0.08), M["dark"], 0.01)
    b("HollowScreenGlow", (8, 2.4, -23.84), (5.6, 1.1, 0.02), M["screen"], 0.004)
    # Flowers and cold light strips.
    for i in range(3):
        b("HollowVase%d" % i, (2.6, 0.65, -23.2 + i * 2.2), (0.22, 0.35, 0.22), M["white"], 0.01)
        c("HollowFlower%d" % i, (2.6, 1.05, -23.2 + i * 2.2), 0.10, 0.30, M["fabric_blue"], "Y", 8, 0.004)
    floor_grid("HollowGrid", (8, 0, -20), (12, 0.1, 8), 2.0)
    light_strip("HollowLightA", 8, 3.42, -21.5, 5.0)
    light_strip("HollowLightB", 8, 3.42, -18.5, 5.0)
    vent("HollowVent", 8, 3.05, -23.8, 1.0)


def build_dream_ward():
    K.room_shell(
        "Dream",
        (0, 0, -24),
        (12, 3.8, 10),
        3.8,
        M["white"],
        M["tile_wet"],
        M["concrete"],
        doors=[{"side": "south", "center": 0, "width": 2.6, "height": 2.8}],
    )
    baseboard("DreamBase", (0, 0, -24), (12, 0.1, 10), ["north", "east", "west"])
    bed("DreamBedWest", -3.7, -25.5, False)
    bed("DreamBedEast", 3.7, -25.5, False)
    bed("DreamBedCenter", 0, -25.5, True)
    # Capsule ring, canopy, monitors, terminal.
    b("DreamHeader", (0, 2.9, -28.85), (6.0, 0.5, 0.08), M["metal"], 0.01)
    b("DreamHeaderGlow", (0, 2.9, -28.79), (5.6, 0.34, 0.02), M["screen"], 0.003)
    b("DreamMonitor", (5.0, 1.4, -20.3), (0.06, 1.0, 1.8), M["metal"], 0.01)
    b("DreamMonitorGlow", (4.96, 1.4, -20.3), (0.02, 0.84, 1.56), M["screen"], 0.003)
    terminal("DreamTerminal", 4.2, -20.3, -math.pi * 0.5)
    bench("DreamBench", -4.2, -20.3, (0.0, 0.0, -1.0))
    for i in range(3):
        monitor("DreamAuxMonitor%d" % i, -1.2 + i * 1.2, 1.6, -28.0, 0.0)
    # Glass panel on the east wall and cables.
    b("DreamGlass", (5.96, 1.7, -24.0), (0.06, 1.8, 8.0), M["glass"], 0.006)
    for i in range(4):
        b("DreamGlassMullion%d" % i, (5.92, 1.7, -26.8 + i * 1.9), (0.05, 1.8, 0.06), M["metal"], 0.003)
    for i in range(3):
        c("DreamCable%d" % i, (-5.0 + i * 5.0, 0.10, -26.5), 0.04, 0.20, M["dark"], "Y", 8, 0.002)
    floor_grid("DreamGrid", (0, 0, -24), (12, 0.1, 10), 2.0)
    light_strip("DreamLightA", 0, 3.62, -26.0, 4.0)
    light_strip("DreamLightB", 0, 3.62, -21.5, 4.0)
    vent("DreamVent", 0, 3.1, -28.9, 0.8)


def build_residential():
    # Connector from the common room.
    K.room_shell(
        "ResConnector",
        (-26.5, 0, 0),
        (3, 3.2, 4),
        3.2,
        M["white"],
        M["tile"],
        M["white"],
        doors=[
            {"side": "east", "center": 0, "width": 2.6, "height": 2.8},
            {"side": "west", "center": 0, "width": 2.6, "height": 2.8},
        ],
    )
    # Long residential corridor.
    K.room_shell(
        "ResCorridor",
        (-30, 0, 0),
        (4, 3.2, 28),
        3.2,
        M["white"],
        M["tile"],
        M["white"],
        doors=[
            {"side": "east", "center": 0, "width": 2.6, "height": 2.8},
            {"side": "west", "center": -8.6, "width": 2.0, "height": 2.8},
        ],
    )
    # Corridor doors on the west wall: room 07 open, others closed.
    for i in range(8):
        z = -12.0 + i * 3.4
        if i == 1:
            # Room 07 doorway (open).
            b("ResDoorFrame07L", (-31.9, 1.4, z - 1.0), (0.24, 2.8, 0.12), M["metal"], 0.006)
            b("ResDoorFrame07R", (-31.9, 1.4, z + 1.0), (0.24, 2.8, 0.12), M["metal"], 0.006)
            b("ResDoorFrame07T", (-31.9, 2.85, z), (0.24, 0.12, 2.12), M["metal"], 0.006)
            continue
        b("ResDoorPanel%d" % i, (-31.94, 1.2, z), (0.06, 2.3, 0.95), M["metal"], 0.004)
        b("ResDoorHandle%d" % i, (-31.90, 1.1, z + 0.32), (0.04, 0.16, 0.04), M["metal_light"], 0.002)
        b("ResDoorNumber%d" % i, (-31.90, 2.15, z), (0.04, 0.16, 0.24), M["screen_warm"], 0.002)
    # Room 07.
    K.room_shell(
        "Room07",
        (-35, 0, -8.6),
        (6, 3.2, 6),
        3.2,
        M["white"],
        M["wood_light"],
        M["white"],
        doors=[{"side": "east", "center": 0, "width": 2.0, "height": 2.8}],
    )
    baseboard("Room07Base", (-35, 0, -8.6), (6, 0.1, 6), ["north", "south", "west"])
    bed("Room07Bed", -35.0, -9.4, False)
    desk("Room07Desk", -36.6, -6.6, 2.0, 0.0)
    chair("Room07Chair", -36.6, -7.7, (0.0, 0.0, -1.0))
    locker("Room07Locker", -32.8, -6.6, (-1.0, 0.0, 0.0))
    b("Room07Mirror", (-32.8, 1.5, -9.0), (0.05, 0.9, 0.7), M["glass"], 0.004)
    b("Room07ScreenFrame", (-35.0, 2.25, -5.72), (2.4, 0.9, 0.06), M["dark"], 0.006)
    b("Room07ScreenGlow", (-35.0, 2.25, -5.68), (2.2, 0.75, 0.02), M["screen"], 0.003)
    b("Room07Shelf", (-35.0, 1.95, -11.45), (2.2, 0.08, 0.35), M["wood"], 0.006)
    b("Room07Rug", (-35.0, 0.03, -8.3), (3.0, 0.04, 3.0), M["fabric_blue"], 0.0)
    light_strip("Room07Light", -35, 3.05, -8.6, 2.0, True)
    # Laundry room at the north end.
    K.room_shell(
        "Laundry",
        (-25, 0, 9),
        (6, 3.2, 6),
        3.2,
        M["white"],
        M["tile_wet"],
        M["white"],
        doors=[{"side": "west", "center": 0, "width": 1.2, "height": 2.4}],
    )
    # The laundry is accessible from the residential corridor; this is where
    # the side-quest ventilation/bin props live.
    b("ResLaundrySign", (-27.9, 2.55, 9.0), (0.06, 0.30, 1.0), M["screen_warm"], 0.003)
    baseboard("LaundryBase", (-25, 0, 9), (6, 0.1, 6), ["north", "south", "east", "west"])
    for i in range(2):
        b("Washer%d" % i, (-26.4 + i * 1.2, 0.65, 10.2), (0.9, 1.1, 0.9), M["white_dirty"], 0.02)
        b("WasherGlass%d" % i, (-26.4 + i * 1.2, 0.75, 10.66), (0.6, 0.5, 0.03), M["glass"], 0.006)
        b("WasherPanel%d" % i, (-26.4 + i * 1.2, 1.25, 10.66), (0.6, 0.18, 0.03), M["screen"], 0.003)
    for i in range(3):
        b("LaundryBasket%d" % i, (-22.8, 0.35, 7.4 + i * 1.1), (0.7, 0.7, 0.7), M["fabric"], 0.03)
    b("LaundryShelf", (-22.6, 1.8, 10.4), (0.7, 0.06, 2.2), M["metal"], 0.004)
    light_strip("LaundryLight", -25, 3.05, 9, 2.0)
    floor_grid("ResGrid", (-30, 0, 0), (4, 0.1, 28), 2.0)
    floor_grid("Room07Grid", (-35, 0, -8.6), (6, 0.1, 6), 2.0)
    # Corridor ceiling lights.
    for i in range(6):
        light_strip("ResLight%d" % i, -30, 3.05, -12.0 + i * 4.5, 1.2)


# ---------------------------------------------------------------------------
# building shell / exterior glimpse
# ---------------------------------------------------------------------------

def build_shell():
    # A partial exterior facade around the entrance, so the building reads as
    # a building and not a floating room set.
    b("FacadeBand", (0, 5.0, 15.0), (28, 8.0, 0.5), M["white"], 0.03)
    b("FacadeGlass", (0, 2.8, 15.25), (10, 5.6, 0.2), M["glass"], 0.01)
    for i in range(5):
        b("FacadeMullion%d" % i, (-4.0 + i * 2.0, 2.8, 15.36), (0.10, 5.6, 0.08), M["metal"], 0.004)
    b("FacadeCanopy", (0, 5.4, 16.2), (16, 0.3, 3.0), M["concrete_dark"], 0.02)
    for side in (-1, 1):
        b("FacadeWing%d" % side, (side * 17.0, 4.0, 15.0), (10, 6.0, 0.5), M["white_dirty"], 0.03)
    b("FacadeStep", (0, 0.15, 16.2), (14, 0.3, 2.0), M["concrete"], 0.01)
    # Snow apron.
    b("ExteriorSnow", (0, -0.3, 18.0), (40, 0.6, 8), M["snow"], 0.1)


# ---------------------------------------------------------------------------
# build
# ---------------------------------------------------------------------------

build_shell()
build_entry()
build_dormitory()
build_connector("DormWestConnector", -14)
build_connector("DormEastConnector", 14)
build_common()
build_showers()
build_observation()
build_medical()
build_hollow_gallery()
build_dream_ward()
build_residential()

K.export_glb(OBJECTS, os.path.join(K.OUT, "academy_sleeper_center.glb"))
print("Sleeper Center complete:", len(bpy.data.objects), "objects")
