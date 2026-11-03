# Gameplay & Quest Systems — Implementation Specification

**Домен:** A04 — Gameplay & Quest Systems  
**Статус:** Stage 2 implementation specification; **игровые файлы не изменялись**  
**Design package:** DP-1.0, `MASTER_PLAN.md`, `FILE_OWNERSHIP.md`, `INTEGRATION_CONTRACTS.md`  
**Базовая точка:** commit `0335a5c346901af2146413b5a159b442d326d8de`, branch `s3-park-art`, dirty tree  
**Владелец документа:** A04  
**Документ-спутник:** `docs/demo_sprint/implementation/AGENT_TASKS.md` (§6, A04-01…A04-12)

> Это спецификация, а не разрешение на правки. Production-работа начинается только после того, как Technical Director подтвердит DP-1.0, file-level claims и решения из §11. До этого меняется только этот документ.

---

## 0. Резюме для Technical Director

1. **A04 не создаёт второй QuestSystem, state, save, HUD, interactor, tide controller или reward pipeline.** Все новые элементы — аддитивные компоненты поверх существующих `QuestSystem`, `NightmareRunState`, `SaveSystem`, `Interactable`, `DialogueRunner` и `TideController`.
2. **M1 (Z01–Z10) и tech demo (Z11–Z18) — два режима, а не две ветки кода.** Один `post_nightmare_finale.tscn`, один `QuestFinaleZone`, разные флаги и разные условия срабатывания.
3. **`start_quest_id` уже реализован** в `QuestNpc`, `QuestPickup`, `QuestTriggerZone`; задача A04-04 — проверить порядок `start_quest` → `notify_event`, а не добавлять поле заново. BUG-011 в `MASTER_AUDIT.md` устарел.
4. **`MapDefinition.visible_markers(flags)` и `MapMarker.hide_when_flag` уже есть.** A04 отвечает за контракт и тест; исправление `MapScreen._build_marker_list()` — A08.
5. **Новых autoload, сцен локаций, UI-файлов, диалоговых ресурсов и тестов в A04-ветке нет.** Кросс-зонные изменения разбиты на A03/A08/A10-задачи.
6. **Главные технические риски:** несовместимость `TideController.get_level()` (нормализованный 0…1) с проектным `max_level = -1.0`; неопределённое владение `QuestChoicePanel`; отсутствие `demo_mode_full` в текущем коде; старые тесты, ожидающие tech-demo-флаг и включённый `Portals/ToWest`.
7. **A04-ветка должна быть зелёной на своих unit-контрактах без правок чужих файлов.** Финальная интеграция M1 требует A03 (сцены/порталы/зоны), A08 (UI/карта/карточка), A10 (тесты) и A00 (freeze/claims).

---

## 1. Scope и границы

### 1.1. Что входит

| Направление | Работа A04 |
|---|---|
| Состояние | Канонические флаги, aliases, `snapshot/restore`, сохранение финального флага |
| Квесты | `QuestSystem` scope, `start_quest_id` verification, `QuestInspectable`, `QuestChoiceController` |
| Прилив | `QuestTideLock`, `QuestTideWait` (P2), контракт с `TideController` |
| Переходы | `LevelPortal` gates, idempotency, повторное срабатывание после флага |
| Финал | `QuestFinaleZone`, `post_nightmare_finale.gd`, M1/tech-demo flags, очистка цели, save |
| Карта | `MapDefinition.visible_markers` / `MapMarker` contract test; UI-фикс — A08 |
| Диалоги | `DialogueRunner.speaker_names`: canonical + legacy aliases |
| Документация | Эта спецификация, A04-архитектура, A04-аудит; без чужих отчётов |

### 1.2. Что не входит

- Второй `QuestSystem`, `QuestCatalog`, `QuestJournal`, `QuestLog`, `SideQuestDefinition`.
- Второй `NightmareRunState`, `SaveSystem`, `CampaignGuide`, `TideController`, `Interactor`, `Interactable`, HUD, inventory.
- `QuestOutcomeReward` и любые outcome-reward классы: уникальные награды — world pickup + flags, обычные — `QuestReward`.
- Правка `project.godot`, autoload, `scenes/ui/**`, `scripts/ui/**`, `scenes/locations/**`, `scripts/locations/**`, `resources/dialogue/**`, `assets/**`, `tests/**`.
- SQ-FS-01…05 как production-контент M1. Пять SQ — **M3**, не M1; их данные создаёт A02, каталожные entries добавляет A04.
- Z11–Z18 до M1 PASS. Tech demo не начинается раньше A00-07/A00-08.
- Полный ручной проход, export build, слуховой тест. Это A10/A00.

### 1.3. Режимы и milestones

| Режим | Маршрут | Финал | Флаг | Условие |
|---|---|---|---|---|
| **M1** | `main_menu → … → labyrinth_first_fragment Z01–Z10` | `POI-Z10-09`, `DemoEndZone` | `post_nightmare_demo_completed` | `demo_mode_full` не выставлен; `shore_first_day_complete` + `camp_night_seen` (см. D-05) |
| **Tech demo** | Z01–Z18 | `POI-Z18-05`, `FinalZone` | `post_nightmare_completed` | `demo_mode_full` выставлен |
| **M3** | SQ-01…05 поверх tech demo | свои исходы | `sq_fs_*` | после M1 PASS; A02/A01/A03/A08 |

`demo_mode_m1` может выставляться явно для логов, но **default — M1 при отсутствии `demo_mode_full`**. Приоритет: `demo_mode_full` > явный `demo_mode_m1` > default M1.

---

## 2. Текущее состояние: факты, а не предположения

### 2.1. Что уже готово и переиспользуется

| Элемент | Факт | Статус | Действие A04 |
|---|---|---|---|
| `QuestSystem` | `activate_scope` / `deactivate_scope`, `start_quest`, `notify_event`, journal, tracking, reward idempotency | READY | Не переписывать |
| `QuestCatalog` | `resources/quests/quest_catalog.tres`, 7 валидных квестов | READY | Не менять для M1 |
| `NightmareRunState` | flags/items/bestiary/quests/currency/memories/checkpoint, snapshot/restore | READY | Добавить alias-слой |
| `SaveSystem` | `user://campaign_save.bin`, F5/F9, scene/position | READY (unit) | Дожать live-flow и final save |
| `LevelPortal` | destination/spawn, required flags, set flags, one-shot, fade | READY | Добавить re-check после флага, если нужно |
| `QuestNpc` / `QuestPickup` / `QuestTriggerZone` | `start_quest_id` уже есть; порядок в целом верный | READY | Только verification |
| `Inspectable` | подсветка/чутьё, не квестовый адаптер | READY | Не заменять |
| `Interactable` / `Interactor` | общий мир взаимодействий | READY | Наследовать |
| `DialogueRunner` | linear sequence, subtitles, voice | READY | Только speaker names |
| `TideController` | `set_phase`, `get_level`, `is_high_water`, `seconds_until_*` | READY | Контракт с A03 |
| `MapDefinition.visible_markers` | фильтрация по `show_when_flag` / `hide_when_flag` | READY | Только тест/contract |
| `MapMarker.hide_when_flag` | поле есть | READY | Не дублировать |
| `CampaignGuide` | external objective, clear/reset | READY | Финальная очистка |
| `post_nightmare_finale` | карточка, возврат в меню | READY | Добавить mode branch |

### 2.2. Что требует исправления

| Проблема | Доказательство | Владелец | Задача |
|---|---|---|---|
| Нет alias-слоя канонических флагов | `NightmareRunState.set_flag/has_flag` работают только с точным именем | A04 | A04-01 |
| `post_nightmare_finale.gd` всегда ставит `post_nightmare_completed` | скрипт, строка `_ready`; M1 получит tech-флаг | A04 | A04-10/A04-11 |
| `DialogueRunner.speaker_names` не содержит `jett`, `rock`, `kasper`, `theo`; `jet` — legacy | словарь speaker_names | A04 | A04-12 |
| `MapScreen._build_marker_list()` передаёт `{}` | `map_screen.gd`, вызов `visible_markers({})`; canvas при этом получает flags | A08 | A08-03 |
| `LevelPortal` не перепроверяет флаг, если игрок уже внутри зоны | логика `body_entered`; диалог может выставить флаг после входа | A04 | A04-02 |
| `TideController.get_level()` — нормализованный 0…1, а контракт `max_level = -1.0` | `tide_controller.gd` | A03 + A04 | A04-07, D-04 |
| `TideController` не имеет `advance_to_low/high` | файл A03 | A03 | A03-07, A04-07 |
| `post_nightmare_finale` не выбирает M1/tech подпись | сцена и скрипт | A04/A08 | A04-10/A04-11, D-04 |
| `Portals/ToWest` включён и ведёт прямо в финал | `labyrinth_first_fragment.tscn` | A03 | A03-10 |
| Нет `DemoEndZone` / `FinalZone` | сцена и grep | A03 | A03-08/A03-10 |
| `demo_mode_full` нигде не выставляется | grep по проекту | A00/A08 | A00-08, D-06 |
| Живой F5/F9 не проверен | `MASTER_AUDIT.md` | A10 | A10-04 |
| Старый тест ждёт tech-флаг при прямом инстансе финала | `test_post_nightmare_locations.gd` | A10 | A10-test update |
| Старый тест ждёт `ToWest.enabled == true` | `test_labyrinth_first_fragment.gd` | A10 | A10-test update |

### 2.3. Чего нет и что создаётся

| Новый элемент | Назначение | Кто создаёт |
|---|---|---|
| `scripts/inspect/quest_inspectable.gd` | `Interactable` с quest_event/completion_flag/start_quest_id | A04 |
| `scripts/quests/quest_choice_controller.gd` | backend выбора, сигнал, запись флага, `notify_event` | A04 (provisional; D-03) |
| `scripts/quests/quest_tide_lock.gd` | гейт по воде, без второго таймера | A04 |
| `scripts/quests/quest_tide_wait.gd` | «переждать прилив», вызывает A03 API | A04 (P2) |
| `scripts/world/quest_finale_zone.gd` | M1/tech final zone, one-shot, flags, save/clear | A04 (provisional; D-02) |
| `scenes/ui/quest_choice_panel.tscn` + `scripts/ui/quest_choice_panel.gd` | UI выбора | A08 |
| `DemoEndZone` / `FinalZone` nodes | сцены Z10/Z18 | A03 |
| A10 contract tests | проверки A04-01…12 | A10 |

### 2.4. Противоречия в документации

| ID | Противоречие | Факт | Решение |
|---|---|---|---|
| DOC-01 | `MASTER_AUDIT` BUG-011: «нет `start_quest_id`» | Поле есть в трёх классах и вызывается до `notify_event` | Считать BUG-011 устаревшим; задача — тест A04-04 |
| DOC-02 | `side_quests.md` §3.3: «ни один класс не вызывает `start_quest`» | противоречит §0.0 и фактическому коду | Считать устаревшим; исправить при следующей редакции A02 |
| DOC-03 | `INTEGRATION_CONTRACTS`: `QuestTideLock.max_level := -1.0` и `get_level() <= max_level` | `get_level()` возвращает 0…1 | D-04: `max_water_y` + `get_water_y()` (A03), либо нормализованный threshold |
| DOC-04 | `QuestChoicePanel` описан как CanvasLayer, но UI принадлежит A08 | A04 не может создать UI-класс | D-03: backend `QuestChoiceController` + UI A08 |
| DOC-05 | `demo_end_zone.gd` назван в A03-08, логика финала — A04 | `scripts/locations/**` — A03, `scripts/world/**` — A04 | D-02: `quest_finale_zone.gd` A04, сцена A03 |
| DOC-06 | `post_nightmare_finale.*` одновременно A04 и A08 | A04 — сцена/скрипт, A08 — карточка/UI | D-07: A04 script, A08 shared scene claim |
| DOC-07 | M1 final condition в `MASTER_PLAN` не перечисляет `camp_night_seen` | `narrative_design.md` требует `shore_first_day_complete` + `camp_night_seen` | D-05: утвердить оба флага |
| DOC-08 | `MapScreen` в UI-аудите назван исправленным | в коде `_build_marker_list()` всё ещё `{}` | Считать UI-аудит частично устаревшим; A08-03 |

---

## 3. Целевая архитектура

### 3.1. Источник истины

```text
NightmareRunState (autoload)
  ├── flags: canonical only
  ├── quests: state + objectives + reward_claimed
  ├── items/currency/memories/bestiary/checkpoint
  └── snapshot()/restore()  ← единственный путь сохранения

QuestSystem (autoload)
  ├── читает QuestCatalog
  ├── читает/пишет NightmareRunState
  ├── scope active только в B03
  └── signals: quest_started/progressed/completed/reward

Scene objects (A03)
  ├── QuestNpc / QuestPickup / QuestTriggerZone / QuestKillCredit
  ├── QuestInspectable / QuestTideLock / QuestTideWait
  └── QuestFinaleZone
        ↓
  QuestSystem.start_quest → notify_event → NightmareRunState → flags/rewards
```

### 3.2. Поток данных

1. Сцена/объект вызывает `start_quest_id` (если задан) **до** `notify_event`.
2. `QuestSystem` активирует квест и цель в `NightmareRunState`.
3. `notify_event` продвигает только активные квесты; повторный контакт не дублирует.
4. Завершение ставит `completion_flag`, выдаёт `QuestReward` один раз (`reward_claimed`), обновляет journal/HUD.
5. `SaveSystem` сохраняет `snapshot()` + scene/position; `restore()` не создаёт второй state.
6. Финальная зона читает flags, вызывает `deactivate_scope`, `CampaignGuide.clear_external_objective()`, ставит флаг, меняет сцену.
7. `post_nightmare_finale` ставит флаг идемпотентно, сохраняет, возвращает в меню.

### 3.3. Запрет дублей

- **Один** `QuestSystem`; новые функции — только в `scripts/quests/**`.
- **Один** `NightmareRunState`; aliases — внутри него, не второй словарь.
- **Один** `SaveSystem`; финальный сейв — его вызов, не второй слот.
- **Один** `Interactable` фреймворк; `QuestInspectable` и `QuestTideLock` наследуют его.
- **Один** `TideController`; `QuestTideWait` только вызывает методы A03.
- **Один** `DialogueRunner`; choice — отдельный backend/UI, не ветвление в runner.
- **Один** `post_nightmare_finale`; M1 и tech demo отличаются флагами, не сценой.

---

## 4. Детальные контракты

### 4.1. `NightmareRunState`: canonical flags + aliases

**Файл:** `scripts/campaign/nightmare_run_state.gd` (A04; shared-file claim A00)

```gdscript
const FLAG_ALIASES := {
    &"precinct_mirror_seen": &"p05_mirror_seen",
    &"academy_jet_seen": &"jett_advice_heard",
    &"academy_gate_checked": &"academy_gate_passed",
    &"sleeper_ready": &"capsule_entered",
    &"black_sea_stars_seen": &"statue_seen",
    &"black_sea_sword_seen": &"statue_seen",
    &"demo_m1_completed": &"post_nightmare_demo_completed",
    &"demo_completed": &"post_nightmare_completed",
}
```

**Правила:**

1. `set_flag(alias, value)` пишет **только** canonical key; alias в `_flags` не попадает.
2. `has_flag/get_flag/clear_flag/require` читают alias через `canonical_flag()`.
3. `snapshot()` содержит только canonical keys; aliases не дублируются.
4. `restore()` канонизирует ключи; если в снимке есть и alias, и canonical, побеждает canonical.
5. `flag_changed` эмитит canonical name. Старые слушатели, которым нужен alias, получают состояние через `has_flag(alias)`.
6. `jet` — **не флаг**, а speaker alias: см. A04-12. `technician` — speaker alias для `medic`, не флаг.
7. Никаких wildcard-алиасов (`black_sea_*`); только явные пары.

**Acceptance:** unit-тест на set/get/clear/require/snapshot/restore; old save с alias читается; новый snapshot не содержит alias; двойной write не создаёт два флага.

### 4.2. `start_quest_id` и мировые адаптеры

**Файлы:** `scripts/quests/quest_npc.gd`, `quest_pickup.gd`, `quest_trigger_zone.gd` (A04)

Текущий порядок (факт):

| Адаптер | Порядок | Статус |
|---|---|---|
| `QuestNpc` | `start_quest` → dialogue → `completion_flag` → `notify_event(talked)` → signals | OK |
| `QuestPickup` | grant → `pickup_flag` → `start_quest` → `notify_event` → `picked_up` | OK |
| `QuestTriggerZone` | `set_flag` → `start_quest` → `notify_event` | OK |

**Правила:**

1. `start_quest_id` задаётся **на мировом объекте**, не в `QuestDefinition`.
2. Для `auto_start=false` `start_quest` обязателен до `notify_event`; иначе первый контакт не засчитается.
3. Если `start_quest` вернул `false` (нет квеста/scope/prerequisite), `notify_event` не должен создавать прогресс; объект не должен выдавать награду дважды.
4. Повторный контакт не дублирует `start_quest`, reward, flag; one-shot — на объекте, не в state.
5. **Код не менять, если тест подтверждает порядок.** Задача A04-04 — regression contract, а не новый API.

**Acceptance:** synthetic `auto_start=false` quest; первый клик стартует и засчитывает; второй клик не меняет прогресс; все три адаптера; `start_quest` fail не двигает цель.

### 4.3. `QuestInspectable`

**Файл:** `scripts/inspect/quest_inspectable.gd` (A04)  
**Наследование:** `class_name QuestInspectable extends Interactable`  
**Не** заменяет `Inspectable` (подсветка/чутьё); они могут сосуществовать на одном объекте.

```gdscript
signal inspected(id: StringName)

@export var required_flags: Array[StringName] = []
@export var completion_flag: StringName
@export var quest_event: StringName = &"interacted"
@export var quest_subject: StringName
@export var start_quest_id: StringName
@export var one_shot := true
```

**Порядок `interact()`:**

1. `require(required_flags)`; при false — ничего.
2. `start_quest_id` (если задан).
3. `super.interact()` — общий audio/`interacted` существующего `Interactable`.
4. `completion_flag` (если задан).
5. `notify_event(quest_event, quest_subject)` (если subject задан).
6. `inspected.emit(interaction_id)`.
7. При `one_shot` — `enabled = false`, объект остаётся видимым.

**Правила:**

- `can_interact_from()` = `super` && not completed && `NightmareRunState.require(required_flags)`.
- `_ready()` вызывает `super._ready()`, добавляет группу, проверяет `completion_flag` для восстановления после save.
- Не создаёт второй Inspectable framework; не заменяет `Inspectable`.
- Для улик SQ объект остаётся в мире; one-shot означает «событие один раз», не «удалить объект».
- M1: зеркало (`p05_mirror_seen`) и Плащ (`shroud_summoned`) могут использовать `completion_flag` без `quest_event`.
- A03 размещает компонент; A04 не правит `scripts/locations/**`.

**Acceptance:** synthetic node; required flag blocks; completion flag disables; event order; repeat no duplicate; old save disables; no second framework.

### 4.4. Choice backend + UI contract

**Проблема:** `DialogueRunner` линейный; SQ-03 требует 3 правдивых варианта и заблокированную ложь. UI принадлежит A08, backend — A04. Нельзя создавать второй dialogue engine.

**Provisional A04 backend:** `scripts/quests/quest_choice_controller.gd`

```gdscript
class_name QuestChoiceController extends Node

signal presentation_requested(prompt: String, choices: Array[Dictionary])
signal choice_selected(choice_id: StringName)
signal closed

func present(prompt: String, choices: Array[Dictionary]) -> bool
func select(choice_id: StringName) -> bool
func close() -> void
```

`choices[i]`:

```gdscript
{
    "id": StringName,
    "text": String,
    "flag": StringName,             # optional
    "quest_event": StringName,      # optional
    "quest_subject": StringName,    # optional
    "enabled": bool,                # optional, default true
    "locked_reason": String,        # optional
}
```

**A08 UI contract (provisional):**

```gdscript
class_name QuestChoicePanel extends CanvasLayer
signal choice_selected(choice_id: StringName)
func show_choices(prompt: String, choices: Array[Dictionary]) -> void
func close() -> void
```

**Правила:**

1. UI только показывает и эмитит `choice_selected`; **не** вызывает `NightmareRunState.set_flag` и `QuestSystem.notify_event`.
2. Controller валидирует активный выбор, id, `enabled`; пишет флаг; вызывает `notify_event`; эмитит сигнал; закрывает.
3. `flag` и `quest_event` применяются один раз; повторный `select` возвращает false.
4. SQ-03: `TheoReturn` сначала проигрывает диалог; choice-узел слушает `dialogue_finished`; `sq_fs_03_resolved` ставится после диалога.
5. Не менять `DialogueRunner`; не добавлять ветвление в `DialogueSequence`.
6. Контракт `QuestChoicePanel` из `INTEGRATION_CONTRACTS` требует DP-1.1, если TD утвердит переименование backend (D-03).

**Acceptance:** 3 choices; signal; flag; repeat no-op; locked choice cannot select; UI does not call QuestSystem; pause/input restored; no second dialogue engine.

### 4.5. Tide: `QuestTideLock`, `QuestTideWait`, A03 API

**Критическое расхождение:** текущий `TideController.get_level()` возвращает **нормализованный 0…1**, а `INTEGRATION_CONTRACTS` использует `max_level := -1.0` (мировые метры). Это нельзя реализовать буквально.

**Предлагаемый контракт (D-04):**

A03 добавляет в `TideController` аддитивно:

```gdscript
func get_water_y() -> float          # мировая Y воды
func advance_to_low() -> bool        # к следующему отливу; false, если уже низкая/идёт переход
func advance_to_high() -> bool       # к следующему приливу; false, если уже высокая/идёт переход
```

`get_level()` остаётся нормализованным для HUD. `advance_*` меняет фазу существующего контроллера, не создаёт таймер. Запрет «во время боя» — отдельное правило `QuestTideWait`: если A05 не даёт публичного `is_in_combat`, это **NOT TESTED/optional**, а не скрытая зависимость от второго контроллера.

**A04 `QuestTideLock`:** `scripts/quests/quest_tide_lock.gd`

```gdscript
class_name QuestTideLock extends Interactable

@export var tide_controller: Node3D
@export var max_water_y := -1.0
@export var quest_id: StringName
@export var start_quest_id: StringName
@export var completion_flag: StringName
@export var quest_event: StringName = &"interacted"
@export var quest_subject: StringName
@export var blocked_prompt := "Вода слишком высока. Соль разбухла."
@export var one_shot := true
```

**Поведение:**

1. `_ready()`: `super._ready()`, resolve `tide_controller` by group `tide_controller` если null.
2. `is_tide_ready()`: false, если контроллер/метод недоступен; иначе `get_water_y() <= max_water_y`.
3. `can_interact_from()` проверяет `enabled`, `one_shot`/completed, `required_flags`; **не** проверяет воду, чтобы показать blocked prompt.
4. `interact()`: если вода высокая — `QuestSystem.show_message(blocked_prompt, &"warning")`, без прогресса/флага; иначе order: `start_quest` → `super.interact()` (audio/signal) → `completion_flag` → `notify_event` → disable if one-shot.
5. `quest_id` — только для проверки активного квеста; не запускать второй `QuestSystem`.
6. Если A03 не добавит `get_water_y`, fallback — `get_level()` с нормализованным `max_level` (0…1), но это **не** соответствует SQ-04 «ниже −1,0»; D-04.

**`QuestTideWait`:** отдельный маленький `Interactable` (A04), exports `tide_controller`, `target` (`low`/`high`), `prompt`; вызывает `advance_to_low/high`; не лечит, не сохраняет, не создаёт второй контроллер. Не входит в M1, P2.

**Acceptance:** box at high water -> message, no flag/progress; at low -> opens once; wait advances low/high; second wait no duplicate; no second timer; no soft-lock.

### 4.6. `QuestFinaleZone` и финальный поток

**Проблема:** M1 final и tech demo final не должны быть двумя сценами; `ToWest` нельзя использовать как финал. A03 создаёт узлы, A04 — логику.

**A04 component:** `scripts/world/quest_finale_zone.gd`

```gdscript
class_name QuestFinaleZone extends Area3D

enum Mode { M1, TECH_DEMO }
signal finale_reached(mode: Mode, completion_flag: StringName)

@export var mode: Mode = Mode.M1
@export var required_flags: Array[StringName] = []
@export var completion_flag: StringName = &"post_nightmare_demo_completed"
@export_file("*.tscn") var finale_scene := "res://scenes/campaign/post_nightmare_finale.tscn"
@export var one_shot := true
@export var player_group: StringName = &"player"
```

**M1:** `mode = M1`, `completion_flag = post_nightmare_demo_completed`, `required_flags = [shore_first_day_complete, camp_night_seen]` (D-05).  
**Tech:** `mode = TECH_DEMO`, `completion_flag = post_nightmare_completed`, `required_flags = []` (или утверждённый gate).

**Порядок:**

1. `_ready()`: настроить Area3D, подключить `body_entered/body_exited`, `flag_changed`; если флаг уже стоит — `_finished = true`.
2. `_can_finish()`:
   - M1: `not demo_mode_full` && все `required_flags` && нет completion flag;
   - TECH: `demo_mode_full` && все `required_flags` && нет completion flag.
3. `_finish()` один раз:
   - `QuestSystem.deactivate_scope()`;
   - `CampaignGuide.clear_external_objective()` (без source — очищает и `quest_system`, и `post_nightmare`);
   - `NightmareRunState.set_flag(completion_flag)`;
   - `finale_reached.emit(...)`;
   - `get_tree().change_scene_to_file(finale_scene)`.
4. Не сохранять здесь: `post_nightmare_finale` сохранит после загрузки, чтобы scene в сейве была финальной карточкой (D-08).
5. A03 ставит `DemoEndZone` в `POI-Z10-09` (`-100,18.2,-5`, radius 4) и `FinalZone` в `POI-Z18-05` (`-1410,35.2,0`, radius 4). A04 не правит сцену.

**`post_nightmare_finale.gd` mode branch:**

```gdscript
func _is_m1() -> bool:
    if NightmareRunState.has_flag(&"demo_mode_full"):
        return false
    if NightmareRunState.has_flag(&"post_nightmare_demo_completed"):
        return true
    if NightmareRunState.has_flag(&"post_nightmare_completed"):
        return false
    return false # legacy/direct launch: сохранить текущее tech-поведение
```

1. `_ready()` ставит **один** флаг: M1 -> `post_nightmare_demo_completed`, tech -> `post_nightmare_completed`; идемпотентно.
2. `SaveSystem.save_game("finale")` — только вне headless; после установки флага. Вызов делать `call_deferred`, чтобы `SceneTree.current_scene` уже указывал на `post_nightmare_finale` и в сейв попала правильная сцена.
3. Карточка/текст — A08-04; A04 script может выставить `is_m1`/`title` property.
4. `R`/`Esc` -> main menu; без второго final scene.
5. Прямой запуск без флагов сохраняет legacy tech (нужно для старого теста A10 до его обновления).

**Acceptance:**

- M1: Z10 срабатывает один раз, только после `shore_first_day_complete` + `camp_night_seen`; ставит M1 flag; не ставит tech flag; очищает guide; scope пуст; карточка «ПЕРВЫЙ ДЕНЬ»; возврат в меню.
- Tech: Z18 срабатывает только при `demo_mode_full`; ставит tech flag; M1 не затронут; `ToWest` выключен A03.
- Save: после карточки сцена = `post_nightmare_finale`; загрузка возвращает карточку; нет soft-lock.
- No duplicate: повторный вход/повторный `_ready` не дублирует флаг/карточку.

### 4.7. Map flags contract

**Файлы A04:** `scripts/map/map_definition.gd`, `scripts/map/map_marker.gd` (менять не планируется).  
**Файл A08:** `scripts/ui/map/map_screen.gd` (UI-фикс).

Контракт:

1. `MapDefinition.visible_markers(flags)` возвращает только `MapMarker.is_visible_with(flags)`.
2. `flags` — `NightmareRunState.snapshot().flags`, не `{}` и не ad-hoc Dictionary.
3. `hide_when_flag` имеет приоритет над `show_when_flag`.
4. `MapScreen`/`RpgMapScreen`/`MapCanvas` используют один и тот же contract; UI не дублирует фильтрацию.
5. A04 не правит `scripts/ui/**`; A08-03 исправляет `MapScreen._build_marker_list()` и добавляет тест.

**Acceptance:** hidden marker not in `visible_markers`; not in `MapScreen` list; objective marker hidden after flag; visible marker present; flags from live state.

### 4.8. Save/load

**Файл:** `scripts/systems/save_system.gd` (A04; shared claim A00)

Существующий payload не меняется по структуре; `run_state` — `NightmareRunState.snapshot()`.

**Требования:**

1. F5/F9 actions не зависят от `project.godot`; `_ensure_input_actions()` уже добавляет.
2. `load_game()`: сначала `NightmareRunState.restore`, затем scene/position; не создавать второй state.
3. Канонические flags в snapshot; aliases читаются при restore.
4. Финальная карточка вызывает `save_game("finale")` отложенно (`call_deferred`), когда `current_scene` уже = `post_nightmare_finale`; загрузка возвращает карточку.
5. Если в сцене нет player (final card), `_apply_pending()` должен очистить pending и не зависать.
6. `QuestSystem` после restore: scope не активируется сам; его активирует сцена B03; `deactivate_scope` на финале/выходе.
7. Никаких ручных слотов/миграций/второго save в M1.
8. Headless: save может быть пропущен; тест не должен требовать файл.

**Acceptance:** F5 in P05 -> load in P08 -> flags/quests/position restored; F5 in B03 -> load -> scope forgotten_shore; final card saves correct flag; corrupt save fails; no duplicate reward; live test A10-04.

### 4.9. Dialogue speaker names

**Файл:** `scripts/dialogue/dialogue_runner.gd` (A04)

Canonical:

| ID | Display |
|---|---|
| `jett` | Джет |
| `rock` | Рок |
| `kasper` | Каспер |
| `cassia` | Кассия |
| `medic` | Медик |
| `theo` | Тео |

Legacy aliases (read-only display):

- `jet` -> Джет
- `technician` -> Медик
- `julius` -> Джулиус (M2, не удалять до M2)
- `lissa_echo` -> Эхо Лиссы (если A01 подтвердит; иначе не добавлять)

Не дублировать canonical keys; alias не создаёт второй speaker. A01-10 — источник имён; A04-12 — реализация.

**Acceptance:** `display_name(&"jett") == "Джет"`, `display_name(&"jet") == "Джет"`, `display_name(&"rock") == "Рок"`, `display_name(&"technician") == "Медик"`, no raw IDs in subtitles, no duplicate keys.

### 4.10. LevelPortal gates

**Файл:** `scripts/world/level_portal.gd` (A04; shared claim A00).  
**Сцены:** A03.

Текущий `LevelPortal` уже умеет `required_flags`, `set_flags_on_use`, `one_shot`, `one_shot_flag`, `enabled`.  
**Планируемая правка A04-02:** добавить обработку `body_exited` и повторную проверку `is_available()` при `flag_changed`, если игрок уже находится в зоне. Это закрывает случай «дверь открылась диалогом, игрок стоит в проёме, `body_entered` уже не придёт».

**Правила:**

1. `required_flags` — canonical only; alias читается через state.
2. `set_flags_on_use` — canonical only; idempotent.
3. Повторный вход/повторный `activate()` не дублирует flags/сцену.
4. `one_shot_flag` не даёт повторно открыть дверь после save.
5. A04 не редактирует `.tscn`; A03 выставляет значения.

**Acceptance:** каждый портал P05–B02 требует канонический флаг; missing flag -> `transition_aborted`; повторный вход не ломает; флаг, выставленный при игроке в зоне, запускает переход; scene destination/spawn верны.

---

## 5. Файлы, ресурсы, инструменты

### 5.1. Файлы A04-ветки

| Путь | Действие | Владелец | Примечание |
|---|---|---|---|
| `scripts/campaign/nightmare_run_state.gd` | modify | A04 | alias layer; shared claim |
| `scripts/systems/save_system.gd` | modify | A04 | final save/pending; shared claim |
| `scripts/dialogue/dialogue_runner.gd` | modify | A04 | speaker names |
| `scripts/world/level_portal.gd` | modify | A04 | flag recheck; shared claim |
| `scripts/campaign/post_nightmare_finale.gd` | modify | A04 | mode branch/flag/save |
| `scripts/inspect/quest_inspectable.gd` | new | A04 | M1 + SQ |
| `scripts/quests/quest_choice_controller.gd` | new (provisional) | A04 | M3 |
| `scripts/quests/quest_tide_lock.gd` | new | A04 | M3/P2 |
| `scripts/quests/quest_tide_wait.gd` | new | A04 | M3/P2 |
| `scripts/world/quest_finale_zone.gd` | new | A04 | M1/tech |
| `docs/demo_sprint/implementation/gameplay_quest_systems_implementation.md` | new | A04 | этот документ |
| `docs/demo_sprint/design/gameplay_architecture.md` | update after TD | A04 | только A04-раздел |
| `docs/demo_sprint/audits/04_gameplay_quest_systems.md` | update after tests | A04 | факты, не чужие отчёты |

### 5.2. Shared files: только через A00 claim

| Файл | Почему shared | Кто просит |
|---|---|---|
| `project.godot` | autoload/input/rendering | A00 only; A04 не меняет |
| `scenes/locations/**` | `DemoEndZone`/`FinalZone`, portal values | A03 |
| `scripts/locations/**` | `TideController.advance_*`, `get_water_y` | A03 |
| `scenes/ui/**`, `scripts/ui/**` | choice UI, MapScreen fix, final card | A08 |
| `resources/dialogue/**` | SQ dialogue/presentation | A01/A02 |
| `tests/**` | contract tests | A10 |
| `scenes/campaign/post_nightmare_finale.tscn` | final card scene | A04 + A08 claim |
| `resources/quests/quest_catalog.tres` | SQ entries | A04 + A02; M3 only |

### 5.3. Ресурсы

| Ресурс | Нужен? | Действие |
|---|---|---|
| Новые текстуры/модели/аудио | Нет | A04 не импортирует ассеты |
| `resources/quests/*.tres` | M1 — нет; M3 — A02 | A04 только catalog entries |
| `resources/map/locations/labyrinth_first_fragment.tres` | M3 markers | A03/A02; A04 не правит |
| `resources/dialogue/**` | M1/M3 | A01; A04 не правит |
| `resources/inspect/**` | Не требуется | `QuestInspectable` конфигурируется сценой |
| Новые сцены | M1 — нет; M3 — choice UI A08 | Не создавать второй final/quest scene |
| Новые autoload | Нет | Запрещено |

### 5.4. Инструменты

| Инструмент | Использование |
|---|---|
| Godot 4.7.2 (`godot`) | headless import, GUT, runtime manual |
| GUT (`addons/gut`) | targeted unit/integration tests |
| Git | branch/diff/status; commit only A00 |
| PowerShell | команды запуска; без абсолютных путей в документах |
| MCP Godot/Blender | **не обязателен**; MCP runtime helper нестабилен; для A04 достаточно headless GUT |
| Blender/Materialize/Krita | не используются |

---

## 6. Зависимости и интеграция

### 6.1. Внутри A04

| Зависимость | Влияние |
|---|---|
| A04-01 -> A04-02/03/08/09/10/11 | canonical flags до порталов, scope, save, map, final |
| A04-03 -> A04-04/05 | scope active до `start_quest_id`/inspectable |
| A04-08 -> A04-10/11 | save до финального flow |
| A04-12 -> A04-03 | speaker names не блокируют, но нужны до M1 gate |

### 6.2. Кросс-специалисты

| Агент | Что нужно | Когда |
|---|---|---|
| A00 | Утвердить DP-1.0, A04-ветку, claims; `demo_mode_full`; `post_nightmare_finale.tscn` shared claim; test ownership rule | До старта |
| A01 | Speaker names (`jett`, `rock`, `kasper`, `theo`, `medic`), `camp_night_seen`, B03 camp night dialogue, mirror/shroud flags | M1 |
| A02 | SQ `.tres`, `labyrinth_narrative_director.gd`, SQ inspectable/tide/choice placement | M3 |
| A03 | Portal values, `DemoEndZone`/`FinalZone`, `QuestInspectable`/`QuestTideLock` nodes, `TideController.advance_*`/`get_water_y`, disable `ToWest`, map markers | M1/M3 |
| A05 | Kill events for `QuestKillCredit`; no changes to A04 | M1/M3 |
| A08 | Choice UI, `MapScreen` flags fix, final cards/text, HUD | M1/M3 |
| A09 | Audio cues for interaction/final (no A04 code) | M1/M3 |
| A10 | Contract/regression tests, live save/load, route/reachability | M1 gate |

### 6.3. Интеграционные точки

| Точка | Контракт |
|---|---|
| P05–B02 -> B03 | `LevelPortal` flags; `QuestSystem.active_scope == ""` до B03 |
| B03 -> final | `QuestFinaleZone` -> `post_nightmare_finale`; flags; clear guide; deactivate scope |
| Quest -> HUD | signals + `CampaignGuide.set_external_objective`; UI only reads |
| Choice -> Quest | `choice_selected` -> controller -> flags/`notify_event`; UI not state |
| Tide -> Quest | `get_water_y`/`advance_*` -> `QuestTideLock/Wait`; no second timer |
| Map -> state | `snapshot().flags` -> `visible_markers`; A08 wiring |

---

## 7. Список задач

### 7.1. Основная таблица

| Task ID | Description | Files | Dependencies | Priority | Acceptance Criteria |
|---|---|---|---|---|---|
| **A04-01** | Canonical flags + aliases; canonical-only writes; restore old saves; `jet` remains speaker alias | `scripts/campaign/nightmare_run_state.gd` | A00-03 | P0 | canonical-only snapshot; aliases read; no double write; old save restores; tests |
| **A04-02** | Portal gates P05–B02; `body_exited` + flag recheck; required/set flags idempotent; no scene edits | `scripts/world/level_portal.gd`; scenes A03 | A03-01…07 | P0 | each portal requires canonical flag; detail recheck; repeat no duplicate; missing flag aborts |
| **A04-03** | Scope isolation: `active_scope==""` in P05–B02/S00–S15; B03 activates; final deactivates | `scripts/quests/quest_system.gd`; `quest_finale_zone.gd` | A04-01, A03-08 | P0 | P05–B02 no quests/HUD; B03 forgotten_shore; leave/final empty |
| **A04-04** | Verify `start_quest_id` in NPC/pickup/trigger; order start → notify; test auto_start=false | `quest_npc.gd`, `quest_pickup.gd`, `quest_trigger_zone.gd` (only if bug); A10 test | A00-03, A04-03 | P0 | first contact counts; repeat no duplicate; failed start no progress; 3 adapters |
| **A04-05** | `QuestInspectable` additive Interactable; flags/event/start/completion; mirror/shroud/clues | new `scripts/inspect/quest_inspectable.gd`; A03 nodes | A03-01, A03-06 | P0 | required flag blocks; completion one-shot; order; no duplicate Inspectable |
| **A04-06** | Choice backend; 3 choices; flag/event; no dialogue engine; UI A08 | new `scripts/quests/quest_choice_controller.gd`; A08 UI | A08-02, A02-03 | P1 | 3 choices; locked; flag once; UI no state writes; pause restored |
| **A04-07** | `QuestTideLock` + `QuestTideWait`; A03 `get_water_y`/`advance_*`; no second timer | new `quest_tide_lock.gd`, `quest_tide_wait.gd`; A03 tide | A03-07, A02-04, D-04 | P2 | high water blocked message; low opens once; wait advances; no duplicate; no soft-lock |
| **A04-08** | Save/load F5/F9; snapshot/restore; final save; no-player pending cleanup | `scripts/systems/save_system.gd`, `nightmare_run_state.gd` | A04-01, A10-04 | P0 | live different-scene load; flags/quests/checkpoint; final card; corrupt fail |
| **A04-09** | Map flags contract; `visible_markers`/`hide_when_flag`; snapshot flags; A08 UI fix | `scripts/map/map_definition.gd`, `map_marker.gd`; A08 `map_screen.gd` | A04-01, A08-03 | P0 | hidden not visible; list and canvas agree; live flags; no A04 UI edit |
| **A04-10** | M1 final: `QuestFinaleZone`; Z10; `post_nightmare_demo_completed`; clear guide; deactivate scope; save; one-shot | new `scripts/world/quest_finale_zone.gd`; `post_nightmare_finale.gd`; A03 Z10 | A03-08, A01-08, A08-04 | P0 | only after first_day + camp_night; one flag; no tech flag; card once; no soft-lock |
| **A04-11** | Tech demo final: Z18 `FinalZone`; `post_nightmare_completed`; `demo_mode_full`; return menu | `quest_finale_zone.gd`, `post_nightmare_finale.gd`; A03 Z18 | A00-08, A03-10, A08-04 | P1 | Z18 only full mode; flag separate; M1 unaffected; ToWest disabled; card once |
| **A04-12** | Canonical speaker names + legacy aliases; no duplicates | `scripts/dialogue/dialogue_runner.gd` | A01-10, A04-01 | P0 | jett/rock/kasper/cassia/medic/theo; jet/technician aliases; no raw IDs |

### 7.2. Трудоёмкость и риск

| Task | Effort (dev-days) | Risk | Причина |
|---|---:|---|---|
| A04-01 | 1.0–1.5 | M | broad state change; old saves/aliases |
| A04-02 | 0.5–1.0 | L/M | mostly A03 scene values; flag recheck |
| A04-03 | 0.5 | L | verification; no expected code |
| A04-04 | 0.5 | L | code already correct; test fixture |
| A04-05 | 1.0–1.5 | M | new component + scene placement dependency |
| A04-06 | 1.0–1.5 | M | contract split/UI dependency |
| A04-07 | 1.5–2.0 | H | tide API/threshold/ownership |
| A04-08 | 1.0–1.5 | M | live scene/position/final save |
| A04-09 | 0.25–0.5 | L | API exists; UI separated |
| A04-10 | 1.5–2.0 | H | mode/flags/save/guide/scene |
| A04-11 | 0.5–1.0 | M | same component; A03/A08 |
| A04-12 | 0.25 | L | dictionary only |
| **Итого A04** | **9–13.5** | — | без A03/A08/A10 работ |

### 7.3. Детализация задач

#### A04-01 — Canonical flags and aliases

**Goal:** один canonical flag в state; старые имена читаются, но не пишутся.

**Implementation:**

1. Add `FLAG_ALIASES` constant and `canonical_flag()`.
2. Route `set_flag/clear_flag/has_flag/get_flag` through it.
3. Canonicalize `restore()` keys; prevent duplicate alias/canonical.
4. Keep `snapshot()` canonical-only.
5. Add doc comment and tests in A10.
6. Verify `precinct_mirror_seen`/`black_sea_*` call sites still work via aliases; A03 migrates to canonical.

**Do not:** add alias keys to `_flags`, emit alias events, touch `QuestSystem` reward logic, or add new global flags.

**Risk:** old snapshot with alias + canonical; canonical must win. Existing scenes use aliases; verify flag_changed consumers only need canonical.

#### A04-02 — Portal gates

**Goal:** no soft-lock when a portal opens while player stands in it.

**Implementation:**

1. Track `_player_inside` on `body_entered/body_exited`.
2. Connect `NightmareRunState.flag_changed`; on change, if inside and `is_available()`, call `activate`.
3. Keep existing `required_flags` / `set_flags_on_use`; no new portal class.
4. A03 sets canonical values in scenes; A04 verifies all 13 portals.
5. A10 test: enter disabled portal, set flag, transition; repeat no duplicate.

**Risk:** re-entrancy/transition loop; use `_running` guard and `_ignore_body_until_frame`.

#### A04-03 — Scope isolation

**Goal:** `QuestSystem` never hijacks P05–B02 or S00–S15 objectives.

**Implementation:**

1. Verify only `LabyrinthQuestDirector._build()` calls `activate_scope`.
2. `deactivate_scope()` on `_exit_tree` already; verify final zone also calls it.
3. If test shows leak, fix only `quest_system.gd` (e.g. reset scope on `state_reset`), not A03 scene.
4. A10 test scene loads P05/B02/S00 with no quests; B03 active; leave B03 empty.

**Risk:** `_exit_tree` ordering on scene change; final zone explicit deactivation is the safety net.

#### A04-04 — `start_quest_id` regression contract

**Goal:** prove existing order; no new field.

**Implementation:**

1. No production change unless test fails.
2. A10 fixture creates a temporary `QuestDefinition` with `auto_start=false`, `show_available=false`, and a world adapter.
3. Assert first `interact`/`fire` starts and progresses; second no-op.
4. Run all three adapters with `start_quest_id` set; assert `notify_event` after start.
5. If `start_quest` fails, assert progress unchanged and no reward.

**Risk:** test fixture mutating global catalog; isolate/restore `QuestSystem` state, use `NightmareRunState.reset()` and `deactivate_scope()`.

#### A04-05 — `QuestInspectable`

**Goal:** clues/mirror/shroud trigger quest events without replacing `Inspectable`.

**Implementation:**

1. New script as §4.3.
2. A03 adds to `InterrogationMirror`, `PuppeteerShroud`, SQ traces; sets `required_flags`, `completion_flag`, `quest_event`, `quest_subject`.
3. M1 mirror: `completion_flag=p05_mirror_seen`, no start.
4. M1 shroud: `completion_flag=shroud_summoned`, no start.
5. SQ: `start_quest_id=sq_fs_01_ninth_token` etc.; `quest_event=interacted`.
6. A10 tests synthetic + scene presence.

**Risk:** `Interactable` audio emits before event; harmless if order of quest state is correct. Do not subclass `Inspectable` and create second highlight framework.

#### A04-06 — Choice backend

**Goal:** SQ-03 choice without touching `DialogueRunner`.

**Implementation:**

1. New controller script; `present/select/close`; choices validation.
2. A08 panel connects signals; UI only.
3. A02/A01 place choice after `TheoReturn` dialogue.
4. Flag/event exactly once; `sq_fs_03_resolved` from choice.
5. A10/ A08 test UI focus/pause; A04 test controller state.

**Risk:** ownership/contract mismatch. If TD rejects split, fallback is A04-owned `QuestChoicePanel` node under `scripts/quests/**` and A08 supplies child UI; do not duplicate.

#### A04-07 — Tide lock and wait

**Goal:** SQ-04/SQ-05 tide interactions without a second timer.

**Implementation:**

1. A03 adds `get_water_y` and `advance_to_low/high` to existing `TideController`.
2. A04 adds `QuestTideLock`/`QuestTideWait`.
3. A02 places box/levers/wait; A03 places nodes.
4. A10 tests high/low, repeat, save/restore.

**Risk:** threshold mismatch (normalized vs world). Do not ship `max_level=-1.0` against normalized `get_level`; it would always pass.

#### A04-08 — Save/load

**Goal:** live F5/F9 and final save.

**Implementation:**

1. Keep one slot/format; canonical flags.
2. Add no-player pending cleanup.
3. Add final card save (`post_nightmare_finale`), skip headless.
4. A10 live test across P05 → P08 and B03; final card load.
5. Document `NOT TESTED` until A10 proves.

**Risk:** saving in final card with no player; ensure state/scene load works; don't save twice per frame.

#### A04-09 — Map flags

**Goal:** API contract + test; UI fix A08.

**Implementation:**

1. No code change expected in `MapDefinition`/`MapMarker`.
2. A10 test `visible_markers` with `show_when_flag`/`hide_when_flag` and live snapshot.
3. A08 fixes `MapScreen._build_marker_list()` to use `_game_flags()`; A04 reviews contract only.
4. No new MapDefinition / MapMarker / MapScreen.

**Risk:** UI audit claims fix; code says otherwise. Verify with actual scene test.

#### A04-10 — M1 final

**Goal:** one-shot M1 final with correct flags and no soft-lock.

**Implementation:**

1. New `QuestFinaleZone`.
2. A03 adds `DemoEndZone` at POI-Z10-09; A04 does not edit scene.
3. A01-08 sets `camp_night_seen` after camp dialogue; A03/A08 sequence.
4. `post_nightmare_finale.gd` mode branch.
5. A08 card text; A10 test; A04 save.
6. Verify: enter before flags -> no trigger; set flags inside -> trigger; second entry no trigger; guide clear; scope empty; save card.

**Risk:** premature final, double final, wrong flag, test break. Strict flags + legacy fallback.

#### A04-11 — Tech demo final

**Goal:** Z18 final only in full mode.

**Implementation:**

1. Same `QuestFinaleZone` `mode=TECH_DEMO`; A03 adds `FinalZone` at POI-Z18-05.
2. `demo_mode_full` set by A00/A08; A04 reads.
3. Disable `Portals/ToWest` (A03); test update A10.
4. `post_nightmare_finale` tech flag; M1 unaffected.
5. A10 test mode matrix.

**Risk:** direct portal bypass; test expecting enabled `ToWest`; mode flag unset.

#### A04-12 — Speaker names

**Goal:** canonical display names and legacy aliases.

**Implementation:**

1. Update dictionary as §4.9.
2. Keep `julius` until M2.
3. A01 confirms `lissa_echo`/`technician`.
4. A10 test `display_name`.

**Risk:** duplicate display names are acceptable for aliases; duplicate keys are not. No raw IDs.

---

## 8. Риски и конфликты

| ID | Риск | Вероятность | Влияние | Смягчение | Владелец |
|---|---|---|---|---|---|
| R-01 | `get_level` normalized vs `max_level -1.0` | Высокая | SQ-04 всегда открыта/закрыта неверно | D-04; `get_water_y`; fallback threshold | A03/A04 |
| R-02 | `QuestChoicePanel` ownership | Высокая | duplicate UI/framework или blocked M3 | D-03; backend/UI split | A04/A08 |
| R-03 | `demo_end_zone.gd` ownership | Высокая | A04 blocked or A03 game logic | D-02; `quest_finale_zone.gd` A04 | A03/A04 |
| R-04 | `post_nightmare_finale` shared A04/A08 | Средняя | conflicting edits | D-07; A04 script, A08 shared claim | A04/A08 |
| R-05 | M1 final prerequisite undefined | Высокая | premature final / unreachable final | D-05; require `camp_night_seen` | A00/A01/A04 |
| R-06 | `demo_mode_full` nowhere set | Высокая | tech demo unreachable or M1 final disabled | D-06; A00/A08 | A00/A08 |
| R-07 | Save final card has no player | Средняя | load hangs/fails | pending cleanup; A10 live | A04/A10 |
| R-08 | Old tests expect tech flag/ToWest | Высокая | red GUT after M1 change | A10 test updates; legacy fallback | A10 |
| R-09 | Alias double-write | Средняя | state inconsistency/old saves | canonical-only; restore dedupe | A04 |
| R-10 | `QuestInspectable` becomes second inspect framework | Средняя | duplicate logic | extends `Interactable`; coexist with `Inspectable` | A04 |
| R-11 | `LevelPortal` flag recheck loops | Низкая | scene reload loop | `_running` guard; one-shot; A10 test | A04 |
| R-12 | Scope leak P05–B02 | Низкая | wrong objective/quests | A04-03 test; deactivate on exit/final | A04/A03 |
| R-13 | `QuestSystem` catalog 7 vs SQ 12 | Средняя (M3) | test failure | A02/A10 update; not M1 | A02/A10 |
| R-14 | `MapScreen` list bug persists | Средняя | hidden markers listed | A08-03; A04 contract test | A08 |
| R-15 | `active_scope` not saved | Низкая | quests inactive on load | scene activates; A10 live | A04 |
| R-16 | Subagent/cross-chat edits while A04 works | Высокая | conflicting files | TD freeze, claims, branch isolation | A00 |

---

## 9. Проверка готовности

### 9.1. Текущее доказательство (на момент аудита)

| Проверка | Результат | Статус |
|---|---|---|
| `test_quest_system` | 9/9, 63 assert | PASS (audit) |
| `test_labyrinth_quest_content` | 4/4, 41 assert | PASS (audit) |
| `test_save_system` | 2/2, 14 assert | PASS (unit) |
| `test_map_system` | 22/22, 836 assert | PASS (audit) |
| `test_labyrinth_first_fragment` | 13/13 isolated; live tree had external animation issues | PARTIAL / NOT RE-RUN |
| Full GUT | 602/619 live tree (external animation/VFX) | NOT GREEN |
| Manual/full route | — | **NOT TESTED** |
| Live F5/F9 | — | **NOT TESTED** |
| Export build | — | **NOT TESTED** |

> В этой задаче Stage 2 тесты не перезапускались; приведены факты из аудита. Нельзя писать «PASS» для того, что не запускалось.

### 9.2. Команды

```powershell
godot --headless --path . --import

godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_quest_system.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_labyrinth_quest_content.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_system.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_map_system.gd -gexit

# planned A10 tests, names to be confirmed by A10
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_quest_extensions.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_gameplay_finale.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_map_flags_contract.gd -gexit

godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

### 9.3. Матрица проверок по задачам

| Task | Unit | Scene/integration | Manual |
|---|---|---|---|
| A04-01 | aliases, snapshot, restore | old flag call sites | old save |
| A04-02 | portal flag recheck | P05–B02 portal matrix | walk through each |
| A04-03 | scope empty/B03 | load P05/B03/final | no HUD hijack |
| A04-04 | synthetic auto_start=false | 3 adapters | first click |
| A04-05 | inspectable order | mirror/shroud/clue nodes | E prompt |
| A04-06 | controller/flag | SQ-03 scene | 3 choices |
| A04-07 | tide threshold | Z11 box/levers | high/low/ wait |
| A04-08 | save/restore | cross-scene | F5/F9 live |
| A04-09 | visible_markers | MapScreen/RpgMapScreen | hidden marker |
| A04-10 | final flags/one-shot | Z10 | full M1 |
| A04-11 | mode matrix | Z18 | tech demo |
| A04-12 | display_name | subtitles | dialogue |

### 9.4. M1 gate для A04

- [ ] P05–B02: `QuestSystem.active_scope == &""`; objectives from `CampaignGuide`.
- [ ] B03: scope `forgotten_shore`; 7 quests catalog; 4 M1 quests complete; `crystal_cache` non-blocking.
- [ ] `start_quest_id` first-contact order verified for all 3 adapters.
- [ ] mirror/shroud `QuestInspectable` flags set once.
- [ ] portals require/set canonical flags; no soft-lock.
- [ ] F5/F9 live in another scene; flags/quests/checkpoint survive.
- [ ] map hidden markers not visible; flags from state.
- [ ] M1 final once after `first_day` + `camp_night_seen`; M1 flag; guide clear; scope empty; card; menu.
- [ ] Tech flag not set in M1; `ToWest` disabled.
- [ ] Full GUT 0 fail (A10/A00).
- [ ] Manual pass (A10).

---

## 10. План отдельной Git-ветки

### 10.1. Branch setup

- Branch: `a04-gameplay-quest-systems` from `0335a5c` after A00 freeze/clean baseline.
- Do not branch from current dirty tree without TD’s snapshot; current tree has 574+ changes.
- No commit/push by A04; TD integrates.

### 10.2. Slice order (each slice independently testable)

| Slice | Files | Tests |
|---|---|---|
| S1: state/flags + speakers | `nightmare_run_state.gd`, `dialogue_runner.gd` | A04-01, A04-12 |
| S2: portal/scope/start | `level_portal.gd`, `quest_system.gd` (only if bug), adapters (only if bug) | A04-02/03/04 |
| S3: inspectable | `quest_inspectable.gd` | A04-05 |
| S4: save/map | `save_system.gd`, map scripts (no UI) | A04-08/09 |
| S5: final | `quest_finale_zone.gd`, `post_nightmare_finale.gd` | A04-10/11 |
| S6: M3 components | `quest_choice_controller.gd`, `quest_tide_lock.gd`, `quest_tide_wait.gd` | A04-06/07 (after M1) |

### 10.3. Branch rules

1. A04 changes only A04-owned paths; no `scenes/locations/**`, `scenes/ui/**`, `scripts/ui/**`, `resources/dialogue/**`, `tests/**`.
2. Scene wiring is an A03 handoff; UI is A08; tests are A10.
3. Shared files (`nightmare_run_state.gd`, `save_system.gd`, `level_portal.gd`, `post_nightmare_finale.tscn`) require A00 claim.
4. If a task needs a scene/UI change to be testable, create a synthetic fixture under A04-owned `scripts/**` or use a local test scene in A10; do not edit the shipped scene.
5. Run targeted tests after each slice; report exit code and `NOT TESTED`.

---

## 11. Спорные моменты для Technical Director

| ID | Вопрос | Предложение A04 | Почему важно |
|---|---|---|---|
| **D-01** | `start_quest_id` считается существующим или его «надо добавить»? | Считать существующим; BUG-011/§3.3 stale; A04-04 — regression test | Иначе дублирование поля/API |
| **D-02** | Кто владеет `demo_end_zone.gd` / `QuestFinaleZone`? | A04 — `scripts/world/quest_finale_zone.gd`; A03 — только scene node config | `scripts/world/**` A04, `scenes/locations/**` A03 |
| **D-03** | `QuestChoicePanel` — A04 или A08? | A04 `QuestChoiceController` backend; A08 `QuestChoicePanel` UI; DP-1.1 contract update | Нельзя создать UI в A04; нельзя duplicate |
| **D-04** | `TideController.get_level()` normalized vs `max_level=-1.0` | A03 adds `get_water_y`; A04 `max_water_y=-1.0`; `get_level` unchanged for HUD | Иначе SQ-04 неверен |
| **D-05** | Какие флаги обязательны для M1 final? | `shore_first_day_complete` + `camp_night_seen`; not all 7 quests | Narrative says camp night; avoid premature final |
| **D-06** | Кто и когда выставляет `demo_mode_full`? | A08 main menu/entry, approved by A00; default M1 if absent | Tech demo unreachable otherwise |
| **D-07** | Кто правит `post_nightmare_finale.tscn`? | A04 script; A08 card/text under shared claim; no second scene | File ownership conflict |
| **D-08** | Где сохранять финальный флаг? | `post_nightmare_finale._ready()` after flag; save scene = finale; load returns card | Avoid loop/soft-lock |
| **D-09** | `QuestTideLock` behavior at high water | Prompt + message, no progress; `can_interact_from` not water-gated | UX text; contract currently says can_interact |
| **D-10** | `ToWest` disable + test update | A03 disables; A10 updates old test; `FinalZone` only | Current test expects enabled |
| **D-11** | `post_nightmare_finale` legacy default | If no mode/M1 flag, keep tech behavior for old test/direct launch; M1 zone sets M1 flag before scene | Avoid red test during migration |
| **D-12** | Tests ownership | A10 writes all `tests/**`; A04 only supplies acceptance matrix | FILE_OWNERSHIP says A10 |
| **D-13** | Expired Chat 04 claims | TD must release/reassign `scripts/ui/gameplay_hud.gd`, `quest_toast.gd`, `labyrinth_quest_director.gd`, tests | ACTIVE_CLAIMS window ended; ownership says A08/A03/A10 |
| **D-14** | SQ-FS scope now? | Not in M1; M3 after M1 PASS; A04 only framework | Avoid expanding P0 |

---

## 12. Handoff TD

### 12.1. Что готово к утверждению

- Scope A04 и границы чужих зон.
- 12 задач с файлами, зависимостями, приоритетами, acceptance.
- Трудоёмкость 9–13.5 dev-days (A04 only).
- Отдельная branch-стратегия без UI/сцен/тестов.
- Список D-01…D-14.

### 12.2. Что TD должен сделать до старта

1. Подтвердить DP-1.0 и baseline freeze.
2. Решить D-01…D-14; обновить `INTEGRATION_CONTRACTS`/`AGENT_TASKS`, если D-02/03/04/05/07/09/10/11 приняты.
3. Выдать A04 claims на shared files: `nightmare_run_state.gd`, `save_system.gd`, `level_portal.gd`, `post_nightmare_finale.tscn` (если A08 не держит).
4. Назначить A03/A08/A10 задачи: scene nodes, UI, tests.
5. Зафиксировать, что `tests/**` не входят в A04-ветку.
6. Разрешить M3-компоненты (A04-06/07) только после M1 PASS.

### 12.3. Что A04 не обещает

- Полный ручной проход M1.
- Живой F5/F9 до A10-04.
- Tech demo Z11–Z18 до A00-08.
- SQ-FS-01…05 в M1.
- Чистый full GUT: текущее дерево имеет внешние animation/VFX ошибки.
- Готовый UI choice panel / final card / MapScreen fix — это A08.

---

## Appendix A — Canonical flags, aliases, portals, final POIs

### A.1. Canonical flags (M1)

| Flag | Устанавливает | Смысл |
|---|---|---|
| `p05_jett_talked` | P05 dialogue | Джет у койки |
| `p05_mirror_seen` | P05 mirror | зеркало |
| `p05_completed` | P05 portal | глава P05 |
| `jett_advice_heard` | P06 dialogue | совет Джета |
| `p06_completed` | P06 portal | глава P06 |
| `academy_gate_passed` | P07 | проверка |
| `p07_completed` | P07 portal | глава P07 |
| `dorm_assigned` | P08 | терминал |
| `p08_completed` | P08 portal | глава P08 |
| `induction_seen` | P09 | индукция |
| `capsule_entered` | P09 | капсула |
| `p09_completed` | P09 portal | глава P09 |
| `statue_seen` | B01 | статуя |
| `shroud_summoned` | B01 | Плащ |
| `b01_completed` | B01 portal | глава B01 |
| `b02_completed` | B02 portal | глава B02 |
| `shore_first_day_complete` | `first_day` reward | первый день |
| `camp_night_seen` | B03 camp night | ночь у костра |
| `post_nightmare_demo_completed` | M1 final | M1 завершён |
| `post_nightmare_completed` | tech final | tech demo завершён |
| `demo_mode_m1` | menu/entry | явный M1 (default) |
| `demo_mode_full` | menu/entry | tech demo |

### A.2. Aliases

| Legacy | Canonical | Тип |
|---|---|---|
| `precinct_mirror_seen` | `p05_mirror_seen` | flag |
| `academy_jet_seen` | `jett_advice_heard` | flag |
| `academy_gate_checked` | `academy_gate_passed` | flag |
| `sleeper_ready` | `capsule_entered` | flag |
| `black_sea_stars_seen` | `statue_seen` | flag |
| `black_sea_sword_seen` | `statue_seen` | flag |
| `demo_m1_completed` | `post_nightmare_demo_completed` | flag |
| `demo_completed` | `post_nightmare_completed` | flag |
| `jet` | `jett` | speaker, **not flag** |
| `technician` | `medic` | speaker, **not flag** |

### A.3. Portal matrix

| Scene | Portal | Required flags | Sets |
|---|---|---|---|
| P05 `police_precinct` | `ToAcademyApproach` | `p05_jett_talked`, `p05_mirror_seen` | `p05_completed` |
| P06 `academy_approach` | `ToAcademyGate` | `jett_advice_heard` | `p06_completed` |
| P07 `academy_gate` | `ToCampus` | `academy_gate_passed` | `p07_completed` |
| P08 `academy_campus` | `ToSleeper` | `dorm_assigned` | `p08_completed` |
| P09 `academy_sleeper_center` | `ToBlackSea` | `induction_seen`, `capsule_entered` | `p09_completed` |
| B01 `black_sea_platform` | `ToCoral` | `statue_seen`, `shroud_summoned` | `b01_completed` |
| B02 `tide_descent` | `ToCoral` | `b01_completed` | `b02_completed` |
| B03 `labyrinth_first_fragment` | `ToDescent` | `b02_completed` | — |

### A.4. Final POIs

| POI | Coordinates | Node | Mode | Flag |
|---|---|---|---|---|
| `POI-Z10-09` | `(-100, 18.2, -5)`, radius 4 | `DemoEndZone` | M1 | `post_nightmare_demo_completed` |
| `POI-Z18-05` | `(-1410, 35.2, 0)`, radius 4 | `FinalZone` | tech | `post_nightmare_completed` |

### A.5. M3 SQ IDs (not M1)

| ID | Code | Priority |
|---|---|---|
| `sq_fs_01_ninth_token` | 08 | M3-P0 |
| `sq_fs_02_echo_tunnel` | 09 | M3-P0 |
| `sq_fs_03_truth_without_lies` | 10 | M3-P0 |
| `sq_fs_04_salt_box` | 11 | M3-P2 |
| `sq_fs_05_bone_bridge_master` | 12 | M3-P1 |

---

## Appendix B — Источники

- `docs/demo_sprint/MASTER_PLAN.md` — scope, modes, flags, gates.
- `docs/demo_sprint/FILE_OWNERSHIP.md` — A04 paths, shared files.
- `docs/demo_sprint/MASTER_AUDIT.md` — current status; BUG-011 stale.
- `docs/demo_sprint/BACKLOG.md` — SS-013/014/032…040/060/061/130.
- `docs/demo_sprint/implementation/INTEGRATION_CONTRACTS.md` — IDs, APIs, save format.
- `docs/demo_sprint/implementation/AGENT_TASKS.md` — A04-01…12.
- `docs/demo_sprint/design/side_quests.md` — SQ design, flags, phase order.
- `docs/demo_sprint/design/world_layout.md` — zones, M1 final, Z18.
- `docs/demo_sprint/design/poi_manifest.md` — POI coordinates.
- `docs/demo_sprint/design/level_implementation_plan.md` — G1–G5, final zone intent.
- `docs/demo_sprint/design/narrative_design.md` — M1 final prerequisites.
- `scripts/quests/quest_system.gd`; `scripts/campaign/nightmare_run_state.gd`; `scripts/systems/save_system.gd`; `scripts/world/level_portal.gd`; `scripts/map/map_definition.gd`; `scripts/map/map_marker.gd`; `scripts/dialogue/dialogue_runner.gd`; `scripts/locations/forgotten_shore_labyrinth/tide_controller.gd`.

---

**Конец спецификации.**
