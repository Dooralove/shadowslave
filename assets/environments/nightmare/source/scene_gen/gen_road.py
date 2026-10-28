"""Генератор scenes/slice/locations/caravan_road_art.tscn (B15 пролога и S01 кампании)."""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from tscn import NM, Scene, dir_to_euler, night_env, v3, f  # noqa: E402
from strip import Path as RoadPath, lay_edges, lay_faces, lay_road, lay_walls  # noqa: E402

ROOT = Path(__file__).resolve().parents[5]  # корень проекта
OUT = ROOT / "scenes/slice/locations/caravan_road_art.tscn"

S = Scene("res://scenes/slice/locations/caravan_road.tscn", "CaravanRoad")
sky_shader = S.res("Shader", NM + "materials/nm_night_sky.gdshader")

# CANON (02_caravan_canon §1.2): ночь, яркая луна, бледный свет, сильный ветер, снег.
# Луна на западе — над бездной; стены вдоль дороги смотрят на неё (освещены), полотно — в боковом свете.
moon = (-0.86, 0.4, 0.1)
# Туман: слабый по дальности (видны дорога и стены на десятки метров) и плотный ниже кромки —
# бездна заполнена мглой, дно не видно (ART-DIRECTION, бриф перевала §3).
env = night_env("Env_art", "Sky_art", moon, fog=0.0032, ambient=(0.24, 0.29, 0.42), ambient_energy=0.55,
                fog_color=(0.07, 0.085, 0.12), sky_affect=0.15,
                extra="fog_height = -14.0\nfog_height_density = 0.035")
S.sub(env.replace("SKY_SHADER", sky_shader))
rx, ry = dir_to_euler((-moon[0], -moon[1], -moon[2]))
S.override("WorldEnvironment", environment='SubResource("Env_art")')
S.override("Sun", rotation=v3((rx, ry, 0)), light_color="Color(0.66, 0.73, 0.95, 1)", light_energy="0.95",
           directional_shadow_max_distance="120.0")

# CSG-заглушки: видимое скрыто; коллизии полотна, стены и невидимого бортика остаются (по ним идёт марш).
for n in ("Valley", "FarRidge", "Road/Surface", "Road/Cliff", "Road/Underside", "Road/Chain/Links"):
    S.override(n, visible="false")
for k in range(1, 19):
    S.override(f"Road/Rocks/Rock{k:02d}", visible="false")
for k in range(1, 13):
    S.override(f"Road/Rocks/Edge{k:02d}", visible="false")

# ---- Путь (локальные оси Road): от +44 м за спиной до −400 м, затем поворот вправо за стену.
S.group("Art", "Road")
path = RoadPath(0.0, 44.0).line(444.0).arc(22.0, 75.0).line(14.0)
S0 = 44.0  # s, где z = 0 (точка появления Spawns/Chain)
W0, W1 = S0 + 36.2, S0 + 48.4  # расширение-стоянка впереди (S01 заканчивается у z = −36)


def ramp(s, a, b, w=6.0):
    if s < a - w or s > b + w:
        return 0.0
    if s < a:
        t = (s - (a - w)) / w
    elif s > b:
        t = 1.0 - (s - b) / w
    else:
        return 1.0
    return t * t * (3 - 2 * t)


wall_lat = lambda s: 1.3 + 2.0 * ramp(s, W0, W1)  # noqa: E731
edge_lat = lambda s: -3.1 * ramp(s, W0, W1)  # noqa: E731
skip = [k for k in range(200) if (S0 - 4 * k) <= -(W0 - S0) + 0.3 and (S0 - 4 * k - 4) >= -(W1 - S0) - 0.5]
lay_road(S, "Road/Art", path, ice=(6, 14, 23, 31, 47, 60, 77, 95), skip=skip)
lay_walls(S, "Road/Art", path, s0=0.3, lateral=wall_lat)
lay_edges(S, "Road/Art", path, s0=0.3, lateral=edge_lat)
lay_faces(S, "Road/Art", path, s1=470.0, drop_lat=lambda s: -3.1 * ramp(s, W0, W1),
          upper_lat=lambda s: 2.0 * ramp(s, W0, W1))
# Стоянка: площадка-расширение и выступ скалы, который «частично защищает» её (CANON гл. 2).
S.inst("CampPlatform", "Road/Art", "mountain/camp_platform_a", (-0.85, 0.0, -36.2))
S.inst("CampOverhang", "Road/Art", "mountain/rock_overhang_b", (3.4, 0.0, -49.0), yaw=0.15)
# «Впереди огонь. Привал.» (реплика у CampArrival): костёр уже горит на площадке.
S.inst("CampFire", "Road/Art", "caravan/campfire_large", (-1.2, 0.02, -43.0), yaw=0.4)
S.inst("CampFlame", "Road/Art", "res://scenes/environment/nm_fire_flame.tscn", (-1.2, 0.15, -43.0))

# ---- Реквизит у подножия стены и на кромке (вместо CSG-камней): камни, осыпь, надувы, лёд.
rng = random.Random(6)
props = ["boulder_angular_a", "scree_pile_a", "boulder_slab_a", "snow_drift_wall_b", "boulder_shard_a",
         "boulder_rounded_a", "snow_drift_wall_b", "boulder_split_a", "scree_pile_a", "snow_drift_wall_b"]
s = S0 - 30.0
k = 0
while s < 460.0:
    if not (W0 - 6 < s < W1 + 6):
        x, z, h = path.offset(s, 1.75 + rng.uniform(0.0, 0.3))
        n = props[k % len(props)]
        S.inst(f"Foot{k:02d}", "Road/Art", "mountain/" + n, (x, path.y(s), z), yaw=-h + rng.uniform(-0.6, 0.6))
        if k % 4 == 1:
            xi, zi, hi = path.offset(s + 2.0, 1.05)
            S.inst(f"Ice{k:02d}", "Road/Art", "trail/ice_flow_a", (xi, 0.0, zi), yaw=-hi)
        if k % 5 == 2:
            xl, zl, hl = path.offset(s + 1.0, -1.7)
            S.inst(f"Lip{k:02d}", "Road/Art", "mountain/snow_drift_small_d", (xl, -0.02, zl), yaw=-hl + rng.uniform(-1, 1))
    s += rng.uniform(5.0, 9.0)
    k += 1
# Сосульки под навесами стены и кости под снегом у стены (ART-DIRECTION брифа тропы: следы прежних караванов).
for k, (sz, n) in enumerate(((S0 + 18.0, "remains/bones_scatter_b"), (S0 + 63.0, "remains/skull_human"),
                             (S0 + 140.0, "remains/bones_scatter_a"), (S0 - 20.0, "remains/bones_scatter_a"))):
    x, z, h = path.offset(sz, 0.7)
    S.inst(f"Remains{k}", "Road/Art", n, (x, 0.0, z), yaw=-h + 1.0)

# ---- Цепь колонны: модели звеньев вместо CSG-бруса (узел Chain сдвигается вместе с Санни).
for k in range(7):
    S.inst(f"ChainLink{k}", "Road/Chain", "caravan/chain_main_taut", (0, 0.03, -8.6 + 2.0 * k))

# ---- Фон: мгла в бездне, отроги по ту сторону, гора над стеной, снегопад.
S.group("Backdrop")
S.inst("Clouds", "Backdrop", "res://scenes/environment/nm_cloud_sea.tscn", (0, -70, 0))
S.inst("RidgeWest", "Backdrop", "backdrop/ridge_mid_a", (-420, -60, -120), yaw=math.radians(90))
S.inst("RidgeNorthWest", "Backdrop", "backdrop/ridge_mid_b", (-360, -70, -480), yaw=math.radians(60))
S.inst("RidgeSouthWest", "Backdrop", "backdrop/ridge_mid_a", (-330, -60, 260), yaw=math.radians(120))
S.inst("BlackMountain", "Backdrop", "mountain/black_mountain_far", (1300, -600, -900), yaw=math.radians(200))
S.inst("Snowfall", ".", "res://scenes/environment/nm_snowfall.tscn")

OUT.write_text(S.text(), encoding="utf-8")
print("wrote", OUT, "skip", skip)
