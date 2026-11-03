#!/usr/bin/env python3
"""Static placeholder audit for Godot 4 .tscn scenes.

The audit resolves PackedScene instances (the art scenes instance the greybox
scene and override/hide individual nodes), applies node property overrides,
and reports visible CSG / primitive-mesh placeholders with world transforms and
world-space AABB dimensions.

Read-only: it never edits scenes or assets.

Run:
    python tools/audit/placeholder_audit.py
    python tools/audit/placeholder_audit.py --json
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

HEADER_RE = re.compile(r'^\[(ext_resource|sub_resource|node|gd_scene)\b(.*)\]$')
PROP_RE = re.compile(r'^([A-Za-z_][A-Za-z0-9_/]*)\s*=\s*(.*)$')
ATTR_RE = re.compile(r'([A-Za-z_][A-Za-z0-9_]*)=("([^"]*)"|([^\s\]]+))')

PRIMITIVE_TYPES = {
    "BoxMesh": "box",
    "CylinderMesh": "cylinder",
    "SphereMesh": "sphere",
    "PlaneMesh": "plane",
    "QuadMesh": "quad",
    "PrismMesh": "prism",
    "TorusMesh": "torus",
    "CapsuleMesh": "capsule",
    "CylinderShape3D": "cylinder",
    "BoxShape3D": "box",
    "SphereShape3D": "sphere",
    "CapsuleShape3D": "capsule",
}

CSG_TYPES = {
    "CSGBox3D": "box",
    "CSGCylinder3D": "cylinder",
    "CSGSphere3D": "sphere",
    "CSGTorus3D": "torus",
    "CSGPolygon3D": "polygon",
    "CSGMesh3D": "mesh",
    "CSGCombiner3D": "combiner",
}

# Scenes that are actually loaded as final location art. The campaign wrappers
# instance these; the greybox scenes underneath them are intentionally ignored
# except where an art scene fails to hide/override a visible node.
FINAL_SCENES = [
    "scenes/slice/locations/park/park_street_art.tscn",
    "scenes/slice/locations/station_lobby_art.tscn",
    "scenes/slice/locations/containment_room_art.tscn",
    "scenes/slice/locations/mountain_vision_art.tscn",
    "scenes/slice/locations/caravan_road_art.tscn",
    "scenes/locations/caravan_site/caravan_site_art.tscn",
    "scenes/locations/pilgrim_path/pilgrim_path_art.tscn",
    "scenes/locations/shadow_sanctuary/shadow_sanctuary_art.tscn",
    "scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn",
]


@dataclass
class SceneData:
    path: Path
    ext_resources: dict[str, str] = field(default_factory=dict)
    sub_resources: dict[str, dict] = field(default_factory=dict)
    nodes: list[dict] = field(default_factory=list)


@dataclass
class Node:
    name: str
    type: str
    props: dict[str, str]
    children: list["Node"] = field(default_factory=list)
    source: str = ""
    instance: str = ""


def parse_attrs(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for m in ATTR_RE.finditer(text):
        out[m.group(1)] = m.group(3) if m.group(3) is not None else m.group(4)
    return out


def parse_scene(path: Path) -> SceneData:
    data = SceneData(path)
    current: dict | None = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith(";"):
            continue
        m = HEADER_RE.match(line)
        if m:
            kind, rest = m.group(1), m.group(2).strip()
            attrs = parse_attrs(rest)
            if kind == "ext_resource":
                data.ext_resources[attrs.get("id", "")] = attrs.get("path", "")
                current = None
            elif kind == "sub_resource":
                current = {"__kind": "sub", "type": attrs.get("type", ""), "props": {}}
                data.sub_resources[attrs.get("id", "")] = current
            elif kind == "node":
                parent = attrs.get("parent", None)
                if parent == ".":
                    parent = ""
                current = {
                    "__kind": "node",
                    "name": attrs.get("name", ""),
                    "type": attrs.get("type", ""),
                    "parent": parent,
                    "instance": attrs.get("instance", ""),
                    "props": {},
                }
                data.nodes.append(current)
            else:
                current = None
            continue
        if current is not None:
            pm = PROP_RE.match(line)
            if pm:
                current["props"][pm.group(1)] = pm.group(2)
    return data


def subtree(nodes: list[dict], parent_path: str) -> list[dict]:
    prefix = parent_path + "/" if parent_path else ""
    out = []
    for n in nodes:
        p = n["parent"]
        if p == parent_path or (parent_path and p.startswith(prefix)):
            out.append(n)
    return out


def ext_id(value: str) -> str:
    m = re.search(r'ExtResource\("([^"]+)"\)', value or "")
    return m.group(1) if m else ""


def res_path(value: str) -> Path:
    if value.startswith("res://"):
        return ROOT / value[len("res://"):]
    return ROOT / value


def find_child(root: Node, path: str) -> Node | None:
    if not path:
        return root
    cur = root
    for part in path.split("/"):
        nxt = next((c for c in cur.children if c.name == part), None)
        if nxt is None:
            return None
        cur = nxt
    return cur


def build_tree(path: Path, load_scene=parse_scene, seen: frozenset[Path] = frozenset()) -> Node:
    path = path.resolve()
    if path in seen:
        return Node(path.stem, "Node3D", {}, source=str(path))
    data = load_scene(path)
    root = Node(path.stem, "Node3D", {}, source=str(path))
    root_done = False
    # First pass: create declared nodes.
    for n in data.nodes:
        parent_path = n["parent"]
        if parent_path is None:
            if not root_done:
                root_done = True
                root.name = n["name"]
                root.type = n["type"] or "Node3D"
                root.props = dict(n["props"])
                root.instance = n["instance"]
                if n["instance"]:
                    base_path = data.ext_resources.get(ext_id(n["instance"]))
                    if base_path and base_path.endswith(".tscn"):
                        base = build_tree(res_path(base_path), load_scene, seen | {path})
                        root.type = base.type
                        root.children = base.children
                        root.source = base.source
            continue
        parent = find_child(root, parent_path)
        if parent is None:
            continue
        node = Node(n["name"], n["type"] or "", dict(n["props"]), source=str(path), instance=n["instance"])
        if n["instance"]:
            base_path = data.ext_resources.get(ext_id(n["instance"]))
            if base_path and base_path.endswith(".tscn") and res_path(base_path).exists():
                base = build_tree(res_path(base_path), load_scene, seen | {path})
                node.type = base.type
                node.children = base.children
                node.source = base.source
        parent.children.append(node)

    # Second pass: overrides that target nodes inside instanced subtrees.
    for n in data.nodes:
        if n["parent"] is None:
            continue
        target = find_child(root, (n["parent"] + "/" + n["name"]) if n["parent"] else n["name"])
        if target is not None and not n["type"]:
            target.props.update(n["props"])
        elif target is None and n["type"]:
            parent = find_child(root, n["parent"])
            if parent is not None:
                parent.children.append(Node(n["name"], n["type"], dict(n["props"]), source=str(path)))
    return root


def parse_transform3d(text: str) -> list[float]:
    inner = text[text.find("(") + 1 : text.rfind(")")]
    vals = [float(v) for v in inner.split(",")]
    if len(vals) != 12:
        raise ValueError(f"bad Transform3D: {text}")
    return vals


def mat_mul(a: list[float], b: list[float]) -> list[float]:
    """Multiply two 4x4 row-major matrices."""
    out = [0.0] * 16
    for r in range(4):
        for c in range(4):
            out[r * 4 + c] = sum(a[r * 4 + k] * b[k * 4 + c] for k in range(4))
    return out


def node_matrix(node: Node) -> list[float]:
    t = node.props.get("transform")
    if t:
        v = parse_transform3d(t)
        # Godot serializes basis columns then origin.
        return [
            v[0], v[3], v[6], v[9],
            v[1], v[4], v[7], v[10],
            v[2], v[5], v[8], v[11],
            0, 0, 0, 1,
        ]
    pos = parse_vec3(node.props.get("position", "Vector3(0, 0, 0)"))
    rot = parse_vec3(node.props.get("rotation", "Vector3(0, 0, 0)"))
    rot_deg = parse_vec3(node.props.get("rotation_degrees", "Vector3(0, 0, 0)"))
    scale = parse_vec3(node.props.get("scale", "Vector3(1, 1, 1)"))
    rx = math.radians(rot.x + rot_deg.x)
    ry = math.radians(rot.y + rot_deg.y)
    rz = math.radians(rot.z + rot_deg.z)
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    # Godot default Euler order YXZ.
    m = [
        cy * cz + sy * sx * sz, -cy * sz + sy * sx * cz, sy * cx,
        cx * sz, cx * cz, -sx,
        -sy * cz + cy * sx * sz, sy * sz + cy * sx * cz, cy * cx,
    ]
    return [
        m[0] * scale.x, m[1] * scale.x, m[2] * scale.x, pos.x,
        m[3] * scale.y, m[4] * scale.y, m[5] * scale.y, pos.y,
        m[6] * scale.z, m[7] * scale.z, m[8] * scale.z, pos.z,
        0, 0, 0, 1,
    ]


def parse_vec3(text: str) -> "Vec3":
    inner = text[text.find("(") + 1 : text.rfind(")")]
    if "Vector3" in text or text.count(",") == 2:
        vals = [float(v) for v in inner.split(",")] if inner.strip() else [0, 0, 0]
    else:
        vals = [float(v) for v in inner.split(",")]
    if len(vals) == 2:
        return Vec3(vals[0], vals[1], 0.0)
    return Vec3(vals[0], vals[1], vals[2])


@dataclass
class Vec3:
    x: float = 0.0
    y: float = 0.0
    z: float = 0.0

    def __add__(self, o: "Vec3") -> "Vec3":
        return Vec3(self.x + o.x, self.y + o.y, self.z + o.z)


def primitive_size(data: SceneData, node: Node) -> tuple[Vec3, str, Vec3] | None:
    """Return (size, primitive kind, local center offset) for a placeholder."""
    if node.type in CSG_TYPES:
        kind = CSG_TYPES[node.type]
        p = node.props
        if kind == "box":
            return parse_vec3(p.get("size", "Vector3(2, 2, 2)")), kind, Vec3()
        if kind == "cylinder":
            r = float(p.get("radius", "0.5"))
            h = float(p.get("height", "2"))
            return Vec3(r * 2, h, r * 2), kind, Vec3()
        if kind == "sphere":
            r = float(p.get("radius", "0.5"))
            return Vec3(r * 2, r * 2, r * 2), kind, Vec3()
        if kind == "torus":
            ro = float(p.get("outer_radius", "1"))
            ri = float(p.get("inner_radius", "0.5"))
            outer = ro
            return Vec3(outer * 2, (ro - ri) * 2, outer * 2), kind, Vec3()
        if kind == "mesh" and "mesh" in p:
            mid = p["mesh"]
            mid_num = re.search(r"SubResource\(\"([^\"]+)\"\)", mid)
            if mid_num:
                sub = data.sub_resources.get(mid_num.group(1), {})
                return sub_size(sub), "mesh:" + sub.get("type", ""), Vec3()
        return None

    if node.type == "MeshInstance3D" and "mesh" in node.props:
        mid = node.props["mesh"]
        m = re.search(r"SubResource\(\"([^\"]+)\"\)", mid)
        if m:
            sub = data.sub_resources.get(m.group(1), {})
            prim = PRIMITIVE_TYPES.get(sub.get("type", ""))
            if prim:
                return sub_size(sub), prim, Vec3()
    return None


def sub_size(sub: dict) -> Vec3:
    t = sub.get("type", "")
    p = sub.get("props", {})
    if t in ("BoxMesh", "BoxShape3D"):
        return parse_vec3(p.get("size", "Vector3(1, 1, 1)"))
    if t in ("CylinderMesh", "CylinderShape3D"):
        r = float(p.get("radius", "0.5"))
        h = float(p.get("height", "2"))
        top = float(p.get("top_radius", p.get("radius", "0.5")))
        bot = float(p.get("bottom_radius", p.get("radius", "0.5")))
        rr = max(r, top, bot)
        return Vec3(rr * 2, h, rr * 2)
    if t in ("SphereMesh", "SphereShape3D"):
        r = float(p.get("radius", "0.5"))
        h = float(p.get("height", str(r * 2)))
        return Vec3(r * 2, h, r * 2)
    if t in ("PlaneMesh", "QuadMesh"):
        s = parse_vec3(p.get("size", "Vector2(1, 1)"))
        return Vec3(s.x, 0.0, s.y)
    if t == "PrismMesh":
        s = parse_vec3(p.get("size", "Vector3(1, 1, 1)"))
        return s
    if t == "TorusMesh":
        ro = float(p.get("outer_radius", "1"))
        ri = float(p.get("inner_radius", "0.5"))
        return Vec3(ro * 2, (ro - ri) * 2, ro * 2)
    if t in ("CapsuleMesh", "CapsuleShape3D"):
        r = float(p.get("radius", "0.5"))
        h = float(p.get("height", "2"))
        return Vec3(r * 2, h, r * 2)
    return Vec3()


def transform_aabb(mat: list[float], size: Vec3, center: Vec3 = Vec3()) -> tuple[Vec3, Vec3]:
    hx, hy, hz = size.x * 0.5, size.y * 0.5, size.z * 0.5
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                x = center.x + sx * hx
                y = center.y + sy * hy
                z = center.z + sz * hz
                pts.append(Vec3(
                    mat[0] * x + mat[1] * y + mat[2] * z + mat[3],
                    mat[4] * x + mat[5] * y + mat[6] * z + mat[7],
                    mat[8] * x + mat[9] * y + mat[10] * z + mat[11],
                ))
    lo = Vec3(min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))
    hi = Vec3(max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))
    return lo, Vec3(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)


def basis_rotation(mat: list[float]) -> tuple[float, float, float]:
    # Extract YXZ Euler degrees from the world matrix (Godot convention).
    sy = -mat[8]
    sy = max(-1.0, min(1.0, sy))
    ry = math.asin(sy)
    if abs(math.cos(ry)) > 1e-5:
        rx = math.atan2(mat[9], mat[10])
        rz = math.atan2(mat[4], mat[0])
    else:
        rx = 0.0
        rz = math.atan2(-mat[1], mat[5])
    return math.degrees(rx), math.degrees(ry), math.degrees(rz)


def walk(node: Node, parent_mat: list[float], parent_visible: bool, data: SceneData,
         scene_path: str, out: list[dict], path: str = "") -> None:
    mat = mat_mul(parent_mat, node_matrix(node))
    visible = parent_visible and node.props.get("visible", "true").strip().lower() != "false"
    my_path = f"{path}/{node.name}" if path else node.name
    prim = primitive_size(data, node) if visible else None
    if prim is not None:
        size, kind, center = prim
        # 0.001 boxes are retired art-overlay proxies; sub-5 cm boxes are
        # decals/tracks, not 3D placeholders.
        if max(size.x, size.y, size.z) >= 0.05:
            lo, dims = transform_aabb(mat, size, center)
            rx, ry, rz = basis_rotation(mat)
            structural = (
                "Geometry/" in my_path
                or node.name.lower().startswith(("wall", "floor", "ceiling", "corridor", "roof"))
            )
            out.append({
                "scene": scene_path,
                "node_path": my_path,
                "name": node.name,
                "type": node.type,
                "source": node.source,
                "kind": kind,
                "category": "structural" if structural else "prop",
                "visible": visible,
                "local_size": [round(size.x, 3), round(size.y, 3), round(size.z, 3)],
                "world_position": [round(mat[3], 3), round(mat[7], 3), round(mat[11], 3)],
                "world_rotation_deg": [round(rx, 1), round(ry, 1), round(rz, 1)],
                "world_aabb_center": [
                    round(lo.x + dims.x / 2, 3),
                    round(lo.y + dims.y / 2, 3),
                    round(lo.z + dims.z / 2, 3),
                ],
                "world_aabb_size": [round(dims.x, 3), round(dims.y, 3), round(dims.z, 3)],
            })
    for child in node.children:
        walk(child, mat, visible, data, scene_path, out, my_path)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    records: list[dict] = []
    for rel in FINAL_SCENES:
        path = ROOT / rel
        if not path.exists():
            continue
        data = parse_scene(path)
        root = build_tree(path)
        walk(root, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1], True, data, rel, records)

    # Group counts per scene.
    counts: dict[str, dict[str, int]] = {}
    for r in records:
        c = counts.setdefault(r["scene"], {"total": 0, "csg": 0, "primitive_mesh": 0})
        c["total"] += 1
        if r["type"].startswith("CSG"):
            c["csg"] += 1
        else:
            c["primitive_mesh"] += 1

    if args.json:
        text = json.dumps({"counts": counts, "placeholders": records}, ensure_ascii=False, indent=2)
    else:
        lines = ["# Placeholder audit", "", "## Counts", "", "| Scene | Total | CSG | Primitive mesh |", "|---|---:|---:|---:|"]
        for scene, c in counts.items():
            lines.append(f"| `{scene}` | {c['total']} | {c['csg']} | {c['primitive_mesh']} |")
        lines += ["", "## Visible placeholders", ""]
        for scene in sorted({r["scene"] for r in records}):
            lines.append(f"### `{scene}`")
            lines.append("")
            lines.append("| Node | Type | Kind | Category | Local size (m) | World pos (m) | Rot (deg) | World AABB (m) |")
            lines.append("|---|---|---|---|---|---|---|---|")
            for r in [x for x in records if x["scene"] == scene]:
                p = r["world_position"]
                rot = r["world_rotation_deg"]
                ls = r["local_size"]
                ws = r["world_aabb_size"]
                lines.append(
                    f"| `{r['node_path']}` | {r['type']} | {r['kind']} | {r['category']} | "
                    f"{ls[0]:.2f} × {ls[1]:.2f} × {ls[2]:.2f} | "
                    f"{p[0]:.2f}, {p[1]:.2f}, {p[2]:.2f} | {rot[0]:.1f}, {rot[1]:.1f}, {rot[2]:.1f} | "
                    f"{ws[0]:.2f} × {ws[1]:.2f} × {ws[2]:.2f} |"
                )
            lines.append("")
        text = "\n".join(lines)

    if args.out:
        Path(args.out).write_text(text, encoding="utf-8")
        print(f"written: {args.out}")
        print(f"visible placeholders: {len(records)}")
    else:
        print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
