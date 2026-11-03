"""P1 main cast builder: MPFB humans + authored gear + 3 LOD layers per character.

Run:
  blender -b --python assets/characters/p1/source/build_main_cast.py -- <output_dir> [character ...]

Characters:
  sunny_real, sunny_nightmare, police_desk, police_guard, hero_auro, scholar,
  shifty, veteran, mass_male, mass_female, mass_slave, mass_soldier, mass_police

Every character uses the MPFB 'game_engine' skeleton, so the existing UAL animation
library applies.  LOD0 is the original mesh; LOD1/LOD2 are copies sharing the same
armature and vertex groups.  All LODs are exported in one GLB; the game-side
CharacterLodVisibility script toggles them by camera distance.
"""
from __future__ import annotations

import json
import math
import os
import random
import re
import sys

import bpy
import bmesh
from mathutils import Vector, Euler

from bl_ext.blender_org.mpfb.services import ExportService, HumanService

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, "..", "..", "sunny_realistic_poc", "source"))
import build_sunny_poc as sunny  # noqa: E402

PROJECT_ROOT = os.path.abspath(os.path.join(_HERE, "..", "..", "..", ".."))
TEXTURE_ROOT = os.path.join(PROJECT_ROOT, "assets", "environments", "nightmare", "materials", "textures")

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


def phenotype(gender, age, muscle, weight, height, asian=0.1, caucasian=0.8, african=0.1):
    return {
        "gender": gender, "age": age, "muscle": muscle, "weight": weight,
        "proportions": 0.5, "height": height, "cupsize": 0.5, "firmness": 0.5,
        "race": {"asian": asian, "caucasian": caucasian, "african": african},
    }


SPECS = {
    "sunny_real": {
        "phenotype": phenotype(1.0, 0.33, 0.18, 0.09, 0.6172, 0.25, 0.75, 0.0),
        "skin": "toigo_light_skin_male_with_goth_makeup/toigo_light_skin_male_with_goth_makeup.mhmat",
        "hair": "cortu_short_messy_hair/cortu_short_messy_hair.mhclo",
        "eyebrows": "eyebrow001/eyebrow001.mhclo",
        "clothes": ["toigo_fisherman_sweater/toigo_fisherman_sweater.mhclo",
                    "toigo_wool_pants/toigo_wool_pants.mhclo", "shoes06/shoes06.mhclo"],
        "tints": {
            "toigo_fisherman_sweater": (0.05, 1.68, (0.80, 0.79, 0.76)),
            "toigo_wool_pants": (0.10, 0.86, (0.60, 0.60, 0.64)),
            "shoes06": (0.0, 0.38, (0.8, 0.8, 0.8)),
        },
        "layers": [("toigo_wool_pants", "toigo_fisherman_sweater")],
        "tuck": [("shoes06", "toigo_wool_pants")],
        "gear": "sunny_real",
        "skin_tint": (0.72, 1.06, (1.0, 0.97, 0.96)),
        "hair_tint": (1.0, 0.16, (1.0, 1.0, 1.0)),
        "lod2_remove": ["eyebrow", "eyelashes", "hood"],
    },
    "sunny_nightmare": {
        "phenotype": phenotype(1.0, 0.33, 0.18, 0.09, 0.6172, 0.25, 0.75, 0.0),
        "skin": "toigo_light_skin_male_with_goth_makeup/toigo_light_skin_male_with_goth_makeup.mhmat",
        "hair": "cortu_short_messy_hair/cortu_short_messy_hair.mhclo",
        "eyebrows": "eyebrow001/eyebrow001.mhclo",
        "clothes": ["elvs_crude_t-shirt_male/elvs_crude_t-shirt_male.mhclo",
                    "toigo_wool_pants/toigo_wool_pants.mhclo"],
        "tints": {
            "elvs_crude_t-shirt_male": (0.08, 0.82, (0.78, 0.73, 0.62)),
            "toigo_wool_pants": (0.08, 0.72, (0.62, 0.58, 0.52)),
        },
        "layers": [("toigo_wool_pants", "elvs_crude_t-shirt_male")],
        "tuck": [],
        "gear": "sunny_nightmare",
        "skin_tint": (0.72, 1.04, (0.97, 0.94, 0.91)),
        "hair_tint": (1.0, 0.15, (1.0, 1.0, 1.0)),
        "lod2_remove": ["eyebrow", "eyelashes", "cuff"],
    },
    "police_desk": {
        "phenotype": phenotype(1.0, 0.55, 0.43, 0.56, 0.635, 0.08, 0.87, 0.05),
        "skin": "middleage_caucasian_male/middleage_caucasian_male.mhmat",
        "hair": "short03/short03.mhclo",
        "eyebrows": "eyebrow002/eyebrow002.mhclo",
        "clothes": ["namuhekam_male_polo_shirt/namuhekam_male_polo_shirt.mhclo",
                    "cortu_cargo_pants/cortu_cargo_pants.mhclo", "shoes05/shoes05.mhclo"],
        "tints": {
            "namuhekam_male_polo_shirt": (0.0, 0.46, (0.30, 0.38, 0.72)),
            "cortu_cargo_pants": (0.0, 0.34, (0.40, 0.46, 0.66)),
            "shoes05": (0.0, 0.22, (0.55, 0.55, 0.55)),
        },
        "layers": [("cortu_cargo_pants", "namuhekam_male_polo_shirt")],
        "tuck": [("shoes05", "cortu_cargo_pants")],
        "gear": "police_desk",
        "hair_tint": (0.0, 1.55, (0.78, 0.78, 0.78)),
        "lod2_remove": ["badge", "radio", "shoulder", "eyebrow", "eyelashes"],
    },
    "police_guard": {
        "phenotype": phenotype(1.0, 0.36, 0.62, 0.48, 0.642, 0.05, 0.9, 0.05),
        "skin": "middleage_caucasian_male/middleage_caucasian_male.mhmat",
        "hair": "short01/short01.mhclo",
        "eyebrows": "eyebrow002/eyebrow002.mhclo",
        "clothes": ["namuhekam_male_polo_shirt/namuhekam_male_polo_shirt.mhclo",
                    "cortu_cargo_pants/cortu_cargo_pants.mhclo", "shoes05/shoes05.mhclo"],
        "tints": {
            "namuhekam_male_polo_shirt": (0.0, 0.38, (0.26, 0.34, 0.60)),
            "cortu_cargo_pants": (0.0, 0.32, (0.36, 0.42, 0.58)),
            "shoes05": (0.0, 0.20, (0.45, 0.45, 0.45)),
        },
        "layers": [("cortu_cargo_pants", "namuhekam_male_polo_shirt")],
        "tuck": [("shoes05", "cortu_cargo_pants")],
        "gear": "police_guard",
        "hair_tint": (0.0, 0.24, (1.0, 1.0, 1.0)),
        "lod2_remove": ["badge", "radio", "shoulder", "eyebrow", "eyelashes"],
    },
    "hero_auro": {
        "phenotype": phenotype(1.0, 0.31, 0.56, 0.48, 0.655, 0.04, 0.92, 0.04),
        "skin": "young_caucasian_male/young_caucasian_male.mhmat",
        "hair": "culturalibre_hair_01/culturalibre_hair_01.mhclo",
        "eyebrows": "eyebrow002/eyebrow002.mhclo",
        "clothes": ["toigo_fisherman_sweater/toigo_fisherman_sweater.mhclo",
                    "cortu_cargo_pants/cortu_cargo_pants.mhclo", "shoes05/shoes05.mhclo"],
        "tints": {
            "toigo_fisherman_sweater": (0.20, 1.05, (0.74, 0.64, 0.50)),
            "cortu_cargo_pants": (0.08, 0.60, (0.48, 0.42, 0.35)),
            "shoes05": (0.10, 0.60, (0.55, 0.45, 0.34)),
        },
        "layers": [("cortu_cargo_pants", "toigo_fisherman_sweater")],
        "tuck": [("shoes05", "cortu_cargo_pants")],
        "gear": "hero",
        "hair_tint": (0.85, 0.82, (0.92, 0.80, 0.62)),
        "lod2_remove": ["pauldron", "clasp", "eyebrow", "eyelashes"],
    },
    "scholar": {
        "phenotype": phenotype(1.0, 0.49, 0.33, 0.35, 0.648, 0.08, 0.87, 0.05),
        "skin": "middleage_caucasian_male/middleage_caucasian_male.mhmat",
        "hair": "culturalibre_hair_02/culturalibre_hair_02.mhclo",
        "eyebrows": "eyebrow002/eyebrow002.mhclo",
        "clothes": ["male_elegantsuit01/male_elegantsuit01.mhclo", "shoes05/shoes05.mhclo"],
        "tints": {
            "male_elegantsuit01": (0.04, 0.42, (0.30, 0.32, 0.38)),
            "shoes05": (0.0, 0.24, (0.35, 0.35, 0.36)),
        },
        "layers": [],
        "tuck": [("shoes05", "male_elegantsuit01")],
        "gear": "scholar",
        "hair_tint": (0.55, 0.55, (0.56, 0.54, 0.50)),
        "lod2_remove": ["glasses", "collar", "eyebrow", "eyelashes"],
    },
    "shifty": {
        "phenotype": phenotype(1.0, 0.38, 0.39, 0.19, 0.62, 0.10, 0.82, 0.08),
        "skin": "middleage_caucasian_male/middleage_caucasian_male.mhmat",
        "hair": "cortu_short_messy_hair/cortu_short_messy_hair.mhclo",
        "eyebrows": "eyebrow003/eyebrow003.mhclo",
        "clothes": ["elvs_crude_t-shirt_male/elvs_crude_t-shirt_male.mhclo",
                    "toigo_wool_pants/toigo_wool_pants.mhclo", "shoes03/shoes03.mhclo"],
        "tints": {
            "elvs_crude_t-shirt_male": (0.08, 0.68, (0.62, 0.56, 0.44)),
            "toigo_wool_pants": (0.10, 0.58, (0.47, 0.43, 0.36)),
            "shoes03": (0.0, 0.30, (0.35, 0.33, 0.30)),
        },
        "layers": [("toigo_wool_pants", "elvs_crude_t-shirt_male")],
        "tuck": [("shoes03", "toigo_wool_pants")],
        "gear": "shifty",
        "hair_tint": (1.0, 0.19, (1.0, 1.0, 1.0)),
        "lod2_remove": ["scarf", "eyebrow", "eyelashes"],
    },
    "veteran": {
        "phenotype": phenotype(1.0, 0.67, 0.62, 0.66, 0.63, 0.05, 0.9, 0.05),
        "skin": "old_caucasian_male/old_caucasian_male.mhmat",
        "hair": "short04/short04.mhclo",
        "eyebrows": "eyebrow002/eyebrow002.mhclo",
        "clothes": ["male_worksuit01/male_worksuit01.mhclo",
                    "cortu_cargo_pants/cortu_cargo_pants.mhclo", "shoes05/shoes05.mhclo"],
        "tints": {
            "male_worksuit01": (0.03, 0.34, (0.36, 0.32, 0.28)),
            "cortu_cargo_pants": (0.02, 0.28, (0.30, 0.27, 0.24)),
            "shoes05": (0.0, 0.18, (0.30, 0.28, 0.25)),
        },
        "layers": [("cortu_cargo_pants", "male_worksuit01")],
        "tuck": [("shoes05", "cortu_cargo_pants")],
        "gear": "veteran",
        "hair_tint": (0.0, 1.25, (0.72, 0.72, 0.70)),
        "lod2_remove": ["fur", "pauldron", "eyebrow", "eyelashes"],
    },
    "mass_male": {
        "phenotype": phenotype(1.0, 0.48, 0.5, 0.5, 0.63, 0.15, 0.7, 0.15),
        "skin": "middleage_caucasian_male/middleage_caucasian_male.mhmat",
        "hair": "short02/short02.mhclo", "eyebrows": "",
        "clothes": ["male_casualsuit02/male_casualsuit02.mhclo", "shoes02/shoes02.mhclo"],
        "tints": {"male_casualsuit02": (0.05, 1.8, (0.62, 0.66, 0.68)), "shoes02": (0.0, 0.8, (0.7, 0.7, 0.7))},
        "layers": [], "tuck": [("shoes02", "male_casualsuit02")],
        "mass": True, "mass_remove": ["low-poly", "eyebrow", "eyelashes"],
        "mass_ratio": 0.18, "mass_texture": 512,
    },
    "mass_female": {
        "phenotype": phenotype(0.0, 0.45, 0.4, 0.5, 0.59, 0.18, 0.72, 0.10),
        "skin": "young_caucasian_female/young_caucasian_female.mhmat",
        "hair": "bob02/bob02.mhclo", "eyebrows": "",
        "clothes": ["female_casualsuit01/female_casualsuit01.mhclo", "shoes03/shoes03.mhclo"],
        "tints": {"female_casualsuit01": (0.06, 1.9, (0.66, 0.66, 0.68)), "shoes03": (0.0, 0.8, (0.6, 0.6, 0.6))},
        "layers": [], "tuck": [("shoes03", "female_casualsuit01")],
        "mass": True, "mass_remove": ["low-poly", "eyebrow", "eyelashes"],
        "mass_ratio": 0.18, "mass_texture": 512,
    },
    "mass_slave": {
        "phenotype": phenotype(1.0, 0.4, 0.35, 0.22, 0.59, 0.15, 0.75, 0.10),
        "skin": "middleage_caucasian_male/middleage_caucasian_male.mhmat",
        "hair": "cortu_short_messy_hair/cortu_short_messy_hair.mhclo", "eyebrows": "",
        "clothes": ["elvs_crude_t-shirt_male/elvs_crude_t-shirt_male.mhclo",
                    "toigo_wool_pants/toigo_wool_pants.mhclo"],
        "tints": {"elvs_crude_t-shirt_male": (0.05, 1.6, (0.62, 0.54, 0.42)),
                  "toigo_wool_pants": (0.05, 1.4, (0.55, 0.48, 0.40))},
        "layers": [("toigo_wool_pants", "elvs_crude_t-shirt_male")], "tuck": [],
        "mass": True, "mass_remove": ["low-poly", "eyebrow", "eyelashes"],
        "mass_ratio": 0.18, "mass_texture": 512,
    },
    "mass_soldier": {
        "phenotype": phenotype(1.0, 0.47, 0.62, 0.56, 0.64, 0.10, 0.84, 0.06),
        "skin": "middleage_caucasian_male/middleage_caucasian_male.mhmat",
        "hair": "short02/short02.mhclo", "eyebrows": "",
        "clothes": ["toigo_fisherman_sweater/toigo_fisherman_sweater.mhclo",
                    "cortu_cargo_pants/cortu_cargo_pants.mhclo", "shoes05/shoes05.mhclo"],
        "tints": {"toigo_fisherman_sweater": (0.08, 1.4, (0.58, 0.48, 0.36)),
                  "cortu_cargo_pants": (0.05, 1.2, (0.42, 0.38, 0.32)), "shoes05": (0.0, 0.6, (0.36, 0.34, 0.30))},
        "layers": [("cortu_cargo_pants", "toigo_fisherman_sweater")],
        "tuck": [("shoes05", "cortu_cargo_pants")],
        "mass": True, "mass_remove": ["low-poly", "eyebrow", "eyelashes"],
        "mass_ratio": 0.18, "mass_texture": 512,
    },
    "mass_police": {
        "phenotype": phenotype(1.0, 0.45, 0.58, 0.5, 0.63, 0.08, 0.86, 0.06),
        "skin": "middleage_caucasian_male/middleage_caucasian_male.mhmat",
        "hair": "short01/short01.mhclo", "eyebrows": "",
        "clothes": ["namuhekam_male_polo_shirt/namuhekam_male_polo_shirt.mhclo",
                    "cortu_cargo_pants/cortu_cargo_pants.mhclo", "shoes05/shoes05.mhclo"],
        "tints": {"namuhekam_male_polo_shirt": (0.0, 1.1, (0.30, 0.38, 0.65)),
                  "cortu_cargo_pants": (0.0, 1.0, (0.40, 0.45, 0.58)), "shoes05": (0.0, 0.5, (0.40, 0.40, 0.40))},
        "layers": [("cortu_cargo_pants", "namuhekam_male_polo_shirt")],
        "tuck": [("shoes05", "cortu_cargo_pants")],
        "mass": True, "mass_remove": ["low-poly", "eyebrow", "eyelashes"],
        "mass_ratio": 0.18, "mass_texture": 512,
    },
}

MAX_TEXTURE = 1024


# ---------------------------------------------------------------------------
# material / primitive helpers
# ---------------------------------------------------------------------------

def material(name, color, roughness=0.7, metallic=0.0, emission=None, image_path=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 0.8
    if image_path and os.path.exists(image_path):
        image = bpy.data.images.load(image_path, check_existing=True)
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def _mesh_object(name, bm, mat):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    if mat is not None:
        mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    for poly in mesh.polygons:
        poly.use_smooth = True
    return obj


def add_sphere(name, location, scale, mat, segments=16, rings=10):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2])) + Vector(location)
    return _mesh_object(name, bm, mat)


def add_box(name, location, size, mat, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(location)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect="EDGES", clamp_overlap=True)
    return _mesh_object(name, bm, mat)


def add_cylinder(name, location, radius, depth, mat, segments=16, radius2=None, rotation=(0, 0, 0)):
    bm = bmesh.new()
    r2 = radius if radius2 is None else radius2
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments,
                          radius1=radius, radius2=r2, depth=depth)
    rot = Euler(rotation, "XYZ").to_matrix()
    for v in bm.verts:
        v.co = rot @ v.co + Vector(location)
    return _mesh_object(name, bm, mat)


def add_cone_between(name, start, end, r1, r2, mat, segments=8):
    start = Vector(start)
    end = Vector(end)
    direction = end - start
    length = direction.length
    if length < 1e-5:
        return None
    mid = (start + end) * 0.5
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments,
                          radius1=r1, radius2=r2, depth=length)
    z = Vector((0, 0, 1))
    rot = z.rotation_difference(direction.normalized()).to_matrix()
    for v in bm.verts:
        v.co = rot @ v.co + mid
    return _mesh_object(name, bm, mat)


def add_ring(name, location, major_radius, minor_radius, mat, rotation=(math.radians(90), 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_radius, minor_radius=minor_radius,
                                     major_segments=16, minor_segments=4, location=location,
                                     rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    if obj.data.materials:
        obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def add_tuft_cloud(name, mat, centers, base_dir, length, radius, seed=1, segments=4):
    rng = random.Random(seed)
    bm = bmesh.new()
    for center in centers:
        c = Vector(center)
        d = Vector(base_dir) + Vector((rng.uniform(-0.45, 0.45), rng.uniform(-0.25, 0.25),
                                        rng.uniform(-0.25, 0.25)))
        if d.length < 1e-4:
            d = Vector((0, 0, 1))
        d.normalize()
        l = length * rng.uniform(0.65, 1.25)
        r = radius * rng.uniform(0.65, 1.2)
        ret = bmesh.ops.create_cone(bm, cap_ends=False, cap_tris=False, segments=segments,
                                    radius1=r, radius2=0.01, depth=l)
        z = Vector((0, 0, 1))
        rot = z.rotation_difference(d).to_matrix()
        for v in ret["verts"]:
            v.co = rot @ v.co + c + d * (l * 0.5)
    return _mesh_object(name, bm, mat)


def apply_transform(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def bind_rigid(obj, rig, bone_name):
    apply_transform(obj)
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()
    group = obj.vertex_groups.new(name=bone_name)
    group.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    return obj


def bind_weighted(obj, rig, weight_fn):
    apply_transform(obj)
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()
    groups = {}
    for bone_name in ("pelvis", "spine_01", "spine_02", "spine_03"):
        groups[bone_name] = obj.vertex_groups.new(name=bone_name)
    for v in obj.data.vertices:
        weights = weight_fn(v.co)
        total = sum(w for _, w in weights)
        if total <= 0:
            weights = [("spine_02", 1.0)]
            total = 1.0
        for bone_name, weight in weights:
            if weight > 0:
                groups[bone_name].add([v.index], weight / total, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    return obj


def _bone(rig, name):
    return rig.data.bones.get(name)


def _bone_head(rig, name):
    bone = _bone(rig, name)
    return (rig.matrix_world @ bone.head_local) if bone else Vector.ZERO


def _body_coords(body):
    return [body.matrix_world @ v.co for v in body.data.vertices]


def _body_width(body):
    coords = _body_coords(body)
    return max(v.x for v in coords) - min(v.x for v in coords)


# ---------------------------------------------------------------------------
# authored gear
# ---------------------------------------------------------------------------

def add_vest_from_cloth(rig, source, name, mat, half_width=0.22, hem_z=0.9, top_z=1.55, offset=0.014):
    dup = source.copy()
    dup.data = source.data.copy()
    dup.name = name
    bpy.context.collection.objects.link(dup)
    dup.data.materials.clear()
    dup.data.materials.append(mat)
    bm = bmesh.new()
    bm.from_mesh(dup.data)
    bm.normal_update()
    drop = [f for f in bm.faces if any(abs(v.co.x) > half_width or v.co.z < hem_z or v.co.z > top_z for v in f.verts)]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    for v in bm.verts:
        v.co += v.normal * offset
    bm.to_mesh(dup.data)
    bm.free()
    return dup


def add_police_gear(rig, meshes, spec):
    # Ключевая полиция: простая читаемая форма, без тяжёлой брони и головных уборов,
    # которые при жёстком креплении к голове давали смещения.
    belt_mat = material("police_belt", (0.025, 0.025, 0.025), 0.62)
    add_cylinder("police_belt", (0, 0, 0.96), 0.19, 0.05, belt_mat, segments=20)
    bind_rigid(bpy.context.object, rig, "pelvis")
    badge_mat = material("police_badge", (0.63, 0.52, 0.22), 0.3, 0.8)
    add_cylinder("police_badge", (0.13, -0.18, 1.35), 0.04, 0.012, badge_mat, segments=6, rotation=(math.radians(90), 0, 0))
    bind_rigid(bpy.context.object, rig, "spine_03")
    radio_mat = material("police_radio", (0.02, 0.02, 0.022), 0.55)
    add_box("police_radio", (-0.17, -0.14, 1.32), (0.06, 0.045, 0.14), radio_mat, 0.006)
    bind_rigid(bpy.context.object, rig, "spine_03")


def add_leather_cuirass(rig, meshes, name, color, half_width=0.22, hem_z=0.88, top_z=1.54, offset=0.02):
    source = next((o for o in meshes if "toigo_fisherman_sweater" in o.name or "male_worksuit01" in o.name), None)
    if source is None:
        return None
    mat = material(name + "_mat", color, 0.62, 0.0, image_path=os.path.join(TEXTURE_ROOT, "brown_leather_diff_1k.jpg"))
    cuirass = add_vest_from_cloth(rig, source, name, mat, half_width, hem_z, top_z, offset)
    return cuirass


def add_cape(rig, name, mat, top_z, bottom_z, width, back_y, rows=7, cols=9, wave=0.02):
    verts = []
    faces = []
    for r in range(rows):
        t = r / (rows - 1)
        z = top_z + (bottom_z - top_z) * t
        w = width * (0.72 + 0.28 * t)
        for c in range(cols):
            u = c / (cols - 1)
            x = (u - 0.5) * 2.0 * w
            y = back_y - math.sin(u * math.pi) * wave * (0.3 + t)
            verts.append((x, y, z))
    for r in range(rows - 1):
        for c in range(cols - 1):
            i = r * cols + c
            faces.append((i, i + 1, i + cols + 1, i + cols))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for poly in mesh.polygons:
        poly.use_smooth = True
    add_solidify(obj, 0.008)
    bind_weighted(obj, rig, lambda co: [
        ("spine_03", max(0.0, min(1.0, (co.z - (top_z - 0.6)) / 0.6))),
        ("spine_02", max(0.0, 1.0 - abs(co.z - (top_z + bottom_z) * 0.5) / 0.9)),
        ("pelvis", max(0.0, min(1.0, (top_z - co.z) / max(0.2, top_z - bottom_z)))),
    ])
    return obj


def add_solidify(obj, thickness):
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Solidify", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = 0.0


def add_long_coat(rig, name, mat):
    add_cape(rig, name + "_back", mat, 1.46, 0.55, 0.32, -0.12, rows=8, cols=9, wave=0.025)
    for side, sign in (("l", -1), ("r", 1)):
        verts = []
        faces = []
        rows, cols = 8, 3
        for r in range(rows):
            t = r / (rows - 1)
            z = 1.45 - t * 0.9
            for c in range(cols):
                u = c / (cols - 1)
                x = sign * (0.16 + u * 0.16)
                y = -0.03 + (1.0 - t) * 0.03 + (u - 0.5) * 0.04
                verts.append((x, y, z))
        for r in range(rows - 1):
            for c in range(cols - 1):
                i = r * cols + c
                faces.append((i, i + 1, i + cols + 1, i + cols))
        mesh = bpy.data.meshes.new(name + "_" + side)
        mesh.from_pydata(verts, [], faces)
        mesh.materials.append(mat)
        obj = bpy.data.objects.new(name + "_" + side, mesh)
        bpy.context.collection.objects.link(obj)
        for poly in mesh.polygons:
            poly.use_smooth = True
        bind_weighted(obj, rig, lambda co: [("spine_03", 1.0), ("pelvis", max(0.0, (1.3 - co.z))) ])


def add_glasses(rig, head_pos):
    mat = material("scholar_glasses", (0.04, 0.04, 0.045), 0.22, 0.65)
    for side, sign in (("l", -1), ("r", 1)):
        add_ring("scholar_glasses_" + side, (head_pos.x + sign * 0.035, head_pos.y - 0.105, head_pos.z + 0.035),
                 0.032, 0.005, mat, rotation=(math.radians(90), 0, 0))
        bind_rigid(bpy.context.object, rig, "head")
    add_cylinder("scholar_glasses_bridge", (head_pos.x, head_pos.y - 0.112, head_pos.z + 0.035),
                 0.006, 0.07, mat, segments=6, rotation=(0, math.radians(90), 0))
    bind_rigid(bpy.context.object, rig, "head")


def add_beard(rig, head_pos, mat):
    add_sphere("veteran_beard", (head_pos.x, head_pos.y - 0.095, head_pos.z - 0.105), (0.085, 0.06, 0.105), mat, segments=14, rings=8)
    bind_rigid(bpy.context.object, rig, "head")


def add_hero_gear(rig, meshes, head_pos):
    # Только кожаная кираса из копии поддоспешника; без плаща/наплечников/меча,
    # которые при жёстком креплении давали плавающие детали.
    add_leather_cuirass(rig, meshes, "hero_cuirass", (0.24, 0.16, 0.09), 0.23, 0.88, 1.54, 0.018)


def add_veteran_gear(rig, meshes, head_pos):
    # Тяжёлая кожаная кираса; меховая накидка и борода вынесены в P2.
    add_leather_cuirass(rig, meshes, "veteran_cuirass", (0.18, 0.12, 0.07), 0.25, 0.86, 1.54, 0.022)


def add_sunny_gear(rig, meshes, head_pos, nightmare=False):
    # Без капюшона/кандалов: это отдельные визуальные детали, которые
    # требуют точной привязки; в P1 оставляем чистый силуэт.
    return


def add_shifty_gear(rig, head_pos):
    return


def add_scholar_gear(rig, meshes, head_pos):
    add_glasses(rig, head_pos)


# ---------------------------------------------------------------------------
# build
# ---------------------------------------------------------------------------

def _find(meshes, tag):
    return next((o for o in meshes if tag in o.name), None)


def _rename_bones_to_humanoid(rig, meshes):
    """Rename MPFB game_engine bones/vertex groups to UAL humanoid names.

    The existing Sunny asset uses Godot's import retargeting for this.  Doing it
    in Blender keeps the new GLBs self-contained: one skeleton, humanoid bone
    names, imported animations work without per-file .import overrides.
    """
    bone_map_path = os.path.join(PROJECT_ROOT, "assets", "characters",
                                 "sunny_realistic_poc", "bone_map_mpfb_game_engine.tres")
    mapping = {}
    try:
        text = open(bone_map_path, "r", encoding="utf-8").read()
        for human, mpfb in re.findall(r'bone_map/([A-Za-z0-9_]+) = &"([^"]*)"', text):
            if mpfb:
                mapping[mpfb] = human
    except OSError:
        print("WARN bone map not found", bone_map_path)

    for obj in meshes:
        for group in list(obj.vertex_groups):
            if group.name in mapping and mapping[group.name] != group.name:
                group.name = mapping[group.name]

    for bone in rig.data.bones:
        if bone.name in mapping and mapping[bone.name] != bone.name:
            bone.name = mapping[bone.name]

    rig.name = "GeneralSkeleton"
    rig.data.name = "GeneralSkeleton"
    print("RENAMED_BONES", len(mapping))


def _remove_objects(meshes, tags):
    remove = [o for o in meshes if any(tag in o.name for tag in tags)]
    for obj in remove:
        bpy.data.objects.remove(obj, do_unlink=True)
    return [o for o in meshes if o not in remove]


def _make_lod(meshes, ratio, remove_tags, suffix):
    copies = []
    for source in meshes:
        if any(tag in source.name for tag in remove_tags):
            continue
        dup = source.copy()
        dup.data = source.data.copy()
        dup.name = source.name + suffix
        bpy.context.collection.objects.link(dup)
        mod = dup.modifiers.new("LOD_Decimate", "DECIMATE")
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        bpy.ops.object.select_all(action="DESELECT")
        dup.select_set(True)
        bpy.context.view_layer.objects.active = dup
        bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
        bpy.ops.object.modifier_apply(modifier=mod.name)
        copies.append(dup)
    return copies


def _adjust_surfaces(meshes):
    """Cloth should read as cloth, skin as skin; MPFB game-engine materials are too glossy."""
    for obj in meshes:
        for slot in obj.material_slots:
            mat = slot.material
            if mat is None or not mat.use_nodes:
                continue
            bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if bsdf is None:
                continue
            low = obj.name.lower()
            if "body" in low or "skin" in low:
                bsdf.inputs["Roughness"].default_value = 0.56
                if "Metallic" in bsdf.inputs:
                    bsdf.inputs["Metallic"].default_value = 0.0
            elif "hair" in low or "eyebrow" in low:
                bsdf.inputs["Roughness"].default_value = 0.62
            elif "eye" in low or "low-poly" in low:
                bsdf.inputs["Roughness"].default_value = 0.22
            else:
                bsdf.inputs["Roughness"].default_value = 0.86
                if "Metallic" in bsdf.inputs:
                    bsdf.inputs["Metallic"].default_value = 0.0


def _export(rig, meshes, out_path):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=False,
        export_morph=False,
        export_skins=True,
        export_yup=True,
    )


def build_character(key, spec, out_dir):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    preset = dict(BASE)
    preset.update({
        "name": key,
        "phenotype": spec["phenotype"],
        "skin_mhmat": spec["skin"],
        "hair": spec["hair"],
        "eyebrows": spec["eyebrows"],
        "clothes": spec["clothes"],
    })
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

    clothes = [o for o in meshes if any(c.split("/")[0] in o.name for c in spec["clothes"])]
    if spec.get("mass"):
        # Массовка: тело под одеждой вырезаем, но саму одежду не декатируем.
        # Иначе низкий полигон даёт дыры на бёдрах, а оставленное тело —
        # просветы кожи сквозь брюки.
        print("BUILD", key, "MASS_COVERED", sunny.remove_covered_body(basemesh, clothes, keep_below=sunny.KEEP_BODY_BELOW))
    else:
        print("BUILD", key, "COVERED", sunny.remove_covered_body(basemesh, clothes, keep_below=sunny.KEEP_BODY_BELOW))
        for inner, outer in spec["layers"]:
            inner_obj, outer_obj = _find(meshes, inner), _find(meshes, outer)
            if inner_obj and outer_obj:
                sunny.remove_covered_body(inner_obj, [outer_obj])
                sunny.tuck_under(inner_obj, outer_obj)
                sunny.trim_above_hem(inner_obj, outer_obj)
        for inner, outer in spec["tuck"]:
            inner_obj, outer_obj = _find(meshes, inner), _find(meshes, outer)
            if inner_obj and outer_obj:
                sunny.tuck_under(inner_obj, outer_obj)

    hair_name = spec["hair"].split("/")[0] if spec["hair"] else ""
    for obj in meshes:
        if hair_name and hair_name in obj.name:
            sat, bright, tint = spec.get("hair_tint", (1.0, 0.2, (1, 1, 1)))
            sunny.recolor(obj, sat, bright, tint)
        for cloth, (sat, bright, tint) in spec["tints"].items():
            if cloth in obj.name:
                sunny.recolor(obj, sat, bright, tint)
        if not any(tag in obj.name for tag in sunny.ALPHA_ASSETS):
            sunny.make_opaque(obj)
    if spec.get("skin_tint"):
        sat, bright, tint = spec["skin_tint"]
        sunny.recolor(basemesh, sat, bright, tint)

    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    head_pos = _bone_head(rig, "head")
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]

    gear = spec.get("gear")
    if gear in ("police_desk", "police_guard"):
        add_police_gear(rig, meshes, spec)
    elif gear == "hero":
        add_hero_gear(rig, meshes, head_pos)
    elif gear == "veteran":
        add_veteran_gear(rig, meshes, head_pos)
    elif gear == "scholar":
        add_scholar_gear(rig, meshes, head_pos)
    elif gear == "shifty":
        add_shifty_gear(rig, head_pos)
    elif gear == "sunny_real":
        add_sunny_gear(rig, meshes, head_pos, nightmare=False)
    elif gear == "sunny_nightmare":
        add_sunny_gear(rig, meshes, head_pos, nightmare=True)

    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    _adjust_surfaces(meshes)
    _rename_bones_to_humanoid(rig, meshes)

    if spec.get("mass"):
        ratio = spec.get("mass_ratio", 0.12)
        meshes = _remove_objects(meshes, spec.get("mass_remove", []))
        for obj in meshes:
            # Не декатировать одежду/обувь: даже 300–500 треугольников при
            # сильном collapse дают дыры на бёдрах и щиколотках. Упрощаем
            # только тело и волосы; одежда остаётся цельной.
            low = obj.name.lower()
            if "body" not in low and "hair" not in low:
                continue
            mod = obj.modifiers.new("Mass_Decimate", "DECIMATE")
            mod.ratio = ratio
            mod.use_collapse_triangulate = True
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
            bpy.ops.object.modifier_apply(modifier=mod.name)
        max_texture = spec.get("mass_texture", 512)
        lod_count = 1
    else:
        # LOD1/LOD2 share the same skeleton, materials and animations.
        lod1_remove = spec.get("lod2_remove", []) + ["eyebrow", "eyelashes"]
        lod1 = _make_lod(meshes, 0.52, lod1_remove, "_LOD1")
        lod2 = _make_lod(meshes, 0.24, spec.get("lod2_remove", []) + ["eyebrow", "eyelashes", "radio", "badge", "sword"],
                         "_LOD2")
        meshes = meshes + lod1 + lod2
        max_texture = MAX_TEXTURE
        lod_count = 3

    for image in bpy.data.images:
        w, h = image.size
        if max(w, h) > max_texture:
            k = max_texture / max(w, h)
            image.scale(int(w * k), int(h * k))
            image.pack()

    out_path = os.path.join(out_dir, key + ".glb")
    os.makedirs(out_dir, exist_ok=True)
    _export(rig, meshes, out_path)

    deps = bpy.context.evaluated_depsgraph_get()
    stats = []
    total = 0
    for obj in meshes:
        ev = obj.evaluated_get(deps)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        tris = len(me.loop_triangles)
        total += tris
        stats.append((obj.name, tris))
        ev.to_mesh_clear()
    zs = [(basemesh.matrix_world @ v.co).z for v in basemesh.data.vertices]
    print("BUILT", key, "TRIS", total, "LODS", lod_count, "HEIGHT", round(max(zs) - min(zs), 4), "OUT", out_path)
    for name, tris in stats:
        if "LOD0" not in name:
            print("  MESH", name, tris)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    out = os.path.abspath(args[0])
    names = args[1:] or list(SPECS.keys())
    for name in names:
        build_character(name, SPECS[name], out)
