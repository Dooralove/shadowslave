"""Материалы кораллового кита Забытого берега (без bpy).

Читают:
- `nm_coral_lib.py` / `build_coral_kit.py` — Blender-превью;
- `make_godot_materials.py --family coral` — `.tres` и `.import`.

Палитра: docs/design/forgotten_shore_labyrinth_research.md §9.8.
"""

TEXSETS = {
    # CC0 Poly Haven: окаменелый коралловый массив (Rob Tuytel / Dimitrios Savva).
    # Это субстрат поверхности; красный цвет и кончики даёт tint + vertex mask.
    "coral_live": dict(albedo="coral_fort_wall_01_diff_2k.jpg", normal="coral_fort_wall_01_nor_gl_2k.jpg",
                       arm="coral_fort_wall_01_arm_2k.jpg", tile=2.2),
    "coral_dead": dict(albedo="coral_fort_wall_02_diff_2k.jpg", normal="coral_fort_wall_02_nor_gl_2k.jpg",
                       arm="coral_fort_wall_02_arm_2k.jpg", tile=2.0),
    "coral_crust": dict(albedo="coral_fort_wall_03_diff_2k.jpg", normal="coral_fort_wall_03_nor_gl_2k.jpg",
                        arm="coral_fort_wall_03_arm_2k.jpg", tile=0.9),
    "bone_aged": dict(albedo="nm_bone_aged_diff_1k.jpg", normal="nm_bone_aged_nor_gl_1k.jpg",
                      arm="nm_bone_aged_arm_1k.jpg", tile=0.7),
    # CC0-подложка Poly Haven: коралловый грунт и мокрый ил.
    "coral_ground": dict(albedo="coral_ground_02_diff_2k.jpg", normal="coral_ground_02_nor_gl_2k.jpg",
                         arm="coral_ground_02_arm_2k.jpg", tile=3.0),
    "mud_wet": dict(albedo="coral_mud_01_diff_2k.jpg", normal="coral_mud_01_nor_gl_2k.jpg",
                    arm="coral_mud_01_arm_2k.jpg", tile=3.2),
}

MATERIALS = {
    # Живой коралл: тёмный багровый, светлые кончики, мокрые нижние участки.
    "nm_coral_live": dict(kind="coral", base="coral_live", tint=(0.15, 0.027, 0.033), normal=1.4,
                          rough_scale=1.0, rough_offset=0.0, metallic=0.0,
                          tip_color=(0.477, 0.155, 0.133), tip_strength=0.55, dead_strength=0.20,
                          wet_strength=0.35, sss=0.22, preview=(0.29, 0.11, 0.13)),
    # Мёртвый/обломанный коралл: светлее, суше, без SSS.
    "nm_coral_dead": dict(kind="coral", base="coral_dead", tint=(0.22, 0.15, 0.14), normal=1.2,
                          rough_scale=1.0, rough_offset=0.06, metallic=0.0,
                          tip_color=(0.638, 0.570, 0.462), tip_strength=0.15, dead_strength=0.0,
                          wet_strength=0.15, sss=0.0, preview=(0.50, 0.42, 0.40)),
    # Корка/ракушки: мелкий масштаб, светлые балянусы.
    "nm_coral_crust": dict(kind="coral", base="coral_crust", tint=(0.38, 0.22, 0.19), normal=1.3,
                           rough_scale=1.0, rough_offset=0.02, metallic=0.0,
                           tip_color=(0.692, 0.638, 0.538), tip_strength=0.30, dead_strength=0.25,
                           wet_strength=0.30, sss=0.0, preview=(0.44, 0.36, 0.34)),
    # Коралловый грунт: подложка Poly Haven, тёмная, с обломками.
    "nm_coral_ground": dict(kind="coral", base="coral_ground", tint=(0.10, 0.05, 0.05), normal=1.1,
                            rough_scale=1.08, rough_offset=0.04, metallic=0.0,
                            tip_color=(0.319, 0.196, 0.163), tip_strength=0.10, dead_strength=0.5,
                            wet_strength=0.45, sss=0.0, preview=(0.16, 0.09, 0.09)),
    # Мокрый ил: почти чёрный, сине-фиолетовый, гладкий в лужах.
    "nm_mud_wet": dict(kind="coral", base="mud_wet", tint=(0.015, 0.018, 0.028), normal=1.0,
                       rough_scale=0.82, rough_offset=-0.04, metallic=0.0,
                       tip_color=(0.20, 0.24, 0.30), tip_strength=0.0, dead_strength=0.0,
                       wet_strength=0.80, sss=0.0, preview=(0.08, 0.06, 0.09)),
    # Старая кость: тёплая, пористая, без снега.
    "nm_bone_aged": dict(kind="coral", base="bone_aged", tint=(1.0, 1.0, 1.0), normal=1.0,
                         rough_scale=1.0, rough_offset=0.06, metallic=0.0,
                         tip_color=(0.787, 0.711, 0.570), tip_strength=0.15, dead_strength=0.0,
                         wet_strength=0.25, sss=0.05, preview=(0.72, 0.68, 0.60)),
}
