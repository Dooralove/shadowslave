# Аудит систем лута, контейнеров и секретов

**Дата:** 2026-11-03.
**Область:** generic-лут Лабиринта (`LootItemData`, `LootPool`, `LootPoolEntry`, `LootCatalog`, `LootPoolRoller`, `LootCache`, `LootDropper`), 11 пулов, 27 предметов, 10 размещённых тайников, 3 GLB-контейнера, интеграция с `NightmareRunState`, `LabyrinthQuestDirector`, `RpgMeditationScreen`.
**Метод:** чтение кода и данных, статические проверки, детерминированные прогоны 1000 роллов, headless-тесты, runtime-проверка через Godot MCP, визуальные капчеры, полный GUT.
**Статус:** аудит завершён; P0–P3 исправления внесены (LootBag, коллизии, Lid, Glow, флейвор, иконки, стек-лимиты, runtime-каталог, сохранение мешков); остаточные рекомендации перечислены ниже. Ручной проход — **NOT TESTED**.

---

## 0. Итог одной страницей

| Оценка | Вывод |
|---|---|
| **Данные** | 27 предметов, 11 пулов; id уникальны, все ссылки валидны, все предметы используются. |
| **Роллы** | Детерминированы; `GD_FUTURE` фильтруется; `unique` теперь проверяется. |
| **Контейнеры** | 10/10 стоят на полу, не пересекают коллизии, id уникальны. |
| **Сохранение** | Флаг открытия переживает `snapshot()`/`restore()`; повторной выдачи нет. |
| **Runtime** | Прямой `interact()` в запущенной сцене сработал: 3 кристалла, верёвка, вода, копьё, флаг. |
| **Главный риск** | **Закрыт:** `LootDropper` создаёт физический `LootBag`; выдача только по `E`. |
| **Второй риск** | **Закрыт:** у контейнеров есть `StaticBody3D`; игрок больше не проходит сквозь них. |
| **Третий риск** | **Закрыт:** крышка сундука и плита саркофага разделены в Blender; `Lid` анимируется (100° / 75°), плюс `Label3D` «Обыскано» и пыль. |
| **Производительность** | 10 моделей ≈ 73k tri, 10 draw calls, 10 omni-светов; 1080p не валидировался. |

---

## 1. Что проверялось

### 1.1. Данные

- `resources/loot/loot_catalog.tres` — 27 `LootItemData`.
- `resources/loot/items/*.tres` — 27 предметов.
- `resources/loot/tables/*.tres` — 11 `LootPool`.
- `resources/loot/README.md` — структура.

### 1.2. Код

- `scripts/loot/loot_item_data.gd`
- `scripts/loot/loot_pool_entry.gd`
- `scripts/loot/loot_pool.gd`
- `scripts/loot/loot_drop.gd`
- `scripts/loot/loot_pool_roller.gd`
- `scripts/loot/loot_cache.gd`
- `scripts/loot/loot_dropper.gd`
- `scripts/loot/loot_catalog.gd`

### 1.3. Интеграция

- `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn` → `Gameplay/Interactables/Secrets`.
- `scenes/loot/containers/*.tscn`.
- `scripts/locations/forgotten_shore_labyrinth/labyrinth_quest_director.gd` → `LootDropper` на карапаксах.
- `scripts/campaign/nightmare_run_state.gd` → `ITEM_IDS`.
- `scripts/ui/rpg_menu/rpg_meditation_screen.gd` → `ITEM_TITLES`.
- `tests/test_labyrinth_quest_content.gd` → ожидание +1 кристалл от дроппера.

### 1.4. Инструменты

- `tools/audit/loot_pool_test.gd` — функциональный тест.
- `tools/audit/loot_save_roundtrip_test.gd` — сохранение/загрузка.
- `tools/audit/loot_secret_audit.gd` — пол/пересечения.
- `tools/audit/loot_data_audit.gd` — целостность данных.
- `tools/audit/loot_table_probe.gd` — фактические роллы и экономика.
- `tools/audit/loot_secret_capture.gd` — 10 in-context PNG.
- Godot MCP runtime — прямой `interact()` в живой сцене.

---

## 2. Дефекты, исправленные в ходе аудита

### 2.1. [High] Реликтовые части сета были недостижимы

**Симптом.** Один общий пул `cache_ossuary_relic` использовался двумя саркофагами. Фиксированные seed-ы Z15 и Z18 не выбрасывали ни одну из трёх частей сета. Фактический прогон:

```text
CACHE secret_z15_ossuary ... -> Осколок души ×10, Древняя коралловая пластина ×1
CACHE secret_z18_ossuary ... -> Осколок души ×10, Древняя коралловая пластина ×1
UNIQUE_RELIC_DROPS {  }
```

**Причина.** Шанс части сета был ~51% на саркофаг, но оба фиксированных seed-а попали в бонусные кристаллы. «Редкая броня в склепах» существовала в данных, но не в прохождении.

**Исправление.** Пул разделён на два:

- `cache_ossuary_relic_helm.tres` — Z15, гарантирует `reef_warden_helm`;
- `cache_ossuary_relic_plate.tres` — Z18, гарантирует `reef_warden_plate`;
- `reef_warden_greaves` остаётся бонусом.

**Проверка после исправления:**

```text
CACHE secret_z15_ossuary -> Осколок души ×5, пластина ×1, шлем ×1, поножи ×1
CACHE secret_z18_ossuary -> Осколок души ×7, пластина ×1, нагрудник ×1
UNIQUE_RELIC_DROPS { helm: 1, greaves: 1, plate: 1 }
```

### 2.2. [Medium] `unique` не проверялся при выдаче

**Симптом.** `LootDrop.unique` выставлялся, но `LootPoolRoller.apply()` просто вызывал `add_item()`. Два разных источника могли выдать одну и ту же уникальную часть сета.

**Исправление.** В `LootPoolRoller.apply()` добавлена проверка `_already_owned()`:

- Memories проверяются через `has_memory`;
- остальные уникальные предметы — через `has_item`;
- повторный уникальный дроп пропускается.

**Проверка:** `UNIQUE helm_count=1 OK`.

### 2.3. [Medium] Seed вражеского дропа зависел от места смерти

**Симптом.** `LootDropper` использовал `pool.id + global_position` при смерти. Игрок мог увести врага в другое место и получить другой ролл; перезагрузка и убийство в другой точке меняли добычу.

**Исправление.** Добавлен `drop_seed`; `LabyrinthQuestDirector` выставляет `hash(enemy_tag)`. Если `drop_seed = 0`, остаётся старый fallback по позиции.

### 2.4. [Low] Износ показывался у материалов

**Симптом.** `LootDrop.to_text()` добавлял «(подержан)» к любому предмету с `condition < 0.7`, включая коралловую пластину.

**Исправление.** Суффикс износа показывается только для `EQUIPMENT` и `RELIC`.

### 2.5. [High] Автовыдача вражеского лута заменена на `LootBag`

**Исправление.** `LootDropper` больше не вызывает `apply()` при смерти. Он роллит пул, создаёт `scenes/loot/loot_bag.tscn`, кладёт туда `Array[LootDrop]` и ставит флаг `loot_<tag>_dropped` (мешок уже создан). Игрок подходит и нажимает `E`; только тогда `LootBag.interact()` выдаёт предметы и показывает тост.

**Проверка:**

```text
DROPPER before=4 after_death=4 after_pickup=5 flag=true bag=true icon=true OK
```

`after_death == before` доказывает отсутствие автовыдачи; `after_pickup > before` — выдачу по взаимодействию.

### 2.6. [Medium] Контейнеры получили коллизию и open-state

**Исправление.**

- В `chest_wood_iron.tscn`, `loot_barrel_cluster.tscn`, `ancient_tomb_sarcophagus.tscn` добавлены `StaticBody3D` + `CollisionShape3D` (layer 1, mask 0) с box по габаритам модели.
- `loot_secret_audit` исключает собственный `StaticBody3D` из ray/overlap-запросов.
- Крышка сундука и плита саркофага разделены в Blender на `Body`/`Lid`; origin `Lid` — задняя петля. `LootCache` анимирует `Lid` (100° / 75°).
- В контейнеры добавлен `Label3D` «Обыскано», который появляется после открытия; `LootCache` также спавнит `impact_dust`.
- `Glow` поднят над моделью (1.15 / 1.05 / 1.85 м), чтобы подсказка читалась.

**Проверка:**

```text
CACHE ... collision=true
LOOT_DATA_AUDIT failures=0
LOOT_SECRET_AUDIT count=10 failures=0
CHEST ... label=true OK
```

---

## 3. Находки и статус

### 3.1. [Fixed] Вражеский лут выдаётся автоматически, а не вручную

**Было.** `LootDropper._on_died()` сразу вызывал `LootPoolRoller.apply()`; игрок получал кристаллы и трофеи в момент смерти. Это конфликтовало с `12_inventory_economy_and_consumables.md` §0.1/§13.4.

**Стало.** Создаётся физический `LootBag`; выдача — только по `E`. Подробности и проверка — §2.5.

**Сохранение.** `NightmareRunState` хранит `loot_bags` (bag_id, сцена, позиция, сериализованные дропы); `LootBagPersistence` восстанавливает неподобранные мешки после загрузки сцены. Проверено `BAG_PERSIST`: `record=true`, `restored=true`, `cleared=true`. Файловый `SaveSystem` с мешками — **NOT TESTED**.

### 3.2. [Fixed] У контейнеров нет коллизии

**Было.** `loot_data_audit` показывал `collision=false` для всех 10 тайников.

**Стало.** Добавлены `StaticBody3D` + box `CollisionShape3D`; `loot_secret_audit` исключает собственный body. Подробности — §2.6.

### 3.3. [Fixed] Нет анимации крышки

**Было.** Модели — один меш; после открытия крышка/плита оставались закрытыми.

**Стало.** Меши разделены в Blender на `Body` и `Lid` с origin в задней петле. `LootCache` анимирует `Lid` вокруг X: сундук 100°, саркофаг 75°. После открытия также появляется `Label3D` «Обыскано» и пыль (`impact_dust`), `Glow` гаснет.

**Проверка:** `CHEST ... lid=100.0 OK`, `SARCOPHAGUS lid=75.0 OK`, `fresh_lid=100.0` после restore.

### 3.4. [Fixed] `Glow` находился внутри модели

**Было.** `Glow` стоял на `y = 0.55–0.80`, внутри меша; свечения не было видно.

**Стало.** Свет поднят над моделью: 1.15 м (сундук), 1.05 м (бочки), 1.85 м (саркофаг).

### 3.5. [Fixed] Одинаковые детерминированные исходы

**Было.** Z09/Z13 бочки и Z14/Z17 сундуки выдавали одинаковые наборы.

**Стало.** У каждого из четырёх тайников есть гарантированный `flavor_item`:

- Z09 — `torch`;
- Z13 — `carapace_plate`;
- Z14 — `field_medkit`;
- Z17 — `bone_spear`.

Фактический `loot_table_probe` показывает разные наборы; общий пул при этом остаётся один.

### 3.6. [Low] Экономика требует плейтеста

Средние значения по 1000 роллов:

| Пул | Среднее предметов | Среднее кристаллов |
|---|---:|---:|
| сундук | 5.82 | 2.50 |
| бочки | 4.29 | 0.91 |
| common оссуарий | 6.14 | 4.01 |
| relic оссуарий | 8.39 | 5.77 |

Суммарно контейнеры дают ~28 кристаллов, плюс 6 с карапаксов и 8 с квестов. Для 18 зон это в грубом бюджете, но relic-саркофаги заметно щедрее обычных сундуков. Нужен плейтест на 45–60 минут.

### 3.7. [Fixed] `stack_max` теперь ограничивает выдачу

`LootPoolRoller.apply()` возвращает остаток; `LootBag` оставляет его в мешке, `LootCache` создаёт overflow-мешок. Проверено `STACK_LIMIT` и `CACHE_OVERFLOW`.

### 3.8. [Fixed] Иконки и физический мешок

`LootItemData.icon` заполнен 8 категорийными иконками из `assets/ui/loot/icons/`; `LootBag` показывает иконку первого предмета через `Sprite3D`. Полноценный слотовый инвентарь всё ещё не реализован.

### 3.9. [Fixed] `LootCatalog` доступен в runtime

`LootRegistry` загружает `loot_catalog.tres` один раз и используется сериализацией, стек-лимитами и иконками.

### 3.10. [Low] Нестрогая валидация `LootPool`

`LootPool.validate()` не проверяет:

- допустимые `canon_status` (`CANON`/`TEXT`/`GD`/`GD_FUTURE`);
- дубли item id внутри пула;
- сумму весов;
- `empty_chance` в диапазоне (спасает только `@export_range` в редакторе);
- `unique`-конфликты между пулами.

Текущие данные проверены отдельным `loot_data_audit` (0 failures), но runtime-валидация могла бы быть строже.

### 3.11. [Low] Разные единицы `empty_chance` в двух слоях

- старый equipment-only `LootTable` — `0.0–1.0` (доля);
- новый `LootPool` — `0.0–100.0` (проценты).

Оба слоя внутренне согласованы, но будущий разработчик может перепутать. В README и DECISIONS указано разделение; при объединении слоёв переименовать в `empty_chance_percent`.

### 3.12. [Low] 10 omni-светов и 10 `_process`

Каждый `LootCache` имеет `Glow` (OmniLight3D, shadow off) и пульсирует в `_process`. 10 штук на 1.5 км — незначительно, но при масштабировании на 50+ контейнеров лучше включать свет/процесс по дистанции (`VisibilityEnabler3D` или ручной distance-check).

### 3.13. [Info] Два слоя лута

Старый equipment-only прототип (`LootTable`, `LootEntry`, `LootDropComponent`, `WorldLootItem`, `InventoryComponent`) оставлен без изменений. Новый generic-слой работает с `NightmareRunState`. Это осознанное разделение, но в папке `scripts/loot/` теперь два набора классов. При следующем этапе решить: слить, пометить старый слой `deprecated` или оставить только для dev-арены.

### 3.14. [Info] Саркофаги — GD, не канон

Три саркофага (Z06, Z15, Z18) — GD-адаптация. Для строгого канона удалить их, оставив 4 сундука и 3 бочки. Это не затронет квесты и маршрут.

### 3.15. [Info] Лицензия Hyper3D

Модели сгенерированы на аккаунте проекта. Перед релизом проверить актуальные условия Hyper3D; запись в `docs/ASSET_LICENSES.md`.

---

## 4. Проверки и доказательства

### 4.1. Целостность данных

```text
ITEMS count=27 unique=27
POOLS count=11 unique=11
CACHES count=10 unique=10
LOOT_DATA_AUDIT failures=0
```

### 4.2. Функциональный тест

```text
CHEST shards=3 rope=1 flag=true opened_signals=1 repeat_shards=3 repeat_rope=1 label=true lid=100.0 OK
SARCOPHAGUS lid=75.0 OK
DROPPER before=4 after_death=4 after_pickup=5 flag=true bag=true icon=true OK
BAG_PERSIST record=true restored=true shards_before=0 after=1 cleared=true OK
STACK_LIMIT held=3 retained=true after=3 freed=true OK
CACHE_OVERFLOW held=3 overflow=true after=1 OK
FUTURE_FILTER without=0 with=134 OK
UNIQUE helm_count=1 OK
SCAVENGER drops=Осколок души ×1, Клешня карапакса ×1 OK
LOOT_POOL_TEST failures=0
```

### 4.3. Сохранение/загрузка

```text
SAVE_ROUNDTRIP shards=3 rope=1 flag=true reset=false restored=true
fresh_opened=true fresh_enabled=false fresh_lid=100.0 repeat_shards=3 repeat_rope=1 OK
```

### 4.4. Пол и пересечения

```text
SECRET Secret_Z02_WreckChest ... delta=0.00 overlaps=0 OK
...
SECRET Secret_Z18_CliffOssuary ... delta=0.00 overlaps=0 OK
LOOT_SECRET_AUDIT count=10 failures=0
```

### 4.5. Runtime

Прямой `interact()` в запущенной сцене:

```text
chest._opened = true
chest.enabled = false
NightmareRunState._currency = { "soul_shard": 3 }
NightmareRunState._items = { "bone_spear": 1, "rope": 1, "water_skin": 1 }
NightmareRunState._flags["loot_secret_z02_wreck_chest_opened"] = true
```

Живое нажатие `E` через `Interactor` не проверено: при телепорте игрока к тайнику срабатывает чекпоинт/восстановление и уводит персонажа. Сам `Interactor` не менялся; прямой runtime-вызов контейнера работает.

### 4.6. Полный GUT

После обновления global class cache (`godot --headless --path . --import`):

```text
Scripts 89, Tests 717, Passing 717, Asserts 7849, All tests passed, exit 0
```

Промежуточный прогон до `--import` показывал 7 падений (`city_skyline`/`world_frame`/`QuestLever`); после обновления кэша они исчезли. Это был stale global class cache, а не лут-регрессия. Лут-тесты (`loot_pool_test`, `loot_save_roundtrip_test`, `loot_data_audit`, `loot_secret_audit`) и `test_labyrinth_first_fragment` / `test_labyrinth_quest_content` также проходят.

### 4.7. Производительность

Runtime snapshot в запущенной сцене:

```text
fps=145, frame_time_ms=4.43, physics_process_time_ms=11.72,
nodes=4367, total_objects=10240, static_memory_mb=439.1,
draw_calls=0, objects_in_frame=0
```

`draw_calls=0` означает, что окно не рендерило кадр в момент замера; **1080p 60 FPS не подтверждён**. Оценка по ассетам: 10 моделей × ~7.3k tri ≈ 73k tri, 10 draw calls, 10 omni-светов — риск низкий, но нужен реальный замер в окне.

---

## 5. Приоритетный план исправлений

| Приоритет | Действие | Ожидаемый эффект |
|---|---|---|
| ~~P0~~ | ~~Решить контракт «ручная добыча»~~ — **Done:** `LootBag` | Конфликт с дизайн-документом закрыт |
| ~~P1~~ | ~~Добавить коллизии контейнерам + обновить audit~~ — **Done** | Контейнеры больше не «призраки» |
| ~~P1~~ | ~~Разделить крышки/плиты и добавить анимацию~~ — **Done:** `Body`/`Lid`, 100° / 75° | Крышки открываются |
| ~~P2~~ | ~~Поднять/переместить `Glow`~~ — **Done:** 1.15 / 1.05 / 1.85 м | Тайники читаются с дистанции |
| ~~P2~~ | ~~Добавить флейвор-записи~~ — **Done:** torch/plate/medkit/spear | Убирает одинаковые исходы |
| P2 | Плейтест экономики (45–60 мин) | Проверить 28+ кристаллов и relic-щедрость |
| ~~P3~~ | ~~Иконки, физические мешки, `stack_max`~~ — **Done:** 8 иконок, `LootBag` + `Icon`, стек-лимиты с остатком | UI/инвентарь следующего этапа |
| P3 | Ужесточить `LootPool.validate` | Раннее ловление ошибок данных |
| P3 | Решить судьбу старого equipment-only слоя | Меньше путаницы в `scripts/loot/` |

---

## 6. NOT TESTED

- Полный ручной проход 45–60 минут с открытием всех 10 тайников.
- Живое нажатие `E` через `Interactor` для контейнера и `LootBag` (прямой `interact()` проверен).
- 1080p 60 FPS в реальном окне.
- Визуальная проверка всех 10 капчеров (проверены Z02, Z11, Z15, Z18; остальные 6 сохранены).
- Route/boundary-аудит **запущен**: `docs/design/route_boundary_audit_2026-11-03.md`; route 18/18 зон, 61/61 POI, boundary не флагует контейнеры.
- Save/load через файл `SaveSystem` (проверен только `snapshot()`/`restore()`).
- Локализация названий предметов.
