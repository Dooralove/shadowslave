"""Read-only extended GLB audit for characters, candidates and animation libraries.

Extends character_asset_audit.py to include incoming generated candidates,
native-clip models, and animation libraries. Parses the GLB JSON chunk directly.
Run from the project root:

  python tools/audit/character_asset_audit_extended.py
"""
from __future__ import annotations

import json
import os
import struct
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FILES = [
    # Current runtime models
    r"assets\characters\p1\models\sunny_real.glb",
    r"assets\characters\p1\models\sunny_nightmare.glb",
    r"assets\characters\p1\models\hero_auro.glb",
    r"assets\characters\p1\models\veteran.glb",
    r"assets\characters\p1\models\shifty.glb",
    r"assets\characters\p1\models\scholar.glb",
    r"assets\characters\p1\models\police_desk.glb",
    r"assets\characters\p1\models\police_guard.glb",
    r"assets\characters\p1\models\mass_male.glb",
    r"assets\characters\p1\models\mass_female.glb",
    r"assets\characters\p1\models\mass_slave.glb",
    r"assets\characters\p1\models\mass_soldier.glb",
    r"assets\characters\p1\models\mass_police.glb",
    r"assets\characters\p1\models\mountain_king_p3.glb",
    r"assets\characters\enemies\carapace_generated\carapace_scavenger_generated.glb",
    r"assets\characters\enemies\larva\larva_corpse.glb",
    r"assets\characters\generated\hero_auro_v6\hero_auro_v6.glb",
    # Generated candidates (not integrated)
    r"incoming_models\P0_characters\sunny_real_v2_rigged_core10.glb",
    r"incoming_models\P0_characters\sunny_real_v2_raw.glb",
    r"incoming_models\P0_characters\sunny_nightmare_v2_raw.glb",
    r"incoming_models\P0_characters\hero_auro_v6_image_rigged.glb",
    r"incoming_models\P0_characters\mountain_king_gen_image_anim.glb",
    r"incoming_models\P1_monsters\carapace_scavenger_gen_image_anim.glb",
    # Animation libraries
    r"assets\characters\sunny_realistic_poc\animations\ual_standard.glb",
    r"assets\characters\sunny_realistic_poc\animations\sunny_idle_relaxed.glb",
    r"assets\characters\sunny_placeholder\Rogue_Hooded.glb",
    r"assets\characters\enemy_placeholder\Barbarian.glb",
    r"assets\characters\placeholders\horse\horse.glb",
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


def count(js, idx):
    return int(js["accessors"][idx].get("count", 0))


def audit(path):
    js, binblob, size = read_glb(path)
    meshes = js.get("meshes", [])
    prims = tris = verts = 0
    uv0 = uv1 = tang = col = skinned = 0
    lod_names = set()
    for m in meshes:
        name = m.get("name", "")
        if "_LOD" in name:
            lod_names.add(name.split("_LOD")[-1][:1])
        for p in m.get("primitives", []):
            prims += 1
            attrs = p.get("attributes", {})
            if "POSITION" in attrs:
                verts += count(js, attrs["POSITION"])
            if "indices" in p:
                tris += count(js, p["indices"]) // 3
            elif "POSITION" in attrs:
                tris += count(js, attrs["POSITION"]) // 3
            uv0 += 1 if "TEXCOORD_0" in attrs else 0
            uv1 += 1 if "TEXCOORD_1" in attrs else 0
            tang += 1 if "TANGENT" in attrs else 0
            col += 1 if "COLOR_0" in attrs else 0
            skinned += 1 if "JOINTS_0" in attrs and "WEIGHTS_0" in attrs else 0
    mats = js.get("materials", [])
    double = sum(1 for m in mats if m.get("doubleSided"))
    alpha = sorted({m.get("alphaMode", "OPAQUE") for m in mats})
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
        images.append((img.get("name", ""), w, h, len(blob)))
    anims = []
    for a in js.get("animations", []):
        duration = 0.0
        for s in a.get("samplers", []):
            inp = js["accessors"][s["input"]]
            if inp.get("max"):
                duration = max(duration, float(inp["max"][0]))
        anims.append((a.get("name", ""), len(a.get("channels", [])), round(duration, 2)))
    skins = js.get("skins", [])
    bones = len(skins[0].get("joints", [])) if skins else 0
    bbox = None
    for m in meshes:
        for p in m.get("primitives", []):
            attrs = p.get("attributes", {})
            if "POSITION" in attrs:
                a = js["accessors"][attrs["POSITION"]]
                mn, mx = a.get("min"), a.get("max")
                if mn and mx:
                    if bbox is None:
                        bbox = [list(mn), list(mx)]
                    else:
                        for i in range(3):
                            bbox[0][i] = min(bbox[0][i], mn[i])
                            bbox[1][i] = max(bbox[1][i], mx[i])
    dims = [round(bbox[1][i] - bbox[0][i], 3) for i in range(3)] if bbox else [0, 0, 0]
    node_scales = []
    for n in js.get("nodes", []):
        if "scale" in n and any(abs(float(v) - 1.0) > 1e-4 for v in n["scale"]):
            node_scales.append((n.get("name", ""), [round(float(v), 3) for v in n["scale"]]))
    return {
        "path": os.path.relpath(path, ROOT).replace("\\", "/"),
        "mb": round(size / 1e6, 2),
        "tris": tris,
        "verts": verts,
        "meshes": len(meshes),
        "prims": prims,
        "bones": bones,
        "uv0": uv0,
        "tangents": tang,
        "skinned": skinned,
        "materials": len(mats),
        "double": double,
        "alpha": alpha,
        "images": images,
        "anims": anims,
        "dims": dims,
        "lod": sorted(lod_names),
        "node_scales": node_scales,
    }


def main():
    rows = []
    for rel in FILES:
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            print("MISSING", rel, file=sys.stderr)
            continue
        rows.append(audit(path))
    print("| Asset | MB | Tris | Verts | Meshes/prims | Bones | UV0 | Tangents | Mats | Double | Textures | Clips | Dims (m) | LOD |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|")
    for r in rows:
        tex = "; ".join(f"{n or 'tex'} {w}x{h}" for n, w, h, _ in r["images"]) or "-"
        clips = ", ".join(f"{n}:{d}s" for n, c, d in r["anims"]) or "-"
        print(f"| `{r['path']}` | {r['mb']} | {r['tris']} | {r['verts']} | {r['meshes']}/{r['prims']} | "
              f"{r['bones']} | {r['uv0']} | {r['tangents']} | {r['materials']} | {r['double']} | {tex} | {clips} | "
              f"{' x '.join(str(v) for v in r['dims'])} | {','.join(r['lod']) or '-'} |")
    print()
    for r in rows:
        print(f"### {r['path']}")
        print(f"- alpha modes: {r['alpha']}")
        print(f"- node scales: {r['node_scales']}")
        if r["anims"]:
            print(f"- clip channels: {[(n, c) for n, c, d in r['anims']]}")


if __name__ == "__main__":
    main()
