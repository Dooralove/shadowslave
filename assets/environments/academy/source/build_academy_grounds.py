"""Academy Grounds — standalone exterior location.

Builds a 260 x 320 m walled campus: approach road, moat and drawbridge,
red gate, perimeter wall and turrets, central glass gallery, Sleeper Center,
Dining Hall, Dojo, Academic Wing, Medical Center, winter landscaping and a
distant city skyline. No gameplay, no portals, no NPCs.

Run:
  blender -b --python assets/environments/academy/source/build_academy_grounds.py
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
# ground and approach
# ---------------------------------------------------------------------------

def build_ground():
    b("GroundSnow", (0, -0.6, 0), (3000, 1.2, 3000), M["snow"], 0.0)
    b("ApproachAsphalt", (0, -0.08, 110), (24, 0.16, 64), M["concrete_dark"], 0.0)
    b("ApproachWalkWest", (-15.5, -0.06, 110), (5, 0.12, 64), M["concrete"], 0.0)
    b("ApproachWalkEast", (15.5, -0.06, 110), (5, 0.12, 64), M["concrete"], 0.0)
    # lane markings
    for i in range(9):
        z = 84 + i * 6.0
        b("LaneDash%d" % i, (0, 0.01, z), (0.22, 0.02, 2.2), M["white_dirty"], 0.0)
    for side in (-1, 1):
        b("Curb%s" % side, (side * 12.6, 0.08, 110), (0.5, 0.2, 64), M["concrete"], 0.01)
        for i in range(8):
            z = 82 + i * 8.0
            b("BollardBase%s%d" % (side, i), (side * 13.6, 0.55, z), (0.22, 1.1, 0.22), M["metal"], 0.01)
            b("BollardGlow%s%d" % (side, i), (side * 13.6, 1.02, z), (0.24, 0.08, 0.24), M["lamp_cold"], 0.005)
    # snow banks along the road
    for side in (-1, 1):
        for i in range(6):
            z = 86 + i * 10.0
            b("SnowBank%s%d" % (side, i), (side * 19.0, 0.35, z), (6.0, 0.7, 6.0), M["snow"], 0.18)
    # checkpoint island
    b("CheckpointIsland", (0, 0.04, 95), (30, 0.18, 14), M["concrete"], 0.02)
    for side in (-1, 1):
        b("CheckpointBooth%s" % side, (side * 9.0, 1.55, 95), (5.2, 3.1, 4.2), M["concrete_dark"], 0.03)
        b("CheckpointBoothRoof%s" % side, (side * 9.0, 3.25, 95), (5.8, 0.3, 4.8), M["metal"], 0.02)
        b("CheckpointWindow%s" % side, (side * 6.35, 1.8, 95), (0.08, 1.0, 2.4), M["glass"], 0.005)
        b("CheckpointGlow%s" % side, (side * 6.30, 2.75, 95), (0.05, 0.12, 3.4), M["lamp_cold"], 0.003)
        c("CheckpointBarrierPost%s" % side, (side * 6.0, 0.65, 98.5), 0.16, 1.3, M["metal"], "Y", 12, 0.006)
    b("CheckpointBarrier", (0, 1.05, 98.5), (12.0, 0.14, 0.14), M["red"], 0.005)
    b("CheckpointLintel", (0, 4.4, 95), (24, 0.5, 0.6), M["metal"], 0.02)
    for i in range(5):
        b("CheckpointLight%d" % i, (-10 + i * 5.0, 4.12, 95), (0.4, 0.08, 0.18), M["lamp"], 0.003)
    # approach lamps
    for side in (-1, 1):
        for i in range(4):
            K.lamp("ApproachLamp%s%d" % (side, i), (side * 14.5, 0, 84 + i * 15.0), 6.0, warm=False)
    # distant road continuation and warm windows
    b("ApproachFarRoad", (0, -0.08, 150), (24, 0.16, 40), M["concrete_dark"], 0.0)
    for side in (-1, 1):
        for i in range(3):
            b("ApproachFarBlock%s%d" % (side, i), (side * 32, 9.0, 112 + i * 18), (22, 18, 16), M["concrete_dark"], 0.02)
            for row in range(3):
                b("ApproachFarWin%s%d%d" % (side, i, row), (side * 20.95, 4.0 + row * 4.0, 112 + i * 18), (0.05, 1.4, 8.0), M["screen_warm"], 0.0)


# ---------------------------------------------------------------------------
# moat, drawbridge and gate
# ---------------------------------------------------------------------------

def build_gate():
    # Moat: a dark recess with water strips.
    b("MoatBed", (0, -3.2, 84), (170, 0.4, 12), M["concrete_dark"], 0.0)
    b("MoatWater", (0, -1.2, 84), (168, 0.08, 10.5), M["glass"], 0.0)
    for side in (-1, 1):
        b("MoatWall%s" % side, (side * 85, -1.5, 84), (0.6, 3.4, 12), M["concrete_dark"], 0.01)
    # Drawbridge: steel plate with ribs, raised slightly above the road.
    b("Drawbridge", (0, 0.18, 78.5), (18, 0.36, 14), M["metal"], 0.02)
    for i in range(7):
        b("DrawbridgeRib%d" % i, (-8.0 + i * 2.66, 0.40, 78.5), (0.22, 0.12, 13.6), M["metal_light"], 0.008)
    for side in (-1, 1):
        b("DrawbridgeEdge%s" % side, (side * 9.0, 0.55, 78.5), (0.18, 0.55, 14), M["metal_light"], 0.01)
        for i in range(4):
            b("DrawbridgeChain%s%d" % (side, i), (side * 9.4, 2.2, 74.0 + i * 2.2), (0.08, 3.6, 0.08), M["metal"], 0.004)
    # Gate wall, split around the 20 m opening.
    K.wall_segment("GateWallWest", (-45.0, 0, 70), 70.0, 12.0, 2.4, True)
    K.wall_segment("GateWallEast", (45.0, 0, 70), 70.0, 12.0, 2.4, True)
    # Add the objects created by wall_segment to the export list.
    for name_prefix in ("GateWallWest", "GateWallEast"):
        for obj in bpy.data.objects:
            if obj.name.startswith(name_prefix) and obj not in OBJECTS and obj.type == "MESH":
                OBJECTS.append(obj)
    # Gate towers.
    for side in (-1, 1):
        x = side * 15.0
        b("GateTower%s" % side, (x, 13.0, 70), (12, 26, 12), M["concrete_dark"], 0.04)
        b("GateTowerCap%s" % side, (x, 26.2, 70), (13, 0.6, 13), M["concrete"], 0.03)
        b("GateTowerBand%s" % side, (x, 8.2, 70), (12.6, 0.5, 12.6), M["concrete"], 0.02)
        b("GateTowerBand2%s" % side, (x, 18.2, 70), (12.6, 0.5, 12.6), M["concrete"], 0.02)
        # narrow vertical windows on both the inner and outer faces
        for row in range(4):
            for col in range(2):
                b("GateTowerWinIn%s%d%d" % (side, row, col), (x - 2.4 + col * 4.8, 6.5 + row * 4.8, 63.95), (1.2, 2.2, 0.08), M["glass"], 0.006)
                b("GateTowerWinOut%s%d%d" % (side, row, col), (x - 2.4 + col * 4.8, 6.5 + row * 4.8, 76.05), (1.2, 2.2, 0.08), M["glass"], 0.006)
        b("GateTowerGlow%s" % side, (x, 25.0, 63.9), (10.0, 0.18, 0.08), M["lamp_cold"], 0.004)
        b("GateTowerGlowOut%s" % side, (x, 25.0, 76.1), (10.0, 0.18, 0.08), M["lamp_cold"], 0.004)
        # A shallow vertical service seam breaks up the outer face.
        b("GateTowerSeam%s" % side, (x, 13.0, 76.08), (0.18, 26.0, 0.06), M["concrete"], 0.004)
        K.turret("GateTurret%s" % side, (x, 26.4, 70), 3.0)
        for obj in bpy.data.objects:
            if obj.name.startswith("GateTurret%s" % side) and obj not in OBJECTS and obj.type == "MESH":
                OBJECTS.append(obj)
    # Gate arch / lintel.
    b("GateLintel", (0, 14.2, 70), (22, 2.6, 3.0), M["concrete_dark"], 0.03)
    b("GateLintelCap", (0, 15.7, 70), (23, 0.4, 3.4), M["concrete"], 0.02)
    b("GateArchTrim", (0, 12.4, 68.55), (22, 0.5, 0.2), M["red"], 0.01)
    # Academy star / emblem above the gate.
    add(K.torus("GateEmblemOuter", (0, 17.0, 70.1), 2.6, 0.12, M["metal_light"]))
    add(K.torus("GateEmblemInner", (0, 17.0, 70.1), 1.7, 0.08, M["red"]))
    add(K.torus("GateEmblemStar", (0, 17.0, 70.1), 0.7, 0.06, M["lamp"]))
    # Red gate leaves: open inward, with ribs and warning edges.
    for side in (-1, 1):
        x = side * 5.0
        br("GateLeaf%s" % side, (x, 6.0, 69.0), (9.6, 12.0, 0.8), M["red"], side * 0.10, 0.03)
        for i in range(5):
            br("GateLeafRib%s%d" % (side, i), (x - 3.4 + i * 1.7, 6.0, 68.55), (0.26, 11.0, 0.18), M["red_dark"], side * 0.10, 0.008)
        br("GateLeafEdge%s" % side, (x, 6.0, 68.5), (9.8, 0.22, 0.18), M["metal_light"], side * 0.10, 0.006)
        for i in range(3):
            br("GateLeafStud%s%d" % (side, i), (x, 2.0 + i * 4.0, 68.5), (8.0, 0.18, 0.18), M["metal"], side * 0.10, 0.006)
    # Gate floodlights and warning lamps.
    for side in (-1, 1):
        for i in range(3):
            b("GateFlood%s%d" % (side, i), (side * 7.0, 10.0 + i * 1.2, 72.0), (0.7, 0.24, 0.5), M["lamp"], 0.006)
    b("GateWarningBar", (0, 11.2, 68.4), (18, 0.16, 0.12), M["alarm"], 0.004)
    for i in range(9):
        b("GateWarningLamp%d" % i, (-8.0 + i * 2.0, 11.0, 68.35), (0.16, 0.16, 0.1), M["alarm"], 0.002)
    # Security barriers and inspection lane.
    for side in (-1, 1):
        for i in range(3):
            b("GateBarrier%s%d" % (side, i), (side * (10.5 + i * 1.6), 0.75, 75.0), (0.18, 1.5, 0.18), M["metal"], 0.006)
        b("GateBarrierRail%s" % side, (side * 12.1, 1.4, 75.0), (4.6, 0.08, 0.08), M["metal_light"], 0.004)
    b("GateInspectionIsland", (0, 0.06, 75.0), (15, 0.16, 3.0), M["concrete"], 0.01)


# ---------------------------------------------------------------------------
# perimeter wall and turrets
# ---------------------------------------------------------------------------

def build_perimeter():
    # West and east walls, 10 m high, segmented.
    for side in (-1, 1):
        x = side * 80.0
        z = -5.0
        for i in range(8):
            zz = 60.0 - i * 20.0
            K.wall_segment("Perimeter%s%d" % (side, i), (x, 0, zz), 20.0, 10.0, 1.8, False)
        for obj in bpy.data.objects:
            if obj.name.startswith("Perimeter%s" % side) and obj not in OBJECTS and obj.type == "MESH":
                OBJECTS.append(obj)
        for i in range(4):
            K.turret("PerimeterTurret%s%d" % (side, i), (x, 10.2, 55.0 - i * 40.0), 3.2)
        for obj in bpy.data.objects:
            if obj.name.startswith("PerimeterTurret%s" % side) and obj not in OBJECTS and obj.type == "MESH":
                OBJECTS.append(obj)
    # North wall.
    for i in range(8):
        xx = -70.0 + i * 20.0
        K.wall_segment("NorthWall%d" % i, (xx, 0, -80.0), 20.0, 10.0, 1.8, True)
    for obj in bpy.data.objects:
        if obj.name.startswith("NorthWall") and obj not in OBJECTS and obj.type == "MESH":
            OBJECTS.append(obj)
    for i in range(3):
        K.turret("NorthTurret%d" % i, (-50.0 + i * 50.0, 10.2, -80.0), 3.2)
    for obj in bpy.data.objects:
        if obj.name.startswith("NorthTurret") and obj not in OBJECTS and obj.type == "MESH":
            OBJECTS.append(obj)
    # Wall-walk rails and red warning strips.
    for side in (-1, 1):
        for i in range(8):
            zz = 60.0 - i * 20.0
            K.railing("WallRail%s%d" % (side, i), (side * 78.9, 10.1, zz + 8.0), (side * 78.9, 10.1, zz - 8.0), 1.1, M["metal"], 5)
    for obj in bpy.data.objects:
        if obj.name.startswith("WallRail") and obj not in OBJECTS and obj.type == "MESH":
            OBJECTS.append(obj)
    # Air dome (visual shield).
    add(K.sphere("AirDome", (0, 0, -5), 155.0, M["dome"], 48, 24))


# ---------------------------------------------------------------------------
# central gallery
# ---------------------------------------------------------------------------

def build_gallery():
    # Long covered walkway from the gate to the Sleeper Center.
    for i in range(9):
        z = 45.0 - i * 8.0
        for side in (-1, 1):
            x = side * 7.0
            c("GalleryColumn%s%d" % (side, i), (x, 4.5, z), 0.28, 9.0, M["white"], "Y", 16, 0.012)
            b("GalleryColumnBase%s%d" % (side, i), (x, 0.35, z), (0.9, 0.7, 0.9), M["concrete"], 0.02)
            b("GalleryColumnCap%s%d" % (side, i), (x, 8.75, z), (1.0, 0.35, 1.0), M["metal_light"], 0.012)
        b("GalleryBeamX%d" % i, (0, 9.0, z), (15.0, 0.45, 0.45), M["metal_light"], 0.02)
    # Glass roof and ridge.
    b("GalleryRoof", (0, 9.3, 13.0), (14.6, 0.22, 64.0), M["glass"], 0.02)
    b("GalleryRidge", (0, 9.5, 13.0), (0.6, 0.3, 64.0), M["metal"], 0.02)
    for side in (-1, 1):
        b("GalleryRoofEdge%s" % side, (side * 7.2, 9.35, 13.0), (0.3, 0.35, 64.0), M["metal_light"], 0.02)
    # Warm light strips under the roof.
    for i in range(9):
        z = 45.0 - i * 8.0
        b("GalleryLight%s" % i, (0, 8.6, z), (5.6, 0.06, 0.22), M["lamp"], 0.004)
    # Benches and planters along the sides.
    for i in range(5):
        z = 38.0 - i * 13.0
        K.bench("GalleryBenchW%d" % i, (-10.2, 0, z), 3.4, math.pi * 0.5)
        K.bench("GalleryBenchE%d" % i, (10.2, 0, z), 3.4, -math.pi * 0.5)
    for i in range(4):
        z = 40.0 - i * 16.0
        K.planter("GalleryPlanterW%d" % i, (-12.5, 0, z), 2.2, 3.8)
        K.planter("GalleryPlanterE%d" % i, (12.5, 0, z), 2.2, 3.8)
    # Directional floor inlay.
    b("GalleryInlay", (0, 0.02, 13.0), (4.0, 0.04, 62.0), M["tile"], 0.0)
    for i in range(8):
        b("GalleryMarker%d" % i, (0, 0.05, 42.0 - i * 8.0), (2.4, 0.03, 0.2), M["metal_light"], 0.0)


# ---------------------------------------------------------------------------
# campus buildings
# ---------------------------------------------------------------------------

def build_sleeper_center():
    # Plinth and broad steps.
    b("SleeperPlinth", (0, 0.7, -70), (74, 1.4, 50), M["concrete"], 0.03)
    K.stairs("SleeperSteps", (0, 0, -47.5), 26.0, 1.4, 5.0, 7, M["concrete"])
    for obj in bpy.data.objects:
        if obj.name.startswith("SleeperSteps") and obj not in OBJECTS and obj.type == "MESH":
            OBJECTS.append(obj)
    # Main mass. Cut a real entrance recess so the lobby behind the glass is
    # visible instead of reading as a black hole.
    sleeper_mass = b("SleeperMass", (0, 10.7, -70), (64, 20, 40), M["white"], 0.05)
    cutter = add(K.box("SleeperEntranceCutter", (0, 5.6, -54.0), (18, 11.2, 10.0), M["dark"], 0.0))
    bpy.context.view_layer.objects.active = sleeper_mass
    boolean = sleeper_mass.modifiers.new("EntranceRecess", "BOOLEAN")
    boolean.operation = "DIFFERENCE"
    boolean.object = cutter
    bpy.ops.object.modifier_apply(modifier=boolean.name)
    if cutter in OBJECTS:
        OBJECTS.remove(cutter)
    bpy.data.objects.remove(cutter, do_unlink=True)
    b("SleeperBaseBand", (0, 1.8, -70), (66, 0.8, 42), M["concrete_dark"], 0.03)
    b("SleeperRoof", (0, 21.1, -70), (66, 0.8, 42), M["concrete"], 0.03)
    # Central glass notch / entrance.
    b("SleeperEntranceGlass", (0, 6.0, -49.8), (16, 10.0, 0.4), M["glass_clear"], 0.02)
    b("SleeperEntranceFrame", (0, 11.2, -49.6), (17.5, 0.6, 0.6), M["metal"], 0.02)
    for side in (-1, 1):
        b("SleeperEntranceFrameSide%s" % side, (side * 8.4, 5.8, -49.6), (0.6, 11.0, 0.6), M["metal"], 0.02)
    b("SleeperCanopy", (0, 6.2, -46.8), (24, 0.35, 7.0), M["concrete_dark"], 0.03)
    b("SleeperCanopyGlow", (0, 6.0, -46.8), (20, 0.06, 5.4), M["lamp_cold"], 0.004)
    for side in (-1, 1):
        c("SleeperCanopyPost%s" % side, (side * 9.8, 3.1, -46.8), 0.16, 6.2, M["metal"], "Y", 12, 0.008)
    # Horizontal window bands and vertical fins.
    for floor in range(4):
        y = 4.0 + floor * 4.6
        for side in (-1, 1):
            x = side * 32.15
            b("SleeperWinBand%s%d" % (side, floor), (x, y, -70), (0.08, 1.7, 32.0), M["glass"], 0.005)
            b("SleeperWinFrame%s%d" % (side, floor), (x - side * 0.03, y + 0.95, -70), (0.1, 0.18, 32.4), M["metal"], 0.006)
            b("SleeperWinFrame2%s%d" % (side, floor), (x - side * 0.03, y - 0.95, -70), (0.1, 0.18, 32.4), M["metal"], 0.006)
        b("SleeperFrontBand%d" % floor, (0, y, -49.75), (48, 1.7, 0.08), M["glass"], 0.005)
        b("SleeperFrontFrame%d" % floor, (0, y + 0.95, -49.7), (48.4, 0.18, 0.1), M["metal"], 0.006)
        b("SleeperFrontFrameB%d" % floor, (0, y - 0.95, -49.7), (48.4, 0.18, 0.1), M["metal"], 0.006)
    for side in (-1, 1):
        for i in range(5):
            x = side * (10.0 + i * 5.2)
            b("SleeperFin%s%d" % (side, i), (x, 11.0, -49.55), (0.28, 19.0, 0.35), M["white_dirty"], 0.008)
    # Side wings.
    for side in (-1, 1):
        b("SleeperWing%s" % side, (side * 44.0, 8.0, -70), (24, 16, 34), M["white_dirty"], 0.04)
        b("SleeperWingRoof%s" % side, (side * 44.0, 16.1, -70), (25, 0.5, 35), M["concrete"], 0.02)
        for floor in range(3):
            b("SleeperWingWin%s%d" % (side, floor), (side * 31.9, 4.5 + floor * 4.4, -70), (0.08, 1.4, 24.0), M["glass"], 0.005)
    # Roof mechanicals.
    for i in range(5):
        b("SleeperRoofUnit%d" % i, (-22.0 + i * 11.0, 22.1, -78.0), (5.0, 1.8, 4.0), M["metal"], 0.02)
        for j in range(3):
            c("SleeperRoofFan%d%d" % (i, j), (-23.4 + i * 11.0 + j * 1.4, 23.1, -78.0), 0.55, 0.25, M["metal_light"], "Y", 16, 0.006)
    # Sign frame above the entrance (text is added in Godot).
    b("SleeperSignFrame", (0, 12.8, -49.5), (20, 1.2, 0.35), M["metal"], 0.02)
    b("SleeperSignGlow", (0, 12.8, -49.3), (18.5, 0.9, 0.08), M["screen"], 0.006)
    # Shallow illuminated lobby behind the glass: the exterior camera must not
    # look into a black void. The full interior is a separate scene.
    b("LobbyFloor", (0, 1.46, -54.0), (16, 0.12, 8.0), M["tile"], 0.0)
    b("LobbyBack", (0, 4.40, -58.0), (16, 6.0, 0.3), M["white"], 0.01)
    b("LobbyCeiling", (0, 7.40, -54.0), (16, 0.3, 8.0), M["white"], 0.01)
    for side in (-1, 1):
        b("LobbySide%s" % side, (side * 8.0, 4.40, -54.0), (0.3, 6.0, 8.0), M["white"], 0.01)
    desk = b("LobbyDesk", (0, 2.30, -52.0), (4.0, 1.8, 0.9), M["wood_light"], 0.02)
    b("LobbyDeskTop", (0, 2.45, -52.0), (4.4, 0.10, 1.1), M["metal_light"], 0.01)
    b("LobbyDeskScreen", (0, 2.95, -51.55), (1.2, 0.55, 0.05), M["screen"], 0.004)
    b("LobbyFloorGlow", (0, 1.56, -52.0), (12.0, 0.04, 0.10), M["lamp_cold"], 0.003)
    b("LobbyLightA", (0, 7.10, -51.0), (10.0, 0.06, 0.20), M["lamp_cold"], 0.004)
    b("LobbyLightB", (0, 7.10, -55.0), (10.0, 0.06, 0.20), M["lamp_cold"], 0.004)
    for side in (-1, 1):
        b("LobbyBench%s" % side, (side * 5.2, 1.85, -53.5), (2.4, 0.08, 0.5), M["wood_light"], 0.01)
        b("LobbyBenchBack%s" % side, (side * 5.2, 2.12, -53.72), (2.4, 0.40, 0.08), M["wood_light"], 0.008)
    # Emergency lights and cameras.
    for side in (-1, 1):
        b("SleeperCamera%s" % side, (side * 5.8, 9.4, -49.4), (0.25, 0.22, 0.5), M["metal"], 0.006)
        b("SleeperEmergency%s" % side, (side * 7.8, 3.2, -49.5), (0.18, 0.18, 0.18), M["alarm"], 0.004)


def build_dining():
    # Low glass pavilion west of the plaza.
    b("DiningPlinth", (-55, 0.4, 10), (40, 0.8, 32), M["concrete"], 0.03)
    b("DiningMass", (-55, 6.4, 10), (34, 12, 26), M["white_dirty"], 0.04)
    b("DiningRoof", (-55, 12.7, 10), (36, 0.8, 28), M["concrete_dark"], 0.03)
    # East-facing glass curtain wall.
    b("DiningGlass", (-37.8, 5.8, 10), (0.3, 9.0, 24.0), M["glass"], 0.02)
    b("DiningDoorFrame", (-37.65, 1.75, 10.0), (0.45, 3.5, 2.8), M["dark"], 0.02)
    b("DiningDoor", (-37.55, 1.6, 10.0), (0.25, 3.1, 2.2), M["wood"], 0.01)
    b("DiningDoorGlow", (-37.4, 3.25, 10.0), (0.15, 0.10, 2.4), M["lamp"], 0.004)
    for i in range(7):
        b("DiningMullion%d" % i, (-37.6, 5.8, -1.0 + i * 4.0), (0.18, 9.2, 0.16), M["metal"], 0.006)
    for floor in range(2):
        b("DiningBand%d" % floor, (-37.6, 3.0 + floor * 5.0, 10), (0.18, 0.2, 24.4), M["metal"], 0.006)
    b("DiningCanopy", (-34.0, 6.8, 10), (8.0, 0.3, 18.0), M["concrete_dark"], 0.02)
    b("DiningCanopyGlow", (-34.0, 6.6, 10), (6.8, 0.06, 16.0), M["lamp"], 0.004)
    for i in range(4):
        b("DiningInteriorGlow%d" % i, (-44.0, 4.0, -2.0 + i * 8.0), (10.0, 0.1, 0.18), M["lamp"], 0.004)
    b("DiningSignFrame", (-37.3, 9.0, 10), (0.4, 1.2, 10.0), M["metal"], 0.02)
    b("DiningSignGlow", (-37.1, 9.0, 10), (0.08, 0.9, 9.0), M["screen_warm"], 0.006)
    # Roof vents and a small winter garden.
    for i in range(3):
        b("DiningRoofUnit%d" % i, (-64.0 + i * 9.0, 13.3, 2.0), (3.2, 1.4, 3.2), M["metal"], 0.02)
    K.planter("DiningPlanter", (-37.0, 0, 22.0), 2.6, 3.2)
    for obj in bpy.data.objects:
        if obj.name.startswith("DiningPlanter") and obj not in OBJECTS and obj.type == "MESH":
            OBJECTS.append(obj)


def build_dojo():
    # Dark training hall with red fins and a circular emblem.
    b("DojoPlinth", (55, 0.5, 10), (42, 1.0, 34), M["concrete"], 0.03)
    b("DojoMass", (55, 7.5, 10), (36, 14, 28), M["concrete_dark"], 0.04)
    b("DojoRoof", (55, 15.0, 10), (38, 0.8, 30), M["metal"], 0.03)
    # West-facing glass and red fins.
    b("DojoGlass", (36.8, 6.0, 10), (0.3, 9.0, 22.0), M["glass"], 0.02)
    # Entrance door and frame, so the facade reads as a building, not a wall.
    b("DojoDoorFrame", (36.65, 1.75, 10.0), (0.45, 3.5, 2.8), M["dark"], 0.02)
    b("DojoDoor", (36.55, 1.6, 10.0), (0.25, 3.1, 2.2), M["metal"], 0.01)
    b("DojoDoorGlow", (36.4, 3.25, 10.0), (0.15, 0.10, 2.4), M["lamp"], 0.004)
    for i in range(6):
        b("DojoFin%d" % i, (36.3, 8.0, -2.0 + i * 5.0), (0.5, 15.0, 0.6), M["red"], 0.008)
    for i in range(4):
        b("DojoMullion%d" % i, (36.5, 6.0, -8.0 + i * 5.5), (0.18, 9.2, 0.16), M["metal"], 0.006)
    add(K.torus("DojoEmblemOuter", (35.9, 12.0, 10.0), 3.4, 0.16, M["red"], (0, math.pi * 0.5, 0)))
    add(K.torus("DojoEmblemInner", (35.8, 12.0, 10.0), 2.2, 0.10, M["metal_light"], (0, math.pi * 0.5, 0)))
    b("DojoCanopy", (33.0, 8.0, 10), (7.0, 0.3, 18.0), M["metal"], 0.02)
    b("DojoCanopyGlow", (33.0, 7.8, 10), (5.8, 0.06, 16.0), M["dark"], 0.004)
    b("DojoCanopyLine", (30.1, 7.82, 10), (0.05, 0.05, 15.0), M["screen"], 0.002)
    for i in range(4):
        b("DojoInteriorGlow%d" % i, (44.0, 4.8, -3.0 + i * 9.0), (18.0, 0.1, 0.2), M["lamp_cold"], 0.004)
    b("DojoSignFrame", (36.2, 10.5, 10), (0.4, 1.2, 8.0), M["metal"], 0.02)
    b("DojoSignGlow", (36.0, 10.5, 10), (0.08, 0.9, 7.2), M["dark"], 0.006)
    b("DojoSignLine", (35.96, 10.05, 10), (0.03, 0.08, 6.8), M["screen"], 0.002)
    # Side training yard.
    b("DojoYard", (55, 0.05, 34), (34, 0.1, 18), M["concrete"], 0.01)
    for side in (-1, 1):
        for i in range(3):
            b("DojoYardPost%s%d" % (side, i), (side * 15.0 + 55, 1.2, 28 + i * 4.0), (0.22, 2.4, 0.22), M["metal"], 0.006)
        b("DojoYardRail%s" % side, (55 + side * 15.0, 2.2, 32.0), (0.08, 0.08, 12.0), M["metal"], 0.004)
    b("DojoYardMat", (55, 0.12, 34), (16, 0.05, 12), M["fabric_blue"], 0.0)


def build_academic():
    # White academic block, library corner and window grid.
    b("AcademicPlinth", (-55, 0.5, -35), (40, 1.0, 32), M["concrete"], 0.03)
    b("AcademicMass", (-55, 9.0, -35), (34, 18, 26), M["white"], 0.04)
    b("AcademicRoof", (-55, 18.5, -35), (36, 0.8, 28), M["concrete"], 0.03)
    # East-facing library glass grid.
    b("AcademicGlass", (-37.8, 8.0, -35), (0.3, 12.0, 22.0), M["glass"], 0.02)
    b("AcademicDoorFrame", (-37.65, 1.75, -35.0), (0.45, 3.5, 2.8), M["dark"], 0.02)
    b("AcademicDoor", (-37.55, 1.6, -35.0), (0.25, 3.1, 2.2), M["metal"], 0.01)
    b("AcademicDoorGlow", (-37.4, 3.25, -35.0), (0.15, 0.10, 2.4), M["lamp"], 0.004)
    for i in range(6):
        b("AcademicMullion%d" % i, (-37.6, 8.0, -45.0 + i * 4.0), (0.18, 12.2, 0.16), M["metal"], 0.006)
    for floor in range(3):
        b("AcademicBand%d" % floor, (-37.6, 3.5 + floor * 4.0, -35), (0.18, 0.22, 22.4), M["metal"], 0.006)
    # Vertical white fins and a reading-room glow.
    for i in range(4):
        b("AcademicFin%d" % i, (-37.3, 10.0, -44.0 + i * 6.0), (0.4, 19.0, 0.5), M["white_dirty"], 0.008)
    for i in range(3):
        b("AcademicGlow%d" % i, (-38.0, 3.5 + i * 4.5, -35), (0.08, 2.0, 18.0), M["lamp"], 0.004)
    b("AcademicCanopy", (-34.0, 6.2, -35), (7.0, 0.3, 18.0), M["concrete_dark"], 0.02)
    b("AcademicCanopyGlow", (-34.0, 6.0, -35), (5.8, 0.06, 16.0), M["lamp"], 0.004)
    b("AcademicSignFrame", (-37.2, 13.0, -35), (0.4, 1.2, 9.0), M["metal"], 0.02)
    b("AcademicSignGlow", (-37.0, 13.0, -35), (0.08, 0.9, 8.2), M["screen"], 0.006)
    # Roof observatory / vents.
    for i in range(4):
        b("AcademicRoofUnit%d" % i, (-64.0 + i * 6.0, 19.2, -40.0), (3.0, 1.2, 3.0), M["metal"], 0.02)
    c("AcademicDome", (-55, 21.0, -35), 4.0, 3.0, M["white_dirty"], "Y", 24, 0.02)


def build_medical():
    b("MedicalPlinth", (55, 0.5, -35), (34, 1.0, 30), M["concrete"], 0.03)
    b("MedicalMass", (55, 7.0, -35), (28, 14, 24), M["white"], 0.04)
    b("MedicalRoof", (55, 14.5, -35), (30, 0.8, 26), M["concrete"], 0.03)
    b("MedicalGlass", (40.8, 6.0, -35), (0.3, 8.0, 18.0), M["glass"], 0.02)
    b("MedicalDoorFrame", (40.65, 1.75, -35.0), (0.45, 3.5, 2.8), M["dark"], 0.02)
    b("MedicalDoor", (40.55, 1.6, -35.0), (0.25, 3.1, 2.2), M["white_dirty"], 0.01)
    b("MedicalDoorGlow", (40.4, 3.25, -35.0), (0.15, 0.10, 2.4), M["lamp_cold"], 0.004)
    for i in range(5):
        b("MedicalMullion%d" % i, (40.6, 6.0, -43.0 + i * 4.0), (0.18, 8.2, 0.16), M["metal"], 0.006)
    for floor in range(2):
        b("MedicalBand%d" % floor, (40.6, 3.8 + floor * 4.2, -35), (0.18, 0.2, 18.4), M["metal"], 0.006)
    # Red cross on the west facade.
    b("MedicalCrossV", (40.4, 10.0, -35), (0.35, 4.0, 1.2), M["red"], 0.01)
    b("MedicalCrossH", (40.4, 10.0, -35), (0.35, 1.2, 4.0), M["red"], 0.01)
    b("MedicalCanopy", (37.0, 5.8, -35), (7.0, 0.3, 14.0), M["concrete_dark"], 0.02)
    b("MedicalCanopyGlow", (37.0, 5.6, -35), (5.8, 0.06, 12.0), M["lamp_cold"], 0.004)
    b("MedicalSignFrame", (40.2, 5.0, -35), (0.4, 0.9, 7.0), M["metal"], 0.02)
    b("MedicalSignGlow", (40.0, 5.0, -35), (0.08, 0.7, 6.2), M["screen"], 0.006)
    for i in range(3):
        b("MedicalRoofUnit%d" % i, (47.0 + i * 5.0, 15.2, -42.0), (2.4, 1.2, 2.4), M["metal"], 0.02)


# ---------------------------------------------------------------------------
# plaza furniture, flags and skyline
# ---------------------------------------------------------------------------

def build_plaza():
    # Central plaza and side paths.
    b("Plaza", (0, 0.02, 10), (60, 0.08, 120), M["concrete"], 0.0)
    b("PlazaAxis", (0, 0.04, 10), (10, 0.04, 120), M["tile"], 0.0)
    for side in (-1, 1):
        b("PlazaEdge%s" % side, (side * 30.0, 0.1, 10), (1.0, 0.2, 120), M["concrete_dark"], 0.01)
        for i in range(5):
            z = 50.0 - i * 22.0
            K.planter("PlazaPlanter%s%d" % (side, i), (side * 24.0, 0, z), 2.4, 4.0)
            K.bench("PlazaBench%s%d" % (side, i), (side * 20.0, 0, z + 5.0), 3.4, math.pi * 0.5 if side < 0 else -math.pi * 0.5)
    for obj in bpy.data.objects:
        if (obj.name.startswith("PlazaPlanter") or obj.name.startswith("PlazaBench")) and obj not in OBJECTS and obj.type == "MESH":
            OBJECTS.append(obj)
    # Flagpoles at the gate plaza.
    for side in (-1, 1):
        for i in range(2):
            x = side * (18.0 + i * 5.0)
            c("FlagPole%s%d" % (side, i), (x, 6.0, 58.0), 0.09, 12.0, M["metal_light"], "Y", 12, 0.006)
            b("Flag%s%d" % (side, i), (x + 1.5, 10.5, 58.0), (3.0, 1.6, 0.05), M["fabric_blue"], 0.01)
    # Directional bollards along the axis.
    for i in range(10):
        z = 50.0 - i * 10.0
        for side in (-1, 1):
            K.bollard("AxisBollard%s%d" % (side, i), (side * 6.0, 0, z))
    for obj in bpy.data.objects:
        if obj.name.startswith("AxisBollard") and obj not in OBJECTS and obj.type == "MESH":
            OBJECTS.append(obj)
    # Lamps on the plaza.
    for side in (-1, 1):
        for i in range(5):
            K.lamp("PlazaLamp%s%d" % (side, i), (side * 12.0, 0, 52.0 - i * 24.0), 6.5, warm=(i % 2 == 0))
    for obj in bpy.data.objects:
        if obj.name.startswith("PlazaLamp") and obj not in OBJECTS and obj.type == "MESH":
            OBJECTS.append(obj)
    # Snow drifts and footprint trails.
    for side in (-1, 1):
        for i in range(6):
            z = 44.0 - i * 18.0
            b("PlazaSnow%s%d" % (side, i), (side * 34.0, 0.45, z), (8.0, 0.9, 12.0), M["snow"], 0.2)
    for i in range(12):
        z = 48.0 - i * 8.0
        b("FootprintL%d" % i, (-2.2, 0.07, z), (0.28, 0.02, 0.5), M["tile_wet"], 0.0)
        b("FootprintR%d" % i, (2.2, 0.07, z - 0.4), (0.28, 0.02, 0.5), M["tile_wet"], 0.0)
    # Utility details: drains, vents, cables.
    for i in range(6):
        z = 40.0 - i * 15.0
        b("PlazaDrain%d" % i, (14.5, 0.03, z), (1.2, 0.04, 0.8), M["metal"], 0.0)
        for j in range(5):
            b("PlazaDrainBar%d%d" % (i, j), (14.0 + j * 0.25, 0.06, z), (0.06, 0.02, 0.7), M["metal_light"], 0.0)
    # Memorial obelisk near the Sleeper Center.
    b("MemorialBase", (22.0, 0.4, -32.0), (5.0, 0.8, 5.0), M["concrete"], 0.03)
    b("MemorialObelisk", (22.0, 4.0, -32.0), (1.2, 7.2, 1.2), M["white"], 0.02)
    b("MemorialCap", (22.0, 7.8, -32.0), (1.8, 0.3, 1.8), M["metal_light"], 0.02)
    for i in range(4):
        b("MemorialPlaque%d" % i, (22.0, 1.4 + i * 1.3, -31.38), (2.4, 0.8, 0.06), M["metal"], 0.006)


def build_skyline():
    # Distant city blocks outside the walls. Visual only, no collision.
    towers = [
        (-120, 150, -140, 34, 70, 26), (-170, 110, -20, 40, 90, 30), (-150, 80, 100, 30, 60, 24),
        (130, 140, -120, 36, 80, 28), (180, 100, 20, 42, 100, 32), (150, 70, 110, 30, 55, 24),
        (-90, 120, -210, 50, 110, 40), (0, 150, -230, 60, 120, 44), (90, 130, -210, 46, 95, 38),
        (-210, 90, -80, 44, 70, 36), (210, 90, -80, 44, 75, 36), (-210, 80, 60, 40, 65, 34),
        (210, 80, 60, 40, 65, 34), (-80, 70, 210, 36, 55, 30), (80, 70, 210, 36, 55, 30),
        (0, 60, 240, 28, 45, 24), (-250, 70, 160, 48, 85, 40), (250, 70, 160, 48, 85, 40),
    ]
    for i, (x, y, z, w, h, d) in enumerate(towers):
        b("SkyTower%d" % i, (x, y * 0.5, z), (w, y, d), M["concrete_dark"], 0.02)
        # Distant windows read as a few emissive vertical strips, not thousands
        # of individual quads. This keeps the GLB light and the silhouette clean.
        face_z = z + d * 0.5 + 0.06 if z < 0 else z - d * 0.5 - 0.06
        strips = max(3, int(w / 5.0))
        for col in range(strips):
            wx = x - w * 0.5 + (col + 0.5) * (w / strips)
            strip_h = y * (0.45 + 0.10 * ((col + i) % 3))
            b("SkyStrip%d%d" % (i, col), (wx, 3.0 + strip_h * 0.5, face_z), (0.55, strip_h, 0.08), M["skyline"], 0.0)
        for band in range(2):
            by = 4.0 + band * (y * 0.42)
            b("SkyBand%d%d" % (i, band), (x, by, face_z), (w * 0.82, 0.18, 0.08), M["skyline"], 0.0)
        # Roof beacon.
        c("SkyBeacon%d" % i, (x, y + 1.0, z), 0.18, 0.4, M["alarm"], "Y", 8, 0.0)
    # Distant outer wall and gate silhouette.
    for side in (-1, 1):
        b("FarWall%s" % side, (side * 190, 8.0, 90), (100, 16, 6), M["concrete_dark"], 0.02)
        b("FarWallTower%s" % side, (side * 150, 14.0, 90), (18, 28, 18), M["concrete_dark"], 0.02)


# ---------------------------------------------------------------------------
# build
# ---------------------------------------------------------------------------

build_ground()
build_gate()
build_perimeter()
build_gallery()
build_sleeper_center()
build_dining()
build_dojo()
build_academic()
build_medical()
build_plaza()
build_skyline()

# Remove accidental duplicates by name (helpers can create overlapping prefixes).
unique = []
seen = set()
for obj in OBJECTS:
    if obj is None or obj.name in seen:
        continue
    seen.add(obj.name)
    unique.append(obj)

K.export_glb(unique, os.path.join(K.OUT, "academy_grounds.glb"))
print("Academy grounds complete:", len(unique), "objects")
