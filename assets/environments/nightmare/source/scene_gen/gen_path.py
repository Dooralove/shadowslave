"""Генератор scenes/locations/pilgrim_path/pilgrim_path_art.tscn (S07–S12)."""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from tscn import NM, Scene, dir_to_euler, night_env, v3, f  # noqa: E402
from strip import (Path as RoadPath, lay_edges, lay_faces, lay_road, lay_walls,  # noqa: E402
                   path_ending_at)

ROOT = Path(__file__).resolve().parents[5]  # корень проекта
OUT = ROOT / "scenes/locations/pilgrim_path/pilgrim_path_art.tscn"

S = Scene("res://scenes/locations/pilgrim_path/pilgrim_path.tscn", "PilgrimPath")
sky_shader = S.res("Shader", NM + "materials/nm_night_sky.gdshader")
# Луна на юго-западе: освещены и стены тропы (смотрят на запад), и южные грани серпантина.
moon = (-0.62, 0.42, 0.66)
# CANON-INFERRED (спецификация S11): «узкий карниз над облаками» — слой облаков на −20 м; туман плотнеет ниже кромки.
env = night_env("Env_art", "Sky_art", moon, fog=0.003, ambient=(0.22, 0.27, 0.38), ambient_energy=0.55,
                fog_color=(0.08, 0.095, 0.135), sky_affect=0.15,
                extra="fog_height = -8.0\nfog_height_density = 0.05")
S.sub(env.replace("SKY_SHADER", sky_shader))
rx, ry = dir_to_euler((-moon[0], -moon[1], -moon[2]))
S.override("Environment/WorldEnvironment", environment='SubResource("Env_art")')
S.node(f'''[node name="Moon" parent="Environment"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 30, 0)
rotation = {v3((rx, ry, 0))}
light_color = Color(0.66, 0.73, 0.95, 1)
light_energy = 0.95''')


def hide(path):
    S.override(path, visible="false")


# ---- CSG блок-аута: скрыт, коллизии выключены — ходьбу дают коллизии моделей и бортики над обрывом.
for n in ("StartRoad", "RampEast", "EastLanding", "RampWest", "WestLanding", "RampNorth", "Alcove", "NarrowLedge",
          "CaveFloor", "CaveWallWest", "CaveWallEast", "CaveCeiling", "HeroLedge", "TempleStair", "CliffWest",
          "CliffEast", "BrokenRoadSlab"):
    S.override("Geometry/" + n, visible="false", use_collision="false")
for n in ("StartSnow", "EastSnow", "WestSnow", "AlcoveSnow", "LedgeSnow", "HeroSnow", "TempleStairSnow",
          "AlcoveOverhang", "GapAbyss", "BrokenRoadSlab2"):
    hide("Geometry/" + n)

S.group("Art")

# ---- 1. Дорога от стоянки (пришли с юга из-за поворота) до излома над провалом (CANON гл. 9).
south = path_ending_at([("arc", 20.0, 60.0), ("line", 34.0)], 0.0, -0.5)
S.group("Road", "Art")
lay_road(S, "Art/Road", south, s0=south.length % 4.0, ice=(3, 9))
lay_walls(S, "Art/Road", south, s1=south.length - 4.0, prefix="R")
lay_edges(S, "Art/Road", south, s1=south.length - 0.5, prefix="R")
lay_faces(S, "Art/Road", south, prefix="R", s1=south.length - 3.0)
S.inst("BrokenEnd", "Art/Road", "trail/road_old_broken_end", (0, 0, -0.5))
S.inst("BrokenScar", "Art/Road", "mountain/rock_wall_broken_c", (1.4, 0, 3.6))
# Южная сторона рампы — скальный массив: закрывает торцы и тыл стены дороги, лицо смотрит на рампу (−Z).
S.inst("RampSouthFace", "Art/Road", "backdrop/cliff_face_tall_b", (1.8, -1.5, -0.6), yaw=math.radians(-90))
S.inst("RampSouthUpper", "Art/Road", "backdrop/cliff_face_tall_a", (3.5, 12.0, 1.5), yaw=math.radians(-90))
for k, (n, p, yaw) in enumerate((("mountain/cliff_edge_collapsed_b", (0, 0, 3.5), 0.0),
                                 ("mountain/scree_pile_a", (-1.7, -4.4, -6.0), 0.6),
                                 ("mountain/boulder_angular_a", (-0.8, -4.4, -7.2), 1.4),
                                 ("mountain/boulder_split_a", (-2.4, -4.5, -5.0), 2.4),
                                 ("mountain/rock_fragments_set", (0.6, -0.02, -2.6), 0.4))):
    S.inst(f"Rubble{k}", "Art/Road", n, p, yaw=yaw)
# Позади старта — дорога уходит за поворот; граница — у завала из свежих глыб (камнепад, гл. 4, 9).
for k, (n, p, yaw) in enumerate((("mountain/boulder_rounded_a", (-0.6, 0, 16.6), 0.4),
                                 ("mountain/boulder_angular_a", (0.6, 0, 17.4), 1.9),
                                 ("mountain/scree_pile_a", (0.2, 0, 18.4), 3.0))):
    S.inst(f"BackRubble{k}", "Art/Road", n, p, yaw=yaw)

# ---- 2. Серпантин у провала: рельеф под отметки сцены, стена горы с востока, обрыв с запада.
S.inst("Switchback", "Art", "path/pp_switchback", (0, 0, 0))
east = RoadPath(8.3, -0.5).line(22.0)
lay_walls(S, "Art", east, prefix="SE", lateral=0.0, start=3)
lay_faces(S, "Art", east, prefix="SE", drop=False, upper_x=2.6, upper_y=10.0)
S.inst("Sword_stone", "Art", "mountain/boulder_slab_a", (7.0, 1.55, -8.4), yaw=0.6, scale=0.75)
for k, (n, p, yaw) in enumerate((("mountain/snow_drift_wall_b", (7.6, 1.62, -6.0), 0.0),
                                 ("mountain/boulder_angular_a", (7.5, 1.62, -10.8), 0.5),
                                 ("mountain/scree_pile_a", (2.4, 0.3, -6.6), 1.2),
                                 ("trail/ice_flow_a", (7.95, 1.6, -9.5), 0.0),
                                 ("mountain/snow_drift_small_d", (-0.4, 3.4, -12.2), 0.8),
                                 ("mountain/rock_outcrop_a", (-0.6, 3.25, -16.6), 1.7))):
    S.inst(f"SwDress{k}", "Art", n, p, yaw=yaw)
for k in range(3):
    S.inst(f"SwDrop{k}", "Art", "backdrop/cliff_face_tall_" + "ab"[k % 2], (-9.5, -44.0, 2.0 - 22.0 * k))

# ---- 3. Полка старой тропы (x ≈ 0,95; 3,8 → 4,1 м): брусчатка, стена справа, карниз над облаками.
up = RoadPath(0.95, -17.8).line(48.0)
up.y = lambda s: 3.8 + 0.3 * min(1.0, max(0.0, s / 8.0))  # 3,8 → 4,1 к алькову, без ступени
ALC0, ALC1 = 8.0, 17.0   # альков (z −25,8 … −34,8): полка алькова стыкуется с брусчаткой без зазора
SPUR0, SPUR1 = 17.0, 23.0  # выступ Учёного (z −34,8 … −40,8)
CAVE0, CAVE1 = 25.7, 36.7  # массив с щелью и пещерой (z −43,5 … −54,5)
S.group("Trail", "Art")
lay_road(S, "Art/Trail", up, s1=ALC0)
lay_road(S, "Art/Trail", up, s0=SPUR1, prefix="N", ice=(1, 3))
lay_edges(S, "Art/Trail", up, s1=ALC0 - 1.0, prefix="A", lateral=0.5)
lay_edges(S, "Art/Trail", up, s0=SPUR1, prefix="C", lateral=0.5, start=1)
lay_walls(S, "Art/Trail", up, s1=ALC0 - 0.4, prefix="A", lateral=1.3)
lay_walls(S, "Art/Trail", up, s0=SPUR1 + 0.3, s1=CAVE0 - 0.2, prefix="B", lateral=1.2, start=2)
lay_walls(S, "Art/Trail", up, s0=CAVE1, prefix="C", lateral=1.05, start=4)
lay_faces(S, "Art/Trail", up, prefix="T", drop_x=-1.6, drop_y=-44.0, upper_x=4.2, upper_y=8.0)
# Альков (CANON гл. 10): ниша за узким выступом, огонь внутри скрыт скалами, вид вниз с полки.
S.inst("Alcove", "Art/Trail", "trail/alcove_shelter", (1.4, 4.1, -30.3))
# Выступ, за который Герой оставляет Учёного (E3.5); сдвинут к стене: проход у обрыва ~0,95 м.
S.inst("ScholarSpur", "Art/Trail", "trail/trail_pilgrim_03_spur", (1.3, 4.1, -34.8))
# Щель за высокими камнями и скрытая пещера без второго выхода (CANON гл. 12–13).
S.inst("Cave", "Art/Trail", "path/cave_crevice_wide", (1.6, 4.1, -48.5))
for k, (n, p, yaw) in enumerate((("trail/icicles_b", (1.9, 6.4, -24.0), 0.0), ("trail/ice_flow_a", (2.15, 4.1, -45.2), 0.0),
                                 ("mountain/snow_drift_wall_b", (1.9, 4.1, -56.5), 0.1),
                                 ("mountain/boulder_shard_a", (1.9, 4.1, -62.2), 0.6),
                                 ("trail/ice_flow_a", (2.2, 4.1, -58.0), 0.0),
                                 ("mountain/snow_drift_small_d", (0.3, 4.1, -51.5), 1.0))):
    S.inst(f"TrDress{k}", "Art/Trail", n, p, yaw=yaw)

# ---- 4. Вершина: плоская скала под снегом, кости, фасад храма (CANON гл. 14).
S.inst("Summit", "Art", "path/pp_summit", (0, 0, 0))

# ---- Точки сценария, оказавшиеся в скале: только данные сцены, код не менялся.
S.node('[node name="AlcoveFire" parent="Props"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 3.4, 4.1, -30.2)')
for n in ("Ring", "Flame"):
    hide("Props/AlcoveFire/" + n)
S.inst("Campfire", "Props/AlcoveFire", "caravan/campfire_large", (0, 0.0, 0), yaw=0.8, scale=0.7)
S.inst("FireFx", "Props/AlcoveFire", "res://scenes/environment/nm_fire_flame.tscn", (0, 0.08, 0), scale=0.75)
S.node('[node name="Light" parent="Props/AlcoveFire/FireFx"]\nvisible = false')
hide("Props/BedrollA")
hide("Props/BedrollB")
S.inst("BedrollA", "Art/Trail", "site/bedroll_a", (2.7, 4.1, -28.9), yaw=1.4)
S.inst("BedrollB", "Art/Trail", "site/bedroll_a", (2.6, 4.1, -31.8), yaw=1.9)
S.inst("Firewood", "Art/Trail", "caravan/firewood_bundle", (4.3, 4.1, -31.3), yaw=0.3)
S.node('[node name="BloodStain" parent="Props"]\ntransform = Transform3D(0.96, 0, 0.3, 0, 1, 0, -0.3, 0, 0.96, 0.5, 4.13, -33.9)')
S.inst("FallIce", "Art/Trail", "trail/ice_flow_a", (0.4, 4.1, -33.6), yaw=math.radians(-90), scale=0.6)
# Пещера без огня (канон); тусклый холодный отсвет из щели, чтобы читались своды и фигуры.
S.node('''[node name="CaveGlow" type="OmniLight3D" parent="Art/Trail"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 6.6, 5.6, -48.5)
light_color = Color(0.55, 0.65, 0.9, 1)
light_energy = 1.3
omni_range = 7.0''')
S.node('[node name="CaveBlood" parent="Props"]\ntransform = Transform3D(0.92, 0, -0.39, 0, 1, 0, 0.39, 0, 0.92, 9.2, 4.12, -49.2)')
S.node('[node name="ShiftyLedge" parent="Spawns"]\nposition = Vector3(0.5, 4.15, -33.5)')
S.node('[node name="CaveInside" parent="Spawns"]\nposition = Vector3(8.9, 4.15, -49.3)')
S.node('[node name="Cave" parent="Interactables"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1.2, 4.25, -48.5)')
S.node('[node name="CaveExit" parent="Interactables"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 7.4, 4.25, -48.5)')
# Тиран над Героем поднимается из бездны (запад), а не из толщи стены.
S.node('[node name="TyrantAtHero" parent="NPCs"]\nposition = Vector3(-3.4, 0.4, -60.3)')
# Внизу под альковом — каменистый склон, по которому бродит слепой Тиран (CANON гл. 10).
# Тиран виден из алькова: уступ скалы под тропой, в кадре камеры отдыха (yaw −0,18, наклон −18°).
S.node('[node name="TyrantSighting" parent="NPCs"]\nposition = Vector3(-5.5, -4.6, -47.0)')
S.inst("SightingLedge", "Art", "mountain/boulder_slab_a", (-5.6, -5.25, -47.0), yaw=0.4, scale=(3.2, 1.6, 3.0))
S.inst("SightingRock", "Art", "mountain/rock_outcrop_a", (-3.6, -4.9, -45.2), yaw=0.7, scale=1.4)
S.inst("SightingScree", "Art", "mountain/scree_pile_a", (-7.4, -4.9, -48.6), yaw=1.9, scale=1.3)
S.inst("SightingFace", "Art", "backdrop/cliff_face_tall_b", (-5.0, -36.0, -36.0), yaw=0.0)

# Тиран — та же модель Горного Короля, что на стоянке (без ИИ и коллизий: только силуэт в постановке);
# CSG-ящики скрыты, видимостью узлов по-прежнему управляет сценарий.
for node in ("TyrantSighting", "TyrantAtHero"):
    for n in ("Body", "Eye1", "Eye2", "Eye3", "Eye4", "Eye5") + (("Arm",) if node == "TyrantAtHero" else ()):
        hide(f"NPCs/{node}/{n}")
    S.inst("King", "NPCs/" + node, "res://scenes/characters/mountain_king.tscn", (0, 0, 0),
           rot=(0.0, math.radians(-90 if node == "TyrantSighting" else -75), 0.0), scale=1.2,
           extra={"process_mode": "4", "collision_layer": "0", "collision_mask": "0"})

# Меч на камне у площадки серпантина.
for n in ("Blade", "Hilt"):
    hide("Props/Sword/" + n)
S.inst("Model", "Props/Sword", "caravan/short_sword", (0, 0.02, 0), rot=(0.0, 0.0, 0.08))
hide("Props/StoneMarker")
hide("Props/GraveStones")
# Кости: CSG-кластеры и поле цилиндров (MultiMesh сценария) скрыты, вместо них — модели (CANON гл. 2, 14:
# «тысячи костей людей и чудовищ»). Данные поля и узлы кластеров остаются — по ним работают тесты.
hide("Props/Bones")
rng = random.Random(14)
bone_models = ["remains/bones_scatter_a", "remains/bones_scatter_b", "remains/bones_pile_c", "remains/skull_human"]
S.group("Remains", "Art")
k = 0
for side in (-1, 1):
    for z in (-67.0, -69.2, -71.4, -73.6, -76.0):
        x = 1.0 + side * rng.uniform(2.3, 3.4)
        S.inst(f"StairBones{k:02d}", "Art/Remains", bone_models[k % 3], (x, 4.05, z), yaw=rng.uniform(0, 6.28))
        k += 1
for i in range(26):
    a = rng.uniform(0, 6.28)
    r = rng.uniform(5.0, 12.5)
    x, z = 1.0 + math.cos(a) * r * 1.1, -80.0 + math.sin(a) * r
    if -84.0 < z < -74.0 and -9.5 < x < 11.5:
        continue  # не на ступенях и не в портале
    n = "remains/bones_monster_a" if i % 7 == 3 else bone_models[i % 4]
    S.inst(f"FieldBones{i:02d}", "Art/Remains", n, (x, 4.05, z), yaw=rng.uniform(0, 6.28))

# ---- Фасад храма: показывается вместе с TempleGlow после захвата Героя (как в сценарии).
for n in ("TempleBody", "Step1", "Step2", "ColumnA", "ColumnB", "ColumnC", "ColumnD", "DoorGlow"):
    hide("Props/TempleGlow/" + n)
for n in ("FragmentWest", "FragmentEast", "FallenLintel"):
    hide("Props/TempleGlow/BrokenGate/" + n)
T = "Props/TempleGlow"
S.inst("Stairs", T, "temple/stairs_a", (1.0, 4.05, -75.4))
S.inst("Portal", T, "temple/portal_frame", (1.0, 5.37, -79.6))
S.inst("Pediment", T, "temple/pediment_fragment", (4.3, 15.1, -79.8), yaw=0.02)
for i, (n, x, z) in enumerate((("column_intact", -5.6, -79.0), ("column_broken_a", 7.6, -79.0),
                               ("column_intact", -9.8, -79.4), ("column_broken_b", 11.8, -79.4))):
    S.inst(f"Column{i}", T, "temple/" + n, (x, 5.37, z))
S.inst("Entablature", T, "temple/entablature_a", (-7.7, 15.3, -79.2))
# Стилобат: храм стоит на каменном подиуме высотой в ступени (1,32 м), а не висит над плато.
for i, x in enumerate((-11.0, -3.0, 5.0, 13.0)):
    for j, z in enumerate((-78.6, -86.6)):
        S.inst(f"Podium{i}{j}", T, "temple/floor_" + "ab"[(i + j) % 2], (x, 5.29, z), scale=(2.0, 3.9, 2.0))
for i, (n, x) in enumerate((("wall_block_intact", -13.0), ("wall_block_ruined", 15.0))):
    S.inst(f"SideWall{i}", T, "temple/" + n, (x, 5.37, -82.0))
    S.inst(f"FlankWall{i}", T, "temple/" + ("wall_block_ruined" if i == 0 else "wall_block_intact"),
           (x, 5.37, -88.6))
S.inst("BackWall", T, "temple/wall_block_intact", (1.0, 5.37, -90.0), yaw=math.radians(90))
for i in range(4):
    S.inst(f"Floor{i}", T, "temple/floor_" + "ab"[i % 2], (-1.0 + 4.0 * (i % 2), 5.37, -81.0 - 4.0 * (i // 2)))
for i in range(3):
    S.inst(f"Roof{i}", T, "temple/roof_slab_a", (-3.0 + 4.0 * i, 15.2, -83.0), yaw=math.radians(90))
S.inst("Gate", T, "temple/gate_broken", (-3.5, 4.05, -73.7), yaw=0.8)  # створка отброшена с прохода
S.inst("FallenLintel", T, "temple/column_fallen", (8.6, 4.05, -73.2), yaw=1.25)
S.inst("Rubble", T, "temple/roof_rubble_a", (-6.4, 4.05, -74.6), yaw=1.2)
S.inst("ReliefA", T, "temple/relief_panel_figure", (-13.0, 9.0, -79.6))
S.inst("ReliefB", T, "temple/relief_panel_geometric", (15.0, 9.0, -79.6))

# Вход в храм — у порога портала на верху ступеней (а не за 10 м до них): после затемнения
# святилище начинается сразу за этим порогом. Искажение стража — у входа (B3, A02).
S.node('[node name="Temple" parent="Interactables"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 5.9, -78.4)')
S.node('[node name="TempleGuard" parent="Props"]\nposition = Vector3(1, 5.45, -77.3)')

# ---- Бортики над обрывом (невидимые; совпадают с губой карниза/кромки), чтобы нельзя было сорваться
#      в пустоту: в обёртке тропы возврата при падении нет.
S.node('[node name="ArtBounds" type="StaticBody3D" parent="Geometry"]\ncollision_mask = 0')
bounds = []


def wall(name, x0, z0, x1, z1, h=4.0, y=None, thick=0.5):
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    ln = math.hypot(x1 - x0, z1 - z0)
    yaw = math.atan2(x1 - x0, z1 - z0)
    sid = f"Bound_{name}"
    S.sub(f'[sub_resource type="BoxShape3D" id="{sid}"]\nsize = Vector3({f(thick)}, {f(h)}, {f(ln)})')
    yy = (y if y is not None else 0.0) + h / 2
    c, s_ = math.cos(yaw), math.sin(yaw)
    S.node(f'''[node name="{name}" type="CollisionShape3D" parent="Geometry/ArtBounds"]
transform = Transform3D({f(c)}, 0, {f(s_)}, 0, 1, 0, {f(-s_)}, 0, {f(c)}, {f(cx)}, {f(yy)}, {f(cz)})
shape = SubResource("{sid}")''')


wall("RoadWest", -2.3, 18.5, -2.3, -0.4)
wall("RoadBack", -2.4, 16.2, 1.4, 16.2)
wall("PitEdge", -2.6, -4.35, 0.15, -4.35)
wall("LandingWest", -1.3, -8.7, -1.3, -18.2, y=3.0)
wall("LandingPit", -1.3, -8.75, 0.9, -8.75, y=3.0)
wall("TrailWest1", -0.85, -18.2, -0.85, -25.8, y=3.6)
wall("AlcoveWest", -0.25, -25.8, -0.25, -34.8, y=3.9)
wall("SpurWest", 0.05, -34.8, 0.05, -40.9, y=3.9)
wall("TrailWest2", -0.85, -40.9, -0.85, -68.5, y=3.9)
wall("ApproachEast", 3.3, -63.0, 3.3, -69.0, y=3.9)
# Кольцо по кромке плато вершины (эллипс 15 × 13 м с шумным краем → внутрь на ~1,2 м).
pts = []
for i in range(24):
    a = i / 24 * 2 * math.pi
    rr = 1.0 + 0.12 * math.sin(3 * a + 1.3) + 0.07 * math.sin(7 * a + 0.4)
    pts.append((1.0 + math.cos(a) * 14.0 * rr, -80.0 + math.sin(a) * 12.0 * rr))
for i in range(24):
    (x0, z0), (x1, z1) = pts[i], pts[(i + 1) % 24]
    if min(x0, x1) < 3.4 and max(x0, x1) > -1.4 and max(z0, z1) > -71.0:
        continue  # проход с карниза на плато
    wall(f"Rim{i:02d}", x0, z0, x1, z1, y=3.8)

# ---- Фон: облака под карнизом, отроги, вершина горы над стеной, снегопад.
S.group("Backdrop")
S.inst("Clouds", "Backdrop", "res://scenes/environment/nm_cloud_sea.tscn", (0, -20, 0))
S.inst("RidgeWest", "Backdrop", "backdrop/ridge_mid_a", (-380, -30, -40), yaw=math.radians(90))
S.inst("RidgeNorthWest", "Backdrop", "backdrop/ridge_mid_b", (-300, -40, -330), yaw=math.radians(60))
S.inst("RidgeSouthWest", "Backdrop", "backdrop/ridge_mid_a", (-320, -30, 300), yaw=math.radians(120))
S.inst("RangeNorth", "Backdrop", "mountain/mountain_range_far", (200, -260, -2600))
S.inst("Snowfall", ".", "res://scenes/environment/nm_snowfall.tscn")

OUT.write_text(S.text(), encoding="utf-8")
print("wrote", OUT)
