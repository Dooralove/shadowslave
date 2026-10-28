"""Материалы и импорт Godot для ассетов Первого Кошмара (системный Python, без bpy).

Запуск из корня проекта:
    python assets/environments/nightmare/source/make_godot_materials.py            # .tres + .import текстур
    python assets/environments/nightmare/source/make_godot_materials.py --bind     # привязать слоты .glb

1. Пишет `materials/<имя>.tres` по описанию `nm_materials.py`:
   layered → ShaderMaterial на `nm_layered_triplanar.gdshader`, uv → ORMMaterial3D.
2. Пишет `.import` текстур до первого импорта: карты нормалей — RGTC (`compress/normal_map=1`),
   высоты и исходные альбедо, заменённые производными, — `importer="skip"` (нужны только Blender).
3. `--bind`: для каждого `.glb` в папках набора читает имена материалов из JSON-чанка и
   прописывает в его `.import` внешние материалы (`_subresources/materials/<слот>/use_external`),
   как у скамейки парка (S3.2). Затем удаляет `.md5` в `.godot/imported`, чтобы Godot
   переимпортировал файл с новыми параметрами (кэш, не исходники).

`--family <имя>` — другой набор ассетов с тем же конвейером (по умолчанию — Первый Кошмар):
`prologue` — пролог (`assets/environments/prologue/`, материалы `pr_materials.py`);
`park` — только привязка новых моделей парка (`props/tree_*`, `lamp_*`, `station_*`, `bollard_*`) к рукописным
`.tres` парка; скамейка, урна и стаканчик S3.2 не трогаются.
"""

import importlib.util
import json
import re
import struct
import sys
from pathlib import Path

SRC = Path(__file__).resolve().parent
sys.path.insert(0, str(SRC))
import nm_materials as M  # noqa: E402

NM = SRC.parent
ROOT = NM.parents[2]
MAT_DIR = NM / "materials"
TEX_DIR = MAT_DIR / "textures"
SHADER = "nm_layered_triplanar.gdshader"
ASSET_DIRS = ["mountain", "caravan", "remains", "flora", "temple", "trail", "backdrop", "site", "path"]
ONLY = None  # префиксы файлов для --bind (None — все .glb папок)
ENV = ROOT / "assets" / "environments"
FAMILIES = {
    "prologue": dict(root=ENV / "prologue", module=ENV / "prologue" / "source" / "pr_materials.py",
                     dirs=["cell", "lobby"], only=None),
    "park": dict(root=ENV / "park", module=None, dirs=["props"], only=("tree_", "lamp_", "station_", "bollard_")),
}


def use_family(name):
    """Переключить пути и таблицу материалов на другой набор ассетов."""
    global M, NM, MAT_DIR, TEX_DIR, ASSET_DIRS, ONLY
    fam = FAMILIES[name]
    NM = fam["root"]
    MAT_DIR = NM / "materials"
    TEX_DIR = MAT_DIR / "textures"
    ASSET_DIRS = fam["dirs"]
    ONLY = fam["only"]
    M = None
    if fam["module"]:
        spec = importlib.util.spec_from_file_location(fam["module"].stem, fam["module"])
        M = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(M)


def res(path):
    return "res://" + Path(path).resolve().relative_to(ROOT).as_posix()


def tex_file(name):
    """Имя — файл в `TEX_DIR`; путь с «/» — от корня проекта (общие текстуры других наборов)."""
    return ROOT / name if "/" in name else TEX_DIR / name


def srgb(c):
    out = []
    for v in c:
        v = max(0.0, min(1.0, v))
        out.append(v * 12.92 if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055)
    return out


def color(c, a=1.0):
    r, g, b = srgb(c)
    return f"Color({r:.4f}, {g:.4f}, {b:.4f}, {a})"


def layered_tres(name, spec):
    base = M.TEXSETS[spec["base"]]
    snow = M.TEXSETS["snow"]
    ext = [("Shader", MAT_DIR / SHADER)]
    for key in ("albedo", "normal", "arm"):
        ext.append(("Texture2D", tex_file(base[key])))
    if spec.get("snow"):
        for key in ("albedo", "normal", "arm"):
            ext.append(("Texture2D", tex_file(snow[key])))
    lines = ['[gd_resource type="ShaderMaterial" format=3]', ""]
    ids = {}
    for i, (kind, p) in enumerate(ext, 1):
        rid = f"{i}_{Path(p).stem[:24]}"
        ids[Path(p).name] = rid
        lines.append(f'[ext_resource type="{kind}" path="{res(p)}" id="{rid}"]')
    lines += ["", '[sub_resource type="FastNoiseLite" id="FastNoiseLite_macro"]', "frequency = 0.012",
              "fractal_octaves = 3", "", '[sub_resource type="NoiseTexture2D" id="NoiseTexture2D_macro"]',
              "width = 256", "height = 256", "seamless = true", 'noise = SubResource("FastNoiseLite_macro")', "",
              "[resource]", f'resource_name = "{name}"', f'shader = ExtResource("{ids[SHADER]}")']
    p = "shader_parameter/"
    lines += [
        f'{p}base_albedo = ExtResource("{ids[base["albedo"]]}")',
        f'{p}base_normal = ExtResource("{ids[base["normal"]]}")',
        f'{p}base_orm = ExtResource("{ids[base["arm"]]}")',
        f"{p}base_tint = {color(spec.get('tint', (1, 1, 1)))}",
        f"{p}base_tile_m = {base['tile']}",
        f"{p}base_normal_strength = {spec.get('normal', 1.0)}",
        f"{p}base_roughness_scale = {spec.get('rough_scale', 1.0)}",
        f"{p}base_roughness_offset = {spec.get('rough_offset', 0.0)}",
        f"{p}base_metallic = {spec.get('metallic', 0.0)}",
        f'{p}macro_noise = SubResource("NoiseTexture2D_macro")',
        f"{p}macro_tile_m = 8.0",
        f"{p}macro_strength = 0.25",
        f"{p}snow_enabled = {'true' if spec.get('snow') else 'false'}",
    ]
    if spec.get("snow"):
        lines += [
            f'{p}snow_albedo = ExtResource("{ids[snow["albedo"]]}")',
            f'{p}snow_normal = ExtResource("{ids[snow["normal"]]}")',
            f'{p}snow_orm = ExtResource("{ids[snow["arm"]]}")',
            f"{p}snow_tile_m = {snow['tile']}",
            f"{p}snow_coverage = {spec.get('coverage', 0.35)}",
            f"{p}snow_softness = 0.12",
            f"{p}snow_breakup = 0.35",
            f"{p}snow_vertex_weight = 1.0",
        ]
    lines += [f"{p}dirt_strength = 1.0", f"{p}triplanar_sharpness = 6.0", ""]
    return "\n".join(lines)


def uv_tres(name, spec):
    base = M.TEXSETS[spec["base"]]
    lines = ['[gd_resource type="ORMMaterial3D" format=3]', ""]
    ids = {}
    for i, key in enumerate(("albedo", "arm", "normal"), 1):
        rid = f"{i}_{key}"
        ids[key] = rid
        lines.append(f'[ext_resource type="Texture2D" path="{res(tex_file(base[key]))}" id="{rid}"]')
    s = 1.0 / base["tile"]
    lines += ["", "[resource]", f'resource_name = "{name}"', "vertex_color_use_as_albedo = true",
              f"albedo_color = {color(spec.get('tint', (1, 1, 1)))}",
              f'albedo_texture = ExtResource("{ids["albedo"]}")',
              f'orm_texture = ExtResource("{ids["arm"]}")',
              f"metallic = {spec.get('metallic', 0.0)}",
              "normal_enabled = true", f"normal_scale = {spec.get('normal', 1.0)}",
              f'normal_texture = ExtResource("{ids["normal"]}")',
              f"uv1_scale = Vector3({s:.4f}, {s:.4f}, {s:.4f})"]
    if spec.get("triplanar"):  # для CSG-поверхностей сцен (UV коробки 0..1 растянули бы текстуру)
        lines += ["uv1_triplanar = true", "uv1_world_triplanar = true"]
    return "\n".join(lines + [""])


def plain_tres(name, spec):
    lines = ['[gd_resource type="StandardMaterial3D" format=3]', ""]
    if "emission_texture" in spec:
        lines += [f'[ext_resource type="Texture2D" path="{res(tex_file(spec["emission_texture"]))}" id="1_emission"]', ""]
    lines += ["[resource]", f'resource_name = "{name}"', "vertex_color_use_as_albedo = true",
              f"albedo_color = {color(spec['color'], spec.get('alpha', 1.0))}",
              f"roughness = {spec.get('rough', 0.8)}"]
    if spec.get("metallic"):
        lines.append(f"metallic = {spec['metallic']}")
    if "alpha" in spec:  # стекло: прозрачность по альфе, обе стороны
        lines += ["transparency = 1", "cull_mode = 2"]
    if "emission" in spec:
        lines += ["emission_enabled = true", f"emission = {color(spec['emission'])}",
                  f"emission_energy_multiplier = {spec.get('emission_energy', 1.0)}"]
        if "emission_texture" in spec:  # умножение: по умолчанию Godot складывает цвет эмиссии с картинкой
            lines += ["emission_operator = 1", 'emission_texture = ExtResource("1_emission")']
    return "\n".join(lines + [""])


TEX_IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map={normal}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""

SKIP_IMPORT = """[remap]

importer="skip"
"""


def write_texture_imports():
    used = set()
    for t in M.TEXSETS.values():
        used.update((t["albedo"], t["normal"], t["arm"]))
    for spec in M.MATERIALS.values():
        if "emission_texture" in spec:
            used.add(spec["emission_texture"])
    for tex in sorted(list(TEX_DIR.glob("*.jpg")) + list(TEX_DIR.glob("*.png"))):
        imp = tex.with_name(tex.name + ".import")
        if tex.name in used:
            if imp.exists() and 'importer="texture"' in imp.read_text(encoding="utf-8"):
                continue  # уже импортирован — uid и пути сохраняем
            normal = 1 if "_nor_" in tex.name else 0
            imp.write_text(TEX_IMPORT.format(normal=normal), encoding="utf-8", newline="\n")
        else:
            imp.write_text(SKIP_IMPORT, encoding="utf-8", newline="\n")
        print("import", tex.name, "texture" if tex.name in used else "skip")


def write_materials():
    for name, spec in M.MATERIALS.items():
        kind = spec["kind"]
        if spec.get("external"):
            continue  # материал живёт в другом наборе (рукописный .tres парка)
        if kind == "layered":
            text = layered_tres(name, spec)
        elif kind == "uv":
            text = uv_tres(name, spec)
        else:
            text = plain_tres(name, spec)
        (MAT_DIR / f"{name}.tres").write_text(text, encoding="utf-8", newline="\n")
        print("material", name)


def glb_materials(path):
    data = path.read_bytes()
    magic, _, _ = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF", path
    length, kind = struct.unpack_from("<I4s", data, 12)
    doc = json.loads(data[20:20 + length])
    return [m.get("name", "") for m in doc.get("materials", [])]


def bind():
    cache = ROOT / ".godot" / "imported"
    for d in ASSET_DIRS:
        for glb in sorted((NM / d).glob("*.glb")) if (NM / d).exists() else []:
            if ONLY and not glb.name.startswith(ONLY):
                continue
            imp = glb.with_name(glb.name + ".import")
            if not imp.exists():
                print("no .import yet (run Godot --import first):", glb.name)
                continue
            names = [n for n in glb_materials(glb) if (MAT_DIR / f"{n}.tres").exists()]
            text = imp.read_text(encoding="utf-8")
            entries = ",\n".join(
                f'"{n}": {{\n"use_external/enabled": true,\n'
                f'"use_external/fallback_path": "{res(MAT_DIR / (n + ".tres"))}",\n'
                f'"use_external/path": "{res(MAT_DIR / (n + ".tres"))}"\n}}' for n in names)
            sub = '_subresources={\n"materials": {\n' + entries + "\n}\n}" if names else "_subresources={}"
            text = re.sub(r"_subresources=\{.*?\n\}\n(?=gltf/|\Z|[a-z_]+/)", sub + "\n", text, flags=re.S) \
                if "_subresources={\n" in text else re.sub(r"_subresources=\{\}", sub, text)
            imp.write_text(text, encoding="utf-8", newline="\n")
            for md5 in cache.glob(glb.name + "-*.md5"):
                md5.unlink()
            print("bound", glb.relative_to(NM).as_posix(), names)


if __name__ == "__main__":
    if "--family" in sys.argv:
        use_family(sys.argv[sys.argv.index("--family") + 1])
    if "--bind" in sys.argv:
        bind()
    else:
        write_texture_imports()
        write_materials()
