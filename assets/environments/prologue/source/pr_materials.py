"""Материалы пролога (участок и изолятор) и новых моделей парка — одно описание для Blender и Godot.

Формат — как `nightmare/source/nm_materials.py` (тот же конвейер):
- `nm_lib.register_materials(MATERIALS, TEXSETS)` — превью в Blender;
- `make_godot_materials.py --family prologue` — `.tres` в `prologue/materials/`.
Текстуры — имена в `prologue/materials/textures/` или пути от корня проекта (общие наборы).
`external=True` — материал Godot уже живёт в другом наборе (рукописные `.tres` парка S3.2/S3.3):
здесь только цвет для превью Blender, `.tres` не пишется, слот привязывается `--family park`.

Палитра изолятора — бриф `docs/design/level_brief_quarantine_cell.md`, §10 (ориентиры, не канон):
стены #343A40, пол #252D34, накладки кресла #3A3D40, стекло #4B5961, свет дезинфекции #C8E7EB,
индикатор Заклятия #B8B4D8 — единственный цветовой акцент бокса.
"""


def lin(h):
    """sRGB-код → линейный цвет (материалы и tint в этом конвейере линейные)."""
    h = h.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(round(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4, 4))
    return tuple(out)


def tint(h, mean=0.5):
    """Множитель для нейтрального альбедо со средней линейной яркостью mean: итог ≈ цвет h."""
    return tuple(round(c / mean, 4) for c in lin(h))


NM_TEX = "assets/environments/nightmare/materials/textures/"
PARK_TEX = "assets/environments/park/materials/textures/"

TEXSETS = {
    # Порошковая краска / композит: «апельсиновая корка», царапины до металла (B-канал ARM = металл).
    "pr_paint": dict(albedo="pr_paint_albedo_1k.jpg", normal="pr_paint_nor_gl_1k.jpg",
                     arm="pr_paint_arm_1k.jpg", tile=0.8),
    # Нескользкое покрытие пола со следами уборки.
    "pr_coating": dict(albedo="pr_coating_albedo_1k.jpg", normal="pr_coating_nor_gl_1k.jpg",
                       arm="pr_coating_arm_1k.jpg", tile=0.6),
    # Винил накладок: альбедо — обесцвеченная кожа Poly Haven; нормали, ARM и высоты — исходные CC0.
    "pr_vinyl": dict(albedo="pr_vinyl_albedo_1k.jpg", normal=NM_TEX + "brown_leather_nor_gl_1k.jpg",
                     arm=NM_TEX + "brown_leather_arm_1k.jpg", height=NM_TEX + "brown_leather_disp_1k.jpg",
                     tile=0.4),
    # Тканый ремень (саржа), тайл 6 см.
    "pr_webbing": dict(albedo="pr_webbing_albedo_512.jpg", normal="pr_webbing_nor_gl_512.jpg",
                       arm="pr_webbing_arm_512.jpg", tile=0.06),
    # Шлифованная сталь: продольные риски.
    "pr_brushed": dict(albedo="pr_brushed_albedo_1k.jpg", normal="pr_brushed_nor_gl_1k.jpg",
                       arm="pr_brushed_arm_1k.jpg", tile=0.4),
}

MATERIALS = {
    # --- Изолятор: бронестены и потолок — матовый графитовый композит (бриф §6, §10).
    "pr_wall": dict(kind="uv", base="pr_paint", tint=tint("#343A40"), metallic=0.6, normal=1.0, bump=0.002,
                    preview=lin("#343A40")),
    # Заменённая панель: чуть другой тон (бриф §6 «несколько заменённых панелей»).
    "pr_wall_alt": dict(kind="uv", base="pr_paint", tint=tint("#3D4349"), metallic=0.6, normal=1.0, bump=0.002,
                        preview=lin("#3D4349")),
    # Пол: тёмное серо-синее нескользкое покрытие.
    "pr_floor": dict(kind="uv", base="pr_coating", tint=tint("#252D34"), normal=1.0, bump=0.002,
                     preview=lin("#252D34")),
    # Накладки кресла: угольный винил, вытертый.
    "pr_vinyl": dict(kind="uv", base="pr_vinyl", tint=tint("#3A3D40"), normal=1.0, bump=0.001,
                     rough_scale=0.85, preview=lin("#3A3D40")),
    # Ремни: тёмная тканая лента.
    "pr_webbing": dict(kind="uv", base="pr_webbing", tint=tint("#26292D"), normal=1.0, bump=0.0005,
                       preview=lin("#26292D")),
    # Сталь: замки, болты, штурвал, петли, шток (узкие блики кромок).
    "pr_steel": dict(kind="uv", base="pr_brushed", tint=tint("#9EA3A8", 0.55), metallic=0.9, normal=1.0,
                     bump=0.0005, preview=lin("#9EA3A8")),
    # Тёмная сталь: рамы, кронштейны, корпуса, каркас кресла.
    "pr_steel_dark": dict(kind="uv", base="pr_brushed", tint=tint("#3C4146", 0.55), metallic=0.8, normal=1.0,
                          bump=0.0005, preview=lin("#3C4146")),
    # --- Лобби: бронеплиты — окрашенная сталь светлее стен бокса (перекличка с фасадом `station_panel`).
    "pr_armor": dict(kind="uv", base="pr_paint", tint=tint("#4E555C"), metallic=0.9, normal=1.0, bump=0.002,
                     preview=lin("#4E555C")),
    # Столешница стойки: тёмный ламинат.
    "pr_counter": dict(kind="uv", base="pr_paint", tint=tint("#2A2E33"), metallic=0.0, normal=0.5,
                       rough_scale=0.8, bump=0.001, preview=lin("#2A2E33")),
    # Трипланарные версии для CSG-поверхностей, оставшихся в сценах (стены, пол и потолок лобби, коридор изолятора).
    "pr_wall_tri": dict(kind="uv", base="pr_paint", tint=tint("#343A40"), metallic=0.6, triplanar=True,
                        preview=lin("#343A40")),
    "pr_floor_tri": dict(kind="uv", base="pr_coating", tint=tint("#252D34"), triplanar=True, preview=lin("#252D34")),
    "pr_lobby_wall_tri": dict(kind="uv", base="pr_paint", tint=tint("#4A4F56"), metallic=0.2, triplanar=True,
                              preview=lin("#4A4F56")),
    "pr_lobby_floor_tri": dict(kind="uv", base="pr_coating", tint=tint("#30353B"), triplanar=True,
                               preview=lin("#30353B")),
    "pr_lobby_ceiling_tri": dict(kind="uv", base="pr_paint", tint=tint("#24272B"), triplanar=True,
                                 preview=lin("#24272B")),
    # Резина: уплотнители, ножки, кабели, тёмная глубина за решёткой.
    "pr_rubber": dict(kind="plain", color=lin("#141516"), rough=0.9, preview=lin("#141516")),
    # Многослойное дымчатое стекло (бриф Z3: отражает сильнее, чем пропускает).
    "pr_glass": dict(kind="plain", color=lin("#4B5961"), alpha=0.42, rough=0.04, metallic=0.25,
                     preview=lin("#4B5961")),
    # Экраны терминалов: картинка интерфейса в эмиссии, без мелкого текста (бриф Z2); матовое антибликовое стекло.
    "pr_screen_cell": dict(kind="plain", color=lin("#050708"), rough=0.35, emission=(1.0, 1.0, 1.0),
                           emission_energy=1.2, emission_texture="pr_screen_cell.png", preview=(0.05, 0.12, 0.14)),
    "pr_screen_lobby": dict(kind="plain", color=lin("#050708"), rough=0.35, emission=(1.0, 1.0, 1.0),
                            emission_energy=1.2, emission_texture="pr_screen_lobby.png", preview=(0.05, 0.1, 0.12)),
    # Рассеиватель светильника дезинфекции: холодный бело-циановый.
    "pr_light": dict(kind="plain", color=lin("#C8E7EB"), rough=0.4, emission=lin("#C8E7EB"), emission_energy=5.0,
                     preview=lin("#C8E7EB")),
    # Индикатор Заклятия: бледно-лиловый, единственный цветовой акцент бокса (бриф §7).
    "pr_indicator": dict(kind="plain", color=lin("#B8B4D8"), rough=0.3, emission=lin("#B8B4D8"),
                         emission_energy=0.7, preview=lin("#B8B4D8")),
    # Маркировка: тусклая жёлтая краска табличек и полос.
    "pr_marking": dict(kind="plain", color=lin("#8C6F22"), rough=0.55, preview=lin("#8C6F22")),
    # Кнопка тревоги лобби: красный пластик (канон: терминал с кнопкой тревоги).
    "pr_alarm": dict(kind="plain", color=lin("#8E1A14"), rough=0.35, preview=lin("#8E1A14")),
    # Предупредительная лампа двери: янтарный колпак, слабое свечение.
    "pr_lamp_warn": dict(kind="plain", color=lin("#6E4A12"), rough=0.3, emission=lin("#FF9A30"),
                         emission_energy=0.6, preview=lin("#B07020")),
    # Датчик турели: тёмное стекло с тусклым красным огнём.
    "pr_sensor": dict(kind="plain", color=lin("#120606"), rough=0.08, emission=lin("#C02010"),
                      emission_energy=0.8, preview=lin("#601008")),
    # --- Парк (материалы Godot — рукописные .tres парка; здесь цвет для превью Blender).
    "composite_light": dict(kind="plain", external=True, color=lin("#9EA1A6"), rough=0.8, preview=lin("#9EA1A6")),
    "composite_mid": dict(kind="plain", external=True, color=lin("#8C9095"), rough=0.85, preview=lin("#8C9095")),
    # Искусственная зелень: холодный зелёный глянцевый пластик, без вариаций (бриф S3, решение пользователя).
    "foliage_plastic": dict(kind="plain", external=True, color=(0.10, 0.22, 0.17), rough=0.35,
                            preview=(0.10, 0.22, 0.17)),
    "dark_metal": dict(kind="plain", external=True, color=(0.08, 0.085, 0.09), rough=0.4, metallic=0.8,
                       preview=(0.08, 0.085, 0.09)),
    # Фасад участка: стена объёма и бронепанели (рукописные .tres S3.1–S3.2), новое стекло и полоса света входа.
    "station": dict(kind="plain", external=True, color=lin("#6E737A"), rough=0.8, preview=lin("#6E737A")),
    "station_panel": dict(kind="plain", external=True, color=lin("#5A6068"), rough=0.5, metallic=0.6,
                          preview=lin("#5A6068")),
    "station_glass": dict(kind="plain", external=True, color=(0.03, 0.04, 0.05), rough=0.05, metallic=0.6,
                          preview=(0.03, 0.04, 0.05)),
    "entrance_light": dict(kind="plain", external=True, color=(0.55, 0.66, 0.85), rough=0.4,
                           emission=(0.55, 0.66, 1.0), emission_energy=3.0, preview=(0.55, 0.66, 0.85)),
    # Матовый рассеиватель фонаря (утром выключен).
    "lamp_lens": dict(kind="plain", external=True, color=(0.6, 0.62, 0.64), rough=0.3, preview=(0.6, 0.62, 0.64)),
}
