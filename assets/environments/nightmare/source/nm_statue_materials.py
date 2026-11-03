"""Материалы колосса безголового рыцаря (без bpy).

Субстрат камня — CC0 Poly Haven `low_tide_rocks`; металл — `rust_coarse_01`.
Смысл: тёмный морской базальт/диорит, светлые сколы и кромки, бронзовые вставки,
холодные звёзды. Никаких светящихся рун и «магии» на камне.
"""

TEXSETS = {
    "statue_stone": dict(albedo="low_tide_rocks_diff_2k.jpg", normal="low_tide_rocks_nor_gl_2k.jpg",
                          arm="low_tide_rocks_arm_2k.jpg", tile=3.6),
    "statue_metal": dict(albedo="rust_coarse_01_diff_1k.jpg", normal="rust_coarse_01_nor_gl_1k.jpg",
                         arm="rust_coarse_01_arm_1k.jpg", tile=0.9),
}

MATERIALS = {
    # Основной камень: тёмный сине-серый, влажный у воды, с солью в трещинах.
    "nm_statue_dark": dict(kind="statue", base="statue_stone", tint=(0.32, 0.31, 0.30), normal=1.25,
                           rough_scale=0.95, rough_offset=0.02, metallic=0.0,
                           wet_strength=0.55, salt_strength=0.35, preview=(0.08, 0.09, 0.11)),
    # Сколы, кромки, выветренные плоскости: светлее и суше.
    "nm_statue_pale": dict(kind="statue", base="statue_stone", tint=(0.64, 0.62, 0.58), normal=1.15,
                           rough_scale=1.0, rough_offset=0.04, metallic=0.0,
                           wet_strength=0.40, salt_strength=0.45, preview=(0.28, 0.30, 0.33)),
    # Бронза/старое железо: тонкие пояса, заклёпки, кромки меча.
    "nm_statue_bronze": dict(kind="statue", base="statue_stone", tint=(0.22, 0.14, 0.08), normal=1.0,
                             rough_scale=1.0, rough_offset=0.02, metallic=0.65,
                             wet_strength=0.45, salt_strength=0.30, preview=(0.12, 0.07, 0.035)),
    # Семь звёзд: холодный камень/металл с мягким свечением.
    "nm_statue_star": dict(kind="plain", color=(0.42, 0.38, 0.30), rough=0.34, metallic=0.25,
                           emission=(0.10, 0.08, 0.04), emission_energy=0.85,
                           preview=(0.62, 0.78, 0.98)),
    # Тёмные швы трещин и провалы.
    "nm_statue_crack": dict(kind="plain", color=(0.012, 0.014, 0.018), rough=0.95,
                            preview=(0.012, 0.014, 0.018)),
}
