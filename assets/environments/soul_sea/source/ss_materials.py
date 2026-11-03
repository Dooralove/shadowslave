"""Материалы Моря Души для Blender-превью и GLB-слотов.

Слоты `ss_*` — только имена материалов. В Godot они подменяются внешними
`.tres` (см. `docs/art/soul_sea_model_map.md` §7). Текстуры не встраиваются
в GLB: `nm_lib.export_collection` экспортирует только слоты.

`ss_obsidian` и `ss_basalt` используют уже существующие CC0/производные
текстуры Nightmare-кита (`nm_marble_black`, `dark_rock_02`), поэтому новых
лицензий для P0 не требуется.
"""

MATERIALS = {
    # Почти чёрный влажный камень помоста, обелисков и плинтов.
    "ss_obsidian": dict(
        kind="layered", base="marble", tint=(0.28, 0.34, 0.46),
        normal=0.9, bump=0.012, rough_scale=0.72, rough_offset=0.08,
        snow=False, preview=(0.015, 0.02, 0.03),
    ),
    # Слоистый базальт скал и дальних осколков.
    "ss_basalt": dict(
        kind="layered", base="rock", tint=(0.30, 0.36, 0.46),
        normal=1.0, bump=0.028, rough_scale=0.92, rough_offset=0.06,
        snow=False, preview=(0.025, 0.032, 0.045),
    ),
    # Тени убитых существ: почти чёрный силуэт; в Godot — soul_sea_shade.gdshader.
    "ss_shadow": dict(
        kind="plain", color=(0.006, 0.008, 0.012), rough=0.96,
        preview=(0.008, 0.01, 0.016),
    ),
    # Хитин карапаксов/центуриона: тёмный, слегка металлический.
    "ss_chitin": dict(
        kind="plain", color=(0.012, 0.017, 0.026), rough=0.42, metallic=0.28,
        preview=(0.018, 0.026, 0.04),
    ),
    # Память: тёплое ядро; в Godot — soul_sea_memory.gdshader.
    "ss_memory": dict(
        kind="plain", color=(0.82, 0.42, 0.14), rough=0.32,
        emission=(1.0, 0.50, 0.18), emission_energy=1.2,
        preview=(1.0, 0.62, 0.28),
    ),
    # Эхо: холоднее и плотнее Памяти.
    "ss_echo": dict(
        kind="plain", color=(0.14, 0.28, 0.68), rough=0.28,
        emission=(0.20, 0.42, 1.0), emission_energy=1.0,
        preview=(0.28, 0.5, 1.0),
    ),
    # Световые линии/проекции орбит.
    "ss_sigil": dict(
        kind="plain", color=(0.85, 0.55, 0.22), rough=0.38,
        emission=(1.0, 0.58, 0.24), emission_energy=1.4,
        preview=(1.0, 0.7, 0.36),
    ),
    # Плоские карты тумана: прозрачные, без теней.
    "ss_mist": dict(
        kind="plain", color=(0.34, 0.44, 0.58), rough=0.82, alpha=0.18,
        emission=(0.10, 0.16, 0.24), emission_energy=0.20,
        preview=(0.34, 0.44, 0.58),
    ),
    # Плоские ряби/пена: прозрачные, без теней.
    "ss_ripple": dict(
        kind="plain", color=(0.32, 0.48, 0.66), rough=0.18, alpha=0.22,
        emission=(0.18, 0.32, 0.48), emission_energy=0.35,
        preview=(0.32, 0.48, 0.66),
    ),
}

# Новых текстурных наборов нет: используем `marble` и `rock` из nm_materials.
TEXSETS = {}
