"""Воспроизводимая сборка прототипа Санни в MPFB 2 (Blender 5.1, MPFB 2.0.18) и экспорт в GLB.

Запуск (Blender с включённым расширением MPFB и установленными CC0-наборами MakeHuman,
см. docs/ASSET_LICENSES.md):
    blender -b --python build_sunny_poc.py -- <путь к выходному .glb>

Параметры персонажа — в PRESET. Санни: подросток ~16 лет, рост 165–168 см (канон), очень худой,
бледный, тёмные неопрятные волосы.
"""
import json
import os
import sys

import bpy
from bl_ext.blender_org.mpfb.services import ExportService, HumanService

PRESET = {
    "name": "Sunny",
    # age: 0.1875 = 11 лет, 0.5 = 25 лет. 0.30 (~16 лет) давало слишком детское, почти девичье лицо,
    # 0.34 (~17 лет) читается как худой подросток-юноша. Рост подобран под ~1,664 м тела.
    "phenotype": {
        "gender": 1.0, "age": 0.34, "muscle": 0.22, "weight": 0.12,
        "proportions": 0.5, "height": 0.6172, "cupsize": 0.5, "firmness": 0.5,
        "race": {"asian": 0.25, "caucasian": 0.75, "african": 0.0},
    },
    # Скелет в стиле UE-манекена: стандартный гуманоид, ретаргетинг в Godot через SkeletonProfileHumanoid.
    "rig": "game_engine",
    "eyes": "low-poly/low-poly.mhclo",
    "eyebrows": "eyebrow001/eyebrow001.mhclo",
    "eyelashes": "eyelashes02/eyelashes02.mhclo",
    "teeth": "",
    "tongue": "",
    "hair": "culturalibre_hair_05/culturalibre_hair_05.mhclo",
    "proxy": "",
    "targets": [],
    # Длинный рукав: короткий рукав футболки при опущенных руках пропускал кожу плеча сквозь ткань.
    # Толстовки в CC0-наборах нет; свитер перекрашивается в выцветший серый (см. CLOTH_TINTS).
    "clothes": ["toigo_fisherman_sweater/toigo_fisherman_sweater.mhclo", "toigo_wool_pants/toigo_wool_pants.mhclo",
                "shoes06/shoes06.mhclo"],
    "skin_mhmat": "young_caucasian_male/young_caucasian_male.mhmat",
    # Материалы «game engine» — простой Principled BSDF, который glTF-экспортёр переносит без потерь.
    "skin_material_type": "GAMEENGINE",
    "eyes_material_type": "GAMEENGINE",
    "clothes_material_type": "GAMEENGINE",
    "skin_material_settings": {},
    "eyes_material_settings": {},
    "expressions": [],
}


## Насколько затемнить текстуру волос (каштановая → почти чёрная, канон: волосы чёрные).
HAIR_DARKEN = 0.22
## Перекраска одежды: (насыщенность 0..1, множитель яркости, оттенок серого). Дешёвая выцветшая одежда.
CLOTH_TINTS = {
    "toigo_fisherman_sweater": (0.08, 1.9, (0.82, 0.81, 0.78)),
    "toigo_wool_pants": (0.15, 1.05, (0.80, 0.80, 0.82)),
}
## Ассеты с настоящей прозрачностью (пряди, ресницы). Остальным материалам альфа отключается:
## материал «game engine» MPFB экспортируется в glTF как BLEND, и Godot сортирует такие меши по расстоянию —
## тело рисовалось поверх одежды.
ALPHA_ASSETS = ("hair", "eyebrow", "eyelashes")
## Пары (внутренний слой, внешний слой) одежды.
LAYERS = [("toigo_wool_pants", "toigo_fisherman_sweater")]
## Пары, где внутренний слой только убирается под внешний, без удаления: задник кроссовка выходил сквозь штанину.
TUCK_ONLY = [("shoes06", "toigo_wool_pants")]
## Вершина тела считается закрытой, если луч по нормали упирается в одежду ближе этого расстояния, м.
COVER_DISTANCE = 0.06
## На сколько утопить закрытые, но не удалённые вершины тела, м.
SHRINK_UNDER_CLOTH = 0.012
## Ниже этой высоты тело не удаляется, только утапливается: под широким краем штанины иначе видна пустота
## между брюками и кроссовком, м.
KEEP_BODY_BELOW = 0.25


def remove_covered_body(body, cover_objects, keep_below=-1.0):
    """Удаляет участки тела под одеждой: иначе кожа проступает сквозь ткань при анимации."""
    import bmesh
    from mathutils.bvhtree import BVHTree
    deps = bpy.context.evaluated_depsgraph_get()
    trees = [BVHTree.FromObject(o, deps) for o in cover_objects]
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.normal_update()
    covered = []
    for v in bm.verts:
        origin = v.co + v.normal * 0.001
        if any(t.ray_cast(origin, v.normal, COVER_DISTANCE)[0] is not None for t in trees):
            covered.append(v)
    # Удаляются только грани, все вершины которых закрыты, — у края рукава кожа остаётся.
    covered_set = set(covered)
    faces = [f for f in bm.faces if all(v in covered_set and v.co.z >= keep_below for v in f.verts)]
    bmesh.ops.delete(bm, geom=faces, context="FACES_ONLY")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    # Оставшиеся закрытые вершины (кромки под рукавами, у ворота, на щиколотках) утапливаются внутрь,
    # чтобы при сгибах кожа не выходила сквозь ткань.
    for v in bm.verts:
        if v.is_valid and v in covered_set:
            v.co -= v.normal * SHRINK_UNDER_CLOTH
    bm.to_mesh(body.data)
    bm.free()
    return len(faces)


def tuck_under(inner, outer, depth=0.03, gap=0.006):
    """Вершины внутреннего слоя, оказавшиеся снаружи внешнего (пояс поверх подола), прячет под внешний слой."""
    import bmesh
    from mathutils.bvhtree import BVHTree
    tree = BVHTree.FromObject(outer, bpy.context.evaluated_depsgraph_get())
    bm = bmesh.new()
    bm.from_mesh(inner.data)
    bm.normal_update()
    moved = 0
    for v in bm.verts:
        hit = tree.ray_cast(v.co - v.normal * 0.0005, -v.normal, depth)
        if hit[0] is not None:
            v.co = hit[0] - v.normal * gap
            moved += 1
    bm.to_mesh(inner.data)
    bm.free()
    return moved


def trim_above_hem(inner, outer, overlap=0.03, torso_half_width=0.2):
    """Удаляет верх внутреннего слоя выше подола внешнего (с нахлёстом): пояс не выйдет сквозь ткань при ходьбе."""
    import bmesh
    hem = min(v.co.z for v in outer.data.vertices if abs(v.co.x) < torso_half_width)
    bm = bmesh.new()
    bm.from_mesh(inner.data)
    faces = [f for f in bm.faces if all(v.co.z > hem + overlap for v in f.verts)]
    bmesh.ops.delete(bm, geom=faces, context="FACES")
    bm.to_mesh(inner.data)
    bm.free()
    return len(faces)


def make_opaque(obj):
    for slot in obj.material_slots:
        mat = slot.material
        for node in mat.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED":
                for link in list(node.inputs["Alpha"].links):
                    mat.node_tree.links.remove(link)
                node.inputs["Alpha"].default_value = 1.0
        mat.surface_render_method = "DITHERED"


def _color_images(obj):
    for slot in obj.material_slots:
        for node in slot.material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image and node.image.colorspace_settings.name != "Non-Color" \
                    and "normal" not in node.image.name.lower():
                yield node.image


def recolor(obj, saturation, brightness, tint):
    """Меняет цвет текстуры (альфа не трогается): яркость сохраняет рисунок ткани или прядей."""
    import numpy as np
    for image in _color_images(obj):
        pixels = np.empty(len(image.pixels), dtype=np.float32)
        image.pixels.foreach_get(pixels)
        rgba = pixels.reshape(-1, 4)
        luminance = rgba[:, :3] @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
        gray = luminance[:, None] * np.array(tint, dtype=np.float32)
        rgba[:, :3] = (gray + (rgba[:, :3] - gray) * saturation) * brightness
        image.pixels.foreach_set(pixels)
        image.update()
        image.pack()


def main(out_path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    settings = HumanService.get_default_deserialization_settings()
    settings["subdiv_levels"] = 0
    basemesh = HumanService.deserialize_from_dict(json.loads(json.dumps(PRESET)), settings)

    # Морф-цели макросов и маски скрытого под одеждой тела запекаются в геометрию, хелперы удаляются.
    ExportService.bake_modifiers_remove_helpers(basemesh, bake_masks=True, bake_subdiv=False, remove_helpers=True)

    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    # Ключи формы (макросы фигуры и лица) применяются в геометрию, а не сбрасываются: сброс возвращал
    # тело к усреднённому базовому мешу, и одежда, подогнанная под итоговую фигуру, оказывалась внутри тела.
    for obj in meshes:
        if obj.data.shape_keys:
            bpy.ops.object.select_all(action="DESELECT")
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            bpy.ops.object.shape_key_remove(all=True, apply_mix=True)

    clothes = [o for o in meshes if any(c.split("/")[0] in o.name for c in PRESET["clothes"])]
    print("COVERED_FACES_REMOVED", remove_covered_body(basemesh, clothes, keep_below=KEEP_BODY_BELOW))
    # Слои одежды: пояс брюк уходит под свитер.
    for inner, outer in LAYERS:
        inner_obj = next((o for o in clothes if inner in o.name), None)
        outer_obj = next((o for o in clothes if outer in o.name), None)
        if inner_obj and outer_obj:
            print("LAYER", inner, "under", outer, remove_covered_body(inner_obj, [outer_obj]),
                  "tucked", tuck_under(inner_obj, outer_obj), "trimmed", trim_above_hem(inner_obj, outer_obj))
    for inner, outer in TUCK_ONLY:
        inner_obj = next((o for o in clothes if inner in o.name), None)
        outer_obj = next((o for o in clothes if outer in o.name), None)
        if inner_obj and outer_obj:
            print("TUCK", inner, "under", outer, tuck_under(inner_obj, outer_obj))
    hair_name = PRESET["hair"].split("/")[0]
    for obj in meshes:
        if hair_name in obj.name:
            recolor(obj, 1.0, HAIR_DARKEN, (1.0, 1.0, 1.0))
        for cloth, (saturation, brightness, tint) in CLOTH_TINTS.items():
            if cloth in obj.name:
                recolor(obj, saturation, brightness, tint)
        if not any(tag in obj.name for tag in ALPHA_ASSETS):
            make_opaque(obj)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        export_apply=True,
        export_animations=False,
        export_morph=False,
        export_skins=True,
        export_yup=True,
    )

    deps = bpy.context.evaluated_depsgraph_get()
    tris = 0
    for obj in meshes:
        ev = obj.evaluated_get(deps)
        mesh = ev.to_mesh()
        mesh.calc_loop_triangles()
        tris += len(mesh.loop_triangles)
        print("MESH", obj.name, len(mesh.loop_triangles), [s.material.name for s in obj.material_slots if s.material])
        ev.to_mesh_clear()
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    zs = [(basemesh.matrix_world @ v.co).z for v in basemesh.data.vertices]
    print("TOTAL_TRIS", tris, "BONES", len(rig.data.bones), "BODY_HEIGHT", round(max(zs) - min(zs), 4))


if __name__ == "__main__":
    main(os.path.abspath(sys.argv[sys.argv.index("--") + 1]))
