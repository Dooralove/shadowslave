# Side Quest Design — аудит

**Дата:** 2026-11-03
**Автор:** Chat 02 — Lead Side Quest Designer. Narrative review — по документам Chat 01, см. `design/side_quests.md` §19.
**HEAD:** `ee97325` (worktree `shadowslave-demo-02`, branch `demo/quests`)
**Ожидаемый путь:** `docs/demo_sprint/audits/02_side_quest_design.md`; текущий `quests.md` принят как эквивалент по `EXPECTED_REPORTS.md` §5.
**Статус:** Stage 6 — данные SQ и runtime-директор реализованы; после глубокого аудита закрыты early-kill/early-loot, save/restore и scope edge cases. Полный M3 runtime всё ещё заблокирован A01/A03/A04/A05/A08; ручной проход — **NOT TESTED**.

---

## 0. Сводка

1. **Текущий scope — не «tech demo» и не S00–S15.** `00_DEMO_SCOPE_AND_CONTRACT.md` (ревизия 2) и `P0_BOARD.md` определяют M1 (пост-Кошмарный срез до входа в Лабиринт) и M3 (полный первый фрагмент Лабиринта, 60–90 мин). Пять SQ-FS относятся к **M3**, а не к M1 и не к Первому Кошмару.
2. **Quest Framework уже существует.** `QuestSystem` — autoload, в `resources/quests/` лежат **7** `QuestDefinition`, есть `QuestCatalog`, `QuestObjective` (7 типов), `QuestReward`, журнал, tracking, внешняя цель, валюта, Памяти, `SaveSystem` и snapshot.
3. **Игровой слой Лабиринта существует.** `LabyrinthQuestDirector` собирает триггеры, чекпоинты, подборы, NPC, врагов; `GameplayHud` показывает цель, субтитры, тост и прилив; `QuestToast` реагирует на старт/финал/награду; `LabyrinthAtmosphere` уже слушает квестовые сигналы.
4. **7 существующих заданий — каркас и обучение, а не полноценные истории.** `first_day` — основная цепочка; остальные — kill/collect/reach/rest. В них нет расследования, выбора, загадки, пропавшего NPC и альтернативных исходов.
5. **Фактические тесты 2026-11-03:** `test_quest_system` — **9/9, 63 assert, PASS**; `test_labyrinth_quest_content` — **4/4, 41 assert, PASS**; `test_labyrinth_first_fragment` — **13/13, 332 assert, PASS** после полного импорта.
6. **Реальные пробелы:** нет `start_quest_id` у `QuestPickup`/`QuestNpc`/`QuestTriggerZone`; нет `QuestInspectable`; нет `QuestChoicePanel`; нет `QuestTideLock`; нет `advance_to_low`; weak-spot `Hurtbox` не умеет >1.0; `MapScreen` передаёт `{}` вместо флагов; `MapMarker.hide_when_flag` и карта Лабиринта уже есть.
7. **Устаревшие утверждения прошлого аудита исправлены:** файловое сохранение уже есть (`SaveSystem`), карта Лабиринта уже есть, `hide_when_flag` уже есть, `test_labyrinth_quest_content` — 4/4 после фикса VFX, structure-тест — 13/13 после полного импорта.
8. **Рекомендация:** не строить второй framework. Добавлять 5 SQ-FS как `QuestDefinition` в существующий каталог. M3-P0 — цепочка SQ-01…03; M3-P1 — SQ-05; M3-P2 — SQ-04. S00–S15 не трогать.

---

## 1. Метод и границы

### 1.1. Прочитано

- `docs/demo_sprint/README.md`, `BASELINE.md`, `EXPECTED_REPORTS.md`, `OWNERSHIP.md`, `design/00_DEMO_SCOPE_AND_CONTRACT.md`.
- `docs/demo_sprint/audits/01_narrative_story.md`, `narrative.md`.
- `docs/demo_sprint/design/narrative_design.md`.
- `docs/design/first_nightmare_*`, `docs/story/first_nightmare_canonical_timeline.md`.
- `docs/design/forgotten_shore_labyrinth_research.md`, `level_brief_labyrinth_first_fragment.md`, `labyrinth_first_fragment_implementation.md`, `docs/level_design/forgotten_shore_labyrinth_handoff.md`.
- `docs/research/post_first_nightmare_dream_realm/01_canonical_timeline.md`, `02_character_dossiers.md`, `03_locations_and_world.md`, `04_creatures_items_and_abilities.md`, `05_scenes_and_dialogue_beats.md`, `07_gameplay_adaptation.md`.
- `docs/design/12_inventory_economy_and_consumables.md`, `docs/design/13_systems_architecture_audit.md`.
- `docs/audio/AUDIO_IMPLEMENTATION_AUDIT.md`, `docs/production/not_tested_inventory.md`.

### 1.2. Проверено в коде

- `project.godot` (autoload `QuestSystem`, `NightmareRunState`, `CampaignGuide`).
- `scripts/quests/*` — `quest_system.gd`, `quest_definition.gd`, `quest_objective.gd`, `quest_reward.gd`, `quest_catalog.gd`, `quest_journal_*`, `quest_npc.gd`, `quest_pickup.gd`, `quest_kill_credit.gd`, `quest_trigger_zone.gd`, `checkpoint_zone.gd`.
- `resources/quests/*` — 7 `.tres` + каталог.
- `scripts/locations/forgotten_shore_labyrinth/labyrinth_quest_director.gd`.
- `scripts/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.gd`, `tide_controller.gd`.
- `scripts/campaign/nightmare_run_state.gd` — quests, currency, memories, snapshot.
- `scripts/guide/campaign_guide.gd` — external objective.
- `scripts/ui/gameplay_hud.gd`, `scripts/ui/quest_toast.gd`, `scripts/ui/rpg_menu/rpg_quest_screen.gd`.
- `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn` — `Gameplay/QuestDirector`, `GameplayHud`.
- `tests/test_quest_system.gd`, `tests/test_labyrinth_quest_content.gd`, `tests/test_labyrinth_first_fragment.gd`.

### 1.3. Запущено

| Проверка | Команда | Результат |
|---|---|---|
| Импорт | `godot --headless --path . --import` | **EXIT=0** |
| QuestSystem | `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_quest_system.gd -gexit` | **9/9 passed**, 63 asserts |
| Labyrinth quest content | `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_labyrinth_quest_content.gd -gexit` | **4/4**, 41 asserts, PASS |
| Labyrinth structure | `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_labyrinth_first_fragment.gd -gexit` | **13/13**, 332 asserts, PASS |

**Важно:** тесты запускались после `--import`; дерево живое, параллельные чаты меняют `LabyrinthAtmosphere` и VFX. Результаты — снимок, не вечная истина.

### 1.4. Не проверялось

- Полный GUT всего дерева.
- Ручной проход S00–S15.
- Ручной проход M1 и M3.
- Runtime SQ-01…05 (не реализованы).
- Визуал, звук, VO, субтитры, доступность.
- Баланс боя и экономика.

Всё перечисленное — **NOT TESTED**.

---

## 2. Фактическое состояние

### 2.1. Framework

| Элемент | Файл / строка | Что реально есть | Ограничение |
|---|---|---|---|
| Autoload | `project.godot:26` | `QuestSystem="*res://scripts/quests/quest_system.gd"` | Зарегистрирован; в S00–S15 не активируется |
| `QuestSystem` | `scripts/quests/quest_system.gd` | `activate_scope`/`deactivate_scope`, `start_quest`, `complete_quest(force)`, `notify_event`, `set_tracked_quest`, `get_journal_entries`, `get_tracked_objective_text`, signals | Нет OR/choice-целей, нет failure/abandon; маркеры карты есть, но `MapScreen` не передаёт флаги |
| `QuestDefinition` | `quest_definition.gd` | id, scope, code, title, category MAIN/SIDE, summary, description, prerequisites, required_quests, auto_start, show_available, objectives, rewards, completion_flag | Нет стадий как отдельной сущности; objectives плоские |
| `QuestObjective` | `quest_objective.gd` | KILL, COLLECT, INTERACT, REACH, TALK, FLAG, CURRENCY; count, optional, hidden_until_previous | `QuestSystem` не проверяет `hidden_until_previous` при выдаче журнала |
| `QuestReward` | `quest_reward.gd` | item, currency, memory, flag, heal, text | Нет bestiary/map reward; условия не поддерживаются |
| `QuestCatalog` | `quest_catalog.gd`, `resources/quests/quest_catalog.tres` | 7 заданий, scope `forgotten_shore` | `test_quest_system` жёстко ждёт 7 |
| Журнал | `quest_journal_entry.gd`, `quest_journal_objective.gd` | Снимки для `RpgQuestScreen`, статусы 0/1/2, tracking | Нет отдельного поля «последствие»/«выбор» |
| `NightmareRunState` | `nightmare_run_state.gd:13–16, 38–45, 137–302, 388–466` | quests, objectives, reward_claimed, currency, memories, tracked_quest, flags, snapshot/restore | Семантика «Первого Кошмара» для пост-Кошмара; файл — через `SaveSystem` |
| `SaveSystem` | `scripts/systems/save_system.gd` | `user://campaign_save.bin`, F5/F9, сцена/позиция/`NightmareRunState` | Один слот, без списка/подтверждения |
| `LabyrinthAtmosphere` | `scripts/audio/labyrinth_atmosphere.gd` | слушает `quest_started`/`quest_objective_completed`/`quest_completed`; `ui_quest_update`/`ui_skill_unlock` | Parse error исправлен; нужен runtime-тест |
| Карта | `resources/map/locations/labyrinth_first_fragment.tres`, `MapMarker`, `RpgMapScreen` | 17 маркеров, `show_when_flag`/`hide_when_flag`, live-маркер | `MapScreen._build_marker_list` передаёт `{}` вместо флагов |
| `LabyrinthQuestDirector` | `scripts/locations/.../labyrinth_quest_director.gd` | triggers, checkpoints, pickups, NPCs, encounters; `Gameplay/Runtime` | Жёстко привязан к маркерам сцены; один владелец |
| `QuestNpc` | `scripts/quests/quest_npc.gd` | Interactable + DialogueRunner; required flags; one_shot; talk event | Линейный диалог; нет выбора |
| `QuestPickup` | `scripts/quests/quest_pickup.gd` | item/currency/memory; pickup flag; event; visual shard/blade/token | Нет tide-lock/condition; визуалы ограничены |
| `QuestKillCredit` | `scripts/quests/quest_kill_credit.gd` | Health.died → `killed` event + credit flag | Нет элитных/частей тела |
| `QuestTriggerZone` | `scripts/quests/quest_trigger_zone.gd` | required flags; `reached` event; set flag | Одноразовый в памяти сцены; флаг — единственная персистентность |
| `CheckpointZone` | `scripts/quests/checkpoint_zone.gd` | чекпоинт + heal/stamina | Не квестовый объект |
| UI | `gameplay_hud.gd`, `quest_toast.gd`, `rpg_quest_screen.gd` | цель, субтитры, тост, журнал, прилив; `RpgQuestScreen` уже приоритизирует live QuestSystem, имеет кнопку tracking и campaign fallback | Header комментарий устарел; нет поля «последствие»; choice UI отсутствует |
| Внешняя цель | `campaign_guide.gd:124–157` | `set_external_objective` подменяет `display_objective`; `base_objective` сохраняется | В S00–S15 нельзя активировать scope, иначе строка beat-цели будет перекрыта |

### 2.2. Семь существующих заданий

| ID | Категория | Цели | Награда | Чего не хватает |
|---|---|---|---|---|
| `first_day` | MAIN | REACH `first_fork`, TALK `nephis`, REACH `camp` | 5 `soul_shard`, heal 20 | Это каркас, не побочная история |
| `first_blood` | SIDE | KILL `wounded_scavenger` | 2 `soul_shard` | Один бой, нет выбора |
| `azure_blade` | SIDE | INTERACT `azure_blade` | 1 `soul_shard`, Memory `azure_blade` | Хороший пример Memory-награды |
| `crystal_cache` | SIDE | COLLECT `soul_shard` ×3 | 3 `soul_shard` | Простой сбор |
| `hunt_pack` | SIDE | KILL `carapace` ×3 | 6 `soul_shard` | Простой бой |
| `camp_rest` | SIDE | INTERACT `campfire` | флаг `camp_rested`, heal 100 | Отдых |
| `bridge_stand` | SIDE | KILL `bridge_carapace` ×2 | 4 `soul_shard` | Бой на мосту |

**Вывод:** это **функциональный каркас и обучение**, а не 7 полноценных побочных историй. Для цели «3–5 полноценных заданий» нужен новый нарративный слой, а не замена framework.

### 2.3. Чего нет

| Пробел | Следствие |
|---|---|
| OR/choice objectives | SQ-03 нельзя выразить одним `QuestObjective`; нужен `complete_quest(force)` или маленький choice-узел |
| `Inspectable` не шлёт квестовых событий | `completed_flag` только читается; улика/след не закрывает `INTERACT`-цель без `QuestInspectable`/`QuestPickup` |
| Нет хука `start_quest` у `auto_start=false` | `QuestTriggerZone`/`QuestPickup`/`QuestNpc` не вызывают `QuestSystem.start_quest`; SQ-01…05 не стартуют |
| `QuestPickup` default `collected`/`interaction_id` | Для `INTERACT`-целей нужно явно `interacted` + `target_id`, иначе цель не закроется |
| Квестовые маркеры на карте | `MapMarker.quest_id` и карта Лабиринта есть; `MapScreen` передаёт `{}` вместо флагов |
| `hide_when_flag` | **Уже есть**; проверить на 5 квестовых маркерах |
| Уникальные NPC | `QuestNpc` использует `Mannequin` (`mass_male`/`mass_female`); Тео будет манекеном |
| Bestiary/map reward | `QuestReward` не умеет; нужен флаг + `CampaignGuide.unlock_bestiary`/map |
| Failure/abandon | Есть только active/completed; «уход Тео» — это флаг, не fail |
| Файловое сохранение | **Уже есть** (`SaveSystem`); один слот, без списка |
| Звук квестов | `LabyrinthAtmosphere` уже слушает сигналы; parse error исправлен |
| Тест на 12 заданий | `test_quest_system` ждёт 7; добавление 5 ломает тест |
| Стабильный структурный тест | `test_labyrinth_first_fragment` 13/13 PASS после полного импорта |

---

## 3. Расхождения «документ ↔ реализация»

| Документ | Утверждение | Факт | Риск |
|---|---|---|---|
| `audits/01_narrative_story.md:20,67` | `QuestSystem` не autoload | `project.godot:26` — autoload; `QuestSystem` загружается | TD может считать слой нерабочим и отложить уже готовую базу |
| `RpgQuestScreen` header | «DEMO only, не связан с квестами» | Экран приоритизирует live `QuestSystem`, имеет кнопку tracking и campaign fallback; demo — только fallback | UI-владелец может не заметить живую интеграцию и делать лишнее |
| `00_DEMO_SCOPE_AND_CONTRACT.md` (ревизия 2) | M3 includes 18 zones + 5 side quests | Framework уже есть; M3 — контентный этап, не архитектура | Путаница «строить/не строить»; правильнее «не ломать/не расширять без нужды» |
| `EXPECTED_REPORTS.md` §3 | 02 не должен создавать Quest Framework без согласования | Framework уже создан; отчёт должен расширять его, а не дублировать | Дублирование `QuestLog`/`SideQuestDefinition` |
| `test_quest_system.gd:26` | В каталоге 7 заданий | При добавлении 5 будет 12 | Тест упадёт; нужен `>=7` или `12` |
| `test_labyrinth_first_fragment.gd` | 13/13 — ожидаемый зелёный | Факт 13/13 PASS после полного импорта | M3 baseline зелёный |
| `README.md:17` | 35 scripts / 255 tests | Baseline 74 / 577; текущее дерево грязное | Устаревший статус, не использовать как доказательство |
| `campaign_guide.gd` external objective | «Не перезаписывает main objective» | `base_objective` сохраняется, но `display_objective` подменяется | В S00–S15 нельзя активировать `forgotten_shore` scope |
| `labyrinth_first_fragment.tscn` | Есть `Gameplay/QuestDirector` и `GameplayHud` | Да, оба в сцене | M3-сцена уже собрана; не пересобирать с нуля |
| `01_CONTENT_MATRIX.md` | SQ-04 в Z15 | `world_layout.md`/`poi_manifest.md` — Z11 | Использовать Z11; матрицу синхронизировать |

---

## 4. Готовность к M3

| Область | Готовность | Что нужно |
|---|---:|---|
| S00–S15 | **Не зависит от побочек** | Не активировать `QuestSystem` scope в кампании |
| M1 | **Не зависит от побочек** | Не добавлять SQ-FS в короткий срез |
| Quest Framework | **75%** | `start_quest_id`, `QuestInspectable`, `QuestChoicePanel`, `QuestTideLock`, `advance_to_low` |
| Контент существующих 7 заданий | **40%** | Каркас есть; истории нет |
| Нарративные SQ-FS | **0%** | 5 SQ из `docs/demo_sprint/design/side_quests.md` |
| Журнал/tracking | **90%** | Живой, с кнопкой tracking; добавить «последствие»/цепочку |
| Состояние/сохранение | **80%** | `SaveSystem` есть; один слот, без списка |
| UI HUD/тост | **80%** | Тост/трекер есть; choice UI нет |
| NPC | **25%** | Манекены; Тео — placeholder |
| Карта | **70%** | Карта и `hide_when_flag` есть; 5 маркеров и `MapScreen` flags-баг |
| Аудио/VFX | **50%** | Hooks есть; parse error; VO/VFX квестов нет |
| Тесты | **80%** | Quest 9/9; content 4/4; structure 13/13 |

**Вывод:** M3 можно довести точечными расширениями. Полный новый framework не нужен и опасен.

---

## 5. P0 / P1 / P2

### P0 — без этого M3 нельзя считать рабочим

1. **Изоляция scope.** `QuestSystem.activate_scope` вызывается только `LabyrinthQuestDirector`; в S00–S15 scope должен оставаться `&""`. Если M1 загружает финальную сцену Лабиринта, `enable_gameplay=false`, иначе 7 квестов автостартуют и перекроют M1-цель.
2. **Стабилизировать дерево.** Полный импорт и baseline 13/13 уже пройдены; осталось закрыть G2–G5.
3. **Не ломать `test_quest_system`.** При добавлении заданий обновить ожидание `7` → `12` (или `>=7`) и прогнать 9/9.
4. **Квестовые хуки.** `start_quest_id` в `QuestPickup`/`QuestNpc`/`QuestTriggerZone`, `QuestInspectable`, `QuestChoicePanel`, `QuestTideLock`, Theo return proxy.
5. **Не строить второй framework.** Использовать `QuestSystem`, `QuestDefinition`, `QuestObjective`, `QuestReward`, `NightmareRunState`, `SaveSystem`.

### P1 — заметно улучшает M3

6. **SQ-01…03** как `QuestDefinition` в существующем каталоге; Тео — `QuestNpc` с манекеном; choice-узел для SQ-03.
7. **Квестовые маркеры** на существующей карте; исправить `MapScreen` flags.
8. **Bestiary/map reward** через флаги и `CampaignGuide.unlock_bestiary`.
9. **Звук** `ui_quest_update` через `LabyrinthAtmosphere`; проверить после полного импорта и сборки SQ-сцены.
10. **Тесты** на новые квесты: старт, цели, награда, snapshot, choice.

### P2 — после M3

11. SQ-04/05, если не входят в M3-P1/P2.
12. Уникальные модели Тео/полипа/альфы.
13. VO, локализация, accessibility.
14. Полные сохранения (слоты, список, миграции).
15. Полный GUT и ручной проход.

---

## 6. Владение файлами

| Путь | Владелец | Что можно |
|---|---|---|
| `docs/design/side_quest*`, `docs/demo_sprint/design/side_quest*` | **02** | дизайн, тексты, координаты-предложения |
| `scripts/quests/**`, `resources/quests/**` | **02** (совместно с 04) | новые `QuestDefinition`, обёртки, данные |
| `scripts/locations/forgotten_shore_labyrinth/labyrinth_quest_director.gd` | **02/04** | добавление контента через хук; не переписывать маршруты |
| `scripts/locations/forgotten_shore_labyrinth/narrative_quest_director.gd` (новый) | **02/04** | только новые SQ_FS_01…05; не трогать `Runtime` |
| `scripts/campaign/nightmare_run_state.gd` | **04 / TD** | общие поля состояния; только через claim |
| `scripts/guide/campaign_guide.gd` | **04 / TD** | external objective; не менять без 04 |
| `scripts/ui/rpg_menu/rpg_quest_screen.gd` | **08** | живой журнал, последствия/цепочка, устаревший header |
| `scenes/locations/forgotten_shore_labyrinth/*` | **03** | координаты, коллизии, маркеры, сцена |
| `assets/characters/**` | **06** | Тео/полип/альфа; не генерировать без решения |
| `tests/test_quest_system.gd` | **10 / 02** | ожидаемое число, новые тесты |

**Общие файлы (`project.godot`, `NightmareRunState`, `CampaignGuide`, `RpgQuestScreen`) — только через TD/соответствующего владельца.**

---

## 7. Риски интеграции

| Риск | Вероятность | Влияние | Смягчение |
|---|---|---|---|
| Scope активируется в S00–S15 | Средняя | Внешняя цель перекроет beat-цель | Держать активацию только в `LabyrinthQuestDirector`; тест на `active_scope == &""` в кампании |
| `test_quest_system` ломается от новых заданий | Высокая | Красный GUT | Обновить expected count; тест на 12 |
| `test_labyrinth_first_fragment` сломается от SQ | Средняя | M3 нельзя принять | Baseline 13/13 PASS; новый контент — только в `NarrativeQuestDirector` |
| Нет уникального Тео | Высокая | Сцена выглядит манекеном | Placeholder `mass_male`; уникальная модель P2 |
| Карта Лабиринта | Низкая | Маркеры не видны | Карта и `hide_when_flag` уже есть; 5 маркеров + `MapScreen` flags |
| Один слот сохранения | Средняя | Нет списка/подтверждения | `SaveSystem` уже есть; P2 расширение |
| Нет choice-цели | Средняя | SQ-03 требует обход | Маленький choice-узел + `complete_quest(force)` |
| Конфликт с 04/08 | Средняя | Правки общих файлов | Claims + TD |
| Канон новых NPC | Средняя | Противоречие S00–S15 | Только M3; не вставлять в S00–S15 |

---

## 8. Проверки

### 8.1. Фактические результаты

```text
godot --headless --path . --import
EXIT=0

test_quest_system.gd
9/9 passed, 63 asserts, all passed

test_labyrinth_quest_content.gd
4/4 passed, 41 asserts, all passed

test_labyrinth_first_fragment.gd
13/13 passed, 332 asserts, all passed
```

### 8.2. Что это значит

- **QuestSystem, каталог, цели, награды, snapshot** — 9/9, зелёные.
- **Базовая цепочка Лабиринта** — 4/4, зелёная.
- **Сцена Лабиринта** — 13/13, зелёная после полного импорта.
- **S00–S15** в этой сессии не прогонялся; последний baseline — 74 скрипта / 577 тестов / 2 fail (`test_post_nightmare_locations`). Полный ручной проход — **NOT TESTED**.

### 8.3. NOT TESTED

- Ручной проход M1, M3 и S00–S15.
- Изоляция scope в S00–S15 (`QuestSystem.active_scope == &""`) — статически проверено, тестом не подтверждено.
- Визуал, свет, читаемость.
- Звук, VO, субтитры.
- Доступность.
- Полный GUT после добавления контента.
- Runtime SQ-01…05 (не реализованы).

---

## 9. Ссылки

- `docs/demo_sprint/design/side_quests.md` — Quest Design Document для 5 нарративных заданий M3.
- `docs/demo_sprint/design/00_DEMO_SCOPE_AND_CONTRACT.md` — границы демо.
- `docs/demo_sprint/audits/01_narrative_story.md` — нарративный аудит (учесть расхождение про autoload).
- `docs/demo_sprint/BASELINE.md` — baseline и таймлайн параллельных правок.
- `docs/design/forgotten_shore_labyrinth_research.md` — канон Лабиринта.
- `docs/design/level_brief_labyrinth_first_fragment.md` — пространство.
- `docs/level_design/forgotten_shore_labyrinth_handoff.md` — as-built.
- `scripts/quests/*`, `resources/quests/*` — framework и 7 заданий.
- `tests/test_quest_system.gd`, `tests/test_labyrinth_quest_content.gd` — фактические проверки.

**Статус:** аудит статический + целевые GUT; игровые файлы не менялись; всё непроверенное — **NOT TESTED**.

---

## 10. Stage 3 implementation — A02

### 10.0. Матрица задач

| Task | Priority | Статус | Результат |
|---|---|---|---|
| A02-01 SQ-01 `.tres` | P0 | **DONE (data)** | code 08, 3 objectives, `sq_fs_01_complete`; runtime ждёт A03/A04 |
| A02-02 SQ-02 `.tres` | P0 | **DONE (data)** | code 09, 6 objectives; runtime ждёт A04/A05 |
| A02-03 SQ-03 `.tres` | P0 | **DONE (data)** | code 10, 4 objectives; runtime ждёт A01/A04/A08 |
| A02-04 SQ-04 `.tres` | P2 | **DONE (data)** | code 11, 5 objectives + 2 shards; runtime ждёт A04 |
| A02-05 SQ-05 `.tres` | P1 | **DONE (data + bypass runtime)** | code 12, 7 objectives; bypass/marks работают после A03-маркеров; kill/tide + 2/3 shards ждут A04/A05 |
| A02-06 narrative director | P0 | **DONE (partial runtime)** | SQ-01…03 + SQ-05 bypass build; 22 objects on full 25 markers без A01/A05; dependency warnings |
| A02-07 reachability | P1 | **PARTIAL / TESTED** | POI/M1 table §10.6; `test_side_quests` covers data/flow, route test остаётся A10 |
| A02-08 SQ not in M1 | P0 | **DONE (static)** | catalog 7, scene has no SQ director; M1 unaffected |

### 10.1. Созданные файлы

| Файл | Статус | Назначение |
|---|---|---|
| `resources/quests/sq_fs_01_ninth_token.tres` | создан | SQ-01, code 08, 3 objectives |
| `resources/quests/sq_fs_02_echo_tunnel.tres` | создан | SQ-02, code 09, 6 objectives |
| `resources/quests/sq_fs_03_truth_without_lies.tres` | создан | SQ-03, code 10, 4 objectives |
| `resources/quests/sq_fs_04_salt_box.tres` | создан | SQ-04, code 11, 5 objectives + 2 soul_shard |
| `resources/quests/sq_fs_05_bone_bridge_master.tres` | создан | SQ-05, code 12, 7 objectives; `rewards=[]`; 2/3 shards — world pickups |
| `scripts/locations/forgotten_shore_labyrinth/labyrinth_narrative_director.gd` | создан | runtime SQ-01…03 + SQ-05 bypass |
| `tests/test_side_quests.gd` | создан (A10 review) | regression: data, event-flow, director build |

Все пять ресурсов прошли `QuestDefinition.is_valid()` в runtime-пробе: **5/5 PASS**.

### 10.2. Каталог — требует A04

`resources/quests/quest_catalog.tres` не менялся (A04). Нужно добавить 5 `ext_resource` и entries:

```text
[ext_resource type="Resource" path="res://resources/quests/sq_fs_01_ninth_token.tres" id="9_sq_fs_01"]
[ext_resource type="Resource" path="res://resources/quests/sq_fs_02_echo_tunnel.tres" id="10_sq_fs_02"]
[ext_resource type="Resource" path="res://resources/quests/sq_fs_03_truth_without_lies.tres" id="11_sq_fs_03"]
[ext_resource type="Resource" path="res://resources/quests/sq_fs_04_salt_box.tres" id="12_sq_fs_04"]
[ext_resource type="Resource" path="res://resources/quests/sq_fs_05_bone_bridge_master.tres" id="13_sq_fs_05"]
```

Добавить `ExtResource("9_sq_fs_01")`…`ExtResource("13_sq_fs_05")` в `quests`; `load_steps` увеличить с 9 до 14. `test_quest_system.gd` expected count — с 7 до 12. Без этого `QuestSystem.start_quest()` не найдёт SQ, и runtime-директор не сможет их запустить, даже если маркеры уже стоят.

### 10.3. Контракт маркеров — требует A03

`LabyrinthNarrativeDirector` ищет `Marker3D` под `Gameplay/Quests` (fallback: `Gameplay/Narrative`). Ожидаемые пути:

```text
SQ_FS_01/Token
SQ_FS_01/Traces/Heel
SQ_FS_01/Traces/Shell
SQ_FS_01/Traces/Blood
SQ_FS_01/Theo
SQ_FS_02/Tunnel
SQ_FS_02/EchoA
SQ_FS_02/EchoB
SQ_FS_02/EchoC
SQ_FS_02/Polyp
SQ_FS_02/Cloak
SQ_FS_02/Core
SQ_FS_03/TheoReturn
SQ_FS_03/Cord
SQ_FS_03/Cache
SQ_FS_03/Token
SQ_FS_05/Bridge
SQ_FS_05/Trail
SQ_FS_05/Lair
SQ_FS_05/Carcass
SQ_FS_05/Bait
SQ_FS_05/Alpha
SQ_FS_05/WestEnd
SQ_FS_05/Reward
SQ_FS_05/TideBonus
```

Координаты — из `poi_manifest.md`; директор их не дублирует. Узел `Gameplay/NarrativeQuestDirector` должен стоять после `Gameplay/QuestDirector`, чтобы scope уже был активирован; директор сам scope не активирует.

### 10.4. Зависимости и блокеры

| Зависимость | Что нужно | Владелец | Текущий статус |
|---|---|---|---|
| Диалоги SQ | `resources/dialogue/labyrinth/sq_fs_01_theo.tres`, `sq_fs_03_theo.tres` | A01 | **MISSING**; NPC не создаются без них |
| Speaker names | `&"theo": "Тео"`, `&"theo_return": "Тео"`, `&"lissa_echo": "Голос Лиссы"` в `DialogueRunner` | A01/A04 | **PENDING** |
| `QuestInspectable` | `scripts/inspect/quest_inspectable.gd`; улики/следы | A04 | **MISSING**; директор проверяет оба пути, fallback — `QuestPickup` |
| `QuestChoicePanel` | выбор SQ-03 | A04/A08 | **MISSING**; `sq_fs_03_resolved` не выставляется |
| `QuestTideLock`, `advance_to_low/high` | SQ-04 | A04 | **MISSING**; P2 runtime выключен |
| `echo_polyp.tscn` | SQ-02 | A05 | **MISSING**; kill-цель не закрывается |
| `Old Shell` | SQ-05 | A05 | **MISSING**; bypass-путь работает, kill/tide ждут A05 |
| SQ-маркеры | 25 точек | A03 | **MISSING** |
| Каталог | 5 entries | A04 | **MISSING** |

### 10.5. Проверки Stage 3

| Проверка | Результат |
|---|---|
| `QuestDefinition.is_valid()` для 5 SQ | **5/5 PASS** |
| Quest flow с временным каталогом | **5/5 PASS**: SQ-01…05 стартуют и завершаются по событиям; SQ-04 выдаёт 2 `soul_shard`; SQ-05 bypass — 0 |
| Runtime-сборка директора с тестовыми маркерами | **PASS**, 22 объекта на полном наборе 25 маркеров; warnings только по отсутствующим A01/A04/A05 |
| SQ-05 bypass probe | **PASS**: 9 объектов; bridge/trail trigger, marks/lair, chum/bait, WestEnd, reward, tide bonus |
| SQ-05 bypass flow | **PASS**: bridge → WestEnd → `alpha_spared` + `resolved` + `sq_fs_05_complete`, 0 shards (by design) |
| `test_side_quests.gd` (new A02 regression) | **8/8, 142 assert, PASS**: data, flow, full marker build, started/derived flags, early polyp/alpha kill, west-first bypass |
| `test_quest_system.gd` | **9/9, 63 assert, PASS** |
| `test_labyrinth_quest_content.gd` | **4/4, 41 assert, PASS** |
| `test_labyrinth_first_fragment.gd` | **13/13, 332 assert, PASS** после полного импорта; SQ-слой не ломает baseline |
| `godot --headless --path . --import` | **EXIT=0**: полный импорт завершён; baseline-тесты после него зелёные |
| Ручной проход M3 | **NOT TESTED** |
| Каталог/маркеры/диалоги/choice | **NOT TESTED** — зависимости не готовы |

`tests/test_side_quests.gd` — новый файл в зоне A10. Он не меняет существующие тесты, но требует review A10 перед merge. Тест проверяет 5 ресурсов, полный event-flow, сборку директора на полном наборе маркеров, derived-flags после загрузки и early-kill/early-loot граничные случаи.

### 10.6. Reachability checklist для A10

| Quest | POI | M1? | Геометрический гейт |
|---|---|---|---|
| SQ-01 | `POI-Z02-02/03`, `POI-Z05-02`, `POI-Z06-02` | нет | G4 (Z06), G5 (Z03→Z05) |
| SQ-02 | `POI-Z08-05`, `POI-Z09-02…08`, `POI-Z09-11` | нет | G3 (устье Z09) |
| SQ-03 | `POI-Z06-02/03`, `POI-Z09-10` | нет | G4 (Z06) |
| SQ-04 | `POI-Z11-01…05` | нет | G2 (Z11 low), tide API |
| SQ-05 | `POI-Z14-01…16` | нет | низкая тропа Z14, alpha AI |

M1 не должен содержать ни один из этих POI. После A03-08/A03-09 A10 запускает `route_walk`/`route_reachability` и проверяет, что 32 SQ-точки достижимы без soft-lock.

### 10.7. Stage 4 self-audit — найденные и закрытые проблемы

| Проблема | Влияние | Решение |
|---|---|---|
| SQ-05 `.tres` выдавал 2 `soul_shard` при любом исходе | bypass получал награду, которой нет в дизайне | `rewards=[]`; 2/3 shards теперь world pickup за `alpha_dead`/`tide_trap` |
| SQ-05 runtime был полностью выключен | P1 нельзя было проверить | добавлен bypass-runtime: bridge/trail, marks/lair, chum/bait, WestEnd, reward |
| Theo dialogue path был жёстко один | A01 мог назвать файл иначе | добавлены candidate-array для Theo и TheoReturn |
| `QuestInspectable` отсутствует | следы исчезали при fallback | fallback `QuestPickup` оставлен; добавлены разные тексты улик, warning один раз; A04 должен добавить адаптер |
| Каталог не содержит SQ | `QuestSystem.start_quest` не находил definitions | точный patch для A04 в §10.2 |
| Маркеры SQ отсутствуют | runtime не строился | точный контракт для A03 в §10.3 |
| `test_labyrinth_first_fragment` был красным после неполного импорта | ложный вывод о поломке сцены | полный `--import --quit` → 13/13 PASS |
| SQ-05 kill/tide награды нельзя проверить без A05 | P1 остаётся частичным | bypass проверен; kill/tide помечены как зависимость A04/A05 |

### 10.8. A02-08: SQ не в M1

Проверено статически и усилено в runtime: `quest_catalog.tres` содержит только 7 базовых заданий; `labyrinth_first_fragment.tscn` не содержит `NarrativeQuestDirector`; директор дополнительно строит SQ только при `QuestSystem.active_scope == &"forgotten_shore"`, а не при любом активном scope. M1-сцена не получает SQ-контент. Runtime SQ возможен только в tech demo после A00-08/A03-08/A04-03 и добавления узла `Gameplay/NarrativeQuestDirector`.

**Итог:** данные SQ-01…05, runtime-каркас SQ-01…03 и bypass-путь SQ-05 реализованы в owned paths. Полная играбельность SQ-01…03 требует A04 (каталог + inspectable/choice), A01 (диалоги), A03 (маркеры), A05 (echo_polyp). SQ-05 kill/tide ждут A04/A05; SQ-04 runtime сознательно выключен до tide API.

---

## 11. Stage 6 — глубокий аудит полноты

**Дата:** 2026-11-03. **Scope:** только A02-owned paths; чужие файлы не менялись.
**База сравнения:** baseline `ee97325`, A02 commit `0cdec32`, Design Package `side_quests.md`, `MASTER_AUDIT.md`, `AGENT_TASKS.md` A02-01…08, текущий runtime.
**Ручной M3:** **NOT TESTED** — зависимости A01/A03/A04/A05/A08 всё ещё отсутствуют.

### 11.1. Граничные случаи, найденные и исправленные

| ID | Проблема | Последствие до фикса | Исправление |
|---|---|---|---|
| S6-01 | `WestEnd` требовал `sq_fs_05_started` | игрок, вошедший на мост с запада, не запускал bypass; цель могла остаться незакрытой | `required_flags=[]`; флаг `resolved` можно восстановить до старта |
| S6-02 | директор искал `QuestInspectable` только в `scripts/quests/` | A04 создаёт `scripts/inspect/quest_inspectable.gd`; адаптер никогда бы не использовался | добавлены оба пути, приоритет `scripts/inspect/` |
| S6-03 | полип убит до старта SQ-02 | KILL-цель стартует с 0, полип уже мёртв — soft-lock | `_repair_early_polyp_kill()` на старте и после сборки |
| S6-04 | альфа убита до/во время старта SQ-05 | `resolved` мог завершить квест раньше `killed`, optional `kill_alpha` оставался 0 | отложенный/повторный `_repair_alpha_kill()`; `resolved` после KILL-события |
| S6-05 | плащ/ядро SQ-02 видны после убийства полипа до старта SQ-02 | предметы можно забрать, а INTERACT-цели позже не закрываются | добавлен gate `sq_fs_02_voice_heard` |
| S6-06 | награда/приливный бонус SQ-05 видны до старта | награда забиралась вне последовательности | добавлен gate `sq_fs_05_started` |
| S6-07 | мёртвый полип/Old Shell спавнились после загрузки | дубли врагов и ложное состояние | spawn пропускается при `*_dead` |
| S6-08 | derived-флаги не восстанавливались | после load отсутствовали `tunnel_safe`, `low_route_safe`, `polyp_found` | `_sync_derived_flags()` + подписка на `flag_changed` |
| S6-09 | проверялся только `is_scope_active()` | чужой активный scope мог собрать SQ в сцене Лабиринта | явная проверка `active_scope == forgotten_shore` |
| S6-10 | `TheoReturn` был one-shot | закрытие choice без выбора блокировало повторный диалог | для SQ-03 `one_shot=false`; A08 скрывает/деспавнит по флагу |
| S6-11 | все эхо-точки и следы давали одинаковый текст | игрок не получал подсказку, какая точка «правильная» | разные тексты для A/B/C и Heel/Shell/Blood |
| S6-12 | не было обратной связи при сборе всех эхо и обходе моста | непонятно, что изменилось | сообщения «Три эха сходятся вверху…» и сообщение обхода |
| S6-13 | `sq_fs_02_polyp_found` зависел от `picked_up` fallback | при A04-инспекте флаг мог не появиться | derived-флаг по трём `sq_fs_02_echo_*` |
| S6-14 | ранний `sq_fs_05_alpha_dead` оставлял `alpha_spared` | взаимоисключающие исходы одновременно | `alpha_spared` очищается при смерти альфы |
| S6-15 | `sq_fs_01_started` нигде не выставлялся | следы и Тео оставались закрытыми даже после старта SQ-01 | started-флаги всех SQ синхронизируются по `quest_started` и состоянию save |
| S6-16 | загрузка сейва в уже открытой сцене не пересобирала SQ-мир | мёртвые враги/взятые предметы могли остаться в старом состоянии | `state_restored` → `refresh()`; world пересобирается по флагам |

### 11.2. Что осталось незавершённым

| ID | Состояние | Чего не хватает | Владелец | Влияние |
|---|---|---|---|---|
| S6-R01 | **BLOCKED** | диалоги `sq_fs_01_theo.tres`, `sq_fs_03_theo.tres`; speaker names `theo`, `theo_return`, `lissa_echo` | A01 | Тео/ТеоReturn не создаются; SQ-01/03 нельзя пройти |
| S6-R02 | **BLOCKED** | `QuestChoicePanel` и три выбора SQ-03, флаги `choice_*`, `cache_allowed`, `theo_left` | A04/A08 | SQ-03 не завершается |
| S6-R03 | **BLOCKED** | `echo_polyp.tscn`, тендрилы, ядро/Health, 1–2 карапакса, bell/bone spear | A05/A04 | SQ-02 kill/quiet/bell пути не играбельны |
| S6-R04 | **BLOCKED** | bestiary entries и unlock events для echo polyp / Old Shell | A05/A09 | нет бестиария и записи «seen/defeated» |
| S6-R05 | **DISABLED** | `QuestTideLock`, `advance_to_low/high`, SQ-04 interactables | A04 | SQ-04 runtime выключен; карта/указатель не выдаются |
| S6-R06 | **BLOCKED** | Old Shell, 2 scavengers, tide trap, WaitSpot, ShadowInspect | A05/A04 | SQ-05 kill/tide/tide-wait не проверены; bypass работает |
| S6-R07 | **MISSING** | 25 runtime-маркеров и узел `Gameplay/NarrativeQuestDirector` | A03 | сцена не собирает SQ |
| S6-R08 | **MISSING** | 5 SQ entries в `quest_catalog.tres` | A04 | `start_quest()` не находит SQ в живой сцене |
| S6-R09 | **MISSING** | Theo/Polyp/Old Shell/SaltBox модели, анимации, props | A06 | только `Mannequin`/fallback; нет bespoke-анимаций |
| S6-R10 | **MISSING** | SQ VFX/SFX/VO | A09 | нет brass glint, биолюминесценции, падения коралла, VO |
| S6-R11 | **PARTIAL** | 5 квестовых маркеров карты, journal header, choice UI | A08 | карта/журнал не отражают SQ полностью |
| S6-R12 | **PARTIAL** | fallback `QuestPickup` исчезает и выглядит как collectible | A04 | до `QuestInspectable` улики не остаются в мире |
| S6-R13 | **NOT TESTED** | ручной проход M3, death/respawn, F5/F9 посреди SQ | A10/A00 | нет подтверждения end-to-end |
| S6-R14 | **NOT TESTED** | A04 `QuestInspectable` с `required_flags` и повторным включением | A04/A10 | контракт enable/disable не проверен на реальном классе |

### 11.3. 32 POI и 25 маркеров

25 маркеров — это **anchor-контракт директора**: по одному на объект/точку взаимодействия. Остальные POI Design Package (всего 32) — дочерние/спавновые точки, которые создаёт A05 внутри `echo_polyp.tscn`/Old Shell (тендрилы A/B/C, карапаксы, tide trap/wait) или A04 внутри SQ-04; дублировать их в директоре нельзя. A10 route-тест должен проверить все 32 POI после A03/A05.

### 11.4. Проверки Stage 6

| Проверка | Результат |
|---|---|
| `test_side_quests.gd` | **8/8, 142 assert, PASS** |
| `test_quest_system.gd` | **9/9, 63 assert, PASS** |
| `test_labyrinth_quest_content.gd` | **4/4, 41 assert, PASS** |
| `test_labyrinth_first_fragment.gd` | **13/13, 332 assert, PASS** (полный импорт) |
| `--import --quit` | **EXIT=0** |
| Director build, полный набор 25 маркеров | **PASS**: 22 объекта без A01/A05; 19 конкретных узлов проверены тестом |
| SQ-05 west-first bypass | **PASS**: `alpha_spared` + `resolved` + complete, 0 shards |
| Ранний kill полипа/альфы | **PASS**: KILL-цель восстанавливается, optional `kill_alpha` = 1 |
| Ручной M3 | **NOT TESTED** |

### 11.5. Передача

1. **A04:** создать `scripts/inspect/quest_inspectable.gd` по контракту, добавить 5 SQ в каталог, реализовать `QuestChoicePanel`/`QuestTideLock`/`advance_*`. Проверить повторное включение по `required_flags`.
2. **A03:** поставить 25 маркеров и `Gameplay/NarrativeQuestDirector` после `QuestDirector`; не дублировать дочерние точки A05.
3. **A01:** добавить диалоги/speaker names; без них SQ-01/03 не создают NPC.
4. **A05:** `echo_polyp.tscn` (Health/ядро/тендрилы), Old Shell, карапаксы, scavengers; ставить `sq_fs_02_polyp_dead`/`sq_fs_05_alpha_dead` через `QuestKillCredit`.
5. **A06/A09:** модели, анимации, VFX/SFX/VO; SQ-02/05 без них остаются серыми.
6. **A08:** choice UI, 5 маркеров карты, journal header.
7. **A10:** review `tests/test_side_quests.gd`; ручной M3, F5/F9, death/respawn, route 32 POI.

**Итог Stage 6:** все найденные в A02-owned коде early-kill/early-loot/save/scope edge cases закрыты и покрыты тестами; оставшиеся пункты — внешние зависимости, а не незакоммиченный код A02. Полный M3 PASS по-прежнему **не заявлен**.
