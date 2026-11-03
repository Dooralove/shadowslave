"""Read-only GLB audit for character/enemy assets.

Parses the JSON chunk directly (no Blender/Godot needed) and reports file size,
triangles, draw-call primitives, UV/tangent/skin attributes, material flags,
textures and animation clips. Run from the project root:

  python tools/audit/character_asset_audit.py > docs/art/character_asset_audit_2026-11-02.md
"""
from __future__ import annotations

import json
import os
import struct
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSETS = os.path.join(ROOT, "assets", "characters")

FILES = [
    r"enemies\carapace\carapace_scavenger.glb",
    r"enemies\larva\larva_corpse.glb",
    r"enemies\larva\larva_corpse_lod.glb",
    r"p1\models\mountain_king_p1.glb",
    r"p1\models\mountain_king_p2.glb",
    r"p1\models\mountain_king_p3.glb",
    r"p1\models\sunny_real.glb",
    r"p1\models\sunny_nightmare.glb",
    r"p1\models\hero_auro.glb",
    r"p1\models\hero_auro_v2.glb",
    r"p1\models\veteran.glb",
    r"p1\models\veteran_v2.glb",
    r"p1\models\shifty.glb",
    r"p1\models\shifty_v2.glb",
    r"p1\models\scholar.glb",
    r"p1\models\police_desk.glb",
    r"p1\models\police_guard.glb",
    r"p1\models\mass_male.glb",
    r"p1\models\mass_female.glb",
    r"p1\models\mass_slave.glb",
    r"p1\models\mass_slave_v2.glb",
    r"p1\models\mass_soldier.glb",
    r"p1\models\mass_soldier_v2.glb",
    r"p1\models\mass_police.glb",
    r"enemy_placeholder\Barbarian.glb",
    r"sunny_placeholder\Rogue_Hooded.glb",
    r"placeholders\horse\horse.glb",
]


def read_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 12 or data[:4] != b"glTF":
        raise ValueError("not a GLB")
    _, _, total = struct.unpack_from("<III", data, 0)
    off = 12
    js = None
    bins = []
    while off + 8 <= min(total, len(data)):
        length, ctype = struct.unpack_from("<II", data, off)
        off += 8
        chunk = data[off:off + length]
        off += length
        if ctype == 0x4E4F534A:
            js = json.loads(chunk.rstrip(b"\x00 \t\r\n").decode("utf-8"))
        elif ctype == 0x004E4942:
            bins.append(chunk)
    if js is None:
        raise ValueError("no JSON chunk")
    return js, b"".join(bins), len(data)


def image_size(blob, mime):
    try:
        if mime == "image/png" or blob[:8] == b"\x89PNG\r\n\x1a\n":
            w, h = struct.unpack(">II", blob[16:24])
            return w, h
        if mime == "image/jpeg" or blob[:2] == b"\xff\xd8":
            i = 2
            while i + 9 < len(blob):
                if blob[i] != 0xFF:
                    i += 1
                    continue
                marker = blob[i + 1]
                i += 2
                if marker in (0xD8, 0xD9):
                    continue
                seglen = struct.unpack(">H", blob[i:i + 2])[0]
                if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
                              0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                    h, w = struct.unpack(">HH", blob[i + 3:i + 7])
                    return w, h
                i += seglen
    except Exception:
        pass
    return 0, 0


def accessor_count(js, idx):
    return int(js["accessors"][idx].get("count", 0))


def accessor_float_bounds(js, idx):
    a = js["accessors"][idx]
    return a.get("min"), a.get("max")


def audit(path):
    js, binblob, size = read_glb(path)
    meshes = js.get("meshes", [])
    prims = 0
    tris = 0
    verts = 0
    uv0 = uv1 = tang = col = 0
    skinned = 0
    mesh_names = []
    lod_names = set()
    for m in meshes:
        mesh_names.append(m.get("name", ""))
        for p in m.get("primitives", []):
            prims += 1
            attrs = p.get("attributes", {})
            if "POSITION" in attrs:
                verts += accessor_count(js, attrs["POSITION"])
            if "indices" in p:
                tris += accessor_count(js, p["indices"]) // 3
            elif "POSITION" in attrs:
                tris += accessor_count(js, attrs["POSITION"]) // 3
            uv0 += 1 if "TEXCOORD_0" in attrs else 0
            uv1 += 1 if "TEXCOORD_1" in attrs else 0
            tang += 1 if "TANGENT" in attrs else 0
            col += 1 if "COLOR_0" in attrs else 0
            skinned += 1 if "JOINTS_0" in attrs and "WEIGHTS_0" in attrs else 0
    mats = js.get("materials", [])
    double = sum(1 for m in mats if m.get("doubleSided"))
    alpha = sorted({m.get("alphaMode", "OPAQUE") for m in mats})
    tex_count = len(js.get("textures", []))
    img_count = len(js.get("images", []))
    images = []
    for img in js.get("images", []):
        mime = img.get("mimeType", "")
        blob = b""
        if "bufferView" in img:
            bv = js["bufferViews"][img["bufferView"]]
            start = int(bv.get("byteOffset", 0))
            blob = binblob[start:start + int(bv.get("byteLength", 0))]
        elif "uri" in img and not img["uri"].startswith("data:"):
            try:
                with open(os.path.join(os.path.dirname(path), img["uri"]), "rb") as f:
                    blob = f.read()
            except OSError:
                pass
        w, h = image_size(blob, mime)
        images.append((img.get("name", ""), mime, w, h, len(blob)))
    anims = []
    for a in js.get("animations", []):
        duration = 0.0
        for s in a.get("samplers", []):
            inp = js["accessors"][s["input"]]
            if inp.get("max"):
                duration = max(duration, float(inp["max"][0]))
        anims.append((a.get("name", ""), len(a.get("samplers", [])), round(duration, 2)))
    skins = js.get("skins", [])
    bones = len(skins[0].get("joints", [])) if skins else 0
    nodes = js.get("nodes", [])
    root_scales = []
    for n in nodes:
        if "scale" in n:
            s = n["scale"]
            if any(abs(float(v) - 1.0) > 1e-4 for v in s):
                root_scales.append((n.get("name", ""), [round(float(v), 3) for v in s]))
    # Bounding box from POSITION accessors (ignores node transforms).
    bbox = None
    for m in meshes:
        for p in m.get("primitives", []):
            attrs = p.get("attributes", {})
            if "POSITION" in attrs:
                mn, mx = accessor_float_bounds(js, attrs["POSITION"])
                if mn and mx:
                    if bbox is None:
                        bbox = [list(mn), list(mx)]
                    else:
                        for i in range(3):
                            bbox[0][i] = min(bbox[0][i], mn[i])
                            bbox[1][i] = max(bbox[1][i], mx[i])
    dims = [round(bbox[1][i] - bbox[0][i], 3) for i in range(3)] if bbox else [0, 0, 0]
    return {
        "path": os.path.relpath(path, ROOT),
        "size": size,
        "meshes": len(meshes),
        "prims": prims,
        "tris": tris,
        "verts": verts,
        "bones": bones,
        "uv0": uv0,
        "uv1": uv1,
        "tangents": tang,
        "colors": col,
        "skinned": skinned,
        "materials": len(mats),
        "double": double,
        "alpha": ",".join(alpha),
        "textures": tex_count,
        "images": images,
        "anims": anims,
        "mesh_names": mesh_names,
        "lod_names": sorted(n for n in mesh_names if "_LOD" in n.upper()),
        "dims": dims,
        "root_scales": root_scales,
    }


def main():
    rows = []
    for rel in FILES:
        p = os.path.join(ASSETS, rel)
        if not os.path.exists(p):
            print("MISSING", rel)
            continue
        try:
            rows.append(audit(p))
        except Exception as e:
            print("ERROR", rel, e, file=sys.stderr)
    print("# Character/enemy asset audit - raw GLB inventory\n")
    print("**Generated:** 2026-11-02  ")
    print("**Method:** read-only GLB JSON/accessor parse; no scene instantiation.  ")
    print("**Scope:** models created or sourced during the current character/enemy rework.\n")
    print("| Asset | MB | Tris | Verts | Meshes / prims | Bones | UV0 | UV1 | Tangents | Colors | Mats | Double-sided | Textures | Clips | Dimensions (m) |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|")
    for r in rows:
        clips = ", ".join(f"{n}:{d}s" for n, _, d in r["anims"]) or "-"
        imgs = r["images"]
        tex_desc = "-" if not imgs else ", ".join(f"{n or 'img'} {w}x{h} {mime.split('/')[-1]}" for n, mime, w, h, _ in imgs)
        print(f"| `{r['path']}` | {r['size']/1048576:.2f} | {r['tris']:,} | {r['verts']:,} | {r['meshes']} / {r['prims']} | {r['bones']} | {r['uv0']} | {r['uv1']} | {r['tangents']} | {r['colors']} | {r['materials']} | {r['double']} | {tex_desc} | {clips} | {r['dims'][0]} x {r['dims'][1]} x {r['dims'][2]} |")
    print("\n## Notes\n")
    print("- `UV0`/`UV1`/`Tangents`/`Colors` count mesh primitives that have the attribute, not vertices.")
    print("- `Double-sided` counts materials with `doubleSided=true`; high counts mean overdraw and possible flipped-normal masking.")
    print("- Dimensions are local POSITION accessor bounds, ignoring node transforms and LOD visibility.")
    print("- Texture memory: an embedded 20482 PNG can cost ~22 MB VRAM after upload; inspect the per-asset report for exact values.")


if __name__ == "__main__":
    main()
