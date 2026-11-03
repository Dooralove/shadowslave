"""Read-only audit of the generated armour GLBs.

Checks skin joint count, weights, zero-weight vertices, influence counts,
tangents/UVs, material sidedness, texture sizes and mesh bounds.

Run:
  python tools/audit/armor_glb_audit.py assets/characters/equipment/armor/*.glb
"""
from __future__ import annotations

import json
import os
import struct
import sys
from collections import Counter


def read_glb(path: str) -> tuple[dict, bytes]:
    with open(path, "rb") as handle:
        data = handle.read()
    magic, version, length = struct.unpack("<III", data[:12])
    if magic != 0x46546C67:
        raise ValueError("not a GLB")
    offset = 12
    json_chunk = b""
    bin_chunk = b""
    while offset < len(data):
        chunk_len, chunk_type = struct.unpack("<II", data[offset:offset + 8])
        payload = data[offset + 8:offset + 8 + chunk_len]
        if chunk_type == 0x4E4F534A:
            json_chunk = payload
        elif chunk_type == 0x004E4942:
            bin_chunk = payload
        offset += 8 + chunk_len
    return json.loads(json_chunk.decode("utf-8")), bin_chunk


COMPONENT_FORMAT = {
    5120: ("b", 1),
    5121: ("B", 1),
    5122: ("h", 2),
    5123: ("H", 2),
    5125: ("I", 4),
    5126: ("f", 4),
}
TYPE_COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read_accessor(gltf: dict, bin_chunk: bytes, index: int) -> list[tuple]:
    accessor = gltf["accessors"][index]
    view = gltf["bufferViews"][accessor["bufferView"]]
    fmt, size = COMPONENT_FORMAT[accessor["componentType"]]
    components = TYPE_COUNT[accessor["type"]]
    count = accessor["count"]
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    stride = view.get("byteStride", size * components)
    out = []
    for i in range(count):
        base = start + i * stride
        values = struct.unpack_from("<" + fmt * components, bin_chunk, base)
        if accessor.get("normalized"):
            denom = 255.0 if fmt == "B" else 65535.0
            values = tuple(v / denom for v in values)
        out.append(values)
    return out


def audit(path: str) -> None:
    gltf, bin_chunk = read_glb(path)
    print("==", os.path.basename(path))
    print("  nodes", len(gltf.get("nodes", [])), "meshes", len(gltf.get("meshes", [])),
          "skins", len(gltf.get("skins", [])), "animations", len(gltf.get("animations", [])))
    skin = gltf.get("skins", [{}])[0]
    joints = skin.get("joints", [])
    joint_names = [gltf["nodes"][j].get("name", "?") for j in joints]
    print("  joints", len(joints))
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            attrs = prim.get("attributes", {})
            pos = read_accessor(gltf, bin_chunk, attrs["POSITION"])
            mn = [min(v[i] for v in pos) for i in range(3)]
            mx = [max(v[i] for v in pos) for i in range(3)]
            print("  mesh", mesh.get("name"), "verts", len(pos),
                  "dims", [round(mx[i] - mn[i], 4) for i in range(3)])
            print("  attributes", sorted(attrs.keys()))
            if "JOINTS_0" not in attrs or "WEIGHTS_0" not in attrs:
                print("  NO SKIN WEIGHTS")
                continue
            joints0 = read_accessor(gltf, bin_chunk, attrs["JOINTS_0"])
            weights0 = read_accessor(gltf, bin_chunk, attrs["WEIGHTS_0"])
            zero = 0
            over4 = 0
            sums = []
            influences = Counter()
            bone_vertices = Counter()
            for js, ws in zip(joints0, weights0):
                total = sum(ws)
                sums.append(total)
                if total <= 1e-6:
                    zero += 1
                count = sum(1 for w in ws if w > 1e-6)
                influences[count] += 1
                if count > 4:
                    over4 += 1
                for j, w in zip(js, ws):
                    if w > 0.01 and 0 <= j < len(joint_names):
                        bone_vertices[joint_names[j]] += 1
            print("  weight_sum min/max/mean", round(min(sums), 5), round(max(sums), 5),
                  round(sum(sums) / len(sums), 5))
            print("  zero_weight_vertices", zero, "over_4_influences", over4)
            print("  influence_histogram", dict(sorted(influences.items())))
            print("  bones_with_weights", len(bone_vertices), "of", len(joints))
            print("  top_bones", bone_vertices.most_common(8))
    for material in gltf.get("materials", []):
        print("  material", material.get("name"), "doubleSided", material.get("doubleSided", False),
              "alphaMode", material.get("alphaMode", "OPAQUE"))
    for image in gltf.get("images", []):
        print("  image", image.get("name"), image.get("mimeType"))
    for texture in gltf.get("textures", []):
        source = texture.get("source")
        if source is not None:
            image = gltf["images"][source]
            view = gltf["bufferViews"][image["bufferView"]]
            print("  texture bytes", image.get("name"), view.get("byteLength"))


if __name__ == "__main__":
    for path in sys.argv[1:]:
        audit(path)
