# Loot data

Типизированные ресурсы лута для Лабиринта Забытого берега.

## Структура

```text
resources/loot/
  loot_catalog.tres          LootCatalog: все 27 предметов
  items/<id>.tres            LootItemData: id, название, категория, стек, канон-статус
  tables/<id>.tres           LootPool: guaranteed + entries + bonus_rolls
```

## Вражеский лут

`LootDropper` при смерти врага создаёт `scenes/loot/loot_bag.tscn` и ставит
флаг `loot_<tag>_dropped`. Предметы выдаются только по `E` на `LootBag`;
автовыдачи нет.

## Как читать пул

- `guaranteed` — всегда выдаётся (ядро награды).
- `entries` — взвешенный пул; `weight` задаёт относительный шанс.
- `bonus_rolls` — сколько независимых бросков по `entries`.
- `empty_chance` — шанс, что `entries` не дадут ничего; `guaranteed` остаётся.
- `canon_status` — `CANON`, `GD`, `GD_FUTURE`.
- `GD_FUTURE`-предметы не выпадают, если у контейнера `include_future = false`.

## Пул — источник правды

Не редактируй `.tres` вручную, если хочешь сохранить воспроизводимость: данные
собираются `tools/build_loot_resources.gd`. После правки скрипта:

```powershell
godot --headless --path . --import
godot --headless --path . -s tools/build_loot_resources.gd
```

`--import` нужен перед первой сборкой, чтобы Godot импортировал иконки
`assets/ui/loot/icons/` и builder смог записать их в `LootItemData.icon`.

## Проверки

```powershell
godot --headless --path . -s tools/audit/loot_pool_test.gd
godot --headless --path . -s tools/audit/loot_save_roundtrip_test.gd
godot --headless --path . -s tools/audit/loot_data_audit.gd
godot --headless --path . -s tools/audit/loot_secret_audit.gd
```

## Таблицы

| ID | Тип | Назначение |
|---|---|---|
| `cache_wreck_chest` | container | кованый сундук, выброшенный приливом |
| `cache_barrel_cluster` | container | тайные бочки с припасами |
| `cache_ossuary_common` | container | сухой карман / костяная куча |
| `cache_ossuary_relic_helm` | container | саркофаг Z15: гарантированный шлем сета (GD) |
| `cache_ossuary_relic_plate` | container | саркофаг Z18: гарантированный нагрудник сета (GD) |
| `enemy_carapace_scavenger` | enemy | обычный карапакс |
| `elite_carapace_centurion` | elite | Центурион + Starlight Legion Armor |
| `boss_carapace_demon` | boss | Демон + Midnight Shard |
| `boss_great_devil` | boss | Великий Дьявол + Drop of Ichor |
| `enemy_blood_fiend` | enemy | Кровавый Демон |
| `enemy_humanoid_bandit` | humanoid | GD_FUTURE: будущие люди-противники |

Полный аудит, обоснование и список размещённых тайников —
`docs/design/loot_tables_and_secrets.md`. Открытые риски и доказательства —
`docs/design/loot_system_audit_2026-11-03.md`.
