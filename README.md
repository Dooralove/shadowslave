# ShadowSlave

3D-игра на Godot 4.7.2 (GDScript). Текущее состояние: **сквозной graybox-маршрут Первого Кошмара S00–S15** — от пролога «Nightmare Begins» до финальной карточки. Боевой прототип Milestone 4 и sandbox-арена сохранены отдельно; они не входят в канонический маршрут.

## Что готово

- Пролог B01–B16: скамейка, участок, Code Black, изолятор, брифинг, видение, пробуждение в цепи и руны.
- S01: марш каравана в цепях и прибытие к стоянке.
- S02–S06: стоянка, нападение, личинка, ключ, освобождение, повозка, падение Тирана, последействие, ветеран, Silver Bell, ночь и рассвет.
- S07–S12: разрушенная дорога, восхождение, альков, смерть Шифти, разоблачение Учёного, пещера, ранение, смерть Героя и подход к храму.
- S13: алтарь, семь подношений, появление Тирана, смерть от теней и завершение испытания.
- S14: звёздная оценка, `glorious`, True Name `Lost from Light`, Aspect `Shadow Slave`, Shadow Bond и First Seal.
- S15: пробуждение, Flaw без имени, финальная карточка и `R` → сброс в начало.

Headless-маршрут после пролога проверен 18 шагами: **35 scripts / 255 tests / 2473 asserts, all passed**. Пролог B01–B16 в этом тесте не проигрывается; полный ручной графический проход — **NOT TESTED**. См. `docs/design/first_nightmare_route_verification.md`.

## Запуск

Нужен Godot 4.7.2. Основная сцена проекта — `res://scenes/main/main.tscn` (тестовый уровень). Кампания запускается отдельно:

```powershell
godot --path . res://scenes/campaign/campaign_entry.tscn
```

В редакторе: открыть `scenes/campaign/campaign_entry.tscn` и нажать F6. Запуск `campaign_entry.tscn` сбрасывает `NightmareRunState` и начинает с пролога.

## Маршрут

```text
campaign_entry
  → first_nightmare_pass
  → caravan_site_arrival
  → pilgrim_path_arrival
  → sanctuary_arrival
  → appraisal_arrival
  → finale_arrival
```

`scenes/campaign/caravan_ambush.tscn` и `scenes/levels/ambush_site_demo.tscn` — неканонический sandbox. Не удалять и не считать частью маршрута.

## Управление

| Действие | Клавиша | Input Map action |
|---|---|---|
| Ходьба | W / A / S / D | `move_forward`, `move_left`, `move_back`, `move_right` |
| Бег | Shift | `sprint` |
| Прыжок | Space | `jump` |
| Обзор камерой | мышь | — |
| Освободить мышь | Escape | `release_mouse` |
| Захватить мышь | ЛКМ в окне | `capture_mouse` |
| Удар | ЛКМ | `attack` |
| Взаимодействие | E | `interact` |
| Следующая реплика | E / Space / Enter | `advance_dialogue` |
| Статус Заклятия | Tab | `open_status` |
| Карта и локации | M | `open_map` |
| Меню персонажа (RPG) | C | `open_character` |
| Закрыть карту или меню | Escape | `ui_cancel`, `release_mouse` |
| Перезапуск кампании | R | `restart` |

## Структура

- `scenes/campaign/` — обёртки маршрута и `campaign_entry.tscn`.
- `scenes/slice/` — пролог и `caravan_road.tscn`.
- `scenes/locations/caravan_site/` — лагерь, нападение, личинка, повозка, последействие.
- `scenes/locations/pilgrim_path/` — восхождение, альков, пещера, Герой, храм.
- `scenes/locations/shadow_sanctuary/` — алтарь и ритуал Тирана.
- `resources/dialogue/` и `resources/spell/` — типизированные `.tres`-ресурсы диалогов и сообщений.
- `scripts/campaign/nightmare_run_state.gd` — autoload состояния прохождения.
- `tests/` — GUT-тесты, включая `test_full_route.gd`.

## Тесты

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Целевые наборы:

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_full_route.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_caravan_site.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_pilgrim_path.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_altar_offering.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_appraisal_and_finale.gd -gexit
```

## Ограничения

- Полный ручной графический проход от `campaign_entry` до финальной карточки не выполнялся: **NOT TESTED**.
- Альков и пещера очень тёмные; тени-руки в святилище читаются как чёрные стержни; отдельный кадр стадии `TYRANT` не сохранён.
- `mark_of_divinity` — флаг-атрибут Санни, выставляется на B16 и отображается в статусе; в `ITEM_IDS` и инвентарь не входит. Страж храма B3 не реализован.
- Один полный прогон GUT дал transient-сбой в `test_mountain_king`; немедленный повтор прошёл. Тест нужно проверить на изоляцию.

## Документация

- `docs/story/first_nightmare_canonical_timeline.md` — канонические блоки 01–20.
- `docs/design/first_nightmare_scene_matrix.md` — матрица сцен, флагов и статусов.
- `docs/design/first_nightmare_route_verification.md` — 18 шагов, тесты и NOT TESTED.
- `docs/design/first_nightmare_restoration_spec.md` — спецификация и критерии приёмки.
- `docs/design/first_nightmare_gap_matrix.md` — исторический аудит и актуальная сводка.
- `docs/design/first_nightmare_prototype_flow.md` — описание сквозного прототипа.
- `docs/AI_HANDOFF_AFTER_S3_2.md` — handoff, backlog и известные проблемы.
- `docs/DECISIONS.md` — архитектурные решения.

```
project.godot        конфигурация проекта
scenes/              сцены: main/main.tscn (точка входа), characters/{sunny,sunny_waking,test_enemy}.tscn,
                     levels/{test_level,combat_arena}.tscn, slice/ (срез: prologue.tscn, locations/, props/),
                     ui/ (prologue_ui.tscn)
scripts/             GDScript: player/ (передвижение, камера, аниматор), combat/ (здоровье, хёртбокс, атака,
                     противник), slice/ (режиссёр среза, локации, CinematicActor), interaction/, dialogue/,
                     spell/ (лист статуса), world/ (сцены-обвязки), ui/ (HUD и слои среза), debug/ (PerfProbe), quests
resources/           типизированные Resource (.tres): characters/sunny_attack.tres,
                     enemies/test_enemy_attack.tres, dialogue/prologue/ (реплики среза),
                     spell/sunny_status.tres, slice/ (карты клипов), items, quests
assets/              исходные ассеты (через Git LFS для бинарных форматов):
                     characters/sunny_placeholder/ — временная модель Санни (KayKit, CC0)
                     characters/enemy_placeholder/ — временная модель противника (KayKit, CC0)
tests/               тесты GUT
docs/                документация проекта: README.md (навигация), DECISIONS.md, ASSET_LICENSES.md, разделы art/, story/, design/, production/
addons/              сторонние плагины: godot_mcp, gut
```

- Граница исследования: глава 16 «Rebirth» → глава 29 «The Last Day on Earth» (вход в Царство Снов) → глава 30 (прибытие) → главы 31–100 (Забытый берег, Древо Души, побег, одиночество в проклятом городе).
- [`docs/research/post_first_nightmare_dream_realm/00_source_registry.md`](docs/research/post_first_nightmare_dream_realm/00_source_registry.md) — реестр источников и статусы.
- [`docs/research/post_first_nightmare_dream_realm/01_canonical_timeline.md`](docs/research/post_first_nightmare_dream_realm/01_canonical_timeline.md) — хронология, границы и пробелы.

Для перехода к `VERIFIED` нужен ручной проход по главам 17–29 на WebNovel или WuxiaDreams.
