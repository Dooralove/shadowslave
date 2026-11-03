# P0 BOARD — Post-Nightmare Milestone (M1)

Обновлено: 2026-11-02 20:35 +03:00  
Цель: играбельный проход `main_menu → police_precinct → … → labyrinth_first_fragment → финал`.  
Статус: **open / in progress / done / blocked**. Владельцы — чаты 01–10; TD интегрирует.

## 0. Статус на 2026-11-02 21:20

**Done:** M1-01 (кнопка «После Кошмара»), M1-02 (кнопка на финале), M1-03 (пресет состояния), M1-04 (цели P05–B03 + HUD), M1-05 (восстановлен `[rendering]`), M1-06 (тест `test_post_nightmare_locations` 15/15), M1-07…M1-15 (базовый контент всех сцен), M1-22 (GameplayHud), M1-24 (музыка/эмбиент по сценам), M1-26 (целевые тесты), M1-27 (полный GUT 632/632).

**Open:** M1-16…M1-21 (финальные модели, Hyper3D), M1-23 (журнал/карта Лабиринта), M1-25 (VFX прилива/дождя), M1-28…M1-29 (ручной проход/чек-лист).

**M2 done (базовый):** полицейский участок, подъезд, ворота, кампус, Sleeper Center, Чёрное море, спуск, финальная карточка. NPC/диалоги — плейсхолдеры.

**Проверка:** `qa/M1_RUN_2026-11-02.md`.

## 1. Интеграция и вход

| ID | Задача | Владелец | Файлы | Статус |
|---|---|---|---|---|
| M1-01 | Кнопка «После Кошмара» в главном меню | 08 + TD | `scenes/ui/main_menu/main_menu.tscn`, `scripts/ui/main_menu/main_menu.gd` | open |
| M1-02 | Переход из финала N26 в `police_precinct` (или явная кнопка) | 01 + 04 | `scripts/campaign/finale.gd`, `scenes/campaign/finale_arrival.tscn` | open |
| M1-03 | Сброс/пресет состояния для пост-Кошмара | 04 | `scripts/campaign/nightmare_run_state.gd` | open |
| M1-04 | Цели по сценам (P05–P09, B01–B03) | 01 + 04 | `resources/campaign/beats/*`, `CampaignGuide`, `ObjectiveLine` | open |
| M1-05 | Восстановить `[rendering]` в `project.godot` | TD | `project.godot` | open |
| M1-06 | Починить/согласовать `test_post_nightmare_locations` | 03 + 10 | `tests/test_post_nightmare_locations.gd`, `black_sea_platform.tscn` | open |

## 2. Сцены и контент

| ID | Сцена | Что нужно | Владелец | Статус |
|---|---|---|---|---|
| M1-07 | `police_precinct` | хранилище, койка, стул, душ, выход | 03 + 07 | open |
| M1-08 | `academy_approach` | машина Джет, КПП, вид академии | 03 + 07 | open |
| M1-09 | `academy_gate` | ворота, мост, стена, турели | 03 + 07 | open |
| M1-10 | `academy_campus` | кампус, общежитие, переход | 03 + 07 | open |
| M1-11 | `academy_sleeper_center` | индукция, капсула, сон | 01 + 03 + 08 | open |
| M1-12 | `black_sea_platform` | статуя, звёзды, меч, спуск | 03 + 07 | open |
| M1-13 | `tide_descent` | вода, уступы, вход в Лабиринт | 03 + 07 | open |
| M1-14 | `labyrinth_first_fragment` | вход, цель, финальная точка | 03 + 04 + 07 | open |
| M1-15 | `coral_labyrinth` | решить: заменить/связать/оставить | 03 | open |

## 3. Модели и анимации

| ID | Модель | Владелец | Статус |
|---|---|---|---|
| M1-16 | Sunny (POC на milestone) | 06 | open |
| M1-17 | Police / academy staff | 06 | open |
| M1-18 | Jet | 06 | open |
| M1-19 | Julius | 06 | open |
| M1-20 | Carapace v2 (UV/текстуры) | 05 + 06 | open |
| M1-21 | Statue LOD/материалы | 07 | open |

## 4. UI / Audio / VFX

| ID | Задача | Владелец | Статус |
|---|---|---|---|
| M1-22 | HUD целей и взаимодействий в пост-Кошмаре | 08 | open |
| M1-23 | Quest journal / карта для Лабиринта | 08 + 04 | open |
| M1-24 | Музыка/эмбиент участка, академии, моря, Лабиринта | 09 | open |
| M1-25 | VFX прилива, дождя, кораллов | 09 + 07 | open |

## 5. QA

| ID | Задача | Владелец | Статус |
|---|---|---|---|
| M1-26 | Целевые тесты пост-Кошмара | 10 | open |
| M1-27 | Полный GUT | 10 | open |
| M1-28 | Ручной проход M1 | 10 | open |
| M1-29 | Чек-лист и отчёт | 10 | open |

## 6. Правила

- Задача считается done только с фактическим тестом/скриншотом/записью.
- Не менять чужие файлы; общие — через TD.
- Если задача блокирует другую — писать в `ACTIVE_CLAIMS.md`.
- P0 не расширять без TD.
