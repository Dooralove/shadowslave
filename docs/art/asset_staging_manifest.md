# Манифест staged-ассетов Poly Haven (G1)

**Дата:** 2026-11-01  
**Статус:** ассеты скачаны в staging **вне проекта**, в Godot не импортированы, `.tres` и сцены не менялись.  
**Путь:** `%USERPROFILE%\Tools\asset_staging\polyhaven`  
**Лицензия:** Poly Haven, **CC0 1.0** (https://polyhaven.com/license). Атрибуция не обязательна; авторы сохранены для реестра.  
**Манифест с SHA256 и URL:** `%USERPROFILE%\Tools\asset_staging\polyhaven\manifest.csv`.

## Состав

| ID | Название | Автор | Байт | Файлы (2K JPG) |
|---|---|---|---:|---|
| `coral_ground_02` | Coral Ground 02 | Rob Tuytel | 8 505 813 | `coral_ground_02_diff_2k.jpg`, `coral_ground_02_nor_gl_2k.jpg`, `coral_ground_02_arm_2k.jpg` |
| `coral_gravel` | Coral Gravel | Rob Tuytel | 9 654 878 | `coral_gravel_diff_2k.jpg`, `coral_gravel_nor_gl_2k.jpg`, `coral_gravel_arm_2k.jpg` |
| `coral_mud_01` | Coral Mud 01 | Rob Tuytel | 7 508 856 | `coral_mud_01_diff_2k.jpg`, `coral_mud_01_nor_gl_2k.jpg`, `coral_mud_01_arm_2k.jpg` |
| `coral_stone_wall` | Coral Stone Wall | Dimitrios Savva | 10 731 201 | `coral_stone_wall_diff_2k.jpg`, `coral_stone_wall_nor_gl_2k.jpg`, `coral_stone_wall_arm_2k.jpg` |
| `low_tide_rocks` | Low Tide Rocks | Dimitrios Savva | 15 110 141 | `low_tide_rocks_diff_2k.jpg`, `low_tide_rocks_nor_gl_2k.jpg`, `low_tide_rocks_arm_2k.jpg` |
| `damp_beach_sand` | Damp Beach Sand | Dimitrios Savva | 10 078 279 | `damp_beach_sand_diff_2k.jpg`, `damp_beach_sand_nor_gl_2k.jpg`, `damp_beach_sand_arm_2k.jpg` |
| `coral_fort_wall_01` | Coral Fort Wall 01 | Dimitrios Savva, Rico Cilliers | 12 510 769 | `coral_fort_wall_01_diff_2k.jpg`, `coral_fort_wall_01_nor_gl_2k.jpg`, `coral_fort_wall_01_arm_2k.jpg` |
| `coral_fort_wall_02` | Coral Fort Wall 02 | Dimitrios Savva | 12 119 045 | `coral_fort_wall_02_diff_2k.jpg`, `coral_fort_wall_02_nor_gl_2k.jpg`, `coral_fort_wall_02_arm_2k.jpg` |
| `coral_fort_wall_03` | Coral Fort Wall 03 | Dimitrios Savva, Rico Cilliers | 12 810 625 | `coral_fort_wall_03_diff_2k.jpg`, `coral_fort_wall_03_nor_gl_2k.jpg`, `coral_fort_wall_03_arm_2k.jpg` |

**Итого:** 9 наборов, **27 файлов**, **99 029 607 байт** (≈94,4 MiB).

## Проверка

- MD5 каждого файла сверен с `api.polyhaven.com/files/<id>`: **27/27 совпадают**, 0 расхождений.
- SHA256 записан в `manifest.csv`.
- Файлы не копировались в `assets/`; Godot их не импортировал.
- Модели (`coast_land_rocks_*`, `lambis_shell`, `rock_07`, `rock_09`, `stone_01`) и HDRI не скачивались — отложены до Stage 2–3.

## Назначение

- `coral_ground_02`, `coral_gravel`, `coral_mud_01` — пол, низины, осыпи, переходы.
- `coral_stone_wall`, `coral_fort_wall_01/02/03` — массивная коралловая порода/кладка; использовать как подложку, не как органическую форму.
- `low_tide_rocks`, `damp_beach_sand` — кромка воды, мокрые камни, следы отлива.

Это **не** готовая текстура красного органического коралла. Для `coral_red`/`coral_deep` нужен собственный материал и bake (см. `docs/art/graphics_audit_and_tooling.md`, §5.5).

## Перенос в проект (позже, после Stage 2)

1. Скопировать нужные наборы в `assets/environments/...` (LFS: JPEG уже покрыт `.gitattributes`).
2. Создать `.import` и `nm_*.tres` по существующему пайплайну.
3. Внести наборы в `docs/ASSET_LICENSES.md` с авторами и URL.
4. Проверить `godot --headless --path . --import` и кадры материалов.

**Сейчас:** 2026-11-02 для кораллового кита перенесены в проект `coral_fort_wall_01/02/03`,
`coral_ground_02`, `coral_mud_01` (15 файлов JPEG); они зарегистрированы в `docs/ASSET_LICENSES.md`.
Остальные наборы (`coral_gravel`, `coral_stone_wall`, `low_tide_rocks`, `damp_beach_sand`) остаются
в staging и в Godot не импортированы.

## P0 style gate staging (2026-11-01, не в проекте)

Для проверки реалистичного dark fantasy в P0 скачаны, но **не импортированы** в Godot:

| Ассет | Версия/формат | Лицензия | Назначение |
|---|---|---|---|
| `island_tree_01` | 1K GLTF + bin + текстуры, ≈66 МБ | Poly Haven CC0 1.0 | реалистичное дерево-прокси для парка |
| `quiver_tree_01` | 1K GLTF + bin + текстуры, ≈8,9 МБ | Poly Haven CC0 1.0 | fallback-дерево |
| `kloofendal_misty_morning_puresky` | 2K HDR, 2,96 МБ | Poly Haven CC0 1.0 | утренний HDRI для парка (использован в P0) |
| `kloofendal_overcast_puresky` | 2K HDR, 4,34 МБ | Poly Haven CC0 1.0 | пасмурный вариант (резерв P0) |
| `qwantani_moon_noon_puresky` | 2K HDR, 4,60 МБ | Poly Haven CC0 1.0 | лунный вариант (резерв P0; ночь скалы сделана шейдером `nm_night_sky`) |

Пути: `%USERPROFILE%\Tools\asset_staging\polyhaven_models\` и `...\polyhaven_hdri\`.
Скрипт `tools/audit/style_gate_capture.gd` читает их из staging через `%USERPROFILE%`, в проект не копирует.

**Финальными ассетами не являются:** `island_tree_01` — тяжёлый style-прокси; для парка нужен оптимизированный дерево-кит/LOD. Перед переносом в `assets/` — регистрация в `docs/ASSET_LICENSES.md`.

**Обновление P2 (2026-11-02):** `island_tree_01` и `kloofendal_misty_morning_puresky` перенесены в
`assets/environments/park/trees/` и `assets/environments/park/sky/` в упрощённом виде; см. `docs/art/p2_real_world.md`.
