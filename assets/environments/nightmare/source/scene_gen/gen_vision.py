"""Генератор scenes/slice/locations/mountain_vision_art.tscn."""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from tscn import NM, Scene, dir_to_euler, night_env, v3, f  # noqa: E402
from strip import Path as RoadPath, lay_edges, lay_faces, lay_road, lay_walls  # noqa: E402

ROOT = Path(__file__).resolve().parents[5]  # корень проекта
OUT = ROOT / "scenes/slice/locations/mountain_vision_art.tscn"

S = Scene("res://scenes/slice/locations/mountain_vision.tscn", "MountainVision")
sky_shader = S.res("Shader", NM + "materials/nm_night_sky.gdshader")
cloud = S.res("PackedScene", "res://scenes/environment/nm_cloud_sea.tscn")
snowfall = S.res("PackedScene", "res://scenes/environment/nm_snowfall.tscn")

# Луна: запад, ~24° над горизонтом (стены вдоль дороги смотрят на неё); луч света — обратный.
moon = (-0.86, 0.4, 0.1)
# Крупный план — ночная дымка (дальний конец дороги и дно бездны растворяются, как в брифе перевала);
# облёт — своё окружение с тонким туманом, иначе гора в 2 км не видна (Camera3D.environment).
env = night_env("Env_art", "Sky_art", moon, fog=0.0035, ambient=(0.24, 0.29, 0.42), ambient_energy=0.5,
                sky_affect=0.0)
S.sub(env.replace("SKY_SHADER", sky_shader))
env2 = night_env("Env_orbit", "Sky_orbit", moon, fog=0.00032, ambient=(0.24, 0.29, 0.42), ambient_energy=0.5)
S.sub(env2.replace("SKY_SHADER", sky_shader))

rx, ry = dir_to_euler((-moon[0], -moon[1], -moon[2]))
S.override("WorldEnvironment", environment='SubResource("Env_art")')
S.override("Moonlight", rotation=v3((rx, ry, 0)), light_energy="0.9",
           directional_shadow_max_distance="400.0")
# CSG-заглушки видения скрыты; узлы, которыми управляет постановка (SnowCover, Bones, Caravan), остаются.
for n in ("Moon", "Ground", "Peaks", "Road/Ridge", "Road/Surface", "Road/Cliff", "Road/Caravan/Chain"):
    S.override(n, visible="false")
for n in ("BoneA", "BoneB", "SkullA", "BoneC", "SkullB", "BoneD"):
    S.override("Road/Bones/" + n, visible="false")
# Снег на дороге: CSG-плита сжата в точку, надувы — внутри узла (постановка сжимает его по Y и прячет).
S.override("Road/SnowCover", position=v3((0, 0, -25)), size=v3((0.001, 0.001, 0.001)))

# ---- Ракурсы: облёт настоящей горы (масштаб 1:1, ~1,4 км), дорога — как была.
C = (1300.0, -600.0, -900.0)  # центр подножия горы
look = (C[0], C[1] + 780.0, C[2])
cam = (C[0] - 1650.0, C[1] + 1100.0, C[2] + 1650.0)
S.override("Shots/Orbit", position=v3(cam), far="12000.0", environment='SubResource("Env_orbit")')
S.override("Shots/Orbit/LookAt", position=v3((look[0] - cam[0], look[1] - cam[1], look[2] - cam[2])))
S.override("Shots/RoadShot", position=v3((10.5, 3.353, 1.709)), far="12000.0", fov="62.0")
S.override("Shots/RoadShot/LookAt", position=v3((1.8, 2.507, -36.13)))

# ---- Фон (мировые координаты)
S.group("Backdrop")
S.inst("BlackMountain", "Backdrop", "mountain/black_mountain_far", C, yaw=math.radians(200))
for i, (p, yaw) in enumerate((((-2600, -260, -1900), 60), ((500, -260, -4300), 0), ((3600, -260, -1500), -75),
                               ((-1400, -260, 3300), 180), ((3000, -260, 2600), 225), ((-3600, -260, 900), 100))):
    S.inst(f"Range{i}", "Backdrop", "mountain/mountain_range_far", p, yaw=math.radians(yaw))
# Отроги по ту сторону бездны (слева от дороги) и за поворотом.
S.inst("RidgeWest", "Backdrop", "backdrop/ridge_mid_a", (-520, -150, -160), yaw=math.radians(90))
S.inst("RidgeNorthWest", "Backdrop", "backdrop/ridge_mid_b", (-380, -170, -620), yaw=math.radians(40))
S.inst("RidgeSouth", "Backdrop", "backdrop/ridge_mid_a", (-260, -160, 520), yaw=math.radians(150))
S.inst("Clouds", "Backdrop", "res://scenes/environment/nm_cloud_sea.tscn", (0, -140, 0))

# ---- Крупный план дороги (локальные оси Road: вдоль −Z, стена справа +X, бездна слева −X)
S.group("Art", "Road")
rng = random.Random(14)
# Путь: прямая 100 м, затем плавный поворот вправо за стену — конец дороги не виден ни с какого ракурса.
path = RoadPath(0.0, 0.8).line(100.0).arc(22.0, 75.0).line(12.0)
lay_road(S, "Road/Art", path, ice=(4, 9, 17))
lay_walls(S, "Road/Art", path, s0=0.2)
lay_edges(S, "Road/Art", path, s0=0.2)
lay_faces(S, "Road/Art", path, s1=112.0)
for k, (x, zz, n) in enumerate(((1.0, -3.0, "scree_pile_a"), (0.6, -21.0, "boulder_angular_a"),
                                (0.9, -33.0, "snow_drift_wall_b"), (0.8, -44.0, "boulder_split_a"))):
    S.inst(f"Prop{k}", "Road/Art", "mountain/" + n, (x, 0, zz), yaw=rng.uniform(-0.5, 0.5))

# Снег, который «сходит» в видении: надувы поперёк полотна (внутри SnowCover, z — от его центра −25).
for k in range(13):
    n = "snow_drift_low_a" if k % 3 else "snow_drift_crest_c"
    S.inst(f"Drift{k:02d}", "Road/SnowCover", "mountain/" + n,
           (rng.uniform(-0.3, 0.3), -0.02, 24.0 - 4.0 * k), yaw=rng.uniform(-0.25, 0.25) + (math.pi if k % 2 else 0))
for k in range(6):
    S.inst(f"WallDrift{k}", "Road/SnowCover", "mountain/snow_drift_wall_b", (0.75, -0.02, 22.0 - 8.5 * k))

# Кости на старой дороге (узел Bones показывает постановка).
for k, (n, p, yaw) in enumerate((("bones_scatter_a", (0.3, 0.0, -12.0), 0.7), ("skull_human", (-0.2, 0.0, -18.5), 2.1),
                                 ("bones_scatter_b", (-0.3, 0.0, -26.0), -0.4), ("bones_pile_c", (0.25, 0.0, -33.0), 1.2),
                                 ("skull_human", (0.7, 0.02, -33.6), -1.0), ("bones_scatter_a", (-0.45, 0.0, -38.5), 2.6))):
    S.inst(f"Remains{k}", "Road/Bones", "remains/" + n, p, yaw=yaw)

# Цепь каравана: четыре звена по 2 м вместо CSG-бруса.
for k in range(4):
    S.inst(f"ChainLink{k}", "Road/Caravan", "caravan/chain_main_taut", (0, 0.1, 1.0 + 2.0 * k))

S.inst("Snowfall", ".", "res://scenes/environment/nm_snowfall.tscn")

OUT.write_text(S.text(), encoding="utf-8")
print("wrote", OUT)
