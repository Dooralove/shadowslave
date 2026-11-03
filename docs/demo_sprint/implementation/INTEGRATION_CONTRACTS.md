# INTEGRATION CONTRACTS — Shadow Slave / Design Package DP-1.0

**Дата:** 2026-11-03  
**Статус:** обязательный контракт Stage 3.  
**Базовая точка:** commit `75f1423d536ae63b073f59bb897d13f052cdbe8a`, branch `demo/integration`, clean tree кроме unstaged `opencode.json`.  
**Правило:** новые сцены, диалоги, квесты и тесты используют только канонические ID из этого документа. Legacy aliases читаются, но не пишутся.

---

## 0. Границы контракта

Этот документ фиксирует:

- Quest IDs, NPC IDs, POI IDs, Event IDs.
- Канонические флаги и aliases.
- Переходы между сценами.
- Публичные API, сигналы и структуры данных.
- Соглашения по `.tres`/`.tscn`.
- Формат сохранения.
- Планируемые аддитивные компоненты (`QuestInspectable`, `QuestChoicePanel`, `QuestTideLock`, `advance_to_low/high`).

**Не является:** вторым QuestSystem, вторым state, вторым save, вторым HUD, вторым dialogue engine, вторым tide controller.

---

## 1. Соглашения ID

| Тип | Формат | Пример | Правило |
|---|---|---|---|
| Quest ID | `snake_case` | `first_day`, `sq_fs_01_ninth_token` | `StringName`; не менять после появления в сохранении |
| NPC ID | `snake_case` | `jett`, `nephis`, `kasper` | display-имя отдельно; один ID на персонажа |
| POI ID | `POI-<scene>-<NN>` / `POI-Z<NN>-<NN>` | `POI-P05-01`, `POI-Z10-09` | только из `poi_manifest.md` |
| Event ID | `P05`…`B03`, `EV-<scene>-<topic>` | `EV-P05-MIRROR` | transient event, не flag |
| Flag ID | `snake_case` | `p05_mirror_seen` | boolean state в `NightmareRunState` |
| Checkpoint ID | `CP-SHORE-*` | `CP-SHORE-CAMP` | только Лабиринт |
| Scene path | `res://...` | `res://scenes/locations/post_nightmare/police_precinct.tscn` | без абсолютных путей |
| Resource ID | `snake_case.tres` | `resources/quests/first_day.tres` | typed `.tres`; JSON не для game data |
| Quest code | 2 цифры | `08`…`12` | SQ-FS; 01–07 базовые |

**Запрещено:** локализованные ID, пробелы, `Jett`/`Jet` как ID, `POI` без сцены, дубли `first_day`/`first_day_2`.

---

## 2. Quest IDs

### 2.1. Семь базовых (существующие)

| ID | Code | Category | Scope | Auto-start | Ключевые цели | Completion flag | M1 |
|---|---|---|---|---|---|---|---|
| `first_day` | `01` | MAIN | `forgotten_shore` | true | `first_fork`, `nephis`, `camp` | `shore_first_day_complete` | **да** |
| `first_blood` | `02` | MAIN | `forgotten_shore` | true | kill `wounded_scavenger` ×1 | `wounded_scavenger_slain` | **да** |
| `azure_blade` | `03` | MAIN | `forgotten_shore` | true | interact `azure_blade` ×1 | `azure_blade_found` | **да** |
| `crystal_cache` | `04` | SIDE | `forgotten_shore` | true | collect `soul_shard` ×3 | `crystal_cache_complete` | частично (2/3) |
| `hunt_pack` | `05` | SIDE | `forgotten_shore` | true | kill `carapace` ×3 | `pack_thinned` | нет |
| `camp_rest` | `06` | SIDE | `forgotten_shore` | true | interact `campfire` ×1 | `camp_rested` | **да** |
| `bridge_stand` | `07` | SIDE | `forgotten_shore` | true | kill `bridge_carapace` ×2 | `bone_bridge_cleared` | нет |

### 2.2. Пять SQ-FS (M3)

| ID | Code | Category | Auto-start | Show available | Prerequisites | Completion flag | Цепочка |
|---|---|---|---|---|---|---|---|
| `sq_fs_01_ninth_token` | `08` | SIDE | **false** | **false** | — | `sq_fs_01_complete` | A |
| `sq_fs_02_echo_tunnel` | `09` | SIDE | **false** | **false** | `sq_fs_01_complete` | `sq_fs_02_complete` | A |
| `sq_fs_03_truth_without_lies` | `10` | SIDE | **false** | **false** | `sq_fs_02_complete` | `sq_fs_03_complete` | A |
| `sq_fs_04_salt_box` | `11` | SIDE | **false** | **false** | — | `sq_fs_04_complete` | B |
| `sq_fs_05_bone_bridge_master` | `12` | SIDE | **false** | **false** | — | `sq_fs_05_complete` | B |

**Правила:**

1. SQ-FS не входят в M1 и S00–S15.
2. `start_quest_id` стоит на мире (pickup/NPC/trigger), не в `QuestDefinition`.
3. SQ-01…03 — M3-P0; SQ-04 — M3-P2; SQ-05 — M3-P1.
4. SQ-03 исход — `sq_fs_03_resolved` (флаг), не новое состояние квеста.
5. SQ-05 исход — `sq_fs_05_resolved` (kill/tide/spare), не FAILED.
6. `QuestOutcomeReward` не используется; награды — world pickup + flags.

### 2.3. M1 reachability

| Quest | POI | M1 complete? | Причина |
|---|---|---|---|
| `first_day` | `POI-Z03-01`, `POI-Z08-02`, `POI-Z10-01` | **да** | все точки в Z01–Z10 |
| `first_blood` | `POI-Z03-02` | **да** | Z03 |
| `azure_blade` | `POI-Z03-03` | **да** | Z03 |
| `crystal_cache` | `POI-Z06-05`, `POI-Z09-08`, `POI-Z14-11` | **нет** | третий осколок в Z14 |
| `hunt_pack` | `POI-Z13-07` | **нет** | Z13 вне M1 |
| `camp_rest` | `POI-Z10-02` | **да** | Z10 |
| `bridge_stand` | `POI-Z14-03` | **нет** | Z14 вне M1 |

Финал M1 не требует `crystal_cache`/`hunt_pack`/`bridge_stand`.

---

## 3. NPC IDs

| ID | Display | Сцены | Роль | Статус | Флаги |
|---|---|---|---|---|---|
| `jett` | Джет | P05, P06 | проводник | Mannequin placeholder; alias `jet` | `p05_jett_talked`, `jett_advice_heard` |
| `desk_officer` | Дежурный | P05 | визуальный NPC | Mannequin | — |
| `interrogation_officer` | Офицер допросной | P05 | визуальный NPC | Mannequin | — |
| `gate_guard` | Охрана КПП | P06/P07 | проверка | Mannequin `police_guard` | `academy_gate_passed` |
| `campus_terminal` | Терминал кампуса | P08 | направление | Interactable | `dorm_assigned` |
| `campus_guide` | Проводник | P08 | optional placeholder | Mannequin; не канон | `dorm_assigned` |
| `medic` | Медик | P09 | индукция | Mannequin; alias `technician` | `induction_seen` |
| `rock` | Рок | P09 | инструктор | **MISSING**; placeholder | `induction_seen` |
| `kasper` | Каспер | P09 | социальный соперник | **MISSING**; placeholder; alias `casper` | `kasper_met` |
| `cassia` | Кассия | P09, Z08, Z10 | Sleeper/спутница | Mannequin; M2/M3 final | `cassia_seen`, `cassia_met` |
| `nephis` | Нефис | P07, Z08, Z10 | силуэт/спутница | Mannequin; M2/M3 final | `nephis_seen_at_gate`, `nephis_met` |
| `julius` | Джулиус | M2 | академия | **M2 only**; текущий placeholder в Sleeper Center вне M1 | — |
| `theo` | Тео | Z06 | SQ-01…03 | **MISSING**; M3 | `sq_fs_01_started`, `sq_fs_01_complete` |
| `echo_polyp` | Эхо-полип | Z09 | SQ-02 | **MISSING**; M3 | `sq_fs_02_polyp_dead` |
| `old_shell` | Старая раковина | Z14 | SQ-05 alpha | **MISSING**; M3 | `sq_fs_05_alpha_dead`/`spared` |

**Правила:**

- Один NPC ID — один персонаж. Нефис в P07/Z08/Z10 — один ID; для кадра использовать маркеры/видимость, не второй `QuestNpc`.
- Джулиус не в M1; `academy_julius_seen` — legacy, не использовать.
- `cassia` в P09 — визуальная, без диалога; в Z08 — диалог.
- `jett` в P05 и P06 — один персонаж, два размещения; не дублировать ID.

---

## 4. POI IDs

### 4.1. Диапазоны

| Сцена | Диапазон | Кол-во | Источник |
|---|---|---:|---|
| `police_precinct` | `POI-P05-01…07` | 7 | `poi_manifest.md` §1 |
| `academy_approach` | `POI-P06-01…06` | 6 | §2 |
| `academy_gate` | `POI-P07-01…06` | 6 | §3 |
| `academy_campus` | `POI-P08-01…05` | 5 | §4 |
| `academy_sleeper_center` | `POI-P09-01…11` | 11 | §5 |
| `black_sea_platform` | `POI-B01-01…06` | 6 | §6 |
| `tide_descent` | `POI-B02-01…06` | 6 | §7 |
| `labyrinth_first_fragment` | `POI-Z01…Z18` + sub-ID | 100+ | §8 |

**Правило:** полный список — только `poi_manifest.md`. Если точки нет, A03 добавляет её в manifest и сцену; A02/A04 не придумывают ID.

### 4.2. Квестовые POI

| Quest | POI |
|---|---|
| `first_day` | `POI-Z03-01`, `POI-Z08-02`, `POI-Z10-01` |
| `first_blood` | `POI-Z03-02` |
| `azure_blade` | `POI-Z03-03` |
| `crystal_cache` | `POI-Z06-05`, `POI-Z09-08`, `POI-Z14-11` |
| `hunt_pack` | `POI-Z13-07` |
| `camp_rest` | `POI-Z10-02` |
| `bridge_stand` | `POI-Z14-03` |
| `sq_fs_01_ninth_token` | `POI-Z02-02`, `POI-Z02-03`, `POI-Z05-02`, `POI-Z08-05`, `POI-Z06-02` |
| `sq_fs_02_echo_tunnel` | `POI-Z08-05`, `POI-Z09-02`…`POI-Z09-08`, `POI-Z09-11`, `POI-Z09-12`, `POI-Z09-06` |
| `sq_fs_03_truth_without_lies` | `POI-Z06-02`, `POI-Z06-03`, `POI-Z09-11` |
| `sq_fs_04_salt_box` | `POI-Z11-03`, `POI-Z11-04A/B/C`, `POI-Z11-05` |
| `sq_fs_05_bone_bridge_master` | `POI-Z14-08`, `POI-Z14-06`…`POI-Z14-10`, `POI-Z14-13`, `POI-Z14-15`, `POI-Z14-16` |
| M1 end | `POI-Z10-09` (`DemoEndZone`) |
| Tech demo end | `POI-Z18-05` (`FinalZone`) |

---

## 5. Event IDs

### 5.1. Сюжетные события

| Event ID | Сцена | Смысл | Основной флаг |
|---|---|---|---|
| `P05` | `police_precinct` | пробуждение/выход | `p05_completed` |
| `P06` | `academy_approach` | Джет/КПП | `p06_completed` |
| `P07` | `academy_gate` | проверка/Нефис | `p07_completed` |
| `P08` | `academy_campus` | терминал | `p08_completed` |
| `P09` | `academy_sleeper_center` | индукция/капсула | `p09_completed` |
| `B01` | `black_sea_platform` | статуя/Плащ | `b01_completed` |
| `B02` | `tide_descent` | спуск | `b02_completed` |
| `B03` | `labyrinth_first_fragment` | Z01–Z10 | `post_nightmare_demo_completed` |

### 5.2. Подсобытия

| Event ID | Где | Смысл |
|---|---|---|
| `EV-P05-JETT` | P05 | разговор с Джет |
| `EV-P05-MIRROR` | P05 | зеркало/тень |
| `EV-P05-EXIT` | P05 | выход во двор |
| `EV-P06-JETT` | P06 | три совета |
| `EV-P06-CHECKPOINT` | P06 | КПП |
| `EV-P07-GATE` | P07 | проверка |
| `EV-P07-NEPHIS` | P07 | силуэт Нефис |
| `EV-P08-TERMINAL` | P08 | направление |
| `EV-P09-INDUCTION` | P09 | индукция |
| `EV-P09-CAPSULE` | P09 | капсула |
| `EV-B01-STATUE` | B01 | статуя/звёзды/меч |
| `EV-B01-SHROUD` | B01 | призыв Плаща |
| `EV-B02-DESCENT` | B02 | спуск/прилив |
| `EV-B03-CAMP` | B03 | ночь у костра |
| `DEMO-END-M1` | Z10 | финал M1 |
| `DEMO-END-FULL` | Z18 | финал tech demo |

**Дополнительные POI-события** (`EV-P05-LORE`, `EV-P06-LORE`, `EV-P07-LANDMARK`, `EV-P08-LANDMARK`, `EV-P09-LORE`, `EV-B02-LANDMARK`, `EV-B02-VISTA`, `EV-Z10-LANDMARK`, `EV-Z10-LORE`, `EV-Z10-ROUTE`, `EV-Z10-VISTA`, `EV-Z18-ROUTE`, `EV-Z18-CLIMB`, `EV-Z18-LANDMARK`) берутся из `poi_manifest.md`; не переименовывать.

### 5.3. Quest events

`QuestSystem.notify_event(event_id, subject_id, amount)` принимает только:

| Kind | event_id | subject_id |
|---|---|---|
| KILL | `killed` | enemy tag (`wounded_scavenger`, `carapace`, `bridge_carapace`) |
| COLLECT | `collected` | item id (`soul_shard`) |
| INTERACT | `interacted` | interaction id (`azure_blade`, `campfire`) |
| REACH | `reached` | trigger id (`first_fork`, `camp`) |
| TALK | `talked` | NPC id (`nephis`) |
| FLAG | `flag` | flag name |
| CURRENCY | `currency` | currency id (`soul_shard`) |

**Не путать:** `EV-*` — нарративное событие; `killed`/`talked` — квестовое событие. Одно не заменяет другое.

---

## 6. Флаги: канонические и aliases

### 6.1. Канонические M1-флаги

| Флаг | Ставится | Смысл |
|---|---|---|
| `post_nightmare_started` | меню/finale/`GreyboxLocation` | вход в пост-Кошмар |
| `p05_jett_talked` | P05 `jett` | разговор с Джет |
| `flaw_revealed` | P05 | Порок показан |
| `flaw_clear_conscience` | P05 | имя Порока |
| `p05_mirror_seen` | P05 mirror | тень в зеркале |
| `shadow_sight_unlocked` | P05 mirror | Shadow Sight |
| `p05_completed` | P05 portal | сцена завершена |
| `jett_advice_heard` | P06 `jett` | три совета |
| `p06_checkpoint_passed` | P06 КПП | локальная проверка |
| `p06_completed` | P06 portal | сцена завершена |
| `nephis_seen_at_gate` | P07 trigger | Нефис у ворот |
| `academy_gate_passed` | P07 guard | проверка пройдена |
| `p07_completed` | P07 portal | сцена завершена |
| `dorm_assigned` | P08 terminal | направление получено |
| `p08_completed` | P08 portal | сцена завершена |
| `induction_seen` | P09 Rock | индукция |
| `kasper_met` | P09 Rock | Каспер представлен |
| `cassia_seen` | P09 trigger | Кассия замечена |
| `academy_month_passed` | P09 time skip | месяц прошёл |
| `capsule_entered` | P09 capsule | вход в капсулу |
| `p09_completed` | P09 portal | сцена завершена |
| `b01_arrived` | B01 start | прибытие |
| `statue_seen` | B01 statue | статуя осмотрена |
| `shroud_summoned` | B01 shroud | Плащ призван |
| `b01_completed` | B01 portal | сцена завершена |
| `tide_seen` | B02 optional | отлив увиден |
| `b02_completed` | B02 portal | сцена завершена |
| `shore_entry` | B03 start | вход в Лабиринт |
| `shore_fork_reached` | Z03 trigger | первая развилка |
| `wounded_scavenger_slain` | бой | карапакс убит |
| `azure_blade_found` | подбор | клинок получен |
| `shore_clearing_reached` | Z08 trigger | прогалина |
| `nephis_met` | Nephis dialogue | Нефис |
| `cassia_met` | Cassia dialogue | Кассия |
| `shore_camp_reached` | Z10 trigger | лагерь |
| `shore_first_day_complete` | `first_day` reward | первый день |
| `camp_rested` | `camp_rest` | отдых у костра |
| `camp_night_seen` | camp night | финальная сцена |
| `post_nightmare_demo_completed` | M1 final card | M1 завершён |
| `demo_mode_m1` | menu/campaign entry | выбран M1 (default) |
| `demo_mode_full` | menu/campaign entry | выбран tech demo |
| `post_nightmare_completed` | tech demo final card | tech demo завершён |

### 6.2. Quest completion flags

| Флаг | Владелец |
|---|---|
| `crystal_cache_complete` | `crystal_cache` |
| `pack_thinned` | `hunt_pack` |
| `bone_bridge_cleared` | `bridge_stand` |
| `sq_fs_01_complete`…`sq_fs_05_complete` | SQ-01…05 |
| `sq_fs_03_resolved` | SQ-03 choice |
| `sq_fs_05_resolved` | SQ-05 outcome |

### 6.3. Legacy aliases (read-only)

| Legacy | Canonical | Действие |
|---|---|---|
| `jet` (NPC ID) | `jett` | читать alias; новые сцены — `jett` |
| `technician` | `medic` | читать alias; новые сцены — `medic` |
| `casper` | `kasper` | читать alias; флаг `kasper_met` |
| `precinct_mirror_seen` | `p05_mirror_seen` | миграция |
| `precinct_exit_seen` | `p05_completed` | миграция после портала |
| `academy_jet_seen` | `jett_advice_heard` | миграция |
| `academy_checkpoint_seen` | `p06_checkpoint_passed` | миграция |
| `academy_gate_checked` | `academy_gate_passed` | миграция |
| `academy_campus_guide_seen` | `dorm_assigned` | миграция |
| `academy_julius_seen` | — | M2 legacy; не использовать в M1 |
| `sleeper_ready` | `capsule_entered` | миграция |
| `black_sea_stars_seen` | `statue_seen` | миграция после полного осмотра |
| `black_sea_sword_seen` | `statue_seen` | миграция после полного осмотра |
| `black_sea_descent_seen` | `b01_completed` | миграция |
| `tide_descent_warning_seen` | `tide_seen` | миграция |
| `demo_m1_completed` | `post_nightmare_demo_completed` | миграция |
| `demo_completed` | `post_nightmare_completed` | tech demo alias |
| `precinct_woke` | — | scene-local; не использовать как гейт |

**Правила:**

1. Новый код пишет только canonical.
2. Aliases читаются, но не создают второй state.
3. Не писать оба флага «на всякий случай»: это маскирует расхождение.
4. После M1 gate aliases можно удалить отдельной задачей A04.

---

## 7. Контракт переходов

| From | Portal | To | Spawn | Required | Sets |
|---|---|---|---|---|---|
| `police_precinct` | `Portals/ToAcademyApproach` | `academy_approach` | `FromPrecinct` | `p05_jett_talked`, `p05_mirror_seen` | `p05_completed` |
| `academy_approach` | `Portals/ToAcademyGate` | `academy_gate` | `FromApproach` | `jett_advice_heard` | `p06_completed` |
| `academy_gate` | `Portals/ToCampus` | `academy_campus` | `FromGate` | `academy_gate_passed` | `p07_completed` |
| `academy_campus` | `Portals/ToSleeper` | `academy_sleeper_center` | `FromCampus` | `dorm_assigned` | `p08_completed` |
| `academy_sleeper_center` | `Portals/ToBlackSea` | `black_sea_platform` | `FromSleeper` | `induction_seen`, `capsule_entered` | `p09_completed` |
| `black_sea_platform` | `Portals/ToCoral` | `tide_descent` | `FromPlatform` | `statue_seen`, `shroud_summoned` | `b01_completed` |
| `tide_descent` | `Portals/ToCoral` | `labyrinth_first_fragment` | `FromDescent` | `b01_completed` | `b02_completed` |
| `labyrinth_first_fragment` | `Portals/ToDescent` | `tide_descent` | `FromCoral` | `b02_completed` | — |
| Z10 `DemoEndZone` | — | M1 final card | — | `shore_first_day_complete`, `camp_night_seen`, **not** `demo_mode_full` | `post_nightmare_demo_completed` |
| Z18 `FinalZone` | `post_nightmare_finale` | finale | — | `demo_mode_full` | `post_nightmare_completed` |

**Финал:** один `scenes/campaign/post_nightmare_finale.tscn`. A04 добавляет в `post_nightmare_finale.gd` ветку по `demo_mode_m1`: M1 ставит `post_nightmare_demo_completed`, tech demo — `post_nightmare_completed`. Второй finale-сцены не создавать.

**Текущие отклонения (FIX, не контракт):**

- `police_precinct/Spawns/Start` = `(0,0.2,14)` вместо камеры.
- `academy_approach` Jet = `(-1.2,0,17.4)` вместо `(-4.8,0,18.0)`.
- `academy_campus` guide = `(3,0,6)` вместо терминала `(-2.5,0.2,4.0)`.
- `academy_sleeper_center` Julius = `(-20,0,-2)` вне M1; `InductionMedic` = `(0,0,-23.4)` вместо `(4.2,0,-20.3)`.
- `tide_descent`/`black_sea_platform` — ступени без коллизионной рампы.
- `DemoEndZone` и `FinalZone` отсутствуют; Z18 сейчас использует прямой портал.

---

## 8. QuestSystem — публичный API

Autoload: `QuestSystem` (`scripts/quests/quest_system.gd`).  
Catalog: `res://resources/quests/quest_catalog.tres`.  
Default scope: `&"forgotten_shore"`.  
`active_scope` по умолчанию `&""`; активируется только B03.

### 8.1. Сигналы

```gdscript
signal catalog_loaded(scope: StringName)
signal quest_started(quest: QuestDefinition)
signal quest_progressed(quest: QuestDefinition, objective: QuestObjective, progress: int, required: int)
signal quest_objective_completed(quest: QuestDefinition, objective: QuestObjective)
signal quest_completed(quest: QuestDefinition)
signal reward_granted(quest: QuestDefinition, reward: QuestReward)
signal tracked_quest_changed(quest: QuestDefinition)
signal journal_changed
signal message_requested(text: String, tone: StringName)
```

### 8.2. Методы

```gdscript
func activate_scope(scope: StringName = DEFAULT_SCOPE) -> void
func deactivate_scope() -> void
func is_scope_active() -> bool
func show_message(text: String, tone: StringName = &"info") -> void

func get_definition(quest_id: StringName) -> QuestDefinition
func get_state(quest_id: StringName) -> StringName
func is_active(quest_id: StringName) -> bool
func is_completed(quest_id: StringName) -> bool
func get_objective_progress(quest_id: StringName, objective_id: StringName) -> int
func get_active_quests() -> Array[QuestDefinition]
func get_completed_quests() -> Array[QuestDefinition]
func get_available_quests() -> Array[QuestDefinition]
func refresh_auto_start() -> void

func start_quest(quest_id: StringName, force := false) -> bool
func complete_quest(quest_id: StringName, force := false) -> bool
func notify_event(event_id: StringName, subject_id: StringName = &"", amount := 1) -> void

func set_tracked_quest(quest_id: StringName) -> bool
func get_tracked_quest() -> QuestDefinition
func get_tracked_objective_text() -> String
func get_tracked_objective() -> QuestObjective
func get_journal_entries() -> Array[QuestJournalEntry]
```

### 8.3. Правила

1. `activate_scope` вызывает только `LabyrinthQuestDirector` при входе в B03.
2. P05–B02 и S00–S15 не активируют scope; `active_scope == &""`.
3. `start_quest` идемпотентен; повторный вызов не сбрасывает прогресс.
4. `notify_event` не создаёт события, если quest не активен/не существует.
5. `reward_claimed` в state обеспечивает идемпотентность наград.
6. `complete_quest` ставит `completion_flag` и вызывает `CampaignGuide`/журнал.
7. M1 end вызывает `deactivate_scope` и `CampaignGuide.clear_external_objective`.

---

## 9. Мировые адаптеры

### 9.1. `QuestNpc`

```gdscript
signal talked(npc_id: StringName)
signal dialogue_started(npc_id: StringName)
signal dialogue_finished(npc_id: StringName)

@export var npc_id: StringName
@export_multiline var display_name := ""
@export var prompt := "Поговорить"
@export var dialogue: DialogueSequence
@export var required_flags: Array[StringName] = []
@export var completion_flag: StringName
@export var start_quest_id: StringName
@export var talk_event: StringName = &"talked"
@export var one_shot := true
@export_range(1.0, 6.0, 0.1) var interaction_radius := 2.2
```

Порядок: `start_quest_id` → dialogue → `completion_flag` → `notify_event(talk_event, npc_id)` → signals.

### 9.2. `QuestPickup`

```gdscript
signal picked_up(pickup_id: StringName)

@export_enum("shard", "blade", "token") var visual_kind := "shard"
@export var item_id: StringName
@export_range(1, 99, 1) var item_count := 1
@export var currency_id: StringName
@export_range(0, 9999, 1) var currency_amount := 0
@export var memory_id: StringName
@export var pickup_flag: StringName
@export var quest_event: StringName = &"collected"
@export var quest_subject: StringName
@export var start_quest_id: StringName
@export var required_flags: Array[StringName] = []
@export_multiline var pickup_text := ""
```

Порядок: grant → `pickup_flag` → `start_quest_id` → `notify_event(quest_event, quest_subject)` → `picked_up`.

### 9.3. `QuestTriggerZone`

```gdscript
extends TriggerZone
@export var quest_event: StringName = &"reached"
@export var quest_subject: StringName
@export var start_quest_id: StringName
@export var set_flag: StringName
@export var required_flags: Array[StringName] = []
```

Порядок: `set_flag` → `start_quest_id` → `notify_event(quest_event, quest_subject)`.

### 9.4. `QuestKillCredit`

```gdscript
signal credited(enemy_tag: StringName)
@export var enemy_tag: StringName = &"carapace"
@export var credit_flag: StringName
@export var kill_event: StringName = &"killed"
```

### 9.5. `CheckpointZone`

```gdscript
signal checkpoint_activated
@export var checkpoint_id: StringName
@export var one_shot := false
```

Пишет `NightmareRunState.set_checkpoint(id, position, true)` и обновляет `FallRecovery`.

### 9.6. `Interactable`

```gdscript
signal interacted(id: StringName)
@export var interaction_id: StringName
@export var prompt := "Взаимодействовать"
@export var radius := 1.5
@export var interact_cue: StringName = &"world_pickup"
@export var interact_volume_db := -4.0
@export var enabled := false
func can_interact_from(point: Vector3) -> bool
func interact() -> void
```

`enabled` по умолчанию `false`; сцена обязана включить.

### 9.7. `TriggerZone`

```gdscript
signal triggered(id: StringName)
@export var trigger_id: StringName
@export var enabled := false
func fire() -> void
```

Одноразовость/условия — в наследнике; `QuestTriggerZone` не сгорает при закрытых флагах.

### 9.8. `LevelPortal`

```gdscript
signal transition_started(destination_scene: String, destination_spawn: StringName)
signal transition_finished(destination_scene: String, destination_spawn: StringName)
signal transition_aborted(reason: String)

@export_file("*.tscn") var destination_scene := ""
@export var destination_spawn: StringName = &""
@export var required_flags: Array[StringName] = []
@export var set_flags_on_use: Array[StringName] = []
@export var one_shot := true
@export var one_shot_flag: StringName = &""
@export var enabled := true
@export var trigger_on_body := true
@export var interactable: Interactable
```

Статические методы:

```gdscript
static func set_pending_spawn(scene_path: String, spawn: StringName, arrival_fade := -1.0) -> void
static func peek_pending_spawn(scene_path := "") -> StringName
static func take_pending_spawn(scene_path: String) -> StringName
static func take_arrival_fade(scene_path: String) -> float
static func clear_pending_spawn() -> void
static func clear_active_transition() -> void
```

---

## 10. Структуры данных

### 10.1. `QuestDefinition`

```gdscript
enum Category { MAIN, SIDE }

@export var id: StringName
@export var scope: StringName = &"forgotten_shore"
@export var code := ""
@export var title := ""
@export var category: Category = Category.SIDE
@export_multiline var summary := ""
@export_multiline var description := ""
@export var prerequisites: Array[StringName] = []
@export var required_quests: Array[StringName] = []
@export var auto_start := true
@export var show_available := true
@export var objectives: Array = []
@export var rewards: Array = []
@export var completion_flag: StringName
```

### 10.2. `QuestObjective`

```gdscript
enum Kind { KILL, COLLECT, INTERACT, REACH, TALK, FLAG, CURRENCY }

@export var id: StringName
@export_multiline var text := ""
@export var kind: Kind = Kind.FLAG
@export var target_id: StringName
@export_range(1, 999, 1) var required_count := 1
@export var optional := false
@export var hidden_until_previous := false
```

`Kind` → event: KILL `killed`, COLLECT `collected`, INTERACT `interacted`, REACH `reached`, TALK `talked`, FLAG `flag`, CURRENCY `currency`.

### 10.3. `QuestReward`

```gdscript
@export var item_id: StringName
@export_range(1, 999, 1) var item_count := 1
@export var currency_id: StringName = &""
@export_range(0, 99999, 1) var currency_amount := 0
@export var memory_id: StringName
@export var flag: StringName
@export_range(0.0, 1000.0, 1.0) var heal_amount := 0.0
@export_multiline var text := ""
```

### 10.4. `QuestCatalog`

```gdscript
@export var scope: StringName = &"forgotten_shore"
@export var quests: Array = []
func build_index() -> Dictionary
```

### 10.5. `QuestJournalEntry` / `QuestJournalObjective`

`QuestJournalEntry`: `id`, `code`, `title`, `category`, `status`, `summary`, `description`, `note`, `tracked`, `objectives`.  
`QuestJournalObjective`: `id`, `text`, `completed`, `optional`, `progress`, `required`.

### 10.6. `DialogueSequence` / `DialogueLine`

`DialogueSequence.lines: Array[DialogueLine]`.  
`DialogueLine`: `speaker: StringName`, `text: String`, `duration: float`, `voice_id: StringName`.

---

## 11. Соглашения по ресурсам

### 11.1. Пути

| Данные | Путь |
|---|---|
| Каталог квестов | `resources/quests/quest_catalog.tres` |
| Базовые квесты | `resources/quests/first_day.tres`, `first_blood.tres`, `azure_blade.tres`, `crystal_cache.tres`, `hunt_pack.tres`, `camp_rest.tres`, `bridge_stand.tres` |
| SQ-FS | `resources/quests/sq_fs_01_ninth_token.tres` … `sq_fs_05_bone_bridge_master.tres` |
| Диалоги post-nightmare | `resources/dialogue/post_nightmare/<event_id>.tres` |
| Диалоги Лабиринта | `resources/dialogue/labyrinth/<npc>_meeting.tres`, `resources/dialogue/labyrinth/sq_fs_*.tres` |
| Карта | `resources/map/locations/<scene_id>.tres` |
| Материалы локаций | `resources/locations/<scene>/materials/*.tres` |
| Аудио | `resources/audio/**` |
| UI | `resources/ui/**`, `resources/rpg_menu/**` |

### 11.2. Правила

1. Только typed `.tres` для игровых данных; JSON — только внешние/импортируемые таблицы.
2. `StringName` для ID; не использовать `String` в новых API.
3. `scope = &"forgotten_shore"` только для Лабиринта; в S00–S15 scope `&""`.
4. SQ: `auto_start=false`, `show_available=false`; старт через `start_quest_id`.
5. `code` — 2-значная строка; SQ 08–12; не менять существующие 01–07.
6. `completion_flag` — snake_case; один квест — один completion flag.
7. `QuestReward` идемпотентен; повторный `complete_quest` не дублирует.
8. Не создавать `QuestOutcomeReward`; исходы — pickup + flags.
9. Не добавлять новые autoload; не менять `project.godot` вне A00.
10. `.tscn` node names из contracts не переименовывать без A00.

### 11.3. Диалоговые ресурсы: канон и текущие файлы

| Canonical | Текущий файл | Действие |
|---|---|---|
| `p05_jett_awakening.tres` | `precinct_wake.tres` | расширить/переписать; speaker `jett` |
| `p05_mirror.tres` | `precinct_mirror.tres` | миграция; `p05_mirror_seen` |
| `p05_exit.tres` | `precinct_exit.tres` | миграция; выход |
| `p06_jett_advice.tres` | `academy_jet.tres` | переписать; `jett_advice_heard` |
| `p06_checkpoint.tres` | `academy_checkpoint.tres` | разделить с P07 |
| `p07_gate.tres` | `academy_checkpoint.tres` (shared) | новый файл; `academy_gate_passed` |
| `p08_campus.tres` | `academy_campus_guide.tres` | терминал/проводник |
| `p09_induction.tres` | `academy_julius.tres` | новый; Рок/Каспер/Кассия |
| `p09_capsule.tres` | `academy_capsule.tres` | миграция; `capsule_entered` |
| `b01_statue.tres` | `black_sea_stars.tres` + `black_sea_sword.tres` | объединить/мигрировать; `statue_seen` |
| `b01_shroud.tres` | — | новый; `shroud_summoned` |
| `b02_descent.tres` | `tide_descent_warning.tres` | миграция; `tide_seen` |
| `b03_camp_night_full.tres` | — | новый; `camp_night_seen` |
| `b03_camp_night_short.tres` | — | новый; без Cassia |

**Правило:** старые файлы не удалять до миграции; `DialogueRunner.speaker_names` должен содержать canonical и legacy alias.

---

## 12. Формат сохранения

`SaveSystem` — единственный слот. Второй save не создавать.

### 12.1. Файл

```text
path: user://campaign_save.bin
magic: SHADOWSLAVE_SAVE
version: 1
format: line(magic) + FileAccess.store_var(payload, true)
```

### 12.2. Payload

```gdscript
{
    "version": 1,
    "scene": "res://scenes/locations/...",
    "position": Vector3,
    "rotation_y": float,
    "saved_at": int,
    "run_state": {
        "flags": { StringName: bool },
        "items": { StringName: int },
        "bestiary": { ... },          # optional
        "quests": {
            StringName: {
                "state": StringName,   # active/completed
                "objectives": { StringName: int },
                "reward_claimed": bool
            }
        },
        "currency": { StringName: int },
        "memories": { ... },          # optional
        "tracked_quest": StringName,  # optional
        "current_beat_id": StringName,# optional
        "checkpoint_id": StringName,  # optional
        "checkpoint_position": Vector3 # optional
    }
}
```

### 12.3. Правила

1. `read_save` отклоняет неверный magic, версию, отсутствие `run_state`.
2. `load_game` сначала `NightmareRunState.restore`, затем смена сцены/позиции.
3. `snapshot`/`restore` — единственный путь сохранения state; не дублировать поля вручную.
4. M1 сохраняет `post_nightmare_demo_completed`; tech demo — `post_nightmare_completed`.
5. Слоты/миграции — P2; для M1 один слот достаточен.
6. Сохранение не должно требовать ручного нажатия на финальной карточке.

---

## 13. Публичные интерфейсы других систем

### 13.1. `NightmareRunState`

Сигналы:

```gdscript
signal flag_changed(name: StringName, value: bool)
signal item_changed(id: StringName, count: int)
signal beat_changed(beat_id: StringName)
signal checkpoint_changed(checkpoint_id: StringName, position: Vector3)
signal bestiary_unlocked(entry_id: StringName, event_id: StringName)
signal quest_changed(quest_id: StringName, state: StringName)
signal quest_objective_changed(quest_id: StringName, objective_id: StringName, progress: int, required: int)
signal currency_changed(currency_id: StringName, amount: int)
signal memory_unlocked(memory_id: StringName)
signal state_reset
signal state_restored
```

Методы:

```gdscript
func reset() -> void
func set_flag(flag_name: StringName, value := true) -> void
func clear_flag(flag_name: StringName) -> void
func has_flag(flag_name: StringName) -> bool
func get_flag(flag_name: StringName, default_value := false) -> bool
func require(flags: Array[StringName]) -> bool

func set_item(id: StringName, count := 1) -> void
func add_item(id: StringName, count := 1) -> void
func remove_item(id: StringName, count := 1) -> bool
func has_item(id: StringName) -> bool
func get_item_count(id: StringName) -> int

func add_currency(currency_id: StringName, amount: int) -> void
func get_currency(currency_id: StringName) -> int
func unlock_memory(memory_id: StringName) -> bool
func has_memory(memory_id: StringName) -> bool

func set_quest_state(quest_id: StringName, state: StringName) -> void
func get_quest_state(quest_id: StringName) -> StringName
func has_quest(quest_id: StringName) -> bool
func get_quest_objective_progress(quest_id: StringName, objective_id: StringName) -> int
func set_quest_objective_progress(quest_id: StringName, objective_id: StringName, progress: int, required := 0) -> void
func get_quest_objectives(quest_id: StringName) -> Dictionary
func mark_quest_reward_claimed(quest_id: StringName) -> void
func is_quest_reward_claimed(quest_id: StringName) -> bool

func set_tracked_quest(quest_id: StringName) -> void
func get_tracked_quest() -> StringName
func get_quest_ids() -> Array[StringName]

func set_checkpoint(checkpoint_id: StringName, position := Vector3.ZERO, has_position := false) -> void
func get_checkpoint_id() -> StringName
func get_checkpoint_position() -> Vector3
func has_checkpoint() -> bool
func has_checkpoint_position() -> bool
func clear_checkpoint() -> void

func snapshot() -> Dictionary
func restore(snapshot_value: Dictionary) -> void
```

### 13.2. `CampaignGuide`

```gdscript
signal objective_changed(text: String, base_text: String, idle_step: int)
signal thought_shown(thought_id: StringName, text: String)
signal journal_changed

func set_external_objective(text: String, source: StringName = &"external") -> void
func clear_external_objective(source: StringName = &"") -> void
func has_external_objective() -> bool
func get_display_objective() -> String
func get_base_objective() -> String
func get_current_beat_id() -> StringName
```

Пост-Кошмар использует `set_external_objective`; Лабиринт — `QuestSystem` + HUD; S00–S15 — beat-цели.

### 13.3. `SaveSystem`

```gdscript
signal saved(slot: String)
signal loaded(slot: String)
signal save_failed(reason: String)

const DEFAULT_SAVE_PATH := "user://campaign_save.bin"
const SAVE_VERSION := 1
const SAVE_MAGIC := "SHADOWSLAVE_SAVE"

func has_save() -> bool
func save_game(slot: String = "quick") -> bool
func build_snapshot() -> Dictionary
func read_save() -> Dictionary
func load_game(slot: String = "quick") -> bool
```

### 13.4. `AudioDirector`

```gdscript
signal caption_requested(text: String)

func play_music(cue_id: StringName, fade := 2.0) -> void
func stop_music(fade := 1.0) -> void
func set_music_intensity(value: float) -> void
func play_ambience(zone_id: StringName, fade := 2.0) -> void
func stop_ambience(fade := 1.0) -> void
func play_sfx(cue_id: StringName, position := Vector3.INF, volume_offset_db := 0.0) -> bool
func play_ui(cue_id: StringName, volume_offset_db := 0.0) -> bool
func play_voice(line_id: StringName) -> bool
func duck_music(amount_db: float, duration: float) -> void
func set_reverb_profile(profile: StringName) -> void
func push_reverb_profile(profile: StringName) -> void
func pop_reverb_profile(profile: StringName) -> void
func get_reverb_profile() -> StringName
func apply_accessibility(captions_enabled: bool, mono: bool, dynamic_range: int) -> void
func apply_pause_policy(paused: bool) -> void
```

### 13.5. `DialogueRunner` / `DialogueManager`

`DialogueRunner`:

```gdscript
signal line_started(line: DialogueLine, index: int, count: int)
signal finished
@export var subtitles: SubtitleUI
@export var speaker_names: Dictionary
var fast_mode := false
var running := false
func run(sequence: DialogueSequence) -> void
func advance() -> void
func display_name(speaker: StringName) -> String
```

`DialogueManager`:

```gdscript
signal bark_requested(bark: BarkLine)
signal bark_cleared
func load_barks(path: String = "") -> bool
func get_bark(context: StringName) -> BarkLine
func show_bark(context: StringName, force := false) -> BarkLine
func request_bark(context: StringName, force := false) -> BarkLine
func set_barks_suppressed(value: bool) -> void
```

### 13.6. `GameplayHud`

```gdscript
@onready var prompt: InteractionPromptUI
@onready var objective_line: ObjectiveLine
@onready var dialogue_runner: DialogueRunner
@onready var quest_toast: QuestToast
@onready var hint: Label
@onready var tide: TideIndicator
func show_hint(text: String, duration := -1.0) -> void
```

### 13.7. `MapDefinition` / `MapMarker`

```gdscript
# MapDefinition
func visible_markers(flags: Dictionary) -> Array[MapMarker]
func marker_by_id(marker_id: StringName) -> MapMarker

# MapMarker
@export var id: StringName
@export var label := ""
@export var quest_id: StringName = &""
@export var show_when_flag: StringName = &""
@export var hide_when_flag: StringName = &""
func is_visible_with(flags: Dictionary) -> bool
```

`MapScreen` обязан передавать flags из `NightmareRunState.snapshot()`, а не `{}`.

### 13.8. `TideController`

```gdscript
@export var water_plane: MeshInstance3D
@export var low_y := -8.0
@export var high_y := 4.0
@export var cycle_seconds := 120.0
@export var gate_threshold := 2.0

func set_phase(value: float) -> void
func is_high_water() -> bool
func get_level() -> float
func get_cycle_progress() -> float
func is_rising() -> bool
func seconds_until_high() -> float
func seconds_until_low() -> float
func high_threshold_level() -> float
```

**Планируется/опционально (A03/A04):**

```gdscript
func get_water_y() -> float
func advance_to_low() -> bool
func advance_to_high() -> bool
```

`QuestTideLock` уже имеет fallback через `get_level()` + `low_y`/`high_y`; `QuestTideWait` требует `advance_to_low/high`. Не создавать второй таймер/второй `TideController`.

---

## 14. Планируемые аддитивные компоненты

### 14.1. `QuestInspectable`

```gdscript
class_name QuestInspectable
extends Interactable

signal inspected(id: StringName)

@export var interaction_id: StringName
@export var prompt := "Осмотреть"
@export var required_flags: Array[StringName] = []
@export var completion_flag: StringName
@export var quest_event: StringName = &"interacted"
@export var quest_subject: StringName
@export var start_quest_id: StringName
@export var one_shot := true

func interact() -> void
```

Порядок: `require` → `start_quest` → `completion_flag` → `notify_event` → `inspected`. Не второй Inspectable-фреймворк.

### 14.2. `QuestChoicePanel`

```gdscript
class_name QuestChoicePanel
extends CanvasLayer

signal choice_selected(choice_id: StringName)

func present(prompt: String, choices: Array[Dictionary]) -> void
func close() -> void
```

`choices[i]`: `{ id: StringName, text: String, flag: StringName, quest_event: StringName, quest_subject: StringName }`.  
Backend A04 слушает `choice_selected`, пишет флаг и `notify_event`; UI не вызывает `QuestSystem` напрямую.

### 14.2.1. `QuestChoiceController` (фактический backend A04)

```gdscript
class_name QuestChoiceController
extends Node

signal presentation_requested(prompt: String, choices: Array[Dictionary])
signal choice_selected(choice_id: StringName)
signal closed

@export var panel: Node
func set_panel(value: Node) -> void
func present(prompt: String, choices: Array[Dictionary]) -> bool
func select(choice_id: StringName) -> bool
func close() -> void
func is_active() -> bool
func get_choices() -> Array[Dictionary]
```

`QuestChoiceController` — backend; `QuestChoicePanel` — UI. Controller вызывает `panel.show_choices()` при наличии метода, panel emits `choice_selected`. Не создавать второй backend.

### 14.3. `QuestTideLock`

```gdscript
class_name QuestTideLock
extends Interactable

@export var tide_controller: Node3D
@export var max_level := -1.0
@export var quest_id: StringName

func can_interact_from(point: Vector3) -> bool
```

**Типизация:** сейчас `TideController` не имеет `class_name`. A03/A04 могут добавить `class_name TideController` (аддитивно) и типизировать поле; до этого использовать `Node3D` и `has_method("get_level")`. Проверка: `tide_controller.get_level() <= max_level`; иначе prompt «Вода слишком высока». Не второй tide controller.

### 14.4. `QuestFinaleZone` (фактический M1/tech finale)

```gdscript
class_name QuestFinaleZone
extends Area3D

enum Mode { M1, FULL }

signal finale_reached(mode: int, completion_flag: StringName)

@export var mode: Mode = Mode.M1
@export var required_flags: Array[StringName] = []
@export var completion_flag: StringName = &"post_nightmare_demo_completed"
@export_file("*.tscn") var finale_scene := "res://scenes/campaign/post_nightmare_finale.tscn"
@export var one_shot := true
@export var player_group: StringName = &"player"
@export_flags_3d_physics var trigger_mask := 2
@export var fade_layer: FadeLayer
func is_finished() -> bool
```

`QuestFinaleZone` — альтернативный контракт A04 для finale; A03 использует `DemoEndZone`/`FinalZone` с теми же флагами. Оба пути ведут в один `post_nightmare_finale.tscn`; не создавать вторую финальную сцену.

---

## 15. Change control

1. Любое изменение ID/сигнала/поля сохранения — новая версия Design Package (`DP-1.1+`) и запись в `docs/DECISIONS.md`.
2. Изменение `project.godot`, autoload, save format — только A00.
3. Изменение quest catalog — A04; A02 присылает entries.
4. Изменение POI — A03 + `poi_manifest.md`; A02/A04 не придумывают ID.
5. Изменение scene node names — A03 + A00; иначе ломаются порталы/тесты.
6. Legacy aliases удаляются только после M1 gate и отдельной задачи A04.
7. Все новые публичные методы должны иметь тест или явный **NOT TESTED**.

---

## 16. Document control

| Поле | Значение |
|---|---|
| Design Package | `DP-1.0` |
| Base commit | `75f1423d536ae63b073f59bb897d13f052cdbe8a` |
| Branch | `demo/integration` |
| Working tree | clean, кроме unstaged `opencode.json`; baseline commit создан |
| Companion docs | `MASTER_PLAN.md`, `FILE_OWNERSHIP.md`, `AGENT_TASKS.md` |

## 17. Stage 5 additions (2026-11-03)

### 17.1. Academy segment

```gdscript
# scenes/locations/academy_playable/academy_grounds_playable.tscn
# scenes/locations/academy_playable/academy_sleeper_center_playable.tscn
class_name AcademyPlayableLocation
extends GreyboxLocation

@export var academy_scene_kind: StringName = &"grounds"   # grounds | sleeper
@export var quest_director_path: NodePath = ^"AcademyGameplayDirector"
```

- Scope: `academy`; catalog `resources/quests/academy/quest_catalog_academy.tres` (24 quests).
- `QuestSystem` loads both catalogs, but `get_active_quests()/get_completed_quests()/get_available_quests()/start_quest()` filter by `active_scope`.
- Entry: main menu `AcademyButton` → `start_academy()` sets `academy_chapter_started`, beat `AC01`, then loads the grounds scene.
- Portal chain: `AcademyGameplayDirector/ToSleeper` ↔ `ToGrounds`; spawns `FromGrounds`/`FromSleeper`.
- Red gate: closed until `academy_gate_passed`; `GateBlocker` is a child of `AcademyGameplayDirector`.

### 17.2. Cutscene framework

```gdscript
# autoload
CutsceneDirector

signal cutscene_started(definition: CutsceneDefinition)
signal cutscene_finished(definition: CutsceneDefinition, result: int)
signal cutscene_skipped(definition: CutsceneDefinition, elapsed: float)
signal cutscene_aborted(definition: CutsceneDefinition, reason: String)

func start_stage(stage: CutsceneStage) -> bool
func play_stage(stage: CutsceneStage) -> int
func is_playing() -> bool
func request_skip(force := false) -> bool
func abort(reason := "") -> void
func notify_event(name: StringName) -> void
func wait_for_event(name: StringName, timeout := 10.0) -> bool
```

- Manifest: `resources/cutscene/m1/*.tres`; script: `scripts/cutscene/content/m1/*.gd`.
- Stage lives in the location scene as `Cutscene/<Name>`; fallback shots/markers come from the scene's `Shots/` and `Spawns/`.
- `completion_flags` are applied on COMPLETED **and** SKIPPED; `once_flag` prevents replay. M1 cutscenes: `P05Wake`, `P05Mirror`, `P09Induction`, `P09Capsule`, `B01Shroud`.
- `GreyboxLocation.play_cutscene(stage_name)` is the only location-side entry; dialogue fallback remains if the stage is missing.

### 17.3. Input rebinding

```gdscript
class_name InputBindings
const ACTIONS: Array[StringName]
const GAMEPAD_DEFAULTS: Dictionary
static func default_gamepad_events(action: StringName) -> Array

class_name InputBindingRow
signal binding_changed(action: StringName, message: String)
func setup(settings: GameSettings, action_id: StringName, minimum_width := 240.0)
```

- `GameSettings` stores only overrides in `user://settings.cfg` section `input`; no override → `project.godot` defaults + gamepad defaults.
- `InputBindingRow` is shared by main menu and pause; Backspace/Delete clears, Esc cancels.
- Gamepad defaults are appended only when an action has no override; `cutscene_skip` is owned by `CutsceneDirector`.

**Конец INTEGRATION_CONTRACTS.**
