"""Сборка типовых временных NPC (MPFB 2, Blender 5.1) и экспорт в GLB.

Все архетипы — один и тот же гуманоид MakeHuman на скелете «game_engine» (как у Санни), поэтому к ним
подходит та же библиотека анимаций Quaternius UAL. Позже каждого нужного персонажа собирают отдельно
по образцу build_sunny_poc.py.

Запуск:
    blender -b --python build_placeholder_humans.py -- <каталог вывода> [архетип ...]
"""
import json
import os
import sys

import bpy
from bl_ext.blender_org.mpfb.services import ExportService, HumanService

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "..", "sunny_realistic_poc", "source"))
import build_sunny_poc as sunny  # noqa: E402  (функции снятия тела под одеждой и перекраски)

BASE = {
    "rig": "game_engine",
    "eyes": "low-poly/low-poly.mhclo",
    "eyelashes": "eyelashes02/eyelashes02.mhclo",
    "teeth": "",
    "tongue": "",
    "proxy": "",
    "targets": [],
    "skin_material_type": "GAMEENGINE",
    "eyes_material_type": "GAMEENGINE",
    "clothes_material_type": "GAMEENGINE",
    "skin_material_settings": {},
    "eyes_material_settings": {},
    "expressions": [],
}


def _phenotype(gender, age, muscle, weight, height):
    return {
        "gender": gender, "age": age, "muscle": muscle, "weight": weight,
        "proportions": 0.5, "height": height, "cupsize": 0.5, "firmness": 0.5,
        "race": {"asian": 0.1, "caucasian": 0.8, "african": 0.1},
    }


## Архетипы. tints: имя одежды -> (насыщенность, яркость, оттенок серого), как CLOTH_TINTS у Санни.
## layers: (внутренний, внешний) слой одежды; tuck: только убрать внутренний под внешний.
ARCHETYPES = {
    "townsman": {
        "phenotype": _phenotype(1.0, 0.5, 0.5, 0.5, 0.55),
        "skin": "middleage_caucasian_male/middleage_caucasian_male.mhmat",
        "hair": "short02/short02.mhclo", "eyebrows": "eyebrow002/eyebrow002.mhclo",
        "clothes": ["male_casualsuit02/male_casualsuit02.mhclo", "shoes02/shoes02.mhclo"],
        "tints": {}, "layers": [], "tuck": [("shoes02", "male_casualsuit02")],
    },
    "townswoman": {
        "phenotype": _phenotype(0.0, 0.45, 0.4, 0.5, 0.5),
        "skin": "young_caucasian_female/young_caucasian_female.mhmat",
        "hair": "bob02/bob02.mhclo", "eyebrows": "eyebrow010/eyebrow010.mhclo",
        "clothes": ["female_casualsuit01/female_casualsuit01.mhclo", "shoes03/shoes03.mhclo"],
        "tints": {}, "layers": [], "tuck": [("shoes03", "female_casualsuit01")],
    },
    "police": {
        "phenotype": _phenotype(1.0, 0.45, 0.65, 0.5, 0.6),
        "skin": "middleage_caucasian_male/middleage_caucasian_male.mhmat",
        "hair": "short01/short01.mhclo", "eyebrows": "eyebrow002/eyebrow002.mhclo",
        # Тёмно-синее поло и брюки — современная полицейская форма.
        "clothes": ["namuhekam_male_polo_shirt/namuhekam_male_polo_shirt.mhclo",
                    "cortu_cargo_pants/cortu_cargo_pants.mhclo", "shoes05/shoes05.mhclo"],
        "tints": {"namuhekam_male_polo_shirt": (0.0, 1.0, (0.36, 0.45, 0.8)),
                  "cortu_cargo_pants": (0.0, 0.45, (0.45, 0.5, 0.7)), "shoes05": (0.0, 0.35, (1, 1, 1))},
        "layers": [("cortu_cargo_pants", "namuhekam_male_polo_shirt")], "tuck": [("shoes05", "cortu_cargo_pants")],
    },
    "slave": {
        "phenotype": _phenotype(1.0, 0.4, 0.45, 0.2, 0.5),
        "skin": "middleage_caucasian_male/middleage_caucasian_male.mhmat",
        "hair": "cortu_short_messy_hair/cortu_short_messy_hair.mhclo", "eyebrows": "eyebrow003/eyebrow003.mhclo",
        # Босой: обуви нет.
        "clothes": ["elvs_crude_t-shirt_male/elvs_crude_t-shirt_male.mhclo",
                    "toigo_wool_pants/toigo_wool_pants.mhclo"],
        "tints": {"elvs_crude_t-shirt_male": (0.1, 0.75, (0.86, 0.78, 0.64)),
                  "toigo_wool_pants": (0.05, 0.9, (0.82, 0.74, 0.62))},
        "layers": [("toigo_wool_pants", "elvs_crude_t-shirt_male")], "tuck": [],
    },
    "knight": {
        "phenotype": _phenotype(1.0, 0.5, 0.8, 0.55, 0.62),
        "skin": "middleage_caucasian_male/middleage_caucasian_male.mhmat",
        "hair": "short02/short02.mhclo", "eyebrows": "eyebrow002/eyebrow002.mhclo",
        # Свитер — стёганый поддоспешник; кираса и шлем строятся поверх (add_armor).
        "clothes": ["toigo_fisherman_sweater/toigo_fisherman_sweater.mhclo",
                    "cortu_cargo_pants/cortu_cargo_pants.mhclo", "shoes05/shoes05.mhclo"],
        "tints": {"toigo_fisherman_sweater": (0.3, 1.4, (0.75, 0.62, 0.48)),
                  "cortu_cargo_pants": (0.1, 0.8, (0.7, 0.66, 0.6)), "shoes05": (0.2, 0.5, (0.8, 0.65, 0.5))},
        "layers": [("cortu_cargo_pants", "toigo_fisherman_sweater")], "tuck": [("shoes05", "cortu_cargo_pants")],
        "armor": True,
    },
}

## Кираса: копия поддоспешника, выдавленная наружу, без рукавов и подола.
CUIRASS_OFFSET = 0.018
CUIRASS_HALF_WIDTH = 0.19
MAX_TEXTURE = 1024


def _metal(name, color, roughness, metallic):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def add_armor(rig, body, gambeson):
    import bmesh
    # Не чистый металл: без отражений окружения (интерьеры, ночь) кираса иначе выглядит чёрной.
    metal = _metal("knight_steel", (0.5, 0.5, 0.52), 0.45, 0.6)

    cuirass = gambeson.copy()
    cuirass.data = gambeson.data.copy()
    cuirass.name = "knight_cuirass"
    bpy.context.collection.objects.link(cuirass)
    cuirass.data.materials.clear()
    cuirass.data.materials.append(metal)
    bm = bmesh.new()
    bm.from_mesh(cuirass.data)
    bm.normal_update()
    zs = [v.co.z for v in bm.verts]
    top, bottom = max(zs), min(zs)
    waist = bottom + (top - bottom) * 0.12
    drop = [f for f in bm.faces if any(abs(v.co.x) > CUIRASS_HALF_WIDTH or v.co.z < waist for v in f.verts)]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    for v in bm.verts:
        v.co += v.normal * CUIRASS_OFFSET
    bm.to_mesh(cuirass.data)
    bm.free()

    # Шлем-капеллина: полусфера с полями, целиком на кости головы.
    head_bone = next(b for b in rig.data.bones if b.name.lower() == "head")
    head_top = max((body.matrix_world @ v.co).z for v in body.data.vertices)
    center = rig.matrix_world @ head_bone.head_local
    radius = 0.125
    cap_z = head_top - radius * 0.72
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=radius)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.005], context="VERTS")
    for v in bm.verts:
        v.co.y *= 1.12
    brim = bmesh.ops.create_cone(bm, segments=24, radius1=radius * 1.35, radius2=radius * 1.02,
                                 depth=0.02, cap_ends=False)
    for v in brim["verts"]:
        v.co.z -= 0.005
        v.co.y *= 1.08
    bm.normal_update()
    mesh = bpy.data.meshes.new("knight_helmet")
    bm.to_mesh(mesh)
    bm.free()
    mesh.shade_smooth()
    helmet = bpy.data.objects.new("knight_helmet", mesh)
    bpy.context.collection.objects.link(helmet)
    helmet.location = (center.x, center.y, cap_z)
    mesh.materials.append(metal)
    bpy.ops.object.select_all(action="DESELECT")
    helmet.select_set(True)
    bpy.context.view_layer.objects.active = helmet
    bpy.ops.object.transform_apply(location=True)
    group = helmet.vertex_groups.new(name=head_bone.name)
    group.add(range(len(mesh.vertices)), 1.0, "REPLACE")
    helmet.parent = rig
    mod = helmet.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    return [cuirass, helmet]


def build(name, spec, out_dir):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    preset = dict(BASE)
    preset.update({"name": name, "phenotype": spec["phenotype"], "skin_mhmat": spec["skin"],
                   "hair": spec["hair"], "eyebrows": spec["eyebrows"], "clothes": spec["clothes"]})
    settings = HumanService.get_default_deserialization_settings()
    settings["subdiv_levels"] = 0
    basemesh = HumanService.deserialize_from_dict(json.loads(json.dumps(preset)), settings)
    ExportService.bake_modifiers_remove_helpers(basemesh, bake_masks=True, bake_subdiv=False, remove_helpers=True)

    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for obj in meshes:
        if obj.data.shape_keys:
            bpy.ops.object.select_all(action="DESELECT")
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            bpy.ops.object.shape_key_remove(all=True, apply_mix=True)

    def find(tag):
        return next((o for o in meshes if tag in o.name), None)

    clothes = [o for o in meshes if any(c.split("/")[0] in o.name for c in spec["clothes"])]
    print(name, "COVERED_FACES_REMOVED", sunny.remove_covered_body(basemesh, clothes, keep_below=sunny.KEEP_BODY_BELOW))
    for inner, outer in spec["layers"]:
        inner_obj, outer_obj = find(inner), find(outer)
        if inner_obj and outer_obj:
            sunny.remove_covered_body(inner_obj, [outer_obj])
            sunny.tuck_under(inner_obj, outer_obj)
            sunny.trim_above_hem(inner_obj, outer_obj)
    for inner, outer in spec["tuck"]:
        inner_obj, outer_obj = find(inner), find(outer)
        if inner_obj and outer_obj:
            sunny.tuck_under(inner_obj, outer_obj)

    for obj in meshes:
        for cloth, (saturation, brightness, tint) in spec["tints"].items():
            if cloth in obj.name:
                sunny.recolor(obj, saturation, brightness, tint)
        if not any(tag in obj.name for tag in sunny.ALPHA_ASSETS):
            sunny.make_opaque(obj)

    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    if spec.get("armor"):
        add_armor(rig, basemesh, find("toigo_fisherman_sweater"))

    # Заглушкам хватает 1K: исходные текстуры MakeHuman 2K–4K раздували GLB до ~20 МБ.
    for image in bpy.data.images:
        w, h = image.size
        if max(w, h) > MAX_TEXTURE:
            k = MAX_TEXTURE / max(w, h)
            image.scale(int(w * k), int(h * k))
            image.pack()

    out_path = os.path.join(out_dir, name + ".glb")
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_apply=True,
                              export_animations=False, export_morph=False, export_skins=True, export_yup=True)
    zs = [(basemesh.matrix_world @ v.co).z for v in basemesh.data.vertices]
    tris = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
    print("BUILT", name, "FACES", tris, "BODY_HEIGHT", round(max(zs) - min(zs), 4), out_path)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    out = os.path.abspath(args[0])
    for key in args[1:] or ARCHETYPES:
        build(key, ARCHETYPES[key], out)
