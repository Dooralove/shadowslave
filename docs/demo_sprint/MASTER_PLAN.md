# MASTER PLAN — Shadow Slave / Demo & Full Story Program

**Design Package:** `DP-1.0`  
**Дата:** 2026-11-03  
**Автор:** Chat 00 — Technical Director / Integration  
**Статус:** **DESIGN LOCK / READY FOR PRODUCTION PLANNING.** Код и сцены в рамках Stage 3 не переписывались.  
**Базовый commit:** `75f1423d536ae63b073f59bb897d13f052cdbe8a`  
**Ветка:** `demo/integration`  
**Рабочее дерево:** clean, кроме unstaged `opencode.json` (локальная Hyper3D MCP-конфигурация; в baseline не входит).  
**Проверки:** статическое чтение документов, сцен, скриптов и ресурсов; полный ручной проход — **NOT TESTED**; экспортный build — **NOT TESTED**.

> Этот документ — вершина design package. Он не заменяет детальные спецификации, а фиксирует общий объём, порядок, границы и правила интеграции. При противоречии детальный документ правится под этот план, а не наоборот; исключение — канон и решения пользователя.

---

## 0. Design lock — что именно зафиксировано

1. **Один demo spine:** пост-Кошмарная цепочка `main_menu → police_precinct → academy_approach → academy_gate → academy_campus → academy_sleeper_center → black_sea_platform → tide_descent → labyrinth_first_fragment`.
2. **Два acceptance-объёма:** обязательный **M1** до лагеря **Z10** (18–25 минут) и **tech demo** до **Z18** (50–70 минут). M1 принимается первым.
3. **Один QuestSystem.** Новый quest framework, второй журнал, второй инвентарь, вторая валюта и второй HUD запрещены.
4. **Один state:** `NightmareRunState`; **один save:** `SaveSystem`; **один guide:** `CampaignGuide`; **один audio:** `AudioDirector`; **один map:** `MapSystem`.
5. **Один writer на файл.** Владение — в `FILE_OWNERSHIP.md`; общие файлы меняются только через TD.
6. **Дизайн-документы — источник истины по контенту.** Текущая реализация — скелет, а не доказательство финального качества.
7. **Placeholder'ы разрешены, но маркируются.** Ни один mannequin не называется финальной моделью.
8. **Никакой массовой реализации до утверждения DP-1.0.** После утверждения — только задачи из `docs/demo_sprint/implementation/AGENT_TASKS.md`.

---

## 1. Видение и опоры

### 1.1. Видение

Игрок завершает Первый Кошмар и просыпается в мире, который считает его выжившим, но не героем. Пост-Кошмарная глава показывает цену выживания: бюрократию, Академию, индукцию, Чёрное море и первый настоящий берег. Лабиринт — не «подземелье», а первое место, где Санни должен выбрать между одиночеством и людьми.

### 1.2. Пять опор

| Опора | Что означает | Что запрещено |
|---|---|---|
| **Канон прежде удобства** | Джет, Нефис, Кассия, Рок, Каспер, Тео и Флоу не меняют характер ради геймплея | Новые боги, пророчества, воскрешения, романтические линии |
| **Пространство рассказывает** | Следы, свет, запахи, обрывки быта | Восклицательные знаки и «квестовыеNPC» без сцены |
| **Один слой состояния** | Все флаги, предметы, квесты и чекпоинты — в `NightmareRunState` | Второй state/quest/inventory |
| **Честная проходимость** | Каждый гейт имеет понятную цель и обход без soft-lock | «Проходимо по дизайну» без route-теста |
| **Доказательство, а не обещание** | PASS только после build + manual + GUT | Отчёт без лога/прохода |

---

## 2. Программа и объёмы

### 2.1. Полная программа M0–M7

| Этап | Объём | Содержание | Статус |
|---|---|---|---|
| **M0** | Foundation / audit | 10 аудитов, консолидация, baseline, решения | **DONE (docs)**; full GUT не чистый |
| **M1** | Post-Nightmare vertical slice | P05–B03, Z01–Z10, финал у костра | **SKELETON**; canonical M1 не реализован |
| **M2** | Academy | Полная академия: Hollow, общежитие, столовая, додзё, Julius, каст | **NOT STARTED** |
| **M3** | Forgotten Shore Labyrinth | Z01–Z18, 7 базовых квестов, SQ-FS-01…05, прилив | **PARTIAL**; G1–G5 и SQ не готовы |
| **M4** | First Nightmare | S00–S15, P01–N26, финальная карточка | **PARTIAL/85%**; ручной проход NOT TESTED |
| **M5** | Acts C–D | Утёсы, Кость-Хребет, Пепельная пустошь, Древо Души | **DESIGN/BACKLOG** |
| **M6** | Western City | Замок Гунлауга, собор, Чёрный Рыцарь | **DESIGN/BACKLOG** |
| **M7** | Release | build, QA, локализация, платформы, кредиты | **NOT STARTED** |

### 2.2. M1 vs tech demo

| Параметр | M1 | Tech demo |
|---|---|---|
| Конец | лагерь Z10, `DemoEndZone` | Z18, `FinalZone` |
| Время | 18–25 мин | 50–70 мин |
| Лабиринт | Z01–Z10 | Z01–Z18 |
| Квесты | 4 завершаемых: `first_day`, `first_blood`, `azure_blade`, `camp_rest`; `crystal_cache` частично | все 7 |
| SQ-FS | нет | SQ-01…03 желательны, SQ-04/05 — P2 |
| Финал | `post_nightmare_demo_completed` | `post_nightmare_completed` |
| Назначение | release gate | показ полного фрагмента |

**Правило:** M1 не блокируется Z11–Z18, SQ-FS, 16-минутным приливом и штормовым сценарием. Tech demo не начинается, пока M1 не принят.

### 2.3. Граница «все модели»

«Все модели» = все модели для **документированного текущего сюжета**: Первый Кошмар, пост-Кошмар, Forgotten Shore, Acts C–D, западный город. Вся веб-новелла за пределами этих документов в объём не входит. Для M1 финальными считаются только те модели, которые прошли pipeline; остальные — помеченные placeholders.

---

## 3. Сюжетный хребет

### 3.1. Восемь сюжетных событий M1

| ID | Сцена | Смысл | Ключевые флаги | Финал |
|---|---|---|---|---|
| **P05** | `police_precinct` | Пробуждение, Джет, зеркало, выход | `p05_jett_talked`, `p05_mirror_seen`, `p05_completed` | `academy_approach` |
| **P06** | `academy_approach` | Джет, три совета, КПП | `jett_advice_heard`, `p06_completed` | `academy_gate` |
| **P07** | `academy_gate` | Проверка, первый силуэт Нефис | `academy_gate_passed`, `nephis_seen_at_gate`, `p07_completed` | `academy_campus` |
| **P08** | `academy_campus` | Направление в Sleeper Center | `dorm_assigned`, `p08_completed` | `academy_sleeper_center` |
| **P09** | `academy_sleeper_center` | Индукция, Рок/Каспер/Кассия, капсула | `induction_seen`, `kasper_met`, `cassia_seen`, `academy_month_passed`, `capsule_entered`, `p09_completed` | `black_sea_platform` |
| **B01** | `black_sea_platform` | Статуя, звёзды, меч, Плащ, спуск | `statue_seen`, `shroud_summoned`, `b01_completed` | `tide_descent` |
| **B02** | `tide_descent` | Спуск к кораллам | `tide_seen` (опц.), `b02_completed` | `labyrinth_first_fragment` |
| **B03** | `labyrinth_first_fragment` | Z01–Z10, Нефис/Кассия, лагерь, ночь | `shore_first_day_complete`, `camp_night_seen`, `post_nightmare_demo_completed` | M1 end |

### 3.2. Канонические имена

- **Джет** — display; canonical NPC ID `jett`; legacy alias `jet`; `JettCar` — только имя визуального пропа.
- **Джулиус** — M2; в M1 его нет. На КПП — `GateGuard`, в кампусе — терминал/проводник.
- **Рок** — `rock`, инструктор P09; **Каспер** — `kasper`, флаг `kasper_met`; **Кассия** — `cassia`.
- **Медик** — `medic`, legacy alias `technician`.
- **Нефис** — `nephis`; один NPC на сцену, без дублей в Z10; для кадра использовать маркеры/видимость.
- **Тео** — `theo`, только M3; в M1 нет.

### 3.3. Что нельзя нарушать

- Санни не получает второй Порок, вторую тень или второе «пробуждение».
- `Puppeteer's Shroud` уже может быть в состоянии; P05/B01 не выдают его повторно с наградой.
- Нефис и Кассия не говорят в P07; Кассия не говорит до Z08.
- Джулиус не появляется в M1.
- В M1 нет таймера прилива и смертельной стены воды; прилив — атмосфера и будущая механика.
- Финальная карточка M1 — у костра Z10, не в Z18.

---

## 4. Мир и уровни

### 4.1. Сцены и переходы

| Сцена | Вход | Выход | Требование | Ставит |
|---|---|---|---|---|
| `police_precinct` | `Spawns/Start` = койка в `CellBlock` | `Portals/ToAcademyApproach` → `academy_approach/FromPrecinct` | `p05_jett_talked`, `p05_mirror_seen` | `p05_completed` |
| `academy_approach` | `FromPrecinct` | `Portals/ToAcademyGate` → `academy_gate/FromApproach` | `jett_advice_heard` | `p06_completed` |
| `academy_gate` | `FromApproach` | `Portals/ToCampus` → `academy_campus/FromGate` | `academy_gate_passed` | `p07_completed` |
| `academy_campus` | `FromGate` | `Portals/ToSleeper` → `academy_sleeper_center/FromCampus` | `dorm_assigned` | `p08_completed` |
| `academy_sleeper_center` | `FromCampus` | `Portals/ToBlackSea` → `black_sea_platform/FromSleeper` | `induction_seen`, `capsule_entered` | `p09_completed` |
| `black_sea_platform` | `FromSleeper` | `Portals/ToCoral` → `tide_descent/FromPlatform` | `statue_seen`, `shroud_summoned` | `b01_completed` |
| `tide_descent` | `FromPlatform` | `Portals/ToCoral` → `labyrinth_first_fragment/FromDescent` | `b01_completed` | `b02_completed` |
| `labyrinth_first_fragment` | `FromDescent` | `Portals/ToDescent` → `tide_descent/FromCoral` | `b02_completed` | — (возврат) |

**Текущий известный разрыв:** `police_precinct/Spawns/Start` сейчас `(0,0.2,14)` во дворе, а канон требует `(5.0,0.2,-18.2)` в камере. Это FIX WP1, не новое решение.

### 4.2. Лабиринт

- **M1:** Z01–Z10; финал `DemoEndZone` `POI-Z10-09` `(-100,18.2,-5)`, радиус 4; активен, если **не** выставлен `demo_mode_full` и нет `post_nightmare_demo_completed`. `demo_mode_m1` выставляется явно для логов, но default — M1.
- **Tech demo:** Z11–Z18; `FinalZone` Z18; портал в `post_nightmare_finale`.
- **G1–G5** — P0: Z04 вход, Z11 лестница, Z08→Z09 рама, Z05→Z06 пол, Z03→Z05 площадка. Без них M1/M3 не принимаются.
- **Z10:** костёр, чекпоинт `CP-SHORE-CAMP`, `DemoEndZone`; не перекрывать костёр.
- **M1 reachability:** `crystal_cache` требует третий осколок в Z14, поэтому в M1 остаётся незавершённым; `hunt_pack`/`bridge_stand` не стартуют. Финал M1 зависит от `first_day`/`camp_night_seen`, а не от всех 7 квестов.

### 4.3. POI

`poi_manifest.md` — единственный источник координат и ID. Формат: `POI-<scene>-<NN>` и `POI-Z<NN>-<NN>`. Запрещено придумывать ID в сценах; если точки нет — добавить в manifest через A03 и проверить коллизию.

---

## 5. Квесты

### 5.1. Семь базовых

| ID | Название | Зона | M1 |
|---|---|---|---|
| `first_day` | Первый день | Z03/Z08/Z10 | **да** |
| `first_blood` | Первая кровь | Z03 | **да** |
| `azure_blade` | Азурный клинок | Z03 | **да** |
| `crystal_cache` | Осколки в костях | Z06/Z09/Z14 | частично |
| `hunt_pack` | Охота в угодьях | Z13 | нет |
| `camp_rest` | Дыхание у огня | Z10 | **да** |
| `bridge_stand` | Костяной мост | Z14 | нет |

### 5.2. Пять SQ-FS (M3)

| ID | Название | Зона | Цепочка | Приоритет |
|---|---|---|---|---|
| `sq_fs_01_ninth_token` | Девятый жетон | Z02→Z05→Z06 | A | M3-P0 |
| `sq_fs_02_echo_tunnel` | Голос из слепого туннеля | Z09 | A | M3-P0 |
| `sq_fs_03_truth_without_lies` | Правда без лжи | Z06 | A | M3-P0 |
| `sq_fs_04_salt_box` | Соляная шкатулка | Z11 | B | M3-P2 |
| `sq_fs_05_bone_bridge_master` | Хозяин костяного моста | Z14 | B | M3-P1 |

**Правила:** SQ не в M1 и не в S00–S15; `auto_start=false`, `show_available=false`; старт через `start_quest_id`; награды идемпотентны; новые глобальные флаги не вводятся; только `sq_fs_*` и локальные мировые состояния.

### 5.3. Квестовые расширения

| Расширение | Статус | Решение |
|---|---|---|
| `start_quest_id` в QuestNpc/QuestPickup/QuestTriggerZone | **уже есть** | проверить порядок `start_quest` → `notify_event` |
| `QuestInspectable` | **нет** | аддитивный `Interactable` для улик/зеркала/плаща |
| `QuestChoicePanel` | **нет** | UI + сигнал, не новый framework |
| `QuestTideLock` | **нет** | проверка `TideController.get_level()` |
| `advance_to_low/high` | **нет** | методы `TideController`, не второй таймер |
| `QuestOutcomeReward` | **не нужен** | исходы через world pickup + flags |
| `MapMarker.hide_when_flag` | поле есть | `MapScreen` должен передавать flags |

---

## 6. Персонажи, модели, анимации

### 6.1. M1 cast

| NPC | ID | Сцена | Статус | Анимация |
|---|---|---|---|---|
| Джет | `jett` (alias `jet`) | P05, P06 | Mannequin placeholder | procedural idle/talk; финальная — M2 |
| Дежурный | `desk_officer` | P05 | Mannequin | procedural; без диалога |
| Офицер допросной | `interrogation_officer` | P05 | Mannequin | procedural |
| Охрана КПП | `gate_guard` | P06/P07 | Mannequin `police_guard` | procedural |
| Терминал кампуса | `campus_terminal` | P08 | interactable | без модели |
| Медик | `medic` | P09 | Mannequin | procedural |
| Рок | `rock` | P09 | **MISSING** | placeholder до M2 |
| Каспер | `kasper` | P09 | **MISSING** | placeholder до M2 |
| Кассия | `cassia` | P09/Z08/Z10 | Mannequin `mass_female` | procedural; финальная — M2/M3 |
| Нефис | `nephis` | P07/Z08/Z10 | Mannequin `mass_female` | procedural; финальная — M2/M3 |
| Джулиус | `julius` | M2 only | Mannequin placeholder | **не в M1** |
| Тео | `theo` | M3 | **MISSING** | M3 |

### 6.2. Чего не хватает

- Финальных моделей/rig/клипов: Jett, Julius, Rock, Kasper, Cassia, Nephis, Theo.
- NPC animation tree с blend; сейчас Mannequin меняет позы без плавного перехода.
- Facial/lip sync, turn-in-place, foot IK — P1/P3.
- LOD1/2 для v3/Hero/Carapace/Mountain King — P1.
- Отдельных клипов hit/death для врагов — P1.

**Правило:** M1 может быть принят с помеченными placeholders; tech demo — только если placeholders не выдаются за финал. Финальный каст — M2/M3.

---

## 7. Бой

| Встреча | Зона | Состав | M1 | Статус |
|---|---|---|---|---|
| **E01** | Z03 | 1 раненый карапакс, 65 HP | **да** | код/тесты есть; ручной бой NOT TESTED |
| **E02** | Z13 | 3 карапакса | нет | групповой бой NOT TESTED |
| **E03** | Z14 | 2 карапакса, мост | нет | NOT TESTED |
| **E04** | sandbox | Mountain King | нет | cinematic/sandbox |
| **E05** | арены | тестовые | нет | dev |

**M1:** E01 обязателен; weak spot и Azure Blade — желательны, но не блокируют финал. **Tech demo:** E01–E03 обязательны. Групповой AI, weak spot hurtbox, hit/death clips — P1.

---

## 8. UI/UX

- Один HUD: цель, HP, выносливость, prompt, субтитры, тост, прилив.
- Пост-Кошмар: `GreyboxLocation` + `GameplayHud` + `CampaignGuide.set_external_objective`.
- Лабиринт: `LabyrinthQuestDirector` + `QuestSystem` + `GameplayHud`.
- S00–S15: `CampaignGuide`/`BeatDirector`; `QuestSystem.active_scope == &""`.
- Карта: `MapScreen` передаёт flags, а не `{}`; `MapMarker.hide_when_flag` работает.
- Журнал: 7 базовых + 5 SQ; без DEMO-fallback после стабилизации.
- M1 финальная карточка: «ПЕРВЫЙ ДЕНЬ» / «Конец M1»; tech demo: «Конец демонстрационного фрагмента».
- Выбор SQ-03: `QuestChoicePanel`; 2–3 варианта; сигнал; флаг; без второго диалогового движка.

---

## 9. Audio/VFX

- Один `AudioDirector`; шины master/music/ambience/sfx/voice/ui; без второго микшера.
- M1: дождь участка, машина, КПП, гул академии, индукция, чёрная вода, ветер статуи, прилив, костёр.
- VFX: тень/плащ, прилив, брызги, шторм — через существующие `scenes/environment/vfx` и `scripts/vfx`; без второго particle framework.
- VO: SAPI/placeholder помечается; финальный VO — P1. Слуховой тест — **NOT TESTED**.

---

## 10. Техническая архитектура

### 10.1. Autoloads (10, зафиксированы)

`MCPRuntime` (временный), `NightmareRunState`, `DialogueManager`, `MapSystem`, `PlayerMenuSystem`, `PauseMenuSystem`, `CampaignGuide`, `QuestSystem`, `SaveSystem`, `AudioDirector`.

**Правило:** новых autoload для M1/M3 не добавлять. `MCPRuntime` исключается из релизного build. `project.godot` — только TD.

### 10.2. Потоки

```text
MainMenu / N26 finale
  → CampaignEntry / GreyboxLocation
  → NightmareRunState (flags/items/quests/currency/memories/checkpoint)
  → scene portals (LevelPortal)
  → P05…B02: CampaignGuide external objective, QuestSystem inactive
  → B03: LabyrinthQuestDirector activates scope forgotten_shore
  → QuestSystem + QuestNpc/Pickup/Trigger + NightmareRunState
  → M1 DemoEndZone / tech demo FinalZone
  → post_nightmare_finale → MainMenu
```

### 10.3. Запрещённые дубли

- Второй `QuestSystem`, `QuestCatalog`, `QuestJournal`.
- Второй `NightmareRunState`, `SaveSystem`, `CampaignGuide`.
- Второй `Interactor`, `Interactable` framework, `TriggerZone` framework.
- Второй HUD, второй journal UI, второй inventory.
- Второй `TideController`/таймер прилива.
- `QuestOutcomeReward` и любые «reward outcome» классы.

---

## 11. Порядок производства

| Волна | Работа | Выход | Зависит |
|---|---|---|---|
| **W0** | Freeze, DP-1.0, ownership, contracts | этот пакет | Stage 3 |
| **W1** | M1 blockers: P05 cell/Jet, P06 Jet, P07 gate/Nephis, P08 terminal, P09 cast, B01 shroud, B02 ramp, G1–G5, Z10 end | M1 playable | W0 |
| **W2** | M1 content: dialogues, flags, final card, HUD, save | M1 acceptance | W1 |
| **W3** | M1 QA: GUT, build, manual pass | M1 PASS | W2 |
| **W4** | M3 tech demo: Z11–Z18, 7 quests, E01–E03, SQ-01…03 | tech demo | W3 |
| **W5** | M2 Academy / M4 First Nightmare polish | full program | W3 |
| **W6** | M5–M7 | release | W5 |

**Правило:** W1–W3 не начинают Z11–Z18 и SQ-FS. W4 не начинается, пока M1 не принят.

---

## 12. Приёмка

### 12.1. M1 gate

1. `godot --headless --path . --import` exit 0.
2. Полный GUT **0 fail**; если 633/634 — это FAIL, а не «почти».
3. `export_presets.cfg` + Windows build запускается.
4. Ручной проход: меню → P05 камера → P06 → P07 → P08 → P09 → B01 → B02 → Z01–Z10 → финальная карточка → меню.
5. Флаги: `p05_completed`, `p06_completed`, `p07_completed`, `p08_completed`, `p09_completed`, `b01_completed`, `b02_completed`, `shore_first_day_complete`, `camp_night_seen`, `post_nightmare_demo_completed`.
6. Нет soft-lock: P05 зеркало, P06 Джет, P07 охрана, P08 терминал, P09 капсула, B01 Плащ, B02 спуск, Z10 костёр.
7. 4 квеста M1 завершаются; `crystal_cache` не блокирует финал.
8. Сохранение F5/F9 в живой игре; загрузка в другой сцене.
9. Все placeholders помечены.

### 12.2. Tech demo gate

M1 gate + Z11–Z18 + все 7 квестов + E01–E03 + `post_nightmare_finale` + SQ-01…03 (если включены). Ручной проход 50–70 минут.

### 12.3. Full program gate

M1 + M2 + M3 + M4 + M5 + M6 + M7; clean clone; export; credits; performance; localization decision.

---

## 13. Разрешение противоречий (Consistency Resolutions)

| ID | Противоречие | Каноническое решение | Действие |
|---|---|---|---|
| C-01 | M1 до Z10 vs DEMO_FLOW до Z18 | Два режима: M1 Z10, tech demo Z18 | `DEMO_FLOW.md` обновлён |
| C-02 | P05 старт во дворе vs в камере | Камера `(5.0,0.2,-18.2)` | FIX WP1; A03-01 |
| C-03 | P05 Джет отсутствует | `p05_jett_awakening`, Джет у койки | A01-01, A03-01 |
| C-04 | P06 Джет `(-1.2,17.4)` vs `(-4.8,18.0)` | `(-4.8,18.0)` | FIX WP2; A03-02 |
| C-05 | Джулиус в M1 vs M2 | M1: `GateGuard`/терминал; Джулиус M2 | world/POI/level plan обновлены |
| C-06 | P08 проводник vs терминал | Терминал — канон; проводник — placeholder | A01-04, A03-04 |
| C-07 | P09 Джулиус vs Рок/Каспер/Кассия | Джулиус убрать; добавить Рок/Каспер/Кассия | A01-05, A03-05 |
| C-08 | P07 нет силуэта Нефис | Добавить `nephis_seen_at_gate` | A01-03, A03-03 |
| C-09 | B01 нет Плаща | `b01_statue.tres` + `shroud_summoned` | A01-06, A03-06 |
| C-10 | Нет M1 финала Z10 | `DemoEndZone` `POI-Z10-09` | A03-08, A04-10 |
| C-11 | Флаги кода ≠ дизайн | Канонические флаги + aliases | `INTEGRATION_CONTRACTS.md` |
| C-12 | M1 «7 квестов» | В M1 завершаются 4; crystal частично; hunt/bridge M3 | DEMO_FLOW/world/level plan обновлены |
| C-13 | `QuestOutcomeReward` vs world pickup | Класс не нужен | level plan исправлен |
| C-14 | `start_quest_id` «нет» | Уже есть в 3 классах | side_quests/level plan исправлены |
| C-15 | Устаревшие числа тестов | 15/15, 13/13, 9/9, 22/22, 3/3 | level plan обновлён |
| C-16 | M1 финальный флаг | `post_nightmare_demo_completed`; alias `demo_m1_completed` | DEMO_FLOW/contracts |
| C-17 | `MapScreen` передаёт `{}` | Передавать flags; `hide_when_flag` | A04-09, A08-03 |
| C-18 | `Jett` vs `Jet` | ID `jett`; alias `jet`; display «Джет» | contracts |
| C-19 | `Kasper` vs `Casper` | ID `kasper`; display «Каспер» | contracts |
| C-20 | `Technician` vs `medic` | ID `medic`; alias `technician` | contracts |
| C-21 | `post_nightmare_completed` для M1 и tech demo | M1 — `post_nightmare_demo_completed`; tech demo — `post_nightmare_completed` | contracts |
| C-22 | QuestSystem scope | Только B03; P05–B02 `&""` | contracts/A04 |
| C-23 | `project.godot` параллельные правки | Только TD | FILE_OWNERSHIP |
| C-24 | M1 `crystal_cache` 3-й осколок Z14 | В M1 не завершается; не блокирует | DEMO_FLOW/world/level plan |
| C-25 | Полный GUT 633/634 | Не PASS; нужен 0 fail | A00/A10 |

---

## 14. Риски и открытые вопросы

| Риск | Влияние | Смягчение |
|---|---|---|
| Нет export build | нельзя показать | A00-02, A10-02 |
| Full GUT 633/634 | ложная готовность | freeze, clean cache, A10-01 |
| Нет ручного прохода | soft-lock неизвестен | A10-03/04 |
| MCP editor disconnected | нет live-скриншотов | headless capture; A00-04 |
| Hyper3D внешний | каст не финальный | placeholders; M2/M3 |
| 10 чатов в одном дереве | конфликты | FILE_OWNERSHIP, ACTIVE_CLAIMS |
| SQ-01…05 не реализованы | M3 неполный | M3-P0 только SQ-01…03 |
| Прилив 120 с vs 16 мин | разный геймплей | 120 с в демо; 16 мин P1 |
| Модели без LOD | производительность | A06-07, A10-07 |
| Локализация/4K | не блокирует M1 | P1/P2 |

**Открытые вопросы:** Q-01 длительность, Q-02 Первый Кошмар в меню, Q-03 прилив, Q-04 первые SQ, Q-05 приоритет моделей, Q-06 платформа, Q-07 язык, Q-08 слоты. Решает пользователь/TD; до ответа действуют значения по умолчанию из `DECISIONS.md`.

---

## 15. Document control

| Поле | Значение |
|---|---|
| Design Package | `DP-1.0` |
| Дата | 2026-11-03 |
| Base commit | `75f1423d536ae63b073f59bb897d13f052cdbe8a` |
| Branch | `demo/integration` |
| Working tree | clean, кроме unstaged `opencode.json`; baseline commit создан |
| Supersedes | `OWNERSHIP.md` (ownership draft), ранние demo-scope противоречия |
| Companion docs | `FILE_OWNERSHIP.md`, `docs/demo_sprint/implementation/AGENT_TASKS.md`, `docs/demo_sprint/implementation/INTEGRATION_CONTRACTS.md` |
| Next review | после M1 gate или при изменении D-01…D-30 |

**Конец MASTER_PLAN.**
