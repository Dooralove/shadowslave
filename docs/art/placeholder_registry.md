# Реестр плейсхолдеров локаций и пилотная замена

Дата: 2026-11-03. Статус: **аудит выполнен, пилотная партия из 3 ассетов заменена и проверена**.
Область: финальные art-сцены, которые грузит кампания, плюс runtime-greybox Лабиринта.
Связанные документы: `docs/art/asset_production_standards.md`, `docs/art/location_asset_matrix.md`,
`docs/art/environment_asset_manifest.md`, `docs/ASSET_LICENSES.md`, `docs/DECISIONS.md`.

## 1. Метод

- `tools/audit/placeholder_audit.py` — статический аудит `.tscn`: раскрывает `PackedScene`-инстансы
  (art-сцена инстансит greybox-сцену), применяет overrides, считает world transform и AABB для
  `CSG*3D` и `MeshInstance3D` с примитивными мешами. Отбрасывает «retired»-боксы 0.001 м и
  decals толщиной < 5 см, чтобы не путать их с 3D-плейсхолдерами.
- `tools/audit/runtime_placeholder_audit.gd` — runtime-аудит сцен, где greybox строится скриптом
  (Лабиринт). Считает только видимые примитивы после `LabyrinthArt`.
- `tools/audit/location_shot.gd` — read-only кадр с заданной камеры для before/after.
- `tools/audit/stealth_cover_collision_probe.gd` — проверка, что скрытые CSG-прокси всё ещё
  блокируют объём заменённых укрытий.
- `tools/audit/containment_probe.gd` — то же для коридора изолятора: стены, торец, пол и
  непрерывность пола от порога до дальней стены.

Ограничение: статический аудит видит только файлы сцен. Он не заменяет ручной проход и не
доказывает, что объект читается в игре; для пилота сделаны кадры до/после.

## 2. Сводка

| Сцена | Видимых статических плейсхолдеров | Что это |
|---|---:|---|
| `scenes/slice/locations/station_lobby_art.tscn` | 9 | оболочка зала: пол, потолок, 4 стены, проём, 2 боковые двери |
| `scenes/slice/locations/containment_room_art.tscn` | **0** | коридор и `ObservationPost` закрыты kit-оверлеем; CSG-прокси скрыты, но остаются коллизией |
| `scenes/locations/caravan_site/caravan_site_art.tscn` | 3 | звенья и кандалы `BrokenChain` (мелкий реквизит) |
| `scenes/locations/pilgrim_path/pilgrim_path_art.tscn` | 6 | 5 следов + пятно крови (плоские decals, не 3D-замены) |
| `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn` | 1 (в файле) | `Tide/WaterPlane` — не плейсхолдер |
| Лабиринт, runtime `Generated/Visual` | **202** | полы, кости, панцири, лужи, лезвия; см. §4 |

Сцены с 0 видимых статических плейсхолдеров: `park_street_art.tscn`, `caravan_road_art.tscn`,
`mountain_vision_art.tscn`, `shadow_sanctuary_art.tscn` (базовый CSG скрыт art-слоем).

`scenes/locations/ambush_site/ambush_site.tscn` — неканоническая песочница, в реестр не входит.
`scenes/locations/post_nightmare/coral_labyrinth.tscn` — старая песочница, не финальная сцена.
`scenes/soul_sea/soul_sea.tscn` — внутренний хаб, не физическая локация; по
`docs/art/soul_sea_model_map.md` ассеты для него не производятся.
Post-nightmare сцены (`scenes/locations/post_nightmare/*.tscn`) уже инстансят art-overlay и не
содержат CSG-плейсхолдеров в загружаемом варианте.

## 3. Статический аудит: полный список

Локальный размер — до поворота; world AABB — после трансформа. Позиция — origin узла в мире.

### `scenes/locations/caravan_site/caravan_site_art.tscn`

| Узел | Тип | Категория | Локальный размер (м) | Позиция (м) | Yaw/Pitch/Roll | World AABB (м) |
|---|---|---|---|---|---|---|
| `CaravanSite/Props/BrokenChain/LinkA` | CSGBox3D | prop | 0.50 × 0.06 × 0.08 | -4.70, 0.12, -1.70 | 0.2, 0.5, 0.6 | 0.50 × 0.07 × 0.09 |
| `CaravanSite/Props/BrokenChain/LinkB` | CSGBox3D | prop | 0.44 × 0.06 × 0.08 | -4.36, 0.13, -1.52 | -0.1, 1.1, 0.4 | 0.44 × 0.06 × 0.09 |
| `CaravanSite/Props/BrokenChain/Shackle` | CSGCylinder3D | prop | 0.30 × 0.08 × 0.30 | -4.02, 0.16, -1.46 | 1.6, 0.4, 0.2 | 0.30 × 0.09 × 0.30 |

### `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`

| Узел | Тип | Категория | Локальный размер (м) | Позиция (м) | Yaw/Pitch/Roll | World AABB (м) |
|---|---|---|---|---|---|---|
| `LabyrinthFirstFragment/Tide/WaterPlane` | MeshInstance3D | prop | 3000.00 × 0.00 × 1200.00 | -700.00, -8.00, 0.00 | 0.0, -0.0, 0.0 | 3000.00 × 0.00 × 1200.00 |

### `scenes/locations/pilgrim_path/pilgrim_path_art.tscn`

| Узел | Тип | Категория | Локальный размер (м) | Позиция (м) | Yaw/Pitch/Roll | World AABB (м) |
|---|---|---|---|---|---|---|
| `PilgrimPath/Props/Tracks/Track0` | CSGBox3D | prop | 0.16 × 0.02 × 0.32 | 1.03, 4.13, -35.20 | 0.0, -0.0, 0.0 | 0.16 × 0.02 × 0.32 |
| `PilgrimPath/Props/Tracks/Track1` | CSGBox3D | prop | 0.16 × 0.02 × 0.32 | 1.29, 4.13, -35.58 | 0.0, -0.0, 0.0 | 0.16 × 0.02 × 0.32 |
| `PilgrimPath/Props/Tracks/Track2` | CSGBox3D | prop | 0.16 × 0.02 × 0.32 | 1.05, 4.13, -35.98 | 0.0, -0.0, 0.0 | 0.16 × 0.02 × 0.32 |
| `PilgrimPath/Props/Tracks/Track3` | CSGBox3D | prop | 0.16 × 0.02 × 0.32 | 1.31, 4.13, -36.38 | 0.0, -0.0, 0.0 | 0.16 × 0.02 × 0.32 |
| `PilgrimPath/Props/Tracks/Track4` | CSGBox3D | prop | 0.16 × 0.02 × 0.32 | 1.03, 4.13, -36.78 | 0.0, -0.0, 0.0 | 0.16 × 0.02 × 0.32 |
| `PilgrimPath/Props/CaveBlood` | CSGBox3D | prop | 0.90 × 0.02 × 0.70 | 9.20, 4.12, -49.20 | 0.0, 23.0, 0.0 | 1.10 × 0.02 × 0.99 |

### `scenes/slice/locations/containment_room_art.tscn`

Видимых статических плейсхолдеров — **0**. Пять CSG-боксов коридора и `ObservationPost`
скрыты (`visible = false`) и заменены kit-оверлеем; см. §6. Прокси коридора сохраняют
`use_collision = true` и остаются его коллизией:

| Прокси | Размер (м) | Позиция (м) | Коллизия |
|---|---|---|---|
| `CorridorFloor` | 1.90 × 1.00 × 6.25 | 0.00, -0.50, -4.375 | да |
| `CorridorWallL` / `CorridorWallR` | 0.30 × 2.80 × 6.00 | ∓0.95, 1.40, -4.50 | да |
| `CorridorEnd` | 2.20 × 2.80 × 0.30 | 0.00, 1.40, -7.60 | да |
| `CorridorCeiling` | 2.20 × 0.30 × 6.25 | 0.00, 2.60, -4.375 | нет (потолок 2.45 м, недостижим) |
| `Art/ObservationPost` | 3.60 × 2.45 × 2.20 | 0.00, 1.23, 4.50 | нет |

### `scenes/slice/locations/station_lobby_art.tscn`

| Узел | Тип | Категория | Локальный размер (м) | Позиция (м) | Yaw/Pitch/Roll | World AABB (м) |
|---|---|---|---|---|---|---|
| `StationLobby/Geometry/Floor` | CSGBox3D | structural | 12.00 × 1.00 × 12.00 | 0.00, -0.50, 0.00 | 0.0, -0.0, 0.0 | 12.00 × 1.00 × 12.00 |
| `StationLobby/Geometry/Ceiling` | CSGBox3D | structural | 12.60 × 0.30 × 12.60 | 0.00, 4.15, 0.00 | 0.0, -0.0, 0.0 | 12.60 × 0.30 × 12.60 |
| `StationLobby/Geometry/WallNorth` | CSGBox3D | structural | 12.60 × 4.00 × 0.30 | 0.00, 2.00, -6.15 | 0.0, -0.0, 0.0 | 12.60 × 4.00 × 0.30 |
| `StationLobby/Geometry/WallSouth` | CSGBox3D | structural | 12.60 × 4.00 × 0.30 | 0.00, 2.00, 6.15 | 0.0, -0.0, 0.0 | 12.60 × 4.00 × 0.30 |
| `StationLobby/Geometry/WallSouth/EntranceCut` | CSGBox3D | structural | 1.60 × 2.40 × 0.50 | 0.00, 1.20, 6.15 | 0.0, -0.0, 0.0 | 1.60 × 2.40 × 0.50 |
| `StationLobby/Geometry/WallWest` | CSGBox3D | structural | 0.30 × 4.00 × 12.00 | -6.15, 2.00, 0.00 | 0.0, -0.0, 0.0 | 0.30 × 4.00 × 12.00 |
| `StationLobby/Geometry/WallEast` | CSGBox3D | structural | 0.30 × 4.00 × 12.00 | 6.15, 2.00, 0.00 | 0.0, -0.0, 0.0 | 0.30 × 4.00 × 12.00 |
| `StationLobby/Geometry/SideDoorWest` | CSGBox3D | structural | 0.08 × 2.20 × 1.20 | -5.98, 1.10, 5.00 | 0.0, -0.0, 0.0 | 0.08 × 2.20 × 1.20 |
| `StationLobby/Geometry/SideDoorEast` | CSGBox3D | structural | 0.08 × 2.20 × 1.20 | 5.98, 1.10, 5.00 | 0.0, -0.0, 0.0 | 0.08 × 2.20 × 1.20 |


## 4. Лабиринт: runtime-аудит

`godot --headless --path . -s tools/audit/runtime_placeholder_audit.gd` после `LabyrinthArt`
показывает **151 видимый примитив** (исключая намеренный процедурный арт `ArtFinal`). Это не
значит, что все 151 надо менять: полы, кости, лужи и лезвия — часть kit-слоя.

| Зона | Видимых примитивов | Комментарий |
|---|---:|---|
| Z02 Carcass | 7 | только пол, рёбра и лужи; **`Z02_Crab*` — 0**, вложенное скрытие исправлено |
| Z10 Coral Hill | 7 | пол, лагерный реквизит, конусы |
| Z13 Hunting Grounds | 14 | кости, массы |
| Z16 Pack Territory | 13 | массы, парапеты |
| Z08 Clearing | 13 | стены, лезвия |
| Z03 / Z04 / Z05 | 30 | по 10 на зону: стены, кости, декор |
| остальные Z01–Z18 | 56 | полы/кости/декор |
| прочее (pickups, weak spots, вода) | 11 | геймплейные визуалы, не плейсхолдеры |

**Вывод:** Z02-баг закрыт 2026-11-03: `_hide_carcass_placeholders()` теперь рекурсивно скрывает
`Z02_Crab0/1/2` и их дочерние меши. Коридор изолятора и `ObservationPost` закрыты kit-оверлеем
(§6). Следующий пакет — мелкий реквизит стоянки и оболочка лобби, после общей сборки пропов
и комнатного кита.

## 5. Пилотная партия: укрытия StealthSection

### Почему эти три

В `pilgrim_path_art.tscn` участок `StealthSection/Covers` оставался тремя чёрными
`CSGBox3D` с `Mat_rock_dark` прямо на маршруте. Это заметный глазом плейсхолдер, у него
простые трансформации и важная игровая роль — укрытие. Пилот проверяет весь пайплайн:
Hyper3D CLI → Blender (pivot/scale/decimate) → GLB → Godot (transform + collision).

### Что заменено

| Базовый узел | Позиция (мир) | Yaw | Локальный размер (X×Y×Z) | World AABB | Новый ассет | Треугольники |
|---|---|---:|---|---|---|---:|
| `StealthSection/Covers/CoverWest` | (-1.10, 4.65, -55.80) | 18.1° | 1.20 × 1.40 × 2.20 | 1.82 × 1.40 × 2.46 | `stealth_cover_a.glb` | 3 198 |
| `StealthSection/Covers/CoverEast` | (3.05, 4.65, -57.00) | -17.2° | 1.20 × 1.40 × 2.20 | 1.80 × 1.40 × 2.46 | `stealth_cover_b.glb` | 3 199 |
| `StealthSection/Covers/CoverEdge` | (0.15, 4.65, -58.15) | 17.2° | 1.00 × 1.20 × 1.60 | 1.43 × 1.20 × 1.82 | `stealth_cover_c.glb` | 2 599 |

Новые меши стоят в `Art/StealthCovers` с теми же `position`/`rotation`, что и исходные CSG.
Локальный bbox совпадает с плейсхолдером; origin — нижний центр, поэтому меши не проваливаются
под пол и не всплывают.

### Промпты Hyper3D

Все три — `Gen-2.5-High`, `Quad`, `--quality 20000/16000`, `--format glb`, PBR:

```powershell
hyper3d generate --prompt "<prompt>" --tier Gen-2.5-High --mesh-mode Quad `
  --quality 20000 --format glb --output json
```

- A: «Single isolated weathered dark slate boulder slab for a grim snowy mountain trail. Broad
  angular wedge, roughly 2.2 m long, 1.2 m wide, 1.4 m tall, leaning slightly, one dominant
  vertical fracture, crisp chipped edges, wind-polished faces, deep blue-grey and charcoal PBR
  albedo, subtle roughness variation, no snow, no vegetation, no ground plane, no base, no plinth,
  no other objects. Game environment prop, realistic scale, clean watertight manifold mesh,
  low-poly friendly, neutral studio background.»
- B: «Single isolated wind-carved dark granite windbreak boulder for a grim snowy mountain trail.
  Two fused angular stone masses forming a low chest-high barrier, roughly 2.2 m long, 1.2 m wide,
  1.4 m tall, horizontal layering, deep cracks, chipped corners, wet dark blue-grey stone with
  subtle mica flecks, no snow, no vegetation, no ground plane, no base, no other objects. Game
  environment prop, realistic scale, clean watertight manifold mesh, low-poly friendly, neutral
  studio background.»
- C: «Single isolated low wedge-shaped dark rock outcrop for a grim snowy mountain trail. Squat
  triangular boulder, roughly 1.6 m long, 1.0 m wide, 1.2 m tall, one steep face and one sloping
  face, frost-split edges, dark charcoal blue-grey stone, faint ice glaze, no snow, no vegetation,
  no ground plane, no base, no other objects. Game environment asset, realistic scale, clean
  watertight manifold mesh, low-poly friendly, neutral studio background.»

ID генераций: A `b73755ad-cc3a-4dbc-b0fc-6c956abdfd1d`, B `54f8fa8c-4cb4-490c-a4b9-a7bd12989e1e`,
C `7ddfff73-e8cc-4ce6-89a3-2cdb93b95a60`. Сырые GLB — в
`incoming_models/P2_environment/stealth_covers/` (gitignored).

### Постобработка

- Импорт GLB, join, apply rotation/scale.
- `remove_doubles` 0.5 мм, `dissolve_degenerate`, пересчёт нормалей наружу.
- Масштаб под локальный bbox плейсхолдера.
- Origin в нижний центр: bbox min Z = 0, center X/Y = 0, object location = (0,0,0).
- Decimate Collapse до 3 200 / 3 200 / 2 600 треугольников.
- `shade_smooth_by_angle(38°)`.
- UV box в метрах, материал-слот `nm_rock`; в Godot слот подменяется на
  `nm_rock_cover.tres` через `.import` (`_subresources/materials/nm_rock/use_external`).
- `nm_rock_cover.tres` — проектный вариант `nm_rock.tres`: `base_tint` 0.58/0.63/0.74,
  `snow_coverage = 0.0`, чтобы укрытия читались тёмным камнем, а не растворялись в снегу.

Путь ассетов — проектный `assets/environments/nightmare/path/`, а не общий
`assets/models/environment/`: так требует `docs/art/asset_production_standards.md` §2
(одно семейство — одна папка, материалы и `.import` рядом с локальным китом).

Исходник и воспроизводимый сборщик:
`assets/environments/nightmare/source/build_stealth_covers.py`,
`assets/environments/nightmare/source/stealth_covers.blend`.

### Интеграция и коллизия

- `pilgrim_path_art.tscn` → `Art/StealthCovers/CoverWest|CoverEast|CoverEdge` — инстансы GLB.
- Базовые CSG-узлы `StealthSection/Covers/*` получили `visible = false`, но **оставлены с
  `use_collision = true`**. Это осознанно: арт-слой не меняет маршрут и не добавляет вторую
  коллизию. Скрытый CSG по-прежнему блокирует (проверено).
- `tools/audit/stealth_cover_collision_probe.gd`: для каждого укрытия лучи по ±X/±Z/±Y попадают
  в собственный CSG-коллайдер; `RESULT failures=0`.

### До / после

![До: чёрные CSG-боксы](../previews/nightmare/stealth_covers_before.jpg)

![После: тёмные каменные укрытия](../previews/nightmare/stealth_covers_after.jpg)

- `docs/art/previews/nightmare/stealth_covers_before.jpg` — чёрные CSG-боксы (в кадре видны два,
  третий перекрыт).
- `docs/art/previews/nightmare/stealth_covers_after.jpg` — те же ракурсы после замены.
- `docs/art/previews/nightmare/stealth_covers_after_wide.jpg` — широкий ракурс, видны все три.
- `docs/art/previews/nightmare/stealth_covers.jpg` — Blender-превью кита с манекеном 1,75 м.

## 6. Изолятор: коридор и пост наблюдения

Коридор и `ObservationPost` не генерировались заново: это уже существующий kit пролога
`assets/environments/prologue/cell/` — бронепанели `cell_wall_panel_a/b/c`, `cell_floor`,
`cell_ceiling`, `cell_wall_window`. Новых GLB нет, поэтому бюджет полигонов и лицензии не
меняются.

### Что собрано

- `Art/Corridor` — пол и потолок `cell_floor`/`cell_ceiling`, по 5 панелей на сторону,
  сжатые торцевые панели `WallLEnd`/`WallREnd` и две панели дальней стены. Пол и потолок
  протянуты до `z = -1.25`, чтобы закрыть 20-сантиметровый разрыв у порога.
- `Art/ObservationPostArt` — три панели задней стены, пол, `desk_counter`, `terminal_desk`
  и приглушённый `PostLight`. Пост виден через окно камеры; это фон, а не проходная зона.
- CSG-боксы коридора скрыты, но **коллизия сохранена** (`use_collision = true`).
  `ObservationPost` скрыт и получил `use_collision = false` — он стоит за стеной.
- `scripts/slice/locations/corridor_art.gd` отключает собственные `StaticBody3D` импортированных
  модулей только внутри `Art/Corridor` и `Art/ObservationPostArt`, чтобы не дублировать
  коллизию CSG-прокси. Панели самой камеры остаются с коллизией.

### Проверка коллизии

`tools/audit/containment_probe.gd` — read-only: лучи из коридора в ±X, к торцу и вниз
попадают в `CorridorWallL/R`, `CorridorEnd`, `CorridorFloor`; по полу на `x = 0` от
`z = -1.0` до `-7.4` разрывов нет; `RESULT failures=0`. Потолок коллизии не имеет
(по умолчанию у CSG), но его нижняя точка — 2.45 м, игрок туда не достаёт.

### Тесты и кадры

| Проверка | Результат |
|---|---|
| `test_prologue_art.gd` | **10/10, 86 asserts** |
| `test_p4_presentation.gd` | **9/9, 65 asserts** |
| `test_pilgrim_path.gd` + `test_full_route.gd` | **13/13, 480 asserts** |
| Collision probe | **failures=0**, стены/торец/пол блокируются CSG-прокси |
| Визуальные кадры | коридор вперёд/назад и пост через окно; до/после одним `location_shot.gd` |
| Ручной проход и катсцена B10–B12 в живом окне | **NOT TESTED** |

## 7. Проверка пилота укрытий

| Проверка | Результат |
|---|---|
| `test_pilgrim_path.gd` | **10/10, 260 asserts, All tests passed** |
| `test_full_route.gd` | **3/3, 220 asserts, All tests passed** |
| Collision probe | **failures=0**, все три укрытия блокируются собственным CSG |
| Godot import | `godot --headless --path . --import` — exit 0; GLB зависят от `nm_rock_cover.tres`; ошибок по ассетам в логе нет |
| Визуальный кадр | before/after сняты одним и тем же `location_shot.gd` |
| Ручной проход | **NOT TESTED** |
| Производительность | **NOT TESTED** (3 × ~3 тыс. треугольников; бюджет не измерялся) |

## 8. Следующие партии

1. ~~**Z02 Carcass, Лабиринт** — 33 меша `Z02_Crab*`.~~ **Исправлено 2026-11-03:**
   `labyrinth_art.gd` рекурсивно скрывает `Z02_Crab0/1/2`; runtime-аудит показывает 0 мешей
   `Z02_Crab*`, `test_labyrinth_first_fragment` — 14/14, кадр `carcass` проверен. Приоритет закрыт.
2. ~~**Изолятор** — коридор из 5 CSG-боксов + `ObservationPost`.~~ **Закрыто 2026-11-03:**
   kit-оверлей из модулей пролога, CSG-прокси сохранены как коллизия, `containment_probe`
   — `failures=0`; см. §6. Приоритет закрыт.
3. **Стоянка каравана** — `BrokenChain/LinkA`, `LinkB`, `Shackle` (0.5 × 0.06 × 0.08 м и меньше).
   Мелкий реквизит; дешевле сделать процедурно или оставить до общей сборки пропов. P2.
4. **Лобби участка** — 9 структурных CSG (пол, потолок, стены, двери). Это оболочка зала,
   поверх неё уже стоят арт-панели; менять только вместе с модульным kit комнаты. P2.
5. **Пост-обработка остальных локаций** — после принятия пилота повторить пайплайн для
   `caravan_site`, сохраняя исходные CSG-коллизии. `containment_room` уже закрыт в §6.

## 9. Регистрация

Все новые ассеты — проектные производные Hyper3D-выходов; условия генератора проверять перед
релизом. Лицензии и ID — в `docs/ASSET_LICENSES.md`. Манифест — в
`docs/art/environment_asset_manifest.md`. Решение о сохранении CSG-коллизии — в `docs/DECISIONS.md`.
