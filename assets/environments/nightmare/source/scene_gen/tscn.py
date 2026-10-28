"""Мини-генератор текстовых .tscn для арт-вариантов (наследование + расстановка моделей)."""
import math

NM = "res://assets/environments/nightmare/"


class Scene:
    def __init__(self, base_path=None, root_name=None, root_type="Node3D"):
        self.ext = []  # (type, path, id)
        self.ext_ids = {}
        self.subs = []  # text blocks
        self.nodes = []  # text blocks
        self.base = base_path
        self.root_name = root_name
        self.root_type = root_type
        if base_path:
            self.base_id = self.res("PackedScene", base_path)

    def res(self, typ, path):
        if path in self.ext_ids:
            return self.ext_ids[path]
        rid = f"{len(self.ext) + 1}_{path.rsplit('/', 1)[-1].split('.')[0][:18]}"
        self.ext.append((typ, path, rid))
        self.ext_ids[path] = rid
        return rid

    def glb(self, rel):
        return self.res("PackedScene", NM + rel + ".glb")

    def sub(self, text):
        self.subs.append(text.strip("\n"))

    def node(self, text):
        self.nodes.append(text.strip("\n"))

    def override(self, path, **props):
        name = path.rsplit("/", 1)[-1]
        parent = path.rsplit("/", 1)[0] if "/" in path else "."
        lines = [f'[node name="{name}" parent="{parent}"]']
        lines += [f"{k} = {v}" for k, v in props.items()]
        self.node("\n".join(lines))

    def group(self, name, parent=".", pos=None, rot=None):
        lines = [f'[node name="{name}" type="Node3D" parent="{parent}"]']
        if pos:
            lines.append(f"position = {v3(pos)}")
        if rot:
            lines.append(f"rotation = {v3(rot)}")
        self.node("\n".join(lines))

    def inst(self, name, parent, rel, pos=(0, 0, 0), yaw=0.0, scale=None, rot=None, extra=None):
        rid = self.glb(rel) if not rel.startswith("res://") else self.res("PackedScene", rel)
        lines = [f'[node name="{name}" parent="{parent}" instance=ExtResource("{rid}")]']
        if scale is not None or rot is not None or yaw:
            r = rot if rot is not None else (0.0, yaw, 0.0)
            s = scale if scale is not None else 1.0
            lines.append(f"transform = {xform(pos, r, s)}")
        else:
            lines.append(f"position = {v3(pos)}")
        for k, v in (extra or {}).items():
            lines.append(f"{k} = {v}")
        self.node("\n".join(lines))

    def text(self):
        out = ["[gd_scene format=3]", ""]
        for typ, path, rid in self.ext:
            out.append(f'[ext_resource type="{typ}" path="{path}" id="{rid}"]')
        out.append("")
        for s in self.subs:
            out.append(s)
            out.append("")
        if self.base:
            out.append(f'[node name="{self.root_name}" instance=ExtResource("{self.base_id}")]')
        else:
            out.append(f'[node name="{self.root_name}" type="{self.root_type}"]')
        out.append("")
        for n in self.nodes:
            out.append(n)
            out.append("")
        return "\n".join(out)


def f(x):
    s = f"{x:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def v3(v):
    return f"Vector3({f(v[0])}, {f(v[1])}, {f(v[2])})"


def basis_yxz(rx, ry, rz, s=1.0):
    """Euler YXZ (порядок Godot по умолчанию) → столбцы базиса."""
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    # R = Ry * Rx * Rz
    ry_m = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rx_m = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    rz_m = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]

    def mul(a, b):
        return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]

    m = mul(mul(ry_m, rx_m), rz_m)
    sv = s if isinstance(s, (tuple, list)) else (s, s, s)
    for j in range(3):
        for i in range(3):
            m[i][j] *= sv[j]
    return m


def xform(pos, rot, s):
    m = basis_yxz(rot[0], rot[1], rot[2], s)
    # Godot пишет Transform3D построчно: rows[0], rows[1], rows[2], затем origin.
    vals = [m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2], *pos]
    return "Transform3D(" + ", ".join(f(v) for v in vals) + ")"


def dir_to_euler(d):
    """Направление луча DirectionalLight (куда светит) → (rx, ry) при порядке YXZ."""
    x, y, z = d
    n = math.sqrt(x * x + y * y + z * z)
    x, y, z = x / n, y / n, z / n
    rx = math.asin(max(-1.0, min(1.0, y)))
    ry = math.atan2(-x, -z)
    return rx, ry


def night_env(sub_id, sky_id, moon_dir, fog=0.0012, ambient=(0.22, 0.27, 0.4), ambient_energy=0.45,
              fog_color=(0.06, 0.075, 0.11), extra="", sky_affect=0.25):
    """Environment + Sky + ShaderMaterial неба (sub_resource-блоки)."""
    md = moon_dir
    return f"""
[sub_resource type="ShaderMaterial" id="{sky_id}_mat"]
shader = ExtResource("SKY_SHADER")
shader_parameter/moon_direction = {v3(md)}

[sub_resource type="Sky" id="{sky_id}"]
sky_material = SubResource("{sky_id}_mat")

[sub_resource type="Environment" id="{sub_id}"]
background_mode = 2
sky = SubResource("{sky_id}")
ambient_light_source = 2
ambient_light_color = Color({f(ambient[0])}, {f(ambient[1])}, {f(ambient[2])}, 1)
ambient_light_energy = {f(ambient_energy)}
tonemap_mode = 2
glow_enabled = true
glow_intensity = 0.4
glow_bloom = 0.05
ssao_enabled = true
ssao_radius = 2.0
ssao_intensity = 1.5
fog_enabled = true
fog_light_color = Color({f(fog_color[0])}, {f(fog_color[1])}, {f(fog_color[2])}, 1)
fog_density = {fog}
fog_aerial_perspective = 0.35
fog_sky_affect = {f(sky_affect)}
{extra}
"""
