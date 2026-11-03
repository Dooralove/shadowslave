"""Сборка кита Моря Души (Blender 5.1, фоновый режим).

Запуск:
    blender -b --factory-startup --python assets/environments/soul_sea/source/build_soul_sea_kit.py -- [опции]

Опции:
    --list                 список имён
    --only=name1,name2     только выбранные ассеты
    --no-export            не писать GLB
    --no-render            не рендерить превью
    --test                 быстрый режим: 3 ассета + один кадр (для отладки)

Выход:
    assets/environments/soul_sea/kit/ss_*.glb
    assets/environments/soul_sea/source/soul_sea_kit.blend
    docs/art/previews/soul_sea/kit_*.jpg
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

SRC = Path(__file__).resolve().parent
NM_SRC = Path(__file__).resolve().parents[2] / "nightmare" / "source"
for _p in (SRC, NM_SRC):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))

import nm_lib as L  # noqa: E402
import ss_lib as S  # noqa: E402

OUT = L.ROOT / "assets" / "environments" / "soul_sea" / "kit"
PREV = L.ROOT / "docs" / "art" / "previews" / "soul_sea"


def _assets():
    a = {
        "ss_dais_hero": S.dais_hero,
        "ss_memory_sphere_hero": S.memory_sphere_hero,
        "ss_shade_mountain_king": S.shade_mountain_king,
        "ss_shade_carapace_centurion": S.shade_carapace_centurion,
    }
    for i in range(3):
        a[f"ss_dais_edge_{'abc'[i]}"] = lambda i=i: S.dais_edge(i)
        a[f"ss_plinth_{'abc'[i]}"] = lambda i=i: S.plinth(i)
        a[f"ss_obelisk_{'abc'[i]}"] = lambda i=i: S.obelisk(i, hero=False)
        a[f"ss_memory_sphere_{'abc'[i]}"] = lambda i=i: S.memory_sphere(i)
        a[f"ss_memory_orbit_ring_{'abc'[i]}"] = lambda i=i: S.memory_orbit_ring(i)
        a[f"ss_memory_orbit_sigil_{'abc'[i]}"] = lambda i=i: S.memory_orbit_sigil(i)
        a[f"ss_memory_thread_{'abc'[i]}"] = lambda i=i: S.memory_thread(i)
        a[f"ss_echo_sphere_{'abc'[i]}"] = lambda i=i: S.echo_sphere(i)
        a[f"ss_ripple_decal_{'abc'[i]}"] = lambda i=i: S.ripple_decal(i)
        a[f"ss_mist_card_{'abc'[i]}"] = lambda i=i: S.mist_card(i)
        a[f"ss_shade_slave_{'abc'[i]}"] = lambda i=i: S.shade_slave(i)
        a[f"ss_shade_carapace_scavenger_{'abc'[i]}"] = lambda i=i: S.shade_carapace_scavenger(i)
        a[f"ss_shade_rank_far_{'abc'[i]}"] = lambda i=i: S.shade_rank_far(i)
        a[f"ss_shade_colossus_far_{'abc'[i]}"] = lambda i=i: S.shade_colossus_far(i)
    for i in range(4):
        a[f"ss_shoal_rock_{'abcd'[i]}"] = lambda i=i: S.shoal_rock(i)
    for i in range(2):
        a[f"ss_step_{'ab'[i]}"] = lambda i=i: S.step(i)
        a[f"ss_memory_mote_{'ab'[i]}"] = lambda i=i: S.memory_mote(i)
        a[f"ss_shade_slaver_{'ab'[i]}"] = lambda i=i: S.shade_slaver(i)
        a[f"ss_shade_centipede_{'ab'[i]}"] = lambda i=i: S.shade_centipede(i)
        a[f"ss_shade_worm_knot_{'ab'[i]}"] = lambda i=i: S.shade_worm_knot(i)
        a[f"ss_shade_blood_flower_{'ab'[i]}"] = lambda i=i: S.shade_blood_flower(i)
    a["ss_obelisk_hero"] = lambda: S.obelisk(0, hero=True)
    return a


ASSETS = _assets()


def selected_names():
    names = []
    for arg in sys.argv:
        if arg.startswith("--only="):
            names = [n.strip() for n in arg.split("=", 1)[1].split(",") if n.strip()]
    if "--test" in sys.argv and not names:
        names = ["ss_dais_hero", "ss_memory_sphere_hero", "ss_shade_slave_a"]
    return names


def _preview_root():
    return L.preview_collection()


def _new_group(name):
    root = _preview_root()
    coll = bpy.data.collections.get(name)
    if coll is None:
        coll = bpy.data.collections.new(name)
        root.children.link(coll)
    return coll


def _clear_group(group):
    for o in list(group.objects):
        bpy.data.objects.remove(o, do_unlink=True)


def _copy_asset(coll, group, loc=(0, 0, 0), rot_z=0.0, scale=1.0, z_to_ground=True):
    """Копирует меши коллекции в preview-группу (данные общие)."""
    pts = []
    for src in coll.objects:
        if src.type != "MESH":
            continue
        pts += [src.matrix_world @ Vector(c) for c in src.bound_box]
    zmin = min(p.z for p in pts) if pts else 0.0
    for src in coll.objects:
        if src.type != "MESH":
            continue
        dup = src.copy()
        dup.data = src.data
        group.objects.link(dup)
        dup.location = (loc[0], loc[1], loc[2] + (-zmin if z_to_ground else 0.0))
        dup.rotation_euler = (0.0, 0.0, rot_z)
        dup.scale = (scale, scale, scale)


def _lineup(group_name, names, spacing=0.7, scale=1.0, with_mannequin=True):
    group = _new_group(group_name)
    _clear_group(group)
    x = 0.0
    for name in names:
        coll = bpy.data.collections.get(name)
        if coll is None:
            print("MISSING", name)
            continue
        pts = []
        for src in coll.objects:
            if src.type == "MESH":
                pts += [src.matrix_world @ Vector(c) for c in src.bound_box]
        if not pts:
            continue
        minx = min(p.x for p in pts)
        maxx = max(p.x for p in pts)
        _copy_asset(coll, group, (x - minx, 0, 0), scale=scale, z_to_ground=True)
        x += (maxx - minx) * scale + spacing
    if with_mannequin:
        man = L.mannequin(location=(x + 0.8, 0, 0))
        for c in list(man.users_collection):
            c.objects.unlink(man)
        group.objects.link(man)
    return group


def _hero_group():
    group = _new_group("PREVIEW_hero")
    _clear_group(group)
    # Помост, Память, орбиты, тени и обелиски — компактная сцена.
    _copy_asset(bpy.data.collections["ss_dais_hero"], group, (0, 0, 0), rot_z=0.2)
    _copy_asset(bpy.data.collections["ss_memory_sphere_hero"], group, (0, 1.25, -0.9), z_to_ground=False)
    for i, (x, y, rz) in enumerate(((-2.2, -1.2, 0.3), (2.0, -1.6, -0.4), (-3.2, 2.2, 1.8))):
        name = f"ss_memory_orbit_ring_{'abc'[i]}"
        _copy_asset(bpy.data.collections[name], group, (x * 0.3, 1.25, -0.9), rot_z=rz, z_to_ground=False)
    _copy_asset(bpy.data.collections["ss_shade_slave_a"], group, (2.8, 1.2, 0), rot_z=-0.5)
    _copy_asset(bpy.data.collections["ss_shade_slaver_a"], group, (3.1, -0.2, 0), rot_z=-0.9)
    _copy_asset(bpy.data.collections["ss_shade_carapace_scavenger_a"], group, (-3.2, -1.8, 0), rot_z=0.7)
    for i, (x, y) in enumerate(((-2.6, 0.8), (2.6, 0.6), (-1.8, -3.2), (1.4, -3.0))):
        name = f"ss_shoal_rock_{'abcd'[i]}"
        _copy_asset(bpy.data.collections[name], group, (x, y, 0), rot_z=0.3 * i, scale=0.7)
    _copy_asset(bpy.data.collections["ss_memory_orbit_sigil_a"], group, (0, 0.36, -0.9), z_to_ground=False)
    return group


def setup_scene():
    L.clear_data()
    L.setup_render(res=(1100, 760), samples=32, sun_elev=26.0, sun_az=-42.0,
                   sun_power=2.2, sky=(0.008, 0.014, 0.028), sky_strength=0.55,
                   exposure=0.7)
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
        scene.eevee.taa_render_samples = 48
    except Exception as exc:
        print("EEVEE unavailable:", exc)
    scene.view_settings.exposure = 1.0
    sun = bpy.data.lights.get("PreviewSun")
    if sun is not None:
        sun.color = (0.62, 0.74, 1.0)
        sun.energy = 3.2
    L.preview_collection()
    # Тёмная вода-подложка: чуть светлее, чтобы силуэты читались.
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=38.0)
    ground = L.object_from_bmesh("PreviewWater", bm, _preview_root(), None)
    mat = L._simple_mat("preview_water", (0.035, 0.050, 0.070), 0.28)
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Metallic"].default_value = 0.25
    ground.data.materials.append(mat)
    ground.location.z = -0.02
    # Тёплый свет Памяти.
    light_data = bpy.data.lights.new("PreviewMemoryLight", "POINT")
    light_data.color = (1.0, 0.55, 0.25)
    light_data.energy = 420.0
    light_data.shadow_soft_size = 0.7
    light = bpy.data.objects.new("PreviewMemoryLight", light_data)
    _preview_root().objects.link(light)
    light.location = (0.0, 2.4, -0.9)
    # Холодный контровой.
    rim_data = bpy.data.lights.new("PreviewRim", "AREA")
    rim_data.color = (0.42, 0.60, 1.0)
    rim_data.energy = 900.0
    rim_data.shape = "DISK"
    rim_data.size = 6.0
    rim = bpy.data.objects.new("PreviewRim", rim_data)
    _preview_root().objects.link(rim)
    rim.location = (-5.5, 5.5, 5.0)
    rim.rotation_euler = (math.radians(58), 0.0, math.radians(-30))
    # Широкий ключевой свет для читаемости формы.
    key_data = bpy.data.lights.new("PreviewKey", "AREA")
    key_data.color = (0.72, 0.82, 1.0)
    key_data.energy = 1100.0
    key_data.shape = "DISK"
    key_data.size = 7.0
    key = bpy.data.objects.new("PreviewKey", key_data)
    _preview_root().objects.link(key)
    key.location = (7.0, -8.0, 7.0)
    key.rotation_euler = (math.radians(48), 0.0, math.radians(42))


def render_group(group, path, direction=(-1.0, -1.55, 0.52), lens=46.0,
                 margin=1.12, target_offset=(0, 0, 0)):
    for child in _preview_root().children:
        child.hide_render = child != group
        child.hide_viewport = child != group
    objs = [o for o in group.objects if o.type == "MESH"]
    if not objs:
        print("EMPTY GROUP", group.name)
        return
    L.frame_camera(objs, direction=direction, lens=lens, margin=margin,
                   target_offset=target_offset)
    L.render(path)


def render_all():
    constructs_a = _lineup("PREVIEW_constructs_a", [
        "ss_dais_hero", "ss_dais_edge_a", "ss_dais_edge_b", "ss_dais_edge_c",
        "ss_step_a", "ss_step_b", "ss_plinth_a", "ss_plinth_b", "ss_plinth_c",
    ], spacing=0.55)
    constructs_b = _lineup("PREVIEW_constructs_b", [
        "ss_shoal_rock_a", "ss_shoal_rock_b", "ss_shoal_rock_c", "ss_shoal_rock_d",
        "ss_obelisk_a", "ss_obelisk_b", "ss_obelisk_c", "ss_obelisk_hero",
        "ss_memory_orbit_sigil_a", "ss_ripple_decal_a", "ss_ripple_decal_b", "ss_ripple_decal_c",
    ], spacing=0.55, with_mannequin=False)
    memory_a = _lineup("PREVIEW_memory_a", [
        "ss_memory_sphere_hero", "ss_memory_sphere_a", "ss_memory_sphere_b", "ss_memory_sphere_c",
        "ss_memory_orbit_ring_a", "ss_memory_orbit_ring_b", "ss_memory_orbit_ring_c",
    ], spacing=0.55)
    memory_b = _lineup("PREVIEW_memory_b", [
        "ss_memory_thread_a", "ss_memory_thread_b", "ss_memory_thread_c",
        "ss_memory_mote_a", "ss_memory_mote_b",
        "ss_echo_sphere_a", "ss_echo_sphere_b", "ss_echo_sphere_c",
    ], spacing=0.55, with_mannequin=False)
    shades_a = _lineup("PREVIEW_shades_a", [
        "ss_shade_slave_a", "ss_shade_slave_b", "ss_shade_slave_c",
        "ss_shade_slaver_a", "ss_shade_slaver_b",
        "ss_shade_carapace_scavenger_a", "ss_shade_carapace_scavenger_b", "ss_shade_carapace_scavenger_c",
    ], spacing=0.65)
    shades_b = _lineup("PREVIEW_shades_b", [
        "ss_shade_carapace_centurion", "ss_shade_mountain_king",
        "ss_shade_centipede_a", "ss_shade_centipede_b",
        "ss_shade_worm_knot_a", "ss_shade_worm_knot_b",
        "ss_shade_blood_flower_a", "ss_shade_blood_flower_b",
    ], spacing=0.65, with_mannequin=False)
    shades_far = _lineup("PREVIEW_shades_far", [
        "ss_shade_rank_far_a", "ss_shade_rank_far_b", "ss_shade_rank_far_c",
        "ss_shade_colossus_far_a", "ss_shade_colossus_far_b", "ss_shade_colossus_far_c",
    ], spacing=0.8, with_mannequin=False)
    hero = _hero_group()
    hero_king = _new_group("PREVIEW_hero_king")
    _clear_group(hero_king)
    _copy_asset(bpy.data.collections["ss_shade_mountain_king"], hero_king, (0, 0, 0), rot_z=0.2)
    _copy_asset(bpy.data.collections["ss_shade_carapace_centurion"], hero_king, (4.2, 1.5, 0), rot_z=-0.6)
    _copy_asset(bpy.data.collections["ss_shade_slave_a"], hero_king, (-3.0, 1.8, 0), rot_z=0.4)
    _copy_asset(bpy.data.collections["ss_shade_slaver_a"], hero_king, (-3.4, -1.2, 0), rot_z=-0.3)
    PREV.mkdir(parents=True, exist_ok=True)
    render_group(constructs_a, PREV / "kit_constructs_a.jpg")
    render_group(constructs_b, PREV / "kit_constructs_b.jpg")
    render_group(memory_a, PREV / "kit_memory_a.jpg")
    render_group(memory_b, PREV / "kit_memory_b.jpg")
    render_group(shades_a, PREV / "kit_shades_a.jpg")
    render_group(shades_b, PREV / "kit_shades_b.jpg")
    render_group(shades_far, PREV / "kit_shades_far.jpg")
    render_group(hero, PREV / "kit_hero.jpg", direction=(-1.0, -1.4, 0.45),
                 lens=52.0, margin=1.06)
    render_group(hero_king, PREV / "kit_hero_king.jpg", direction=(-1.0, -1.5, 0.48),
                 lens=50.0, margin=1.08)


def main():
    args = sys.argv
    if "--list" in args:
        print("\n".join(sorted(ASSETS)))
        return
    names = selected_names() or sorted(ASSETS)
    unknown = [n for n in names if n not in ASSETS]
    if unknown:
        raise SystemExit(f"unknown assets: {unknown}\nknown: {sorted(ASSETS)}")
    setup_scene()
    built = []
    for name in names:
        print("BUILD", name)
        obj = ASSETS[name]()
        coll = obj.users_collection[0]
        built.append(coll.name)
        if "--no-export" not in args:
            L.export_collection(coll, OUT / f"{coll.name}.glb")
    L.set_assets_visible(False)
    if "--no-render" not in args and not args.count("--test"):
        render_all()
    # Не затирать полный .blend частичной сборкой --only.
    if len(built) == len(ASSETS):
        L.save_blend(SRC / "soul_sea_kit.blend")
    else:
        L.save_blend(SRC / "soul_sea_kit_partial.blend")
        print("PARTIAL: full blend not overwritten")
    print("DONE", len(built), "assets")
    print("TRIS", sum(L.tri_count(o) for c in bpy.data.collections if c.name.startswith("ss_")
                      for o in c.objects if o.type == "MESH"))


if __name__ == "__main__":
    main()
