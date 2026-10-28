"""Генератор scenes/locations/shadow_sanctuary/shadow_sanctuary_art.tscn (S13).

Координаты зала: пол y = 0, зал x −10…10, z −7,5…7,5, ворота на юге (z = 7,1).
Снаружи — та же вершина, что в тропе: тропа → зал = (x − 1, y − 5,37, z + 86,7)."""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from tscn import NM, Scene, dir_to_euler, night_env, v3, f  # noqa: E402

ROOT = Path(__file__).resolve().parents[5]  # корень проекта
OUT = ROOT / "scenes/locations/shadow_sanctuary/shadow_sanctuary_art.tscn"
OFF = (-1.0, -5.37, 86.7)

S = Scene("res://scenes/locations/shadow_sanctuary/shadow_sanctuary.tscn", "ShadowSanctuary")
sky_shader = S.res("Shader", NM + "materials/nm_night_sky.gdshader")
moon = (-0.3, 0.75, 0.25)  # высокая луна: свет каскадами через проломы крыши (CANON гл. 14)
env = night_env("Env_art", "Sky_art", moon, fog=0.004, ambient=(0.13, 0.15, 0.22), ambient_energy=0.45,
                fog_color=(0.06, 0.07, 0.1), sky_affect=0.1,
                extra="volumetric_fog_enabled = true\nvolumetric_fog_density = 0.012\n"
                      "volumetric_fog_albedo = Color(0.75, 0.8, 0.95, 1)\nvolumetric_fog_length = 48.0")
S.sub(env.replace("SKY_SHADER", sky_shader))
rx, ry = dir_to_euler((-moon[0], -moon[1], -moon[2]))


def hide(path):
    S.override(path, visible="false")


def P(x, y, z):
    return (x + OFF[0], y + OFF[1], z + OFF[2])


S.override("Environment/WorldEnvironment", environment='SubResource("Env_art")')
S.node(f'''[node name="Moonlight" parent="Environment"]
rotation = {v3((rx, ry, 0))}
light_color = Color(0.66, 0.73, 0.95, 1)
light_energy = 0.7''')
# Лучи через проломы — выше новой кровли (11 м).
for n, x, z in (("Beam_Main", 0.6, -0.5), ("Beam_East", 6.4, 4.4), ("Beam_North", 0.0, -3.8)):
    S.node(f'[node name="{n}" parent="Environment"]\nposition = Vector3({f(x)}, 15.0, {f(z)})\nspot_range = 22.0')

# ---- CSG: видимое скрыто; коллизия пола, стен, колонн и возвышения остаётся. Кровля CSG на 6,25 м —
#      невидимый потолок ниже новой кровли — унесена вверх (сжатая коробка в комбайнере всё равно сталкивается).
S.override("Geometry/Blockout", visible="false")
S.override("Geometry/Blockout/MegalithWalls/Roof", transform="Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 120, 0)")
for n in ("CeilingBreach_Main", "CeilingBreach_East", "CeilingBreach_North"):
    S.override("Geometry/Blockout/MegalithWalls/" + n, transform="Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 130, 0)")
for n in ("GateLintelWest", "GateLintelEast"):
    S.override("Geometry/Blockout/MegalithWalls/" + n, transform="Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 140, 0)")
# Монолит-алтарь CSG опущен под верх модели алтаря (верх 1,5 м).
S.override("Geometry/Blockout/AltarStone", position=v3((0, 1.0, -5.0)))

S.group("Art")
# Пол: плиты 4 × 4 м.
for i, x in enumerate((-8, -4, 0, 4, 8)):
    for j, z in enumerate((-3.5, 0.5, 4.5, 8.5)):
        S.inst(f"Floor{i}{j}", "Art", "temple/floor_" + "ab"[(i + j) % 2], (x, 0.0, z))
# Стены из блоков чёрного мрамора 10,9 м; часть — с трещинами и обломами (CANON: трещины).
walls = []
for k, z in enumerate((-4.4, 1.2, 5.6)):
    walls.append((f"WallW{k}", "wall_block_ruined" if k == 1 else "wall_block_intact", (-10.3, 0, z), 0.0))
    walls.append((f"WallE{k}", "wall_block_intact" if k != 2 else "wall_block_ruined", (10.3, 0, z), math.pi))
for k, x in enumerate((-7.0, -1.0, 5.0, 9.0)):
    walls.append((f"WallN{k}", "wall_block_intact" if k != 2 else "wall_block_ruined", (x, 0, -8.2), math.pi / 2))
for k, x in enumerate((-8.3, 8.3)):
    walls.append((f"WallS{k}", "wall_block_intact", (x, 0, 8.0), -math.pi / 2))
for n, m, p, yaw in walls:
    S.inst(n, "Art", "temple/" + m, p, yaw=yaw)
S.inst("Portal", "Art", "temple/portal_frame", (0.0, 0.0, 7.7))
S.inst("Pediment", "Art", "temple/pediment_fragment", (3.3, 9.8, 7.9))
# Колонны: колоссальные монолиты на местах CSG-колонн; одна разрушена, барабан упал.
cols = [("column_intact", -6, -4.8), ("column_intact", -6, 0), ("column_broken_a", -6, 4.8),
        ("column_intact", 6, -4.8), ("column_intact", 6, 0), ("column_broken_b", 6, 4.8)]
for k, (m, x, z) in enumerate(cols):
    S.inst(f"Column{k}", "Art", "temple/" + m, (x, 0, z), yaw=0.3 * k)
for k, (x, z) in enumerate(((-6, -2.4), (6, -2.4), (6, 2.4))):
    S.inst(f"Entablature{k}", "Art", "temple/entablature_a", (x, 9.95, z), yaw=math.pi / 2)
# Упавшая колонна у западной стены — укрытие-щель Санни (узел SunnyCrevice сценария).
S.inst("FallenColumn", "Art", "temple/column_fallen", (-8.3, 0, 0.6), yaw=math.pi / 2)
S.inst("FallenDrum", "Art", "temple/roof_rubble_a", (7.9, 0, 2.9), yaw=0.4)
# Кровля: плиты на 10,9 м, проломы — над тремя лучами (CANON: часть крыши обрушена, лунные круги).
breaches = [(0.6, -0.5, 7.5, 5.5), (6.4, 4.4, 2.8, 2.4), (0.0, -4.9, 2.2, 2.6)]
k = 0
for x in (-8.4, -6.0, -3.6, -1.2, 1.2, 3.6, 6.0, 8.4):
    for z in (-4.5, 1.5, 6.0):
        if any(abs(x - bx) < bw / 2 + 0.6 and abs(z - bz) < bd / 2 + 1.5 for bx, bz, bw, bd in breaches):
            continue
        S.inst(f"Roof{k:02d}", "Art", "temple/roof_slab_a", (x, 10.9, z), yaw=0.04 * (k % 3))
        k += 1
# Под проломами: обломки крыши, снег и лёд на полу (CANON).
for k, (n, p, yaw) in enumerate((("temple/roof_rubble_a", (1.6, 0, 0.6), 0.6), ("temple/roof_rubble_a", (-1.9, 0, -1.6), 2.1),
                                 ("temple/roof_slab_a", (2.6, 0.0, -2.2), 1.2),
                                 ("mountain/snow_drift_low_a", (0.2, 0.0, -0.3), 0.3),
                                 ("mountain/snow_drift_crest_c", (2.4, 0.0, 1.4), 2.6),
                                 ("mountain/snow_drift_small_d", (6.6, 0.0, 4.2), 0.9),
                                 ("mountain/snow_drift_small_d", (0.2, 0.0, -4.0), 1.7),
                                 ("trail/ice_flow_a", (9.35, 0.0, 3.6), math.pi),
                                 ("trail/ice_flow_a", (-9.35, 0.0, -2.0), 0.0),
                                 ("mountain/snow_drift_wall_b", (-8.9, 0.0, -5.8), 0.0))):
    S.inst(f"Debris{k}", "Art", n, p, yaw=yaw)
# Рельефы на фризе (CANON: изысканные рельефы; мотивы — ART-DIRECTION).
for k, (n, p, yaw) in enumerate((("relief_panel_figure", (-9.4, 6.4, -2.6), math.pi / 2),
                                 ("relief_panel_geometric", (-9.4, 6.4, 3.0), math.pi / 2),
                                 ("relief_panel_figure", (9.4, 6.4, -2.6), -math.pi / 2),
                                 ("relief_panel_figure", (-3.0, 6.6, -7.3), 0.0),
                                 ("relief_panel_geometric", (3.0, 6.6, -7.3), 0.0))):
    S.inst(f"Relief{k}", "Art", "temple/" + n, p, yaw=yaw)

# ---- Алтарь (CANON гл. 14: цельный чёрный мрамор, «широкий, как кровать», сухой и чистый).
hide("Geometry/Blockout/AltarDais")
S.inst("DaisLower", "Art", "temple/floor_a", (0, 0.3, -3.5), scale=(1.0, 0.9, 0.75))
S.inst("DaisUpper", "Art", "temple/floor_b", (0, 0.6, -3.8), scale=(0.8, 0.9, 0.6))
S.inst("Altar", "Art", "temple/altar_black_marble", (0, 0.6, -5.0))
S.node('[node name="AltarInteractionPoint" parent="Spawns"]\nposition = Vector3(0, 1.55, -5)')
S.node('[node name="RitualGlow" parent="."]\nposition = Vector3(0, 1.51, -4.74)')

# ---- Снаружи: вершина, кости, ступени храма — тот же мир, что в тропе.
S.group("Outside")
# Стилобат зала: снаружи стены стоят на подиуме, плато ниже на 1,32 м (как в сцене тропы).
for i, x in enumerate((-8.0, 0.0, 8.0)):
    for j, z in enumerate((8.0, 0.0, -8.0)):
        S.inst(f"Podium{i}{j}", "Outside", "temple/floor_" + "ab"[(i + j) % 2], (x, -0.08, z), scale=(2.0, 3.9, 2.0))
S.inst("Summit", "Outside", "path/pp_summit", OFF)
S.inst("Stairs", "Outside", "temple/stairs_a", P(1.0, 4.05, -75.4))
# Створка ворот, вырванная «рукой гиганта» (CANON гл. 14), отброшена на плато у подножия ступеней — проём свободен.
S.inst("Gate", "Outside", "temple/gate_broken", P(-3.5, 4.05, -73.7), yaw=0.8)
rng = random.Random(14)
bone_models = ["remains/bones_scatter_a", "remains/bones_scatter_b", "remains/bones_pile_c", "remains/skull_human"]
for i in range(22):
    a = rng.uniform(0.3, 2.85)
    r = rng.uniform(5.0, 12.0)
    x, z = 1.0 + math.cos(a) * r * 1.1, -80.0 + math.sin(a) * r
    if z < -71.0:
        continue
    n = "remains/bones_monster_a" if i % 7 == 3 else bone_models[i % 4]
    S.inst(f"Bones{i:02d}", "Outside", n, P(x, 4.05, z), yaw=rng.uniform(0, 6.28))
S.inst("Clouds", "Outside", "res://scenes/environment/nm_cloud_sea.tscn", (0, -25.4, 0))
S.inst("RidgeWest", "Outside", "backdrop/ridge_mid_a", (-380, -36, 46), yaw=math.radians(90))
S.inst("RidgeSouth", "Outside", "backdrop/ridge_mid_b", (-60, -46, 420), yaw=math.radians(170))
S.inst("RidgeEast", "Outside", "backdrop/ridge_mid_a", (360, -40, 120), yaw=math.radians(-80))

OUT.write_text(S.text(), encoding="utf-8")
print("wrote", OUT)
