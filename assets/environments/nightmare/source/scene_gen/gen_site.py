"""Генератор scenes/locations/caravan_site/caravan_site_art.tscn (S02–S06)."""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from tscn import NM, Scene, dir_to_euler, night_env, v3, f  # noqa: E402
from strip import (Path as RoadPath, lay_edges, lay_faces, lay_road, lay_walls,  # noqa: E402
                   path_ending_at)

ROOT = Path(__file__).resolve().parents[5]  # корень проекта
OUT = ROOT / "scenes/locations/caravan_site/caravan_site_art.tscn"

S = Scene("res://scenes/locations/caravan_site/caravan_site.tscn", "CaravanSite")
sky_shader = S.res("Shader", NM + "materials/nm_night_sky.gdshader")
moon = (-0.86, 0.4, 0.1)  # как на дороге: запад, над бездной
env = night_env("Env_art", "Sky_art", moon, fog=0.0032, ambient=(0.24, 0.29, 0.42), ambient_energy=0.5,
                fog_color=(0.07, 0.085, 0.12), sky_affect=0.15,
                extra="fog_height = -14.0\nfog_height_density = 0.035")
S.sub(env.replace("SKY_SHADER", sky_shader))
rx, ry = dir_to_euler((-moon[0], -moon[1], -moon[2]))
S.override("Environment/WorldEnvironment", environment='SubResource("Env_art")')
S.node(f'''[node name="Moon" parent="Environment"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 24, 0)
rotation = {v3((rx, ry, 0))}
light_color = Color(0.66, 0.73, 0.95, 1)
light_energy = 0.95''')

# ---- CSG: видимое скрыто, коллизия площадки и стен остаётся (проверена тестами геометрии выхода).
S.override("Geometry/Blockout", visible="false")
# Пандус в северном проходе — горб на дороге вверх; убран (полотно дороги — модули с коллизией).
S.override("Geometry/Blockout/Ramp", transform="Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.2, -60, -5.9)",
           size=v3((0.001, 0.001, 0.001)))
# Северная граница: проход к дороге вверх (выход на рассвете перенесён на север — см. DECISIONS).
S.sub('[sub_resource type="BoxShape3D" id="Shape_north_w"]\nsize = Vector3(5, 4, 0.5)')
S.sub('[sub_resource type="BoxShape3D" id="Shape_north_e"]\nsize = Vector3(4.6, 4, 0.5)')
S.sub('[sub_resource type="BoxShape3D" id="Shape_exit_side"]\nsize = Vector3(0.5, 4, 5.4)')
S.sub('[sub_resource type="BoxShape3D" id="Shape_exit_end"]\nsize = Vector3(3.4, 4, 0.5)')
S.node('''[node name="North" parent="Geometry/Boundary"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -3.5, 2, -4.25)
shape = SubResource("Shape_north_w")''')
for name, pos, shape in (("NorthEast", (3.7, 2, -4.25), "Shape_north_e"),
                         ("ExitWest", (-1.25, 2, -6.95), "Shape_exit_side"),
                         ("ExitEast", (1.65, 2, -6.95), "Shape_exit_side"),
                         ("ExitEnd", (0.2, 2, -9.6), "Shape_exit_end")):
    S.node(f'''[node name="{name}" type="CollisionShape3D" parent="Geometry/Boundary"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {f(pos[0])}, {f(pos[1])}, {f(pos[2])})
shape = SubResource("{shape}")''')
S.node('''[node name="DawnExit" parent="Interactables"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.2, 0.2, -7.4)''')
S.node('''[node name="DawnExit" parent="Spawns"]
position = Vector3(0.2, 0.05, -7.6)''')

# ---- Площадка, стены, кромка
S.group("Art")
# Грунт сужен с запада: край плиты уходит под снежный карниз кромки (иначе прямой срез над обрывом).
S.inst("Ground", "Art", "site/camp_site_ground", (0.35, 0, 0.5), scale=(0.9, 1.0, 1.0))
# Восточная стена: модуль + навес-выступ, «частично защищающий» стоянку (CANON гл. 2).
S.inst("EastWall", "Art", "mountain/rock_wall_a", (5.9, 0, 5.7))
S.inst("EastOverhang", "Art", "mountain/rock_overhang_b", (5.9, 0, -0.3))
S.inst("EastUpper", "Art", "backdrop/cliff_face_tall_a", (8.6, 9.0, 7.0))
# Южный торец расширения (стена поворачивает к дороге) и северные скалы с проходом.
S.inst("SouthCorner", "Art", "mountain/rock_wall_b", (1.3, 0, 6.3), yaw=math.radians(-90))
S.inst("NorthEastRock", "Art", "mountain/rock_wall_a", (8.7, 0, -5.0), yaw=math.radians(90))
S.inst("NorthWestRock", "Art", "mountain/rock_wall_broken_c", (-1.1, 0, -4.9), yaw=math.radians(90))
S.inst("NorthUpper", "Art", "backdrop/cliff_face_tall_b", (25.0, 8.0, -6.5), yaw=math.radians(90))
# Западная кромка обрыва (губа на x = −6) и лицо обрыва в бездну.
for k in range(3):
    S.inst(f"CampEdge{k}", "Art", "mountain/" + ("cliff_edge_a1", "cliff_edge_a2", "cliff_edge_a1")[k],
           (-4.0, 0, 5.7 - 5.0 * k))
S.inst("CampDrop", "Art", "backdrop/cliff_face_tall_a", (-7.2, -40.0, 8.0))

# ---- Южная дорога (по ней пришли): из-за поворота внизу к площадке, ровная у границы.
south = path_ending_at([("arc", 20.0, 60.0), ("line", 18.0)], 0.0, 5.7)
L_S = south.length
south.y = lambda s: -0.075 * max(0.0, (L_S - 6.0) - s)


def ramp_in(s, a, w=6.0):
    t = min(1.0, max(0.0, (s - a) / w))
    return t * t * (3 - 2 * t)


S.group("SouthRoad", "Art")
lay_road(S, "Art/SouthRoad", south, s0=-1.0 + (L_S % 4.0))
lay_walls(S, "Art/SouthRoad", south, s1=L_S - 0.2, prefix="S")
lay_edges(S, "Art/SouthRoad", south, s1=L_S - 0.5, prefix="S", lateral=lambda s: -4.0 * ramp_in(s, L_S - 9.0))
lay_faces(S, "Art/SouthRoad", south, s1=L_S - 6.0, prefix="S")

# ---- Северная дорога (вверх, выход на рассвете): проход между скалами, затем поворот вправо.
north = RoadPath(0.2, -4.6).line(22.0).arc(16.0, 75.0).line(14.0)
north.y = lambda s: 0.07 * max(0.0, s - 5.0)
S.group("NorthRoad", "Art")
lay_road(S, "Art/NorthRoad", north)
lay_walls(S, "Art/NorthRoad", north, s0=5.6, prefix="N", start=2)
lay_edges(S, "Art/NorthRoad", north, s0=5.0, prefix="N", start=1)
lay_faces(S, "Art/NorthRoad", north, s0=6.0, prefix="N")

# ---- Подножия, снег, лёд, следы (не на точках сценария)
rng = random.Random(21)
dress = [
    ("mountain/snow_drift_wall_b", (4.9, 0, 4.2), 0.1), ("mountain/snow_drift_wall_b", (5.0, 0, -3.6), -0.2),
    ("mountain/scree_pile_a", (5.1, 0.0, 1.6), 0.4), ("mountain/snow_drift_crest_c", (-5.0, 0, -0.6), 1.4),
    ("mountain/snow_drift_low_a", (-4.8, 0, 4.6), 1.6), ("mountain/boulder_angular_a", (5.2, 0, -1.6), 0.8),
    ("mountain/rock_fragments_set", (3.0, 0, -4.0), 0.2), ("mountain/boulder_slab_a", (-5.4, 0, -3.8), 0.3),
    ("mountain/snow_drift_small_d", (2.6, 0, 4.6), 0.0), ("mountain/snow_drift_small_d", (-2.8, 0, -3.9), 2.0),
    ("trail/ice_flow_a", (5.5, 0, 3.0), 0.0), ("trail/ice_flow_a", (5.6, 0, -2.4), 0.0),
    ("trail/icicles_b", (4.4, 4.6, 0.4), 0.0),
    # Груда камней у южной границы: дорога вниз сужается, невидимая граница совпадает с завалом.
    ("mountain/scree_pile_a", (-1.0, -0.1, 9.9), 0.6), ("mountain/boulder_rounded_a", (0.9, -0.15, 10.2), 1.2),
    ("mountain/boulder_split_a", (-0.1, -0.15, 11.1), 2.0),
    # Юго-западный угол: выход скалы и надув закрывают стык кромки площадки и кромки дороги.
    ("mountain/rock_outcrop_a", (-4.6, -0.05, 6.4), 0.5), ("mountain/snow_drift_crest_c", (-3.4, 0, 6.9), 2.2),
    ("mountain/boulder_slab_a", (-5.6, -0.1, 5.4), 1.1), ("mountain/snow_drift_small_d", (-2.4, 0, 6.3), 0.4),
]
for k, (n, p, yaw) in enumerate(dress):
    S.inst(f"Dress{k:02d}", "Art", n, p, yaw=yaw)

# ---- Реквизит сценария: модели внутри узлов, которыми управляет сценарий (CSG скрыт)
def hide(path):
    S.override(path, visible="false")


def shrink(path):
    S.override(path, size=v3((0.001, 0.001, 0.001)))


for n in ("Stone01", "Stone02", "Stone03", "Stone04", "Stone05", "Stone06", "Stone07", "Stone08", "LogA", "LogB",
          "FlameA", "FlameB"):
    hide("Props/Fire/" + n)
S.inst("Campfire", "Props/Fire", "caravan/campfire_large", (0, 0.0, 0), yaw=0.3)
S.inst("Flame", "Props/Fire", "res://scenes/environment/nm_fire_flame.tscn", (0, 0.12, 0))
S.node('[node name="Light" parent="Props/Fire/Flame"]\nvisible = false')  # свет огня — FireLight сценария

for n in ("Basket", "Bread", "Flask"):
    hide("Props/Rations/" + n)
S.inst("BreadA", "Props/Rations", "caravan/bread_stale", (0, 0.0, 0), yaw=0.4)
S.inst("BreadB", "Props/Rations", "caravan/bread_stale", (0.13, 0.0, 0.07), yaw=-0.9)
S.inst("Water", "Props/Rations", "caravan/water_flask", (0.24, -0.02, -0.04), yaw=1.2)

for n in ("ChainLine", "LinkA", "LinkB", "Shackle"):
    hide("Props/Chain/" + n)
phi = math.atan2(0.86, 0.52)
cx, cz = -1.80, -0.95
for k, t in enumerate((-1.87, 0.0, 1.87)):
    S.inst(f"Main{k}", "Props/Chain", "caravan/chain_main_taut", (cx + math.sin(phi) * t, -0.1, cz + math.cos(phi) * t),
           yaw=phi)
S.inst("Slack", "Props/Chain", "caravan/chain_main_slack", (0.05, 0.0, 0.45), yaw=-0.6)
S.inst("Shackles", "Props/Chain", "caravan/shackles_pair", (0.55, 0.0, 0.6), yaw=0.4)

hide("Props/Wagon/Blockout")
hide("Props/Wagon/Shaft")
S.inst("Model", "Props/Wagon", "caravan/wagon_cargo", (0, 0, 0), yaw=math.radians(-90))
for w in ("WedgeL", "WedgeR"):
    shrink("Props/Wagon/" + w)
    S.inst("Chock", "Props/Wagon/" + w, "caravan/wheel_chock", (0.05, -0.16, 0), yaw=math.radians(90))

for n in ("LinkA", "LinkB", "LinkC", "LinkD"):
    hide("Props/ChainLoop/" + n)
S.inst("Loop", "Props/ChainLoop", "caravan/chain_main_slack", (0, -0.17, 0), yaw=0.5, scale=0.7)

for n in ("Blade", "Hilt"):
    hide("Props/VeteranSword/" + n)
S.inst("Model", "Props/VeteranSword", "caravan/sword_broken", (0, 0.0, 0))

for n in ("StemA", "StemB", "StemC", "BerryA", "BerryB", "BerryC", "BerryD"):
    hide("Props/Bloodbane/" + n)
S.inst("BushA", "Props/Bloodbane", "flora/bloodbane_bush_a", (0, -0.05, 0), yaw=0.3)
S.inst("BushC", "Props/Bloodbane", "flora/bloodbane_bush_c", (0.5, -0.05, 0.45), yaw=1.9)
S.inst("BushB", "Props/Bloodbane", "flora/bloodbane_bush_b", (-0.35, -0.05, -0.5), yaw=-0.7)

for n in ("LogA", "LogB", "LogC", "Stump"):
    hide("Props/Dressing/Woodpile/" + n)
S.inst("BundleA", "Props/Dressing/Woodpile", "caravan/firewood_bundle", (0, 0, 0), yaw=1.4)
S.inst("BundleB", "Props/Dressing/Woodpile", "caravan/firewood_bundle", (0.1, 0.22, 0.05), yaw=1.7)
for b in ("BedrollA", "BedrollB"):
    hide(f"Props/Dressing/{b}/Base")
    hide(f"Props/Dressing/{b}/Pillow")
    S.inst("Model", "Props/Dressing/" + b, "site/bedroll_a", (0, 0, 0))
for n in ("Box", "Band"):
    hide("Props/Dressing/Crate/" + n)
S.inst("Model", "Props/Dressing/Crate", "caravan/crate_supplies_a", (0, 0, 0), yaw=0.2)
hide("Props/Dressing/Barrel")
S.inst("BarrelModel", "Props/Dressing", "caravan/barrel_water_a", (-0.55, 0, -1.85))
S.inst("SackModel", "Props/Dressing", "caravan/sack_grain_a", (-2.2, 0, -2.9), yaw=0.9)

for fl in ("FlaskA", "FlaskB", "FlaskC"):
    hide(f"Props/Flasks/{fl}/Body")
    hide(f"Props/Flasks/{fl}/Neck")
    S.inst("Model", "Props/Flasks/" + fl, "caravan/water_flask", (0, 0.06, 0), rot=(math.radians(90), 0.6, 0))

for n in ("Ring", "Shaft", "Bit"):
    hide("Props/Key/" + n)
S.inst("Model", "Props/Key", "caravan/shackle_key", (0, -0.08, 0), yaw=0.5)

# Камнепад: модели внутри CSG-камней (сценарий роняет узлы Props/Rocks/*), CSG сжаты в точку.
rocks = {"Rock01": ("mountain/boulder_angular_a", 0.65), "Rock02": ("mountain/boulder_rounded_a", 0.6),
         "Rock03": ("mountain/boulder_angular_a", 0.45), "Rock04": ("mountain/boulder_split_a", 0.45),
         "Rock05": ("mountain/boulder_angular_a", 0.35), "Rock06": ("mountain/boulder_slab_a", 0.45),
         "Ice01": ("mountain/boulder_shard_a", 0.7), "Ice02": ("mountain/boulder_shard_a", 0.85),
         "Ice03": ("mountain/boulder_shard_a", 0.6), "Ice04": ("mountain/boulder_shard_a", 0.55)}
for n, (m, sc) in rocks.items():
    shrink("Props/Rocks/" + n)
    S.inst("Model", "Props/Rocks/" + n, m, (0, -0.3 * sc, 0), scale=sc)

# Оружие стражи в руках NPC: модели вместо CSG-цилиндров (сами всадники и лошади — конвейер персонажей).
hide("NPCs/Hero/Spear")
S.inst("SpearModel", "NPCs/Hero", "caravan/spear_soldier", (0.28, -0.72, -0.1), rot=(math.radians(90), 0.0, -0.1))
hide("NPCs/Veteran/Whip")
S.inst("WhipModel", "NPCs/Veteran", "caravan/whip_coiled", (0.32, 0.12, -0.05), rot=(0.0, 0.0, math.radians(80)))

# ---- Фон: облака в бездне, отроги по ту сторону, гора над северными скалами, снегопад
S.group("Backdrop")
S.inst("Clouds", "Backdrop", "res://scenes/environment/nm_cloud_sea.tscn", (0, -70, 0))
S.inst("RidgeWest", "Backdrop", "backdrop/ridge_mid_a", (-420, -60, 40), yaw=math.radians(90))
S.inst("RidgeNorthWest", "Backdrop", "backdrop/ridge_mid_b", (-340, -70, -380), yaw=math.radians(60))
S.inst("RidgeSouthWest", "Backdrop", "backdrop/ridge_mid_a", (-330, -60, 420), yaw=math.radians(120))
# «Над ним — чёрная гора, луна, снег» (02_caravan_canon, сцена у края лагеря): вершина над северными скалами.
S.inst("BlackMountain", "Backdrop", "mountain/black_mountain_far", (300, -620, -980), yaw=math.radians(200))
S.inst("Snowfall", ".", "res://scenes/environment/nm_snowfall.tscn")

OUT.write_text(S.text(), encoding="utf-8")
print("wrote", OUT)
