# Аудит реализованных систем ShadowSlave

Дата: 2026-11-03. Ветка: `demo/integration`. Рабочее дерево грязное (pre-existing изменения и untracked-файлы других задач); код в этом аудите не менялся.
Статус: **автоматические проверки зелёные; ручной проход, звук и производительность — NOT TESTED**.

Документ не заменяет ручной playtest. Он фиксирует, что реально реализовано в коде, что проверено автоматически и какие архитектурные риски остаются до следующего этапа.

## 0. Итог

1. **Каркас демо-маршрута собран и проходит автоматические проверки.** S00–S15, 26 beat-событий, 12 квестовых ресурсов, сохранение состояния, боевой слой, стелс, UI, аудио и карта имеют работающий код и GUT-покрытие.
2. **Полный GUT зелёный на повторном прогоне:** 88 скриптов, **711/711 тестов**, **7 811 asserts**, exit 0. Первый полный прогон оборвался на `test_caravan_march` с exit -1; изолированный тест — 7/7, повторный полный прогон — 711/711. Это похоже на transient-сбой харнесса/движка, а не на воспроизводимый дефект, но его нужно наблюдать.
3. **Главные незакрытые системы — не «ещё один экран», а границы состояния.** Кампания хранит прогресс в `NightmareRunState`, а новый equipment-слой — в `InventoryComponent`/`EquipmentComponent`; это два разных хранилища. SaveSystem сохраняет только первое. Решение «два loot-слоя намеренно» записано в `DECISIONS.md`, но контракт сохранения экипировки пока не определён.
4. **Релизный gate не пройден:** нет `export_presets.cfg`, в `project.godot` остаётся autoload `MCPRuntime`, полный ручной проход не выполнялся.
5. **README был устаревшим и обновлён:** до аудита он говорил о 35/255 тестах, падении `test_labyrinth_first_fragment` и отсутствии звуковых файлов. Фактически 88/711, лабиринт 14/14, 345 аудиофайлов; README приведён к текущему состоянию 2026-11-03.

## 1. Что и как проверялось

| Проверка | Команда | Результат |
|---|---|---|
| Полный GUT (второй прогон) | `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` | **88 scripts / 711 tests / 711 pass / 7 811 asserts / exit 0**, 220.7 с |
| Первый полный GUT | та же команда | exit -1 на `test_caravan_march`; изолированный `test_caravan_march` — **7/7, 31 assert, exit 0** |
| Компиляция скриптов | `godot --headless --path . -s tools/audit/qa_script_audit.gd` | **385 проверено, 0 failures** |
| Целостность ресурсов | `godot --headless --path . -s tools/audit/qa_resource_audit.gd` | **715 проверено: 211 сцен, 504 ресурса, 0 failures** |
| Headless-импорт | `godot --headless --path . --import` | **exit 0**, ошибок по ассетам нет |
| Boot main menu | `godot --headless --path . res://scenes/ui/main_menu/main_menu.tscn --quit-after 5` | exit 0 |
| Boot campaign entry | `godot --headless --path . res://scenes/campaign/campaign_entry.tscn --quit-after 5` | exit 0 |
| Пилотная локация | `test_pilgrim_path.gd` | **10/10, 260 asserts** |
| Сквозной маршрут | `test_full_route.gd` | **3/3, 220 asserts** |
| Лабиринт | `test_labyrinth_first_fragment.gd` | **14/14, 341 assert** |
| Post-nightmare | `test_post_nightmare_locations.gd` | **15/15, 516 asserts** |

Статический аудит редактора (`get_errors`) показывает **0 parse errors** и около 50 предупреждений (shadowed variables, integer division, incompatible ternary). Это не блокеры, но часть из них стоит вычистить.

## 2. Autoload и владение состоянием

Порядок в `project.godot`:

| Autoload | Роль | Замечание |
|---|---|---|
| `MCPRuntime` | runtime-мост Godot MCP | **временный; убрать/исключить из релизной сборки** |
| `NightmareRunState` | флаги, предметы, бестиарий, квесты, валюта, Памяти, чекпоинт | единый state кампании; плоские словари |
| `DialogueManager` | барки и контексты | данные — `data/dialogues/sunny_barks.json` |
| `MapSystem` | карта и fallback `MapScreen` | 16 локаций, 13 регионов |
| `PlayerMenuSystem` | единое меню `C`/`I` | инвентарь/персонаж/умения — demo data |
| `PauseMenuSystem` | пауза, настройки, выход | хранит свой `paused`/mouse |
| `CampaignGuide` | цель, журнал, бестиарий, мысли | внешняя цель QuestSystem имеет приоритет |
| `QuestSystem` | 12 квестов, событийная шина, журнал | активен только в scope `forgotten_shore` |
| `SaveSystem` | quick/checkpoint снимок | один файл `user://campaign_save.bin` |
| `AudioDirector` | музыка, эмбиент, SFX, VO, reverb | 6 шин + Reverb, data-driven cues |

Состояние не хранит ссылки на узлы, поэтому переживает `change_scene_to_file()`. Это правильное решение для демо.

Поток данных в текущей реализации: ввод → `SunnyController` / `CombatController` / `Interactor` → сигналы сцен → `QuestSystem` / `BeatDirector` / `CampaignGuide` → `NightmareRunState`; `SaveSystem` снимает `NightmareRunState` + сцену/позицию; UI читает autoload-состояние; `AudioDirector` получает cue-запросы от сцен и компонентов. Equipment-alpha в этот поток пока не включён.

## 3. Матрица систем

| Система | Статус | Что реализовано | Проверка | Главный gap |
|---|---|---|---|---|
| Кампания и переходы | **READY** | `campaign_entry`, 6 оболочек, `LevelPortal`, 26 beat-событий, гейты appraisal/finale | `test_full_route` 3/3, `test_campaign_flow` 11/11, boot exit 0 | ручной проход NOT TESTED |
| `NightmareRunState` | **READY** | флаги, предметы, бестиарий, квесты, валюта, Памяти, чекпоинт, snapshot/restore | `test_nightmare_run_state`, `test_save_system` | плоские строковые флаги; нет namespaces |
| Save/Load | **PARTIAL** | версия, magic, snapshot, позиция/поворот, восстановление сцены, F5/F9, автосейвы на чекпоинтах/квестах | `test_save_system` | один файл на все «слоты»; нет UI; equipment не сохраняется; запись не atomic |
| BeatDirector / CampaignGuide | **READY** | 26 beat-ресурсов, цели, idle-подсказки, журнал, бестиарий | `test_beat_system` 7/7, `test_campaign_guide` 9/9 | часть контента — заглушки, ручной темп NOT TESTED |
| QuestSystem | **READY / PARTIAL** | 12 `.tres` (1 main + 11 side), auto-start, prerequisites, event bus, rewards, journal, save | `test_quest_system`, `test_quest_extensions`, `test_side_quests` | SQ-02 ждёт `echo_polyp.tscn`; SQ-04 ждёт tide-lock; SQ-05 ждёт Old Shell |
| Бой | **READY / PARTIAL** | attack/block/dodge/i-frames/stamina, 4 типа врагов, weak spot ×1.5, group attack tokens, HUD | `test_combat_controller` 8/8, `test_melee_attack` 13/13, `test_carapace_enemy` 10/10, `test_mountain_king` 11/11 | hitstop только в данных; ручной бой NOT TESTED |
| Игрок и анимации | **READY / PARTIAL** | SunnyController, chain/camp tether, wounded, fall recovery, AnimationTree, combat integration | `test_sunny`, `test_sunny_animation` 16/16, `test_sunny_waking` | POC-модель и скольжение стоп не проверены вживую |
| Взаимодействие / Inspect | **READY** | Interactable, Interactor, Inspectable, QuestInspectable, guide beacon | `test_interaction`, `test_inspectable` 7/7 | ручной фокус/подсветка NOT TESTED |
| Стелс | **READY / PROTOTYPE** | ShadowZone, NoiseEventSystem, BlindTyrant, Hero vision, bell rescue | `test_act4_stealth` 12/12 | hardcoded layout; ручной проход NOT TESTED |
| UI/HUD | **READY / PARTIAL** | main menu, pause, player menu, map, HUD, vitals, subtitles, quest choice, final card | `test_main_menu`, `test_player_menu_system`, `test_vitals_hud`, `test_combat_hud` | inventory/character/aspect/memories — demo; 4K/gamepad NOT TESTED |
| Карта | **READY** | 16 map definitions, 13 regions, world/local map, live player marker | `test_map_system` 22/22, 743 asserts | ручное управление мышью NOT TESTED |
| Диалоги | **READY / PARTIAL** | 81 `.tres`-последовательности, barks, subtitles, fast mode, skip | `test_dialogue`, `test_dialogue_barks` 15/15 | barks — JSON, не typed resource; ручной flow NOT TESTED |
| Аудио | **READY / PARTIAL** | 6 шин + reverb, music layers, ambience, SFX pool, voice, captions, accessibility | `test_audio_system` 19/19, `test_audio_playback` 7/7, `test_labyrinth_audio` 6/6 | 83 voice ID без файлов; SAPI — placeholder; слуховой тест NOT TESTED |
| Equipment / Loot / Stats | **ALPHA / DEMO ONLY** | 10 equipment-скриптов, 14 loot-скриптов, 16 equipment `.tres`, 40 loot `.tres`, armor stats, encumbrance, weapon sheathing | `test_equipment_alpha` 11/11, `test_armor_stats_loot` 9/9 | не подключено к кампании и save; inventory UI — demo |
| Инвентарь UI | **DEMO ONLY** | `RpgDemoSession`, категории, поиск, экипировка, торговля, вес | `test_rpg_menu_glossary`, `test_ui_demo` | не читает `NightmareRunState`; честно помечен «ПРОТОТИП» |
| Soul Sea | **DEMO ONLY** | `SoulSeaController` в `combat_arena`, отдельный World3D-остров, HUD, beacon | `test_soul_sea_scene` | нет входа в кампании; tech demo |
| Post-nightmare | **PARTIAL** | 8 location-сцен, 7 art-overlay, 13 порталов, police/academy/Black Sea/tide descent | `test_post_nightmare_locations` 15/15 | greybox, нет NPC/квестов/сюжетных триггеров; ручной проход NOT TESTED |
| Лабиринт 18 зон | **PARTIAL / TECH DEMO** | greybox + 60 GLB art kit, tide, audio, quests, narrative, carapace encounters, 1.5 км | `test_labyrinth_first_fragment` 14/14; Z02_Crab* — 0 | не подключён к кампании/меню; часть SQ-контента отсутствует; 1.5 км вручную NOT TESTED |
| Настройки | **READY / PARTIAL** | graphics, audio, accessibility, `user://settings.cfg` v3, immediate apply | `test_game_settings` 6/6, `test_main_menu` 6/6 | переназначение клавиш не реализовано |
| Asset pipeline (pilot) | **READY / PILOT** | `placeholder_audit.py`, runtime-аудит, `build_stealth_covers.py`, Blender MCP, GLB import, collision probe | `test_pilgrim_path` 10/10, collision probe 0 failures, import exit 0 | только 3 укрытия; нет общего batch-runner для остальных локаций |
| Производительность | **PARTIAL** | PerfProbe, P5 guards, occlusion/LOD settings, MultiMesh | `test_p5_optimization`, `test_perf_probe` | полный 1080p/60 FPS прогон NOT TESTED |
| Сборка/релиз | **BLOCKED** | — | — | нет `export_presets.cfg`; `MCPRuntime` в autoload; ручной gate не пройден |

## 4. Ключевые находки

### 4.1. Два хранилища состояния (P1)

Кампания и квесты живут в `NightmareRunState`. Новый equipment-слой живёт в `InventoryComponent` и `EquipmentComponent`; его тесты прямо говорят: «не трогают кампанию и сохранения». `SaveSystem` сохраняет только `NightmareRunState.snapshot()`, поэтому:

- надетый сет/оружие/аксессуар не переживёт F5/F9;
- предметы, добавленные через `WorldLootItem` в `InventoryComponent`, не попадут в снимок;
- если `InventoryComponent` отсутствует, `WorldLootItem` падает обратно в `NightmareRunState.add_item()`, и тогда предмет сохраняется, но без слотов/экипировки.

Это записано в `DECISIONS.md` как осознанное разделение «two loot layers, on purpose», но контракт сохранения экипировки не определён. До подключения экипировки к кампании нужно выбрать: (а) единый `ActorState`/адаптер, (б) equipment остаётся demo-only, (в) `SaveSystem` получает отдельный блок `equipment`.

### 4.2. Модальность размазана по системам (P1)

`MapSystem`, `PlayerMenuSystem`, `PauseMenuSystem`, `SoulSeaController` и inventory-прототип каждый сохраняют и восстанавливают `paused`/`mouse_mode` и блокируют друг друга через группы. Сейчас это работает и покрыто тестами, но добавление ещё одного модального окна (торговля, крафт, диалоговый выбор, режим тени) увеличивает число парных исключений. В `docs/design/13_systems_architecture_audit.md` уже предложен стек `GameModes`; он пока не внедрён. Это главный архитектурный долг перед расширением UI.

### 4.3. `NightmareRunState` — глобальный словарь флагов (P1)

Флаги — плоские `StringName` (`temple_reached`, `flasks_poisoned`, `sq_fs_02_polyp_dead`), предметы — константа `ITEM_IDS`, квесты/валюта/Памяти — отдельные словари. Для одного Кошмара это нормально; для нескольких Кошмаров, реального мира и регионов нужны namespace и реестры. Пока это не блокер демо, но миграция будет дорогой.

### 4.4. Z02: вложенные плейсхолдеры — исправлено (P1, визуальный баг)

`LabyrinthArt._replace_carcass_placeholders()` обходил только прямых детей зоны и проверял `MeshInstance3D`. `Z02_Crab0/1/2` — это `Node3D`, поэтому их дочерние `Body`, `Pincer`, `Leg` оставались видимыми (33 меша). **Исправлено 2026-11-03:** добавлен рекурсивный `_hide_carcass_placeholders()`, который скрывает поддерево `Z02_Crab*`, не трогая зону `Z02_Carcass` и art-слой. Проверка: runtime-аудит — **0 мешей `Z02_Crab*`**, `test_labyrinth_first_fragment` — **14/14** (добавлен регрессионный тест `test_carcass_crab_placeholders_are_hidden`), кадр `carcass` — рёбра/череп без крабов.

### 4.5. Побочные квесты Лабиринта неполные (P1)

`LabyrinthNarrativeDirector` честно предупреждает:

- `echo_polyp.tscn` отсутствует — SQ-02 ждёт A05;
- `QuestTideLock/advance_to_low` отсутствует — SQ-04 ждёт A04;
- Old Shell scene отсутствует — SQ-05 работает через обход.

Квестовые ресурсы и fallback-логика есть, но канонический контент не закрыт. Для демо это допустимо, если не обещать полный набор SQ; для приёмки нужно либо создать сцены, либо скрыть незавершённые квесты из журнала.

### 4.6. SaveSystem: один файл на все слоты (P2)

`save_game(slot)` принимает `"quick"`, `"checkpoint"`, `"quest"`, `"finale"`, но все пишут в `DEFAULT_SAVE_PATH`. Метки слотов — только сигналы/уведомления. Автосейв на чекпоинте перезаписывает quick-save и наоборот. Для демо это приемлемо, но UI «слоты» обещать нельзя. Запись идёт напрямую, без temp+rename; при обрыве возможен частичный файл (magic/version проверяются при чтении, но атомарности нет).

### 4.7. README был устаревшим — обновлён (P1)

До аудита README говорил:

- «35 scripts / 255 tests / 2473 asserts» — фактически **88 / 711 / 7811**;
- «`test_labyrinth_first_fragment` сейчас падает» — фактически **14/14**;
- «звуковых файлов для шин Music/SFX нет» — фактически **345** аудиофайлов;
- «инвентарь — демо-заглушка» — верно для кампании, но не упоминался equipment-alpha.

README обновлён 2026-11-03: текущие числа, статус лабиринта, аудио и equipment/loot. `docs/AI_HANDOFF_AFTER_S3_2.md` остаётся историческим документом; актуальный снимок — этот отчёт. `docs/production/not_tested_inventory.md` — статический индекс, его можно перегенерировать позже.

### 4.8. Asset pipeline: пилот есть, batch-процесса нет (P2)

Пилотная замена трёх укрытий проверяет полный путь Hyper3D CLI → Blender → GLB → Godot → collision probe. Инструменты `tools/audit/placeholder_audit.py` и `runtime_placeholder_audit.gd` дают воспроизводимый реестр, `assets/environments/nightmare/source/build_stealth_covers.py` — воспроизводимую постобработку. Изолятор закрыт иначе — переиспользованием kit пролога и `tools/audit/containment_probe.gd` для коллизии, без новых GLB. Остаётся ручной пилот на три ассета: нет общего batch-runner для мелкого реквизита стоянки и оболочки лобби; для них лучше расширить существующий скрипт, а не заводить второй pipeline.

### 4.9. Debug-обход пролога (P2)

`first_nightmare_pass.gd` имеет `debug_direct_scene := true`: при прямом запуске сцены без `prologue_completed` он сам ставит этот флаг и продолжает марш. Из меню этот путь не доступен, но в релизной сборке такие debug-флаги лучше запирать через `OS.is_debug_build()` или явный аргумент. Аналогично `restart_enabled`/`transition_enabled` в тестовых сценах — это нормально для тестов, но не должно быть способом обойти сюжет в поставке.

### 4.10. Релизная гигиена (P0)

- `MCPRuntime` — autoload в `project.godot`; AGENTS.md прямо требует убрать/исключить перед релизом.
- `export_presets.cfg` отсутствует (и в `.gitignore`), поэтому release-сборка не воспроизводится из репозитория.
- Полный ручной проход S00–S15 и пост-Кошмарной цепочки не выполнялся.

## 5. Что проверено автоматически, а что нет

### Проверено

- Компиляция 385 скриптов.
- Загрузка 715 сцен/ресурсов.
- Полный GUT 711/711.
- Boot main menu и campaign entry.
- Сквозной маршрут S00–S15 логикой.
- Лабиринт 14/14 и post-nightmare 15/15.
- Пилотная замена укрытий (10/10 + collision probe).
- Импорт проекта exit 0.

### NOT TESTED

- Полный ручной проход от `campaign_entry` до финальной карточки.
- Ручной бой, стелс, падения, камера, взаимодействия.
- Живые F5/F9, загрузка в середине сцены, повреждённый сейв в реальном окне.
- Equipment save/load, интеграция экипировки в кампанию.
- Аудио на слух, разборчивость SAPI, loop seam, микс.
- 1080p/60 FPS, 4K, ultrawide, минимальное железо.
- Геймпад и переназначение клавиш.
- Непрерывный проход Лабиринта 1,5 км.
- Ручной проход пост-Кошмарной цепочки.
- Экспортная сборка.

## 6. Приоритеты

### P0 — до демонстрации/релиза

1. Убрать `MCPRuntime` из релизного autoload или исключить его export-фильтром; проверить сборку.
2. Создать `export_presets.cfg` (или задокументировать, почему его нет) и прогнать `--export-release`.
3. Пройти вручную S00–S15 и зафиксировать баги; не считать GUT заменой проходу.

### P1 — до следующего расширения

4. Определить контракт save для equipment/inventory; добавить round-trip тест.
5. ~~Исправить рекурсивное скрытие `Z02_Crab*`~~ — **исправлено 2026-11-03**. Осталось решить судьбу трёх SQ-сцен (`echo_polyp`, Old Shell, tide-lock).
6. Внедрить `GameModes`/modal stack до добавления новых модальных экранов.
7. ~~Обновить README/handoff с фактическими числами и статусами.~~ **README обновлён 2026-11-03**; handoff остаётся историческим.

### P2 — полировка

8. Атомарная запись save, слоты или честное название «один слот».
9. Hitstop, tide lethality/cycle, key rebinding.
10. Голосовые файлы для 83 ID, замена SAPI-плейсхолдеров.
11. Namespaced flags и реестры предметов/квестов.
12. Убрать 50 статических предупреждений (shadowed variables, integer division).

## 7. Короткий вердикт

**Технически демо-стержень живой:** проект импортируется, boot-сцены запускаются, 711 тестов зелёных, ключевые системы покрыты. **Релизный gate — нет:** нет экспортной сборки, MCPRuntime в релизном autoload, ручной проход и аудио не проверены. Новый equipment/loot-слой — качественный alpha, но пока живёт вне кампании и вне save; это главный интеграционный долг следующего этапа.
