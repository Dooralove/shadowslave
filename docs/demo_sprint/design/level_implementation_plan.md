# Level Implementation Plan — демонстрационный мир

**Автор:** Чат 03 — Lead World Designer / Level Designer  
**Дата:** 2026-11-02  
**Статус:** план реализации. Игровые файлы в этой задаче не изменялись.  
**Цель:** собрать сквозной проход `main_menu → police_precinct → … → labyrinth_first_fragment → финал` без soft-lock, с работающими целями, NPC, квестами и коллизиями.  
**Документы-спутники:** `world_layout.md`, `poi_manifest.md`, `side_quests.md`, `gameplay_architecture.md`, `00_DEMO_SCOPE_AND_CONTRACT.md`.

---

## 0. Исходная точка

### 0.1. Фактические проверки на 2026-11-03 (Stage 2)

| Проверка | Результат |
|---|---|
| `godot --headless --path . --import` | exit 0 |
| `test_post_nightmare_locations` | 15/15, 513 assert — pass |
| `test_labyrinth_first_fragment` | 13/13, 332 assert — pass |
| `test_labyrinth_quest_content` | 4/4, 41 assert — pass |
| `test_quest_system` | 9/9, 63 assert — pass |
| `test_level_transition` | 22/22, 83 assert — pass |
| `test_full_route` (Первый Кошмар) | 3/3, 220 assert — pass |
| `route_reachability` (Лабиринт) | 16/18 центров зон; 43/48 маркеров |
| `labyrinth_route_walk` | 34–36/51; часть провалов — сброс на чекпоинт/диагностика, не геометрия |
| Полный ручной проход M1 | **NOT TESTED** |

### 0.2. Текущая цепочка переходов

Проверено по `.tscn`:

```text
police_precinct/ToAcademyApproach (0,1.5,16.4)
  → academy_approach/FromPrecinct (1.5,0.2,18.5)
academy_approach/ToAcademyGate (0,1.5,-21)
  → academy_gate/FromApproach (0,0.2,21.5)
academy_gate/ToCampus (0,1.5,-25.6)
  → academy_campus/FromGate (0,0.2,18.5)
academy_campus/ToSleeper (0,1.5,-21.2)
  → academy_sleeper_center/FromCampus (0,0.2,11)
academy_sleeper_center/ToBlackSea (0,1.0,-25.5)
  → black_sea_platform/FromSleeper (0,0.2,2.6)
black_sea_platform/ToCoral (8.25,1.1,0)
  → tide_descent/FromPlatform (0,0.2,17.6)
tide_descent/ToCoral (0,-4.5,-22.5)
  → labyrinth_first_fragment/FromDescent (38,6.2,0)
labyrinth_first_fragment/ToDescent (41,6,0)
  → tide_descent/FromCoral (0,-5.8,-19.5)
```

`coral_labyrinth` больше не находится на main chain; `tide_descent/ToCoral` ведёт в новый Лабиринт. Это правильно. `coral_labyrinth` остаётся dev-sandbox.

---

## 1. Правила и владение

| Путь | Владелец | Что можно |
|---|---|---|
| `scenes/locations/**`, `scripts/locations/**`, `resources/locations/**` | 03 | геометрия, спавны, коллизии, level-скрипты |
| `scenes/campaign/**` (геометрия/спавны) | 03 | точки входа и порталы, не сюжет |
| `scripts/quests/**`, `resources/quests/**` | 02/04 | квестовые ресурсы и runtime-объекты |
| `scripts/campaign/nightmare_run_state.gd`, `scripts/guide/campaign_guide.gd` | 04 | общее состояние/цель |
| `assets/environments/**`, `resources/locations/**/materials/**` | 07 | арт, материалы, свет |
| `tests/**`, `tools/audit/**` | 10 | проверки |
| `project.godot`, `docs/DECISIONS.md` | TD | только через TD |

**Жёсткие ограничения:**
- не переписывать `QuestSystem`, `NightmareRunState`, `CampaignGuide`;
- не менять персонажные модели;
- не менять `Spawns/*`, `Portals/*`, `Markers/*`, `Gameplay/*` без координации с 04/10;
- не добавлять коллизию, перекрывающую основной маршрут;
- после изменения `Generated/Collision` — `boundary_audit`;
- каждая правка — с целевым тестом.

---

## 2. Общая схема работ

```text
WP0  Интеграция входа и финалов            (03 + 04 + 08 + TD)
WP1  Police precinct P05                    (03 + 07)
WP2  Academy approach/gate/campus P06–P08   (03 + 07)
WP3  Sleeper center P09                     (03 + 01 + 08)
WP4  Black Sea / Tide descent B01–B02       (03 + 07)
WP5  Labyrinth entry + Z01–Z10              (03 + 02 + 04)
WP6  Labyrinth quest/NPC/combat layer       (02 + 04 + 03)
WP7  Side quests SQ-01…05                   (02 + 04 + 03)
WP8  Z11–Z18 + финал                        (03 + 02 + 04)
WP9  QA: GUT, route, ручной проход          (10)
```

Порядок: WP0 → WP1–WP4 (M1) → WP5 → WP6 → WP9 (M1 gate) → WP7/WP8 → WP9 (tech demo gate).

---

## 3. WP0 — вход, цели, финалы

### 3.1. Вход в пост-Кошмар

- **Файлы:** `scenes/ui/main_menu/main_menu.tscn` (TD), `scripts/ui/main_menu/main_menu.gd` (08), `scenes/campaign/finale_arrival.tscn` (TD/01/04).
- **Действие:** кнопка «После Кошмара» (или «Продолжить») запускает `police_precinct.tscn` с чистым/подготовленным состоянием; из финальной карточки N26 — явный переход, не автоматический.
- **Спавн:** `Spawns/WakeCell` (см. WP1), не `Start` во дворе.
- **Состояние:** `NightmareRunState` — пресет `post_nightmare_start`; не сбрасывать чужие флаги, если игрок пришёл из финала.
- **Приёмка:** из меню и из финала игрок попадает в камеру, а не в двор; повторный запуск не дублирует награды.

### 3.2. Цели по сценам

- **Файлы:** `resources/campaign/beats/*` (04), `CampaignGuide` (04), `ObjectiveLine` (08).
- **Цели:** P05 «Выйти из участка», P06 «Добраться до академии», P07 «Пройти ворота», P08 «Найти спальный центр», P09 «Пройти индукцию», B01 «Осмотреть статую и спуститься», B02 «Спуститься к кораллам», B03 «Войти в Лабиринт».
- **Правило:** одна строка цели; не дублировать `base_objective`; внешняя цель только при активном scope Лабиринта.

### 3.3. Финалы

| Финал | Точка | Узел | Условие | Результат |
|---|---|---|---|---|
| M1 | Z10 костёр `(-100,18.2,-5)` | `Area3D`/`QuestTriggerZone` `DemoEndZone`, радиус 4 | `demo_mode_m1` (default; **не** `demo_mode_full`) | карточка «ПЕРВЫЙ ДЕНЬ» / «Конец M1», меню/`R` |
| Tech demo | Z18 верх `(-1410,35.2,0)` | `FinalZone`, радиус 4 | `demo_mode_full` | карточка «Конец демонстрационного фрагмента» |

**Файлы:** `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`, новый `scripts/locations/forgotten_shore_labyrinth/demo_end_zone.gd` (03), UI-карточка (08). Не использовать выключенный `Portals/ToWest` как финал.

---

## 4. WP1 — Police precinct (P05)

### 4.1. Пробуждение в камере

**Проблема:** `Spawns/Start` и `Player` стоят во дворе `(0,0.2,14)`; P05 «пробуждение» теряется.

**Правка:**
- В `scenes/locations/post_nightmare/police_precinct.tscn`:
  - `Player.position = Vector3(5.0, 0.2, -18.2)`, `rotation_degrees.y = 90` (лицом на запад, к выходу из камеры).
  - `Spawns/Start.position = Vector3(5.0, 0.2, -18.2)`, `rotation_degrees.y = 90`.
  - `Spawns/FromApproach` остаётся `(0,0.2,13.5)` — возврат из академии.
- **Проверка:** камера 5×5, койка `(5,0,-18.2)`, проём решёток у `z=-15`; решётки без коллизии; игрок выходит в блок камер.

### 4.2. Зеркало и «дом»

- **Зеркало:** `Interactable`/`Inspectable` в `(-18.8,0.2,-2)`, цель — `(-19.55,1.8,-2)`. Игрок стоит в допросной, смотрит на запад. Триггер один раз: тень в зеркале, барк.
- **Шкафчик:** `Inspectable` в `(-8.4,0.2,3.4)`; текст «вещи Санни», не выдавать предмет без решения 04.
- **Офицер:** опциональный `QuestNpc` у стойки `(1.0,0,-3.2)`, лицом на юг; без нового диалогового дерева — барк.

### 4.3. Коллизии

- Двор: boundary по краю; ворота 4,2 м; машина/контейнер с коллизией.
- Камеры: 14×10, проход 2,4 м; решётки визуальные, не блокируют.
- Допросная: 6×7, дверь 2,2 м; стол и стулья не перекрывают точку зеркала.

### 4.4. Приёмка

- P05: старт в камере → выход → зеркало → двор → портал.
- Нет застревания в решётках/койке.
- `test_post_nightmare_locations` остаётся 15/15 (Stage 2 baseline).

---

## 5. WP2 — Academy approach / gate / campus (P06–P08)

### 5.1. Approach

- **NPC Джет:** `QuestNpc` в `(-4.8,0,18.0)`, yaw `270` (на восток, к игроку); машина `(-3.4,0,18.6)`.
- **Цель:** `ObjectiveLine` «Добраться до КПП»; после диалога — маркер на КПП.
- **Коллизии:** дорога 14 м, тротуары 3 м; машина с коллизией; шлагбаум не блокирует; портал 4×3.
- **Проверка:** путь от `(1.5,0.2,18.5)` до `(0,0.2,-18.5)` без препятствий.

### 5.2. Gate

- **NPC охрана КПП:** `QuestNpc` `GateGuard` в `(5.0,0.2,2.0)`, yaw `180` (на юг, к площади); стойка `(5.5,0,3)`. **Джулиус — M2**, не в M1.
- **Цель:** «Пройти проверку и войти в академию».
- **Коллизии:** арка 4,8 м; башни 7×8, двери 2,4 м; площадь 40×24; внутренняя дорога 14 м.
- **Проверка:** проход `(0,0.2,21.5)` → арка → `(0,0.2,-13)` → портал.

### 5.3. Campus

- **NPC:** терминал направления или проводник-студент `(-2.5,0.2,4.0)`, yaw `180`; **Джулиус — M2**, в M1 его нет.
- **Цель:** «Найти спальный центр».
- **Коллизии:** дорожка 12 м; галерея 10,5×27, колонны 0,32 м; северный вход 5 м; портал 4×3.
- **Проверка:** `(0,0.2,18.5)` → галерея → `(0,0.2,-18.5)`.

**Общие требования WP2:** не добавлять новых стен; все NPC — `QuestNpc` с `DialogueSequence`; не блокировать центральную ось; проверять `test_post_nightmare_locations`.

---

## 6. WP3 — Sleeper center (P09)

### 6.1. Индукция

- **Точка:** центральная койка `(0,0.2,-25.5)`; кольцо `(0,0.03,-25.5)`; балдахин.
- **Действие:** `Interactable` «Лечь на койку»; при взаимодействии:
  1. `input_enabled = false`;
  2. короткая катсцена/затемнение;
  3. `Portals/ToBlackSea.activate()`.
- **Портал:** уже стоит `(0,1.0,-25.5)`, fade 1,35/1,55; не создавать второй.
- **NPC медик/техник:** `QuestNpc` `InductionMedic` `(4.2,0.2,-20.3)`, yaw `270`; барк о протоколе. **Рок, Каспер и Кассия** — отдельные placeholder'ы индукции (см. §9.3).

### 6.2. Коллизии и пространство

- Проход спальни 2,6 м; 12 капсул не перекрывают центральную ось.
- Медкоридор 4 м; койки 4,4×3,6; дверь 3 м; зона взаимодействия 2 м.
- **Фикс не требуется:** 12×10 dream ward достаточно.

### 6.3. Приёмка

- P09: вход → спальня → наблюдательная → медкрыльо → койка → затемнение.
- Нет возможности пройти мимо индукции и застрять (портал только через койку/триггер).
- `test_post_nightmare_locations` 15/15 (Stage 2 baseline).

---

## 7. WP4 — Black Sea / Tide descent (B01–B02)

### 7.1. Black Sea: точки осмотра

- **Звёзды:** `Inspectable` у `(0,0.2,5.2)`, смотрит на нагрудник; барк о семи звёздах.
- **Меч:** `Inspectable` у `(-4.8,0.2,1.2)`, yaw 58; барк о мече.
- **Спуск:** `DescentLedge (7.4,-0.35,0)`; портал `ToCoral (8.25,1.1,0)`.
- **Коллизии:** boundary по кромке шеи; восточный сектор открыт; площадка ⌀12; не ставить коллизию на точки осмотра.

### 7.2. Black Sea: рампа

**Проблема:** 4 ступени по 0,55 м; для контроллера это стена, если игрок пойдёт вниз после осмотра.

**Правка (B1):**
- Сохранить визуальные ступени/плиты.
- Добавить коллизионную рампу от `(6.2,0,0)` до `(8.25,0.35,0)`, ширина 3,2 м, толщина 0,25; верх совпадает с порогом портала.
- Убрать/отключить пошаговые коллизии, если они мешают.
- **Проверка:** игрок проходит от центра площадки до портала без прыжка; камера не цепляется.

### 7.3. Tide descent: рампа

**Проблема:** 24 ступени по 0,25 м; вниз работает, вверх — нет. Возврат/подъём ломается.

**Правка (B2):**
- Оставить 24 визуальные ступени и боковые липы.
- Добавить невидимую коллизионную рампу от `(0,-6,-18)` до `(0,0,18)`, ширина 5 м, толщина 0,3.
- Отключить пошаговую коллизию у `TideStairs` (оставить меши).
- **Проверка:** вверх и вниз без прыжка; `FromCoral` yaw 180 ведёт наверх; портал наверху доступен.

### 7.4. Коралловые ворота

- Нижняя площадка 8×7; арка `(0,-3.8,-22.5)`; портал `(0,-4.5,-22.5)`.
- **Проверка:** проход 5,8 м; портал 4×3; нет провала между нижней площадкой и порталом.

---

## 8. WP5 — Labyrinth entry и Z01–Z10

### 8.1. Вход

- `Spawns/FromDescent (38,6.2,0)`, yaw 90; карниз +6; рампа вниз.
- **Проверка:** старт на полу, первый кадр со статуей; `Portals/ToDescent` работает.

### 8.2. Критические фиксы G1–G5

| ID | Файл/функция | Текущее | Правка | Проверка |
|---|---|---|---|---|
| G1 | `labyrinth_first_fragment.gd:_build_z04_mud_hollow` | `Z04_EastWallA (-15,-55)→(-15,-12)`, `B (-15,-2)→(-15,-30)` перекрывают вход | A: `(-15,-55)→(-15,-30)`; B: `(-15,-12)→(-15,-2)`; проём 18 м | `route_walk z03_z04`; `Z04` достижима |
| G2 | `_build_z11_tide_channel` | `Z11_WestLowStairs (-150,-1)→(-153,0)` под полом Z12 | `(-147,-1,0)→(-150,0,0)` | `route_walk z11_low` |
| G3 | `_build_z08_clearing` | `Z08_TunnelFrameL (-58.5,1.5,19)` в проходе | L `(-55,1.5,17.5)`, R `(-55,1.5,22.5)`, top `(-55,3.2,20)`; проём 4 м | `route_walk z08_z09` |
| G4 | `_build_z05_bone_passage` | `Z05_ToPocket` начинается z30, пол Z05 кончается z26 | `floor_between(-35,26 → -50,30)`, width 4; или плита 6×6 | `route_walk z05_z06` |
| G5 | `_build_z03_first_fork` / Z05 | V-угол без площадки | `floor_zone(Z03, "Z03_BoneLanding", Vector2(-16,14), Vector2(6,6), 0.0, "mud")` | `route_walk z03_z05` |

**Правило:** после G1–G5 запустить `boundary_audit`; новые края не должны появиться на main route. Не менять `Generated/Visual/Zxx` арт-слой.

### 8.3. Z01–Z10 content

| Зона | Объекты | NPC/квест | Проверка |
|---|---|---|---|
| Z01 | вход, статуя, ложный след | B03, SQ-01 clue | спавн/пол |
| Z02 | туша, жетон, след | SQ-01 | жетон на полу −1,5 |
| Z03 | пень, клинок, бой | `first_blood`, `azure_blade` | бой/подбор |
| Z04 | низина, гребень | риск | G1 |
| Z05 | арка, кровь, камера | SQ-01 | G5 |
| Z06 | Тео, тайник, кристалл | SQ-01/03 | G4 |
| Z07 | гряда, лезвие | обзор | рампа |
| Z08 | Нефис/Кассия, туннель | `first_day`, SQ-02 | G3 |
| Z09 | эхо, плащ, карапаксы | SQ-02/03 | G3 |
| Z10 | лагерь, костёр, чекпоинт | `camp_rest`, M1 end | чекпоинт |

**M1 reachability:** в Z01–Z10 полностью завершаются только `first_day`, `first_blood`, `azure_blade`, `camp_rest`. `crystal_cache` требует 3 осколка, третий — в Z14, поэтому в M1 остаётся незавершённым. `hunt_pack` (Z13) и `bridge_stand` (Z14) в M1 не стартуют. Это не soft-lock: финал M1 зависит от `first_day`/`camp_night_seen`, а не от всех 7 квестов.

### 8.4. Z10 M1 end

- `DemoEndZone` в `(-100,18.2,-5)`, радиус 4; активен при `demo_mode_m1` (default) и **не** при `demo_mode_full`.
- Не перекрывать костёр/чекпоинт; срабатывает один раз; карточка и возврат в меню.
- В `demo_mode_full` зона выключена.

---

## 9. WP6 — Labyrinth quest/NPC/combat layer

### 9.1. Существующий слой (не переписывать)

`LabyrinthQuestDirector` уже создаёт:
- triggers: `first_fork`, `clearing`, `camp`, `hunting`, `bridge`, `refuge`, `storm`, `cliffs`;
- checkpoints: `CP-SHORE-START`, `CP-SHORE-CAMP`, `CP-SHORE-REFUGE`, `CP-SHORE-CLIFF`;
- pickups: Azure Blade, 3 shards;
- NPC: Нефис/Кассия;
- enemies: WoundedScavenger, 3 PackCarapace, 2 BridgeCarapace;
- campfire.

**Правило:** не менять имена/позиции этих узлов; новые объекты — в отдельный `Gameplay/RuntimeNarrative` или `Quests/`.

### 9.2. Новый narrative-слой

- **Узел:** `Gameplay/NarrativeQuestDirector` (Node3D) + `Gameplay/RuntimeNarrative`.
- **Скрипт:** `scripts/locations/forgotten_shore_labyrinth/labyrinth_narrative_director.gd` (03).
- **Данные:** 5 новых `QuestDefinition` (02) + `quest_catalog.tres` (02/04).
- **Старт:** `QuestStart`-хук / `start_quest_id` (04); `auto_start=false`.
- **Объекты:** `Quests/SQ_FS_01…05`; координаты — `poi_manifest.md`; не использовать `Gameplay/*` как квестовые узлы.

### 9.3. NPC

| NPC | Сцена | Узел | Проверка |
|---|---|---|---|
| Джет | academy_approach | `NPCs/Jet` | не блокирует дорогу; канонический ID `jett`, legacy alias `jet` |
| Охрана КПП | academy_gate | `NPCs/GateGuard` | не блокирует арку; **Джулиус — M2**, не в M1 |
| Медик/техник | sleeper_center | `NPCs/InductionMedic` | не блокирует медкрыло; канонический ID `medic` |
| Рок | sleeper_center | `NPCs/Rock` | трибуна индукции; M1 placeholder |
| Каспер | sleeper_center | `NPCs/Kasper` | социальная сцена; M1 placeholder; ID `kasper` |
| Тео | Z06 | `Quests/SQ_FS_01/Theo` | M3, не в M1 |
| Нефис/Кассия | Z08 | существующие | не дублировать; Кассия также визуально в P09 |

### 9.4. Бой

- Z03: `WoundedScavenger` 65 HP; не блокирует выходы.
- Z13: 3 `PackCarapace`; не ставить в узких проходах.
- Z14: 2 `BridgeCarapace`; не блокировать мост/низ.
- Z09: 2 `Carapace` для SQ-02; можно обойти.
- Z16: 3 `Carapace` (проект); гребень безопасен.
- Z02: 3 падальщика пассивны; не на пути к жетону.

---

## 10. WP7 — Side quests SQ-01…05

### 10.1. Данные

- 5 `QuestDefinition` с кодами 08–12; `auto_start=false`, `show_available=false`.
- `QuestObjective` по §3.4 `side_quests.md`.
- `QuestReward` идемпотентны; не дублировать 7 существующих наград.
- `test_quest_system` обновить с 7 до 12 (10/02).

### 10.2. Объекты по зонам

| SQ | Объекты | Координаты | Тип |
|---|---|---|---|
| SQ-01 | Token, Heel, Shell, Blood, Theo | Z02/Z01/Z05/Z06 | QuestPickup/Inspectable/NPC |
| SQ-02 | 3 Echo, Core, Cloak, 2 Carapace, ListenPoint | Z09 | QuestTrigger/QuestKillCredit/Pickup |
| SQ-03 | Theo, Cache, Token | Z06/Z09 | NPC/Interactable |
| SQ-04 | Box, 3 Levers, Wait | Z11 low/high | QuestTideLock/Interactable |
| SQ-05 | Trigger, Tracks, Carcass, Bait, Lair, Alpha, TideTrigger, West/East | Z14 | QuestTrigger/QuestNpc/Carapace |

**Все координаты — в `poi_manifest.md`; 32/32 сверены с `side_quests.md`.**

### 10.3. Минимальные аддитивные расширения

| Расширение | Владелец | Зачем |
|---|---|---|
| `QuestStart`/`start_quest_id` | 04 | старт `auto_start=false` по контакту; **уже есть** в QuestNpc/QuestPickup/QuestTriggerZone, нужна проверка порядка |
| `QuestTideLock` | 03+04 | шкатулка только при воде ниже −1,0 |
| `QuestChoice` | 08+04 | SQ-03 |
| `MapMarker.hide_when_flag` | 03+08 | карта, P1; поле уже есть, нужен flags-фикс `MapScreen` |
| ~~`QuestOutcomeReward`~~ | — | **Не нужен:** исходы SQ-03/05 закрываются мировыми pickup'ами и флагами, как в `side_quests.md` §3.2 |

**Не делать:** второй autoload, второй журнал, вторую валюту, второй инвентарь.

---

## 11. WP8 — Z11–Z18 и финал

| Зона | Работы | Проверка |
|---|---|---|
| Z11 | G2, SQ-04, tide line | `route_walk z11_low` |
| Z12 | низ/верх, шпиль | проход |
| Z13 | 3 петли, стая, скелет | `route_walk z13` |
| Z14 | мост, SQ-05, Эхо | `route_walk z14` |
| Z15 | хаб, чекпоинт, саммит (P2) | `route_walk z15` |
| Z16 | низ/гребень, стая | `route_walk z16` |
| Z17 | гроза, обвал, высокий путь | `route_walk z17` |
| Z18 | серпантин, финал | `FinalZone` |

**Финал Z18:** `FinalZone` `(-1410,35.2,0)` радиус 4; карточка; `Portals/ToWest` не включать.

---

## 12. Коллизии и проходы: стандарт

| Элемент | Требование |
|---|---|
| Основной проход | ≥3 м; высота ≥2,2 м; уклон ≤45° |
| Рампа | ширина ≥3 м; верх/низ совпадают с полом ±0,05 м; без ступеньки |
| Дверь/арка | ≥2,4 м; портал 4×3 м |
| Мост | 6 м; рёбра-перила не перекрывают настил |
| Узкое место | 3 м; не сужать декором |
| NPC | 1,5 м вокруг; не на оси прохода |
| Pickup | 1×1; не в геометрии; подъём 0,75 м |
| Trigger | радиус 3–18 м; не срабатывает дважды |
| Boundary | только по внешнему краю; не на main route |
| Падение | `FallRecovery` + чекпоинт; не оставлять «призрачный пол» |

**После каждой правки коллизии:** `boundary_audit` (шаг 1,5; jump 1), проверить 0 ghost floor и отсутствие новых смертельных прыжков на main route.

---

## 13. Проверки

### 13.1. Целевые

```powershell
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_post_nightmare_locations.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_labyrinth_first_fragment.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_labyrinth_quest_content.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_quest_system.gd -gexit
```

### 13.2. Маршрут

- `tools/audit/labyrinth_route_walk.gd` — 51 сегмент; после G1–G5 должно быть 51/51 (или каждый провал объяснён).
- `tools/audit/route_reachability.gd` — 18/18 центров зон; 48/48 маркеров.
- `tools/audit/boundary_audit.gd` — 0 ghost floor; без новых смертельных прыжков.
- `tools/audit/scene_bounds.gd` — сверка координат POI.

### 13.3. Ручной проход

| Сценарий | Критерий |
|---|---|
| M1 | меню → камера → академия → море → спуск → Z10, 18–25 мин |
| M1 death | падение/смерть возвращает к чекпоинту, не в меню |
| Tech demo | Z10 → Z18 + SQ-01…03, 50–70 мин |
| SQ-01 пропуск | задание не стартует, маршрут не блокируется |
| SQ-04 прилив | шкатулка доступна только в отлив |
| Финал | карточка, `R`/меню, без soft-lock |

---

## 14. Порядок и время

| Окно | Работа | Выход |
|---|---|---|
| 0:00–0:15 | WP0 вход/цели/финалы | меню → камера |
| 0:15–0:45 | WP1–WP3 город/академия | P05–P09 |
| 0:45–1:05 | WP4 море/спуск | B01–B02 |
| 1:05–1:40 | WP5 G1–G5 + Z01–Z10 | M1 |
| 1:40–2:10 | WP6 NPC/7 квестов | бой/встреча/лагерь |
| 2:10–2:40 | WP7 SQ-01…03 | цепочка A |
| 2:40–2:55 | WP8 Z11–Z18 + финал | tech demo |
| 2:55–3:00 | WP9 QA | отчёт |

**Cut list при нехватке времени:**
1. SQ-04/SQ-05 (P2).
2. Z15 саммит +25.
3. Z16 стая (оставить пространство).
4. Проводник в кампусе (оставить терминал; Джулиус — M2).
5. Tech demo Z18 (оставить M1 финал Z10).

---

## 15. Риски

| Риск | Влияние | Смягчение |
|---|---|---|
| `DEMO_FLOW.md` отсутствовал на старте | разные чаты по-разному видят поток | создан производный `DEMO_FLOW.md`; TD фиксирует финальный |
| `narrative_design.md` всё ещё про Первый Кошмар | конфликт целей | не включать S00–S15 в M1; M4 отдельно |
| Параллельные правки Quest/Combat | ложные parse errors | `--editor --quit` перед тестами; не чинить чужие файлы |
| `route_walk` сбрасывает игрока на чекпоинт | ложные FAIL | сбрасывать `NightmareRunState`/`FallRecovery` перед сегментом; новый тест 10 |
| 4,95 млн треугольников art | FPS | LOD/MultiMesh/occlusion после M1 |
| `coral_labyrinth` путается с новым Лабиринтом | два входа | не связывать; оставить sandbox |
| SQ-01 требует прыжка в Z06 | accessibility | G4 плита |
| Z04/Z11 ломают низкие маршруты | «полуоткрытость» не работает | G1/G2 |

---

## 16. Definition of Done

- [ ] M1 проходит от меню до Z10 без падения и soft-lock.
- [ ] Все 13 переходов работают, spawn корректен.
- [ ] P05–P09, B01–B03 имеют цель и действие.
- [ ] 7 существующих квестов работают.
- [ ] SQ-01…03 (P1) работают; SQ-04/05 — P2.
- [ ] G1–G5, B1–B2, P1, F1 применены.
- [ ] `test_post_nightmare_locations`, `test_labyrinth_first_fragment`, `test_labyrinth_quest_content`, `test_quest_system` — зелёные.
- [ ] `route_reachability` 18/18, `route_walk` 51/51 или объяснённые провалы.
- [ ] `boundary_audit`: 0 ghost floor, без новых смертельных прыжков.
- [ ] Ручной проход записан в `qa/`.
- [ ] Нет новых parse errors; импорт exit 0.
