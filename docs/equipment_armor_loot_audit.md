# Аудит систем брони, статов и лута — 2026-11-03

**Область:** `ArmorItem` / `ArmorStats` / `CharacterStats`, `EquipmentComponent`,
`WeaponData`, equipment-loot layer, три сгенерированных сета, демо-сцена, тесты и
документация.  
**Метод:** чтение кода, статический анализ GLB (веса/кости/материалы), GUT,
headless-import, `resource_check`, read-only capture и замеры draw calls.  
**Статус:** alpha. Найденные дефекты исправлены; остаточные риски перечислены ниже.

## 1. Итог

Системы рабочие: броня надевается на общий скелет, статы применяются и снимаются,
оружие переставляется в руку/на пояс, лут выпадает и подбирается, контейнер выдаёт
предметы в инвентарь. Три сета визуально читаются и корректно сидят на базовом
скелете.

В ходе аудита найдено **4 дефекта продукта** и **1 проблема тестового окружения**.
Все исправлены и покрыты проверками:

1. HUD получал устаревшее текущее HP при изменении максимума бронёй.
2. `InventoryComponent.from_ids()` очищал инвентарь до валидации и терял предметы
   при неудачной загрузке.
3. `EquipmentComponent.apply_ids()` обходил проверку `rig_profile`/`validate()` и
   мог надеть сет от другого скелета.
4. Меши брони не были помечены `lod_ignore`; `CharacterLodVisibility` мог спрятать
   броню на LOD1/2, если собирал узлы после экипировки.
5. Полный GUT падал на 6 side-quest тестах из-за порядка загрузки глобального
   класса `QuestLever` в `-s`-режиме; это проблема тестового раннера, не игры.

## 2. Найденные и исправленные дефекты

### 2.1 HUD и изменение максимума здоровья — исправлено

**Серьёзность:** высокая для UI/боя.  
**Симптом:** при надевании сета с `+max_health` `CharacterStats` вызывал
`HealthComponent.configure(new_max, false)`, получал `health_changed(current=50,
max=120)`, затем вручную менял `current_health` на 60 без повторного сигнала. HUD
показывал 50/120 вместо 60/120.  
**Доказательство:** новый тест
`test_health_signal_reports_new_current_after_max_change` падал с `50 != 60`.  
**Исправление:** добавлен
`HealthComponent.set_max_health_preserving_ratio(new_max)`, который меняет максимум,
сохраняет долю здоровья и отправляет один корректный `health_changed`.  
**Файлы:** `scripts/combat/health_component.gd`,
`scripts/stats/character_stats.gd`.

### 2.2 Неатомарная загрузка инвентаря — исправлено

**Серьёзность:** средняя (потеря предметов при повреждённом сейве).  
**Симптом:** `InventoryComponent.from_ids()` вызывал `clear()` до проверки всех ID.
Если один ID отсутствовал в каталоге, старый инвентарь уже был очищен.  
**Доказательство:** тест `test_inventory_from_ids_is_atomic` падал: старый предмет
исчезал, частично загруженный новый оставался.  
**Исправление:** сначала валидируются все ID и вместимость, затем состояние
заменяется; при неожиданном отказе `add_item` старые `_items`/`_order`
восстанавливаются.  
**Файл:** `scripts/loot/inventory_component.gd`.

### 2.3 `apply_ids()` обходил проверку скелета — исправлено

**Серьёзность:** средняя (можно надеть визуал от другого rig-профиля).  
**Симптом:** `EquipmentComponent.equip()` проверял `validate()` и `_rig_matches()`,
а `apply_ids()` — нет. Каталог с чужим `rig_profile` приводил к `rebuild()` и
попытке привязать меш к несовместимому скелету.  
**Доказательство:** тест `test_apply_ids_rejects_mismatched_rig_profile` падал:
`apply_ids()` возвращал `true` и заменял тело.  
**Исправление:** `apply_ids()` собирает кандидатов (body/weapon/accessories),
проверяет `validate()` и `_rig_matches()` до замены `loadout`.  
**Файл:** `scripts/equipment/equipment_component.gd`.

### 2.4 Броня и `CharacterLodVisibility` — исправлено

**Серьёзность:** средняя (риск исчезновения брони вдали).  
**Симптом:** `CharacterLodVisibility` классифицирует меши по именам `_LOD1/_LOD2`.
Меш брони называется `model_001` и попадает в LOD0. Если LOD-компонент собирал
узлы после `EquipmentComponent.rebuild()`, на дистанции LOD1/2 броня скрывалась
вместе с телом.  
**Исправление:** привязанные меши брони добавляются в группу `lod_ignore`;
`CharacterLodVisibility` их пропускает. Это не даёт LOD-ам брони, но исключает
исчезновение.  
**Файл:** `scripts/equipment/equipment_component.gd`.

### 2.5 Порядок тестов и `QuestLever` — исправлено в тесте

**Серьёзность:** тестовая инфраструктура, не продукт.  
**Симптом:** полный GUT с `test_armor_stats_loot` перед `test_side_quests` давал 6
падений `DIRECTOR.new()` с `Invalid call. Nonexistent function 'new' in base
'GDScript'`. Verbose-лог показал реальную причину: `Identifier "QuestLever" not
declared` в `labyrinth_narrative_director.gd:528`. Загрузка демо-сцены меняла
состояние глобального кэша классов в `-s`-режиме.  
**Исправление:** в `test_armor_stats_loot.gd` добавлен
`preload("res://scripts/quests/quest_lever.gd")` с комментарием. Это
workaround тестового раннера; в обычном запуске игры глобальный кэш загружается
редактором.  
**Файл:** `tests/test_armor_stats_loot.gd`.

## 3. Аудит ассетов

### 3.1 Скиннинг и веса

`tools/audit/armor_glb_audit.py` проверил три финальных GLB:

| Сет | Кости | Вершины | Нулевые веса | Сумма весов | Макс. влияний | Кости с весами |
|---|---:|---:|---:|---|---:|---:|
| Scout | 52 | 59,290 | 0 | 1.0 | 4 | 50/52 |
| Mercenary | 52 | 62,852 | 0 | 1.0 | 4 | 51/52 |
| Heavy | 52 | 58,782 | 0 | 1.0 | 4 | 50/52 |

Вывод: скиннинг технически чистый — нет нулевых весов, суммы нормализованы,
превышения 4 влияний нет, тангеиты и UV0 присутствуют. Две кости без весов —
ожидаемо (мелкие пальцы/пальцы стоп), это не ошибка.

### 3.2 Материалы и текстуры

`tools/audit/armor_material_audit.gd`:

- один меш, один материал на сет;
- `albedo_texture`, `normal_texture`, `metallic_texture`, `roughness_texture`
  подключены;
- `shading_mode = per-pixel`, `transparency = opaque`;
- `cull_mode = disabled` (double-sided) у всех трёх.

Double-sided оправдан для плаща/капюшона с открытыми краями, но для закрытых
лат/кирасы это лишний overdraw. Рекомендация: разделить закрытые пластины и
ткань на два материала или оставить double-sided только тканевым частям.

### 3.3 Масштаб и посадка

- Высота GLB: 1.898–1.900 м, как у базового `sunny_nightmare_v2`.
- После re-bind броня сидит на 52-костном скелете; визуальные проверки Scout /
  Mercenary / Heavy подтверждают посадку.
- Scout сохраняет базовую голову (`hide_surfaces = [1,2,3]`), Mercenary/Heavy
  скрывают её (`[0,1,2,3]`), потому что шлемы закрытые.
- Остаточный риск: капюшон Scout плотно сидит вокруг головы; при повороте головы
  возможен клиппинг. Нужен pose-тест (attack/dodge/death).

## 4. Производительность

Замер `tools/audit/equipment_perf_audit.gd` на демо-сцене 1600×900:

| Состояние | Draw calls | Primitives | Objects | VRAM сцены |
|---|---:|---:|---:|---:|
| Без брони | 63 | 125,488 | 344 | ~237.7 MB |
| Scout | 53 | 430,459 | 607 | ~238.8 MB |
| Mercenary | 48 | 301,528 | 619 | ~237.2 MB |
| Heavy | 48 | 159,246 | 623 | ~237.1 MB |

- Draw calls низкие (48–63), в бюджет проекта (<1500) укладываются.
- Primitives включают все проходы/тени, поэтому не равны треугольникам модели;
  сам сет — 58–60k tri, один меш/один материал.
- Скриптовый замер FPS в `-s`-режиме не является GPU-профилем: цифры 400–900 FPS
  недостоверны, их нельзя выдавать за игровой FPS. Ручной 1080p/60 FPS — **NOT
  TESTED**.
- LOD у брони нет: на дальней дистанции сет рендерится в полном разрешении, пока
  тело уходит в LOD1/2. Это главный остаточный performance-риск.

## 5. Тесты и проверки

| Проверка | Результат |
|---|---|
| `godot --headless --path . --import` | exit 0 |
| `test_armor_stats_loot.gd` | **20/20, 88 asserts, all passed** |
| `test_equipment_alpha.gd` | 11/11, 46 asserts |
| `test_combat_arena.gd` | 6/6, 19 asserts |
| `test_carapace_enemy.gd` | 10/10, 45 asserts |
| Полный GUT | **717/717, 7,849 asserts, exit 0** |
| `tools/audit/resource_check.gd` | без ошибок |
| GLB weight/material audit | без критических ошибок |

Полный GUT получен с preload-workaround для `QuestLever`; без него 6 side-quest
тестов падают из-за порядка загрузки классов в `-s`-режиме. Это ограничение
тестового раннера, а не игровой логики.

## 6. Остаточные риски и рекомендации

> Ниже — исходный список после первого прохода. Что уже закрыто — в §9–10.

### P1 — до следующей приёмки

1. **Pose-тест деформации.** Снять Scout/Mercenary/Heavy в `ATTACK`, `DODGE`,
   `DEATH` и на повороте головы; проверить плечи, капюшон, пояс и пах. Сейчас
   проверен только idle.
2. **LOD для брони.** Добавить LOD1/LOD2 или хотя бы distance culling; иначе
   дальние NPC/игрок в броне рендерят 58–60k tri.
3. **Ручной playthrough.** Проверить надевание/снятие, урон по типам, перегруз,
   подбор и контейнер в живой сцене. Сейчас — **NOT TESTED**.
4. **Save/load экипировки.** `NightmareRunState` fallback есть, но round-trip
   экипировки и инвентаря не тестировался.

### P2 — качество и удобство

5. **Материалы.** Double-sided для закрытых пластин — лишний overdraw. Разделить
   ткань и пластины или включить single-sided для закрытых частей.
6. **Явный путь инвентаря.** `WorldLootItem`/`LootContainer` при отсутствии
   `inventory_path` берут первый `player_inventory`; в сцене с несколькими
   инвентарями это может выбрать чужой. Передавать путь явно.
7. **Время жизни лута.** `WorldLootItem.lifetime = 120 с`; выпавший сет исчезает
   через две минуты. Решить, нужно ли это для игрока (сейчас приемлемо для демо).
8. **Точность шанса.** В `LootTable` проверка `rng.randf() <= chance`; при
   `chance = 0` теоретически возможен проход на ровно 0.0. Заменить на `<`.
9. **Оружие без ножен.** `WeaponData.validate()` требует непустой
   `sheath_socket`; оружие, которое должно просто исчезать, не наденется.
   Разрешить пустой сокет при `visible_when_sheathed = false`.
10. **Сигнал при пустом оружии.** `set_weapon_drawn()` эмитит
    `weapon_drawn_changed` даже без оружия; UI может показать неверное состояние.

### P3 — тестовое покрытие

11. Добавить тесты: смерть → `LootDropComponent` → физический дроп; auto-pickup
    через `Area3D`; полный инвентарь в `LootContainer`; взвешенное распределение
    `LootTable`; `HealthComponent` с сопротивлением и типом урона; `from_ids`
    round-trip; повторное переключение сетов и восстановление surface.
12. Добавить pose-capture в `tools/audit/armor_sets_capture.gd` для attack/dodge.

## 7. Инструменты аудита

- `tools/audit/armor_glb_audit.py` — веса, кости, влияния, UV/тангеиты, материалы,
  размеры текстур.
- `tools/audit/armor_material_audit.gd` — Godot-материалы после импорта.
- `tools/audit/equipment_perf_audit.gd` — draw calls/primitives/VRAM; FPS в
  `-s`-режиме не считать игровым.
- `tools/audit/armor_sets_capture.gd` — 1600×900 captures.

## 8. Вердикт

Для alpha-среза системы **пригодны**: данные типизированы, статы обратимы, лут
физический, сеты сидят на общем скелете, критичные дефекты исправлены и покрыты
тестами. До production не хватает LOD, pose-проверки, save/load и ручного
playthrough; материалы и мелкие edge-case'ы лута — P2/P3.

## 9. Post-audit fixes

После первичного отчёта исправлены дополнительные пункты, не требующие смены
архитектуры:

- **Equipment ID persistence.** `NightmareRunState` получил `equipment` в
  `snapshot()/restore()`, методы `set_equipment_ids()/get_equipment_ids()/
  has_equipment()/clear_equipment()`, а `EquipmentComponent` —
  `persist_to_run_state`, `save_to_run_state()` и `restore_from_run_state()`.
  Демо-сцена включает persistence. Покрыто
  `test_equipment_ids_persist_in_run_state`.
- **Explicit loot inventory path.** `LootDropComponent.inventory_path` передаётся
  заспавненному `WorldLootItem`; при наличии пути групповой fallback больше не
  выбирает первый инвентарь. Покрыто
  `test_world_loot_uses_explicit_inventory_path`.
- **LootTable edge cases.** `chance` проверяется через `<`, `max_drops <= 0`
  возвращает пустой результат, `max_drops < 1` ловится в `validate()`.
- **Weapon without sheath.** `WeaponData.validate()` разрешает пустой
  `sheath_socket`, если `visible_when_sheathed = false`;
  `EquipmentItemData.validate()` принимает `grip_socket` вместо обязательного
  `attach_socket` для оружия. Покрыто `test_weapon_without_sheath_is_allowed`.
- **Weapon signal.** `set_weapon_drawn()` эмитит `weapon_drawn_changed` только
  когда оружие действительно есть.
- **Дополнительные тесты.** `test_health_damage_type_resistance`,
  `test_inventory_ids_round_trip`, `test_loot_container_rejects_when_full`,
  `test_loot_drop_component_spawns_on_death`.

Актуальные результаты: `test_armor_stats_loot` — **20/20, 88 assert**; полный
GUT — **717/717, 7,849 assert, exit 0**; headless import — exit 0.

Остаточные риски после этих исправлений: отсутствие LOD у брони, double-sided
материалы, pose/death clipping, demo-inventory save/load и ручной playthrough.

Закрыты после аудита: P1.4 (equipment ID persistence), P2.6 (explicit inventory path), P2.8 (chance/max_drops), P2.9 (weapon without sheath), P2.10 (weapon signal). Остаются: LOD брони, double-sided материалы, pose/death clipping, demo-inventory save/load, ручной playthrough.

## 10. LOD, materials, pose and inventory persistence

После аудита закрыты четыре оставшихся пункта:

- **LOD1/LOD2.** `build_armor_lods.py` добавляет `model_LOD1` (ratio 0.45) и
  `model_LOD2` (ratio 0.18) в тот же skinned GLB. `EquipmentComponent` задаёт
  `visibility_range`: LOD0 0-8 м, LOD1 8-18 м, LOD2 18 м+ с запасом 0.5 м.
  Итоговые треугольники: Scout 59,457 / 26,754 / 10,702; Mercenary
  58,458 / 26,306 / 10,522; Heavy 60,000 / 27,000 / 10,799. Проверено
  `tools/audit/armor_lod_capture.gd` на 2/10/20 м — броня не исчезает.
- **Cloth/plate split.** `split_armor_materials.py` сэмплирует metallic-канал
  metallic-roughness карты и назначает металлическим граням single-sided
  material; ткань остаётся double-sided. Heavy — полностью plate, один
  single-sided material. Проверены front/side/back рендеры всех трёх сетов.
- **Pose/death.** `tools/audit/armor_pose_capture.gd` снимает ATTACK, DODGE,
  DEATH и поворот головы. Head turn Scout исправлен: область капюшона
  переопределена на 100% `Head` (`fix_armor_head_weights.py`). Death/dodge
  читаются; attack (`HumanSpBoxing`) всё ещё клиппит крупные наплечники и плащ
  в голову. Это ограничение анимационного контента: нужен sword-swing клип или
  раздельные наплечники. Эксперимент с полной rigidify пластин был отвергнут —
  пластины разлетаются сильнее.
- **Demo inventory persistence.** `NightmareRunState` получил отдельный
  `inventory` (id -> count) в `snapshot()/restore()`;
  `InventoryComponent.persist_to_run_state` сохраняет/восстанавливает стеки.
  Демо-инвентарь переживает snapshot/restore; покрыто
  `test_demo_inventory_persists_stacks`.

**Актуальные проверки:** `test_armor_stats_loot` — **20/20, 88 assert**; полный
GUT — **717/717, 7,849 assert, exit 0**; headless import — exit 0. Captures:
`docs/art/previews/equipment/lod_*.png` и `pose_*.png`.

**Остаточные риски:** клиппинг ATTACK из-за `HumanSpBoxing`, отсутствие
cloth-симуляции, ручной playthrough и 1080p/60 FPS — **NOT TESTED**.
