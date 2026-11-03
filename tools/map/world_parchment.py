"""Рисованная карта Царства снов в стиле пергаментной карты.

Модуль хранит и геометрию регионов (её использует build_maps.py для .tres), и
саму живопись. Стиль: старая бумага, акварельные заливки, тушь, ручные горы,
леса и подписи. Внешних картинок нет — только детерминированный шум и
векторные глифы, поэтому карта воспроизводима и лицензионно чиста.

Запуск отдельно из корня проекта:  python tools/map/world_parchment.py
"""
import math
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

import paint as P

W, H = 1600, 1200
S = 2                     # суперсэмплинг линий и текста
W2, H2 = W * S, H * S

# --- Палитра -----------------------------------------------------------------
PAPER_RGB = (224, 204, 166)
PAPER_LIGHT = (236, 224, 196)
INK = (54, 39, 24)
INK_SOFT = (104, 80, 52)
INK_RED = (94, 36, 28)
SEA_INK = (37, 61, 70)
GOLD = (150, 116, 58)
CREAM = (238, 226, 200)
DARK_PANEL = (22, 23, 20)

FONT_FILES = {
    (False, False): ["georgia.ttf", "DejaVuSerif.ttf", "times.ttf"],
    (True, False): ["georgiab.ttf", "DejaVuSerif-Bold.ttf", "timesbd.ttf"],
    (False, True): ["georgiai.ttf", "DejaVuSerif-Italic.ttf", "timesi.ttf"],
    (True, True): ["georgiaz.ttf", "DejaVuSerif-BoldItalic.ttf", "timesbi.ttf"],
}
FONT_DIRS = [
    os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts"),
    "/usr/share/fonts/truetype/msttcorefonts",
    "/usr/share/fonts/truetype/dejavu",
    "/usr/share/fonts/TTF",
]

# --- География ---------------------------------------------------------------
# Контуры заданы в долях растра (0..1). Данные Godot получают те же точки,
# умноженные на REALM_FRACTION из build_maps.py.

COAST = [
    (0.055, 0.035), (0.10, 0.018), (0.16, 0.022), (0.22, 0.012), (0.29, 0.020),
    (0.36, 0.012), (0.43, 0.022), (0.50, 0.014), (0.57, 0.022), (0.64, 0.034),
    (0.700, 0.050), (0.760, 0.038), (0.820, 0.025), (0.880, 0.022), (0.930, 0.030),
    (0.970, 0.045), (0.992, 0.070), (0.995, 0.150), (0.993, 0.250), (0.995, 0.360),
    (0.990, 0.452),
    (0.952, 0.468), (0.900, 0.492), (0.855, 0.478), (0.800, 0.462), (0.744, 0.478),
    (0.724, 0.530), (0.716, 0.585), (0.727, 0.640), (0.710, 0.700), (0.702, 0.748),
    (0.735, 0.780), (0.790, 0.770), (0.845, 0.758), (0.900, 0.768), (0.952, 0.752),
    (0.985, 0.782), (0.996, 0.840), (0.992, 0.900), (0.975, 0.955), (0.952, 1.000),
    (0.540, 1.000), (0.520, 0.962), (0.500, 0.918), (0.474, 0.902), (0.446, 0.916),
    (0.418, 0.902), (0.388, 0.918), (0.356, 0.900), (0.330, 0.888), (0.302, 0.896),
    (0.274, 0.884), (0.244, 0.858), (0.214, 0.838), (0.184, 0.812), (0.152, 0.782),
    (0.122, 0.742), (0.102, 0.696), (0.086, 0.648), (0.072, 0.600), (0.062, 0.552),
    (0.044, 0.506), (0.036, 0.458), (0.050, 0.412), (0.038, 0.366), (0.046, 0.318),
    (0.034, 0.272), (0.044, 0.226), (0.036, 0.180), (0.046, 0.136), (0.040, 0.090),
]

BAY = [
    (0.990, 0.452), (0.952, 0.468), (0.900, 0.492), (0.855, 0.478), (0.800, 0.462),
    (0.744, 0.478), (0.724, 0.530), (0.716, 0.585), (0.727, 0.640), (0.710, 0.700),
    (0.702, 0.748), (0.735, 0.780), (0.790, 0.770), (0.845, 0.758), (0.900, 0.768),
    (0.952, 0.752), (0.985, 0.782), (0.996, 0.840), (0.996, 0.452),
]

REGIONS = [
    dict(
        id="region_frozen_wastes", title="ЛЕДЯНЫЕ ПУСТОШИ",
        subtitle="Край мира · вечный лёд",
        description=(
            "Ледяные пустоши на самом севере, за морем. Бескрайняя Бель, "
            "ледник Тернвалл, Северный Форпост и Ледяная Цитадель."
        ),
        outline=[
            (0.042, 0.052), (0.10, 0.020), (0.16, 0.024), (0.22, 0.014),
            (0.29, 0.022), (0.36, 0.014), (0.43, 0.024), (0.50, 0.016),
            (0.57, 0.024), (0.64, 0.036), (0.70, 0.052), (0.755, 0.074),
            (0.785, 0.114), (0.792, 0.165), (0.778, 0.218), (0.748, 0.250),
            (0.700, 0.262), (0.660, 0.282), (0.600, 0.292), (0.540, 0.300),
            (0.470, 0.298), (0.400, 0.286), (0.330, 0.274), (0.260, 0.268),
            (0.195, 0.276), (0.140, 0.258), (0.098, 0.226), (0.070, 0.180),
            (0.054, 0.130), (0.046, 0.086),
        ],
        color=(198, 216, 212), opacity=0.62,
        label=(0.470, 0.135), label_size=30,
        title_fill=(44, 66, 72), title_stroke=(232, 224, 200),
    ),
    dict(
        id="region_burned_forest", title="ВЫЖЖЕННЫЙ ЛЕС",
        subtitle="Пепел · чёрные стволы",
        description=(
            "Огромный выжженный лес к югу от Ледяных пустошей. Пепельный полог, "
            "Эмберхолд, Выжженный бастион и Чёрная дорога."
        ),
        outline=[
            (0.098, 0.226), (0.140, 0.258), (0.195, 0.276), (0.260, 0.268),
            (0.330, 0.274), (0.400, 0.286), (0.470, 0.298), (0.540, 0.300),
            (0.600, 0.292), (0.660, 0.282), (0.700, 0.262), (0.748, 0.250),
            (0.770, 0.300), (0.762, 0.352), (0.734, 0.402), (0.690, 0.428),
            (0.630, 0.440), (0.560, 0.448), (0.490, 0.442), (0.420, 0.438),
            (0.350, 0.446), (0.282, 0.438), (0.220, 0.424), (0.166, 0.398),
            (0.124, 0.356), (0.100, 0.306),
        ],
        color=(48, 46, 40), opacity=0.86,
        label=(0.430, 0.345), label_size=30,
        title_fill=(230, 218, 191), title_stroke=(38, 33, 26),
    ),
    dict(
        id="region_nightmare_desert", title="ПУСТЫНЯ КОШМАРОВ",
        subtitle="Северо-восток · белый песок",
        description=(
            "Выжженная пустыня белого песка к востоку от Забытого берега. "
            "Гробница Ариэля, Дюны Безмолвия и Забытый Обелиск."
        ),
        outline=[
            (0.748, 0.250), (0.778, 0.218), (0.792, 0.165), (0.785, 0.112),
            (0.800, 0.090), (0.850, 0.058), (0.905, 0.040), (0.955, 0.035),
            (0.990, 0.055), (0.995, 0.150), (0.993, 0.260), (0.995, 0.380),
            (0.990, 0.452), (0.952, 0.468), (0.900, 0.492), (0.855, 0.478),
            (0.800, 0.462), (0.760, 0.448), (0.770, 0.400), (0.762, 0.352),
            (0.770, 0.300),
        ],
        color=(214, 184, 126), opacity=0.72,
        label=(0.830, 0.236), label_size=27,
        title_fill=(84, 58, 26), title_stroke=(238, 226, 198),
    ),
    dict(
        id="region_forgotten_shore", title="ЗАБЫТЫЙ БЕРЕГ",
        subtitle="Кратер · Лабиринт",
        description=(
            "Кратер к северу от Полых гор. В центре — Багровый шпиль в кольце "
            "Лабиринта, на восточном краю — Тёмный город, в глубине кратера — "
            "Безымянный остров."
        ),
        outline=[
            (0.124, 0.356), (0.166, 0.398), (0.220, 0.424), (0.282, 0.438),
            (0.350, 0.446), (0.420, 0.438), (0.490, 0.442), (0.560, 0.448),
            (0.630, 0.440), (0.690, 0.428), (0.734, 0.402), (0.760, 0.438),
            (0.762, 0.482), (0.738, 0.520), (0.690, 0.548), (0.630, 0.564),
            (0.560, 0.576), (0.490, 0.580), (0.420, 0.572), (0.350, 0.560),
            (0.282, 0.540), (0.220, 0.514), (0.166, 0.482), (0.132, 0.438),
        ],
        color=(128, 36, 40), opacity=0.82,
        label=(0.440, 0.452), label_size=29,        title_fill=(252, 228, 208), title_stroke=(72, 18, 18),
    ),
    dict(
        id="region_hollow_mountains", title="ПОЛЫЕ ГОРЫ",
        subtitle="Зона смерти · северная стена",
        description=(
            "Хребет длиной в тысячи километров — северная граница земель людей. "
            "Отделяет Забытый берег от остального Царства."
        ),
        outline=[
            (0.062, 0.552), (0.126, 0.520), (0.200, 0.548), (0.290, 0.578),
            (0.380, 0.596), (0.470, 0.604), (0.560, 0.596), (0.640, 0.578),
            (0.712, 0.552), (0.744, 0.576), (0.720, 0.606), (0.650, 0.626),
            (0.570, 0.642), (0.480, 0.650), (0.390, 0.646), (0.300, 0.632),
            (0.220, 0.612), (0.150, 0.590), (0.082, 0.580),
        ],
        color=(84, 82, 74), opacity=0.72,
        label=(0.300, 0.605), label_size=20,
        title_fill=(240, 230, 206), title_stroke=(48, 40, 32),
    ),
    dict(
        id="region_song_domain", title="СЕРЫЕ ГОРЫ",
        subtitle="Владения Песни",
        description=(
            "Серые горы на западе и земли Великого клана Песни. Вороново Сердце "
            "стоит на склонах хребта, у северной границы владений."
        ),
        outline=[
            (0.052, 0.556), (0.110, 0.516), (0.180, 0.552), (0.270, 0.584),
            (0.340, 0.612), (0.368, 0.660), (0.360, 0.724), (0.340, 0.786),
            (0.300, 0.842), (0.250, 0.878), (0.192, 0.898), (0.140, 0.872),
            (0.102, 0.824), (0.078, 0.760), (0.062, 0.692), (0.050, 0.622),
        ],
        color=(86, 94, 76), opacity=0.70,
        label=(0.150, 0.655), label_size=27,
        title_fill=(48, 48, 36), title_stroke=(234, 224, 200),
    ),
    dict(
        id="region_godgrave", title="МОГИЛА БОГА",
        subtitle="Цепь зон смерти",
        description=(
            "Цепь зон смерти между владениями: останки павшего божества, "
            "Поле костей, Безмолвные стражи и Стеклянные пики."
        ),
        outline=[
            (0.340, 0.612), (0.390, 0.646), (0.480, 0.650), (0.570, 0.642),
            (0.650, 0.626), (0.706, 0.604), (0.724, 0.646), (0.718, 0.706),
            (0.694, 0.768), (0.664, 0.828), (0.622, 0.874), (0.560, 0.896),
            (0.492, 0.892), (0.426, 0.872), (0.380, 0.830), (0.360, 0.772),
            (0.354, 0.706), (0.368, 0.660),
        ],
        color=(104, 92, 86), opacity=0.66,
        label=(0.500, 0.900), label_size=28,
        title_fill=(50, 40, 36), title_stroke=(232, 222, 198),
    ),
    dict(
        id="region_chained_isles", title="СКОВАННЫЕ ОСТРОВА",
        subtitle="Парящие острова · цепи",
        description=(
            "Парящие острова, связанные гигантскими железными цепями. "
            "Храм Ночи, Железная тюрьма, Святилище Ночи и Разбитые острова."
        ),
        outline=[
            (0.720, 0.462), (0.800, 0.462), (0.855, 0.478), (0.900, 0.492),
            (0.952, 0.468), (0.990, 0.452), (0.995, 0.560), (0.992, 0.660),
            (0.988, 0.748), (0.952, 0.752), (0.900, 0.768), (0.845, 0.758),
            (0.790, 0.770), (0.735, 0.780), (0.702, 0.748), (0.710, 0.700),
            (0.727, 0.640), (0.716, 0.585), (0.724, 0.530),
        ],
        color=(34, 54, 50), opacity=0.78,
        label=(0.850, 0.545), label_size=26,
        title_fill=(236, 226, 198), title_stroke=(28, 34, 30),
    ),
    dict(
        id="region_stormsea", title="ШТОРМОВОЕ МОРЕ",
        subtitle="Владения Дома Ночи",
        description=(
            "Море на юге Царства, с которым граничат владения Меча и Песни. "
            "Ночной сад, Ночное небо и Ночная гавань."
        ),
        outline=[
            (0.020, 0.808), (0.080, 0.820), (0.150, 0.836), (0.214, 0.864),
            (0.274, 0.892), (0.330, 0.910), (0.386, 0.936), (0.430, 0.970),
            (0.460, 1.000), (0.020, 1.000),
        ],
        color=(44, 80, 96), opacity=0.70,
        label=(0.200, 0.935), label_size=25,
        title_fill=(226, 220, 194), title_stroke=(26, 40, 48),
    ),
    dict(
        id="region_shattered_lands", title="РАСКОЛОТЫЕ ЗЕМЛИ",
        subtitle="Юг · трещины",
        description=(
            "Расколотые пустоши на юге, между Штормовым морем и Котловиной. "
            "Трещины уходят вглубь, и никто не знает, что лежит под ними."
        ),
        outline=[
            (0.356, 0.900), (0.388, 0.918), (0.418, 0.902), (0.446, 0.916),
            (0.474, 0.902), (0.500, 0.918), (0.520, 0.962), (0.540, 1.000),
            (0.430, 1.000), (0.414, 0.968), (0.380, 0.944),
        ],
        color=(164, 130, 84), opacity=0.66,
        label=(0.440, 0.962), label_size=20,
        title_fill=(74, 50, 24), title_stroke=(236, 222, 194),
    ),
    dict(
        id="region_basin", title="КОТЛОВИНА",
        subtitle="Владения Доблести",
        description=(
            "Зелёная котловина в сердце земель клана Доблести. Бастион, "
            "Вечное золото, Великий лес и Речные врата."
        ),
        outline=[
            (0.540, 0.906), (0.580, 0.878), (0.622, 0.874), (0.664, 0.828),
            (0.694, 0.768), (0.718, 0.706), (0.735, 0.780), (0.790, 0.770),
            (0.845, 0.758), (0.900, 0.768), (0.952, 0.752), (0.988, 0.748),
            (0.992, 0.900), (0.975, 0.955), (0.952, 1.000), (0.540, 1.000),
            (0.520, 0.962), (0.530, 0.930),
        ],
        color=(92, 124, 66), opacity=0.66,
        label=(0.815, 0.945), label_size=26,
        title_fill=(42, 56, 28), title_stroke=(236, 226, 198),
    ),
]

LAND_IDS = [
    "region_frozen_wastes", "region_burned_forest", "region_nightmare_desert",
    "region_forgotten_shore", "region_hollow_mountains", "region_song_domain",
    "region_godgrave", "region_shattered_lands", "region_basin",
]

# id, подпись, описание, u, v, kind (0..3), icon, light
PLACES = [
    ("frozen_citadel", "Ледяная Цитадель", "Цитадель во льдах на краю мира.", 0.492, 0.098, 0, "temple", True),
    ("northern_outpost", "Северный Форпост", "Поселение у южной кромки вечных льдов.", 0.306, 0.142, 1, "town", True),
    ("ternwall_glacier", "Ледник Тернвалл", "Медленно ползущий ледник на востоке пустошей.", 0.690, 0.110, 0, "label", True),
    ("emberhold", "Эмберхолд", "Город в сердце выжженного леса.", 0.402, 0.360, 1, "city", True),
    ("charred_bastion", "Выжженный бастион", "Руины крепости, пережившей огонь.", 0.560, 0.352, 0, "ruins", True),
    ("obsidian_keep", "Обсидиановая крепость", "Чёрная крепость у восточной кромки леса.", 0.656, 0.292, 0, "tower", True),
    ("ashen_canopy", "Пепельный полог", "Сплошной полог мёртвых крон над лесом.", 0.370, 0.304, 0, "label", True),
    ("tomb_of_ariel", "Гробница Ариэля", "Древняя гробница в глубине пустыни.", 0.812, 0.098, 2, "temple", False),
    ("dunes_of_silence", "Дюны Безмолвия", "Белые дюны, в которых не слышно ветра.", 0.842, 0.184, 0, "label", False),
    ("searchwind_wastes", "Пустоши Ищущего Ветра", "Выжженные пустоши на востоке.", 0.858, 0.302, 0, "label", False),
    ("sands_of_obelisk", "Пески Обелиска", "Пески вокруг забытого монумента.", 0.790, 0.374, 0, "label", False),
    ("forgotten_obelisk", "Забытый Обелиск", "Обелиск, чьё имя стёрто временем.", 0.846, 0.402, 0, "obelisk", False),
    ("howling_mirror", "Воющее Зеркало", "Гладкая скала, в которой воет ветер.", 0.922, 0.436, 2, "ruins", False),
    ("crimson_spire", "Багровый шпиль", "Багровый шпиль в кольце Лабиринта.", 0.382, 0.494, 3, "tower", True),
    ("dark_city", "Тёмный город", "Руины на восточном краю кратера.", 0.556, 0.484, 0, "city", True),
    ("dark_graveyard", "Кладбище Тьмы", "Мёртвое поле у стен Тёмного города.", 0.534, 0.532, 2, "cursed", True),
    ("nameless_isle", "Безымянный остров", "Остров в чёрной глубине кратера.", 0.454, 0.506, 0, "label", True),
    ("soul_burning_tree", "Древо, сжигающее души", "Красное древо, у которого горят души.", 0.622, 0.478, 2, "tree", True),
    ("salt_flats_tree", "Солончаковое древо", "Одинокое дерево на солончаках.", 0.612, 0.450, 0, "tree", True),
    ("boneblight_pass", "Перевал Костесвета", "Проход к кратеру с запада.", 0.292, 0.516, 0, "gate", True),
    ("ashen_barrow", "Пепельный курган", "Курган напротив Тёмного города, на западном краю кратера.", 0.286, 0.490, 0, "label", True),
    ("moonriver", "Равнина Лунной Реки", "Равнина во владениях Песни.", 0.250, 0.646, 0, "label", False),
    ("jade_palace", "Нефритовая обитель", "Храм в западных горах.", 0.062, 0.702, 0, "temple", False),
    ("ravenheart", "Вороново Сердце", "Столица клана Песни на склонах хребта.", 0.146, 0.714, 0, "major_city", False),
    ("ravenreach", "Вороний хребет", "Горный форпост над Вороновым Сердцем.", 0.104, 0.748, 1, "town", False),
    ("stormward_pass", "Штормовой перевал", "Перевал, открытый всем ветрам.", 0.138, 0.660, 0, "gate", False),
    ("crescent_plateau", "Полумесячное плато", "Плато в форме полумесяца.", 0.044, 0.766, 0, "label", False),
    ("roundtable_keep", "Крепость Круглого Стола", "Старая крепость на южных склонах.", 0.174, 0.778, 0, "fortress", False),
    ("eaglen_den", "Орлиное гнездо", "Поселение на орлиных скалах.", 0.182, 0.826, 1, "town", False),
    ("congreve_peak", "Пик Конгрива", "Высочайшая вершина Серых гор.", 0.044, 0.846, 0, "label", False),
    ("mournful_plain", "Скорбная равнина", "Равнина у южных отрогов.", 0.272, 0.792, 0, "label", False),
    ("silence_of_bones", "Безмолвие костей", "Кости павшего божества под открытым небом.", 0.556, 0.662, 0, "label", False),
    ("silent_watchers", "Безмолвные стражи", "Исполинские фигуры на краю поля костей.", 0.442, 0.700, 2, "cursed", False),
    ("field_of_bones", "Поле костей", "Поле, усеянное костями неизвестных тварей.", 0.422, 0.744, 0, "label", False),
    ("veilstone", "Вуаль-камень", "Камень, скрывающий границу зоны смерти.", 0.432, 0.802, 0, "obelisk", False),
    ("glass_peaks", "Стеклянные пики", "Пики из чёрного стекла.", 0.552, 0.754, 0, "label", False),
    ("bone_sea", "Костяное море", "Море костей у подножия Могилы Бога.", 0.568, 0.826, 0, "label", False),
    ("sunken_road", "Затонувшая дорога", "Дорога, ушедшая под кости.", 0.486, 0.852, 0, "label", False),
    ("night_temple", "Храм Ночи", "Храм на парящем острове.", 0.820, 0.526, 0, "temple", True),
    ("iron_prison", "Железная тюрьма", "Бастион-тюрьма на цепи.", 0.796, 0.610, 2, "fortress", True),
    ("sanctuary_of_night", "Святилище Ночи", "Святилище на южном острове.", 0.856, 0.656, 0, "temple", True),
    ("broken_isles", "Разбитые острова", "Осколки островов на краю бездны.", 0.944, 0.702, 0, "label", True),
    ("night_garden", "Ночной сад", "Сад на берегу Штормового моря.", 0.284, 0.886, 0, "label", True),
    ("night_sky", "Ночное небо", "Берег, где небо не отражается в воде.", 0.300, 0.926, 0, "label", True),
    ("unknown_lands", "???", "Никто не знает, что здесь.", 0.395, 0.936, 0, "label", False),
    ("bastion", "Бастион", "Цитадель в сердце владений Доблести.", 0.818, 0.882, 1, "major_city", False),
    ("evergold", "Вечное золото", "Город у золотых полей.", 0.682, 0.886, 1, "town", False),
    ("greatwood", "Великий лес", "Древний лес на востоке Котловины.", 0.910, 0.972, 0, "label", False),
    ("rivergate", "Речные врата", "Городок у слияния рек.", 0.622, 0.976, 1, "town", False),
]

# Подписи природных объектов без значка: (text, u, v, size, spacing, light, italic)
NOTES = [
    ("БЕСКРАЙНЯЯ БЕЛЬ", 0.470, 0.070, 16, 3, False, True),
    ("БЛЕДНАЯ РАВНИНА", 0.552, 0.196, 15, 3, False, True),
    ("ЧЁРНАЯ ДОРОГА", 0.305, 0.350, 14, 2, True, True),
    ("БЕЗДНА", 0.760, 0.730, 13, 3, True, True),
]

# Хребты: (полилиния, количество, min_h, max_h, snow)
RIDGES = [
    ([(0.060, 0.556), (0.130, 0.545), (0.210, 0.560), (0.300, 0.582),
      (0.390, 0.598), (0.480, 0.604), (0.570, 0.596), (0.650, 0.578), (0.716, 0.556)],
     34, 16, 30, False),
    # Пепельный вал по южной кромке кратера Забытого берега.
    ([(0.110, 0.535), (0.180, 0.562), (0.260, 0.582), (0.350, 0.596),
      (0.440, 0.608), (0.530, 0.608), (0.620, 0.596), (0.700, 0.578), (0.748, 0.560)],
     38, 9, 18, False),
    ([(0.040, 0.610), (0.100, 0.635), (0.155, 0.665), (0.212, 0.700),
      (0.268, 0.742), (0.312, 0.788), (0.300, 0.825), (0.250, 0.858),
      (0.190, 0.878), (0.130, 0.858), (0.086, 0.816), (0.058, 0.756), (0.042, 0.680)],
     30, 18, 34, True),
    ([(0.074, 0.700), (0.130, 0.720), (0.190, 0.748), (0.244, 0.786),
      (0.278, 0.828), (0.240, 0.860), (0.178, 0.870), (0.118, 0.842)],
     16, 14, 24, False),
    ([(0.060, 0.742), (0.120, 0.762), (0.180, 0.792), (0.235, 0.824), (0.270, 0.856)],
     14, 9, 16, False),
    ([(0.588, 0.700), (0.590, 0.744), (0.586, 0.786), (0.582, 0.826)],
     8, 14, 24, False),
    # Стеклянные пики Могилы Бога.
    ([(0.500, 0.700), (0.520, 0.728), (0.540, 0.756), (0.556, 0.786), (0.566, 0.816)],
     10, 12, 24, True),
    ([(0.760, 0.930), (0.812, 0.918), (0.868, 0.912), (0.916, 0.918)],
     9, 10, 16, False),
    ([(0.610, 0.912), (0.680, 0.925), (0.750, 0.934), (0.820, 0.928), (0.890, 0.938)],
     12, 7, 13, False),
    ([(0.590, 0.070), (0.650, 0.062), (0.706, 0.074), (0.752, 0.094)],
     8, 12, 22, False),
    # Ледяные шпили вдоль северной кромки.
    ([(0.080, 0.070), (0.160, 0.055), (0.240, 0.060), (0.320, 0.050), (0.400, 0.060),
      (0.480, 0.050), (0.560, 0.058), (0.640, 0.050), (0.720, 0.060)],
     18, 8, 15, True),
]

FORESTS = [
    ("region_burned_forest", 380, 11, True),
    ("region_song_domain", 110, 12, False),
    ("region_godgrave", 42, 13, True),
    ("region_basin", 230, 14, False),
    ("region_chained_isles", 42, 15, False),
    ("region_frozen_wastes", 20, 16, True),
]

ISLES = [
    # u, v, rx, ry, rot, occupied_by
    (0.762, 0.512, 0.036, 0.023, -8, ""),
    (0.822, 0.548, 0.050, 0.030, 6, "night_temple"),
    (0.892, 0.514, 0.032, 0.020, -12, ""),
    (0.858, 0.604, 0.040, 0.025, 4, "iron_prison"),
    (0.790, 0.648, 0.034, 0.021, 10, ""),
    (0.858, 0.664, 0.042, 0.026, -6, "sanctuary_of_night"),
    (0.936, 0.682, 0.034, 0.020, 14, "broken_isles"),
    (0.926, 0.586, 0.026, 0.017, -4, ""),
]

ROADS = [
    [(0.338, 0.320), (0.360, 0.344), (0.402, 0.360), (0.470, 0.376), (0.530, 0.410), (0.556, 0.484)],
    [(0.402, 0.360), (0.462, 0.336), (0.530, 0.334), (0.594, 0.322), (0.656, 0.292)],
    [(0.278, 0.662), (0.252, 0.710), (0.218, 0.756), (0.196, 0.792), (0.182, 0.826)],
    [(0.146, 0.714), (0.176, 0.752), (0.218, 0.780), (0.272, 0.792)],
    [(0.818, 0.882), (0.760, 0.902), (0.704, 0.926), (0.662, 0.950), (0.622, 0.976)],
    [(0.818, 0.882), (0.860, 0.906), (0.892, 0.934)],
    [(0.382, 0.494), (0.420, 0.520), (0.468, 0.530), (0.534, 0.532)],
]

SEA_ROUTES = [
    [(0.100, 0.946), (0.172, 0.920), (0.250, 0.900), (0.300, 0.892)],
    [(0.170, 0.930), (0.210, 0.858), (0.230, 0.790), (0.250, 0.740)],
    [(0.760, 0.560), (0.820, 0.585), (0.858, 0.604), (0.920, 0.650)],
    [(0.930, 0.520), (0.952, 0.600), (0.944, 0.682)],
]

RIVERS = [
    [(0.804, 0.790), (0.788, 0.824), (0.770, 0.856), (0.744, 0.884), (0.706, 0.912),
     (0.676, 0.940), (0.650, 0.968), (0.622, 0.994)],
    [(0.892, 0.784), (0.886, 0.826), (0.872, 0.866), (0.866, 0.908), (0.878, 0.950), (0.892, 0.988)],
    [(0.612, 0.060), (0.606, 0.098), (0.588, 0.136), (0.566, 0.170), (0.552, 0.206)],
    [(0.218, 0.612), (0.196, 0.646), (0.176, 0.684), (0.162, 0.724), (0.150, 0.768), (0.130, 0.810)],
]

LEGEND = [
    ("major_city", "Столица / крупный город"),
    ("city", "Город / крепость"),
    ("town", "Городок / поселение"),
    ("ruins", "Руины / древнее место"),
    ("port", "Порт / гавань"),
    ("tower", "Башня / форт"),
    ("temple", "Храм / святыня"),
    ("cursed", "Проклятое место"),
    ("obelisk", "Обелиск / монумент"),
    ("gate", "Врата / перевал"),
    ("road", "Дорога / торговый путь"),
    ("sea_route", "Морской путь"),
    ("river", "Река"),
    ("border", "Граница"),
]


# --- Утилиты -----------------------------------------------------------------

def _font(size, bold=False, italic=False):
    key = (int(size), bold, italic)
    if key in _FONTS:
        return _FONTS[key]
    path = None
    for name in FONT_FILES[(bold, italic)]:
        for folder in FONT_DIRS:
            candidate = os.path.join(folder, name)
            if os.path.exists(candidate):
                path = candidate
                break
        if path:
            break
    font = ImageFont.truetype(path, int(size)) if path else ImageFont.load_default()
    _FONTS[key] = font
    return font


_FONTS = {}


def _px(pt):
    return (pt[0] * W, pt[1] * H)


def _scale(col, k):
    return tuple(max(0, min(255, int(c * k))) for c in col)


def _inside(poly, x, y):
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y):
            if x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
                inside = not inside
        j = i
    return inside


def _smooth(points, samples=8):
    return P.smooth_curve([_px(p) for p in points], samples)


def _rect_for_text(draw, at, text, font, anchor="mm"):
    w = draw.textlength(text, font=font)
    h = font.size
    x, y = at
    if anchor[0] == "m":
        x -= w * 0.5
    elif anchor[0] == "r":
        x -= w
    if anchor[1] == "m":
        y -= h * 0.5
    elif anchor[1] == "s":
        y -= h * 0.82
    return (x, y, w, h)


class _Art:
    def __init__(self, base):
        self.img = base.convert("RGBA")
        self.d = ImageDraw.Draw(self.img)

    def xy(self, u, v):
        return (u * W * S, v * H * S)

    def line(self, pts, width=2.0, fill=INK, alpha=235, joint="curve"):
        self.d.line([(x * S, y * S) for x, y in pts], fill=fill + (alpha,),
                    width=max(1, int(round(width * S))), joint=joint)

    def polygon(self, pts, fill=None, outline=None, width=1.0, alpha=255, oalpha=255):
        p = [(x * S, y * S) for x, y in pts]
        if fill is not None:
            self.d.polygon(p, fill=fill + (alpha,))
        if outline is not None:
            self.d.line(p + [p[0]], fill=outline + (oalpha,),
                        width=max(1, int(round(width * S))), joint="curve")

    def ellipse(self, u, v, rx, ry, fill=None, outline=None, width=1.0, alpha=255):
        box = [(u - rx) * W * S, (v - ry) * H * S, (u + rx) * W * S, (v + ry) * H * S]
        if fill is not None:
            self.d.ellipse(box, fill=fill + (alpha,))
        if outline is not None:
            self.d.ellipse(box, outline=outline + (alpha,), width=max(1, int(width * S)))

    def text(self, at, text, size, fill=INK, bold=False, italic=False, spacing=0,
             anchor="mm", stroke=0, stroke_fill=None, alpha=255):
        font = _font(size * S, bold, italic)
        x, y = at[0] * S, at[1] * S
        fill4 = fill + (alpha,)
        stroke4 = stroke_fill + (alpha,) if stroke_fill else None
        if spacing <= 0:
            self.d.text((x, y), text, font=font, fill=fill4, anchor=anchor,
                        stroke_width=int(stroke * S), stroke_fill=stroke4)
            return
        sp = spacing * S
        widths = [self.d.textlength(ch, font=font) for ch in text]
        total = sum(widths) + sp * (len(text) - 1)
        if anchor[0] == "m":
            x -= total * 0.5
        elif anchor[0] == "r":
            x -= total
        va = "l" + anchor[1]
        for ch, w in zip(text, widths):
            if ch != " ":
                self.d.text((x, y), ch, font=font, fill=fill4, anchor=va,
                            stroke_width=int(stroke * S), stroke_fill=stroke4)
            x += w + sp


def _paper(rng):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    base = np.array([0.882, 0.806, 0.660], np.float32)
    n1 = P.fbm(H, W, 190, 5, rng) - 0.5
    n2 = P.fbm(H, W, 24, 4, rng) - 0.5
    n3 = P.fbm(H, W, 5.0, 2, rng) - 0.5
    col = base[None, None, :] * (1.0 + (0.105 * n1 + 0.05 * n2 + 0.022 * n3)[..., None])

    # Крупные разводы и пятна старой бумаги.
    stain = np.zeros((H, W), np.float32)
    for _ in range(22):
        cx, cy = rng.uniform(0, W), rng.uniform(0, H)
        rx, ry = rng.uniform(70, 260), rng.uniform(50, 180)
        stain += np.exp(-(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2) * 1.7)
    stain = np.clip(stain * 0.16, 0, 0.22)
    col = P.mix(col, np.array([0.62, 0.50, 0.34], np.float32)[None, None, :], stain)

    edge = np.minimum(np.minimum(xx, W - 1 - xx), np.minimum(yy, H - 1 - yy))
    burn = np.clip(1.0 - edge / 36.0, 0, 1) ** 1.55
    col = P.mix(col, np.array([0.35, 0.27, 0.17], np.float32)[None, None, :], burn * 0.50)
    return col


def _sea_color(land, rng):
    dist = P.distance_to(land > 0.5)
    deep = P.ramp(np.clip(dist / 105.0, 0, 1), [
        (0.0, (96, 136, 134)), (0.18, (66, 104, 110)), (0.55, (42, 74, 86)), (1.0, (28, 52, 66)),
    ])
    waves = P.fbm(H, W, 13, 3, rng)
    deep = deep * (0.92 + 0.17 * waves[..., None])
    shelf = np.exp(-(dist / 7.0) ** 2)
    deep = P.mix(deep, np.array([0.58, 0.70, 0.68], np.float32)[None, None, :], shelf * 0.34)
    return deep, dist


def _icon(art, kind, u, v, size=20, ink=INK, fill=CREAM, light=False):
    """Глиф поселения/места. Рисуется в локальном квадрате 20×20."""
    if kind == "label":
        return
    x, y = art.xy(u, v)
    k = size * S / 20.0

    def p(px, py):
        return (x + px * k, y + py * k)

    def poly(pts, f=None, o=None, w=1.2):
        q = [p(a, b) for a, b in pts]
        if f is not None:
            art.d.polygon(q, fill=f + (255,))
        if o is not None:
            art.d.line(q + [q[0]], fill=o + (255,), width=max(1, int(w * k)))

    def line(pts, w=1.2, c=None):
        art.d.line([p(a, b) for a, b in pts], fill=(c or ink) + (255,), width=max(1, int(w * k)))

    def rect(x0, y0, x1, y1, f=None, o=None, w=1.0):
        poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], f, o, w)

    def ell(cx, cy, rx, ry, f=None, o=None, w=1.0):
        box = [p(cx - rx, cy - ry), p(cx + rx, cy + ry)]
        if f is not None:
            art.d.ellipse(box, fill=f + (255,))
        if o is not None:
            art.d.ellipse(box, outline=o + (255,), width=max(1, int(w * k)))

    # Лёгкий пергаментный нимб, чтобы значки читались на тёмных заливках.
    if light:
        art.d.ellipse([x - 12 * k, y - 12 * k, x + 12 * k, y + 12 * k],
                      fill=(20, 18, 16, 120))
    else:
        art.d.ellipse([x - 12 * k, y - 12 * k, x + 12 * k, y + 12 * k],
                      fill=fill + (110,))

    if kind in ("city", "major_city", "fortress"):
        towers = [(-7, -2, -3, 6), (-2.5, -5, 2.5, 6), (3, -2, 7, 6)]
        if kind == "fortress":
            towers = [(-7, -5, 7, 6)]
        for x0, y0, x1, y1 in towers:
            rect(x0, y0, x1, y1, fill, ink, 1.1)
            # зубцы
            for bx in [x0, x0 + (x1 - x0) * 0.45]:
                rect(bx, y0 - 2, bx + 1.1, y0, ink, ink, 0.4)
        rect(-7, 4.2, 7, 6, fill, ink, 1.0)
        # ворота
        box = [p(-1.4, 1.4), p(1.4, 6)]
        art.d.ellipse(box, fill=ink + (255,))
        if kind == "major_city":
            art.d.polygon([p(0, -11), p(1.4, -8.4), p(4, -8.0), p(2.1, -6.1),
                           p(2.6, -3.4), p(0, -4.8), p(-2.6, -3.4), p(-2.1, -6.1),
                           p(-4, -8.0), p(-1.4, -8.4)], fill=ink + (255,))
    elif kind == "town":
        rect(-7, 0, -1, 6, fill, ink, 1.0)
        poly([(-8.4, 0), (-4, -4), (0.4, 0)], fill, ink, 1.0)
        rect(1, 2, 7, 6, fill, ink, 1.0)
        poly([(-0.2, 2), (4, -2.5), (8.2, 2)], fill, ink, 1.0)
        rect(-5.2, 2.4, -3.4, 4.2, ink, ink, 0.4)
    elif kind == "ruins":
        for cx, h in [(-6, 5), (-1.5, 2.5), (3.5, 6.5), (6.8, 3)]:
            rect(cx, -h, cx + 2.2, 6, fill, ink, 1.0)
            line([(cx, -h), (cx + 2.2, -h + 1.2)], 0.8)
        line([(-8, 6.2), (8, 6.2)], 1.0)
    elif kind == "port":
        line([(0, -8), (0, 5)], 1.6)
        ell(0, -8.6, 1.6, 1.6, None, ink, 1.0)
        line([(-4, 3), (4, 3)], 1.4)
        line([(-4.2, 0.5), (-6.2, 3), (-4.2, 3)], 1.3)
        line([(4.2, 0.5), (6.2, 3), (4.2, 3)], 1.3)
        line([(-4.4, -2.5), (4.4, -2.5)], 1.0)
    elif kind == "tower":
        rect(-3, -6, 3, 6, fill, ink, 1.1)
        poly([(-4.2, -6), (0, -10), (4.2, -6)], fill, ink, 1.1)
        rect(-3.6, -3, -2.2, -1.4, ink, ink, 0.3)
        rect(2.2, -3, 3.6, -1.4, ink, ink, 0.3)
        line([(0, -10), (0, -13)], 1.0)
        poly([(0, -13), (4, -12), (0, -10.8)], ink, ink, 0.4)
    elif kind == "temple":
        poly([(-8, -1), (0, -7), (8, -1)], fill, ink, 1.1)
        for cx in [-6, -3, 0, 3, 6]:
            line([(cx, -1), (cx, 6)], 1.0)
        line([(-8, 6.4), (8, 6.4)], 1.4)
        line([(-8, 0.4), (8, 0.4)], 1.0)
    elif kind == "cursed":
        ell(0, -2, 6.2, 6.8, fill, ink, 1.2)
        ell(-2.4, -3.2, 1.3, 1.5, ink, ink, 0.3)
        ell(2.4, -3.2, 1.3, 1.5, ink, ink, 0.3)
        poly([(-2, 2.2), (0, 6.2), (2, 2.2)], ink, ink, 0.4)
    elif kind == "obelisk":
        poly([(-2.2, 6.5), (-1.2, -5), (0, -8.5), (1.2, -5), (2.2, 6.5)], fill, ink, 1.2)
        line([(-4, 6.6), (4, 6.6)], 1.4)
        line([(-1.2, -1), (1.2, -1)], 0.8)
    elif kind == "gate":
        rect(-7, -4, -4, 6.5, fill, ink, 1.1)
        rect(4, -4, 7, 6.5, fill, ink, 1.1)
        # арка
        art.d.arc([p(-4, -6), p(4, 4)], 180, 360, fill=ink + (255,),
                  width=max(1, int(1.3 * k)))
        line([(-7, -4), (-4, -4)], 1.0)
        line([(4, -4), (7, -4)], 1.0)
    elif kind == "tree":
        line([(0, 6), (0, -1)], 1.4)
        poly([(-5, -1), (0, -8), (5, -1)], fill, ink, 1.0)
        poly([(-4, 2.5), (0, -3.5), (4, 2.5)], fill, ink, 1.0)


def _place_label(art, occupied, at, text, size, fill, stroke, spacing=0,
                 italic=False, bold=False, delta=(0, 0), pad=2.0):
    """Ставит подпись рядом с точкой, избегая занятых прямоугольников."""
    x, y = at[0] + delta[0], at[1] + delta[1]
    font = _font(size * S, bold, italic)
    w = art.d.textlength(text, font=font) / S
    h = size * 1.05
    rect = (x - w / 2 - pad, y - h / 2 - pad, w + pad * 2, h + pad * 2)
    if rect[0] < 14 or rect[1] < 14 or rect[0] + rect[2] > W - 14 or rect[1] + rect[3] > H - 14:
        return False
    for ox, oy, ow, oh in occupied:
        if rect[0] < ox + ow and rect[0] + rect[2] > ox and rect[1] < oy + oh and rect[1] + rect[3] > oy:
            return False
    art.text((x, y), text, size, fill=fill, bold=bold, italic=italic,
             spacing=spacing, anchor="mm", stroke=1.6, stroke_fill=stroke)
    occupied.append(rect)
    return True


def _draw_legend(art, occupied):
    x0, y0, x1, y1 = 34, 166, 372, 566
    art.d.rectangle([x0 * S, y0 * S, x1 * S, y1 * S], fill=(30, 30, 24, 198))
    art.d.rectangle([x0 * S, y0 * S, x1 * S, y1 * S], outline=GOLD + (210,), width=2 * S)
    art.d.rectangle([(x0 + 4) * S, (y0 + 4) * S, (x1 - 4) * S, (y1 - 4) * S],
                    outline=GOLD + (80,), width=S)
    art.text(((x0 + x1) * 0.5, y0 + 22), "ЛЕГЕНДА", 16, fill=GOLD, bold=True,
             spacing=5, stroke=0)
    row = 24.0
    top = y0 + 50
    for i, (kind, label) in enumerate(LEGEND):
        cy = top + i * row
        cx = x0 + 26
        if kind in ("road", "sea_route", "river", "border"):
            if kind == "road":
                art.d.line([(cx - 10) * S, cy * S, (cx + 10) * S, cy * S], fill=INK_SOFT + (230,), width=2 * S)
                art.d.line([(cx - 8) * S, cy * S, (cx + 8) * S, cy * S], fill=CREAM + (230,), width=S)
            elif kind == "sea_route":
                for k in range(-2, 3):
                    art.d.ellipse([(cx + k * 4 - 1) * S, (cy - 1) * S, (cx + k * 4 + 1) * S, (cy + 1) * S],
                                  fill=CREAM + (210,))
            elif kind == "river":
                art.d.line([(cx - 10) * S, (cy + 3) * S, (cx - 3) * S, (cy - 2) * S,
                            (cx + 4) * S, (cy + 2) * S, (cx + 10) * S, (cy - 3) * S],
                           fill=(96, 146, 150, 230), width=2 * S, joint="curve")
            else:
                for k in range(-2, 3):
                    art.d.ellipse([(cx + k * 4 - 1) * S, (cy - 1) * S, (cx + k * 4 + 1) * S, (cy + 1) * S],
                                  fill=CREAM + (160,))
        else:
            _icon(art, kind, cx / W, cy / H, size=15, ink=CREAM, fill=DARK_PANEL, light=True)
        art.text((x0 + 48, cy), label, 14, fill=CREAM, stroke=0, anchor="lm")
    occupied.append((x0 - 3, y0 - 3, x1 - x0 + 6, y1 - y0 + 6))


def _draw_title(art):
    art.text((44, 40), "МИР", 22, fill=INK, bold=True, spacing=9, anchor="lm")
    art.text((42, 78), "SHADOW SLAVE", 52, fill=INK, bold=True, spacing=1,
             stroke=0, anchor="lm")
    art.d.line([45 * S, 118 * S, 452 * S, 118 * S], fill=INK + (160,), width=S)
    art.d.line([45 * S, 122 * S, 430 * S, 122 * S], fill=INK + (90,), width=S)
    art.text((46, 138), "«В конце концов, тень побеждает.» — Нефис", 15,
             fill=INK_SOFT, italic=True, anchor="lm")


def _draw_frame(art):
    for inset, alpha, width in [(8, 190, 2), (14, 80, 1)]:
        art.d.rectangle([inset * S, inset * S, (W - inset) * S, (H - inset) * S],
                        outline=INK + (alpha,), width=width * S)
    # Уголки: короткие двойные штрихи.
    for cx, cy in [(8, 8), (W - 8, 8), (8, H - 8), (W - 8, H - 8)]:
        sx = 1 if cx < W / 2 else -1
        sy = 1 if cy < H / 2 else -1
        art.d.line([(cx + 4 * sx) * S, cy * S, (cx + 46 * sx) * S, cy * S],
                   fill=GOLD + (170,), width=2 * S)
        art.d.line([cx * S, (cy + 4 * sy) * S, cx * S, (cy + 46 * sy) * S],
                   fill=GOLD + (170,), width=2 * S)


def _draw_compass(art):
    cx, cy, r = W - 92, H - 96, 34
    art.d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S],
                  outline=INK + (170,), width=2 * S)
    art.d.ellipse([(cx - r * 0.58) * S, (cy - r * 0.58) * S,
                   (cx + r * 0.58) * S, (cy + r * 0.58) * S],
                  outline=INK + (90,), width=S)
    for i in range(8):
        a = -math.pi / 2 + i * math.pi / 4
        length = r * (1.0 if i % 2 == 0 else 0.58)
        tip = (cx + math.cos(a) * length, cy + math.sin(a) * length)
        side = (math.cos(a + math.pi / 2) * r * 0.12, math.sin(a + math.pi / 2) * r * 0.12)
        fill = INK if i % 2 == 0 else INK_SOFT
        art.polygon([(cx + side[0], cy + side[1]), tip, (cx, cy)], fill=fill)
        art.polygon([(cx, cy), tip, (cx - side[0], cy - side[1])], fill=_scale(fill, 0.65))
    art.text((cx, cy - r - 14), "С", 15, fill=INK, bold=True)


def _draw_paper_marks(art, rng):
    # Сгибы и волокна бумаги.
    for _ in range(5):
        if rng.random() < 0.5:
            x = rng.uniform(0.1, 0.9) * W
            pts = [(x + math.sin(i * 0.15) * 2, i * H / 30) for i in range(31)]
        else:
            y = rng.uniform(0.1, 0.9) * H
            pts = [(i * W / 30, y + math.sin(i * 0.12) * 2) for i in range(31)]
        art.line(pts, width=1.0, fill=(96, 76, 50), alpha=22)
    # Мелкие крапинки.
    for _ in range(260):
        u, v = rng.uniform(0.02, 0.98), rng.uniform(0.02, 0.98)
        r = rng.uniform(0.4, 1.4)
        art.ellipse(u, v, r / W, r / H, fill=(92, 68, 42), alpha=45)


def _draw_sea(art, rng, land_mask):
    # Волны: короткие штрихи только по воде.
    for _ in range(2200):
        u, v = rng.uniform(0.01, 0.99), rng.uniform(0.01, 0.99)
        if _inside(COAST, u, v):
            continue
        length = rng.uniform(0.010, 0.034)
        amp = rng.uniform(0.001, 0.003)
        pts = [((u + k * length / 6.0) * W, (v + math.sin(k * 1.2) * amp) * H) for k in range(7)]
        art.line(pts, width=rng.uniform(0.7, 1.3), fill=SEA_INK, alpha=int(rng.uniform(28, 62)))

    # Береговые линии: два слабых контура вокруг суши.
    for k, alpha in [(1.008, 60), (1.018, 36)]:
        pts = [_px(((u - 0.5) * k + 0.5, (v - 0.5) * k + 0.5)) for u, v in COAST]
        art.line(pts + [pts[0]], width=1.1, fill=SEA_INK, alpha=alpha)

    # Штрихи прибоя: короткие перпендикуляры к берегу.
    coast = _smooth(COAST, 10)
    for i in range(0, len(coast) - 1, 3):
        x0, y0 = coast[i]
        x1, y1 = coast[i + 1]
        dx, dy = x1 - x0, y1 - y0
        length = math.hypot(dx, dy)
        if length < 1e-3:
            continue
        nx, ny = dy / length, -dx / length
        art.line([(x0, y0), (x0 + nx * rng.uniform(4.0, 9.0), y0 + ny * rng.uniform(4.0, 9.0))],
                 width=0.9, fill=SEA_INK, alpha=72)
        art.line([(x0, y0), (x0 - nx * rng.uniform(2.0, 4.5), y0 - ny * rng.uniform(2.0, 4.5))],
                 width=0.7, fill=SEA_INK, alpha=35)

    # Основной контур суши — двойная тушь.
    art.d.line([(x * S + S, y * S + S) for x, y in coast], fill=(240, 228, 200, 90),
               width=5 * S, joint="curve")
    art.d.line([(x * S, y * S) for x, y in coast], fill=INK + (235,),
               width=int(2.4 * S), joint="curve")


def _draw_mountains(art, rng):
    light = (136, 130, 116)
    shade = (74, 68, 60)
    snow = (212, 208, 198)
    for path, count, hmin, hmax, snowy in RIDGES:
        curve = _smooth(path, 12)
        # равномерно идём по кривой и ставим пики со сдвигом
        for i in range(count):
            t = (i + rng.uniform(0.1, 0.9)) / count
            idx = min(len(curve) - 1, int(t * (len(curve) - 1)))
            x, y = curve[idx]
            x += rng.uniform(-8, 8)
            y += rng.uniform(-4, 4)
            h = rng.uniform(hmin, hmax) * 0.86
            w = h * rng.uniform(0.85, 1.35)
            base_y = y + h * 0.10
            pts = [
                (x - w * 0.52, base_y), (x - w * 0.34, base_y - h * 0.34),
                (x - w * 0.16, base_y - h * 0.64), (x, base_y - h),
                (x + w * 0.18, base_y - h * 0.62), (x + w * 0.36, base_y - h * 0.30),
                (x + w * 0.52, base_y),
            ]
            art.polygon(pts, fill=light, outline=INK, width=1.1)
            art.polygon([(x, base_y - h), (x + w * 0.18, base_y - h * 0.62),
                         (x + w * 0.36, base_y - h * 0.30), (x + w * 0.52, base_y),
                         (x, base_y)], fill=shade, alpha=200)
            # штриховка теневой стороны
            for k in range(3):
                yy = base_y - h * (0.18 + k * 0.16)
                art.line([(x + w * 0.06, yy), (x + w * (0.20 + k * 0.07), yy + h * 0.10)],
                         width=0.8, fill=INK, alpha=80)
            if snowy and h > 22:
                cap = [(x, base_y - h), (x - w * 0.13, base_y - h * 0.78),
                       (x - w * 0.04, base_y - h * 0.80), (x + w * 0.03, base_y - h * 0.74),
                       (x + w * 0.12, base_y - h * 0.79)]
                art.polygon(cap, fill=snow, alpha=225)


def _tree(art, x, y, size, dead, rng):
    if dead:
        art.line([(x, y), (x + rng.uniform(-2, 2), y - size)], width=1.7, fill=(24, 21, 17), alpha=240)
        for k in range(2):
            yy = y - size * (0.45 + k * 0.25)
            art.line([(x, yy), (x + size * 0.26, yy - size * 0.22)], width=1.0,
                     fill=(24, 21, 17), alpha=215)
            art.line([(x, yy), (x - size * 0.24, yy - size * 0.18)], width=1.0,
                     fill=(24, 21, 17), alpha=215)
        if rng.random() < 0.65:
            art.ellipse(x / W, (y - size * 0.86) / H,
                        size * rng.uniform(0.28, 0.42) / W,
                        size * rng.uniform(0.20, 0.30) / H,
                        fill=(28, 25, 20), alpha=200)
    else:
        ink = (34, 42, 28)
        body = (56, 78, 44)
        hi = (86, 108, 58)
        art.line([(x, y), (x, y - size * 0.55)], width=1.4, fill=(48, 38, 26), alpha=235)
        for k, (dx, dy, rr) in enumerate([(0, 0.55, 0.34), (-0.20, 0.44, 0.27), (0.20, 0.42, 0.25)]):
            art.ellipse((x + dx * size) / W, (y - dy * size) / H,
                        rr * size / W, rr * size * 1.15 / H,
                        fill=body if k else hi, outline=ink, alpha=235)


def _draw_forests(art, rng):
    for rid, count, seed, dead in FORESTS:
        poly = next(r["outline"] for r in REGIONS if r["id"] == rid)
        r = np.random.default_rng(seed)
        placed = 0
        guard = 0
        while placed < count and guard < count * 40:
            guard += 1
            u, v = r.uniform(0, 1), r.uniform(0, 1)
            if not _inside(poly, u, v):
                continue
            size = r.uniform(8, 16) if not dead else r.uniform(9, 17)
            _tree(art, u * W, v * H, size, dead, r)
            placed += 1


def _draw_desert(art, rng):
    poly = next(r["outline"] for r in REGIONS if r["id"] == "region_nightmare_desert")
    for row in range(34):
        v = 0.06 + row * 0.040
        if v > 0.44:
            break
        phase = rng.uniform(0, 6)
        pts = []
        for k in range(40):
            u = 0.70 + k * 0.0075
            vv = v + math.sin(k * 0.55 + phase) * 0.008
            if _inside(poly, u, vv):
                pts.append((u * W, vv * H))
        if len(pts) > 2:
            art.line(pts, width=1.3, fill=(124, 88, 44), alpha=130)
            # короткие «крючки» у края дюны
            for pt in pts[::7]:
                art.line([pt, (pt[0] + 7, pt[1] - 5)], width=1.0,
                         fill=(124, 88, 44), alpha=95)


def _draw_mesas(art, rng):
    mesas = [
        (0.765, 0.168, 0.052, 0.030), (0.885, 0.315, 0.046, 0.026),
        (0.944, 0.228, 0.036, 0.022), (0.806, 0.402, 0.040, 0.022),
    ]
    for u, v, rw, rh in mesas:
        x, y = u * W, v * H
        w, h = rw * W, rh * H
        top = [(x - w, y), (x - w * 0.72, y - h), (x + w * 0.52, y - h * 0.82),
               (x + w, y)]
        art.polygon(top, fill=(192, 158, 102), outline=INK, width=1.4)
        art.polygon([(x - w * 0.72, y - h), (x + w * 0.52, y - h * 0.82),
                     (x + w, y), (x, y)], fill=(151, 116, 68), alpha=205)
        for k in range(4):
            yy = y - h * (0.15 + k * 0.18)
            art.line([(x - w * 0.25, yy), (x + w * (0.35 + k * 0.06), yy + h * 0.10)],
                     width=0.9, fill=(104, 76, 42), alpha=100)
        art.line([(x - w * 0.72, y - h), (x + w * 0.52, y - h * 0.82)],
                 width=1.2, fill=(236, 210, 160), alpha=180)
        # редкие камни у подножия
        for _ in range(8):
            px = x + rng.uniform(-w * 1.1, w * 1.1)
            py = y + rng.uniform(2, h * 0.25)
            art.ellipse(px / W, py / H, rng.uniform(1.0, 2.2) / W,
                        rng.uniform(0.7, 1.5) / H, fill=(108, 82, 52), alpha=120)


def _draw_fields(art, rng):
    poly = next(r["outline"] for r in REGIONS if r["id"] == "region_basin")
    for _ in range(18):
        u, v = rng.uniform(0.60, 0.94), rng.uniform(0.88, 0.99)
        if not _inside(poly, u, v):
            continue
        w = rng.uniform(0.012, 0.032)
        h = rng.uniform(0.008, 0.018)
        pts = [(u - w, v + rng.uniform(-2, 2) / H), (u + w, v + rng.uniform(-2, 2) / H),
               (u + w * 0.8, v + h), (u - w * 0.8, v + h)]
        art.polygon([(px * W, py * H) for px, py in pts],
                    fill=(148, 158, 76) if rng.random() < 0.5 else (118, 140, 68),
                    alpha=90, outline=(74, 92, 46), width=0.8, oalpha=70)
        for k in range(3):
            yy = v + h * (0.25 + k * 0.22)
            art.line([((u - w * 0.9) * W, yy * H), ((u + w * 0.9) * W, yy * H)],
                     width=0.7, fill=(70, 86, 42), alpha=65)


def _draw_embers(art, rng):
    poly = next(r["outline"] for r in REGIONS if r["id"] == "region_burned_forest")
    for _ in range(140):
        u, v = rng.uniform(0.10, 0.77), rng.uniform(0.23, 0.45)
        if not _inside(poly, u, v):
            continue
        art.ellipse(u, v, rng.uniform(0.5, 1.4) / W, rng.uniform(0.5, 1.4) / H,
                    fill=(186, 92, 44), alpha=int(rng.uniform(55, 130)))


def _draw_bones(art, rng):
    poly = next(r["outline"] for r in REGIONS if r["id"] == "region_godgrave")
    for _ in range(56):
        u, v = rng.uniform(0.36, 0.70), rng.uniform(0.64, 0.88)
        if not _inside(poly, u, v):
            continue
        x, y = u * W, v * H
        a = rng.uniform(0, math.pi)
        length = rng.uniform(4, 13)
        dx, dy = math.cos(a) * length, math.sin(a) * length
        art.line([(x - dx, y - dy), (x + dx, y + dy)], width=rng.uniform(1.2, 2.4),
                 fill=(198, 186, 160), alpha=150)
        if rng.random() < 0.35:
            art.ellipse(x / W, (y - dy) / H, 1.6 / W, 1.2 / H,
                        fill=(206, 194, 168), alpha=140)


def _draw_ice(art, rng):
    poly = next(r["outline"] for r in REGIONS if r["id"] == "region_frozen_wastes")
    for _ in range(90):
        u, v = rng.uniform(0.04, 0.79), rng.uniform(0.02, 0.31)
        if not _inside(poly, u, v):
            continue
        a = rng.uniform(0, math.pi)
        length = rng.uniform(0.006, 0.03)
        pts = [(u * W, v * H)]
        for k in range(3):
            u += math.cos(a) * length * 0.5
            v += math.sin(a) * length * 0.5
            a += rng.uniform(-0.6, 0.6)
            pts.append((u * W, v * H))
        art.line(pts, width=1.0, fill=(70, 100, 110), alpha=90)

    # Ледяные обломки и айсберги вдоль кромки.
    for _ in range(18):
        u, v = rng.uniform(0.07, 0.76), rng.uniform(0.035, 0.28)
        if not _inside(poly, u, v):
            continue
        w = rng.uniform(8, 26)
        h = rng.uniform(6, 20)
        x, y = u * W, v * H
        pts = [(x - w, y), (x - w * 0.45, y - h * 0.75), (x, y - h),
               (x + w * 0.55, y - h * 0.55), (x + w, y)]
        art.polygon(pts, fill=(212, 226, 224), outline=(64, 92, 104), width=1.0, alpha=210)
        art.polygon([(x, y - h), (x + w * 0.55, y - h * 0.55), (x + w, y), (x, y)],
                    fill=(166, 196, 200), alpha=170)


def _draw_cracks(art, rng, rid, color, count=26, depth=3):
    poly = next(r["outline"] for r in REGIONS if r["id"] == rid)

    def branch(x, y, a, n):
        for _ in range(n):
            length = rng.uniform(4, 18)
            nx = x + math.cos(a) * length
            ny = y + math.sin(a) * length
            if _inside(poly, nx / W, ny / H):
                art.line([(x, y), (nx, ny)], width=rng.uniform(0.8, 1.6),
                         fill=color, alpha=int(rng.uniform(90, 190)))
                if depth > 1 and rng.random() < 0.28:
                    branch(nx, ny, a + rng.uniform(-0.7, 0.7), n - 1)
                x, y = nx, ny
            a += rng.uniform(-0.28, 0.28)

    for _ in range(count):
        u, v = rng.uniform(0, 1), rng.uniform(0, 1)
        if _inside(poly, u, v):
            branch(u * W, v * H, rng.uniform(0, math.tau), depth)


def _draw_crater(art, rng):
    cx, cy = 0.454 * W, 0.506 * H
    rx, ry = 0.088 * W, 0.060 * H
    # чёрная бездна
    art.ellipse(cx / W, cy / H, rx / W, ry / H, fill=(14, 13, 13), alpha=240)
    art.ellipse(cx / W, cy / H, rx * 0.93 / W, ry * 0.90 / H,
                outline=(92, 32, 30), width=2.2, alpha=200)
    # остров в бездне
    art.ellipse(cx / W, cy / H, 0.016, 0.010, fill=(92, 82, 66), outline=INK, width=1.2)
    # коралловое кольцо Лабиринта
    for ring, rad in enumerate([1.06, 1.16, 1.28]):
        for k in range(44):
            a = k / 44 * math.tau + rng.uniform(-0.03, 0.03)
            r0 = rad * (1.0 + rng.uniform(-0.02, 0.02))
            x = cx + math.cos(a) * rx * r0
            y = cy + math.sin(a) * ry * r0
            if not _inside(COAST, x / W, y / H):
                continue
            length = rng.uniform(3, 9) * (1.0 - ring * 0.15)
            art.line([(x, y), (x + math.cos(a) * length, y + math.sin(a) * length)],
                     width=rng.uniform(1.0, 2.0), fill=(126, 26, 30), alpha=175)
            if rng.random() < 0.4:
                art.line([(x, y), (x + rng.uniform(-5, 5), y + rng.uniform(-5, 5))],
                         width=1.0, fill=(150, 38, 38), alpha=140)


def _draw_skeleton(art):
    bone = (214, 202, 178)
    dark = (82, 68, 56)
    cx, cy = 0.505 * W, 0.652 * H
    # череп
    art.ellipse(cx / W, cy / H, 0.023, 0.020, fill=bone, outline=INK, width=1.6)
    art.ellipse((cx - 11) / W, (cy - 2) / H, 0.007, 0.008, fill=dark, alpha=240)
    art.ellipse((cx + 11) / W, (cy - 2) / H, 0.007, 0.008, fill=dark, alpha=240)
    art.line([(cx - 8, cy + 9), (cx + 8, cy + 9)], width=1.3, fill=INK, alpha=220)
    # позвоночник
    spine = []
    for k in range(16):
        t = k / 15.0
        spine.append((cx + math.sin(t * 2.4) * 9 - t * 6, cy + 22 + t * 260))
    art.line(spine, width=5.0, fill=bone, alpha=235)
    art.line(spine, width=1.2, fill=dark, alpha=160)
    # рёбра
    for i in range(9):
        t = i / 8.0
        x0, y0 = spine[2 + int(t * 9)]
        span = 118 * math.sin(math.pi * (0.20 + 0.72 * t)) + 24
        for side in (-1, 1):
            pts = []
            for k in range(9):
                s = k / 8.0
                pts.append((x0 + side * span * math.sin(s * 1.45),
                            y0 + 18 * s + 30 * s * s))
            art.line(pts, width=5.0, fill=bone, alpha=220)
            art.line(pts, width=1.0, fill=dark, alpha=140)
    # руки
    for side in (-1, 1):
        sh = (spine[3][0] + side * 34, spine[3][1] - 6)
        el = (sh[0] + side * 86, sh[1] + 72)
        hand = (el[0] + side * 30, el[1] + 94)
        art.line([sh, el, hand], width=6.0, fill=bone, alpha=225)
        art.line([sh, el, hand], width=1.2, fill=dark, alpha=130)
        for k in range(3):
            art.line([hand, (hand[0] + side * (10 + k * 4), hand[1] + 14 + k * 3)],
                     width=1.6, fill=bone, alpha=220)


def _draw_isles(art, rng):
    scaled = []
    for u, v, rx, ry, rot, who in ISLES:
        scaled.append((u, v, rx * 0.82, ry * 0.82, rot, who))

    # Цепи между островами — под островами, чтобы концы прятались под камнем.
    for a, b in [(0, 1), (1, 2), (1, 3), (3, 5), (4, 5), (5, 6), (5, 7), (2, 7)]:
        u0, v0, _, r0, _, _ = scaled[a]
        u1, v1, _, r1, _, _ = scaled[b]
        y0 = v0 + r0 * 0.7
        y1 = v1 + r1 * 0.7
        art.d.line([(u0 * W * S, y0 * H * S), (u1 * W * S, y1 * H * S)],
                   fill=(30, 28, 24, 210), width=4 * S)
        art.d.line([(u0 * W * S, y0 * H * S), (u1 * W * S, y1 * H * S)],
                   fill=(124, 114, 94, 235), width=2 * S)
        for k in range(7):
            t = (k + 0.5) / 7
            x = (u0 + (u1 - u0) * t) * W * S
            y = (y0 + (y1 - y0) * t) * H * S
            art.d.ellipse([x - 2.4 * S, y - 1.4 * S, x + 2.4 * S, y + 1.4 * S],
                          outline=(154, 142, 116, 230), width=S)

    for u, v, rx, ry, rot, _who in scaled:
        # тень на бездне
        art.ellipse((u + 0.004) / 1.0, (v + ry * 1.3) / 1.0, rx * 1.05, ry * 0.55,
                    fill=(12, 20, 22), alpha=90)
        # нижняя скала
        under = [(u - rx, v), (u - rx * 0.52, v + ry * 1.5), (u, v + ry * 2.1),
                 (u + rx * 0.55, v + ry * 1.45), (u + rx, v)]
        art.polygon([_px(p) for p in under], fill=(52, 46, 38), outline=INK, width=1.3)
        art.polygon([_px(p) for p in [(u - rx, v), (u + rx, v), (u + rx, v + ry * 0.35),
                                       (u - rx, v + ry * 0.35)]],
                    fill=(92, 80, 58), alpha=225)
        # зелёная шапка
        top = []
        for k in range(18):
            a = k / 18 * math.tau
            rr = 1.0 + 0.15 * math.sin(a * 3 + rot)
            top.append((u + math.cos(a) * rx * rr, v + math.sin(a) * ry * rr))
        art.polygon([_px(p) for p in top], fill=(62, 86, 50), outline=INK, width=1.4)
        # штриховка травы
        for k in range(5):
            y = v + rng.uniform(-ry * 0.55, ry * 0.55)
            art.line([((u - rx * 0.65) * W, y * H),
                      ((u + rx * 0.55) * W, y * H + rng.uniform(-3, 3))],
                     width=0.8, fill=(38, 54, 32), alpha=90)
        for _ in range(5):
            tu = u + rng.uniform(-rx * 0.55, rx * 0.55)
            tv = v + rng.uniform(-ry * 0.35, ry * 0.35)
            _tree(art, tu * W, tv * H, rng.uniform(6, 9), False, rng)


def _draw_route(art, pts, kind):
    if kind == "road":
        smooth = P.smooth_curve([_px(p) for p in pts], 8)
        art.d.line([(x * S, y * S) for x, y in smooth], fill=(78, 56, 34, 215),
                   width=int(3.2 * S), joint="curve")
        art.d.line([(x * S, y * S) for x, y in smooth], fill=(226, 210, 174, 235),
                   width=int(1.6 * S), joint="curve")
        # пунктир поверх
        for i in range(len(smooth) - 1):
            x0, y0 = smooth[i]
            x1, y1 = smooth[i + 1]
            d = math.hypot(x1 - x0, y1 - y0)
            if d < 1e-3:
                continue
            art.d.line([(x0 * S, y0 * S), (x1 * S, y1 * S)],
                       fill=(70, 50, 30, 220), width=S)
    elif kind == "sea":
        for i in range(len(pts) - 1):
            x0, y0 = _px(pts[i])
            x1, y1 = _px(pts[i + 1])
            steps = max(1, int(math.hypot(x1 - x0, y1 - y0) / (7 * S)))
            for k in range(steps):
                t0 = k / steps
                t1 = min(1.0, (k + 0.45) / steps)
                art.d.line([((x0 + (x1 - x0) * t0) * S, (y0 + (y1 - y0) * t0) * S),
                            ((x0 + (x1 - x0) * t1) * S, (y0 + (y1 - y0) * t1) * S)],
                           fill=SEA_INK + (150,), width=S)
    else:
        smooth = P.smooth_curve([_px(p) for p in pts], 10)
        art.d.line([(x * S, y * S) for x, y in smooth], fill=(74, 112, 118, 220),
                   width=int(3.0 * S), joint="curve")
        art.d.line([(x * S, y * S) for x, y in smooth], fill=(128, 178, 178, 210),
                   width=int(1.2 * S), joint="curve")


def _region_title(art, reg, occupied):
    u, v = reg["label"]
    size = reg.get("label_size", 30)
    color = reg.get("title_fill", INK)
    stroke = reg.get("title_stroke", PAPER_LIGHT)
    font = _font(size * S, True, False)
    x, y = u * W, v * H
    w = art.d.textlength(reg["title"], font=font) / S
    art.text((x, y), reg["title"], size, fill=color, bold=True, spacing=3.2,
             stroke=2.0, stroke_fill=stroke)
    sub = reg["subtitle"].upper()
    sub_size = max(11, int(size * 0.42))
    art.text((x, y + size * 1.02), sub, sub_size, fill=color, spacing=2.2,
             stroke=1.2, stroke_fill=stroke, alpha=215)
    occupied.append((x - w / 2 - 6, y - size * 0.8,
                     w + 12, size * 2.0))


def _sea_labels(art, occupied):
    labels = [
        ("ЗАЛИВ ТИШИНЫ", 0.862, 0.742, 13, True),
    ]
    for text, u, v, size, dark in labels:
        fill = (232, 224, 198) if dark else (44, 72, 82)
        stroke = (28, 40, 48) if dark else (224, 216, 190)
        _place_label(art, occupied, (u * W, v * H), text, size, fill, stroke,
                     spacing=3.4, italic=True, delta=(0, 0))


def _draw_harbor(art, rng):
    # Корабль в Штормовом море: тёмный корпус и светлые паруса.
    x, y = 0.088 * W, 0.955 * H
    hull = [(x - 72, y), (x + 68, y), (x + 44, y + 24), (x - 54, y + 24)]
    art.polygon(hull, fill=(46, 36, 24), outline=INK, width=1.8)
    art.d.line([((x - 58) * S, (y + 5) * S), ((x + 54) * S, (y + 5) * S)],
               fill=(196, 170, 120, 220), width=2 * S)
    masts = [(-34, 92, 30), (2, 118, 40), (40, 82, 26)]
    for dx, h, sail_w in masts:
        mx = x + dx
        art.d.line([(mx * S, (y - 4) * S), (mx * S, (y - h) * S)],
                   fill=INK + (235,), width=2 * S)
        # Парус — выпуклый четырёхугольник, привязанный к мачте и рее.
        sail = [(mx + 4, y - h + 8), (mx + sail_w, y - h + 26),
                (mx + sail_w - 6, y - 34), (mx + 4, y - 26)]
        art.polygon(sail, fill=(226, 211, 178), outline=INK, width=1.1, alpha=238)
        art.line([(mx, y - h + 8), (mx + sail_w, y - h + 26)],
                 fill=INK, width=1.0, alpha=190)
    # Флаг.
    art.polygon([(x + 2, y - 118), (x + 30, y - 108), (x + 2, y - 98)],
                fill=(120, 38, 32), outline=INK, width=1.0)
    art.d.line([(x + 2) * S, (y - 118) * S, (x + 2) * S, (y - 98) * S],
               fill=INK + (220,), width=2 * S)


def render(path):
    rng = np.random.default_rng(1729)
    color = _paper(rng)
    paper_color = color.copy()

    masks = {}
    for reg in REGIONS:
        masks[reg["id"]] = P.polygon_mask(H, W, [_px(p) for p in reg["outline"]], 2.2)
    coast_mask = P.polygon_mask(H, W, [_px(p) for p in COAST], 2.4)

    land = np.clip(coast_mask, 0, 1)
    sea = 1.0 - land

    sea_col, _dist = _sea_color(land, rng)
    color = P.mix(color, sea_col, sea)

    # Тёмная бездна залива Скованных островов.
    bay_mask = P.polygon_mask(H, W, [_px(p) for p in BAY], 4.0)
    color = P.mix(color, np.array([0.085, 0.125, 0.135], np.float32)[None, None, :],
                  bay_mask * 0.60)

    land_col = paper_color.copy()
    for reg in REGIONS:
        if reg["id"] not in LAND_IDS:
            continue
        m = np.clip(masks[reg["id"]] * coast_mask, 0, 1)
        tex = P.fbm(H, W, 24, 3, rng)
        wash = P.tint(reg["color"]) * (0.92 + 0.18 * (tex[..., None] - 0.5))
        land_col = P.mix(land_col, wash, m * reg["opacity"])

    # Внутренняя тень по краям регионов — акварельный «наплыв».
    for reg in REGIONS:
        if reg["id"] not in LAND_IDS:
            continue
        m = np.clip(masks[reg["id"]] * coast_mask, 0, 1)
        edge = np.clip(m - ndimage.gaussian_filter(m, 13), 0, 1)
        land_col *= (1.0 - 0.16 * edge[..., None])

    # Пепельный вал вокруг Забытого берега: закрывает разрыв между красной
    # чашей кратера и Полыми горами и не даёт проступить «морю» внутри суши.
    fs_mask = np.clip(masks["region_forgotten_shore"] * coast_mask, 0, 1)
    rim_band = np.clip(ndimage.gaussian_filter(fs_mask, 22.0) - fs_mask, 0, 1)
    rim_band = np.clip(rim_band * 4.2, 0, 1)
    land_col = P.mix(land_col, P.tint((52, 46, 40)), rim_band * 0.78)
    inner_edge = np.clip(fs_mask - ndimage.gaussian_filter(fs_mask, 4.0), 0, 1)
    land_col = P.mix(land_col, P.tint((104, 28, 24)), inner_edge * 0.35)

    color = land_col * land[..., None] + sea_col * sea[..., None]

    # Кратер Забытого берега.
    cx, cy = 0.454 * W, 0.506 * H
    rx, ry = 0.088 * W, 0.060 * H
    e = np.sqrt(((np.arange(W)[None, :] - cx) / rx) ** 2 +
                ((np.arange(H)[:, None] - cy) / ry) ** 2).astype(np.float32)
    hole = np.clip((1.0 - e) * 3.4, 0, 1)
    color = P.mix(color, np.array([0.055, 0.050, 0.050], np.float32)[None, None, :], hole * 0.94)
    rim = np.exp(-((e - 1.0) / 0.09) ** 2)
    color = P.mix(color, np.array([0.52, 0.10, 0.10], np.float32)[None, None, :], rim * 0.28)

    # Лёгкая выцветшая виньетка.
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.hypot((xx - W / 2) / (W / 2), (yy - H / 2) / (H / 2))
    color = color * (1.0 - 0.10 * np.clip(d - 0.55, 0, 1) ** 1.4)[..., None]

    base = Image.fromarray((np.clip(color, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")
    base = base.resize((W2, H2), Image.LANCZOS)
    art = _Art(base)
    rng2 = np.random.default_rng(90210)

    _draw_sea(art, rng2, land)
    _draw_desert(art, rng2)
    _draw_mesas(art, rng2)
    _draw_ice(art, rng2)
    _draw_embers(art, rng2)
    _draw_fields(art, rng2)
    _draw_cracks(art, rng2, "region_forgotten_shore", (48, 12, 12), 34, 3)
    _draw_cracks(art, rng2, "region_shattered_lands", (62, 40, 20), 30, 3)
    _draw_cracks(art, rng2, "region_basin", (38, 52, 26), 12, 2)
    _draw_mountains(art, rng2)
    _draw_forests(art, rng2)
    _draw_skeleton(art)
    _draw_bones(art, rng2)
    _draw_isles(art, rng2)
    _draw_crater(art, rng2)
    _draw_harbor(art, rng2)

    for pts in ROADS:
        _draw_route(art, pts, "road")
    for pts in SEA_ROUTES:
        _draw_route(art, pts, "sea")
    for pts in RIVERS:
        _draw_route(art, pts, "river")

    # Легкое размытие живописи до подписей: убирает «цифровую» резкость
    # тонких штрихов, оставляя акварельную мягкость. Текст и значки ниже
    # рисуются уже по чистому слою и остаются резкими.
    art.img = art.img.filter(ImageFilter.GaussianBlur(1.1))
    art.d = ImageDraw.Draw(art.img)

    # Рамка, титул, легенда.
    _draw_frame(art)
    _draw_title(art)
    occupied = []
    _draw_legend(art, occupied)

    # Подписи регионов — до мест, чтобы места обходили их.
    for reg in REGIONS:
        _region_title(art, reg, occupied)

    # Места: значок + подпись с поиском свободного места.
    for pid, label, desc, u, v, kind, icon, light in PLACES:
        if icon != "label":
            _icon(art, icon, u, v, size=18, ink=CREAM if light else INK,
                  fill=DARK_PANEL if light else PAPER_LIGHT, light=light)
        ink = CREAM if light else INK
        stroke = (28, 26, 22) if light else PAPER_LIGHT
        size = 15 if len(label) < 20 else 14
        at = (u * W, v * H)
        candidates = [(0, -21), (0, 23), (34, 0), (-34, 0), (34, -18), (-34, 18),
                      (0, -36), (0, 38), (52, 8), (-52, -8)]
        for dx, dy in candidates:
            if _place_label(art, occupied, at, label, size, ink, stroke, delta=(dx, dy)):
                break

    for text, u, v, size, spacing, light, italic in NOTES:
        ink = CREAM if light else INK_SOFT
        stroke = (28, 26, 22) if light else PAPER_LIGHT
        at = (u * W, v * H)
        for dx, dy in [(0, 0), (0, -18), (0, 18)]:
            if _place_label(art, occupied, at, text, size, ink, stroke,
                            spacing=spacing, italic=italic, delta=(dx, dy)):
                break

    _sea_labels(art, occupied)

    out = art.img.convert("RGB").resize((W, H), Image.LANCZOS)
    # Мягкая финальная линза: гасит муар тонких штрихов при масштабировании.
    out = out.filter(ImageFilter.GaussianBlur(0.35))
    out.save(path, optimize=True)
    return out


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    target = os.path.join(here, "..", "..", "assets", "ui", "map", "dream_realm.png")
    render(os.path.abspath(target))
    print("ok:", target)
