"""Shared helper library for the Academy location build.

The geometry is authored in "Godot coordinates" (X right, Y up, Z north-negative)
and converted to Blender coordinates (X right, Y = -Z_godot, Z = Y_godot).
Exports are GLB scenes with one object per architectural element; Godot applies
the final PBR materials by material name, so the GLB stays small and editable.

Run the builders only in background Blender:
    blender -b --python assets/environments/academy/source/build_academy_grounds.py
    blender -b --python assets/environments/academy/source/build_academy_sleeper_center.py
"""
from __future__ import annotations

import math
import os

import bpy
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "environments", "academy")


# ---------------------------------------------------------------------------
# coordinate helpers
# ---------------------------------------------------------------------------

def gpos(x: float, y: float, z: float) -> tuple[float, float, float]:
    """Godot (x, y, z) -> Blender (x, -z, y)."""
    return (x, -z, y)


def gsize(size: tuple[float, float, float]) -> tuple[float, float, float]:
    """Godot size (x, y, z) -> Blender size (x, z, y)."""
    return (size[0], size[2], size[1])


def grot_y(radians: float) -> float:
    """Rotation around Godot Y -> Blender Z (sign mirrored)."""
    return -radians


# ---------------------------------------------------------------------------
# scene / materials
# ---------------------------------------------------------------------------

def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    # Factory reset removes the datablocks; the module cache must not keep
    # references to removed materials.
    _MATERIALS.clear()
    global _M
    _M = materials()


_MATERIALS: dict[str, bpy.types.Material] = {}


def mat(
    name: str,
    color: tuple[float, float, float],
    metallic: float = 0.0,
    roughness: float = 0.7,
    alpha: float = 1.0,
    emission: tuple[float, float, float] | None = None,
    emission_strength: float = 1.0,
) -> bpy.types.Material:
    cached = _MATERIALS.get(name)
    if cached is not None:
        return cached
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, alpha)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Alpha"].default_value = alpha
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    if alpha < 1.0:
        try:
            m.surface_render_method = "DITHERED"
        except Exception:
            m.blend_method = "BLEND"
    _MATERIALS[name] = m
    return m


def materials() -> dict[str, bpy.types.Material]:
    return {
        "white": mat("academy_white", (0.80, 0.82, 0.84), 0.0, 0.52),
        "white_dirty": mat("academy_white_dirty", (0.64, 0.66, 0.68), 0.0, 0.62),
        "plaster": mat("academy_plaster", (0.72, 0.73, 0.74), 0.0, 0.68),
        "concrete": mat("academy_concrete", (0.40, 0.42, 0.45), 0.0, 0.82),
        "concrete_dark": mat("academy_concrete_dark", (0.19, 0.21, 0.24), 0.05, 0.72),
        "dark": mat("academy_dark", (0.055, 0.065, 0.082), 0.35, 0.38),
        "metal": mat("academy_metal", (0.20, 0.22, 0.25), 0.85, 0.32),
        "metal_light": mat("academy_metal_light", (0.56, 0.59, 0.63), 0.70, 0.28),
        "red": mat("academy_red", (0.42, 0.045, 0.05), 0.25, 0.42),
        "red_dark": mat("academy_red_dark", (0.22, 0.02, 0.025), 0.2, 0.5),
        "glass": mat("academy_glass", (0.025, 0.055, 0.085), 0.65, 0.07, 0.38),
        "glass_clear": mat("academy_glass_clear", (0.18, 0.27, 0.34), 0.25, 0.05, 0.17),
        "snow": mat("academy_snow", (0.84, 0.88, 0.92), 0.0, 0.90),
        "tile": mat("academy_tile", (0.56, 0.58, 0.61), 0.0, 0.36),
        "tile_wet": mat("academy_tile_wet", (0.29, 0.33, 0.37), 0.12, 0.18),
        "wood": mat("academy_wood", (0.28, 0.18, 0.11), 0.0, 0.62),
        "wood_light": mat("academy_wood_light", (0.50, 0.38, 0.26), 0.0, 0.65),
        "fabric": mat("academy_fabric", (0.14, 0.16, 0.20), 0.0, 0.92),
        "fabric_blue": mat("academy_fabric_blue", (0.11, 0.19, 0.33), 0.0, 0.90),
        "hollow": mat("academy_hollow", (0.60, 0.56, 0.50), 0.0, 0.86),
        "lamp": mat("academy_lamp", (0.95, 0.86, 0.68), 0.0, 0.40, 1.0, (1.0, 0.76, 0.46), 3.2),
        "lamp_cold": mat("academy_lamp_cold", (0.72, 0.86, 1.0), 0.0, 0.40, 1.0, (0.52, 0.78, 1.0), 3.0),
        "screen": mat("academy_screen", (0.02, 0.04, 0.06), 0.15, 0.28, 1.0, (0.25, 0.62, 0.82), 2.2),
        "screen_warm": mat("academy_screen_warm", (0.07, 0.05, 0.03), 0.15, 0.28, 1.0, (1.0, 0.62, 0.28), 2.2),
        "alarm": mat("academy_alarm", (0.25, 0.012, 0.008), 0.0, 0.40, 1.0, (0.85, 0.02, 0.01), 2.4),
        "grid": mat("academy_grid", (0.27, 0.30, 0.33), 0.0, 0.72),
        "topiary": mat("academy_topiary", (0.075, 0.150, 0.110), 0.0, 0.82),
        "skyline": mat("academy_skyline", (0.045, 0.048, 0.055), 0.0, 0.55, 1.0, (0.90, 0.42, 0.16), 0.9),
        "dome": mat("academy_dome", (0.30, 0.50, 0.72), 0.0, 0.10, 0.055, (0.18, 0.38, 0.65), 0.35),
    }


# ---------------------------------------------------------------------------
# primitives
# ---------------------------------------------------------------------------

def _finish(obj, material, bevel: float = 0.0, smooth: bool = False):
    if bevel > 0.0:
        modifier = obj.modifiers.new("Bevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        modifier.limit_method = "ANGLE"
        modifier.angle_limit = math.radians(40)
        modifier.harden_normals = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(material)
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    return obj


def box(name: str, center: tuple[float, float, float], size: tuple[float, float, float], material, bevel: float = 0.0):
    """Box in Godot coordinates."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=gpos(*center))
    obj = bpy.context.object
    obj.name = name
    obj.scale = gsize(size)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, material, bevel)


def box_rot(name: str, center: tuple[float, float, float], size: tuple[float, float, float], material, rot_y: float = 0.0, bevel: float = 0.0):
    obj = box(name, center, size, material, bevel)
    if abs(rot_y) > 1e-6:
        obj.rotation_euler[2] = grot_y(rot_y)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return obj


def cyl(name: str, center: tuple[float, float, float], radius: float, depth: float, material, axis: str = "Y", segments: int = 20, bevel: float = 0.0):
    """Cylinder in Godot coordinates. Axis Y is vertical in Godot / Z in Blender."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments, radius=radius, depth=depth, location=gpos(*center))
    obj = bpy.context.object
    obj.name = name
    if axis == "Y":
        pass
    elif axis == "X":
        obj.rotation_euler[1] = math.radians(90)
    elif axis == "Z":
        obj.rotation_euler[0] = math.radians(90)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish(obj, material, bevel, smooth=True)


def torus(name: str, center: tuple[float, float, float], major: float, minor: float, material, rot: tuple[float, float, float] = (0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major,
        minor_radius=minor,
        major_segments=32,
        minor_segments=8,
        location=gpos(*center),
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (rot[0], rot[1], rot[2])
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish(obj, material, smooth=True)


def sphere(name: str, center: tuple[float, float, float], radius: float, material, segments: int = 24, rings: int = 12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=radius, location=gpos(*center))
    obj = bpy.context.object
    obj.name = name
    return _finish(obj, material, smooth=True)


# ---------------------------------------------------------------------------
# architectural helpers
# ---------------------------------------------------------------------------

def window_grid(prefix: str, center: tuple[float, float, float], size: tuple[float, float, float], cols: int, rows: int, frame_mat, glass_mat, depth: float = 0.06):
    """Vertical window wall on the south face (Godot +Z) of a mass."""
    x, y, z = center
    width, height, _ = size
    gap_x = width / cols
    gap_y = height / rows
    for c in range(cols):
        cx = x - width * 0.5 + gap_x * (c + 0.5)
        for r in range(rows):
            cy = y - height * 0.5 + gap_y * (r + 0.5)
            box("%s_glass_%d_%d" % (prefix, c, r), (cx, cy, z), (gap_x * 0.86, gap_y * 0.82, depth), glass_mat, 0.01)
    for c in range(cols + 1):
        cx = x - width * 0.5 + gap_x * c
        box("%s_mullion_%d" % (prefix, c), (cx, y, z + depth * 0.6), (0.05, height, 0.08), frame_mat, 0.008)
    for r in range(rows + 1):
        cy = y - height * 0.5 + gap_y * r
        box("%s_band_%d" % (prefix, r), (x, cy, z + depth * 0.6), (width, 0.05, 0.08), frame_mat, 0.008)


def railing(prefix: str, start: tuple[float, float, float], end: tuple[float, float, float], height: float, material, posts: int = 8):
    sx, sy, sz = start
    ex, ey, ez = end
    dx = ex - sx
    dy = ey - sy
    dz = ez - sz
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length < 0.01:
        return
    for i in range(posts + 1):
        t = i / posts
        box("%s_post_%d" % (prefix, i), (sx + dx * t, sy + height * 0.5, sz + dz * t), (0.05, height, 0.05), material, 0.006)
    box("%s_top" % prefix, (sx + dx * 0.5, sy + height, sz + dz * 0.5), (abs(dx) + 0.06, 0.06, abs(dz) + 0.06), material, 0.008)
    box("%s_mid" % prefix, (sx + dx * 0.5, sy + height * 0.55, sz + dz * 0.5), (abs(dx) + 0.04, 0.04, abs(dz) + 0.04), material, 0.006)


def stairs(prefix: str, center: tuple[float, float, float], width: float, total_rise: float, total_run: float, steps: int, material):
    x, y, z = center
    step_rise = total_rise / steps
    step_run = total_run / steps
    for i in range(steps):
        box(
            "%s_step_%d" % (prefix, i),
            (x, y + step_rise * (i + 0.5), z - total_run * 0.5 + step_run * (i + 0.5)),
            (width, step_rise, step_run),
            material,
            0.008,
        )


def lamp(prefix: str, position: tuple[float, float, float], height: float = 6.0, warm: bool = True):
    x, y, z = position
    box("%s_base" % prefix, (x, y + 0.15, z), (0.34, 0.3, 0.34), "academy_metal" if False else _M["metal"], 0.01)
    cyl("%s_pole" % prefix, (x, y + height * 0.5, z), 0.07, height, _M["metal"], "Y", 12, 0.006)
    box("%s_head" % prefix, (x, y + height, z), (0.55, 0.12, 0.28), _M["metal"], 0.008)
    box("%s_glow" % prefix, (x, y + height - 0.08, z), (0.42, 0.04, 0.18), _M["lamp"] if warm else _M["lamp_cold"], 0.004)


def bench(prefix: str, position: tuple[float, float, float], length: float = 3.2, rot_y: float = 0.0):
    x, y, z = position
    box_rot("%s_seat" % prefix, (x, y + 0.46, z), (length, 0.10, 0.52), _M["wood_light"], rot_y, 0.012)
    box_rot("%s_back" % prefix, (x, y + 0.78, z - 0.22), (length, 0.42, 0.08), _M["wood_light"], rot_y, 0.01)
    for side in (-1, 1):
        box_rot("%s_leg_%d" % (prefix, side), (x + side * (length * 0.36), y + 0.23, z), (0.08, 0.46, 0.46), _M["metal"], rot_y, 0.006)


def planter(prefix: str, position: tuple[float, float, float], size: float = 2.2, tree_height: float = 4.0):
    x, y, z = position
    box("%s_box" % prefix, (x, y + 0.35, z), (size, 0.7, size), _M["concrete"], 0.02)
    box("%s_snow" % prefix, (x, y + 0.73, z), (size * 0.92, 0.06, size * 0.92), _M["snow"], 0.01)
    cyl("%s_trunk" % prefix, (x, y + 1.1 + tree_height * 0.5, z), 0.09, tree_height, _M["wood"], "Y", 8, 0.004)
    # Geometric winter topiary: three stacked cones, deliberately artificial.
    for i in range(3):
        r = size * (0.34 - i * 0.07)
        h = tree_height * 0.34
        yy = y + 1.0 + tree_height * (0.25 + i * 0.23)
        bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=r, radius2=0.02, depth=h, location=gpos(x, yy, z))
        obj = bpy.context.object
        obj.name = "%s_crown_%d" % (prefix, i)
        _finish(obj, _M["topiary"], smooth=False)
        box("%s_crown_snow_%d" % (prefix, i), (x, yy + h * 0.46, z), (r * 1.2, 0.05, r * 1.2), _M["snow"], 0.0)


def bollard(prefix: str, position: tuple[float, float, float]):
    x, y, z = position
    cyl("%s_body" % prefix, (x, y + 0.5, z), 0.11, 1.0, _M["metal"], "Y", 12, 0.006)
    cyl("%s_glow" % prefix, (x, y + 0.88, z), 0.115, 0.06, _M["lamp_cold"], "Y", 12, 0.002)


def turret(prefix: str, position: tuple[float, float, float], height: float = 4.0):
    x, y, z = position
    cyl("%s_base" % prefix, (x, y + 0.35, z), 1.1, 0.7, _M["concrete_dark"], "Y", 16, 0.02)
    cyl("%s_body" % prefix, (x, y + height * 0.5, z), 0.62, height, _M["metal"], "Y", 16, 0.015)
    box("%s_head" % prefix, (x, y + height + 0.2, z), (1.4, 0.55, 1.0), _M["metal"], 0.02)
    for side in (-1, 1):
        cyl("%s_barrel_%d" % (prefix, side), (x + side * 0.28, y + height + 0.22, z + 0.65), 0.055, 0.9, _M["metal_light"], "Z", 10, 0.004)
    box("%s_warning" % prefix, (x, y + height + 0.52, z - 0.2), (0.18, 0.12, 0.18), _M["alarm"], 0.006)


def wall_segment(prefix: str, center: tuple[float, float, float], length: float, height: float = 10.0, thickness: float = 1.8, horizontal: bool = True):
    x, y, z = center
    size = (length, height, thickness) if horizontal else (thickness, height, length)
    box("%s_core" % prefix, (x, y + height * 0.5, z), size, _M["concrete_dark"], 0.03)
    # cap
    cap_size = (length + 0.2, 0.28, thickness + 0.35) if horizontal else (thickness + 0.35, 0.28, length + 0.2)
    box("%s_cap" % prefix, (x, y + height + 0.14, z), cap_size, _M["concrete"], 0.025)
    # panel seams and buttresses
    count = max(2, int(length / 5.0))
    for i in range(count):
        t = (i + 0.5) / count
        px = x - length * 0.5 + length * t if horizontal else x
        pz = z if horizontal else z - length * 0.5 + length * t
        if horizontal:
            box("%s_panel_%d" % (prefix, i), (px, y + height * 0.5, z - thickness * 0.5 - 0.02), (length / count * 0.86, height * 0.78, 0.05), _M["concrete"], 0.01)
        else:
            box("%s_panel_%d" % (prefix, i), (x - thickness * 0.5 - 0.02, y + height * 0.5, pz), (0.05, height * 0.78, length / count * 0.86), _M["concrete"], 0.01)
    for side in (-1, 1):
        bx = x + side * length * 0.5 if horizontal else x
        bz = z if horizontal else z + side * length * 0.5
        box("%s_buttress_%d" % (prefix, side), (bx, y + height * 0.42, bz), (0.55, height * 0.84, 0.55), _M["concrete"], 0.02)
    # warning strip
    if horizontal:
        box("%s_strip" % prefix, (x, y + height - 0.45, z - thickness * 0.5 - 0.04), (length * 0.92, 0.06, 0.04), _M["red"], 0.004)
    else:
        box("%s_strip" % prefix, (x - thickness * 0.5 - 0.04, y + height - 0.45, z), (0.04, 0.06, length * 0.92), _M["red"], 0.004)


def room_shell(
    name: str,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    height: float,
    wall_mat,
    floor_mat,
    ceil_mat,
    doors: list[dict] | None = None,
    windows: list[dict] | None = None,
):
    """Room with optional door gaps. Doors: side south/north/east/west, center offset, width, height."""
    cx, cy, cz = center
    w, _, d = size
    doors = doors or []
    windows = windows or []
    box("%s_floor" % name, (cx, cy - 0.1, cz), (w, 0.2, d), floor_mat, 0.01)
    box("%s_ceiling" % name, (cx, cy + height + 0.1, cz), (w, 0.2, d), ceil_mat, 0.01)
    sides = {
        "south": (cx, cz + d * 0.5, w, "x"),
        "north": (cx, cz - d * 0.5, w, "x"),
        "west": (cx - w * 0.5, cz, d, "z"),
        "east": (cx + w * 0.5, cz, d, "z"),
    }
    for side, (sx, sz, length, axis) in sides.items():
        door = next((x for x in doors if x.get("side") == side), None)
        window = next((x for x in windows if x.get("side") == side), None)
        _wall_side(name, side, sx, sz, length, height, wall_mat, door, window, axis)
    for door in doors:
        _door_frame(name, door, center, size, height)


def _wall_side(name, side, sx, sz, length, height, material, door, window, axis):
    thickness = 0.2
    door_w = float(door.get("width", 2.4)) if door else 0.0
    door_h = float(door.get("height", 2.8)) if door else 0.0
    door_c = float(door.get("center", 0.0)) if door else 0.0
    if door is None:
        if axis == "x":
            box("%s_wall_%s" % (name, side), (sx, height * 0.5, sz), (length, height, thickness), material, 0.008)
        else:
            box("%s_wall_%s" % (name, side), (sx, height * 0.5, sz), (thickness, height, length), material, 0.008)
    else:
        left = door_c - door_w * 0.5
        right = door_c + door_w * 0.5
        if axis == "x":
            if left > -length * 0.5:
                box("%s_wall_%s_l" % (name, side), (sx - length * 0.5 + (-length * 0.5 + left) * 0.5 + length * 0.5, height * 0.5, sz), (left + length * 0.5, height, thickness), material, 0.008)
            if right < length * 0.5:
                box("%s_wall_%s_r" % (name, side), (sx + (right + length * 0.5) * 0.5, height * 0.5, sz), (length * 0.5 - right, height, thickness), material, 0.008)
            box("%s_wall_%s_t" % (name, side), (sx + door_c, door_h + (height - door_h) * 0.5, sz), (door_w, height - door_h, thickness), material, 0.008)
        else:
            if left > -length * 0.5:
                box("%s_wall_%s_l" % (name, side), (sx, height * 0.5, sz - length * 0.5 + (left + length * 0.5) * 0.5), (thickness, height, left + length * 0.5), material, 0.008)
            if right < length * 0.5:
                box("%s_wall_%s_r" % (name, side), (sx, height * 0.5, sz + (right + length * 0.5) * 0.5), (thickness, height, length * 0.5 - right), material, 0.008)
            box("%s_wall_%s_t" % (name, side), (sx, door_h + (height - door_h) * 0.5, sz + door_c), (thickness, height - door_h, door_w), material, 0.008)
    if window:
        wc = float(window.get("center", 0.0))
        ww = float(window.get("width", 4.0))
        wh = float(window.get("height", 1.6))
        wy = float(window.get("y", height * 0.62))
        if axis == "x":
            box("%s_window_%s" % (name, side), (sx + wc, wy, sz), (ww, wh, 0.06), _M["glass"], 0.004)
            box("%s_window_frame_%s" % (name, side), (sx + wc, wy, sz + 0.04), (ww + 0.16, wh + 0.16, 0.05), _M["metal"], 0.006)
        else:
            box("%s_window_%s" % (name, side), (sx, wy, sz + wc), (0.06, wh, ww), _M["glass"], 0.004)
            box("%s_window_frame_%s" % (name, side), (sx + 0.04, wy, sz + wc), (0.05, wh + 0.16, ww + 0.16), _M["metal"], 0.006)


def _door_frame(name, door, center, size, height):
    cx, cy, cz = center
    w, _, d = size
    side = door.get("side")
    width = float(door.get("width", 2.4))
    door_h = float(door.get("height", 2.8))
    offset = float(door.get("center", 0.0))
    if side == "south":
        x, z = cx + offset, cz + d * 0.5
        box("%s_door_frame_l" % name, (x - width * 0.5, door_h * 0.5, z), (0.12, door_h, 0.26), _M["metal"], 0.01)
        box("%s_door_frame_r" % name, (x + width * 0.5, door_h * 0.5, z), (0.12, door_h, 0.26), _M["metal"], 0.01)
        box("%s_door_frame_t" % name, (x, door_h, z), (width + 0.24, 0.12, 0.26), _M["metal"], 0.01)
    elif side == "north":
        x, z = cx + offset, cz - d * 0.5
        box("%s_door_frame_l" % name, (x - width * 0.5, door_h * 0.5, z), (0.12, door_h, 0.26), _M["metal"], 0.01)
        box("%s_door_frame_r" % name, (x + width * 0.5, door_h * 0.5, z), (0.12, door_h, 0.26), _M["metal"], 0.01)
        box("%s_door_frame_t" % name, (x, door_h, z), (width + 0.24, 0.12, 0.26), _M["metal"], 0.01)
    elif side == "west":
        x, z = cx - w * 0.5, cz + offset
        box("%s_door_frame_l" % name, (x, door_h * 0.5, z - width * 0.5), (0.26, door_h, 0.12), _M["metal"], 0.01)
        box("%s_door_frame_r" % name, (x, door_h * 0.5, z + width * 0.5), (0.26, door_h, 0.12), _M["metal"], 0.01)
        box("%s_door_frame_t" % name, (x, door_h, z), (0.26, 0.12, width + 0.24), _M["metal"], 0.01)
    elif side == "east":
        x, z = cx + w * 0.5, cz + offset
        box("%s_door_frame_l" % name, (x, door_h * 0.5, z - width * 0.5), (0.26, door_h, 0.12), _M["metal"], 0.01)
        box("%s_door_frame_r" % name, (x, door_h * 0.5, z + width * 0.5), (0.26, door_h, 0.12), _M["metal"], 0.01)
        box("%s_door_frame_t" % name, (x, door_h, z), (0.26, 0.12, width + 0.24), _M["metal"], 0.01)


def export_glb(objects: list, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    # Export every mesh in the scene. Helpers create objects internally, so a
    # manually maintained list is fragile; the scene is the source of truth.
    meshes = [o for o in bpy.data.objects if o is not None and o.type == "MESH"]
    for obj in meshes:
        obj.select_set(True)
    if not meshes:
        raise RuntimeError("No meshes to export: %s" % path)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=False,
        export_morph=False,
        export_yup=True,
        export_texcoords=False,
        export_normals=True,
        export_materials="EXPORT",
    )
    total = sum(len(o.data.polygons) for o in meshes)
    print("BUILT", path, "objects", len(meshes), "polys", total)


_M = materials()
