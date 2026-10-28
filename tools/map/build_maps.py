"""Сборка карт: растровая основа (PNG) и данные Godot (.tres) из одной геометрии.

Запуск из корня проекта:  python tools/map/build_maps.py
Пишет:
  assets/ui/map/dream_realm.png, first_nightmare.png, city.png
  resources/map/world_map.tres, resources/map/regions/*.tres, resources/map/map_atlas.tres

География Царства снов: относительные положения из глав (см. docs/design/world_map_regions.md),
раскладка уточнена по фан-карте вики как ориентиру. Это схема, не официальная карта.
Карты локаций (resources/map/locations/*.tres) не трогаются: это данные для мини-карты
и источник геометрии, которую карта региона собирает по размещениям (MapPlacement).
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import paint as P  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSETS = os.path.join(ROOT, "assets", "ui", "map")
RES = os.path.join(ROOT, "resources", "map")

# Общая карта: растр Царства занимает левую часть области (REALM_FRACTION ширины),
# справа — колонка «За пределами Царства». Пропорция области — WORLD_ASPECT.
WORLD_W, WORLD_H = 1600, 1200
REALM_FRACTION = 0.80
WORLD_ASPECT = (WORLD_W / WORLD_H) / REALM_FRACTION

REGION_W, REGION_H = 1600, 1000

WALKABLE, BLOCKED, HAZARD, ROUTE, EDGE, UNAVAILABLE = range(6)
LANDMARK, CAMP, DANGER, QUEST = range(4)
ACTIVE, IN_DEV = 0, 1


def px(u, v):
    return (u * WORLD_W, v * WORLD_H)


# --- География Царства снов (нормализовано к растру Царства, 0..1) -----------

COAST = [(0.0, 0.80), (0.10, 0.83), (0.22, 0.86), (0.34, 0.885), (0.44, 0.90), (0.55, 0.92),
         (0.66, 0.945), (0.78, 0.955), (0.90, 0.965), (1.0, 0.97)]
SEA = COAST + [(1.0, 1.0), (0.0, 1.0)]

CRATER = dict(center=(0.30, 0.155), radius_px=128.0, labyrinth_px=64.0)

REALM_REGIONS = [
    dict(id="region_forgotten_shore", title="ЗАБЫТЫЙ БЕРЕГ", subtitle="Север · кратер",
         description="Огромный кратер к северу от Полых гор. В центре — Багровый шпиль в кольце Лабиринта, на восточном краю кратера — Тёмный город, на западном — Пепельный курган.",
         outline=[(0.02, 0.02), (0.60, 0.02), (0.62, 0.12), (0.60, 0.28), (0.40, 0.31), (0.20, 0.30), (0.02, 0.27)],
         label=(0.30, 0.285)),
    dict(id="region_nightmare_desert", title="ПУСТЫНЯ КОШМАРОВ", subtitle="Северо-восток",
         description="Выжженная пустыня белого песка к востоку от Забытого берега, вдоль Полых гор. По преданию — место великой битвы.",
         outline=[(0.60, 0.02), (0.99, 0.02), (0.99, 0.30), (0.80, 0.32), (0.60, 0.28), (0.62, 0.12)],
         label=(0.80, 0.10)),
    dict(id="region_hollow_mountains", title="ПОЛЫЕ ГОРЫ", subtitle="Зона смерти",
         description="Хребет длиной в тысячи километров. Отделяет Забытый берег от остального Царства и останавливает продвижение людей на север.",
         outline=[(0.02, 0.27), (0.20, 0.30), (0.40, 0.31), (0.60, 0.28), (0.80, 0.32), (0.99, 0.30),
                  (0.99, 0.45), (0.80, 0.46), (0.60, 0.44), (0.40, 0.46), (0.20, 0.45), (0.02, 0.44)],
         label=(0.50, 0.375)),
    dict(id="region_song_domain", title="ВЛАДЕНИЯ ПЕСНИ", subtitle="Великий клан Песни",
         description="Обширный анклав клана Песни на северо-западе от Бастиона. Столица Вороново Сердце стоит на склонах горного хребта у северной границы владений.",
         outline=[(0.02, 0.44), (0.20, 0.45), (0.38, 0.46), (0.40, 0.60), (0.37, 0.75), (0.34, 0.885),
                  (0.22, 0.86), (0.10, 0.83), (0.02, 0.80)],
         label=(0.19, 0.70)),
    dict(id="region_godgrave", title="МОГИЛА БОГА", subtitle="Цепь зон смерти",
         description="Цепь зон смерти между владениями Меча и Песни: узкая на севере, где лежат останки божества, и широкая на юге, у Штормового моря.",
         outline=[(0.38, 0.46), (0.60, 0.44), (0.60, 0.60), (0.62, 0.75), (0.66, 0.945), (0.55, 0.92),
                  (0.44, 0.90), (0.34, 0.885), (0.37, 0.75), (0.40, 0.60)],
         label=(0.50, 0.77)),
    dict(id="region_chained_isles", title="СКОВАННЫЕ ОСТРОВА", subtitle="Север владений Доблести",
         description="Парящие острова, связанные гигантскими железными цепями. Лежат у северного края земель клана Доблести, на границе с Полыми горами.",
         outline=[(0.60, 0.44), (0.80, 0.46), (0.99, 0.45), (0.99, 0.72), (0.80, 0.74), (0.62, 0.75), (0.60, 0.60)],
         label=(0.80, 0.53)),
    dict(id="region_sword_domain", title="ВЛАДЕНИЯ МЕЧА", subtitle="Великий клан Доблести",
         description="Земли клана Доблести. В их сердце — Бастион; на юге владения выходят к Штормовому морю.",
         outline=[(0.62, 0.75), (0.80, 0.74), (0.99, 0.72), (0.99, 0.97), (0.90, 0.965), (0.78, 0.955), (0.66, 0.945)],
         label=(0.82, 0.80)),
    dict(id="region_stormsea", title="ШТОРМОВОЕ МОРЕ", subtitle="Владения Дома Ночи",
         description="Море на юге Царства. С ним граничат и владения Меча, и владения Песни.",
         outline=SEA,
         label=(0.31, 0.945)),
]

REALM_LANDMARKS = [
    ("crimson_spire", "Багровый шпиль", "В центре Лабиринта, посреди кратера Забытого берега.", (0.30, 0.155), QUEST),
    ("dark_city", "Тёмный город", "Руины на восточном краю кратера; над городом стоит замок.", (0.30 + 128 / WORLD_W, 0.155), LANDMARK),
    ("ashen_barrow", "Пепельный курган", "Напротив Тёмного города, на западном краю кратера.", (0.30 - 128 / WORLD_W, 0.155), LANDMARK),
    ("black_skull", "Цитадель Чёрного Черепа", "Цитадель в Пустыне Кошмаров.", (0.77, 0.19), LANDMARK),
    ("tomb_of_ariel", "Гробница Ариэля", "Гробница в глубине пустыни.", (0.92, 0.17), DANGER),
    ("ravenheart", "Вороново Сердце", "Столица владений Песни на склонах хребта.", (0.17, 0.51), CAMP),
    ("moonriver", "Равнина Лунной Реки", "Равнина во владениях Песни.", (0.25, 0.64), LANDMARK),
    ("nameless_temple", "Безымянный храм", "Храм в зоне смерти Могилы Бога.", (0.495, 0.53), DANGER),
    ("night_temple", "Храм Ночи", "Храм на Скованных островах.", (0.68, 0.51), LANDMARK),
    ("tower_of_longing", "Башня Тоски", "Башня на Скованных островах.", (0.815, 0.60), LANDMARK),
    ("noctis", "Святилище Ноктиса", "Святилище на Скованных островах.", (0.735, 0.68), LANDMARK),
    ("bastion", "Бастион", "Цитадель в сердце владений Доблести.", (0.79, 0.86), CAMP),
]

GODGRAVE_BONES = dict(
    skull=(0.49, 0.475),
    spine=[(0.49, 0.49), (0.495, 0.55), (0.50, 0.61), (0.505, 0.67)],
)

RIVERS = [
    [(0.27, 0.46), (0.255, 0.55), (0.24, 0.64), (0.215, 0.74), (0.20, 0.845)],
    [(0.93, 0.73), (0.88, 0.80), (0.83, 0.87), (0.80, 0.955)],
]


# --- Первый Кошмар: размещение локаций на общей карте региона ----------------
# Центр области локации (world_bounds.get_center()) ставится в center (px растра),
# масштаб — pixels_per_meter, поворот — по часовой стрелке (градусы).

LOCATIONS = {
    "caravan_road": dict(label="КАРАВАННЫЙ ПЕРЕВАЛ", pivot=(-2.0, -4.0), center=(330, 640), ppm=3.0, rot=45.0,
                         label_offset=(-40, 150), points=dict(start=(0.0, 40.0), end=(0.0, -36.0))),
    "caravan_site": dict(label="СТОЯНКА КАРАВАНА", pivot=(0.0, 1.0), center=(650, 400), ppm=9.0, rot=0.0,
                         label_offset=(0, -105), points=dict(exit=(0.0, 9.5))),
    "pilgrim_path": dict(label="ТРОПА ПАЛОМНИКОВ", pivot=(0.0, -39.0), center=(1010, 470), ppm=2.6, rot=0.0,
                         label_offset=(150, 40), points=dict(start=(0.0, 10.0), temple=(1.0, -79.4))),
    "shadow_sanctuary": dict(label="ТЕНИСТОЕ СВЯТИЛИЩЕ", pivot=(0.0, 0.0), center=(1300, 210), ppm=7.0, rot=0.0,
                             label_offset=(0, -80), points=dict(entrance=(0.0, 7.5))),
}


def place(loc_id, world):
    loc = LOCATIONS[loc_id]
    x, z = world[0] - loc["pivot"][0], world[1] - loc["pivot"][1]
    a = math.radians(loc["rot"])
    rx = x * math.cos(a) - z * math.sin(a)
    rz = x * math.sin(a) + z * math.cos(a)
    return (loc["center"][0] + rx * loc["ppm"], loc["center"][1] + rz * loc["ppm"])


def trail(a, b, bend):
    """Тропа между локациями: дуга с прогибом bend (px) поперёк направления."""
    (x0, y0), (x1, y1) = a, b
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / length, dx / length
    return [a, (mx + nx * bend, my + ny * bend), b]


FN_TRAILS = [
    trail(place("caravan_road", LOCATIONS["caravan_road"]["points"]["end"]),
          place("caravan_site", LOCATIONS["caravan_site"]["points"]["exit"]), 40),
    trail(place("caravan_site", LOCATIONS["caravan_site"]["points"]["exit"]),
          place("pilgrim_path", LOCATIONS["pilgrim_path"]["points"]["start"]), -60),
    trail(place("pilgrim_path", LOCATIONS["pilgrim_path"]["points"]["temple"]),
          place("shadow_sanctuary", LOCATIONS["shadow_sanctuary"]["points"]["entrance"]), 30),
]

# Город: точки пролога (px растра города).
CITY_POINTS = [
    ("park", "Парк", "Скамейка в парке: кофе и утро пролога.", (360, 680), LANDMARK),
    ("street", "Улица", "Переход от парка к участку.", (720, 540), LANDMARK),
    ("station", "Участок", "Брифинг и Code Black.", (1060, 440), DANGER),
    ("isolator", "Изолятор", "Засыпание перед переходом в Царство.", (1250, 300), QUEST),
]
CITY_ROUTE = [p[3] for p in CITY_POINTS]


# --- Живопись -----------------------------------------------------------------

def bone_shape(H, W, rng):
    """Останки божества: череп, позвоночник, рёбра и кости рук, полузасыпанные."""
    sx, sy = px(*GODGRAVE_BONES["skull"])
    spine = P.smooth_curve([px(*p) for p in GODGRAVE_BONES["spine"]], 10)
    bones = P.line_mask(H, W, spine, 11, 2.5)
    skull = np.clip(1.0 - np.sqrt(P.ellipse_mask(H, W, sx, sy, 30, 24)), 0, 1) ** 0.35
    sockets = np.maximum(
        np.clip(1.0 - np.sqrt(P.ellipse_mask(H, W, sx - 10, sy - 2, 7, 6)), 0, 1),
        np.clip(1.0 - np.sqrt(P.ellipse_mask(H, W, sx + 10, sy - 2, 7, 6)), 0, 1),
    )
    rib_count = 9
    for i in range(rib_count):
        t = (i + 1) / (rib_count + 2)
        x0, y0 = spine[int(t * (len(spine) - 1))]
        length = 120 * math.sin(math.pi * (0.25 + 0.75 * t)) + 30
        for side in (-1, 1):
            curve = []
            for k in range(9):
                s = k / 8.0
                curve.append((x0 + side * length * math.sin(s * 1.5), y0 + 22 * s + 46 * s * s))
            bones = np.maximum(bones, P.line_mask(H, W, curve, 7 - i * 0.3, 1.6))
    for side in (-1, 1):
        shoulder = (spine[4][0] + side * 60, spine[4][1] - 6)
        elbow = (shoulder[0] + side * 110, shoulder[1] + 70)
        hand = (elbow[0] + side * 40, elbow[1] + 110)
        bones = np.maximum(bones, P.line_mask(H, W, [spine[4], shoulder, elbow, hand], 8, 2.0))
    bones = np.maximum(bones, skull)
    buried = np.clip((P.fbm(H, W, 18.0, 3, rng) - 0.3) * 3.0, 0, 1)
    return bones * buried, sockets


def paint_realm(path):
    H, W = WORLD_H, WORLD_W
    rng = np.random.default_rng(1729)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)

    def region_mask(rid, blur=36.0, warp_px=60.0, cell=180.0):
        reg = next(r for r in REALM_REGIONS if r["id"] == rid)
        m = P.polygon_mask(H, W, [px(*p) for p in reg["outline"]], blur)
        return np.clip(P.warp(m, warp_px, cell, rng), 0, 1)

    sea = np.clip(region_mask("region_stormsea", 4.0, 34.0, 120.0) * 1.6 - 0.3, 0, 1)
    land = 1.0 - sea
    fs = region_mask("region_forgotten_shore")
    nd = region_mask("region_nightmare_desert")
    hm = region_mask("region_hollow_mountains", 46.0, 70.0, 220.0)
    song = region_mask("region_song_domain")
    gg = region_mask("region_godgrave")
    ci = region_mask("region_chained_isles", 30.0, 70.0, 200.0)
    sw = region_mask("region_sword_domain")

    # Рельеф: пологие равнины, мощный хребет с предгорьями.
    base = P.fbm(H, W, 320.0, 6, rng)
    detail = P.fbm(H, W, 40.0, 4, rng)
    hills = P.ridged(H, W, 160.0, 6, rng)
    mountains = P.ridged(H, W, 85.0, 7, rng)
    peaks = np.clip(hm * 1.6 - 0.3, 0, 1)
    foothills = np.clip(hm * 2.0, 0, 1) - peaks
    height = base * 0.10 + detail * 0.025 + hills * 0.05 * (song + sw)
    height += peaks * (0.30 + mountains * 1.05) + foothills * hills * 0.32
    northern_song = np.clip(1.0 - (yy / H - 0.44) * 5.0, 0, 1)
    height += song * northern_song * mountains * 0.45

    # Забытый берег: кратер с Лабиринтом из алых кораллов в центре.
    cx, cy = px(*CRATER["center"])
    r = CRATER["radius_px"]
    e = np.sqrt(P.ellipse_mask(H, W, cx, cy, r, r * 0.92))
    e = P.warp(e, 9.0, 70.0, rng)
    rim = np.exp(-((e - 1.0) / 0.11) ** 2)
    basin = np.clip(1.0 - e, 0, 1)
    ash_dunes = P.ridged(H, W, 55.0, 4, rng)
    height += fs * (rim * 0.45 - basin * 0.42 + ash_dunes * 0.06)
    lab_e = e * r / CRATER["labyrinth_px"]
    walls = (P.ridged(H, W, 7.0, 2, rng) > 0.55).astype(np.float32)
    labyrinth = np.clip((1.0 - lab_e) * 4.0, 0, 1)
    height += labyrinth * walls * 0.05

    # Пустыня: мелкие изогнутые дюны.
    dune_warp = P.fbm(H, W, 90.0, 4, rng) * 120.0
    dunes = (np.sin((xx * 0.8 + yy * 0.5 + dune_warp) * 0.23) * 0.5 + 0.5) ** 2
    dunes *= np.clip(P.fbm(H, W, 70.0, 3, rng) * 1.6 - 0.3, 0, 1)
    height = height * (1.0 - nd) + nd * (base * 0.10 + dunes * 0.022)

    # Могила Бога: останки божества.
    bones, sockets = bone_shape(H, W, rng)
    bones *= np.clip(gg * 1.5, 0, 1)
    height += bones * 0.16 - gg * detail * 0.02

    # Скованные острова: парящие островки над бездной, цепи между ними.
    rng_i = np.random.default_rng(77)
    centers = []
    tries = 0
    while len(centers) < 16 and tries < 4000:
        tries += 1
        u, v = rng_i.uniform(0.62, 0.98), rng_i.uniform(0.47, 0.74)
        x, y = px(u, v)
        if ci[int(y), int(x)] < 0.7:
            continue
        if all(math.hypot(x - a, y - b) > 70 for a, b in centers):
            centers.append((x, y))
    islands = np.zeros((H, W), np.float32)
    for x, y in centers:
        rad = rng_i.uniform(20, 40)
        blob = np.clip(1.0 - np.sqrt(P.ellipse_mask(H, W, x, y, rad, rad * rng_i.uniform(0.6, 0.9))), 0, 1)
        islands = np.maximum(islands, blob)
    islands = np.clip(P.warp(islands, 12.0, 30.0, rng) * 4.0, 0, 1)
    abyss = np.clip(ci * 1.4 - 0.2, 0, 1) * (1.0 - islands)
    isle_height = 0.12 + hills * 0.25 + detail * 0.05
    height = height * (1.0 - abyss) * (1.0 - ci * islands) + ci * islands * isle_height - abyss * 0.05

    height = height * land

    # Цвет по биомам.
    grass = P.ramp(height + detail * 0.05, [(0.0, (60, 74, 46)), (0.12, (78, 92, 56)), (0.25, (104, 106, 72)), (0.5, (128, 122, 98))])
    rock = P.ramp(height, [(0.05, (88, 80, 66)), (0.35, (104, 96, 82)), (0.7, (132, 126, 116)),
                           (0.95, (200, 204, 210)), (1.3, (238, 240, 244))])
    ash = P.ramp(height + ash_dunes * 0.05, [(-0.3, (34, 30, 34)), (0.0, (82, 76, 72)), (0.15, (108, 100, 92)), (0.45, (136, 128, 118))])
    sand = P.ramp(height, [(0.0, (180, 154, 108)), (0.03, (206, 184, 136)), (0.07, (226, 210, 168))])
    dead = P.ramp(detail, [(0.3, (70, 62, 56)), (0.5, (90, 80, 70)), (0.7, (112, 102, 90))])
    patch = P.fbm(H, W, 26.0, 2, rng)
    fields = P.ramp(patch, [(0.35, (92, 104, 58)), (0.5, (150, 134, 78)), (0.62, (112, 116, 64)), (0.75, (162, 146, 90))])

    color = grass
    forest = np.clip((P.fbm(H, W, 90.0, 5, rng) - 0.48) * 6.0, 0, 1)
    canopy = P.fbm(H, W, 3.5, 2, rng)
    forest_col = P.ramp(canopy, [(0.3, (28, 42, 28)), (0.55, (42, 58, 36)), (0.75, (64, 80, 48))])
    color = P.mix(color, fields, sw * 0.7 * (1.0 - forest))
    color = P.mix(color, forest_col, forest * np.clip(song + sw * 0.7, 0, 1) * (1.0 - peaks))
    color = P.mix(color, rock, np.clip(hm * 1.5, 0, 1))
    color = P.mix(color, ash, fs)
    crater_sea = P.ramp(P.fbm(H, W, 16.0, 3, rng), [(0.3, (18, 16, 24)), (0.7, (36, 22, 30))])
    color = P.mix(color, crater_sea, fs * np.clip(basin * 5.0, 0, 1))
    coral = P.ramp(P.fbm(H, W, 5.0, 2, rng), [(0.3, (96, 22, 24)), (0.7, (150, 40, 36))])
    color = P.mix(color, coral, labyrinth * walls)
    city_shape = np.clip(1.0 - np.sqrt(P.ellipse_mask(H, W, cx + r * 0.98, cy, 30, 26)), 0, 1)
    city = (P.fbm(H, W, 2.5, 1, rng) > 0.5) * city_shape
    color = P.mix(color, P.tint((48, 46, 50)) * np.ones_like(color), np.clip(city_shape * 2.0, 0, 1) * 0.6)
    color = P.mix(color, P.tint((92, 88, 86)) * np.ones_like(color), city * 0.8)
    barrow = np.clip(1.0 - np.sqrt(P.ellipse_mask(H, W, cx - r * 0.98, cy, 30, 24)), 0, 1)
    height += barrow * 0.18
    color = P.mix(color, P.tint((150, 146, 140)) * np.ones_like(color), barrow * 0.6)
    color = P.mix(color, sand, nd)
    color = P.mix(color, dead, gg)
    color = P.mix(color, P.tint((198, 188, 166)) * np.ones_like(color), np.clip(bones * 1.2, 0, 1) * 0.85)
    color = P.mix(color, P.tint((20, 18, 16)) * np.ones_like(color), sockets * gg)
    void = P.ramp(P.fbm(H, W, 30.0, 5, rng), [(0.2, (8, 10, 16)), (0.55, (20, 24, 36)), (0.85, (52, 58, 74))])
    color = P.mix(color, void, abyss)
    isle_col = P.ramp(isle_height, [(0.1, (72, 84, 58)), (0.25, (98, 104, 74)), (0.4, (128, 124, 102))])
    color = P.mix(color, isle_col, ci * islands)

    chains = np.zeros((H, W), np.float32)
    for a in range(len(centers)):
        near = sorted(range(len(centers)), key=lambda k: math.hypot(centers[k][0] - centers[a][0],
                                                                    centers[k][1] - centers[a][1]))[1:3]
        for b in near:
            chains = np.maximum(chains, P.line_mask(H, W, [centers[a], centers[b]], 2, 0.5))
    color = P.mix(color, P.tint((118, 112, 104)) * np.ones_like(color), chains * abyss * 0.8)

    # Светотень; у островов — отбрасываемая в бездну тень.
    shade = P.hillshade(height, scale=420.0)
    ambient = np.clip(1.0 - P.ridged(H, W, 220.0, 3, rng) * 0.25, 0.75, 1.0)
    lit = 0.40 + 0.80 * shade
    lit = lit * (1.0 - abyss) + abyss * 1.0
    color = color * (lit * ambient)[..., None] * land[..., None] + color * sea[..., None]
    isle_shadow = np.roll(np.roll(islands, 10, axis=0), 8, axis=1) * (1.0 - islands) * abyss
    color = color * (1.0 - isle_shadow[..., None] * 0.6)

    # Реки.
    for index, river in enumerate(RIVERS):
        curve = P.meander(P.smooth_curve([px(*p) for p in river], 24), 14.0, 9 + index)
        wide = P.line_mask(H, W, curve, 7, 1.0)
        core = P.line_mask(H, W, curve, 3, 0.6)
        color = P.mix(color, P.tint((30, 44, 46)) * np.ones_like(color), wide * land)
        color = P.mix(color, P.tint((64, 104, 112)) * np.ones_like(color), core * land)

    # Море: глубина по расстоянию до берега, светлая кромка прибоя.
    dist = P.distance_to(land > 0.5)
    deep = P.ramp(np.clip(dist / 90.0, 0, 1), [(0.0, (60, 96, 100)), (0.25, (34, 62, 74)), (1.0, (16, 32, 44))])
    waves = P.fbm(H, W, 12.0, 3, rng)
    deep = deep * (0.88 + waves[..., None] * 0.22)
    color = P.mix(color, deep, sea)
    foam = np.exp(-(dist / 2.5) ** 2) * sea
    color = P.mix(color, P.tint((170, 180, 168)) * np.ones_like(color), foam * 0.55)

    # Неизведанное: «никто не знает, что на западе и севере» — туман у краёв.
    edge = np.minimum(xx, yy)
    mist = np.clip(1.0 - edge / 70.0, 0, 1) ** 1.5 * (0.6 + P.fbm(H, W, 40.0, 3, rng) * 0.6)
    color = P.mix(color, P.tint((30, 32, 36)) * np.ones_like(color), mist)

    color = P.finish(color, rng, grain=0.07, vignette=0.30, desaturate=0.18)
    P.save(color, path)


def paint_first_nightmare(path):
    H, W = REGION_H, REGION_W
    rng = np.random.default_rng(31337)
    corridor = np.zeros((H, W), np.float32)
    for loc_id, loc in LOCATIONS.items():
        cx, cy = loc["center"]
        span = {"caravan_road": 150, "caravan_site": 110, "pilgrim_path": 150, "shadow_sanctuary": 95}[loc_id]
        blob = np.clip(1.0 - np.sqrt(P.ellipse_mask(H, W, cx, cy, span, span * 1.1)), 0, 1)
        corridor = np.maximum(corridor, blob ** 0.6)
    road = [place("caravan_road", (0.0, 40.0)), place("caravan_road", (0.0, -36.0))]
    corridor = np.maximum(corridor, P.line_mask(H, W, road, 70, 18))
    for t in FN_TRAILS:
        corridor = np.maximum(corridor, P.line_mask(H, W, P.smooth_curve(t), 60, 20))
    corridor = P.warp(corridor, 30.0, 120.0, rng)
    corridor = ndimage_blur(corridor, 6.0)
    # Крутые стенки долины: плавный порог вместо широкого размытого склона.
    corridor = np.clip((corridor - 0.25) / 0.2, 0, 1)
    corridor = corridor * corridor * (3.0 - 2.0 * corridor)

    # Пропасть к западу от дороги перевала (в сцене — долина на 45 м ниже).
    west = [place("caravan_road", (-16.0, 46.0)), place("caravan_road", (-16.0, -46.0))]
    gorge = np.clip(P.warp(P.line_mask(H, W, west, 46, 10), 10.0, 40.0, rng), 0, 1)

    # Горы: крупные хребты с деталями поменьше, без сплошной ряби.
    range_shape = P.fbm(H, W, 420.0, 3, rng)
    ridges = P.ridged(H, W, 150.0, 6, rng)
    fine = P.ridged(H, W, 38.0, 3, rng)
    height = 0.25 + range_shape * 0.35 + ridges * 0.85 + fine * 0.10
    valley = 0.18 + P.fbm(H, W, 80.0, 3, rng) * 0.04 + fine * 0.025
    height = height * (1.0 - corridor) + valley * corridor
    height = height * (1.0 - gorge) - gorge * 0.6

    rock = P.ramp(height, [(-0.6, (8, 9, 12)), (0.0, (34, 36, 40)), (0.12, (96, 100, 106)), (0.18, (176, 182, 190)),
                           (0.3, (128, 128, 126)), (0.45, (92, 90, 86)), (0.75, (122, 120, 116)),
                           (0.95, (206, 210, 216)), (1.3, (240, 242, 246))])
    snow_floor = P.ramp(P.fbm(H, W, 30.0, 3, rng), [(0.3, (178, 184, 192)), (0.7, (208, 212, 218))])
    color = P.mix(rock, snow_floor, np.clip(corridor * 1.8, 0, 1) * (1.0 - gorge))
    for t in FN_TRAILS:
        curve = P.smooth_curve(t, 20)
        color = P.mix(color, P.tint((112, 100, 84)) * np.ones_like(color), P.line_mask(H, W, curve, 7, 1.5) * 0.6)
    shade = P.hillshade(height, scale=320.0)
    color = color * (0.40 + 0.80 * shade[..., None])
    fog = np.clip(P.fbm(H, W, 160.0, 4, rng) - 0.5, 0, 1) * 1.6 * (1.0 - corridor)
    color = P.mix(color, P.tint((214, 220, 228)) * np.ones_like(color), fog * 0.30)
    color = P.finish(color, rng, grain=0.05, vignette=0.45, desaturate=0.08)
    P.save(color, path)


def ndimage_blur(field, sigma):
    from scipy import ndimage
    return ndimage.gaussian_filter(field, sigma)


def paint_city(path):
    H, W = REGION_H, REGION_W
    rng = np.random.default_rng(2024)
    color = np.ones((H, W, 3), np.float32) * P.tint((52, 54, 58))
    asphalt = P.fbm(H, W, 6.0, 2, rng)
    color = color * (0.85 + asphalt[..., None] * 0.25)

    park = P.polygon_mask(H, W, [(150, 560), (520, 560), (560, 800), (300, 900), (120, 820)], 6)
    park = np.clip(P.warp(park, 12.0, 40.0, rng), 0, 1)
    trees = P.fbm(H, W, 7.0, 3, rng)
    park_col = P.ramp(trees, [(0.3, (40, 60, 38)), (0.55, (56, 80, 48)), (0.75, (84, 104, 64))])

    # Кварталы с неровной сеткой улиц; каждый квартал делится на здания разной высоты.
    block = np.zeros((H, W), np.float32)
    roof = np.zeros((H, W, 3), np.float32)
    rng_b = np.random.default_rng(5)
    xs = [0]
    while xs[-1] < W:
        xs.append(xs[-1] + int(rng_b.integers(110, 190)))
    ys = [0]
    while ys[-1] < H:
        ys.append(ys[-1] + int(rng_b.integers(90, 150)))
    for j in range(len(ys) - 1):
        for i in range(len(xs) - 1):
            street = 14 if (i % 3 and j % 3) else 26
            x0, x1 = xs[i] + street // 2, xs[i + 1] - street // 2
            y0, y1 = ys[j] + street // 2, ys[j + 1] - street // 2
            cuts_x = sorted(set([x0, x1] + list(rng_b.integers(x0 + 20, max(x0 + 21, x1 - 20), 2))))
            cuts_y = sorted(set([y0, y1] + list(rng_b.integers(y0 + 20, max(y0 + 21, y1 - 20), 1))))
            for a in range(len(cuts_x) - 1):
                for b in range(len(cuts_y) - 1):
                    bx0, bx1 = cuts_x[a] + 2, cuts_x[a + 1] - 2
                    by0, by1 = cuts_y[b] + 2, cuts_y[b + 1] - 2
                    if bx1 - bx0 < 8 or by1 - by0 < 8:
                        continue
                    level = rng_b.uniform(0.3, 1.0)
                    tone = np.array([0.30, 0.31, 0.34]) * (0.7 + level * 0.5) + rng_b.uniform(-0.03, 0.03)
                    block[by0:by1, bx0:bx1] = level
                    roof[by0:by1, bx0:bx1] = tone
                    roof[by0:by0 + 3, bx0:bx1] = tone * 1.25
                    roof[by0:by1, bx0:bx0 + 3] = tone * 1.18
    route = P.smooth_curve(CITY_ROUTE, 20)
    avenue = P.line_mask(H, W, route, 40, 2.0)
    station = np.clip(1.0 - np.sqrt(P.ellipse_mask(H, W, 1120, 380, 140, 90)), 0, 1) > 0.0
    built = (block > 0).astype(np.float32) * (1.0 - park) * (1.0 - avenue)
    # Тени зданий к юго-востоку.
    shadow = np.roll(np.roll(block, 7, axis=0), 7, axis=1) * (1.0 - built)
    color = color * (1.0 - shadow[..., None] * 0.45)
    color = P.mix(color, roof, built)
    color = P.mix(color, P.tint((84, 88, 96)) * np.ones_like(color), station * built * 0.6)
    color = P.mix(color, park_col, park)
    paths = P.line_mask(H, W, P.smooth_curve([(180, 600), (330, 690), (470, 640), (520, 760)], 10), 5, 1.0)
    color = P.mix(color, P.tint((150, 140, 118)) * np.ones_like(color), paths * park)
    color = P.mix(color, P.tint((34, 34, 38)) * np.ones_like(color), avenue)
    lane = P.line_mask(H, W, route, 2, 0.5)
    color = P.mix(color, P.tint((190, 176, 120)) * np.ones_like(color), lane * 0.7)
    height = park * trees * 0.08
    shade = P.hillshade(height, scale=900.0)
    color = color * (0.70 + 0.45 * shade[..., None])
    color = P.finish(color, rng, grain=0.05, vignette=0.45, desaturate=0.15)
    P.save(color, path)


# --- Данные Godot -------------------------------------------------------------

def f(v):
    s = ("%.4f" % v).rstrip("0").rstrip(".")
    return s if s not in ("", "-0") else "0"


def pts(points):
    return "PackedVector2Array(%s)" % ", ".join("%s, %s" % (f(x), f(y)) for x, y in points)


HEADER = """[gd_resource type="Resource" script_class="{cls}" format=3]

[ext_resource type="Script" path="res://scripts/map/map_marker.gd" id="1_marker"]
[ext_resource type="Script" path="res://scripts/map/map_definition.gd" id="2_def"]
[ext_resource type="Script" path="res://scripts/map/map_feature.gd" id="3_feature"]
[ext_resource type="Script" path="res://scripts/map/map_region.gd" id="4_region"]
[ext_resource type="Script" path="res://scripts/map/map_placement.gd" id="5_placement"]
"""


def map_block(name, m, as_root=False):
    """MapDefinition: sub_resource name (или корень файла)."""
    out = []
    feat_ids, mark_ids, place_ids = [], [], []
    for i, (kind, points, closed) in enumerate(m.get("features", [])):
        sid = "%s_F%d" % (name, i)
        feat_ids.append(sid)
        out += ['[sub_resource type="Resource" id="%s"]' % sid, 'script = ExtResource("3_feature")',
                "kind = %d" % kind, "points = %s" % pts(points),
                "closed = %s" % ("true" if closed else "false"), ""]
    for i, (mid, label, desc, (x, y), kind) in enumerate(m.get("markers", [])):
        sid = "%s_M%d" % (name, i)
        mark_ids.append(sid)
        out += ['[sub_resource type="Resource" id="%s"]' % sid, 'script = ExtResource("1_marker")',
                'id = &"%s"' % mid, 'label = "%s"' % label, 'description = "%s"' % desc,
                "use_world_position = true", "world_position = Vector2(%s, %s)" % (f(x), f(y)),
                "kind = %d" % kind, ""]
    for i, (loc_id, loc) in enumerate(m.get("placements", {}).items()):
        sid = "%s_P%d" % (name, i)
        place_ids.append(sid)
        out += ['[sub_resource type="Resource" id="%s"]' % sid, 'script = ExtResource("5_placement")',
                'location_id = &"%s"' % loc_id, 'label = "%s"' % loc["label"],
                "center = Vector2(%s, %s)" % (f(loc["center"][0]), f(loc["center"][1])),
                "pixels_per_meter = %s" % f(loc["ppm"]), "rotation_degrees = %s" % f(loc["rot"]),
                "label_offset = Vector2(%s, %s)" % (f(loc["label_offset"][0]), f(loc["label_offset"][1])), ""]
    texture_line = []
    if m.get("texture"):
        texture_line = ['background_texture = ExtResource("%s")' % m["texture"]]
    out += ["[resource]" if as_root else '[sub_resource type="Resource" id="%s"]' % name,
            'script = ExtResource("2_def")', 'id = &"%s"' % m["id"], 'title = "%s"' % m["title"],
            'subtitle = "%s"' % m["subtitle"], 'description = "%s"' % m["description"],
            "background_color = Color(%s)" % m["bg"], "land_color = Color(%s)" % m["land"],
            "accent_color = Color(%s)" % m["accent"], 'terrain_style = &"%s"' % m["style"],
            "world_bounds = Rect2(%s)" % ", ".join(f(v) for v in m["bounds"])]
    out += texture_line
    if "background_rect" in m:
        out.append("background_rect = Rect2(%s)" % ", ".join(f(v) for v in m["background_rect"]))
    out += ['features = Array[ExtResource("3_feature")]([%s])' % ", ".join('SubResource("%s")' % s for s in feat_ids),
            'markers = Array[ExtResource("1_marker")]([%s])' % ", ".join('SubResource("%s")' % s for s in mark_ids),
            'placements = Array[ExtResource("5_placement")]([%s])' % ", ".join('SubResource("%s")' % s for s in place_ids),
            "scene_paths = PackedStringArray()", ""]
    return out


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


def realm_to_area(u, v):
    return (u * REALM_FRACTION, v)


def write_world():
    markers = [(mid, label, desc, realm_to_area(*uv), kind) for mid, label, desc, uv, kind in REALM_LANDMARKS]
    m = dict(id="world", title="ЦАРСТВО СНОВ", subtitle="Общая карта мира · схема",
             description="Царство снов — весь мир истории. Расположение регионов — схема по описаниям из глав; регионы без карты пока в разработке.",
             bg="0.03, 0.04, 0.05, 1", land="0.2, 0.2, 0.17, 1", accent="0.78, 0.63, 0.38, 1", style="kingdom",
             bounds=(0, 0, 1, 1), texture="6_tex", background_rect=(0, 0, REALM_FRACTION, 1), markers=markers)
    text = HEADER.format(cls="MapDefinition")
    text += '[ext_resource type="Texture2D" path="res://assets/ui/map/dream_realm.png" id="6_tex"]\n\n'
    text += "\n".join(map_block("World", m, as_root=True))
    write(os.path.join(RES, "world_map.tres"), text)


OUTSIDE = [
    dict(id="region_first_nightmare", title="ПЕРВЫЙ КОШМАР", subtitle="Испытание Заклятия",
         description="Кошмар — отдельное испытание Заклятия, а не часть карты Царства. Перевал, стоянка, тропа паломников и святилище на одной карте.",
         rect=(0.815, 0.12, 0.175, 0.32), texture="first_nightmare.png",
         locations=["caravan_road", "caravan_site", "pilgrim_path", "shadow_sanctuary"],
         map=dict(id="region_first_nightmare_map", title="ПЕРВЫЙ КОШМАР", subtitle="Горный перевал и храм",
                  description="Все локации маршрута на одной карте. Внутри каждой — реальная геометрия уровня; расстояния между локациями условные.",
                  bg="0.03, 0.035, 0.04, 1", land="0.55, 0.56, 0.58, 1", accent="0.78, 0.63, 0.38, 1", style="snow",
                  bounds=(0, 0, REGION_W, REGION_H), placements=LOCATIONS,
                  features=[(ROUTE, [tuple(p) for p in P.smooth_curve(t, 6)], False) for t in FN_TRAILS])),
    dict(id="region_city", title="ГОРОД", subtitle="Реальный мир · пролог",
         description="Город из пролога, за пределами Царства снов. Схема мест пролога: парк, улица, участок, изолятор.",
         rect=(0.815, 0.56, 0.175, 0.32), texture="city.png", locations=[],
         map=dict(id="region_city_map", title="ГОРОД", subtitle="Реальный мир · пролог",
                  description="Места пролога в порядке сюжета. Схема; локальные карты городских сцен ещё не созданы.",
                  bg="0.03, 0.035, 0.04, 1", land="0.3, 0.3, 0.32, 1", accent="0.6, 0.66, 0.7, 1", style="city",
                  bounds=(0, 0, REGION_W, REGION_H),
                  features=[(ROUTE, [tuple(p) for p in P.smooth_curve(CITY_ROUTE, 6)], False)],
                  markers=[(mid, label, desc, xy, kind) for mid, label, desc, xy, kind in CITY_POINTS])),
]


def write_region(reg, outside):
    text = HEADER.format(cls="MapRegion")
    body = []
    if outside:
        text += '[ext_resource type="Texture2D" path="res://assets/ui/map/%s" id="6_tex"]\n' % reg["texture"]
        reg["map"]["texture"] = "6_tex"
        body = map_block("RegionMap", reg["map"])
        x, y, w, h = reg["rect"]
        outline = [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]
        label = (x + w / 2, y + h + 0.045)
    else:
        outline = [realm_to_area(*p) for p in reg["outline"]]
        label = realm_to_area(*reg["label"])
    text += "\n" + "\n".join(body)
    lines = ["[resource]", 'script = ExtResource("4_region")', 'id = &"%s"' % reg["id"],
             'title = "%s"' % reg["title"], 'subtitle = "%s"' % reg["subtitle"],
             'description = "%s"' % reg["description"],
             "status = %d" % (ACTIVE if outside else IN_DEV),
             "outside_realm = %s" % ("true" if outside else "false"),
             "outline = %s" % pts(outline),
             "label_position = Vector2(%s, %s)" % (f(label[0]), f(label[1])),
             "location_ids = Array[StringName]([%s])" % ", ".join('&"%s"' % l for l in reg.get("locations", []))]
    if outside:
        lines.append('region_map = SubResource("RegionMap")')
    text += "\n".join(lines) + "\n"
    write(os.path.join(RES, "regions", reg["id"] + ".tres"), text)


def write_atlas(region_ids):
    locs = ["forgotten_shore", "caravan_road", "caravan_site", "ambush_site", "pilgrim_path",
            "shadow_sanctuary", "drowned_city"]
    out = ['[gd_resource type="Resource" script_class="MapAtlas" format=3]', "",
           '[ext_resource type="Script" path="res://scripts/map/map_atlas.gd" id="1_atlas"]',
           '[ext_resource type="Resource" path="res://resources/map/world_map.tres" id="2_world"]',
           '[ext_resource type="Script" path="res://scripts/map/map_region.gd" id="3_region"]',
           '[ext_resource type="Script" path="res://scripts/map/map_definition.gd" id="4_def"]']
    for i, rid in enumerate(region_ids):
        out.append('[ext_resource type="Resource" path="res://resources/map/regions/%s.tres" id="r%d"]' % (rid, i))
    for i, loc in enumerate(locs):
        out.append('[ext_resource type="Resource" path="res://resources/map/locations/%s.tres" id="l%d"]' % (loc, i))
    out += ["", "[resource]", 'script = ExtResource("1_atlas")', 'world_map = ExtResource("2_world")',
            'regions = Array[ExtResource("3_region")]([%s])' % ", ".join('ExtResource("r%d")' % i for i in range(len(region_ids))),
            'locations = Array[ExtResource("4_def")]([%s])' % ", ".join('ExtResource("l%d")' % i for i in range(len(locs)))]
    write(os.path.join(RES, "map_atlas.tres"), "\n".join(out) + "\n")


def main():
    os.makedirs(ASSETS, exist_ok=True)
    os.makedirs(os.path.join(RES, "regions"), exist_ok=True)
    only = set(sys.argv[1:])
    if not only or "paint" in only:
        paint_realm(os.path.join(ASSETS, "dream_realm.png"))
        paint_first_nightmare(os.path.join(ASSETS, "first_nightmare.png"))
        paint_city(os.path.join(ASSETS, "city.png"))
    if not only or "data" in only:
        for name in os.listdir(os.path.join(RES, "regions")):
            if name.endswith(".tres"):
                os.remove(os.path.join(RES, "regions", name))
        write_world()
        for reg in REALM_REGIONS:
            write_region(reg, outside=False)
        for reg in OUTSIDE:
            write_region(reg, outside=True)
        write_atlas([r["id"] for r in OUTSIDE] + [r["id"] for r in REALM_REGIONS])
    print("ok; world aspect = %.4f, realm fraction = %.2f" % (WORLD_ASPECT, REALM_FRACTION))


if __name__ == "__main__":
    main()
