# AI handoff — Academy gameplay segment

Дата: 2026-11-03  
Статус: **игровой сегмент Академии собран и проверен headless-тестами.** Подробный отчёт: `docs/art/academy_location_build.md`.

---

## Что готово

- Две арт-локации: `academy_grounds.tscn`, `academy_sleeper_center_building.tscn`.
- Два playable-wrapper'а: `academy_grounds_playable.tscn`, `academy_sleeper_center_playable.tscn`.
- Игрок, HUD, fade, спавны, портал grounds ↔ sleeper, камера игрока.
- Красные ворота закрыты до разговора с охраной; после `academy_gate_passed` створки открываются, блокирующий коллайдер снимается.
- 23 NPC, 23 интерактивных пропса, 11 loot-тайников.
- 24 квеста: 12 основных (`AC-MQ-01…12`) + 12 побочных (`AC-SQ-01…12`), каталог `resources/quests/academy/quest_catalog_academy.tres`, scope `academy`.
- `QuestSystem` грузит оба каталога; `forgotten_shore` не изменён.
- Точки «дойти» переведены на флаги `academy_reached_*`, чтобы one-shot триггеры не ломали квесты, открывающиеся позже.
- Коллизии: рампы моста и ступеней Sleeper Center, дверь прачечной, торцевые стены коннекторов.

## Как запустить

```powershell
godot --path . res://scenes/locations/academy_playable/academy_grounds_playable.tscn
godot --path . res://scenes/locations/academy_playable/academy_sleeper_center_playable.tscn
```

В редакторе — открыть сцену и **F6**. Сегмент также доступен из главного меню кнопкой **«Академия · ALPHA»**; M1-маршрут при этом не меняется.

## Проверки

| Проверка | Результат |
|---|---|
| `qa_script_audit.gd` | 392/0 |
| `qa_resource_audit.gd` | 762/0 |
| Full GUT | 723/723, 7882 asserts |
| `test_post_nightmare_locations.gd` | 16/16 |
| `test_full_route.gd` | 3/3 |
| `test_quest_system`, `test_quest_extensions`, `test_side_quests`, `test_labyrinth_quest_content` | 33/33 |
| `academy_gameplay_probe.gd` | 0 failures |
| `academy_interaction_probe.gd` | 0 failures |
| `academy_navigation_probe.gd` | 0 failures |
| `academy_walkthrough_probe.gd` | 24/24 quests, 0 failures |

## Не проверено

- Живой ручной проход мышью/геймпадом.
- 1080p/60 FPS, draw calls, LOD/occlusion.
- Финальный art pass (Hollow, комнаты, лица NPC, дальний план).
- Аудио: шаги, вентиляция, Hollow, капсулы.
- Сохранение/загрузка academy-прогресса между сессиями.
- `git status` падает на clean-фильтре `.glb` (Git LFS); Stage 5 закоммитил сегмент через `feature/academy-gameplay`.

## Важные файлы

- `scripts/locations/academy/academy_gameplay_director.gd` — весь игровой контент.
- `scripts/locations/academy/academy_playable_location.gd` — wrapper, scope, HUD/audio.
- `scripts/quests/quest_system.gd` — мультикаталоговый scope.
- `resources/quests/academy/` — 24 `.tres` + каталог.
- `resources/loot/academy/` — 3 пула.
- `tools/audit/academy_*_probe.gd` — проверки.
- `tools/audit/academy_gameplay_capture.gd` — rendered-кадры.

## Следующий шаг

1. Живой ручной проход и проверка камеры/мыши/геймпада.
2. Профилирование и LOD/merge/occlusion.
3. Финальный art pass и звук.
4. Достроить интерьеры столовой, додзё, академического крыла и медкорпуса либо перенести их NPC внутрь.
5. Починить кодировку `docs/DECISIONS.md` и перенести туда решения из отчёта.
