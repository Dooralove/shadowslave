# Demo Sprint — BASELINE

Снимок: **2026-11-02, 20:05–20:10 +03:00**  
Составил: Chat 00 — Technical Director  
Статус: исходное состояние зафиксировано. Игровые файлы, сцены и ассеты намеренно не менялись.

> **Важно: рабочее дерево живое.** Пока снимался baseline, параллельный чат записал `scripts/quests/*`, изменения в `NightmareRunState`, материалы Лабиринта и `docs/demo_sprint/audits/quests.md` (20:03–20:05). Счётчики Git ниже — снимок на момент проверки; перед интеграцией их нужно пересчитать. Мои действия: только `--import`, запуск сцен через MCP и создание `docs/demo_sprint/`.

## 1. Git

| Параметр | Значение |
|---|---|
| Ветка | `s3-park-art` |
| HEAD | `0335a5c346901af2146413b5a159b442d326d8de` |
| Последний коммит | `2026-11-02 08:09:53 +03:00` — `feat: complete P2.5-P5 art, UI and optimization` |
| Remote | `origin` → `https://github.com/Dooralove/shadowslave.git` |
| Локальные ветки | `main`, `s2-character-poc`, `s3-park-art` |
| Staged | 0 файлов |
| Modified tracked | 78 файлов (на старте сессии было 77) |
| Untracked | 184 записи (на старте сессии было 171) |
| `git diff --stat` | 78 файлов, +1015 / −340 строк |
| `git diff --check` | exit 0, ошибок пробелов нет |
| Коммиты / push / reset / checkout / stash | **не выполнялись** |

### 1.1. Что уже лежит в рабочем дереве

Это pre-existing работа, не моя и не текущего спринта. Её нельзя удалять или перезаписывать:

- статуя Колосса: `assets/environments/nightmare/statue/*`, `source/build_statue_*`, LOD-сцены, превью, `docs/art/statue_*`;
- Soul Sea kit: 63 GLB в `assets/environments/soul_sea/kit/`, `.blend`, `ss_lib.py`, аудит и превью;
- P1 cast v2: `hero_auro_v2`, `veteran_v2`, `shifty_v2`, `mass_slave_v2`, `mass_soldier_v2`, текстуры и `.import`;
- Mountain King p2/p3, Larva corpse/LOD, Carapace Scavenger: модели, сцены, скрипты, ресурсы, тесты;
- новые документы `docs/art/*_2026-11-02.md`, `docs/art/generated_asset_manifest.md`, `docs/art/generation_queue_2026-11-02.md`;
- изменения `docs/DECISIONS.md`, `docs/ASSET_LICENSES.md`, `opencode.json`, `.gitattributes`, `.gitignore`;
- параллельная работа по quest framework: `scripts/quests/*`, правки `scripts/campaign/nightmare_run_state.gd`, `scripts/guide/campaign_guide.gd`, материалы Лабиринта, `docs/demo_sprint/audits/quests.md`.

### 1.2. Git LFS

| Параметр | Значение |
|---|---|
| Версия | `git-lfs/3.5.1` (GitHub, windows amd64) |
| Файлов в LFS | 1081 |
| `git lfs fsck --pointers` | **OK**, exit 0 |
| `git lfs status` | есть неотслеживаемые изменения LFS-объектов, ожидаемо для рабочего дерева |

Правила `.gitattributes`:

- LFS: `*.fbx`, `*.glb`, `*.gltf`, `*.blend`, `*.blend1`, `*.wav`, `*.hdr`, `*.ogg`, `*.psd`, `*.kra`, `*.xcf`, `*.tga`, `*.exr`;
- LFS для PNG/JPG в `assets/characters/p1/**`, `assets/environments/**`, `docs/art/previews/**`, `assets/ui/map/**`, `assets/characters/enemies/**`, `assets/characters/placeholders/**`;
- текстовые форматы (`.gd`, `.tscn`, `.tres`, `.json`, `.godot`, `.cfg`, `.md`) в LFS **не** добавлены — это соответствует `AGENTS.md`.

## 2. Инструменты

| Инструмент | Версия / статус | Проверка |
|---|---|---|
| Godot | **4.7.2.stable.official.ed1daf0bf** | `godot --version` |
| GUT | **9.7.1** | `addons/gut/plugin.cfg` |
| Godot MCP server | **0.6.1** | `get_godot_status` |
| Godot MCP editor | connected, live | `get_godot_status` |
| Godot MCP runtime helper | **connected** | `get_runtime_status.runtime_helper_connected = true` |
| Blender | **5.1.1** (build 2026-04-14) | `blender --version` |
| Blender MCP addon | **1.8**, protocol **15** | `get_addon_status` |
| Blender MCP server | `mcp-for-blender==2.2.6` по конфигу | `opencode.json` / `.mcp.json` |
| Blender libraries | Sketchfab **on**, Hyper3D **on**; Poly Haven / Poly Pizza off | `get_addon_status` |
| Blender generators | Tripo / Hunyuan3D / Meshy off | `get_addon_status` |

Расхождения с `AGENTS.md`:

- `AGENTS.md` говорит, что runtime helper Godot не подключается из-за parse errors. В этой сессии helper **подключился**; сцены запускаются.
- `AGENTS.md` говорит, что внешние библиотеки и генераторы моделей выключены. Фактически Sketchfab и Hyper3D включены. Это не менялось мной; зафиксировано как drift конфигурации.

## 3. Импорт проекта

```powershell
godot --headless --path . --import
```

Результат: **exit 0**. Ошибок парсинга и импорта в выводе нет. Импорт создал/обновил `.import` и `.uid` sidecar-файлы для untracked-ассетов; это ожидаемый побочный эффект, исходные ассеты не изменялись.

Кэш `.godot/` — около **1.1 ГБ**, исключён из Git.

### 3.1. Предупреждения редактора

`get_errors` показывает 9 предупреждений (не ошибок):

| Файл | Строка | Предупреждение |
|---|---:|---|
| `scripts/ui/map/map_paint.gd` | 249 | integer used when enum expected |
| `scripts/ui/map/map_canvas.gd` | 744 | local `scale` shadows `Control.scale` |
| `scripts/ui/rpg_menu/rpg_inventory_screen.gd` | 236, 254 | local `visible` shadows `CanvasItem.visible` |
| `scripts/ui/rpg_menu/rpg_inventory_screen.gd` | 499, 525 | local `name` shadows `Node.name` |
| `scripts/ui/rpg_menu/rpg_skill_graph.gd` | 188 | integer division |
| `scripts/guide/thought_bubble.gd` | 27 | parameter `text` shadows `Label3D.text` |
| `scripts/audio/sfx_pool.gd` | 73 | ternary values not mutually compatible |

Это не блокеры запуска, но QA должна отделить новые предупреждения от baseline.

## 4. Тесты

Команда:

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Фактический результат:

```text
Scripts              74
Tests               577
Passing Tests       575
Failing Tests         2
Asserts           6857/6869
Time              263.581s
EXIT=1
```

### 4.1. Падающие тесты

Оба падения — в `tests/test_post_nightmare_locations.gd`:

1. `test_each_location_scene_builds_greybox` — у `black_sea_platform` нет модулей `NeckPlatform`, `BrokenCollar`, `ShoulderWest`, `ShoulderEast`, `Chest`, `ChestStars`, `Sword`.
2. `test_black_sea_platform_matches_canonical_statue_neck` — `has_module()` false, `get_module()` возвращает `null` для `NeckPlatform` и `ChestStars`.

Причина (статически): сцена `black_sea_platform.tscn` переведена на новый hero-ассет `StatueKnightLOD`; primitive-модули старого greybox больше не строятся. Тест продолжает проверять старый контракт `GreyboxLocation.has_module()`. Это **расхождение теста и реализации**, а не падение runtime.

Следствие: baseline **красный**. Нельзя утверждать «полный GUT зелёный», пока контракт теста не согласован. Исправление — задача консолидации, не baseline.

### 4.2. Стоимость прогона

Полный GUT — около **4 минуты 24 секунды**. В 3-часовом спринте это дорого: целевые наборы обязательны, полный прогон — на контрольных точках.

## 5. Запускаемость

Проверено через Godot MCP в живом редакторе:

| Сцена | Результат |
|---|---|
| `res://scenes/ui/main_menu/main_menu.tscn` | запущена, runtime helper connected, runtime root `/root/MainMenu`, немедленных ошибок нет |
| `res://scenes/campaign/campaign_entry.tscn` | запущена, runtime helper connected, runtime root `/root/CampaignEntry`, немедленных ошибок нет |

Ограничения:

- `take_screenshot` вернул **«Viewport returned no image»** и в главном меню, и в кампании. Скриншот-доказательств в этой сессии нет.
- Полный ручной проход не выполнялся. Клик «Играть» → кампания в живом окне не проверялся.
- Проверка ограничена фактом запуска и отсутствием немедленных ошибок; это **не** подтверждение проходимости.

## 6. Структура проекта

| Показатель | Значение |
|---|---:|
| `.tscn` сцен | 113 |
| `.gd` скриптов | 195 |
| `.tres` ресурсов | 208 |
| `.glb` моделей | 320 |
| тестовых скриптов | 74 |
| файлов в `assets/` | 2277 |
| объём `assets/` | 819.3 МБ |
| файлов в LFS | 1081 |
| markdown-документов в `docs/` | 106 |
| сцен-сирот (нет ссылок) | 3 |

Сцены-сироты:

- `scenes/dev/sanctuary_approach_visual_check.tscn`;
- `scenes/dev/soul_sea_asset_preview.tscn`;
- `scenes/ui/rpg_menu/trade_offer_row.tscn` (инстанцируется кодом, не сценой).

### 6.1. Точки входа

- Главная сцена проекта: `res://scenes/ui/main_menu/main_menu.tscn`.
- Кампания: `res://scenes/campaign/campaign_entry.tscn`.
- Демо-арена: `res://scenes/main/main.tscn` (инстанцирует `test_level.tscn`).
- Sandbox: `scenes/levels/combat_arena.tscn`, `scenes/levels/ambush_site_demo.tscn`, `scenes/levels/larva_arena.tscn`.

### 6.2. Autoload

| Autoload | Файл | Роль |
|---|---|---|
| `MCPRuntime` | `addons/godot_mcp/runtime/mcp_runtime.gd` | runtime-мост MCP; временный, убрать/исключить перед релизом |
| `NightmareRunState` | `scripts/campaign/nightmare_run_state.gd` | флаги, предметы, бестиарий, квесты, валюта, Памяти, чекпоинт |
| `DialogueManager` | `scripts/systems/dialogue_manager.gd` | диалоги и субтитры |
| `MapSystem` | `scripts/map/map_system.gd` | карта по `M` |
| `PlayerMenuSystem` | `scripts/ui/player_menu_system.gd` | единое меню по `C`/`I` |
| `CampaignGuide` | `scripts/guide/campaign_guide.gd` | цель, журнал, бестиарий, мысли |
| `AudioDirector` | `scripts/audio/audio_director.gd` | шины, музыка, эмбиент, SFX, VO, reverb |

### 6.3. Маршрут Первого Кошмара

```text
main_menu
  → campaign_entry
  → first_nightmare_pass
  → caravan_site_arrival
  → pilgrim_path_arrival
  → sanctuary_arrival
  → appraisal_arrival
  → finale_arrival
  → финальная карточка / R → campaign_entry
```

Это единственный end-to-end маршрут, подключённый к меню.

### 6.4. Пост-Кошмарная цепочка

```text
police_precinct → academy_approach → academy_gate → academy_campus
→ academy_sleeper_center → black_sea_platform → tide_descent → coral_labyrinth
```

Цепочка связана порталами `LevelPortal`, но **не имеет входа** из `finale_arrival`, главного меню или кампании. Запускается только прямым открытием сцены. Это отдельный прототип, а не продолжение демо.

### 6.5. Отдельные прототипы

- `scenes/soul_sea/soul_sea.tscn` — модальное Море Души; контроллер есть только в `combat_arena.tscn`, клавиша `V`.
- `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn` — greybox Лабиринта, 18 зон; отдельная сцена, без входа из кампании.
- `scenes/levels/ambush_site_demo.tscn` — неканонический sandbox; сохранить.

## 7. Документация и расхождения

Ключевые документы:

- `README.md`, `AGENTS.md`, `docs/DECISIONS.md` (877 строк, хронологический журнал);
- `docs/AI_HANDOFF_AFTER_S3_2.md`;
- `docs/design/first_nightmare_scene_matrix.md`, `first_nightmare_route_verification.md`, `first_nightmare_gap_matrix.md`, `first_nightmare_restoration_spec.md`, `first_nightmare_prototype_flow.md`;
- `docs/design/game_menu_audit.md`, `docs/design/level_transitions.md`;
- `docs/design/11_combat_system.md`, `12_inventory_economy_and_consumables.md`, `13_systems_architecture_audit.md`;
- `docs/art/*`, `docs/audio/*`, `docs/production/*`, `docs/research/*`, `docs/story/*`.

Зафиксированные расхождения «документ ↔ факт»:

| Документ | Утверждение | Факт |
|---|---|---|
| `README.md:17` | 35 scripts / 255 tests / 2473 asserts | 74 scripts / 577 tests / 6857–6869 asserts, 2 fail |
| `docs/design/first_nightmare_route_verification.md:18-23` | 35 / 255 / 2473 | то же; документ устарел |
| `docs/design/game_menu_audit.md:154` | 70 scripts / 554 tests / 6746 asserts | устарело |
| `docs/DECISIONS.md` (P5) | 73 scripts / 572 tests / 6848 asserts | устарело |
| `docs/AI_HANDOFF_AFTER_S3_2.md:103` | основная сцена — `main.tscn` | фактически `main_menu.tscn` |
| `README.md:104` | звук не реализован, файлов Music/SFX нет | `AudioDirector`, 569 аудиофайлов, аудио-тесты |
| `AGENTS.md` (MCP) | runtime helper не подключается из-за parse errors | helper подключился, сцены запускаются |
| `AGENTS.md` (Blender) | внешние библиотеки и генераторы выключены | Sketchfab и Hyper3D включены |
| `docs/design/level_transitions.md:4` | «цепочка после Первого Кошмара подключена» | подключена только внутри себя; входа из кампании/меню нет |
| `docs/production/not_tested_inventory.md` | 150 вхождений `NOT TESTED` | `DECISIONS.md` говорит о 142; индекс не пересчитан после новых документов |
| `README.md:102` | полный ручной проход не выполнялся | всё ещё верно |

Вывод: **документы — источник замысла, но не доказательство реализации.** Все отчёты десяти чатов должны проверять код и сцены, а не пересказывать документы.

## 8. Известные ограничения baseline

1. **Полный GUT красный:** 2 падения в `test_post_nightmare_locations` из-за старого контракта `black_sea_platform`.
2. **Нет ручного прохождения:** ни одного непрерывного сеанса от меню до финальной карточки.
3. **Нет скриншотов в этой сессии:** `take_screenshot` не работает; для доказательств использовать `tools/audit/*.gd` или отдельный запуск.
4. **Пост-Кошмарная цепочка недоступна из игры:** только прямой запуск сцены.
5. **Лабиринт — greybox без контента:** 18 зон, маркеры, прилив-прототип; нет NPC, врагов, предметов, карты, шторма.
6. **Море Души доступно только в `combat_arena`:** в кампании нет контроллера/точки входа.
7. **Демо-данные:** инвентарь, торговля, персонаж, аспект, Памяти — `RpgDemoSession`/заглушки, не канонический инвентарь.
8. **Ассеты:** 819 МБ, 320 GLB, 1081 LFS-файл; импорт и полный тест дорогие.
9. **Параллельная работа:** дерево меняется другими чатами; перед интеграцией обязателен пересчёт `git status` и проверка `ACTIVE_CLAIMS.md`.
10. **MCPRuntime — временный autoload:** перед релизной сборкой убрать или исключить.

## 9. Что не делалось

- Не менялись игровые сцены, скрипты, ресурсы, модели, материалы и текстуры.
- Не выполнялись коммиты, push, checkout, reset, stash, очистка дерева.
- Не удалялись и не перезаписывались чужие изменения.
- Не запускался полный ручной проход.
- Не проверялись звук на слух, геймпад, 4K/ultrawide, минимальное железо.
- Не проверялся свежий клон проекта с нуля.

## 10. Следующий шаг

1. Принять десять отчётов в `docs/demo_sprint/audits/`.
2. Свести их в `design/00_DEMO_SCOPE_AND_CONTRACT.md` и `design/01_INTEGRATION_PLAN.md`.
3. Зафиксировать P0-список и владельцев файлов в `implementation/ACTIVE_CLAIMS.md`.
4. Только после этого начинать изменения кода.

## 11. Drift после снимка (20:10–20:25)

Рабочее дерево изменилось параллельными чатами уже после baseline. Это не мои правки; фиксирую, чтобы не потерять:

| Время | Изменение | Влияние |
|---|---|---|
| 20:11–20:14 | `labyrinth_first_fragment.gd`, `labyrinth_art.gd`, `labyrinth_greybox.gd`, `labyrinth_quest_director.gd` | Лабиринт получил игровой слой и арт-интеграцию |
| 20:13–20:15 | `scripts/quests/*`, `resources/quests/*`, `QuestSystem` | квестовый слой появился, но в S00–S15 не входит |
| 20:15 | `project.godot`: добавлены autoload `PauseMenuSystem`, `QuestSystem`; добавлен `[display]` 1920×1080 / 1600×900 / canvas_items | новые системы активны глобально |
| 20:15 | `project.godot`: **удалён блок `[rendering]`** с `import_s3tc_bptc`, `use_occlusion_culling`, `mesh_lod threshold_pixels=1.5` | **регрессия P5**: оптимизации больше не включены |
| 20:15 | `scenes/ui/pause_menu/pause_menu.tscn`, `scripts/ui/pause_menu_system.gd` | новое pause-меню |
| 20:18–20:19 | `docs/demo_sprint/audits/01_narrative_story.md`, `narrative.md`, `quests.md` | два отчёта получены |

**Вывод:** baseline — это снимок, а не замороженное состояние. Перед интеграцией обязательно пересчитать `git status`, проверить `project.godot` и восстановить `[rendering]` (P0).
