# Архитектура игровых систем демофрагмента

Дата: 2026-11-02
Область: Forgotten Shore Labyrinth, первый фрагмент B03–B05 — **tech demo / stretch**, не основной M1-маршрут.
Связанные документы: `docs/demo_sprint/audits/gameplay_systems.md`, `docs/demo_sprint/audits/quests.md`, `docs/demo_sprint/design/side_quests.md`, `docs/demo_sprint/design/00_DEMO_SCOPE_AND_CONTRACT.md`, `docs/design/12_inventory_economy_and_consumables.md`, `docs/design/13_systems_architecture_audit.md`, `docs/DECISIONS.md`.

> **Граница scope.** `QuestSystem` активируется только в `LabyrinthQuestDirector` (`forgotten_shore`). В S00–S15 `active_scope == &""`, `CampaignGuide.base_objective` не подменяется. Пять нарративных заданий SQ-01…05 из `side_quests.md` — дизайн P1/P2, в этом проходе не реализованы; реализованы семь заданий-каркасов из `resources/quests/`.

## 1. Цель

Сделать не «меню с кнопками», а работающий цикл:

```text
исследование → взаимодействие → бой → прогресс цели → награда
      ↑                                              │
      └──────────── смена сцены / смерть / загрузка ─┘
```

Критерий готовности: побочное задание можно получить, обновить, завершить и получить награду в игре; прогресс не теряется при смене сцены, смерти и загрузке слота; интерфейс показывает то же состояние, что хранится в данных.

## 2. Границы и решения

| Решение | Причина |
|---|---|
| Один источник состояния — `NightmareRunState` | Уже переживает `change_scene_to_file`, используется кампанией и порталами |
| Один квестовый движок — `QuestSystem` | `BeatDirector` остаётся для основного сюжета; побочные задания не дублируют его |
| Данные заданий — `.tres` | Правило проекта: баланс и описания в типизированных ресурсах |
| Награды — в существующее состояние | Не создавать второй инвентарь и вторую экономику |
| `Memories` — отдельный реестр | По `12` это не предмет полевого набора и не стопка |
| Взаимодействия — существующие `Interactable`/`Interactor` | Второй `Interactor` не нужен |
| Цель в HUD — через `CampaignGuide` | Уже есть `ObjectiveLine`, журнал и смена цели события |
| Журнал — через `RpgQuestScreen` | Уже есть экран, строки, карточка и прогресс-бар |
| Сохранение — снимок `NightmareRunState` | Один формат для чекпоинта, быстрого слота и будущего меню |

**Не входит в этот проход:** полноценный инвентарь на 8 слотов, торговля, крафт, аптечка, слоты Memories, эффекты Памятей, ИИ спутников, Эхо, стелс, гроза, финальный арт. Эти системы описаны отдельно и не подменяются демо-заглушками.

## 3. Слои

```text
┌──────────────────────────────────────────────────────────────┐
│ Presentation                                                 │
│ ObjectiveLine · RpgQuestScreen · QuestToast · CombatHud      │
│ InteractionPromptUI · SubtitleUI · DialogueRunner            │
└───────────────────────────────┬──────────────────────────────┘
                                │ signals
┌───────────────────────────────▼──────────────────────────────┐
│ Runtime                                                      │
│ QuestSystem · GameplayHud · LabyrinthQuestDirector           │
│ QuestPickup · QuestNpc · QuestTriggerZone · CheckpointZone   │
│ QuestKillCredit · SaveSystem                                 │
└───────────────────────────────┬──────────────────────────────┘
                                │ read/write
┌───────────────────────────────▼──────────────────────────────┐
│ State                                                        │
│ NightmareRunState: flags · items · quests · currency ·        │
│ memories · bestiary · checkpoint · beat                      │
└───────────────────────────────┬──────────────────────────────┘
                                │ load
┌───────────────────────────────▼──────────────────────────────┐
│ Data                                                         │
│ QuestCatalog · QuestDefinition · QuestObjective ·            │
│ QuestReward · DialogueSequence · .tres                       │
└──────────────────────────────────────────────────────────────┘
```

### 3.1. Данные

- `QuestCatalog` (`resources/quests/quest_catalog.tres`) — список заданий и scope.
- `QuestDefinition` — id, scope, код, title, category, prerequisites, required_quests, auto_start, objectives, rewards, completion_flag.
- `QuestObjective` — id, text, kind, target_id, required_count, optional, hidden_until_previous.
- `QuestReward` — item, currency, memory, flag, heal, text.
- `DialogueSequence` — существующий ресурс; новые сцены Нефис и Кассии лежат в `resources/dialogue/labyrinth/`.

Типы целей:

| Kind | Событие | target_id |
|---|---|---|
| `KILL` | `killed` | тег противника (`wounded_scavenger`, `carapace`, `bridge_carapace`) |
| `COLLECT` | `collected` | id предмета или `soul_shard` |
| `INTERACT` | `interacted` | `interaction_id` |
| `REACH` | `reached` | id триггера |
| `TALK` | `talked` | id NPC |
| `FLAG` | `flag` | имя флага |
| `CURRENCY` | `currency` | id валюты |

### 3.2. Состояние

`NightmareRunState` — единственный владелец изменяемого прогресса:

- `flags: Dictionary[StringName, bool]`
- `items: Dictionary[StringName, int]`
- `quests: Dictionary[quest_id, {state, objectives, reward_claimed}]`
- `currency: Dictionary[currency_id, int]`
- `memories: Dictionary[memory_id, bool]`
- `bestiary`, `current_beat_id`, `checkpoint_id`, `checkpoint_position`
- `tracked_quest`

`snapshot()` включает всё перечисленное. `restore()` сначала очищает состояние, затем применяет снимок и эмитит `state_restored`; `QuestSystem` пересобирает журнал и строку цели, но не выдаёт награды повторно.

## 4. QuestSystem

Autoload `QuestSystem` (`scripts/quests/quest_system.gd`). Не является вторым `BeatDirector`: он не двигает события P01–N26 и не заменяет `CampaignGuide`.

### 4.1. Жизненный цикл

```text
                    prerequisites + required_quests
                                  │
                                  ▼
   [нет записи] ──auto_start──► [active] ──все required objectives──► [completed]
        │                          │                                   │
        │                          │ objective progress                │ rewards once
        │                          ▼                                   ▼
        │                     [available]                       flags/items/currency/
        │                                                       memory/checkpoint
        └────────── show_available ─────┘
```

Правила:

1. `activate_scope(scope)` вызывается сценой фрагмента. До этого каталог пассивен: кампания не получает чужих заданий.
2. `refresh_auto_start()` запускает только задания активного scope, у которых выполнены prerequisites и required_quests.
3. `notify_event(event_id, subject_id, amount)` двигает совпавшие цели. Сцены не знают id заданий.
4. `item_changed` синхронизирует `COLLECT`-цели по фактическому количеству, но не откатывает прогресс при трате.
5. `flag_changed` запускает автозапуск и закрывает `FLAG`-цели.
6. `complete_quest(quest_id, force)` — аварийный/сюжетный вход; награда всё равно выдаётся один раз.
7. `tracked_quest` выбирает первое активное MAIN-задание, иначе первое активное SIDE.
8. `deactivate_scope()` вызывается при выходе из сцены: строка цели гаснет, состояние остаётся.

### 4.2. Сигналы

| Сигнал | Назначение |
|---|---|
| `quest_started(quest)` | тост, журнал |
| `quest_progressed(quest, objective, progress, required)` | отладка, журнал |
| `quest_objective_completed(quest, objective)` | звук/тост, будущие подсказки |
| `quest_completed(quest)` | тост, автосейв |
| `reward_granted(quest, reward)` | тост награды |
| `tracked_quest_changed(quest)` | HUD |
| `journal_changed` | `RpgQuestScreen` |
| `message_requested(text, tone)` | подбор, отдых, системные сообщения |

### 4.3. Строка цели и журнал

`QuestSystem` вызывает `CampaignGuide.set_external_objective(text, &"quest_system")`. Пока внешняя цель задана, она имеет приоритет над целью события; idle-подсказки не перебивают её. `ObjectiveLine` уже слушает `CampaignGuide`, а при активном scope дополнительно читает `QuestSystem` напрямую и показывает `ProgressBar` для целей с несколькими шагами. Второго HUD-виджета нет.

`RpgQuestScreen.refresh()` выбирает один источник по приоритету:

1. живые снимки `QuestJournalEntry` из `QuestSystem.get_journal_entries()` при активном scope;
2. история `CampaignGuide` для Первого Кошмара;
3. DEMO-каталог `resources/rpg_menu/quest_demo.tres` только если игровых данных нет.

Живая запись показывает статус, цели, прогресс и кнопку «Следить за целью». Клик по строке выбирает запись; кнопка вызывает `QuestSystem.set_tracked_quest()`. DEMO-записи не выдаются за кампанию.

## 5. Мировые адаптеры

| Узел | База | Роль |
|---|---|---|
| `QuestPickup` | `Interactable` | подбор предмета/валюты/Памяти, флаг, событие `collected`/`interacted` |
| `QuestNpc` | `Node3D` + `Interactable` | диалог через `DialogueRunner`, флаг, событие `talked` |
| `QuestTriggerZone` | `TriggerZone` | одноразовый вход, флаг, событие `reached`; условия проверяются до выключения |
| `CheckpointZone` | `Area3D` | чекпоинт в `NightmareRunState`, лечение, восстановление выносливости, автосейв |
| `QuestKillCredit` | `Node` рядом с `Health` | событие `killed`, флаг уникального врага |
| `LabyrinthQuestDirector` | `Node3D` | расставляет адаптеры по авторским маркерам `Gameplay/*` |

### 5.1. Игрок → объект

```text
E / Interact
  → Interactor выбирает ближайший Interactable
  → QuestPickup.interact() / QuestNpc._on_interacted()
  → NightmareRunState (флаг/предмет/валюта/Память)
  → QuestSystem.notify_event(...)
  → objective progress → complete → reward
  → QuestToast / ObjectiveLine / RpgQuestScreen
```

### 5.2. Игрок → зона

```text
CharacterBody3D входит в Area3D
  → TriggerZone.body_entered
  → QuestTriggerZone.fire()
  → проверка required_flags
  → set_flag + QuestSystem.notify_event("reached", id)
```

### 5.3. Враг → квест

```text
HealthComponent.died
  → QuestKillCredit._on_died()
  → set_flag уникального врага + QuestSystem.notify_event("killed", tag)
  → objective progress
```

`CarapaceEnemy` не знает о квестах. `QuestKillCredit` добавляется директором к экземпляру, поэтому один и тот же враг может быть переиспользован в арене без квестового кредита.

## 6. Содержание демофрагмента

### 6.1. Основное задание

| id | Цели | Награда |
|---|---|---|
| `first_day` | дойти до развилки; поговорить с Нефис; дойти до лагеря | 5 осколков, лечение 20, флаг `shore_first_day_complete` |

### 6.2. Побочные задания

| id | Условие старта | Цели | Награда |
|---|---|---|---|
| `first_blood` | флаг `shore_fork_reached` | убить `wounded_scavenger` | 2 осколка, флаг `wounded_scavenger_slain` |
| `azure_blade` | `wounded_scavenger_slain` | забрать `azure_blade` | Память `azure_blade`, 1 осколок, флаг `azure_blade_found` |
| `crystal_cache` | сразу | собрать 3 `soul_shard` | 3 осколка, флаг `crystal_cache_complete` |
| `hunt_pack` | `shore_hunting_reached` | убить 3 `carapace` | 6 осколков, флаг `pack_thinned` |
| `camp_rest` | `shore_camp_reached` | использовать `campfire` | лечение 100, флаг `camp_rested` |
| `bridge_stand` | `shore_bridge_reached` | убить 2 `bridge_carapace` | 4 осколка, флаг `bone_bridge_cleared` |

### 6.3. Мировые точки

- `AzureBladePickup` — Память, не предмет инвентаря; скрыт до флага `wounded_scavenger_slain`, чтобы награду нельзя было забрать раньше задания.
- `SoulShardDryPocket`, `SoulShardTunnel`, `SoulShardBridge` — три осколка.
- `Campfire` — отдых, чекпоинт `CP-SHORE-CAMP`.
- `Nephis`, `Cassia` — NPC с диалогами; Нефис открывает цель встречи.
- `WoundedScavenger` — ослабленный карапакс (65 HP).
- `PacksZ13` — три карапакса.
- `TwoCarapaces` — два карапакса на костяном мосте.
- `CheckpointZone`: `CP-SHORE-START`, `CP-SHORE-CAMP`, `CP-SHORE-REFUGE`, `CP-SHORE-CLIFF`.

## 7. Награды

`QuestReward` применяется в `QuestSystem._grant_reward()`:

```text
item_id + item_count       → NightmareRunState.add_item()
currency_id + amount       → NightmareRunState.add_currency()
memory_id                  → NightmareRunState.unlock_memory()
flag                       → NightmareRunState.set_flag()
heal_amount                → HealthComponent.heal()
```

Порядок:

1. задание переходит в `completed`;
2. ставится `completion_flag`;
3. награды выдаются один раз, затем `reward_claimed = true`;
4. эмитятся `reward_granted` и `quest_completed`;
5. выбирается следующая отслеживаемая цель;
6. в не-headless режиме пишется быстрый слот.

При `restore()` завершённые задания не проходят через `_complete_quest()`, поэтому повторной выдачи нет.

## 8. Сохранение и прогресс

### 8.1. Внутри сессии

- Смена сцены: `NightmareRunState` — autoload, поэтому флаги, квесты, валюта, Памяти и чекпоинт сохраняются.
- Смерть: `FallRecovery` возвращает на `NightmareRunState.checkpoint_id` / позицию; квестовый прогресс не откатывается.
- Подобранные предметы: флаг в `NightmareRunState`; при повторном входе `QuestPickup` скрывается.
- Убитые враги: уникальный флаг; директор не спавнит их снова.

### 8.2. Дисковый слот

`SaveSystem` (`scripts/systems/save_system.gd`, autoload):

- путь `user://campaign_save.bin`;
- `F5` — `save_game()`, `F9` — `load_game()`;
- payload: `version`, `scene`, `position`, `rotation_y`, `run_state`, `saved_at`;
- `load_game()` восстанавливает `NightmareRunState`, перезагружает сцену и применяет позицию после появления игрока;
- автосейв на `CheckpointZone`, `BeatDirector.activate_checkpoint()` и завершении задания (кроме headless);
- настройки не входят в слот и остаются в `user://settings.cfg`.

Это минимальный слот «для выхода», а не полноценное меню сохранений. Ручные слоты, подтверждение перезаписи и список сохранений — следующий этап.

## 9. Интеграция с другими системами

### 9.1. Бой

- `QuestKillCredit` — единственная точка связи врага и квестов.
- `HealthComponent` не менялся.
- `CarapaceEnemy`/`LarvaEnemy` не знают о QuestSystem.
- `CombatHud` автоматически привязывается к игроку и ближайшему врагу.

### 9.2. Инвентарь

- Полноценный инвентарь на 8 слотов **не реализован**; `InventoryPrototype` остаётся DEMO-витриной.
- Квестовые предметы и валюта хранятся в `NightmareRunState`.
- Когда появится канонический инвентарь по `12`, он должен читать `NightmareRunState`, а не создавать второй источник.
- `ITEM_IDS` остаётся временным списком; каталог предметов — отдельная задача.

### 9.3. Memories / Soul Sea

- `NightmareRunState` хранит открытые Памяти.
- `azure_blade` открывается наградой.
- Слоты, эффекты, отображение в Soul Sea и выбор активной Памяти — не реализованы; визуальный прототип Soul Sea не переписывался.

### 9.4. Сюжет

- `BeatDirector` продолжает вести P01–N26.
- `CampaignGuide` остаётся источником цели события; внешняя квестовая цель имеет приоритет только пока активна.
- `NightmareRunState.set_current_beat()` и квесты не конфликтуют: это разные поля снимка.

### 9.5. Переходы

- `tide_descent/ToCoral` ведёт в `labyrinth_first_fragment.tscn` / `FromDescent`.
- `labyrinth_first_fragment/ToDescent` ведёт обратно в `tide_descent.tscn` / `FromCoral`.
- `LabyrinthQuestDirector` активирует scope при входе и деактивирует при выходе; состояние остаётся в autoload.

## 10. Файловое распределение

| Путь | Ответственность |
|---|---|
| `scripts/quests/quest_definition.gd` | данные задания |
| `scripts/quests/quest_objective.gd` | данные цели |
| `scripts/quests/quest_reward.gd` | данные награды |
| `scripts/quests/quest_catalog.gd` | индекс каталога |
| `scripts/quests/quest_system.gd` | autoload, прогресс, награды, трекинг, журнал |
| `scripts/quests/quest_journal_entry.gd` | снимок для `RpgQuestScreen` |
| `scripts/quests/quest_journal_objective.gd` | снимок цели |
| `scripts/quests/quest_pickup.gd` | подбор |
| `scripts/quests/quest_npc.gd` | NPC и диалог |
| `scripts/quests/quest_trigger_zone.gd` | сюжетный/квестовый триггер |
| `scripts/quests/checkpoint_zone.gd` | чекпоинт и автосейв |
| `scripts/quests/quest_kill_credit.gd` | кредит убийства |
| `scripts/inspect/quest_inspectable.gd` | осмотр улик/зеркала/Плаща |
| `scripts/quests/quest_choice_controller.gd` | backend выбора SQ-03 |
| `scripts/quests/quest_tide_lock.gd` | гейт объекта по высоте воды |
| `scripts/quests/quest_tide_wait.gd` | ожидание/смена фазы прилива |
| `scripts/world/quest_finale_zone.gd` | M1/tech финальная зона |
| `scripts/systems/save_system.gd` | быстрый слот |
| `scripts/locations/forgotten_shore_labyrinth/labyrinth_quest_director.gd` | расстановка контента по маркерам |
| `scripts/ui/gameplay_hud.gd` | сборка HUD из существующих виджетов |
| `scripts/ui/quest_toast.gd` | короткие сообщения о заданиях |
| `resources/quests/*.tres` | семь заданий и каталог |
| `resources/dialogue/labyrinth/*.tres` | диалоги Нефис и Кассии |
| `scenes/quests/gameplay_hud.tscn` | HUD фрагмента |
| `scenes/quests/quest_pickup.tscn` | мировой предмет |
| `scenes/quests/quest_npc.tscn` | NPC |
| `tests/test_quest_system.gd` | каталог, прогресс, награды, снимок |
| `tests/test_labyrinth_quest_content.gd` | реальная цепочка через мир |
| `tests/test_save_system.gd` | слот сохранения |
| `docs/demo_sprint/audits/gameplay_systems.md` | аудит |
| `docs/demo_sprint/design/gameplay_architecture.md` | этот документ |

## 11. Что готово / что завершить / чего нет

### Готово

- Каталог и семь заданий.
- Автозапуск по флагам и prerequisite-заданиям.
- Прогресс KILL/COLLECT/INTERACT/REACH/TALK/FLAG/CURRENCY.
- Награды: предмет, валюта, Память, флаг, лечение.
- Журнал и строка цели.
- NPC-диалоги, подбор, триггеры, чекпоинты, кредит убийства.
- Быстрый слот сохранения и автосейв.
- Интеграция с `tide_descent`.

### Завершить в следующем проходе

- Ручной проход от `tide_descent` до утёсов.
- Проверка F5/F9 в живом окне.
- Канонический инвентарь и отображение квестовых предметов.
- Слоты и эффекты Памятей, Soul Sea.
- Аптечка/еда/расходники по `12`.
- Спутники, Эхо, стелс, гроза, финальный арт.
- Полные сохранения (слоты, список, подтверждение).

### Чего нет и что не подменяется

- Пять нарративных заданий SQ-01…05 из `design/side_quests.md` — только дизайн; A04-компоненты для них добавлены, но сцены/данные создаёт A02/A03.
- OR-цели, failure/abandon, квестовые маркеры на карте и bestiary/map-награды не реализованы. `QuestChoiceController`, `QuestInspectable`, `QuestTideLock`/`QuestTideWait` реализованы как аддитивные компоненты; UI выбора — A08, размещение — A03. Хук `start_quest_id` уже есть в `QuestPickup`/`QuestNpc`/`QuestTriggerZone`.
- Второго инвентаря.
- Второго `QuestSystem` или второго журнала.
- Второго `Interactor`.
- Второй валюты.
- Фальшивых квестов в DEMO-каталоге.

## 12. Приёмка

- [ ] Игрок входит из `tide_descent` в `labyrinth_first_fragment`.
- [ ] `first_day` активен, строка цели видна.
- [ ] Триггер развилки запускает `first_blood`.
- [ ] Раненый карапакс умирает, задание закрывается, награда начисляется.
- [ ] Азурный клинок подбирается, Память открывается, задание закрывается.
- [ ] Три осколка обновляют `crystal_cache` и закрывают его.
- [ ] Нефис открывает цель встречи; Кассия доступна после неё.
- [ ] Лагерь закрывает `first_day` и запускает `camp_rest`.
- [ ] Костёр лечит и ставит чекпоинт.
- [ ] Стая и мост закрываются по 3 и 2 убийствам.
- [ ] F5 сохраняет, F9 возвращает сцену, позицию и прогресс.
- [ ] Смерть возвращает на чекпоинт, квесты не откатываются.
- [ ] Повторный вход не воскрешает убитых и не выдаёт награды заново.
- [x] Полный GUT зелёный (Stage 7: 648/648, 7380 asserts, exit 0).
- [ ] Ручной проход и визуальная читаемость — **NOT TESTED** до фактической проверки.

---

## 13. Stage 3 wave 1 — A04 implementation

**Дата:** 2026-11-03. **Ветка:** `demo/gameplay`. **База:** `ee97325`.

Добавлены аддитивные компоненты без второго framework:

- `NightmareRunState.FLAG_ALIASES` / `canonical_flag()`: legacy-флаг читается, но новые записи и snapshot содержат только canonical.
- `QuestInspectable` (`scripts/inspect/`): `Interactable` для зеркала, Плаща и улик; `required_flags`, `completion_flag`, `start_quest_id`, `quest_event`.
- `QuestChoiceController` (`scripts/quests/`): backend выбора; UI `QuestChoicePanel` остаётся A08.
- `QuestTideLock` / `QuestTideWait`: гейт по высоте воды и вызов `advance_to_low/high`; второго `TideController` нет. До появления `get_water_y()` используется текущий `get_level()` + `low_y/high_y`.
- `QuestFinaleZone` (`scripts/world/`): M1/tech one-shot zone; ставит canonical flag, очищает guide, выключает scope, вызывает единственный `post_nightmare_finale.tscn`.
- `post_nightmare_finale.gd`: M1/tech mode branch, canonical flag, deferred save.
- `LevelPortal`: повторная проверка required flag, если игрок уже внутри зоны.
- `SaveSystem`: pending не зависает в сцене без player.

Осталось интегрировать: A03 scene nodes/portal values/tide API, A08 choice/map/final UI, A10 live/manual tests. Полный GUT на момент отчёта: **648/648, exit 0**. Ручной проход и F5/F9 — **NOT TESTED**.
