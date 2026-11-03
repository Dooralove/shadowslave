# Gameplay & Quest Systems — отчёт Chat 04

Дата: 2026-11-02
Полный системный аудит: `docs/demo_sprint/audits/gameplay_systems.md`
Архитектура: `docs/demo_sprint/design/gameplay_architecture.md`
Связанный отчёт Chat 02: `docs/demo_sprint/audits/quests.md`

## 0. Сводка

1. `NightmareRunState` — единственный state; в него аддитивно добавлены `quests`, `currency`, `memories`, `tracked_quest` и снимок.
2. `QuestSystem` — существующий autoload; второй framework не создавался. Scope активируется только `LabyrinthQuestDirector`.
3. Реализованы 7 заданий-каркасов: `first_day`, `first_blood`, `azure_blade`, `crystal_cache`, `hunt_pack`, `camp_rest`, `bridge_stand`.
4. Реализованы мировые адаптеры: `QuestPickup`, `QuestNpc`, `QuestTriggerZone`, `CheckpointZone`, `QuestKillCredit`; `start_quest_id` — для будущих `auto_start=false` заданий.
5. Награды идут в `NightmareRunState` (item/currency/memory/flag) или `HealthComponent.heal`; повтор идемпотентен.
6. `RpgQuestScreen` выбирает live QuestSystem → историю CampaignGuide → DEMO-каталог; tracking вынесен в кнопку.
7. `ObjectiveLine` при активном scope читает QuestSystem и показывает прогресс-бар; beat-цель не подменяется вне scope.
8. `SaveSystem` — быстрый слот `user://campaign_save.bin` (F5/F9), автосейв на чекпоинтах/завершении задания; `snapshot` включает квесты.
9. Пять нарративных SQ-01…05 из `design/side_quests.md` — дизайн, не реализованы.
10. Целевые тесты: `test_quest_system` 9/9, `test_labyrinth_quest_content` 4/4, `test_save_system` 2/2; совместно 15/15, 118 assert, exit 0.

## 1. Фактическое состояние

| Система | Файл | Состояние |
|---|---|---|
| State | `scripts/campaign/nightmare_run_state.gd` | flags/items/quests/currency/memories/bestiary/checkpoint/snapshot |
| Quests | `scripts/quests/quest_system.gd` | start/complete, events, tracking, journal, rewards |
| Data | `resources/quests/*.tres` | 7 valid definitions + catalog |
| World | `labyrinth_quest_director.gd` | triggers, checkpoints, pickups, NPCs, 6 enemies |
| HUD | `gameplay_hud.tscn`, `quest_toast.gd`, `objective_line.gd` | objective, prompt, subtitles, combat, toast |
| Journal | `rpg_quest_screen.gd` | live journal + campaign fallback + DEMO fallback |
| Save | `scripts/systems/save_system.gd` | F5/F9, checkpoint/quest autosave |
| Transitions | `tide_descent.tscn` | ToCoral → labyrinth_first_fragment / FromDescent |

## 2. P0 / P1 / P2

### P0

- Не активировать `QuestSystem` в S00–S15; scope только Лабиринт.
- Не ломать `NightmareRunState.snapshot()`; квесты/валюта/Памяти входят в снимок.
- Не создавать второй инвентарь/журнал/Interactor.
- `project.godot` autoload: `QuestSystem` и `SaveSystem` зарегистрированы; `CampaignGuide` сохранён.
- Структурный тест Лабиринта остаётся внешним блокером (`SunnyAnimator` clips/`_update_grounding`).

### P1

- SQ-01…03 из `design/side_quests.md`.
- `QuestStart` уже есть; добавить `QuestInspectable`, `QuestTideLock`, choice/OR-цели.
- Квестовые маркеры карты и `hide_when_flag`.
- Bestiary/map rewards.
- Звук `ui_quest_update`.

### P2

- SQ-04/05, уникальные NPC, VO, файловые слоты с UI.

## 3. Проверки

```text
test_quest_system.gd          9/9, 63 asserts
test_labyrinth_quest_content.gd 4/4, 41 asserts
test_save_system.gd           2/2, 14 asserts
combined                      15/15, 118 asserts, exit 0
full GUT (parallel tree)      602/619, 17 failures in animation/VFX/combat resources
```

Полный ручной проход и F5/F9 в живом окне — **NOT TESTED**.

---

## 4. Stage 3 wave 1 — фактическая реализация A04

**Дата:** 2026-11-03
**Ветка:** `demo/gameplay`
**База:** `ee97325`
**Рабочее дерево:** изменения закоммичены в A04 final commit; хеш передаётся TD.

### 4.1. Что изменено

| Файл | Изменение |
|---|---|
| `scripts/campaign/nightmare_run_state.gd` | `FLAG_ALIASES` + `canonical_flag()`; canonical-only writes/snapshot; restore канонизирует старые сейвы |
| `scripts/dialogue/dialogue_runner.gd` | canonical `jett`, `rock`, `kasper`, `cassia`, `medic`, `theo` + legacy `jet`, `casper`, `technician`, `lissa_echo` |
| `scripts/quests/quest_system.gd` | guard: активировать можно только scope каталога (`forgotten_shore`) |
| `scripts/systems/save_system.gd` | очистка pending для сцен без игрока (финальная карточка) |
| `scripts/world/level_portal.gd` | `body_exited` + повторная проверка required flag, если игрок уже в зоне |
| `scripts/campaign/post_nightmare_finale.gd` | M1/tech mode branch, canonical flag, clear guide/scope, deferred save |
| `scripts/inspect/quest_inspectable.gd` | новый аддитивный `Interactable` для улик/зеркала/Плаща |
| `scripts/quests/quest_choice_controller.gd` | backend выбора SQ-03; UI остаётся A08 |
| `scripts/quests/quest_tide_lock.gd` | гейт по высоте воды; совместим с текущим `get_level()` и будущим `get_water_y()` |
| `scripts/quests/quest_tide_wait.gd` | вызов будущих `advance_to_low/high`; не создаёт таймер |
| `scripts/world/quest_finale_zone.gd` | M1/tech final zone, one-shot, flags, clear/deactivate |

### 4.2. Проверки

| Проверка | Результат |
|---|---|
| `godot --headless --path . --import` | exit 0 |
| Full GUT: `-gdir=res://tests -gexit` | **82 script, 648 tests, 648 pass, 7380 asserts, exit 0**; 312.36 s; только orphan-диагностика |
| `test_quest_system` | 9/9, 63 asserts |
| `test_save_system` | 2/2, 14 asserts |
| `test_labyrinth_quest_content` | 4/4, 41 asserts |
| `test_post_nightmare_locations` | 15/15, 513 asserts |
| `test_level_transition` | 22/22, 83 asserts |
| `test_map_system` | 22/22, 836 asserts |
| `test_quest_extensions.gd` | 12/12, 47 asserts: aliases, Inspectable, choice, tide lock/wait, final zone/card, map flags, P05 scope, portal flag recheck, start order |

### 4.3. Не проверено / зависит от других

- **A00 review:** `scripts/campaign/nightmare_run_state.gd` и `scripts/world/level_portal.gd` — shared-file contracts; изменения в них требуют подтверждения A00 перед merge.
- **A03:** portal required/set flags в P05–B02, `DemoEndZone`/`FinalZone` nodes, `QuestInspectable`/`QuestTideLock` placements, `TideController.get_water_y`/`advance_*`.
- **A08:** `MapScreen._build_marker_list()` flags fix, `QuestChoicePanel` UI, финальные карточки/тексты.
- **A10:** live F5/F9, M1 manual pass, route/reachability, stress.
- **NOT TESTED:** ручной проход, живой F5/F9, фактический финальный переход из Z10/Z18, choice UI, экспортная сборка.

### 4.4. Точные запросы владельцам других зон

**A03 — сцены/порталы/прилив.** A04 не редактирует `scenes/locations/**` и `scripts/locations/**`.

| Сцена | Что добавить/изменить |
|---|---|
| P05 `police_precinct` | `Portals/ToAcademyApproach.required_flags = [p05_jett_talked, p05_mirror_seen]`; `set_flags_on_use = [p05_completed]` |
| P06 `academy_approach` | `Portals/ToAcademyGate.required_flags = [jett_advice_heard]`; `set_flags_on_use = [p06_completed]` |
| P07 `academy_gate` | `Portals/ToCampus.required_flags = [academy_gate_passed]`; `set_flags_on_use = [p07_completed]` |
| P08 `academy_campus` | `Portals/ToSleeper.required_flags = [dorm_assigned]`; `set_flags_on_use = [p08_completed]` |
| P09 `academy_sleeper_center` | `Portals/ToBlackSea.required_flags = [induction_seen, capsule_entered]`; `set_flags_on_use = [p09_completed]` |
| B01 `black_sea_platform` | `Portals/ToCoral.required_flags = [statue_seen, shroud_summoned]`; `set_flags_on_use = [b01_completed]` |
| B02 `tide_descent` | `Portals/ToCoral.required_flags = [b01_completed]`; `set_flags_on_use = [b02_completed]` |
| Z10 | Node `DemoEndZone` (Area3D + `quest_finale_zone.gd`) at `(-100, 18.2, -5)`, sphere radius 4, `mode = 0`, `required_flags = [shore_first_day_complete, camp_night_seen]`, `completion_flag = post_nightmare_demo_completed` |
| Z18 | Node `FinalZone` (Area3D + `quest_finale_zone.gd`) at `(-1410, 35.2, 0)`, sphere radius 4, `mode = 1`, `completion_flag = post_nightmare_completed`; `Portals/ToWest.enabled = false` |
| Z11 | Attach `QuestTideLock` to Salt Box; `QuestTideWait` to high-ledge wait point |
| Z06/Z09/Z14 | Attach `QuestInspectable` to SQ-01/02/05 traces/cache/lair; set `start_quest_id`/`completion_flag`/`quest_event` |
| `TideController` | Add `get_water_y() -> float`, `advance_to_low() -> bool`, `advance_to_high() -> bool`; keep `get_level()` normalized for HUD |

**A08 — UI.** A04 не редактирует `scenes/ui/**`, `scripts/ui/**`.

- `MapScreen._build_marker_list()` must use `_game_flags()` and `visible_markers(flags)`; current `{}` is still a bug.
- `QuestChoicePanel` UI: connect `show_choices(prompt, choices)` and emit `choice_selected(choice_id)`; never write state.
- Final card: M1 title «ПЕРВЫЙ ДЕНЬ / Конец M1», tech title «Конец демонстрационного фрагмента»; call `is_m1()` from `post_nightmare_finale.gd`.
- M1 HUD objective must not be overwritten by QuestSystem outside B03.

**A10 — tests.** Add permanent tests for the temporary A04 probe cases: aliases, Inspectable, ChoiceController, TideLock/Wait, FinaleZone/card, map flags, scope isolation, portal flag recheck, start order, live save/load.

**A00 — contracts/review.** Review `nightmare_run_state.gd`/`level_portal.gd`; decide whether to keep `QuestChoiceController` or rename contract to `QuestChoicePanel` backend; update `INTEGRATION_CONTRACTS`; add `TideController.get_water_y`/`advance_*` to A03 task; resolve old freeze claim.

---

## 5. Stage 4 — дополнительный аудит A04

**Дата:** 2026-11-03. **Ветка:** `demo/gameplay`. **HEAD:** `ee97325`.
**Изменения:** закоммичены в A04 final commit; игровые сцены, UI и `project.godot` не менялись.

### 5.1. Дополнительно исправлено

- `QuestFinaleZone` теперь использует существующий `FadeLayer`, если он есть в сцене; при отсутствии слоя переход остаётся мгновенным. Это убирает резкий скачок Z10/Z18 → финальная карточка.
- `post_nightmare_finale.gd` принудительно завершает `QuestSystem` scope и очищает внешнюю цель даже при прямом запуске сцены.
- `SaveSystem` больше не оставляет pending-позицию в сценах без `player`.

### 5.2. Новые/подтверждённые проблемы

| ID | Проблема | Владелец | Влияние |
|---|---|---|---|
| A04-S4-01 | M1 final zone не существует в `labyrinth_first_fragment.tscn`; `ToWest` всё ещё включён | A03 | M1 завершается не в Z10, а через Z18; финальный флаг может быть неверным |
| A04-S4-02 | Портал P05–B02 не имеют required/set flags | A03 | можно проскочить сюжетные гейты; M1 не соответствует контракту |
| A04-S4-03 | Нет `QuestInspectable`/`QuestTideLock` nodes в мире | A03/A02 | новые компоненты недоступны игроку |
| A04-S4-04 | Нет `TideController.advance_to_low/high` | A03 | SQ-04/SQ-05 tide actions не работают; `QuestTideWait` только сообщает о недоступности |
| A04-S4-05 | `MapScreen._build_marker_list()` передаёт `{}` | A08 | скрытые маркеры остаются в списке |
| A04-S4-06 | Нет `QuestChoicePanel` UI | A08 | backend SQ-03 не отображается игроку |
| A04-S4-07 | Финальная карточка статична: M1/tech текст не переключается | A08 | M1 показывает tech-demo текст |
| A04-S4-08 | Live F5/F9, ручной проход, финальный переход не проверены | A10 | нельзя утверждать M1 PASS |
| A04-S4-09 | `ACTIVE_CLAIMS` содержит старый freeze/claim Chat 02+04 | A00 | shared-file ownership не зафиксирован для merge |
| A04-S4-10 | `QuestChoiceController` не описан в `INTEGRATION_CONTRACTS` | A00 | возможен конфликт с будущим A08-классом |

### 5.3. Итог Stage 4

A04-компоненты готовы и покрыты full GUT, но **M1 не является playable** без сцен A03 и UI A08. Дальнейшая работа A04 без этих зон была бы дублированием чужого контента или скрытой подменой. Следующий корректный шаг — интеграция A03/A08/A10 и повторный full GUT + manual.

---

## 6. Stage 6 — deep completeness audit

### 6.1. Исправлено в Stage 6

- `QuestInspectable`: добавлен `inspect_text` и toast-обратная связь после осмотра.
- `QuestTideLock`: добавлен `success_text`; при высокой воде остаётся внятное сообщение, успешное открытие даёт feedback.
- `QuestFinaleZone`: проверяет существование `finale_scene` до установки флага; использует `FadeLayer`, если он есть.
- `QuestChoiceController`: закрывается при `NightmareRunState.state_reset`, чтобы панель не висела между забегами.
- `LevelPortal`: flag-recheck не обходит spawn protection, поэтому появление внутри портала не зацикливает переход.
- Добавлен постоянный `tests/test_quest_extensions.gd` (12/12, 43 asserts) вместо временного probe.

### 6.2. Оставшиеся проблемы

| ID | Проблема | Владелец |
|---|---|---|
| S6-01 | `DemoEndZone`/`FinalZone` не стоят в сценах; M1 финал недоступен в Z10 | A03 |
| S6-02 | Порталы P05–B02 без required/set flags | A03 |
| S6-03 | `QuestInspectable`/`QuestTideLock` не размещены в мире | A03/A02 |
| S6-04 | Нет `TideController.get_water_y`/`advance_to_low/high` | A03 |
| S6-05 | `MapScreen._build_marker_list()` всё ещё `{}` | A08 |
| S6-06 | Нет `QuestChoicePanel` UI | A08 |
| S6-07 | M1/tech текст финальной карточки не переключается | A08 |
| S6-08 | Live F5/F9, manual M1, final transition, export — NOT TESTED | A10/A00 |
| S6-09 | `QuestChoiceController`/`QuestFinaleZone` не в `INTEGRATION_CONTRACTS` | A00 |
| S6-10 | `ACTIVE_CLAIMS` старый claim/freeze | A00 |

### 6.3. Runtime/parse

- `--import`: exit 0.
- Full GUT: **648/648, 7376 asserts, exit 0**, 344.33 s; orphan diagnostics only.
- Headless scene load: `main_menu`, `post_nightmare_finale`, `police_precinct`, `labyrinth_first_fragment` — exit 0.
- Ручной проход, живой F5/F9, финальный переход из Z10/Z18 — **NOT TESTED**.

---

## 7. Stage 7 — quality pass

### 7.1. Исправлено

- Финальная карточка теперь переключает заголовок, kicker, текст и hint между M1 и tech demo; M1 показывает «ПЕРВЫЙ ДЕНЬ», а не текст tech demo.
- `SaveSystem` сообщает игроку о неудачном сохранении/загрузке через существующий toast, а не только через `push_error`.
- Закрытый `LevelPortal` с `required_flags` показывает `locked_message`, вместо молчаливого игнорирования входа.
- `QuestInspectable`/`QuestTideLock` получили явную текстовую обратную связь об осмотре/успехе.
- Portal flag-recheck не обходит spawn protection.
- Финальная зона проверяет существование `finale_scene` и использует `FadeLayer`.

### 7.2. Проверки Stage 7

| Проверка | Результат |
|---|---|
| `--import` | exit 0 |
| Full GUT | **82 scripts, 648 tests, 648 pass, 7380 asserts, exit 0**, 312.36 s |
| `test_quest_extensions.gd` | 12/12, 47 asserts |
| `test_level_transition` | 22/22, 83 asserts |
| `test_post_nightmare_locations` | 15/15, 513 asserts |
| Runtime load `main_menu`, `post_nightmare_finale`, `police_precinct`, `labyrinth_first_fragment` | exit 0 |
| `git diff --check` | exit 0 |

### 7.3. Что всё ещё портит впечатление

- M1 final отсутствует в Z10; игрок не увидит M1-финал на положенном месте (A03).
- Закрытые порталы/улики/приливные объекты не расставлены в сценах (A03/A02).
- `MapScreen` список маркеров всё ещё может показывать скрытые объекты (A08).
- Choice UI отсутствует (A08).
- Живой F5/F9 и ручной проход не проверены (A10).

**NOT TESTED:** ручной M1, живой F5/F9, фактический переход Z10/Z18 → карточка, Choice UI, MapScreen UI, export build.
