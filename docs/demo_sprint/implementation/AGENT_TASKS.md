# AGENT TASKS — Shadow Slave / Design Package DP-1.0

**Дата:** 2026-11-03  
**Статус:** production plan after DP-1.0 lock.  
**Правило:** задачи выполняются только после утверждения `MASTER_PLAN.md`, `FILE_OWNERSHIP.md`, `INTEGRATION_CONTRACTS.md`.  
**Приоритеты:** `P0` — блокер M1; `P1` — tech demo / качество; `P2` — полная программа / полировка.  
**Формат ID:** `A<agent>-<NN>`. Backlog-ссылки — `SS-*`, где задача уже есть; `M1-*` — новые M1-задачи, которые нужно добавить в BACKLOG в W0.

---

## 0. Правила выполнения

1. **Один файл — один владелец.** См. `FILE_OWNERSHIP.md`.
2. **Не начинать с P1/P2, пока P0 M1 не зелёный.**
3. **Не менять общие сцены/скрипты одновременно.** Shared-file — через `docs/demo_sprint/implementation/ACTIVE_CLAIMS.md` и A00.
4. **Не добавлять autoload, QuestSystem, inventory, HUD, interactor, tide controller.**
5. **Каждая задача заканчивается отчётом:** что изменено, какой тест запущен, что **NOT TESTED**.
6. **Placeholder маркируется** в имени/отчёте; запрещено называть его финальной моделью.
7. **Не коммитить и не push.** Коммит — только A00 после интеграции.

---

## 1. Критический путь M1

```text
A00-01 freeze
  → A04-01 canonical flags
  → A03-01 P05 cell/Jet/mirror
  → A03-02 P06 Jet/checkpoint
  → A03-03 P07 gate/Nephis
  → A03-04 P08 terminal
  → A03-05 P09 Rock/Kasper/Cassia/medic
  → A03-06 B01 statue/shroud
  → A03-07 B02 ramp
  → A03-08 G1–G5 + Z10 DemoEndZone
  → A01-01…08 dialogues
  → A04-02/03/04/08/09/10 state/quest/save/final
  → A05-01 E01
  → A06-01/02/06 placeholders/animator
  → A07-01…06 art readability
  → A08-01/02/03/04/09 HUD/choice/map/final/menu
  → A09-01…06 audio/VFX
  → A10-03/04/06/07/10 QA
  → A00-07 M1 gate
```

**M1 не требует:** Z11–Z18, SQ-FS, 16-минутного прилива, штормового сценария, финальных моделей Джет/Джулиуса/Рок/Каспер/Кассия, 4K, локализации.

---

## 2. A00 — Technical Director / Integration

| ID | Pri | Task | Depends | Acceptance | Backlog |
|---|---|---|---|---|---|
| **A00-01** | P0 | Заморозить дерево и получить чистый baseline: `git status`, `--import`, полный GUT, лог | — | import exit 0; полный GUT **0 fail**; лог сохранён; если 633/634 — задача не закрыта | SS-001 |
| **A00-02** | P0 | Создать `export_presets.cfg` и Windows build; запустить `build/ShadowSlave.exe` | A00-01 | preset есть; build запускается; меню → демо → выход; лог экспорта exit 0 | SS-002, SS-022 |
| **A00-03** | P0 | Утвердить DP-1.0: `MASTER_PLAN`, `FILE_OWNERSHIP`, `AGENT_TASKS`, `INTEGRATION_CONTRACTS`; зафиксировать версию/hash | Stage 3 | 4 документа существуют; ID уникальны; hash совпадает с HEAD; `opencode.json` остаётся локальным unstaged | — |
| **A00-04** | P0 | Зафиксировать 10 autoload и правило `MCPRuntime` только для dev; релизный build без MCPRuntime | A00-03 | список autoload совпадает с `project.godot`; release build не содержит MCPRuntime | SS-017, SS-073 |
| **A00-05** | P0 | Ввести shared-file gate: `ACTIVE_CLAIMS` + подтверждение A00; запретить одновременные правки общих сцен/скриптов | A00-03 | каждый shared-file claim имеет владельца, цель и окно; конфликтов нет | INT-01 |
| **A00-06** | P0 | Интегрировать M1-задачи A01–A09; разрешать только file-level изменения | A00-05, A03-01…08, A04-01/02/03/05/08/10/12, A01-01…08, A05-01, A06-01/02/06, A07-01…06, A08-01/04/09, A09-01…06 | M1 цепочка проходит в редакторе; флаги канонические; нет новых autoload | — |
| **A00-07** | P0 | Провести M1 gate: build + manual + GUT + save/load | A00-02, A00-06, A10-07 | все пункты §12.1 `MASTER_PLAN` PASS; иначе FAIL с причинами | SS-003, SS-025 |
| **A00-08** | P1 | Разрешить tech demo Z11–Z18 только после M1 PASS; зафиксировать `demo_mode_full` | A00-07 | M1 PASS; tech demo scope утверждён; Z11–Z18 не начаты раньше | — |
| **A00-09** | P1 | Синхронизировать README/AGENTS/DECISIONS с фактическим состоянием (без ложных PASS) | A00-07 | числа/сцены/статусы совпадают с кодом; NOT TESTED сохранены | SS-069 |
| **A00-10** | P2 | Обновить roadmap M2–M7 после M1/tech demo | A00-08 | roadmap имеет зависимости, ресурсы, критерии; не обещает сроки без оценки | — |

---

## 3. A01 — Narrative & Story

| ID | Pri | Task | Depends | Acceptance | Backlog |
|---|---|---|---|---|---|
| **A01-01** | P0 | P05: `p05_jett_awakening.tres`, `p05_mirror.tres`, `p05_exit.tres`; Джет у койки; флаги `p05_jett_talked`, `p05_mirror_seen`; без повторной выдачи Плаща | A00-03 | диалоги существуют; speaker `jett`; флаги ставятся один раз; повторный вход не дублирует | M1-01 |
| **A01-02** | P0 | P06: `p06_jett_advice.tres`; три совета; `jett_advice_heard`; barks машины/стены/вывески | A00-03 | Джет говорит у машины; флаг ставится; портал требует флаг; текст каноничен | M1-02 |
| **A01-03** | P0 | P07: `p07_gate.tres`; проверка охраны; силуэт Нефис; `academy_gate_passed`, `nephis_seen_at_gate` | A00-03 | охрана не блокирует; Нефис молчит; флаги ставятся | M1-03 |
| **A01-04** | P0 | P08: `p08_campus.tres`; терминал/проводник; `dorm_assigned` | A00-03 | терминал выдаёт «Sleeper Center, сектор B»; флаг ставится | M1-04 |
| **A01-05** | P0 | P09: `p09_induction.tres` (Рок, Каспер, Кассия), `p09_capsule.tres`, time-skip cards; `induction_seen`, `kasper_met`, `cassia_seen`, `academy_month_passed`, `capsule_entered` | A00-03 | Рок/Каспер/Кассия присутствуют; капсула требует induction; таймскип не повторяется | M1-05 |
| **A01-06** | P0 | B01: `b01_statue.tres`; статуя, звёзды, меч, Плащ; `statue_seen`, `shroud_summoned` | A00-03 | Плащ призывается один раз; без награды; портал требует оба флага | M1-06 |
| **A01-07** | P0 | B02: `b02_descent.tres` (опционально); `tide_seen`; предупреждение о приливе | A03-07 | переход не зависит от `tide_seen`; текст не обещает таймер | M1-07 |
| **A01-08** | P0 | B03: `b03_camp_night_full.tres`, `b03_camp_night_short.tres`; `camp_night_seen`; финальная карточка M1 | A03-08 | полный/короткий вариант; финал не запускается без `first_day`; карточка «ПЕРВЫЙ ДЕНЬ» | M1-08 |
| **A01-09** | P1 | Черновики SQ-01…03 (Тео, эхо, «Правда без лжи»); передать A02/A00 review | A02-01…03 | текст не противоречит канону; нет новых глобальных флагов | SS-032…034 |
| **A01-10** | P0 | Канонические speaker names: `jett` (alias `jet`), `rock`, `kasper`, `cassia`, `medic`, `theo`; убрать дубли; передать A04 | A04-01 | список утверждён; display-имена совпадают с текстом; A04-12 применяет в `DialogueRunner` | M1-09 |

---

## 4. A02 — Side Quest & Content

| ID | Pri | Task | Depends | Acceptance | Backlog |
|---|---|---|---|---|---|
| **A02-01** | P0 | SQ-01 `sq_fs_01_ninth_token.tres`: code 08, SIDE, `auto_start=false`, `show_available=false`, objectives Z02/Z05/Z06, `sq_fs_01_complete` | A00-07, A03-09, A04-03 | `.tres` валиден; старт через token; награда идемпотентна; каталог обновлён A04 | SS-032 |
| **A02-02** | P0 | SQ-02 `sq_fs_02_echo_tunnel.tres`: code 09, prerequisite `sq_fs_01_complete`, Z09, echo polyp, quiet path | A02-01 | квест стартует из Z09; есть путь без боя; `sq_fs_02_complete` | SS-033 |
| **A02-03** | P0 | SQ-03 `sq_fs_03_truth_without_lies.tres`: code 10, prerequisite `sq_fs_02_complete`, Theo, choice, `sq_fs_03_resolved` | A02-02, A08-02 | 3 варианта; Flaw не даёт лжи; последствия локальны | SS-034 |
| **A02-04** | P2 | SQ-04 `sq_fs_04_salt_box.tres`: code 11, Z11, tide lock, 3 levers | A04-07 | шкатулка доступна только в отлив; `sq_fs_04_complete` | SS-076 |
| **A02-05** | P1 | SQ-05 `sq_fs_05_bone_bridge_master.tres`: code 12, Z14, alpha, kill/tide/spare | A05-03 | 3 исхода; `sq_fs_05_resolved`; награда без дубля | SS-077 |
| **A02-06** | P0 | `labyrinth_narrative_director.gd`: runtime-объекты SQ; не менять `LabyrinthQuestDirector` | A00-07, A03-08, A04-05 | SQ-01…03 появляются в runtime; существующие 7 квестов не ломаются | SS-038 |
| **A02-07** | P1 | Reachability-план: 32 POI SQ + 7 базовых; передать A10 | A10-06 | все цели достижимы; каждый провал объяснён; нет soft-lock | — |
| **A02-08** | P0 | Зафиксировать: SQ не в M1; не добавлять SQ в P05–B02/Z01–Z10 | A00-03 | M1 не содержит SQ; tech demo включает только разрешённые | D-18 |

---

## 5. A03 — World & Level

| ID | Pri | Task | Depends | Acceptance | Backlog |
|---|---|---|---|---|---|
| **A03-01** | P0 | P05: `Spawns/Start` → `(5.0,0.2,-18.2)` в `CellBlock`; Джет у койки; `InterrogationMirror` в допросной; выход во двор | A04-01, A01-01 | старт в камере; Джет/зеркало доступны; маршрут камера → допросная → двор; нет застревания в решётках | M1-01 |
| **A03-02** | P0 | P06: Джет `(-4.8,0,18.0)`; КПП; портал; не блокировать дорогу | A01-02 | путь от `(1.5,0.2,18.5)` до `(0,0.2,-18.5)` свободен; Джет у машины | M1-02 |
| **A03-03** | P0 | P07: `GateGuard`; силуэт Нефис; арка/портал; проверка не блокирует | A01-03 | проход `(0,0.2,21.5)` → арка → `(0,0.2,-13)`; Нефис виден, не интерактивен | M1-03 |
| **A03-04** | P0 | P08: терминал `(-2.5,0.2,4.0)`; убрать/сделать optional `CampusGuide`; портал | A01-04 | терминал читается; цель ведёт к Sleeper Center; нет дубля NPC | M1-04 |
| **A03-05** | P0 | P09: убрать Джулиуса из M1; `InductionMedic` `(4.2,0,-20.3)`; Рок `(0,0,-23.4)`, Каспер `(2.5,0,-21.5)`, Кассия `(-3,0,-22.5)`; капсула | A01-05, A06-02 | все NPC не блокируют проход; капсула — единственный путь; Julius отсутствует | M1-05 |
| **A03-06** | P0 | B01: `Puppeteer's Shroud` inspectable; статуя/звёзды/меч; портал | A01-06 | Плащ доступен после статуи; `shroud_summoned`; спуск не блокирован | M1-06 |
| **A03-07** | P0 | B02: коллизионная рампа B2; убрать ступенчатую коллизию; портал | A04-01 | вверх/вниз без прыжка; `FromCoral` ведёт наверх | SS-111 |
| **A03-08** | P0 | G1–G5; `DemoEndZone` `POI-Z10-09` + `demo_end_zone.gd`; Z10 костёр/чекпоинт; M1 финал | A04-02 | Z04/Z11/Z08/Z05/Z03 проходимы; Z10 финал срабатывает один раз; route-тест запускает A10 | SS-005…009 |
| **A03-09** | P0 | Сверить все POI с `poi_manifest.md`; обновить координаты; не придумывать ID | A00-03 | 100% POI имеют сцену/узел/статус; дублей нет | — |
| **A03-10** | P1 | Z11–Z18 tech demo: G2, Z15/Z18, Z13/Z16, финальный портал | A00-08 | route_walk; `FinalZone`; нет soft-lock | SS-041…046 |
| **A03-11** | P1 | Route/boundary: `route_walk`, `route_reachability`, `boundary_audit`; 0 ghost floor на main route | A03-08, A10-03 | 51/51 или каждый провал объяснён; 18/18 центров; 48/48 маркеров | SS-010 |

---

## 6. A04 — Gameplay & Quest Systems

| ID | Pri | Task | Depends | Acceptance | Backlog |
|---|---|---|---|---|---|
| **A04-01** | P0 | Канонические флаги + aliases: `jet`→`jett`, `precinct_mirror_seen`→`p05_mirror_seen`, `academy_jet_seen`→`jett_advice_heard`, `academy_gate_checked`→`academy_gate_passed`, `sleeper_ready`→`capsule_entered`, `black_sea_*`→`statue_seen`, `demo_m1_completed`→`post_nightmare_demo_completed`, `demo_completed`→`post_nightmare_completed` | A00-03 | новые записи только canonical; aliases читаются; нет двойной записи | M1-09 |
| **A04-02** | P0 | `LevelPortal`-гейты P05–B02: required/set flags, idempotent; значения на порталах выставляет A03 | A03-01…07 | каждый портал требует канонический флаг; повторный вход не ломает; сцены не правит A04 | M1-10 |
| **A04-03** | P0 | Scope isolation: `QuestSystem.active_scope == &""` в P05–B02/S00–S15; активация только B03; deactivate на M1 end | A04-01 | тест: вне Лабиринта квесты не стартуют; в B03 scope `forgotten_shore` | SS-014 |
| **A04-04** | P0 | Проверить `start_quest_id` в QuestNpc/Pickup/Trigger: порядок `start_quest` → `notify_event`; тест auto_start=false | A00-03, A04-03 | SQ стартует до прогресса; повторный контакт не дублирует; тест на синтетическом квесте | SS-038 |
| **A04-05** | P0 | `QuestInspectable`: аддитивный `Interactable` для зеркала/плаща/улик; `start_quest_id`, `completion_flag`, `quest_event`, `required_flags` | A03-06 | объект работает; нет второго Inspectable-фреймворка; тест | SS-037 |
| **A04-06** | P1 | Backend `QuestChoicePanel`: сигнал `choice_selected(choice_id)`, запись флага, `sq_fs_03_resolved`; без нового dialogue engine | A00-03 | 3 варианта; выбор пишет флаг; повтор не дублирует | SS-035 |
| **A04-07** | P2 | `QuestTideLock` + `TideController.advance_to_low/high`; проверка `get_level()`; без второго таймера | A03-07 | шкатулка доступна только в отлив; ожидание не блокирует | SS-036 |
| **A04-08** | P0 | Save/load: F5/F9, `NightmareRunState.snapshot/restore`, сцена/позиция; canonical flags | A04-01 | live save/load в другой сцене; квесты/флаги сохраняются | SS-130 |
| **A04-09** | P0 | `MapDefinition.visible_markers(flags)` / `MapMarker.hide_when_flag` контракт; flags из `NightmareRunState.snapshot()`; тест | A04-01 | скрытые маркеры не видны; API отдаёт корректный список; UI-фикс — A08-03 | SS-039 |
| **A04-10** | P0 | M1 final logic: `post_nightmare_demo_completed`, `CampaignGuide.clear_external_objective`, `QuestSystem.deactivate_scope`, save; tech demo - `post_nightmare_completed`; сцену вызывает A03 | A03-08, A08-04 | M1 карточка один раз; tech demo отдельный флаг; нет soft-lock; A04 не правит `scenes/locations/**` | M1-11 |
| **A04-11** | P1 | Tech demo final Z18: `FinalZone` → `post_nightmare_finale`; `demo_mode_full` | A00-08 | Z18 финал; возврат в меню; отдельный флаг | SS-020 |
| **A04-12** | P0 | `DialogueRunner.speaker_names`: canonical `jett`/`rock`/`kasper`/`cassia`/`medic`/`theo` + legacy aliases; без дублей | A01-10, A04-01 | canonical отображаются; старые alias читаются; тест | M1-09 |

---

## 7. A05 — Combat & Enemy AI

| ID | Pri | Task | Depends | Acceptance | Backlog |
|---|---|---|---|---|---|
| **A05-01** | P0 | E01: раненый карапакс 65 HP, медленный замах, уязвимый сустав; не блокирует выходы | A03-08, A06-06 | бой проходим; HP/урон согласованы; ручной E01 | SS-012 |
| **A05-02** | P1 | E02: 3 карапакса в Z13; групповой бой; 3–5 мин | A00-08, A05-01 | все 3 убиваются; нет одновременного стана; ручной | SS-059 |
| **A05-03** | P1 | E03: 2 карапакса на Z14; мост не блокируется | A00-08, A05-01 | проход по мосту; враги не сталкивают в пропасть без шанса | SS-012 |
| **A05-04** | P0 | Respawn врагов после смерти игрока: HP/позиция согласованы с чекпоинтом | A04-08 | после смерти нет «полуживых» врагов; тест | SS-011 |
| **A05-05** | P1 | Weak spot hurtbox-множитель; Inspectable не влияет на урон напрямую | A05-01 | удар в сустав > обычного; тест | SS-058 |
| **A05-06** | P1 | Group attack token: 1–2 атакующих, остальные давят | A05-02 | нет 3 одновременных атак; тест | SS-059 |
| **A05-07** | P1 | Интегрировать hit/death клипы карапакса/личинки в состояния A05; клипы создаёт A06 | A06-06, A06-10 | 2–3 клипа; нет процедурного flinch в финале; A05 не правит `assets/characters/**` | SS-121 |
| **A05-08** | P1 | Combat HUD target switching/hide | A08-01 | цель меняется; полоса скрывается после боя | SS-118 |

---

## 8. A06 — Character & Animation

| ID | Pri | Task | Depends | Acceptance | Backlog |
|---|---|---|---|---|---|
| **A06-01** | P0 | Jet placeholder: Mannequin `mass_female`, 5 клипов (idle/talk/walk/point/leave), LOD0 | A00-03 | в P05/P06 не выглядит сломанным; помечен placeholder | SS-029 |
| **A06-02** | P0 | Rock/Kasper/Cassia placeholders для P09; Cassia также Z08 | A00-03 | 3 NPC видны; не блокируют; помечены placeholder | M1-05 |
| **A06-03** | P1 | Julius M2 model/rig/клипы; не в M1 | A00-07 | M2 сцена; M1 не содержит Julius | SS-030 |
| **A06-04** | P1 | Nephis/Cassia финальные модели + LOD1/2 | A00-07, A03-08 | 2 GLB + rig + клипы; Z08/Z10 | SS-078 |
| **A06-05** | P1 | NPC AnimationTree: blend idle/talk/walk/point | A00-07, A06-01/02 | 3 перехода; нет резкой смены позы | SS-120 |
| **A06-06** | P0 | Стабилизировать `Mannequin`/animator: `_prepare_native_locomotion`, no parse errors | A00-01 | `test_labyrinth_first_fragment` 13/13; нет warning | SS-016 |
| **A06-07** | P1 | LOD1/2 для v3/Hero/Carapace/Mountain King; замер tri | A06-04/05 | 3 LOD; budget; скриншот | SS-054 |
| **A06-08** | P2 | Финальная Sunny Nightmare | A00-08 | GLB + rig + LOD + 10 клипов | SS-050 |
| **A06-09** | P2 | Theo model (M3) | A02-01 | GLB + idle/talk/kneel/dead | SS-031 |
| **A06-10** | P1 | Carapace/Larva hit/death clips (assets/animations); передать A05 | A05-01 | 2–3 клипа; LOD0; тест в E01 | SS-121 |

---

## 9. A07 — Environment Art

| ID | Pri | Task | Depends | Acceptance | Backlog |
|---|---|---|---|---|---|
| **A07-01** | P0 | P05 art: камера, койка, зеркало, дождь, свет; читаемость | A03-01 | capture из игрового ракурса; зеркало читается | M1-01 |
| **A07-02** | P0 | Academy approach/gate/campus: снег, мокрый асфальт, КПП, арка, галерея | A03-02…04 | нет плоских стен; путь читается | M1-02/03/04 |
| **A07-03** | P0 | Sleeper Center: индукционный зал, 12 капсул, трибуна, холодный свет | A03-05 | зал не пустой; NPC не в геометрии | SS-026 |
| **A07-04** | P0 | B01: статуя/семь звёзд/меч; масштаб; слой Плаща | A03-06 | статуя читается как колосс; Плащ виден | M1-06 |
| **A07-05** | P0 | B02: коралловые ворота, рампа, мокрые стены | A03-07 | спуск читается; нет провала | SS-111 |
| **A07-06** | P0 | Z10 camp: костёр, лежанки, столб, ночь; не перекрывать `DemoEndZone` | A03-08 | финальный кадр; 6+ props | SS-124 |
| **A07-07** | P1 | Z15/Z18 скальные полки; Z02 hero-туша; Z13 скелет; decals | A03-10 | capture; нет кубов | SS-041…044 |
| **A07-08** | P1 | Материалы/PBR: коралл, кость, мокрый камень, металл; без внешних ассетов без лицензии | A07-01…06 | 5 материалов; лицензии; нет фиолетового/неона | SS-045 |
| **A07-09** | P1 | Свет/туман/читаемость; 3 capture-ракурса на зону | A07-01…06 | нет чёрных провалов; UI читается | SS-071 |
| **A07-10** | P1 | Draw calls <1500; MultiMesh/LOD/occlusion | A07-07 | замер 1080p; отчёт | SS-049 |

**Правило A07:** арт-задачи 01–06 выполняются через `assets/environments/**`, `assets/shaders/**` и `resources/locations/**/materials/**`; `scenes/locations/**` правит только A03 по запросу. A07 не перезаписывает сцены локаций.

---

## 10. A08 — UI/UX

| ID | Pri | Task | Depends | Acceptance | Backlog |
|---|---|---|---|---|---|
| **A08-01** | P0 | M1 HUD: цель, HP, выносливость, prompt, субтитры, тост, прилив; без перекрытий | A04-03 | каждая сцена имеет цель; prompt работает; нет наложений | SS-021 |
| **A08-02** | P0 | `QuestChoicePanel` UI: 2–3 варианта, клавиши/мышь, сигнал, фокус | A04-06 | выбор виден; не блокирует pause; тест | SS-035 |
| **A08-03** | P0 | `MapScreen` flags fix: передавать flags из state, а не `{}`; использовать `MapDefinition.visible_markers` | A04-09 | маркеры скрываются; тест; UI-файл принадлежит A08 | SS-039 |
| **A08-04** | P0 | M1 final cards: «ПЕРВЫЙ ДЕНЬ» / «Конец M1» и tech demo «Конец демонстрационного фрагмента»; return to menu; `R`/`Esc` | A04-01, A00-03 | обе карточки; нет зависания; флаги читаются из state | M1-11 |
| **A08-05** | P0 | Pause/settings/credits; MCPRuntime не показывать; громкость/субтитры | A00-02 | pause работает; настройки сохраняются; credits | SS-074 |
| **A08-06** | P1 | Journal/quest screen: 7+5; статусы; tracked; без DEMO-fallback | A00-07, A02-01…03 | 12 квестов; нет дублей; журнал живой | SS-128 |
| **A08-07** | P1 | 4K/ultrawide: 3 разрешения; контраст; скриншоты | A08-01 | 1920×1080, 2560×1440, 3840×2160 | SS-065 |
| **A08-08** | P2 | Реальный inventory/Памяти UI; не выдавать demo за канон | A04-08 | предметы/валюта/Памяти из state | SS-060 |
| **A08-09** | P0 | Main menu: «После Кошмара» entry; «Играть» (Первый Кошмар); credits; demo label | A00-03 | оба входа работают; demo явно помечено | — |

---

## 11. A09 — Audio & VFX

| ID | Pri | Task | Depends | Acceptance | Backlog |
|---|---|---|---|---|---|
| **A09-01** | P0 | M1 ambience/music: участок, академия, море, спуск; без второго микшера | A03-01…07 | 4 зоны; переходы; нет клиппинга | — |
| **A09-02** | P0 | P05/P06 SFX: дождь, машина, шаги, КПП, радио | A01-01/02 | cue существуют; 3D-позиционирование | — |
| **A09-03** | P0 | P09: индукция, толпа, капсула, затемнение | A01-05 | сцена не тихая; капсула читается | — |
| **A09-04** | P0 | B01/B02: ветер, чёрная вода, прилив, кораллы | A01-06/07 | 2 зоны; нет «океана» поверх диалога | — |
| **A09-05** | P0 | Z01–Z10: ветер, кости, костёр, ночь; camp night | A01-08 | финальная сцена; нет обрыва аудио | — |
| **A09-06** | P0 | VFX: тень/Плащ, прилив, брызги; через `scripts/vfx` | A07-04/05 | 3 эффекта; budget; нет второго particle framework | — |
| **A09-07** | P1 | VO placeholders для M1; SAPI помечен; субтитры | A01-10 | 83 реплики или меньше; нет финального VO claim | SS-063 |
| **A09-08** | P1 | Listening test protocol; LUFS/peaks; 3 сцены | A09-01…06 | протокол заполнен; **NOT TESTED** если не слушали | SS-062 |
| **A09-09** | P1 | Storm VFX Z17: молнии, брызги, порывы | A03-10 | шторм читается; FPS | SS-046 |

---

## 12. A10 — QA & Release

| ID | Pri | Task | Depends | Acceptance | Backlog |
|---|---|---|---|---|---|
| **A10-01** | P0 | Baseline full GUT: import, 81 script, 634 test; 0 fail; лог | A00-01 | 0 fail; если 633/634 — FAIL | SS-001 |
| **A10-02** | P0 | Build/clean machine: `build/ShadowSlave.exe`; меню → демо → выход | A00-02 | build запускается; лог | SS-022 |
| **A10-03** | P0 | M1 route test: все сцены, флаги, время, баги | A00-06 | M1 18–25 мин; нет soft-lock; отчёт | SS-003 |
| **A10-04** | P0 | Save/load live: F5/F9, другая сцена, смерть/чекпоинт | A04-08 | состояние/квесты сохраняются; отчёт | SS-130 |
| **A10-05** | P1 | Tech demo route Z18 + 7 квестов + E01–E03 | A00-08 | 50–70 мин; финал; отчёт | SS-003 |
| **A10-06** | P0 | Quest reachability: 7 базовых + SQ-01…03; 32 POI SQ | A02-01…03, A04-03 | все цели достижимы; нет soft-lock | SS-013 |
| **A10-07** | P0 | M1 manual pass: P05 камера → Z10; записать флаги/баги/время | A10-03 | полный проход; видео/скриншоты | SS-003 |
| **A10-08** | P1 | Performance: 1080p ≥60 FPS, draw calls <1500, VRAM <4 GB | A07-10 | 5 сцен; CSV; отчёт | SS-070 |
| **A10-09** | P0 | Clean clone: import, UID, full GUT | A00-02 | чистый clone; 0 fail | SS-023 |
| **A10-10** | P0 | QA report: PASS/FAIL/NOT TESTED; без ложных утверждений | все P0 | отчёт с логами; блокеры перечислены | SS-025 |

---

## 13. Dependency graph (сжато)

```text
A00-01
 ├─ A00-02 ─ A10-02 ─ A00-07
 ├─ A04-01 ─ A03-01…07 ─ A04-02 ─ A03-08
 │                         ├─ A04-10 ─ A10-07 ─ A00-07
 │                         └─ A01-08
 ├─ A01-01…06 ─ A03-01…06
 ├─ A06-06 ─ A05-01 ─ A05-04
 ├─ A06-01/02/06
 ├─ A07-01…06
 ├─ A08-04 ─ A04-10
 ├─ A08-01/02/03/09
 └─ A09-01…06
A00-07 ─ A00-08 ─ A03-10 ─ A05-02/03 ─ A10-05
```

---

## 14. Definition of Done

Задача считается закрытой только если:

1. Изменены только файлы владельца (или есть shared-file claim).
2. Нет нового autoload/quest framework/inventory/HUD/interactor/tide controller.
3. Targeted test запущен и приложен вывод.
4. Если тест не запускался — написано **NOT TESTED**, а не «готово».
5. Placeholder помечен.
6. Отчёт: файлы, флаги, координаты, зависимости, риски.
7. A00 подтвердил интеграцию, если задача меняет общий контракт.

---

## 15. Document control

| Поле | Значение |
|---|---|
| Design Package | `DP-1.0` |
| Base commit | `75f1423d536ae63b073f59bb897d13f052cdbe8a` |
| Branch | `demo/integration` |
| Working tree | clean, кроме unstaged `opencode.json`; baseline commit создан |
| Companion docs | `MASTER_PLAN.md`, `FILE_OWNERSHIP.md`, `INTEGRATION_CONTRACTS.md` |

**Конец AGENT_TASKS.**
