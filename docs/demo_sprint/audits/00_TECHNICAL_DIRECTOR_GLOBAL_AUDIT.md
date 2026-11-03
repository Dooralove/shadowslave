# Глобальный аудит Technical Director

Дата: 2026-11-02, 20:10–20:30 +03:00  
Автор: Chat 00 — Technical Director / Integration Lead  
HEAD: `0335a5c346901af2146413b5a159b442d326d8de` (ветка `s3-park-art`)  
Статус: статический аудит + фактический импорт, полный GUT, запуск двух сцен через MCP.  
Ручной проход: **NOT TESTED**.

> Рабочее дерево живое: параллельные чаты пишут `scripts/quests/*`, `LabyrinthQuestDirector`, материалы Лабиринта и документы `docs/demo_sprint/*` во время аудита. Все числа — снимок, а не вечная истина.

## 0. Краткий вывод

1. **Единственная законченная сюжетная арка — Первый Кошмар P01–N26.** Она подключена к меню, имеет финальную карточку, 26 событий, 49 диалоговых ресурсов, арт P2–P5, аудио-каркас и 74 тестовых скрипта.
2. **Полный GUT красный:** 74 скрипта, 577 тестов, 575 pass, 2 fail, 6857/6869 assert, exit 1. Оба падения — stale-контракт `test_post_nightmare_locations` с новым `black_sea_platform`.
3. **Документация сильно отстала от кода.** README и route verification говорят о 35/255 тестах; фактически 74/577. README говорит, что звука нет; фактически 569 аудиофайлов и `AudioDirector`. AGENTS говорит, что runtime helper не подключается; фактически подключился.
4. **N18 (личинка Шифти) отсутствует в исполнении.** `pilgrim_path_arrival.gd` после `kill_shifty()` сразу вызывает `begin_dawn()`; флаг `shifty_larva_killed` в gameplay не ставится нигде, только в тестах. Это ломает канонический блок 14 и оценку N25.
5. **N07 (Bloodbane) сыгран неверно.** В лагере проигрывается `camp_berries.tres` («ягоды»), а `camp_bloodbane.tres` не используется; `camp_bloodbane_seen` ставится постановкой, а не предупреждением Учёного.
6. **Пост-Кошмарная цепочка не имеет входа.** `finale.gd` умеет только `R → campaign_entry`. `police_precinct → … → coral_labyrinth` связана порталами внутри себя, но не из финала, меню или кампании.
7. **Два разных Лабиринта.** `scenes/locations/post_nightmare/coral_labyrinth.tscn` — старый greybox B03–B05; `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn` — новый 18-зонный полигон. Они не связаны; второй не входит ни в одну цепочку.
8. **Море Души — техдемо в арене.** `SoulSeaController` есть только в `combat_arena.tscn`, клавиша `V`; в кампании точки входа нет.
9. **Боевая система есть, но в кампании почти не используется.** Второй личинка на стоянке — реальный бой; остальное — sandbox/арены. Mountain King в каноне — cinematics, не босс-файт.
10. **P5-оптимизации отключены в `project.godot`.** Параллельный чат удалил блок `[rendering]` с `import_s3tc_bptc`, `use_occlusion_culling`, `mesh_lod threshold_pixels=1.5`. Это регрессия относительно P5; вернуть — P0.
11. **Демо-стержень должен быть Первым Кошмаром.** Лабиринт и пост-Кошмар — отдельные tech demo, иначе 3 часа уйдут на серую геометрию без конца и начала.

## 1. Метод и границы

### 1.1. Что реально запускалось

| Проверка | Команда / метод | Результат |
|---|---|---|
| Импорт | `godot --headless --path . --import` | exit 0 |
| Полный GUT | `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` | 74/577, 575 pass, 2 fail, exit 1, 263.6 s |
| Главное меню | MCP `run_scene` | запустилось, runtime helper connected, немедленных ошибок нет |
| Кампания | MCP `run_scene` | запустилась, runtime helper connected, немедленных ошибок нет |
| Скриншот | MCP `take_screenshot` | **«Viewport returned no image»** — доказательств нет |
| Git LFS | `git lfs fsck --pointers` | OK |
| Git diff | `git diff --check` | exit 0 |

### 1.2. Что не запускалось

- Полный ручной проход от меню до финальной карточки.
- Ручной бой, стелс, падения, камера, геймпад.
- Прослушивание звука.
- 1080p/60 с vsync, 4K, ultrawide, минимальное железо.
- Свежий клон с нуля.
- Пост-Кошмарная цепочка и Лабиринт вручную.

Всё это — **NOT TESTED**.

## 2. Архитектура

### 2.1. Autoload и владение состоянием

| Autoload | Файл | Роль | Замечание |
|---|---|---|---|
| `MCPRuntime` | `addons/godot_mcp/runtime/mcp_runtime.gd` | runtime-мост MCP | временный, убрать/исключить перед релизом |
| `NightmareRunState` | `scripts/campaign/nightmare_run_state.gd` | флаги, предметы, бестиарий, квесты, валюта, Памяти, чекпоинт | параллельно расширяется QuestSystem; snapshot/restore есть |
| `DialogueManager` | `scripts/systems/dialogue_manager.gd` | диалоги/субтитры | линейный, без выбора |
| `MapSystem` | `scripts/map/map_system.gd` | карта по `M` | сначала меню, fallback `MapScreen` |
| `PlayerMenuSystem` | `scripts/ui/player_menu_system.gd` | меню `C`/`I` | одно окно, пауза |
| `PauseMenuSystem` | `scripts/ui/pause_menu_system.gd` | pause-меню | добавлен параллельно 20:15 |
| `CampaignGuide` | `scripts/guide/campaign_guide.gd` | цель, журнал, бестиарий, мысли | параллельно получил `external_objective` |
| `QuestSystem` | `scripts/quests/quest_system.gd` | квестовый журнал Лабиринта | добавлен параллельно 20:15; в S00–S15 не входит |
| `AudioDirector` | `scripts/audio/audio_director.gd` | шины, музыка, эмбиент, SFX, VO, reverb | 6 шин, pause, captions |

Состояние — плоские словари, без ссылок на узлы. Файлового сохранения нет: `snapshot()`/`restore()` живут в памяти. Для демо этого достаточно; для «продолжить» — нет.

### 2.2. Маршрут кампании

```text
main_menu
  → campaign_entry (reset)
  → prologue B01–B16 (P01–P05)
  → first_nightmare_pass N06
  → caravan_site_arrival N07–N13
  → pilgrim_path_arrival N14–N23
  → sanctuary_arrival N24
  → appraisal_arrival N25
  → finale_arrival N26
  → карточка / R → campaign_entry
```

Подтверждение: `NEXT_SCENE` в оболочках, `tests/test_full_route.gd` (3 теста, 18 шагов), `tests/test_campaign_flow.gd` (11 тестов).

### 2.3. Пост-Кошмарная цепочка

```text
police_precinct ⇄ academy_approach ⇄ academy_gate ⇄ academy_campus
  ⇄ academy_sleeper_center → black_sea_platform ⇄ tide_descent ⇄ coral_labyrinth
```

- 8 сцен, 13 порталов, 15 map definitions.
- Вход из `finale_arrival`, `main_menu` или `campaign_entry` **отсутствует**.
- NPC, диалогов, квестов и сюжетных триггеров в цепочке нет.
- `black_sea_platform` — единственная сцена с hero-ассетом (StatueKnightLOD); остальные — greybox.

### 2.4. Лабиринт

Есть две реализации:

| Сцена | Что это | Статус |
|---|---|---|
| `scenes/locations/post_nightmare/coral_labyrinth.tscn` | старый greybox B03–B05, комнаты/коридоры, `CoralLabyrinth` | входит в пост-Кошмарную цепочку |
| `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn` | новый 18-зонный полигон Z01–Z18, ~1.5 км, tide, coral art | **ни к чему не подключён**, кроме тестов |

Новый полигон содержит `TideController` (120-секундный цикл, 8 шлюзов), `LabyrinthAudio`, `LabyrinthAtmosphere`, `LabyrinthArt` (60 GLB кораллового кита), маркеры NPC/encounters/items. Параллельный чат добавляет `LabyrinthQuestDirector`, `QuestSystem`, NPC, pickups, encounters.

Это **не** продолжение Первого Кошмара и не вход в демо. Это отдельный tech demo.

### 2.5. Sandbox и техдемо

| Сцена | Роль |
|---|---|
| `scenes/levels/combat_arena.tscn` | боевая арена, Carapace, SoulSeaController, InventoryPrototype |
| `scenes/levels/ambush_site_demo.tscn` | неканонический sandbox засады |
| `scenes/levels/larva_arena.tscn` | тестовая арена личинки |
| `scenes/levels/test_level.tscn` | тестовый уровень |
| `scenes/soul_sea/soul_sea.tscn` | модальное Море Души |
| `scenes/dev/*` | превью ассетов |

## 3. Контент

### 3.1. Объём

| Показатель | Значение |
|---|---:|
| `.tscn` | 113 |
| `.gd` | 195 |
| `.tres` | 208 |
| `.glb` | 320 |
| тестовых скриптов | 74 |
| файлов в `assets/` | 2277 |
| объём `assets/` | 819.3 МБ |
| LFS-файлов | 1081 |
| markdown в `docs/` | 106 |
| битов `BeatDirector` | 26 |
| диалоговых последовательностей | 49 |
| записей бестиария | 3 |
| записей глоссария персонажей | 0 |
| map definitions | 15 |
| аудиофайлов | 569 |

### 3.2. Пролог

- `scenes/slice/prologue.tscn` — 6 локаций через `location_overrides`.
- Все локации — art-варианты: `park_street_art`, `station_lobby_art`, `containment_room_art`, `mountain_vision_art`, `caravan_road_art`.
- B01–B16: скамейка, кофе, Code Black, изолятор, брифинг, тьма, видение, караван, руны.
- `test_prologue_art` 10/10, `test_slice_locations` 8/8, `test_slice_director` 11/11.
- Ручной проход — **NOT TESTED**.

### 3.3. Первый Кошмар

| Блок | Сцена | Статус |
|---|---|---|
| N06 марш | `first_nightmare_pass` + `caravan_road_art` | работает по коду |
| N07 стоянка | `caravan_site_arrival` + `caravan_site_art` | **N07 Bloodbane сыгран неверно** |
| N08–N13 нападение/личинка/повозка/последействие/ночь | `caravan_site` | работает по коду; второй личинка — бой |
| N14–N17 дорога/альков/Шифти | `pilgrim_path` | работает по коду |
| N18 личинка Шифти | `pilgrim_path` | **отсутствует в исполнении** |
| N19–N23 Учёный/пещера/стелс/Герой/храм | `pilgrim_path` | работает по коду; N19 обходит N18 |
| N24 алтарь/Тиран/тени | `sanctuary_arrival` + `shadow_sanctuary_art` | работает по коду |
| N25 оценка | `appraisal_arrival` | работает; первая личинка не отделена от личинки Шифти |
| N26 пробуждение/карточка | `finale_arrival` | работает по коду; `R` |

### 3.4. Пост-Кошмар

- 5 основных локаций + 3 связующие.
- `black_sea_platform`: статуя-колосс, LOD0/1/2, 7 звёзд, меч; `StatueKnightLOD`.
- Остальные — greybox с материал-палитрой.
- `test_post_nightmare_locations` 5/7: два падения из-за старого контракта модулей.
- Нет NPC/диалогов/квестов; сюжетно не связано с финалом.

### 3.5. Лабиринт

- 18 зон, три акта, high/low routes, 63 переходные точки (по docs).
- `TideController`: 120 с, low_y −8, high_y 4, gate_threshold 2.
- `LabyrinthArt`: 60 GLB кораллового кита, материалы, декор.
- `LabyrinthQuestDirector` (параллельно): триггеры, чекпоинты, pickups, NPC, encounters.
- Нет локальной карты для 18 зон (есть только регион `forgotten_shore` с тестовыми сценами).
- Нет шторма/дождя/молний, нет NPC-моделей (параллельно добавляются).
- Ручной проход 1.5 км — **NOT TESTED**.

### 3.6. Море Души

- `soul_sea.tscn`, `SoulSeaController`, HUD, 63 GLB kit.
- Модальный вход по `V` только в `combat_arena`.
- `test_soul_sea_scene` 3/3, `test_inventory_and_soul_sea` в составе `test_rpg_menu_glossary`/`test_player_menu_system` — косвенно.
- В кампании входа нет.

## 4. Системы и тесты

| Система | Ключевые файлы | Тесты | Факт |
|---|---|---|---|
| State | `nightmare_run_state.gd` | `test_nightmare_run_state` 5/5, `test_bestiary_journal` 5/5 | flags/items/bestiary/quests/currency/memories; snapshot |
| Beat/Guide | `beat_director.gd`, `campaign_guide.gd` | `test_beat_system` 7/7, `test_campaign_guide` 9/9 | 26 beats, одна цель, журнал, мысли |
| Dialogue | `dialogue_runner.gd` | `test_dialogue` 5/5, `test_dialogue_barks` 15/15 | линейный, без выбора |
| Interaction | `interactable.gd`, `interactor.gd` | `test_interaction` 7/7 | E, радиус, приоритет |
| Inspect | `inspectable.gd` | `test_inspectable` 7/7 | подсветка, флаги, мысль |
| Combat | `combat_controller.gd`, `health_component.gd`, `melee_attack.gd` | 8+9+13+6+5+5+11+6+9 | работает; в кампании — второй личинка |
| Enemies | Larva, Mountain King, Carapace, TestEnemy | 5+11+5+9 | Carapace — арена; Mountain King — cinematic |
| UI/Menu | `rpg_menu_prototype.gd`, screens | 10+7+22+6+1 | 8 вкладок, глоссарий, карта, медитация |
| Map | `map_system.gd`, `map_canvas.gd` | 22/22 | 15 map definitions |
| Audio | `audio_director.gd`, cue library | 19+7+6+6 | 13 music/49 SFX/29 ambience; VO SAPI |
| Settings | `game_settings.gd` | 6/6 | графика/звук; **нет rebind** |
| Level transitions | `level_portal.gd` | 22/22 | fade, spawn, gates |
| Prologue | `slice_director.gd` | 11/11 + art 10/10 | B01–B16 |
| Post-nightmare | `greybox_location.gd`, `black_sea_platform.gd` | 5/7 | stale test |
| Labyrinth | `labyrinth_first_fragment.gd`, `tide_controller.gd` | 13/13 | standalone |
| Soul Sea | `soul_sea_controller.gd` | 3/3 | modal in arena |
| Quest (new) | `scripts/quests/*` | нет полного набора | параллельная работа |

### 4.1. Полный GUT: фактический результат

```text
Scripts              74
Tests               577
Passing Tests       575
Failing Tests         2
Asserts           6857/6869
Time              263.581s
EXIT=1
```

Падения:

- `test_post_nightmare_locations::test_each_location_scene_builds_greybox` — у `black_sea_platform` нет модулей `NeckPlatform`, `BrokenCollar`, `ShoulderWest`, `ShoulderEast`, `Chest`, `ChestStars`, `Sword`.
- `test_post_nightmare_locations::test_black_sea_platform_matches_canonical_statue_neck` — `has_module()` false, `get_module()` null.

Причина: сцена переведена на `StatueKnightLOD`, primitive-модули больше не строятся; тест проверяет старый контракт `GreyboxLocation.has_module()`. Это не runtime-баг, но baseline красный.

### 4.2. Пробелы покрытия

- Нет теста N18 и флага `shifty_larva_killed` в gameplay.
- Нет теста N07 Bloodbane (есть только staged flags).
- Нет теста входа в пост-Кошмарную цепочку (потому что входа нет).
- Нет теста входа в Лабиринт из меню/кампании.
- Нет теста Soul Sea в кампании.
- Нет теста файлового сохранения (его нет).
- Нет теста полного ручного прохода (по определению).
- Нет теста 1080p/60 с vsync.

## 5. Расхождения «документ ↔ реализация»

| # | Документ | Утверждение | Факт | Риск |
|---:|---|---|---|---|
| 1 | `README.md:17` | 35 scripts / 255 tests / 2473 asserts | 74 / 577 / 6857–6869, 2 fail | занижает объём и скрывает красный suite |
| 2 | `docs/design/first_nightmare_route_verification.md:18-23` | 35 / 255 / 2473 | то же | устарело |
| 3 | `docs/design/game_menu_audit.md:154` | 70 / 554 / 6746 | устарело | устарело |
| 4 | `docs/art/p5_optimization.md:93` | 73 / 572 / 6848, exit 0 | устарело | устарело |
| 5 | `docs/AI_HANDOFF_AFTER_S3_2.md:103` | основная сцена `main.tscn` | `main_menu.tscn` | путаница входа |
| 6 | `README.md:104` | звука нет, файлов Music/SFX нет | 569 аудиофайлов, `AudioDirector`, 26 аудиотестов | занижает готовность |
| 7 | `AGENTS.md` (MCP) | runtime helper не подключается | подключился; сцены запускаются | неверная оценка инструментов |
| 8 | `AGENTS.md` (Blender) | внешние библиотеки/генераторы off | Sketchfab on, Hyper3D on | drift конфигурации |
| 9 | `docs/design/level_transitions.md:4` | цепочка после Кошмара подключена | только внутри себя; входа из финала/меню нет | можно принять за готовый контент |
| 10 | `docs/design/first_nightmare_scene_matrix.md:75` | страж храма не реализован | `pilgrim_path` TempleGuard + 13 тестов | недооценка готовности |
| 11 | `docs/design/first_nightmare_scene_matrix.md` | блок 14 (N18) готов | N18 отсутствует; `shifty_larva_killed` не ставится | канонический разрыв |
| 12 | `docs/design/first_nightmare_scene_matrix.md` | N07 Bloodbane | `camp_berries.tres`, Bloodbane не звучит | сюжетная ошибка |
| 13 | `docs/design/11_combat_system.md:4` | боевые встречи в кампанию не встроены | второй личинка на стоянке — бой | недооценка |
| 14 | `docs/design/12_inventory_economy_and_consumables.md:4` | в Godot ничего не реализовано | items, inventory UI, demo session, quests/currency | устарело |
| 15 | `docs/audio/AUDIO_IMPLEMENTATION_AUDIT.md:44` | полный GUT NOT PASSED из-за park/sunny | текущие падения — post-nightmare test | историческая причина |
| 16 | `docs/production/not_tested_inventory.md` | 150 вхождений | `DECISIONS.md` говорит 142; индекс не пересчитан | метрика устарела |
| 17 | `README.md:104` | настройки — шаблон, rebind не реализован | графика/звук есть, rebind нет | частично верно |
| 18 | `docs/design/level_transitions.md:262` | `test_post_nightmare_locations` 7/7, 473 assert | 5/7, 2 fail | красный suite |
| 19 | `docs/design/game_menu_audit.md:154` | полный GUT зелёный после import | 2 fail | устарело |
| 20 | `docs/design/first_nightmare_gap_matrix.md:22` | 35 / 255 / 2473 | устарело | исторический документ, но цитируется как текущий |
| 21 | `docs/art/p5_optimization.md:58,65,70` | S3TC/BPTC, occlusion culling, mesh LOD threshold включены в `project.godot` | блок `[rendering]` удалён параллельной правкой | **регрессия P5**; вернуть до демо |
| 22 | `docs/design/first_nightmare_scene_matrix.md:75` | страж храма не реализован | реализован, 13 тестов | недооценка |
| 23 | `docs/design/12_inventory...:4` | инвентарь/экономика не реализованы | items, demo inventory, quests/currency | устарело |

Вывод: **нельзя строить план по числам из README/DECISIONS.** Все отчёты должны проверять код и запускать тесты.

## 6. Оценка готовности к демо

| Область | Контент | Доказательство | Вердикт |
|---|---:|---:|---|
| Пролог B01–B16 | 90% | 60% (тесты, без ручного) | готов по коду |
| Первый Кошмар N06–N26 | 80% | 55% | почти готов; N07/N18/N25 — P0 |
| Пост-Кошмар | 45% техники | 15% | не демо |
| Лабиринт 18 зон | 35% (геометрия/арт/тид + параллельный gameplay) | 20% | tech demo, не кампания |
| Море Души | 60% техники | 30% | tech demo в арене |
| Бой | 70% системы | 30% в кампании | работает, мало контента |
| UI/меню | 75% | 60% | рабочее, нужна полировка |
| Аудио | 70% каркаса | 0% слуха | технически есть, субъективно нет |
| Арт | 75% | 50% | P2–P5 есть; читаемость/свет — P1 |
| Тесты | 74 скрипта | 575/577 | красный из-за 2 stale |

### 6.1. Что это значит для 3 часов

- **Нельзя** начинать с Лабиринта: 18 зон greybox, нет конца, нет входа, нет карты, нет NPC (параллельно появляются).
- **Можно** довести Первый Кошмар: 4 контентных P0 + 1 тестовый контракт + ручной проход.
- **Можно** оставить Лабиринт как отдельный tech demo, если P0 зелёный.

## 7. Риски интеграции

| Риск | Вероятность | Влияние | Смягчение |
|---|---|---|---|
| Параллельные чаты меняют общие файлы | высокая | конфликты, потеря работы | `OWNERSHIP.md`, `ACTIVE_CLAIMS.md`, freeze |
| Scope split: Narrative — Первый Кошмар, Quest — Лабиринт | высокая | силы уходят в разные демо | решение TD: основной стержень + отдельный tech demo |
| Красный GUT | высокая | нельзя заявить готовность | P0-1 первым |
| Нет ручного прохода | высокая | демо не доказано | P0-2, чек-лист |
| N18 требует боя в сюжетной сцене | средняя | можно сломать N19 | отдельная арена/сцена, тест флага |
| N07 меняет диалог и флаги | средняя | можно сломать camp_explored | целевой тест |
| Два Лабиринта | высокая | путаница, дублирование | явно разделить: `coral_labyrinth` — старый sandbox, `labyrinth_first_fragment` — tech demo |
| 819 МБ ассетов, импорт дорогой | средняя | таймауты | не переимпортировать без нужды |
| Скриншоты MCP не работают | средняя | нет визуальных доказательств | `tools/audit/*.gd`, отдельный запуск |
| SAPI VO 42 МБ, 83 реплики без файлов | средняя | не финальный звук | captions, `NOT TESTED` |
| MCPRuntime в релизе | низкая | лишний autoload | убрать перед сборкой |

## 8. Рекомендованный план

### P0 — демо

1. **Зафиксировать scope:** Первый Кошмар — основной; Лабиринт — отдельный tech demo.
2. **P0-0:** вернуть в `project.godot` блок `[rendering]`: `import_s3tc_bptc`, `use_occlusion_culling`, `mesh_lod threshold_pixels=1.5`.
3. **P0-1:** согласовать `test_post_nightmare_locations` с новым `black_sea_platform` (не удалять проверки, а проверить новые узлы/ассет).
4. **P0-2:** N07 Bloodbane.
5. **P0-3:** N18 + гейт N19 + `shifty_larva_killed`.
6. **P0-4:** N25 — разделить первое и второе деяния личинок.
7. **P0-5:** полный ручной проход S00–S15; чек-лист.
8. **P0-6:** импорт + полный GUT + отсутствие новых ошибок.
9. **P0-7:** меню → кампания → финальная карточка → `R`.
10. **P0-8:** аудио/UI sanity в кампании.

### P1 — качество

- N22/N23 один «Found you».
- N16 обмен о слепоте + бестиарий в момент наблюдения.
- N09 атрибуция второй личинки.
- P03 Рейн.
- Свет/читаемость алькова, пещеры, святилища.
- Foot sliding, анимации, камера.
- UI-тема, субтитры, captions.
- Чистка 9 предупреждений.

### Stretch — tech demo

- Лабиринт «Забытый берег» отдельным запуском.
- Пост-Кошмарный тизер (участок → академия → Чёрное море).
- Море Души из меню.
- QuestSystem/побочные задания.

## 9. Открытые решения

1. **Scope:** Первый Кошмар (рекомендуется) или Лабиринт как основное демо. Это решение пользователя/TD; от него зависит всё.
2. **N18:** делать бой или сокращённую сцену с личинкой? Канон требует личинку; бой можно упростить.
3. **N07:** заменить `camp_berries` на `camp_bloodbane` или добавить предупреждение Учёного в существующую сцену?
4. **Лабиринт:** оставить отдельным tech demo или подключить вместо `coral_labyrinth`? Второе — большой риск для 3 часов.
5. **Пост-Кошмар:** не подключать к финалу; оставить отдельным запуском.

## 10. Что я не проверял

- Полный ручной проход.
- Бой, стелс, падения, камеру, геймпад.
- Звук на слух.
- 1080p/60, 4K, ultrawide, минимальное железо.
- Свежий клон.
- Пост-Кошмарную цепочку и Лабиринт вручную.
- Новые quest-скрипты параллельного чата (они менялись во время аудита).

Всё перечисленное — **NOT TESTED**.
