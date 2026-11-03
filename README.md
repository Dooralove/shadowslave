# ShadowSlave

3D-игра на Godot 4.7.2 (GDScript). Текущее состояние: **сквозной graybox-маршрут Первого Кошмара S00–S15** — от пролога «Nightmare Begins» до финальной карточки, плюс отдельный playable-сегмент Академии (Academy Grounds + Sleeper Center, 24 задания), M1/tech-demo Лабиринта и система кат-сцен. Боевой прототип Milestone 4 и sandbox-арена сохранены отдельно; они не входят в канонический маршрут.

## Что готово

- Стартовое меню входа (`scenes/ui/main_menu/main_menu.tscn`): «Играть» запускает кампанию, «После Кошмара», «Технический фрагмент» и «Академия · ALPHA» открывают отдельные демо-сегменты, «Настройки» — графика, звук, управление и переназначение клавиш/геймпада с сохранением в `user://settings.cfg`.
- Единое игровое меню (`scenes/ui/rpg_menu_prototype.tscn`): глоссарий с бестиарием, рюкзак, карта мира, задания, персонаж, умения, памяти и медитация в одном окне. Открывается по `C`/`I`, карта по `M`; глоссарий и карта используют живые данные кампании.
- Пролог B01–B16: скамейка, участок, Code Black, изолятор, брифинг, видение, пробуждение в цепи и руны.
- S01: марш каравана в цепях и прибытие к стоянке.
- S02–S06: стоянка, нападение, личинка, ключ, освобождение, повозка, падение Тирана, последействие, ветеран, Silver Bell, ночь и рассвет.
- S07–S12: разрушенная дорога, восхождение, альков, смерть Шифти, разоблачение Учёного, пещера, ранение, смерть Героя и подход к храму.
- S13: алтарь, семь подношений, появление Тирана, смерть от теней и завершение испытания.
- S14: звёздная оценка, `glorious`, True Name `Lost from Light`, Aspect `Shadow Slave`, Shadow Bond и First Seal.
- S15: пробуждение, Flaw без имени, финальная карточка и `R` → сброс в начало.

Полный GUT: **92 scripts / 749 tests / 8 039 asserts, all passed**. Headless-маршрут после пролога проверен 18 шагами; `test_full_route` — 3/3. Пролог B01–B16 в этом тесте не проигрывается; полный ручной графический проход — **NOT TESTED**. См. `docs/design/first_nightmare_route_verification.md` и `docs/production/implemented_systems_audit_2026-11-03.md`.

## Запуск

Нужен Godot 4.7.2. Основная сцена проекта — стартовое меню `res://scenes/ui/main_menu/main_menu.tscn`. «Играть» открывает канонический маршрут через `campaign_entry.tscn`; «Академия · ALPHA» открывает `academy_grounds_playable.tscn`; «Настройки» сохраняются в `user://settings.cfg` и применяются сразу.

Демо-арена `scenes/main/main.tscn` сохранена и запускается напрямую:

```powershell
godot --path . res://scenes/ui/main_menu/main_menu.tscn
godot --path . res://scenes/campaign/campaign_entry.tscn
godot --path . res://scenes/main/main.tscn
```

В редакторе: `main_menu.tscn` запускается по F5 (основная сцена), кампания — по F6 из `campaign_entry.tscn`. Запуск `campaign_entry.tscn` сбрасывает `NightmareRunState` и начинает с пролога.

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
| Пауза / закрыть меню / освободить мышь | Escape | `release_mouse` |
| Захватить мышь | ЛКМ в окне | `capture_mouse` |
| Удар | ЛКМ | `attack` |
| Взаимодействие | E | `interact` |
| Следующая реплика | E / Space / Enter | `advance_dialogue` |
| Статус Заклятия | Tab | `open_status` |
| Карта мира в едином меню | M | `open_map` |
| Единое меню: персонаж | C | `open_character` |
| Единое меню: рюкзак | I | `open_inventory` |
| Закрыть карту или меню | Escape | `ui_cancel`, `release_mouse` |
| Перезапуск кампании | R | `restart` |
| Быстрое сохранение | F5 | `quick_save` (создаётся SaveSystem) |
| Быстрая загрузка | F9 | `quick_load` (создаётся SaveSystem) |
| Пропуск кат-сцены | Backspace / Back (геймпад) | `cutscene_skip` (создаётся CutsceneDirector) |

Клавиши можно переназначить в «Настройках → Управление» или в паузе. Для геймпада по умолчанию: левый стик — движение, A — прыжок/следующая реплика, X — удар, Y — взаимодействие, LB — бег, Start — пауза.

## Структура

- `scenes/ui/main_menu/` — стартовое меню и экран настроек.
- `scenes/ui/rpg_menu/` и `scripts/ui/rpg_menu/` — единое игровое меню, глоссарий, бестиарий, встроенная карта и медитация. Аудит — `docs/design/game_menu_audit.md`.
- `scenes/campaign/` — обёртки маршрута и `campaign_entry.tscn`.
- `scenes/locations/academy/` и `scenes/locations/academy_playable/` — арт-локации Академии и их playable-wrapper'ы.
- `scripts/cutscene/` и `resources/cutscene/` — CutsceneDirector, UI, триггеры и M1-катсцены.
- `scripts/settings/input_bindings.gd` и `scripts/ui/input_binding_row.gd` — переназначение клавиш/геймпада.
- `scenes/slice/` — пролог и `caravan_road.tscn`.
- `scenes/locations/caravan_site/` — лагерь, нападение, личинка, повозка, последействие.
- `scenes/locations/pilgrim_path/` — восхождение, альков, пещера, Герой, храм.
- `scenes/locations/shadow_sanctuary/` — алтарь и ритуал Тирана.
- `resources/dialogue/` и `resources/spell/` — типизированные `.tres`-ресурсы диалогов и сообщений.
- `scripts/campaign/nightmare_run_state.gd` — autoload состояния прохождения.
- `scripts/quests/` и `resources/quests/` — Quest Framework и семь заданий демофрагмента Лабиринта.
- `scripts/systems/save_system.gd` — быстрый слот `user://campaign_save.bin` (F5/F9) и автосейв на чекпоинтах.
- `scripts/settings/game_settings.gd` — настройки графики/звука и `user://settings.cfg`.
- `tests/` — GUT-тесты, включая `test_full_route.gd`, `test_main_menu.gd`, `test_game_settings.gd`, `test_quest_system.gd`, `test_labyrinth_quest_content.gd` и `test_save_system.gd`.

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
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_main_menu.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_game_settings.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_rpg_menu_glossary.gd -gexit
```

## Ограничения

- Полный ручной графический проход от `campaign_entry` до финальной карточки не выполнялся: **NOT TESTED**.
- Переход «Играть» → `campaign_entry` проверен тестом и наличием сцены, но не ручным кликом в живом окне: **NOT TESTED**.
- Настройки графики, звука и доступности работают и сохраняются в `user://settings.cfg`; переназначение клавиш и геймпада реализовано, но живая проверка в бою — **NOT TESTED**. Аудио-каркас содержит 345 файлов (290 WAV + 55 OGG), но слуховой тест и замена SAPI-плейсхолдеров — **NOT TESTED**.
- Ручной проход Academy-сегмента, M1 и tech demo мышью/геймпадом — **NOT TESTED**; headless-пробы Academy проходят 24/24 квестов.
- Альков и пещера очень тёмные; тени-руки в святилище читаются как чёрные стержни; отдельный кадр стадии `TYRANT` не сохранён.
- `mark_of_divinity` — флаг-атрибут Санни, выставляется на B16 и отображается в статусе; в `ITEM_IDS` и инвентарь не входит. Страж храма B3 не реализован.
- Один полный прогон GUT дал transient-сбой в `test_mountain_king`; немедленный повтор прошёл. Тест нужно проверить на изоляцию.
- `test_labyrinth_first_fragment` — **14/14, 341 assert**. Вложенное скрытие `Z02_Crab*` исправлено 2026-11-03 и закрыто регрессионным тестом (runtime-аудит: 0 мешей `Z02_Crab*`); непрерывный проход 1,5 км и FPS — **NOT TESTED**.
- Изолятор: коридор и пост наблюдения пересобраны kit-оверлеем из модулей пролога; CSG-прокси сохранены как коллизия, `containment_probe` — `failures=0`. Катсцена B10–B12 в живом окне — **NOT TESTED**.
- Квестовый прогресс хранится в `NightmareRunState`. Equipment/loot alpha (16 equipment `.tres`, 40 loot `.tres`, `EquipmentComponent`/`InventoryComponent`) существует и покрыт тестами, но не подключён к кампании и не сохраняется в `SaveSystem`; полноценный инвентарь, слоты Memories, аптечка и торговля остаются демо-заглушками/следующим этапом.

## Документация

- `docs/story/cutscene_registry/README.md` — аудит канона и реестр кат-сцен: 5 частей, 14 глав, 70 кинематографических событий.
- `docs/story/first_nightmare_canonical_timeline.md` — канонические блоки 01–20.
- `docs/design/first_nightmare_scene_matrix.md` — матрица сцен, флагов и статусов.
- `docs/design/first_nightmare_route_verification.md` — 18 шагов, тесты и NOT TESTED.
- `docs/design/first_nightmare_restoration_spec.md` — спецификация и критерии приёмки.
- `docs/design/first_nightmare_gap_matrix.md` — исторический аудит и актуальная сводка.
- `docs/design/first_nightmare_prototype_flow.md` — описание сквозного прототипа.
- `docs/AI_HANDOFF_AFTER_S3_2.md` — handoff, backlog и известные проблемы.
- `docs/DECISIONS.md` — архитектурные решения.
- `docs/demo_sprint/audits/ui_ux.md` — аудит HUD, меню, карты, журнала и диалогов.
- `docs/demo_sprint/design/ui_ux_design.md` — дизайн UI/UX демонстрационного прохождения.

## Исследование канона: после Первого Кошмара

Статус: **главы 17–99 прочитаны по зеркалу WuxiaDreams (часть фрагментами), глава 100 — в начале**. Сверка с оригиналом на WebNovel не выполнена (там 403), поэтому статус текста — `TEXT` (по зеркалу), а не `VERIFIED`. Главы 1–16 по тексту не проверены.

- Граница исследования: глава 16 «Rebirth» → глава 29 «The Last Day on Earth» (вход в Царство Снов) → глава 30 (прибытие) → главы 31–100 (Забытый берег, Древо Души, побег, одиночество в проклятом городе).
- [`docs/research/post_first_nightmare_dream_realm/00_source_registry.md`](docs/research/post_first_nightmare_dream_realm/00_source_registry.md) — реестр источников и статусы.
- [`docs/research/post_first_nightmare_dream_realm/01_canonical_timeline.md`](docs/research/post_first_nightmare_dream_realm/01_canonical_timeline.md) — хронология, границы и пробелы.

Для перехода к `VERIFIED` нужен ручной проход по главам 17–29 на WebNovel или WuxiaDreams.
