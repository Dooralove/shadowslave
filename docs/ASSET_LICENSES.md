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
