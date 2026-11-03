"""?????? ??????? ?? Stone Knight (Sketchfab, CC BY, mzee92) + ?????.

????????: assets/environments/nightmare/source/stone_knight_source.glb
????????: CC BY 4.0, ????? mzee92; ??. LICENSE_STONE_KNIGHT.txt.

?????? ??????????: ????? ??????? ????????-???, ???? ???? ?? -Z (Blender).
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

SRC = Path(__file__).resolve().parent
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

import nm_lib as L
import nm_props as P
import build_statue_colossus_v2 as V2

OUT = L.NM_DIR / "statue"
SRC_GLB = L.SOURCE_DIR / "stone_knight_source.glb"
PREV = L.ROOT / "docs" / "art" / "previews" / "forgotten_shore"


def load_source():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SRC_GLB))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("Stone Knight source has no meshes")
    # ???????? ??????? ??????? ? ??????? ?????????, ????? ?????????? ???? ????????.
    for o in meshes:
        o.data.transform(o.matrix_world)
        o.matrix_world = Matrix.Identity(4)
        o.parent = None
        o.data.update()
    return meshes


def transform_meshes(meshes, M):
    for o in meshes:
        o.data.transform(M)
        o.data.update()


def find_torso(meshes):
    for o in meshes:
        for m in o.data.materials:
            if m and m.name in ("torso", "defaultMaterial.002"):
                return o
    return max(meshes, key=lambda o: len(o.data.vertices))


def top_center(meshes):
    zmax = max(max((o.matrix_world @ v.co).z for v in o.data.vertices) for o in meshes)
    pts = []
    for o in meshes:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            if w.z > zmax - 2.5:
                pts.append(w)
    return (sum(p.x for p in pts) / len(pts), sum(p.y for p in pts) / len(pts), zmax)


def add_stars(coll, torso):
    # ???? ?????: ??????????? ? ????? ??????; ?????? ? ?????? ???????? ?????,
    # ????????? ?????? ? ??????? ???????.
    def surface_y(x, z):
        hit, loc, normal, idx = torso.ray_cast(Vector((x, 200.0, z)), Vector((0, -1, 0)), distance=500.0)
        if hit:
            return loc.y
        return 24.0

    def make_star(name, x, z, boss_r, star_r):
        y = surface_y(x, z)
        bm = P.cylinder(boss_r, 1.3, segs=32, axis="Y")
        bm.transform(V2.T(x, y + 0.10, z))
        V2.add_obj(coll, name + "Boss", bm, "nm_statue_crack", 30.0)
        ring = [Vector((x + math.cos(V2.TAU * i / 48) * (boss_r + 0.25),
                        y + 0.78, z + math.sin(V2.TAU * i / 48) * (boss_r + 0.25)))
                for i in range(48)]
        V2.add_obj(coll, name + "Ring", P.tube(ring, 0.18, segs=6, closed=True),
                   "nm_statue_bronze", 30.0)
        V2.star(coll, name, star_r, star_r * 0.42, 0.55, (x, y + 1.0, z), "nm_statue_star")
        for i in range(6):
            a = V2.TAU * i / 6
            V2.sphere(coll, f"{name}Stud{i}", (0.10, 0.08, 0.10),
                      (x + math.cos(a) * (boss_r + 0.3), y + 0.78,
                       z + math.sin(a) * (boss_r + 0.3)), "nm_statue_pale", 8, 5, 0.0, i)

    make_star("StarCenter", 0.0, -17.0, 3.1, 2.55)
    # ???????????? ?? ????? ??????, ?? ?????? ???? ????????? ? ???????,
    # ????? ?? ????????? ?? ???????? ????.
    for i, (sx, sz) in enumerate(((-8.0, -13.0), (8.0, -13.0),
                                   (-9.0, -23.0), (9.0, -23.0),
                                   (-9.5, -32.0), (9.5, -32.0))):
        make_star(f"Star{i}", sx, sz, 2.0, 1.65)


def build():
    meshes = load_source()
    # ??????????: ? ????????? ????? -X; ??????? -90? ???? ????? +Y (Blender).
    R = Matrix.Rotation(math.radians(-90), 4, "Z")
    transform_meshes(meshes, R)
    cx, cy, zmax = top_center(meshes)
    transform_meshes(meshes, Matrix.Translation((-cx, -cy, -zmax)))
    torso = find_torso(meshes)

    L.register_materials(V2.SM.MATERIALS, V2.SM.TEXSETS)
    for name, spec in V2.SM.MATERIALS.items():
        V2.preview_material(name, spec, V2.SM.TEXSETS)
    def plain_mat(name, color, rough=0.87, metallic=0.0):
        m = bpy.data.materials.get(name)
        if m:
            return m
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        nt.nodes.clear()
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metallic
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        return m
    def stone_texture_mat():
        m = bpy.data.materials.get("stone_textured")
        if m:
            return m
        m = bpy.data.materials.new("stone_textured")
        m.use_nodes = True
        nt = m.node_tree
        nt.nodes.clear()
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        uv = nt.nodes.new("ShaderNodeUVMap")
        alb = nt.nodes.new("ShaderNodeTexImage")
        alb.image = bpy.data.images.load(str(L.TEX_DIR / "low_tide_rocks_diff_2k.jpg"), check_existing=True)
        nor = nt.nodes.new("ShaderNodeTexImage")
        nor.image = bpy.data.images.load(str(L.TEX_DIR / "low_tide_rocks_nor_gl_2k.jpg"), check_existing=True)
        nor.image.colorspace_settings.name = "Non-Color"
        arm = nt.nodes.new("ShaderNodeTexImage")
        arm.image = bpy.data.images.load(str(L.TEX_DIR / "low_tide_rocks_arm_2k.jpg"), check_existing=True)
        arm.image.colorspace_settings.name = "Non-Color"
        for t in (alb, nor, arm):
            nt.links.new(uv.outputs["UV"], t.inputs["Vector"])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        nt.links.new(alb.outputs["Color"], mix.inputs["A"])
        mix.inputs["B"].default_value = (0.34, 0.32, 0.28, 1.0)
        nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nmap.inputs["Strength"].default_value = 1.1
        nt.links.new(nor.outputs["Color"], nmap.inputs["Color"])
        nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(arm.outputs["Color"], sep.inputs["Color"])
        nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
        bsdf.inputs["Metallic"].default_value = 0.0
        return m
    stone_tex = stone_texture_mat()
    stone_plain = plain_mat("stone_plain", (0.18, 0.16, 0.13))
    stone_light = plain_mat("stone_light", (0.38, 0.35, 0.30))

    coll = L.asset_collection("statue_knight_colossus")
    for o in meshes:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        coll.objects.link(o)
    # ???????? ? ???????.
    V2.build_platform(coll)
    # ??????? ??????? ?????????? ????????: ???????? ?????? ???? ??????, ?? ?????????.
    for o in list(coll.objects):
        if o.name.startswith(("RimTooth", "PlatformInlay")):
            bpy.data.objects.remove(o, do_unlink=True)
    # ????????? ??????? ?????? ????????.
    # ???????? ???????? ? ?????? ?????????.
    for o in list(coll.objects):
        if o.name.startswith(("NeckPlatform", "Fracture", "Debris", "Fallen", "NeckCollarFill", "NeckColla", "NeckPlug")):
            L.uv_box(o, 2.5)
            o.data.materials.clear()
            o.data.materials.append(stone_tex)
        if o.name.startswith(("CollarRim", "PlatformInlayRim")):
            o.data.materials.clear()
            o.data.materials.append(stone_light)
    # ????????? ????? ????? ????????? ??????? ???????-?????? ?????? 12-? ????????.
    src_mat = bpy.data.materials.get("platform")
    if src_mat:
        bm = bmesh.new()
        segs = 96
        inner, outer = 5.35, 12.0
        top = -0.45
        bot = -1.8
        for i in range(segs):
            a = 2.0 * math.pi * i / segs
            wob = 1.0 + 0.018 * math.sin(7 * a) + 0.01 * math.sin(13 * a)
            bm.verts.new((math.cos(a) * inner, math.sin(a) * inner, top))
            bm.verts.new((math.cos(a) * outer * wob, math.sin(a) * outer * wob, top))
            bm.verts.new((math.cos(a) * outer * wob, math.sin(a) * outer * wob, bot))
            bm.verts.new((math.cos(a) * inner, math.sin(a) * inner, bot))
        for i in range(segs):
            j = (i + 1) % segs
            vs = list(bm.verts)
            bm.faces.new((vs[i * 4], vs[i * 4 + 1], vs[j * 4 + 1], vs[j * 4]))
            bm.faces.new((vs[i * 4 + 3], vs[j * 4 + 3], vs[j * 4 + 2], vs[i * 4 + 2]))
            bm.faces.new((vs[i * 4], vs[j * 4], vs[j * 4 + 3], vs[i * 4 + 3]))
            bm.faces.new((vs[i * 4 + 1], vs[i * 4 + 2], vs[j * 4 + 2], vs[j * 4 + 1]))
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        fill = V2.add_obj(coll, "NeckCollarFill", bm, "stone_plain", 34.0)
        # ??????? ??????.
        for rr, rad in ((5.55, 0.11), (11.85, 0.12)):
            path = [Vector((math.cos(2 * math.pi * i / 96) * rr,
                            math.sin(2 * math.pi * i / 96) * rr, top + 0.03))
                    for i in range(96)]
            V2.add_obj(coll, f"CollarRim{int(rr*10)}", P.tube(path, rad, segs=5, closed=True),
                       "stone_light", 26.0)

    # ????????? ???????? ??????-??? ??? ?????????, ????? ???? ?? ???????? ??????? ???????.
    if src_mat:
        bm = P.cylinder(8.2, 5.5, segs=64, axis="Z", cap=False)
        bm.transform(V2.T(0, 0, -2.75))
        col = V2.add_obj(coll, "NeckCollar", bm, "stone_plain", 34.0)
        rim = [Vector((math.cos(2 * math.pi * i / 96) * 8.02,
                       math.sin(2 * math.pi * i / 96) * 8.02, -0.42))
               for i in range(96)]
        V2.add_obj(coll, "NeckCollarRim", P.tube(rim, 0.12, segs=5, closed=True),
                   "stone_light", 26.0)
    # ????????? ???????? ?????? ???: ???????? ???????? ??????, ? ?? ??????? ??? ????????.
    if src_mat:
        bm = P.cylinder(5.8, 14.0, segs=64, axis="Z")
        bm.transform(V2.T(0, 0, -7.0))
        plug = V2.add_obj(coll, "NeckPlug", bm, "stone_plain", 34.0)
    for o in list(coll.objects):
        if o.name.startswith(("NeckCollarFill", "NeckCollar", "NeckPlug")):
            L.uv_box(o, 2.5)
            o.data.materials.clear()
            o.data.materials.append(stone_tex)
    add_stars(coll, torso)
    # ??? ? ???? ?????????.
    for i, o in enumerate(meshes):
        o.name = f"StoneKnightPart{i}"
    # ???? ??? ? ??????????? ??????? ?????????? ? ?????? draw calls.
    bpy.ops.object.select_all(action="DESELECT")
    for o in coll.objects:
        if o.type == "MESH":
            o.select_set(True)
    if bpy.context.selected_objects:
        bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
        bpy.ops.object.join()
        joined = bpy.context.view_layer.objects.active
        joined.name = "statue_knight_colossus"
        # Source GLB has custom split normals; clearing them lets L.shade build
        # shared smooth normals instead of splitting every triangle on export.
        try:
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
        except Exception:
            pass
        L.shade(joined, 38.0)
    # ???????: ??? ??????? ?????????, ?????? ??? ? (0,0,0), ???? ???????? = 0.
    joined.select_set(True)
    bpy.context.view_layer.objects.active = joined
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / "statue_knight_colossus.glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_image_format="AUTO",
    )
    bpy.ops.wm.save_as_mainfile(filepath=str(L.SOURCE_DIR / "statue_colossus.blend"))
    return coll


if __name__ == "__main__":
    coll = build()
    obj = bpy.data.objects.get("statue_knight_colossus")
    if obj is not None:
        if bpy.context.scene.world is None:
            w = bpy.data.worlds.new("StatueWorld")
            w.use_nodes = True
            bpy.context.scene.world = w
        V2.render_previews(obj)
    print("DONE stone-knight colossus", obj.name if obj else None)
