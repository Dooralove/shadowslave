# Route и boundary-аудит Лабиринта после коллизий контейнеров

**Дата:** 2026-11-03.
**Сцена:** `res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`.
**Причина:** после добавления `StaticBody3D` контейнерам нужно было проверить, что они не перекрыли маршрут и не создали новых смертельных краёв.

---

## 1. Route reachability

Команда:

```powershell
godot --headless --path . -s tools/audit/route_reachability.gd -- \
  --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn \
  --step=1.5
```

Результат:

```text
zone_result=18/18
poi_result=61/61
```

`route_reachability.gd` дополнен: он теперь включает `LootCache` в список POI, поэтому проверяет не только маркеры, но и все 10 тайников.

| Секрет | Позиция | Ближайшая клетка | dxz | dy | Результат |
|---|---|---:|---:|---:|---|
| `Secret_Z02_WreckChest` | `(19.0, -1.5, 36.2)` | `(18.0, -1.5, 36.0)` | 1.0 | 0.0 | PASS |
| `Secret_Z06_Ossuary` | `(-52.0, 6.0, 49.5)` | `(-51.0, 6.0, 49.5)` | 1.0 | 0.0 | PASS |
| `Secret_Z09_Barrels` | `(-82.0, 0.0, 21.2)` | `(-81.0, 0.0, 21.0)` | 1.0 | 0.0 | PASS |
| `Secret_Z11_TideChest` | `(-137.5, -6.0, 26.5)` | `(-138.0, -6.0, 25.5)` | 1.1 | 0.0 | PASS |
| `Secret_Z13_Barrels` | `(-505.0, 0.0, 24.0)` | `(-504.0, 0.0, 24.0)` | 1.0 | 0.0 | PASS |
| `Secret_Z14_BridgeChest` | `(-638.0, 2.0, 19.5)` | `(-639.0, 2.0, 19.5)` | 1.0 | 0.0 | PASS |
| `Secret_Z15_RelicOssuary` | `(-708.0, 18.0, -28.0)` | `(-706.5, 18.0, -28.5)` | 1.6 | 0.0 | PASS |
| `Secret_Z16_Barrels` | `(-1025.0, 0.0, -32.0)` | `(-1026.0, 0.0, -31.5)` | 1.1 | 0.0 | PASS |
| `Secret_Z17_StormChest` | `(-1280.0, -2.0, 27.5)` | `(-1281.0, -2.0, 27.0)` | 1.1 | 0.0 | PASS |
| `Secret_Z18_CliffOssuary` | `(-1415.0, 35.0, 7.5)` | `(-1414.5, 35.0, 6.0)` | 1.6 | 0.0 | PASS |

**Вывод:** коллизии контейнеров не перекрыли ни один маршрут и не сделали ни один тайник недостижимым.

---

## 2. Boundary audit

Команда:

```powershell
godot --headless --path . -s tools/audit/boundary_audit.gd -- \
  --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn \
  --out="$env:TEMP/opencode/boundary_labyrinth" --step=1.5
```

Результат:

```text
seeds = 10
flood cells = 146390
lethal edges = 3482
lethal jumps = 2
ghost floors = 2 (Z10_CoralHill/@Node3D@1087)
floating objects = 61
```

**Важно:** ни один `Secret_*` и ни один `Loot*` не попал в списки `floating objects` или `lethal edges`. Новые контейнеры и их `StaticBody3D` не добавили boundary-флагов.

Остальные 3 482 смертельных края, 2 смертельных прыжка, 2 призрачных пола (Z10_CoralHill) и 61 висящий объект — это существующая геометрия Лабиринта: открытые кромки масс, статуя, западный шпиль, утёсы и старые art-объекты. Boundary-аудит писался для небольших art-сцен и на 1,5-километровом Лабиринте даёт базовый шум, а не список регрессий. `--write-boundary` не использовался: он бы расставил невидимые стены по всем краям и изменил уровень.

**Вывод:** регрессий от коллизий контейнеров нет; общий boundary-долг Лабиринта остаётся отдельной задачей level design.

---

## 3. Что ещё проверено

- `loot_secret_audit` — 10/10 тайников на полу, `delta=0.00`, `overlaps=0`.
- `loot_data_audit` — 27 items / 11 pools / 10 caches, `failures=0`, у всех `collision=true`.
- `loot_pool_test` — CHEST (lid 100°), SARCOPHAGUS (lid 75°), DROPPER (bag + icon), BAG_PERSIST, STACK_LIMIT, CACHE_OVERFLOW, FUTURE_FILTER, UNIQUE, SCAVENGER — `failures=0`.
- `loot_table_probe` — Z09/Z13/Z14/Z17 получили разные flavor-предметы (torch/plate/medkit/spear).
- Полный GUT — **717/717, 7849 asserts, exit 0**.

**NOT TESTED:** ручной проход, живое нажатие `E` на каждом тайнике, 1080p 60 FPS.
