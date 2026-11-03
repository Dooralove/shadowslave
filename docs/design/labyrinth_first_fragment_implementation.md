# Labyrinth First Fragment — реализованный greybox

> **Актуальный handoff и проверки:** `docs/level_design/forgotten_shore_labyrinth_handoff.md`. Этот документ — as-built заметки; разделы 8–10 ниже частично устарели после замены ступеней рампами и удаления автоматических парапетов.

**Статус:** greybox-сцена собрана; актуальный прогон — GUT 13/13, 331 assert, `EXIT=0`; аудит границ — 3 238 краёв, 0 «призрачного пола», 1 смертельный прыжок. Визуальная полировка — задача Claude; непрерывный ручной проход 1,5 км и FPS — **NOT TESTED**.
**Дата:** 2026-11-01.
**План:** `docs/design/level_brief_labyrinth_first_fragment.md`.
**Канон:** `docs/design/forgotten_shore_labyrinth_research.md`.

---

## 1. Файлы

| Файл | Назначение |
|---|---|
| `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn` | Самостоятельная сцена; запускается без кампании |
| `scripts/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.gd` | Планировка 18 зон, маркеры, свет, ориентиры |
| `scripts/locations/forgotten_shore_labyrinth/labyrinth_greybox.gd` | Строитель: `Generated/Visual`, `Generated/Collision`, зоны, лестницы, шлюзы |
| `scripts/locations/forgotten_shore_labyrinth/tide_controller.gd` | Прототип прилива: вода, шлюзы, фазы |
| `resources/locations/forgotten_shore_labyrinth/env_labyrinth.tres` | Окружение сцены |
| `resources/locations/forgotten_shore_labyrinth/sky_labyrinth.tres` | `Sky` для окружения |
| `resources/locations/forgotten_shore_labyrinth/sky_labyrinth_material.tres` | Бледное серое небо |
| `tests/test_labyrinth_first_fragment.gd` | GUT: структура, зоны, маршруты, пол, прилив |

Сцена не меняет `project.godot`, главную сцену, кампанию, Первый Кошмар, контроллер, камеру или общие менеджеры.

---

## 2. Запуск

Из редактора: открыть `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`, F6.

Из консоли:

```powershell
godot --path . res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn
```

Тест:

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_labyrinth_first_fragment.gd -gexit
```

**Важно:** в текущем рабочем дереве общие боевые скрипты Claude (`StaminaComponent`, `CombatSettings`, `AttackData`, `CampaignGuide`) дают parse errors, из-за которых runtime helper Godot MCP не подключается. Перед headless-тестом нужен `godot --headless --path . --import`, иначе сцена игрока может не загрузиться из-за устаревшего кэша классов. Это не ошибка новой локации.

---

## 3. Структура сцены

```
LabyrinthFirstFragment (Node3D, labyrinth_first_fragment.gd)
├── WorldEnvironment (env_labyrinth)
├── Sun (DirectionalLight3D)
├── Player (sunny_waking_poc.tscn; sprint/jump включены, combat выключен)
├── Spawns (10)
├── Portals
│   ├── ToDescent → tide_descent/FromCoral
│   └── ToWest (выключен; будущий B06)
├── Shots (17 камер + цели)
├── Markers
│   ├── CampCheckpoint / RefugeCheckpoint / CliffCheckpoint
│   ├── FirstSighting / AzureBladePickup
│   └── TideSafePoints (9 высот)
├── Gameplay
│   ├── Triggers (8 маркеров)
│   ├── Interactables (5 маркеров)
│   ├── Encounters (4 маркера)
│   ├── Companions (3 маркера)
│   └── Dialogue (2 маркера)
├── Landmarks
│   ├── Statue / CampPillar / WesternSpire
│   ├── BoneBridge / StormWall / Cliffs
│   └── CampLight (FlickerLight)
├── Tide
│   ├── WaterPlane (1600 × 400)
│   ├── TideController (120 с прототип)
│   └── TideGates (контейнер; шлюзы создаются в Generated/Collision)
├── UI
│   └── Fade (FadeLayer)
└── Generated (создаётся в _ready)
    ├── Visual/<Zone>
    ├── Collision/<Zone>
    ├── Lights/<Zone>
    └── Labels/<Zone>
```

`Generated/` полностью пересобирается `rebuild()`. `Gameplay`, `Spawns`, `Portals`, `Shots`, `Markers`, `Landmarks`, `Tide` не затрагиваются. `Landmarks` — авторские якоря; их дочерние меши заменяются без перестройки маршрутов.

---

## 4. Зоны (as built)

| ID | Зона | X | Z | Пол | Верх | Ключевое |
|---|---|---|---|---|---|---|
| Z01 | Threshold | +12…+45 | −12…+12 | 0 / +6 | открыто | Вход, карниз, статуя |
| Z02 | Carcass | +8…+30 | +15…+38 | −1,5 | открыто | Туша, карапаксы, тупик |
| Z03 | First Fork | −12…+12 | −12…+12 | 0 | открыто | Пень, 3 выхода, первый бой |
| Z04 | Mud Hollow | −45…−15 | −55…−30 | −3 | открыто | Низина, гребень, рёбра |
| Z05 | Bone Passage | −45…−15 | +15…+40 | 0 | 8 | Узкий проход, арка |
| Z06 | Dry Pocket | −55…−40 | +40…+52 | +6 | открыто | Скрытая высота, кристалл |
| Z07 | Scout Ridge | −55…+5 | −62…−48 | +7 | открыто | Верхний обход, лезвие |
| Z08 | Clearing | −80…−50 | −18…+18 | 0 | открыто | Прогалина, первая встреча |
| Z09 | Blind Tunnel | −85…−55 | +18…+22 | 0 | 4 | Туннель, световая щель |
| Z10 | Coral Hill | −125…−85 | −30…+20 | +1 / +18 | открыто | Лагерь, костёр, столб |
| Z11 | Tide Channel | −150…−125 | −30…+30 | −6 / +6 | открыто | Нижний порог, верхний карниз |
| Z12 | West Isthmus | −200…−150 | −25…+25 | 0 / +5 | открыто | Сужение, высокий проход |
| Z13 | Hunting Grounds | −550…−200 | −120…+120 | −2…+2 | открыто | 3 маршрута, 13 масс, скелет |
| Z14 | Bone Bridge | −650…−550 | −40…+40 | +2 / +6 | открыто | Мост, низкая тропа |
| Z15 | High Refuge | −750…−650 | −80…+40 | +2 / +18 | открыто | Чекпоинт, обзор; саммит +25 не построен |
| Z16 | Pack Territory | −1050…−750 | −150…+150 | −3…+1 | открыто | Низкий лабиринт, гребень |
| Z17 | Storm Run | −1300…−1050 | −80…+80 | −2 / +8 | открыто | Верхняя тропа, препятствия |
| Z18 | Cliffs | −1450…−1300 | −100…+100 | +2 / +35 | открыто | Серпантин, финал |

**Маршруты:**
- Восток: `Z01 → Z03 → Z04/Z05/Z07 → Z08 → Z10`; петля `Z10 → Z09 → Z08`; возврат по уступам/рампе.
- Центр: `Z10 → Z11 → Z12 → Z13a/b/c → Z14 → Z15`; три петли Z13.
- Запад: `Z15 → Z16 (низ/гребень) → Z17 → Z18`; финальный подъём.
- Срезы: `Z09`, верхний карниз `Z11`, костяной мост `Z14`, южный гребень `Z16`.

**Тупики:** `Z02`, `Z06` — с наградой/видом; не обязательны.

---

## 5. Что уже может игрок

- Пройти от входного карниза через порог, развилку и любой из трёх восточных маршрутов к прогалине и лагерю.
- Вернуться через туннель, по рампе или по верхнему обходу.
- Пройти центральную часть: канал, перешеек, три петли охотничьих угодий, костяной мост, высокое убежище.
- Пройти запад: низкий лабиринт стаи или южный гребень, штормовой коридор, серпантин на утёсы.
- Увидеть прилив: вода поднимается/опускается, низкие шлюзы закрываются, высокие обходы остаются.
- Пользоваться `Spawns/Start`, `Camp`, `Refuge`, `CliffBase` для отладки; вернуться в `tide_descent` через портал.

---

## 6. Переиспользованные системы

- `GreyboxLocation`: материалы, `Spawns`/`Shots`, `_aim_shots`, `_apply_pending_spawn`, реестр модулей.
- `LevelPortal` + `FadeLayer`: возврат в `tide_descent`, будущий западный выход.
- `SunnyController`, `ThirdPersonCamera`, `Interactor`, `HealthComponent` — через `sunny_waking_poc.tscn`; дубликата контроллера нет.
- `NightmareRunState` — через `LevelPortal` и `GreyboxLocation`; новых глобальных менеджеров нет.
- `FlickerLight` — костёр лагеря.
- `Label3D`, `OmniLight3D`, `SpotLight3D` — временный свет и подписи.
- GUT, `boundary_audit.gd`, `location_capture.gd` — проверки.

---

## 7. Заглушки и что не реализовано

| Что | Состояние |
|---|---|
| Противники | Только маркеры `Gameplay/Encounters`; `TestEnemy` не расставлены |
| Нефис, Кассия | Маркеры `Gameplay/Companions` и `Dialogue`; моделей и диалогов нет |
| Эхо | Маркер; сценарного проезда нет |
| Первый бой, Azure Blade | Маркеры `FirstFight`, `AzureBladePickup`; механики нет |
| Первая встреча и лагерь | Маркеры `FirstSighting`, `Camp`; триггеров и диалогов нет |
| Прилив | Визуальная вода + 8 шлюзов; нет HUD, утопления, штормового сценария |
| Гроза | `StormWall` — тёмный силуэт; дождя, молний и ветра нет |
| Карта | `MapDefinition` не создавалась; глобальная карта не менялась |
| Сохранения | Не реализованы; чекпоинты — только маркеры |
| Лазание, плавание, тень, ИИ спутников | Не реализованы |
| Финальные модели, материалы, VFX, звук | Не реализованы |

---

## 8. Проверки

### 8.1. GUT

```text
Scripts               1
Tests                13
Passing Tests        13
Asserts             331
Time             108.10s
All tests passed!
EXIT=0
```

Покрыто: сборка сцены, `Generated/Visual`/`Generated/Collision`, 18 зон, 10 spawns, 2 портала, 17 ракурсов, ориентиры, прилив (вода + шлюзы), повторная сборка, старт на полу, 18 опорных точек зон, 63 переходные точки маршрута (телепорт + пол), а также реальное движение: вход вверх/вниз, подъём Z10, лагерь → западный карниз, гребень Z16 → высокая тропа Z17.

### 8.2. Аудит границ

`tools/audit/boundary_audit.gd`, шаг 1,5 м, `--jump=1`:

| Показатель | Значение |
|---|---|
| Seeds | 10 |
| Досягаемая площадь | 145 465 м² |
| Смертельных краёв (ячеек) | 3 238 |
| «Призрачный пол» | 0 |
| Смертельных прыжков через низкую стену | 1 |
| Краёв со стеной | 6 414 |
| Висящих объектов | 0 |

**Ограничение:** 3 238 края — это открытые внешние края больших полов и рамп. Автоматические боковые стенки у рамп были удалены, потому что перекрывали площадки и делали связки непроходимыми. Основные полы имеют часть парапетов; внешние края остаются намеренными обрывами и обрабатываются `FallRecovery`. Один смертельный прыжок найден около `x≈−46, z≈34` (Z05/Z06). Ноль краёв не достигнут; «призрачного пола» и провала сквозь землю нет.

### 8.3. Визуальная проверка

`tools/audit/location_capture.gd` (без runtime) сделал 24 PNG в `%TEMP%/opencode/task4_shots_final2`: `player_view`, `overview_east`, `overview_west`, `entrance`, `carcass`, `fork`, `mud`, `bone`, `ridge`, `clearing`, `camp`, `channel`, `hunting`, `bridge`, `refuge`, `pack`, `storm`, `cliffs` и eye-кадры. Просмотрены: вход, обзор востока, развилка, прогалина, лагерь, охота, мост, убежище, стая, гроза, утёсы, канал. Сцена читается как блок-аут: красные массы, грязь, кости, столб, костёр, мост, серпантин; не финальный арт. `Shots/Mud` и `Shots/Bone` стоят внутри стен — вспомогательные камеры нужно переставить.

### 8.4. Что не проверено

- **Ручной непрерывный проход** 1,5 км — NOT TESTED. Маршрут покрыт 63 переходными точками и 18 опорными, но это не заменяет проход.
- **FPS/draw calls** — NOT TESTED; сцена 1 308 узлов, 433 меша, 611 draw calls в тестовом кадре, оптимизация не делалась. `scene_stats` показывает только первый кадр; это не замер FPS.
- **Godot MCP runtime** — editor connected, но runtime helper не подключается из-за parse errors общих боевых скриптов Claude; runtime-скриншоты и `send_input` не считать выполненными.
- **Звук, финальный свет, VFX** — NOT TESTED/не реализованы.

---

## 9. Проблемы и ограничения

1. **Зависимость от класса игрока.** `sunny_waking_poc.tscn` использует общий `SunnyController` и новые боевые скрипты Claude. Пока в рабочем дереве есть parse errors (`StaminaComponent`, `CombatSettings`, `AttackData`, `CampaignGuide`), сцена игрока может не загрузиться после смены кэша классов. Перед тестом нужен `--import`; после исправления скриптов Claude зависимость исчезнет.
2. **Масштаб.** 1,5 км, 1 308 узлов, 433 меша, ~79 200 треугольников, 611 draw calls в тестовом кадре; нет LOD/occlusion/visibility-оптимизации. Для blockout допустимо, для полировки — оптимизировать и замерить FPS.
3. **Границы.** 3 238 края аудита, 1 смертельный прыжок; автоматические парапеты рамп удалены, открытые края обрабатываются `FallRecovery`. Решение: ручные парапеты/`boundary` по внешнему периметру и повторный аудит.
4. **Прилив.** 120 с прототип, не 16 минут; нет HUD, утопления и штормового сценария. Шлюзы — единственная механика.
5. **Арт.** Все формы — примитивы; метки скрыты (`show_debug_labels=false`); лейблы ASCII, но шрифт `Label3D` не проверялся.
6. **Маркеры без контента.** `Gameplay/*` — только `Marker3D`; это задел, не фальшивая механика.
7. **Карта и сохранения** не подключены.

---

## 10. Что делать Claude при полировке

1. **Читать план:** `docs/design/level_brief_labyrinth_first_fragment.md` §3–§6 и этот документ. Карта моделей и кораллового кита — `docs/art/labyrinth_model_map.md`.
2. **Заменять только `Generated/Visual/<Zone>`** финальными моделями; `Generated/Collision/<Zone>` сохранять. Если коллизия должна измениться — менять её отдельно и перезапускать `boundary_audit`.
3. **Landmarks** — авторские якоря: `Statue`, `CampPillar`, `WesternSpire`, `BoneBridge`, `StormWall`, `Cliffs`. Заменять дочерние меши, не двигать узлы.
4. **Не переименовывать** `Spawns/*`, `Portals/*`, `Shots/*`, `Markers/*`, `Gameplay/*`, `Tide/*`; тест и переходы опираются на них.
5. **Материалы:** заменить примитивные `coral_red`/`coral_pale` на PBR-риф; сохранить палитру (`#4a1c22`, `#8c4a4a`, `#6b5550`, `#d8cfc0`, `#141018`, `#05070c`, `#2f7fa8`, `#ff8a3c`, `#8a8f96`).
6. **Свет:** сохранить бледный рассеянный день, длинные тени, тёмные туннели; усилить костёр и дальние силуэты; не делать тёплый лес.
7. **Прилив:** вода и шлюзы уже работают; добавить HUD/предупреждения, утопление/возврат, штормовой сценарий; целевой цикл 16 минут.
8. **Гроза:** `StormWall` — заготовка; добавить дождь, молнии, ветер, затемнение, звук; не менять маршрут Z17.
9. **Оптимизация:** `VisibilityEnabler3D`/`OccluderInstance3D`, `MultiMesh` для костей/лезвий, объединение коллизий, LOD; проверить FPS на RTX 3060 Laptop.
10. **Контент:** расставить `TestEnemy`/карапаксов по маркерам, добавить Нефис/Кассию, Эхо, первый бой, Azure Blade, встречу и лагерь — не раньше, чем будет утверждён геймплей.

---

## 11. Предлагаемая запись в `docs/DECISIONS.md`

`docs/DECISIONS.md` не изменялся, чтобы не конфликтовать с параллельными правками Claude. Предлагаемая запись:

- **2026-11-01 — Greybox Лабиринта.** Самостоятельная сцена `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`; строитель `LabyrinthGreybox` разделяет `Generated/Visual` и `Generated/Collision`; 18 зон, ~1,5 км; прилив — сценарный прототип 120 с с 8 шлюзами; игровые точки и `Landmarks` — авторские, не пересобираются. Общие контроллер, камера, кампания и Первый Кошмар не менялись. Runtime MCP не использован из-за parse errors общих боевых скриптов; проверка — GUT + boundary audit + location capture.
