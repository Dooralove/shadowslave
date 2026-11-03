# Реестр ассетов ShadowSlave

Каждый внешний ассет (модели, текстуры, анимации, звук, шрифты, плагины) регистрируется здесь до попадания в проект.

| Имя | Источник | Автор | Лицензия | URL | Дата загрузки | Ограничения использования |
|---|---|---|---|---|---|---|
| Godot Engine 4.7.2 | godotengine.org / github.com/godotengine/godot-builds | Godot Engine contributors | MIT | https://godotengine.org/download/archive/4.7.2-stable/ | 2026-10-21 | Инструмент разработки, в проект не входит |
| Godot MCP plugin (`addons/godot_mcp/`) | github.com/tomyud1/godot-mcp (commit 2c1f300) | tomyud1 | См. `addons/godot_mcp/LICENSE` | https://github.com/tomyud1/godot-mcp | 2026-10-21 | Инструмент разработки, копия LICENSE в папке плагина |
| GUT 9.7.1 (`addons/gut/`) | github.com/bitwes/Gut | Butch Wesley и участники | MIT | https://github.com/bitwes/Gut | 2026-10-21 | Тестовый фреймворк |
| Rogue_Hooded.glb — временная модель Санни со скелетом и 76 анимациями (`assets/characters/sunny_placeholder/`) | KayKit : Adventurers Character Pack 1.0, официальный GitHub автора (`Characters/gltf/Rogue_Hooded.glb`, SHA-256 `93E6E252…BB91545`) | Kay Lousberg (www.kaylousberg.com) | CC0 1.0 (текст: `assets/characters/sunny_placeholder/LICENSE_KayKit.txt`) | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 | 2026-10-21 | Нет (CC0). Упоминание автора желательно, но не обязательно. Временный ассет: не финальный облик Санни |
| Rogue_Hooded_rogue_texture.png — текстура модели, извлечена Godot из .glb при импорте | то же | Kay Lousberg | CC0 1.0 | — | 2026-10-21 | Как у модели |

| Barbarian.glb — временная модель тестового противника со скелетом и 76 анимациями (`assets/characters/enemy_placeholder/`) | KayKit : Adventurers Character Pack 1.0, тот же официальный GitHub (`Characters/gltf/Barbarian.glb`, SHA-256 `CEFC311A…0669CC6`) | Kay Lousberg (www.kaylousberg.com) | CC0 1.0 (текст: `assets/characters/enemy_placeholder/LICENSE_KayKit.txt`) | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 | 2026-10-21 | Нет (CC0). Временный ассет |
| Barbarian_barbarian_texture.png — текстура модели, извлечена Godot из .glb при импорте | то же | Kay Lousberg | CC0 1.0 | — | 2026-10-21 | Как у модели |

### Противники: личинка Горного Короля (2026-11-02)

| Имя | Источник | Автор | Лицензия | URL | Дата загрузки | Ограничения использования |
|---|---|---|---|---|---|---|
| `assets/characters/enemies/larva/larva_corpse.glb` — скульпт «Bloodspike Horror Creature», переработан в личинку Горного Короля | Sketchfab, UID `efdc13de41904163aed0319b74c3d305`; исходник 261 689 tri, 25 костей, клип Idle | Purple.Point | **CC BY 4.0** (Sketchfab: CC Attribution) | https://sketchfab.com/3d-models/efdc13de41904163aed0319b74c3d305 | 2026-11-02 | **Требуется атрибуция:** Purple.Point, «Bloodspike Horror Creature», Sketchfab, CC BY 4.0; ссылка на исходник и пометка об изменениях. Добавить в титры/credits перед релизом. Производные файлы распространяются на тех же условиях CC BY 4.0 |
| `larva_corpse_larva_corpse_albedo/normal/roughness.png` — извлечённые Godot карты материала | производные от исходной baseColor-текстуры Sketchfab | Purple.Point (исходник), проект ShadowSlave (обработка) | CC BY 4.0 | — | 2026-11-02 | Как у модели; нормали/roughness сгенерированы из baseColor, альбедо перекрашено в холодный трупный тон |

**Изменения исходника:** объединены три primitive-меша в один, decimate 261 689 → 28 785 tri, сохранены 25-костный риг и клип Idle; модель отмасштабирована до ~1.03 м, ориентация +Y forward; сгенерированы normal/roughness карты и производное альбедо. Исходный high-poly и исходные текстуры не входят в поставку проекта.

| Open Sans SemiBold — шрифт интерфейса по умолчанию (встроен в Godot, отдельным файлом в проект не входит) | Godot Engine 4.7.2, `thirdparty/fonts/OpenSans*.woff2` (сведения из `Engine.get_copyright_info()`) | Steve Matteson / Open Sans Project Authors | SIL OFL 1.1 | https://github.com/googlefonts/opensans | 2026-10-21 (проверка) | Нет для использования в игре; шрифт нельзя продавать отдельно |

### Прототип S2 (`assets/characters/sunny_realistic_poc/`, ветка `s2-character-poc`)

| Имя | Источник | Автор | Лицензия | URL | Дата загрузки | Ограничения использования |
|---|---|---|---|---|---|---|
| MPFB 2.0.18 — расширение Blender для генерации персонажей | extensions.blender.org (установлено в Blender 5.1 пользователя) | MakeHuman Community | Код GPL v3 (инструмент, в проект не входит) | https://extensions.blender.org/add-ons/mpfb/ | 2026-10-21 | Инструмент; на сгенерированные модели GPL не распространяется |
| Базовый меш MakeHuman hm08, макроцели, скелет `game_engine` с весами (данные MPFB) | Поставка MPFB 2.0.18 | MakeHuman Community | CC0 1.0 («All core assets are shared under CC0») | https://static.makehumancommunity.org/about/license.html | 2026-10-21 | Нет |
| Кожа `young_caucasian_male`, глаза `low-poly` + материал `brown`, брови `eyebrow001`, ресницы `eyelashes02`, обувь `shoes06` | Набор `makehuman_system_assets_cc0.zip` (280,7 МБ) | makehuman_system | CC0 1.0 (манифест набора) | https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html | 2026-10-21 | Нет |
| Волосы `culturalibre_hair_05` | Набор `hair01_cc0.zip` (227,8 МБ) | culturalibre | CC0 1.0 | http://www.makehumancommunity.org/node/2445 | 2026-10-21 | Нет. Текстура затемнена до чёрного в скрипте сборки |
| Свитер `toigo_fisherman_sweater` | Набор `shirts01_cc0.zip` (24,5 МБ) | Margaret Toigo | CC0 1.0 | http://www.makehumancommunity.org/node/1187 | 2026-10-21 | Нет. Перекрашен в выцветший серый в скрипте сборки |
| Брюки `toigo_wool_pants` | Набор `pants01_cc0.zip` (21,9 МБ) | Margaret Toigo | CC0 1.0 | http://www.makehumancommunity.org/node/1194 | 2026-10-21 | Нет |
| Universal Animation Library [Standard] — 46 клипов, скелет-гуманоид (`animations/ual_standard.glb`) | OpenGameArt (загружено автором `quaternius`), `universal_animation_librarystandard.zip`, 14,5 МБ | Quaternius | CC0 1.0 (`animations/LICENSE_Quaternius_UAL.txt`) | https://opengameart.org/content/universal-animation-library | 2026-10-21 | Нет |
| `animations/sunny_idle_relaxed.glb` — собственный клип `Idle_Relaxed` (поза покоя) на скелете UAL | Создан в проекте скриптом `source/build_idle_relaxed.py` из `ual_standard.glb` | Проект ShadowSlave (скелет — Quaternius) | Производная CC0-ассета; собственная поза | — | 2026-10-21 | Нет |

Дополнительно скачаны и установлены в пользовательские данные MPFB (вне проекта), но в модели не используются: `skins02_cc0.zip` (76,1 МБ, CC0). Все 146 ассетов пяти наборов помечены в манифестах как CC0. CC-BY-наборы не загружались.

`sunny_poc.glb` собирается воспроизводимо скриптом `source/build_sunny_poc.py`; извлечённые Godot текстуры `sunny_poc_*.png` — производные перечисленных CC0-ассетов.

`rogue_placeholder_dark.tres` и `barbarian_placeholder_dark.tres` — собственные материалы проекта (затемнённые копии материалов моделей), не внешние ассеты.

S1 (graybox-срез) новых внешних ассетов не добавляет: локации собраны из CSG-примитивов, NPC — собственный манекен из капсулы и сферы (`scenes/slice/props/mannequin.tscn`), Санни — уже зарегистрированная модель KayKit Rogue со скрытыми ножами.

### S3.2: CC0-текстуры парка (`assets/environments/park/materials/textures/`, ветка `s3-park-art`)

Все наборы — Poly Haven, лицензия CC0 1.0 («all assets are CC0», https://polyhaven.com/license), загрузка 2026-10-21 по разрешению пользователя. Файлы — JPEG: `*_diff_*` (альбедо), `*_nor_gl_*` (нормали OpenGL), `*_arm_*` (AO/шероховатость/металличность = ORM в Godot). Всего 21 файл, ≈ 23,6 МБ.

| Набор | Разрешение | Автор | URL | Использование |
|---|---|---|---|---|
| `rusty_metal_02` | 2K | Rob Tuytel | https://polyhaven.com/a/rusty_metal_02 | Скамейка: нормали и ARM напрямую, альбедо — источник для `bench_paint_rust_albedo.png` |
| `granite_tile_04` | 2K | Amal Kumar | https://polyhaven.com/a/granite_tile_04 | Дорожки парка, тротуары, бордюры (разный оттенок и масштаб) |
| `worn_tile_floor` | 1K | Dimitrios Savva | https://polyhaven.com/a/worn_tile_floor | Старая плитка в нише со скамейкой |
| `clean_asphalt` | 1K | Dimitrios Savva | https://polyhaven.com/a/clean_asphalt | Проезжая часть |
| `plaster_grey_04` | 1K | Rob Tuytel | https://polyhaven.com/a/plaster_grey_04 | Светлый композит и корпус урны (только нормали и ARM, альбедо — цвет) |
| `concrete_slab_wall` | 1K | Dimitrios Savva | https://polyhaven.com/a/concrete_slab_wall | Композит со швами: опоры эстакады, стволы, кромки |
| `metal_plate_02` | 1K | Rob Tuytel | https://polyhaven.com/a/metal_plate_02 | Тёмные бронепанели и объём участка |

Производные собственные файлы (из CC0-источника, скрипт `assets/environments/park/source/make_bench_textures.py`): `bench_paint_rust_albedo.png` (краска перекрашена в тёмно-зелёный, ржавчина затемнена), `rust_stain.png` (декаль ржавых потёков). Скамейка, урна и стаканчик (`assets/environments/park/props/*.glb`) — собственные модели скрипта `build_park_props.py`.

S3.1 (блок-аут парка, ветка `s3-park-art`) новых внешних ассетов не добавляет: `assets/environments/park/park_blockout.glb` собирается собственным скриптом `source/build_park_blockout.py` из примитивов, экран — собственный шейдер. CC0-материалы Poly Haven / ambientCG разрешены пользователем для S3.2 и будут регистрироваться здесь до попадания в проект.

Mixamo рассматривался как основной источник, но скачивание требует входа в аккаунт Adobe; выбран CC0-аналог с подтверждения пользователя.

## Звук святилища (C-подготовка, 2026-10-26)

| Имя | Источник | Автор | Лицензия | URL | Дата загрузки | Ограничения использования |
|---|---|---|---|---|---|---|
| `assets/audio/sanctuary/wind_whoosh_loop.ogg` — зацикленный ветер (фоновый слой площадки храма) | OpenGameArt, `wind woosh loop.ogg` | SketchMan3 | CC0 1.0 (`http://creativecommons.org/publicdomain/zero/1.0/`) | https://opengameart.org/content/wind-whoosh-loop | 2026-10-26 | Атрибуция не обязательна; указан автор добровольно |
| `assets/audio/sanctuary/guard_presence_ambience_1.wav` — тёмный амбиент (`ambience-1.wav`, 4.6 с, 24 бит, стерео) для присутствия стража | OpenGameArt, `dark_ambiences.zip` | Ogrebane | CC0 1.0 | https://opengameart.org/content/dark-ambiences | 2026-10-26 | Атрибуция не обязательна. Подходит по характеру, на слух не проверен |

Не использовано: `rock_break.ogg` (CC0, themightyglider) — звук разрушения камня, не скрип; `dungeon_ambient_1.ogg` (CC0, JaggedStone) — пещерный амбиент с каплями, не открытая площадка; `legit_audio … the_shop_free_sfx` — CC0 только для бесплатных звуков сайта, пакет крупный и не относится к сцене. Подходящего CC0-скрипа камня не найдено: этот слой остаётся открытым блокером.

### Звук святилища: каменный скрип при пересечении порога (2026-10-26)

| Имя | Источник | Автор | Лицензия | URL | Дата | Ограничения использования |
|---|---|---|---|---|---|---|
| `assets/audio/sanctuary/stone_door_large_001.ogg` — тяжёлая каменная дверь, тихий скрип/трение камня при пересечении порога храма (A02) | Freesound, «Door - Stone - Large - 001.wav», публичное превью 128 kbps Ogg Vorbis, моно, 44.1 кГц, ≈3.5 с | DWOBoyle | **CC BY 4.0** (`https://creativecommons.org/licenses/by/4.0/`) | https://freesound.org/people/DWOBoyle/sounds/474178/ | 2026-10-26 | **Требуется атрибуция:** автор DWOBoyle, название звука, ссылка на страницу, пометка о лицензии CC BY 4.0. Внутриигровых титров с этой атрибуцией в проекте не проверялось — нужно решить до релиза. Оригинальный WAV доступен только после входа на сайт; в проект взято публичное превью без обхода доступа. Качество ниже оригинала. Не обрабатывалось. На слух не проверено |

Не использовано:
- `StoneDoor_OpensWithChoir.wav` (Schlaudio, sounds/581371) — помечен CC0, но сам указывает «Credits to original» на DWOBoyle 474178 (CC BY 4.0). Производная с CC0-пометкой не снимает требование атрибуции оригинала, поэтому не взят. Также содержит хор.
- `Wooden door grincing…` (Sadiquecat), `1./2. Wood staircase…` (VMan533), `Journey To The Interweb` (Aemyn), `G18-13-Bells and Horses` (craigsmith) — дерево, ambient или не относятся к камню.
- `creaky_door_hinge.wav` (w.forster.1, CC0, OpenGameArt) — скрип петли, не камень; подмена каменному скрипу не принята.
- `qubodup-DoorSet` (CC0, OpenGameArt) — дверные звуки дерева и металла; каменного нет.

## Окружение Первого Кошмара (`assets/environments/nightmare/`, 2026-10-26)

### CC0-текстуры Poly Haven (`materials/textures/`)

Все наборы — Poly Haven, лицензия CC0 1.0 (https://polyhaven.com/license), загрузка 2026-10-26 по
API `api.polyhaven.com/files/<набор>` (JPEG: `*_diff_*`, `*_nor_gl_*`, `*_arm_*`, `*_disp_*`).
Использование Poly Haven подтверждено пользователем (S3.2; в этой сессии — «используй то, что даст
лучшее качество»). Около 40 МБ.

| Набор | Разрешение | Автор | URL | Использование |
|---|---|---|---|---|
| `dark_rock_02` | 2K | Amal Kumar | https://polyhaven.com/a/dark_rock_02 | Порода перевала: нормали, ARM, высота; альбедо → `nm_rock_albedo_2k.jpg` |
| `snow_02` | 2K | Rob Tuytel | https://polyhaven.com/a/snow_02 | Снег и лёд: нормали, ARM; альбедо → `nm_snow_albedo_2k.jpg` |
| `rock_surface` | 2K | Amal Kumar | https://polyhaven.com/a/rock_surface | Обработанный камень (плиты дороги) и кость: нормали, ARM; альбедо → `nm_stone_worked_albedo_2k.jpg`, `nm_bone_albedo_1k.jpg` |
| `rough_wood` | 1K | Rob Tuytel | https://polyhaven.com/a/rough_wood | Дерево повозки, бочек, дров; кора и уголь (тонировка) |
| `rust_coarse_01` | 1K | Dimitrios Savva, Rico Cilliers | https://polyhaven.com/a/rust_coarse_01 | Кованое железо: нормали, ARM; альбедо → `nm_iron_albedo_1k.jpg` |
| `rough_linen` | 1K | colormass, Rico Cilliers | https://polyhaven.com/a/rough_linen | Мешковина, тент, верёвка: нормали, ARM; альбедо → `nm_linen_albedo_1k.jpg` |
| `brown_leather` | 1K | Rob Tuytel | https://polyhaven.com/a/brown_leather | Кожа фляг, кнута, рукоятей (альбедо скачано как `brown_leather_albedo_1k` → `brown_leather_diff_1k.jpg`) |

Скачаны и удалены как неподходящие (в проекте не остались): `dark_rock` (тёплый тон, светлые жилы
не по палитре), `snow_01` (отпечатки современных подошв с протектором — противоречат миру).

### Производные и собственные текстуры

Скрипт `source/make_nm_textures.py` (numpy + Pillow): перекраска альбедо под палитру
`docs/art/mountain_pass_environment_art.md` — `nm_rock_albedo_2k`, `nm_stone_worked_albedo_2k`,
`nm_snow_albedo_2k`, `nm_linen_albedo_1k`, `nm_bone_albedo_1k`, `nm_iron_albedo_1k` (производные CC0);
процедурный чёрный мрамор `nm_marble_black_{albedo,nor_gl,arm,disp}_2k` — собственный, без внешнего источника.

### Модели

Все `.glb` в `mountain/`, `caravan/`, `flora/`, `remains/`, `temple/`, `trail/` — собственные модели проекта,
собраны скриптами `source/build_*.py` в Blender 5.1 (исходники `source/*_kit.blend`). Внешних моделей нет.
Партия 7 (2026-11-01, арт-проход четырёх локаций): `flora/dead_tree_a.glb`, `flora/dead_tree_b.glb`,
`flora/dead_tree_c.glb` — собственные процедурные мёртвые деревья для среднего плана; исходник
`source/build_dead_tree_kit.py`, `.blend` — `source/dead_tree_kit.blend`; материал — существующий `materials/nm_bark.tres`.
Внешних текстур и моделей не добавлено.
Партия 6 (2026-10-27): `backdrop/` (высокие скальные массивы, средние отроги — `build_backdrop_kit.py`),
`site/` (грунт стоянки, подстилка — `build_site_kit.py`), `path/` (рельеф серпантина и вершины, проходимый вариант
пещеры — `build_path_kit.py`) — тоже собственные, без внешних источников.
Шейдеры `materials/nm_night_sky.gdshader` (ночное небо: звёзды, луна) и `materials/nm_cloud_sea.gdshader`
(слой облаков), сцены эффектов `scenes/environment/nm_snowfall.tscn`, `nm_cloud_sea.tscn`, `nm_fire_flame.tscn`
(частицы, градиентные текстуры в самих сценах) — собственные.
Шейдер `materials/nm_layered_triplanar.gdshader` — собственный (смешение нормалей «whiteout» по
описанию Ben Golus, «Normal Mapping for a Triplanar Shader», алгоритм без заимствования кода).

## Окружение пролога (`assets/environments/prologue/`, партия 5, 2026-10-26)

- **Модели** `cell/*.glb`, `lobby/*.glb` и `park/props/tree_planter_a|b|c.glb`, `park/props/lamp_street_a.glb` —
  собственные, собраны `prologue/source/build_prologue_kit.py` (исходник `prologue_kit.blend`). Внешних моделей нет.
- **Текстуры** `prologue/materials/textures/pr_*` — процедурные (`prologue/source/make_pr_textures.py`, numpy):
  краска, покрытие пола, ремень, шлифованная сталь, экраны интерфейса — без внешних источников.
  `pr_vinyl_albedo_1k.jpg` — производная от **brown_leather** Poly Haven (CC0, уже в реестре выше: нормали и ARM
  материала `pr_vinyl` берутся из того же набора в `nightmare/materials/textures/`).
- **Материалы парка** `park/materials/foliage_plastic.tres`, `dark_metal.tres`, `lamp_lens.tres`, `station_glass.tres`,
  `entrance_light.tres` — собственные, без текстур.
- **Модели фасада** `park/props/station_facade_bay|slit.glb`, `station_entrance.glb`, `bollard_a.glb` и варианты
  `prologue/cell/restraint_chair_upright(_straps).glb`, `vault_door_inward.glb` — собственные (`build_prologue_kit.py`).
- **Фасады квартала** (2026-10-27): шейдер `park/materials/city_facade.gdshader` и материалы `city_curtain_wall.tres`,
  `city_stone_windows.tres`, `city_far_tower.tres` — собственные, без текстур.

## Подложки карт (`assets/ui/map/`, 2026-10-27)

- `dream_realm.png`, `first_nightmare.png`, `city.png` — собственные, процедурные: рисует `tools/map/build_maps.py`
  (numpy, scipy, Pillow; шум, карта высот, светотень). Внешних изображений нет. Фан-карта вики Shadow Slave
  использовалась только как текстовый ориентир по раскладке регионов (координаты меток), её изображение не копировалось.

## Типовые NPC-заглушки (`assets/characters/placeholders/`, 2026-10-27)

- **Люди** `humans/townsman|townswoman|police|slave|knight.glb` — собраны `source/build_placeholder_humans.py`
  в MPFB 2 (Blender 5.1) из CC0-наборов MakeHuman (тело, кожа, волосы, одежда — те же наборы, что у прототипа
  Санни, `LICENSE_MakeHuman_CC0.txt`). Одежда перекрашена скриптом. Кираса и шлем рыцаря — собственная геометрия
  скрипта. PNG рядом — текстуры, извлечённые импортом Godot из GLB.
- **Анимации людей** — Quaternius Universal Animation Library (CC0, уже в проекте:
  `sunny_realistic_poc/animations/`), спокойная стойка — `sunny_idle_relaxed.glb` (собственная).
- **Лошадь** `horse/horse.glb` — Quaternius «LowPoly Animated Farm Animal Pack», CC0
  (https://opengameart.org/content/lowpoly-animated-farm-animal-pack, `LICENSE_Quaternius_FarmAnimals.txt`);
  сконвертирована из FBX `source/convert_horse.py`, клипы переименованы.

## P2 real world (`assets/environments/park/p2/`, `assets/environments/prologue/p2/`, 2026-11-02)

- **Island tree** `assets/environments/park/trees/island_tree_lod0|1|2.glb` — производная от **Poly Haven `island_tree_01`**, CC0 1.0; исходный 1K GLTF, упрощён glTF-Transform до 3 LOD. URL: https://polyhaven.com/a/island_tree_01.
- **Morning HDRI** `assets/environments/park/sky/kloofendal_misty_morning_2k.hdr` — **Poly Haven `kloofendal_misty_morning_puresky`**, CC0 1.0; URL: https://polyhaven.com/a/kloofendal_misty_morning_puresky.
- **P2 kit** `assets/environments/park/p2/*.glb` (facades, bus shelter, station entrance) и `assets/environments/prologue/p2/*.glb` (counter, lockers, chairs, ducts, vents, alarm beacon, drain, pipe, window glass) — собственные процедурные модели, собраны `assets/environments/park/source/build_p2_kit.py`; внешних моделей нет.
- **Lawn/decal textures** `p2_grass_diff_1k.jpg`, `p2_wet_stain.png`, `p2_scratch.png` — собственные процедурные, `assets/environments/park/source/make_p2_grass.py` и `assets/environments/prologue/source/make_p2_decals.py`.
- **P2 materials** `p2_grass.tres`, `p2_lobby_environment.tres`, `p2_cell_environment.tres`, `p2_wet_sheen.tres`, `p2_counter_screen.tres` — собственные.
- **Existing prologue materials/textures** (`pr_*`) используются по уже зарегистрированным CC0-наборам Poly Haven; новых внешних лицензий нет.

## Колосс безголового рыцаря (Forgotten Shore, 2026-11-02)

- **Stone Knight** — базовая скульптура безголового рыцаря с мечом.
  Автор: **mzee92**, источник: https://sketchfab.com/3d-models/stone-knight-c3e3712fd5164e44abdab658981cb395,
  лицензия **CC BY 4.0** (https://creativecommons.org/licenses/by/4.0/).
  Локальные файлы: `assets/environments/nightmare/source/stone_knight_source.glb` (исходник)
  и производный `statue_knight_colossus.glb`. **Атрибуция выведена в главном
  меню** (`CreditsButton` / `CreditsDialog`): «Stone Knight by mzee92,
  CC BY 4.0, via Sketchfab»; проверить в релизной сборке.
  Атрибуция продублирована в `statue/LICENSE_STONE_KNIGHT.txt`.
  Модель скачана через Sketchfab API после явного разрешения пользователя.
- **low_tide_rocks** — 2K diffuse/normal/ARM, Poly Haven, автор Rob Tuytel, **CC0 1.0**.
  URL: https://polyhaven.com/a/low_tide_rocks. Файлы: `assets/environments/nightmare/materials/textures/low_tide_rocks_{diff,nor_gl,arm}_2k.jpg`.
  Используется для процедурной площадки/камня; звёзды — собственная геометрия.
- `source/build_stone_knight_colossus.py`, `source/nm_statue_materials.py`,
  `materials/nm_statue_triplanar.gdshader`, `materials/nm_statue_*.tres` — собственные.
- **LOD1/LOD2** `statue_knight_colossus_lod1.glb`, `statue_knight_colossus_lod2.glb`
  — производные от Stone Knight, **CC BY 4.0**, без текстур; та же атрибуция mzee92.
- `scripts/locations/post_nightmare/statue_knight_lod.gd`,
  `statue_knight_colossus_lod.tscn` — собственные.
- Процедурный v1 (`source/build_statue_colossus.py`) — собственный fallback; в финальном
  ассете не используется.
- `rust_coarse_01` не используется в финальных материалах статуи: импорт diffuse в Godot
  был повреждён (`importer="skip"`), бронза переведена на CC0-камень с тинтом.

## P1 main cast (`assets/characters/p1/`, 2026-11-02)
- **Sunny, police_desk, police_guard, hero_auro, scholar, shifty, veteran, mass_***
  (`assets/characters/p1/models/*.glb`) — собраны `source/build_main_cast.py` в MPFB 2 / Blender 5.1
  из CC0-наборов MakeHuman (тело, кожа, волосы, одежда). Одежда перекрашена скриптом;
  кираса Hero/Veteran — производная копия одежды, без внешних моделей.
  `assets/characters/p1/LICENSE_MakeHuman_CC0.txt`; источник наборов:
  https://static.makehumancommunity.org/assets/assetpacks.html.
- **Текстуры** `assets/characters/p1/models/*.png|*.jpg` — извлечены импортом Godot из GLB
  (те же CC0-наборы MakeHuman; `brown_leather` — Poly Haven CC0, уже в реестре выше).
- **Анимации** — существующая библиотека Quaternius UAL (`sunny_realistic_poc/animations/`,
  CC0); для героев используется UAL, для Массовки — та же библиотека.
- **Mountain King** `models/mountain_king_p1.glb` — оригинальная процедурная модель, риг,
  пять клипов (`Idle`, `Walk`, `Telegraph`, `Attack`, `Death`) и 3 LOD; исходник
  `source/build_mountain_king.py`. Внешних моделей/текстур нет.
- **LOD**: LOD0/LOD1/LOD2 находятся в одном GLB, переключаются
  `scripts/characters/character_lod_visibility.gd`; это визуальная оптимизация, не геймплей.
- **Массовка**: `mass_*` — упрощённые силуэты без уникальных лиц/глаз; палитры по типам
  (горожанин, горожанка, раб, солдат, полиция).



- `GuideBeacon`, `ThoughtBubble` и `ObjectiveLine` — собственная процедурная геометрия и UI-код. Внешних моделей,
  текстур, шрифтов и звуков не добавлено; новых лицензий и атрибуции не требуется.
- Тексты целей и мыслей — авторские пересказы для проекта (`resources/campaign/beats/`, `resources/campaign/thoughts/`),
  не цитаты первоисточника.

## Боевая основа (`assets/audio/combat/`, `assets/shaders/`, 2026-11-01)

- `breath_cold_loop.wav` и `noise_rustle_loop.wav` — сгенерированы процедурно в проекте (Python, `wave`):
  отфильтрованный шум с огибающими дыхания и шороха. Внешних записей нет; лицензионных обязательств не возникает.
- `condition_vignette.gdshader`, `GuideBeacon`, `ThoughtBubble` — собственный код и процедурная геометрия; внешних
  моделей, текстур и шрифтов нет.
- `inspect_outline.gdshader` и компонент `Inspectable` — собственный код; внешних ассетов нет.

## Инструменты графического производства (2026-11-01)

Инструменты установлены на рабочей машине; в поставку игры не входят. Полный инвентарь с путями и проверками —
`docs/art/tooling_inventory.md`.

| Инструмент | Версия | Лицензия | Назначение | Статус |
|---|---|---|---|---|
| Krita | 5.3.4.1 | GPL-3.0 | 2D-живопись, decals, правка текстур | установлен 2026-11-01, `krita --version` |
| Materialize | 1.78 | GPL-3.0 | PBR-карты из изображений | установлен 2026-11-01, запуск проверен |
| glTF-Transform CLI | 4.5.1 | MIT | инспекция/оптимизация GLB | установлен 2026-11-01, `gltf-transform --version` |
| Blender | 5.1.1 | GPL-2.0-or-later | DCC, Geometry Nodes, Cycles | установлен; OptiX/Node Wrangler включены |
| Godot Engine | 4.7.2 | MIT | редактор/runtime | установлен |
| Material Maker | 1.7 | MIT | процедурные PBR-графы | установлен; экспериментальный |
| MaterialPilot | 0.1.0 | Apache-2.0 | автоматизация Material Maker | экспериментальный; не используется |
| Godot MCP | 0.6.1 | MIT | управление редактором/сценами | установлен; runtime helper не подключается из-за parse errors проекта |
| GUT | 9.7.1 | MIT | тесты | установлен |
| Blender MCP addon | 1.8 / protocol 15 | MIT | мост Blender ↔ MCP | проверен при открытом Blender |
| MPFB | 2.0.18 | GPL-3.0 (код) | MakeHuman-персонажи | установлен ранее |
| Node.js | 24.19.0 | MIT | CLI-инструменты | установлен |
| Python | 3.13.3 | PSF-2.0 | скрипты/текстуры | установлен |
| Git LFS | 3.5.1 | GPL-2.0 | бинарные ассеты | установлен |

GPL-инструменты не делают созданные в них игровые ассеты автоматически GPL: лицензия конкретного ассета определяется
его источником. Инструменты в поставку игры не входят.

## Staging Poly Haven (2026-11-01, не в проекте)

Скачано 9 CC0-наборов Poly Haven (27 файлов 2K JPG: diff/nor_gl/arm, ≈94,4 MiB) в
`%USERPROFILE%\Tools\asset_staging\polyhaven`; в Godot не импортировано, `.tres`/сцены не менялись.
Состав, авторы и проверка MD5 — `docs/art/asset_staging_manifest.md`.

- `coral_ground_02`, `coral_gravel`, `coral_mud_01` — Rob Tuytel, CC0.
- `coral_stone_wall`, `low_tide_rocks`, `damp_beach_sand` — Dimitrios Savva, CC0.
- `coral_fort_wall_01`, `coral_fort_wall_03` — Dimitrios Savva, Rico Cilliers, CC0.
- `coral_fort_wall_02` — Dimitrios Savva, CC0.

URL каждого набора: `https://polyhaven.com/a/<id>`; прямые ссылки на файлы — в `manifest.csv`. При переносе в `assets/` эти наборы должны быть внесены сюда отдельной записью с URL и датой импорта.

### P0 style gate (2026-11-01, staging, не в проекте)

- `island_tree_01`, `quiver_tree_01` — Poly Haven, CC0 1.0; 1K GLTF + текстуры; style-прокси для парка, не финальные.
- `kloofendal_misty_morning_puresky`, `kloofendal_overcast_puresky`, `qwantani_moon_noon_puresky` — Poly Haven, CC0 1.0; 2K HDR; варианты света.
- В Godot не импортированы; пути и размеры — `docs/art/asset_staging_manifest.md`.


## Аудио-плейсхолдеры (2026-11-01)

| Файл | Источник | Лицензия | Примечание |
|---|---|---|---|
| `assets/audio/sfx/player/footsteps/*.wav` | процедурная генерация `tools/audio/generate_placeholder_audio.py` (numpy) | project-owned, сторонние сэмплы не использованы | временные шаги, 9 поверхностей × 3 вариации (27 файлов) |
| `assets/audio/sfx/combat/*.wav` | та же генерация | project-owned | временные боевые SFX (12) |
| `assets/audio/sfx/world/*.wav` | та же генерация | project-owned | world/loop SFX, включая tide/storm/bone/coral/silver bell/whip/ritual (17) |
| `assets/audio/ui/*.wav` | та же генерация | project-owned | временные UI SFX (14) |
| `assets/audio/placeholder/music/*.ogg` | та же генерация, сжатие `tools/audio/compress_audio.py` | project-owned | 24 OGG-слоя (3 на cue: base/pulse/melody), включая labyrinth/pilgrim/finale |
| `assets/audio/placeholder/ambience/*.ogg` | та же генерация, сжатие `tools/audio/compress_audio.py` | project-owned | 9 ambience-петель, включая water/storm/bone/coral |
| `assets/audio/voice/lines/*.wav` | Windows SAPI `System.Speech`, Microsoft Irina Desktop (ru-RU), `tools/audio/export_voice_lines.gd` + `tools/audio/generate_sapi_voice.ps1` | временный синтез; условия Microsoft Windows/SAPI voice apply; не распространять как отдельный voice pack | 146 реплик пролога/каравана; не финальное VO |
| `assets/audio/voice/barks/*.wav` | тот же SAPI-синтез | те же условия | 30 барков; не финальное VO |
| `default_bus_layout.tres` | `tools/audio/build_bus_layout.gd` | project-owned | не является внешним ассетом |

Всего 279 сгенерированных аудиофайлов: 70 SFX WAV (mono/22,05 кГц), 176 SAPI voice WAV, 33 OGG (24 music layer + 9 ambience), около 47,9 МБ вместе с 5 существующими файлами. С demo-слоем Лабиринта — **296 файлов** (+17: 12 WAV + 5 OGG, ≈1,9 МБ). При замене на AI/записанные ассеты обновить эту таблицу, указать автора/лицензию и не выдавать плейсхолдеры за финальную озвучку.

## Demo-фрагмент Лабиринта: аудио и VFX (2026-11-02)

| Ассет | Источник | Лицензия | Примечание |
|---|---|---|---|
| `assets/audio/demo/sfx/*.wav` | процедурная генерация `tools/audio/generate_demo_audio.py` (numpy/scipy/soundfile) | project-owned, сторонние сэмплы не использованы | 12 коротких 3D-сигналов: карапакс, прилив, вода, ветер, Азурный клинок, осколок, Эхо, камень, отдых у костра |
| `assets/audio/demo/ambience/*.ogg` | та же генерация, OGG Vorbis, 44,1 кГц, стерео | project-owned | 2 петли: костёр и штормовой дождь; край петли с fade 12 мс |
| `assets/audio/demo/music/labyrinth_storm_*.ogg` | та же генерация, OGG Vorbis | project-owned | 3 слоя штормовой темы (`base/pulse/melody`), 16 с, D minor |
| `scenes/environment/vfx/*.tscn`, `scripts/vfx/one_shot_vfx.gd` | авторские Godot-сцены и скрипт, процедурные градиенты/меши | project-owned | impact ichor/dust, death carapace, tide spray, storm rain, azure motes |
| `scripts/audio/labyrinth_atmosphere.gd` | авторский скрипт | project-owned | привязка VFX/локального звука к зонам, приливу, костру и шторму |
| `assets/environments/nightmare/materials/nm_tide_water.gdshader` | авторский шейдер (существовал до этой сессии) | project-owned | применён к `Tide/WaterPlane` через `nm_tide_water_labyrinth.tres`; атрибуция не требуется |

**Важно:** новых внешних музыкальных или звуковых файлов нет. Референсы из `docs/audio/AUDIO_DESIGN_DOCUMENT.md` остаются только ссылками и не входят в сборку. SAPI-голос в демо-фрагменте Лабиринта не используется; для Нефис и Кассии озвучка пока отсутствует (текстовые субтитры). Файл `assets/audio/sanctuary/stone_door_large_001.ogg` (CC BY 4.0, DWOBoyle) относится к святилищу, а не к Лабиринту; если он попадёт в распространяемую сборку, нужна атрибуция.

## Character Animation Pipeline (2026-11-02)

### Rokoko free mocap packs (project subset)

| Ассет | Источник | Автор | Лицензия | URL | Дата | Примечание |
|---|---|---|---|---|---|---|
| `assets/characters/animation_library/rokoko/rokoko_walk_forward.fbx`, `rokoko_run_treadmill.fbx`, `rokoko_run_injured_treadmill.fbx` | Rokoko free pack `WALK-RUN-CYCLES-MOCAP.zip` (12 218 874 байт), 16 клипов; в проект взяты 3 клипа | Rokoko, захват Sam Lazarus | Rokoko free resource terms: использование в любых проектах, включая коммерческие; отдельного файла лицензии в ZIP нет | https://www.rokoko.com/resources/rokoko-mocap-16-free-walk-and-run-cycle-animations | 2026-11-02 | Исходные FBX; ретаргет и очистка дорожек выполнены в проекте |
| `assets/characters/animation_library/rokoko/rokoko_knife_stab_01.fbx`, `rokoko_knife_stab_02.fbx`, `rokoko_grenade_throw_01.fbx`, `rokoko_grenade_throw_02.fbx` | Rokoko free pack `MotionLibrary_Weapons.zip` (8 058 943 байт), 10 клипов; в проект взяты 4 клипа | Rokoko Motion Library contributors | Rokoko free resource terms: использование в любых проектах, включая коммерческие; отдельного файла лицензии в ZIP нет | https://www.rokoko.com/resources/motion-library-10-free-fight-and-weapon-animations | 2026-11-02 | Исходные FBX; ретаргет и очистка дорожек выполнены в проекте |
| `assets/characters/animation_library/rokoko_library.tres` | Слияние 7 импортированных Rokoko-клипов | Project-owned merge; анимации принадлежат Rokoko | Наследует лицензию исходных Rokoko-клипов | — | 2026-11-02 | Не самостоятельный ассет; хранит ссылки на клипы |
| `assets/characters/animation_library/rokoko/bone_map_rokoko_newton.tres` | Авторская карта костей Newton → SkeletonProfileHumanoid | Project-owned | — | — | 2026-11-02 | Не содержит сторонних ассетов |

Суммарный размер 7 FBX — 11 195 040 байт (~10,7 MiB). В Git попадают через LFS (`.fbx` уже в `.gitattributes`).

### Инструмент ретаргета

| Инструмент | Версия | Лицензия | Назначение | Статус |
|---|---|---|---|---|
| Blender Retarget extension | 5.2.0 | GPL-3.0-or-later | Ретаргет/бейк персонажных анимаций в Blender | Установлен 2026-11-02 в user extensions Blender 5.1.1; проверено `addon_utils.check("bl_ext.user_default.retarget") == (True, True)`. Не входит в поставку игры. Источник: https://extensions.blender.org/add-ons/retarget/ |

## Forgotten Shore: коралловый кит (2026-11-02)

Модели `assets/environments/nightmare/coral/*.glb` — собственные, собраны скриптом
`assets/environments/nightmare/source/build_coral_kit.py` (Blender 5.1). Внешних моделей нет.
Процедурная текстура `nm_bone_aged_*` — project-owned (скрипт `make_coral_textures.py`).

| Имя | Источник | Автор | Лицензия | URL | Дата | Ограничения |
|---|---|---|---|---|---|---|
| `coral_fort_wall_01_{diff,nor_gl,arm}_2k.jpg` | Poly Haven, набор Coral Fort Wall 01; скопировано из staging в `assets/environments/nightmare/materials/textures/` | Dimitrios Savva, Rico Cilliers | CC0 1.0 | https://polyhaven.com/a/coral_fort_wall_01 | 2026-11-02 | Атрибуция не обязательна; использован как субстрат поверхности, не как готовая органическая модель |
| `coral_fort_wall_02_{diff,nor_gl,arm}_2k.jpg` | Poly Haven, Coral Fort Wall 02 | Dimitrios Savva | CC0 1.0 | https://polyhaven.com/a/coral_fort_wall_02 | 2026-11-02 | То же |
| `coral_fort_wall_03_{diff,nor_gl,arm}_2k.jpg` | Poly Haven, Coral Fort Wall 03 | Dimitrios Savva, Rico Cilliers | CC0 1.0 | https://polyhaven.com/a/coral_fort_wall_03 | 2026-11-02 | То же |
| `coral_ground_02_{diff,nor_gl,arm}_2k.jpg` | Poly Haven, Coral Ground 02 | Rob Tuytel | CC0 1.0 | https://polyhaven.com/a/coral_ground_02 | 2026-11-02 | Грунт/коралловый щебень |
| `coral_mud_01_{diff,nor_gl,arm}_2k.jpg` | Poly Haven, Coral Mud 01 | Rob Tuytel | CC0 1.0 | https://polyhaven.com/a/coral_mud_01 | 2026-11-02 | Мокрый ил/низины |

Лицензия Poly Haven: https://polyhaven.com/license. Авторы и исходные имена сохранены в
`docs/art/asset_staging_manifest.md`; файлы перенесены в проект 2026-11-02.

## Море Души: кит P0–P1 (2026-11-02)

Модели `assets/environments/soul_sea/kit/*.glb` — собственные, собраны скриптом
`assets/environments/soul_sea/source/build_soul_sea_kit.py` (Blender 5.1). Внешних моделей нет.
Материалы `ss_*` — project-owned; `ss_obsidian` использует уже зарегистрированные в этом файле
текстуры `nm_marble_black_*`, `ss_basalt` — `nm_rock_albedo_2k` и `dark_rock_02_*` (CC0 Poly Haven
и производные проекта). Новых лицензий и новых внешних ассетов в этом пакете нет.


### P3 First Nightmare VFX (2026-11-02)

The following are generated, project-owned assets; no third-party license is introduced by this pass:

- `assets/environments/nightmare/materials/textures/p3_footprint.png`
- `assets/environments/nightmare/materials/textures/p3_blood.png`
- `assets/environments/nightmare/materials/textures/p3_chain_scrape.png`
- `assets/environments/nightmare/materials/p3_marble_polished.tres`
- `assets/environments/nightmare/source/make_p3_decals.py`

The three PNGs were generated procedurally by `make_p3_decals.py` (Pillow). `p3_marble_polished.tres` is a project-owned material variant built from the already-registered project black-marble textures (`nm_marble_black_*`); it introduces no new external download. P3 VFX scenes use Godot procedural particles and existing project materials.


### P2.5 Spell Void transition (2026-11-02)

P2.5 adds no new third-party asset. `scenes/slice/locations/spell_void.tscn`, `scripts/slice/locations/spell_void.gd` and `scenes/environment/p25_void_motes.tscn` are project-owned procedural Godot content. The floating silhouette reuses the already-registered P1 `sunny_p1_model.tscn`; rune rings, glyphs, particles and camera work are generated in-engine. No new external download or license is introduced.

### P4 UI / DOF / LUT (2026-11-02)

P4 introduces no third-party asset and no new external license. `resources/environment/p4_grade_lut.tres` is a project-owned procedural GradientTexture1D color grade. `resources/cameras/p4_cutscene_dof.tres` is a project-owned CameraAttributesPractical resource. UI uses the existing project-owned `RpgMenuTheme`; no font, icon or texture download was added.

### P5 park optimization derivatives (2026-11-02)

The five optimized park GLBs in `assets/environments/park/p2/p5/` are project-owned derivatives of the existing project-owned P2 park assets, produced with glTF-Transform 4.5.1 `join`. The originals remain in `assets/environments/park/p2/`. No third-party download, texture or new license was introduced.

## P1.5 cast gear pass (`assets/characters/p1/models/*_v2.glb`, 2026-11-02)

`hero_auro_v2`, `veteran_v2`, `shifty_v2`, `mass_slave_v2`, `mass_soldier_v2` — project-owned derivatives of the existing P1 MPFB/CC0 models. No new external models, textures, hair or animation packs were added. The only external material surface used by the new gear is the already-registered Poly Haven `brown_leather` (CC0). Hair donor for Hero is the project's own `mass_male.short02`. Original P1 `.glb` files remain in the repository.

## Generated character assets — Sunny v3 (2026-11-02)

- `assets/characters/generated/sunny_real_v3/sunny_real_v3.glb` — image-to-3D output generated in a previous pass with Hyper3D CLI from the project's approved Sunny concept. Project-owned output under the generating account's Hyper3D terms; no third-party model or texture was added. Verify the current Hyper3D terms before release.
- `assets/characters/generated/sunny_real_v3/sunny_real_v3_clean2.glb` — project-owned derivative of the above: fused sword vertices removed, walk/landroll forward drift flattened, MikkTSpace tangents added, material set single-sided, exported with Blender 5.1.1.
- `assets/characters/generated/sunny_real_v3/sunny_v3_model.gd`, `sunny_real_v3.tscn`, `resources/characters/sunny_v3_animation_tree.tres` — project-owned integration code/resources.
- `assets/characters/generated/hero_auro_v6/hero_auro_v6.glb` — generated with the same Hyper3D image-to-3D pipeline; project-owned generated output, no external textures/models added.
- `incoming_models/P0_characters/sunny_real_v2_rigged_core10.glb`, `sunny_nightmare_v2_raw.glb` — generated candidates retained as fallback/research; **not integrated**. They are not part of the shipped asset set.
- `assets/environments/nightmare/caravan/short_sword.glb` — project-owned procedural caravan prop used as the P1 weapon socket mesh; no external license.
- `incoming_models/concepts/white_horse/reference.png` — crop of the public-domain photograph `White horse.jpg` by Rosendahl, Wikimedia Commons (`File:White_horse.jpg`). Released into the public domain by the author; used only as an Image-to-3D reference. The generated `white_horse_v2_raw.glb` is a Hyper3D output; verify the generator's terms before shipping. Not yet integrated into `assets/`.
- `assets/characters/generated/{shifty_v4,scholar_v3,veteran_v5,broad_slave_v3}/` — Hyper3D text-to-3D + rigging outputs generated for this project, derived from the approved prompt set; project-owned candidate assets under the generating account's Hyper3D terms. No third-party model or texture was added. Verify the current Hyper3D terms before release. They are integrated as placeholders through `Mannequin`; the P1 fallbacks remain.
- `assets/characters/generated/white_horse_v2/` — Hyper3D Image-to-3D + quadruped rig output generated from the public-domain horse reference above. Candidate asset; not used by any scene (the caravan still uses the Quaternius/CC0 `horse.tscn` placeholder). Verify the generator's terms before shipping.
- `assets/characters/generated/mountain_king_v2/` — Hyper3D Image-to-3D + custom-rig output; custom native clips and integration code are project-owned. The old `mountain_king_p3` fallback remains. Verify the generator's terms before release.
- `assets/characters/generated/sunny_nightmare_v2/` — Hyper3D Image-to-3D + core rig output, re-materialled in Blender for the slave-cloth placeholder. Project-owned candidate under the generating account's Hyper3D terms; the P1 Nightmare fallback remains.
- `assets/characters/generated/white_horse_stock/` — clean static horse wrapper; source: Sketchfab **“Horse Rig”** by **CreativeMachine**, UID `bd71883bad9845389ef4ec2801004801`, **CC BY 4.0**. Re-materialled to white; no animations used. Keep attribution in credits.
- `incoming_models/P1_monsters/{centipede_gen_a_rigged.glb,worm_knot_gen_b_rigged.glb,blood_flower_gen_b_rigged.glb,carapace_centurion_gen_image_rigid_dark.glb}` and the dark/tinted variants — project-owned Hyper3D-generated candidates with Blender rigs/materials; not shipped in a scene yet. Verify Hyper3D terms before release.

## Vitals HUD sprite kit (2026-11-03)

- `assets/ui/vitals/hp_frame.png` - orthographic UI render of the Hyper3D CLI relief `442c7ad3-b6bf-4080-8d74-c4e2b6fcb8c3`; project-owned output under the generating account's Hyper3D terms. Recolored to the project's dark-crimson coral and bone/bronze palette in `tools/art/finalize_vitals_sprites.py`.
- `assets/ui/vitals/hp_medallion.png` - orthographic UI render of the Hyper3D CLI relief `8ae8e4d8-3993-4d8e-a827-6ec86dd7399a`; same terms and recolor pass.
- `assets/ui/vitals/hp_fill.png`, `hp_plate.png`, `hp_glow.png`, `hp_shine.png`, `hp_notch.png` - project-owned procedural PNGs generated by `tools/art/generate_vitals_textures.py` (Pillow/OpenCV/numpy). No external source or license.
- `incoming_models/P3_ui/hp_frame_raw.glb`, `hp_medallion_raw.glb` - raw Hyper3D outputs retained locally for reproducibility; gitignored, not shipped. Verify current Hyper3D terms before release.
- `assets/ui/vitals/vitals_vignette.gdshader`, `scenes/ui/vitals_bar.tscn`, `scripts/ui/vitals_bar.gd`, `scripts/ui/vitals_display.gd` - project-owned code/resources.

## 2026-11-03 - Equipment alpha assets

- `assets/characters/equipment/armor/caravan_alpha.glb`, `coral_alpha.glb` - project-owned procedural blockout armour, derived from the existing `sunny_nightmare_v2` mesh and built by `assets/characters/equipment/source/build_caravan_alpha.py` (Blender 5.1). No external textures or third-party models.
- `short_sword.glb` and `water_flask.glb` - existing project-owned caravan props, reused as alpha weapon/accessory; no new license.

## 2026-11-03 - Stealth cover kit (Hyper3D CLI)

- `assets/environments/nightmare/path/stealth_cover_a.glb`, `stealth_cover_b.glb`, `stealth_cover_c.glb` - text-to-3D outputs generated with Hyper3D CLI (`@hyper3d/cli` 0.3.0, Rodin Gen-2.5-High, Quad, GLB, PBR) from the project's own prompts. Generation IDs: `b73755ad-cc3a-4dbc-b0fc-6c956abdfd1d`, `54f8fa8c-4cb4-490c-a4b9-a7bd12989e1e`, `7ddfff73-e8cc-4ce6-89a3-2cdb93b95a60`. Post-processed in Blender 5.1 (join, target scale, bottom-centre origin, decimate, UV box, normals) by `assets/environments/nightmare/source/build_stealth_covers.py`. Project-owned generated output under the generating account's Hyper3D terms; no third-party model or texture was added. Verify the current Hyper3D terms before release.
- `incoming_models/P2_environment/stealth_covers/cover_{a,b,c}_raw.glb` - raw Hyper3D outputs retained locally for reproducibility; gitignored, not shipped.
- `assets/environments/nightmare/source/build_stealth_covers.py`, `stealth_covers.blend` - project-owned pipeline and source scene.
- `assets/environments/nightmare/materials/nm_rock_cover.tres` - project-owned variant of `nm_rock.tres` (base tint, snow coverage); reuses the already-registered Poly Haven CC0 rock/snow textures. No new external texture.
- `docs/art/previews/nightmare/stealth_covers.jpg`, `stealth_covers_before.jpg`, `stealth_covers_after.jpg`, `stealth_covers_after_wide.jpg` - project-owned preview/render captures. Not shipped runtime assets.

## 2026-11-03 — Loot containers (Hyper3D CLI)

- `assets/models/containers/chest_wood_iron.glb`, `loot_barrel_cluster.glb`, `ancient_tomb_sarcophagus.glb` — text-to-3D outputs generated with the project Hyper3D CLI (`@hyper3d/cli`, Rodin Gen-2.5-Medium, Quad, GLB, PBR) from the project's own prompts. Generation IDs: `4a6852b4-d4ab-47d2-b466-fdb0cc07070a`, `b716c37b-4a83-45d5-8317-ed9ee6325f01`, `60280f7a-5b6a-4bb3-b61a-3a0d37388f7c`. Post-processed in Blender 5.1 (join, target scale, decimate, bottom-centre origin, 1K resize) through Blender MCP. Project-owned generated output under the generating account's Hyper3D terms; no third-party model or texture was added. Verify the current Hyper3D terms before release.
- `incoming_models/P2_environment/containers/chest_wood_iron_raw.glb`, `loot_barrel_cluster_raw.glb`, `ancient_tomb_sarcophagus_raw.glb` — raw Hyper3D outputs retained locally for reproducibility; gitignored, not shipped.
- `docs/art/previews/containers/*.png` — project-owned Blender preview renders; not shipped runtime assets.
- `resources/loot/items/*.tres`, `resources/loot/tables/*.tres`, `resources/loot/loot_catalog.tres` — project-owned data resources; no external license.

## 2026-11-03 - Generated armour sets (Hyper3D CLI + Blender rebind)

- `assets/characters/equipment/armor/scout_leather.glb` - Hyper3D text-to-3D outfit generation `d3a04960-d300-40f7-9632-4902df14d0ec`, human/core rig `cdddc84f-2ab0-4310-9941-0280c4cd24b6`. Project-owned generated output under the generating account's Hyper3D terms; no third-party model or texture was added. Verify the current Hyper3D terms before release.
- `assets/characters/equipment/armor/mercenary_medium.glb` - generation `fedeb263-cf19-4eca-b225-ebd980bd06a6`, rig `38d6f2cc-71a6-4b48-bf00-1692db2a49a2`; same terms.
- `assets/characters/equipment/armor/heavy_plate.glb` - generation `18d9b4bb-ca0d-45ec-a04d-51dabd958102`, rig `49ebaa26-44a9-4b27-af8e-6f3ac740ec9b`; same terms.
- All three were post-processed in Blender 5.1: the blank mannequin head island was removed by `assets/characters/equipment/source/prepare_generated_armor.py`; the outfit was re-bound to the project `sunny_nightmare_v2` skeleton with weight transfer by `assets/characters/equipment/source/rebind_generated_armor.py`; cloth/plate materials were split by `split_armor_materials.py`; the Scout hood was weighted to `Head` by `fix_armor_head_weights.py`; LOD0/1/2 were built by `build_armor_lods.py`; textures were resized to 1024 with glTF-Transform 4.5.1. `rigidify_armor_plates.py` was evaluated and rejected (plate separation in the boxing guard), so smooth transferred weights are retained.
- `incoming_models/P2_equipment/*_raw.glb` and `*_rigged.glb` - raw Hyper3D outputs retained locally for reproducibility; gitignored, not shipped. Verify the current Hyper3D terms before release.
- `resources/equipment/armor/scout_leather.tres`, `mercenary_medium.tres`, `heavy_plate.tres`; `resources/equipment/stats/*_stats.tres`; `resources/loot/demo_loot.tres` - project-owned data resources; no external license.
- `docs/art/previews/equipment/*.png` - project-owned Godot capture renders; not shipped runtime assets.

## 2026-11-03 - Reference-layout HUD (minimap, quick items, control hints)

- `assets/ui/hud/minimap_mask.gdshader`, `scenes/ui/hud_minimap.tscn`, `scripts/ui/hud_minimap.gd`, `scripts/ui/hud_minimap_canvas.gd` - project-owned circular minimap and compass. Map data is read from the existing `MapSystem`; no new map or external image is introduced.
- `scenes/ui/hud_quick_items.tscn`, `scripts/ui/hud_quick_items.gd` - project-owned quick-items strip. It reads existing `NightmareRunState` item counts; no new inventory or item data.
- `scenes/ui/hud_control_hints.tscn`, `scripts/ui/hud_control_hints.gd` - project-owned control hints. Key labels are read from the existing `InputMap`; no external font or image.
- `assets/ui/rpg_menu/icons/torch.svg` - project-owned line icon in the existing menu icon language.
- `docs/art/previews/hud_reference/hud_reference_full.png`, `hud_reference_subtitles.png` - project-owned Godot capture renders; not shipped runtime assets.
- `tools/audit/gameplay_hud_capture.gd` - project-owned HUD capture tool.

## 2026-11-03 — Loot category icons

- `assets/ui/loot/icons/loot_{currency,material,consumable,tool,equipment,memory,key,relic}.png` — project-owned procedural 128×128 RGBA icons generated by `tools/art/make_loot_icons.py` (Pillow). No external source, texture or license.
- `tools/art/make_loot_icons.py` — project-owned generator script.
