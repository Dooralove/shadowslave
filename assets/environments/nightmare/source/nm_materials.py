"""Единое описание материалов Первого Кошмара (без bpy).

Читают два потребителя:
- `nm_lib.py` — строит ноды материалов Blender для превью-рендеров;
- `make_godot_materials.py` — пишет `.tres` для Godot (`materials/*.tres`).

Имя материала = имя слота в .glb; Godot подменяет слот внешним `.tres` через `.import`.

kind:
- "plain" — `StandardMaterial3D` без текстур (цвет, шероховатость, эмиссия): угли, ягоды.
- "layered" — трипланарный шейдер `nm_layered_triplanar.gdshader`: слой + снег сверху,
  маска грязи/снега из цветового атрибута вершин (`nm_mask`). UV не нужны.
- "uv" — `ORMMaterial3D` по UV в метрах (дерево, железо, ткань, кожа): волокно и
  направление рисунка задаются развёрткой, а не проекцией.
"""

# Наборы текстур: файлы в materials/textures/, tile — реальный размер тайла, м.
# Альбедо nm_* — производные `make_nm_textures.py`; остальное — CC0 Poly Haven как есть.
TEXSETS = {
    "rock": dict(albedo="nm_rock_albedo_2k.jpg", normal="dark_rock_02_nor_gl_2k.jpg",
                 arm="dark_rock_02_arm_2k.jpg", height="dark_rock_02_disp_2k.jpg", tile=2.0),
    "stone_worked": dict(albedo="nm_stone_worked_albedo_2k.jpg", normal="rock_surface_nor_gl_2k.jpg",
                         arm="rock_surface_arm_2k.jpg", height="rock_surface_disp_2k.jpg", tile=1.6),
    "snow": dict(albedo="nm_snow_albedo_2k.jpg", normal="snow_02_nor_gl_2k.jpg",
                 arm="snow_02_arm_2k.jpg", height="snow_02_disp_2k.jpg", tile=3.0),
    "marble": dict(albedo="nm_marble_black_albedo_2k.jpg", normal="nm_marble_black_nor_gl_2k.jpg",
                   arm="nm_marble_black_arm_2k.jpg", height="nm_marble_black_disp_2k.jpg", tile=3.0),
    "bone": dict(albedo="nm_bone_albedo_1k.jpg", normal="rock_surface_nor_gl_2k.jpg",
                 arm="rock_surface_arm_2k.jpg", height="rock_surface_disp_2k.jpg", tile=0.6),
    "wood": dict(albedo="rough_wood_diff_1k.jpg", normal="rough_wood_nor_gl_1k.jpg",
                 arm="rough_wood_arm_1k.jpg", height="rough_wood_disp_1k.jpg", tile=0.5),
    "iron": dict(albedo="nm_iron_albedo_1k.jpg", normal="rust_coarse_01_nor_gl_1k.jpg",
                 arm="rust_coarse_01_arm_1k.jpg", height="rust_coarse_01_disp_1k.jpg", tile=0.6),
    "linen": dict(albedo="nm_linen_albedo_1k.jpg", normal="rough_linen_nor_gl_1k.jpg",
                  arm="rough_linen_arm_1k.jpg", height="rough_linen_disp_1k.jpg", tile=0.27),
    "leather": dict(albedo="brown_leather_diff_1k.jpg", normal="brown_leather_nor_gl_1k.jpg",
                    arm="brown_leather_arm_1k.jpg", height="brown_leather_disp_1k.jpg", tile=0.4),
}

# tint — множитель альбедо (линейный); rough_scale/offset — поправка шероховатости ORM;
# normal — сила карты нормалей; bump — высота рельефа для превью Blender, м;
# snow — снег сверху (только layered); coverage — доля «вверх смотрящих» поверхностей под
# снегом; preview — цвет вьюпорта и цвет слота в .glb.
MATERIALS = {
    # Скальная порода перевала (CANON: тёмный камень; палитра — mountain_pass_environment_art.md).
    "nm_rock": dict(kind="layered", base="rock", tint=(1.0, 1.0, 1.0), normal=1.0, bump=0.06,
                    snow=True, coverage=0.3, preview=(0.05, 0.06, 0.075)),
    # Обработанный камень: плиты старой дороги, бордюры, ступени.
    "nm_stone_worked": dict(kind="layered", base="stone_worked", tint=(1.0, 1.0, 1.0), normal=0.9, bump=0.03,
                            snow=True, coverage=0.3, preview=(0.1, 0.11, 0.12)),
    # Снег — отдельная геометрия (надувы, карнизы, заполнение между плитами).
    "nm_snow": dict(kind="layered", base="snow", tint=(1.0, 1.0, 1.0), normal=0.3, bump=0.01,
                    snow=False, preview=(0.6, 0.64, 0.67)),
    # Лёд: наплывы и корка — холодный, глаже снега; не зеркало (бриф перевала, §4). Темнее снега:
    # сквозь прозрачный лёд просвечивает чёрный камень, белые только пузырьковые прожилки.
    "nm_ice": dict(kind="layered", base="snow", tint=(0.32, 0.4, 0.47), normal=0.35, bump=0.004,
                   rough_scale=0.3, rough_offset=0.0, snow=False, preview=(0.45, 0.55, 0.6)),
    # Чёрный мрамор храма (CANON гл. 14); снег ложится на верхние грани обломков.
    "nm_marble_black": dict(kind="layered", base="marble", tint=(1.0, 1.0, 1.0), normal=0.8, bump=0.01,
                            snow=True, coverage=0.38, preview=(0.03, 0.03, 0.035)),
    # Алтарь: тот же мрамор, но снег на него не ложится (CANON: единственное сухое и чистое место).
    "nm_marble_altar": dict(kind="layered", base="marble", tint=(0.92, 0.92, 0.95), normal=0.6, bump=0.006,
                            rough_scale=0.85, snow=False, preview=(0.025, 0.025, 0.03)),
    # Кость людей и чудовищ: желтовато-серая, не белее снега.
    "nm_bone": dict(kind="layered", base="bone", tint=(1.0, 1.0, 1.0), normal=0.5, bump=0.004,
                    snow=True, coverage=0.25, preview=(0.42, 0.39, 0.32)),
    # Дерево повозки, клиньев, бочек, дров: выветренное серо-коричневое.
    "nm_wood": dict(kind="uv", base="wood", tint=(0.92, 0.9, 0.88), normal=1.0, bump=0.004,
                    preview=(0.15, 0.13, 0.11)),
    # Тёмное дерево: ось, днище, старые балки, обугленные дрова.
    "nm_wood_dark": dict(kind="uv", base="wood", tint=(0.5, 0.46, 0.43), normal=1.0, bump=0.004,
                         preview=(0.07, 0.06, 0.05)),
    # Кованое железо: цепи, кандалы, ободья, скобы (тёмный металл + ржавчина #754432).
    "nm_iron": dict(kind="uv", base="iron", tint=(1.0, 1.0, 1.0), normal=1.0, bump=0.003,
                    metallic=0.35, preview=(0.05, 0.04, 0.035)),
    # Мешковина, грубое полотно тента.
    "nm_linen": dict(kind="uv", base="linen", tint=(1.0, 1.0, 1.0), normal=1.0, bump=0.002,
                     preview=(0.22, 0.17, 0.1)),
    # Кожа: фляги, ремни, упряжь.
    "nm_leather": dict(kind="uv", base="leather", tint=(0.8, 0.78, 0.76), normal=1.0, bump=0.002,
                       preview=(0.08, 0.03, 0.01)),
    # Верёвка и обвязка груза: тёмная пенька.
    "nm_rope": dict(kind="uv", base="linen", tint=(0.55, 0.5, 0.42), normal=1.0, bump=0.002,
                    preview=(0.12, 0.09, 0.06)),
    # Кора и сухие ветки куста Bloodbane: почти чёрное дерево.
    "nm_bark": dict(kind="uv", base="wood", tint=(0.28, 0.25, 0.24), normal=1.0, bump=0.003,
                    preview=(0.04, 0.035, 0.03)),
    # Обугленное дерево костра.
    "nm_charcoal": dict(kind="uv", base="wood", tint=(0.12, 0.11, 0.105), normal=1.0, bump=0.004,
                        rough_scale=1.0, preview=(0.02, 0.02, 0.02)),
    # Угли: тусклое тёплое свечение (бриф перевала: факел/огонь #C58A4D, сердцевина #F2C78D).
    "nm_ember": dict(kind="plain", color=(0.09, 0.03, 0.01), rough=0.85,
                     emission=(1.0, 0.36, 0.08), emission_energy=2.5, preview=(0.6, 0.2, 0.05)),
    # Зола под костром.
    "nm_ash": dict(kind="plain", color=(0.16, 0.155, 0.15), rough=1.0, preview=(0.16, 0.155, 0.15)),
    # Чёрствый хлеб рабов: CANON «маленький кусок твёрдого, заплесневелого хлеба» (гл. 2).
    "nm_bread": dict(kind="plain", color=(0.3, 0.19, 0.09), rough=0.9, preview=(0.3, 0.19, 0.09)),
    # Ягоды Bloodbane: CANON «ярко-красные»; не светятся (02_caravan_canon, R5), лёгкий блеск.
    "nm_berry": dict(kind="plain", color=(0.5, 0.012, 0.02), rough=0.32, preview=(0.5, 0.012, 0.02)),
}


def tex(texset, channel):
    return TEXSETS[texset][channel]
