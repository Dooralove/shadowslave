# QA BASELINE — независимый аудит

Дата: 2026-11-02, 20:20–21:05 +03:00  
Автор: Chat 10 — Independent Lead QA / Release Engineer  
HEAD: `0335a5c346901af2146413b5a159b442d326d8de` (`feat: complete P2.5-P5 art, UI and optimization`)  
Ветка: `s3-park-art`  
Рабочее дерево: **грязное и живое**; на момент снимка 508 записей `git status --short`, рабочее дерево менялось параллельными чатами во время аудита.

> Этот документ — снимок, а не приговор финальному состоянию. Любой PASS/FAIL действителен только для зафиксированного состояния дерева. Перед финальным отчётом проверки повторяются.

## 0. Сводка

1. **Проект импортируется** после пересборки class-кэша: `godot --headless --path . --import` → exit 0. Первый запуск после параллельных правок дал ложные parse errors (`StaminaComponent`), которые исчезли после повторного импорта.
2. **Полный GUT: исторический baseline был красным, финальный прогон — зелёный.** На первом прогоне (20:20): 74 скрипта, 577 тестов, 575 pass, 2 fail, 6857/6869 asserts. Оба падения — `test_post_nightmare_locations`, старый контракт `black_sea_platform`. К 20:58 тест обновлён под `StatueKnightLOD`; финальный прогон 21:55–22:00: **81 скрипт, 624 теста, 624 pass, 7274 asserts, exit 0** (см. §14).
3. **Целевые наборы кампании зелёные:** `test_full_route` 3/3, `test_campaign_flow` 11/11, `test_save_system` 2/2, `test_quest_system` 8/8, `test_main_menu` 7/7, `test_game_settings` 6/6. Лабиринт: `test_labyrinth_first_fragment` 13/13 в изолированном прогоне, но в полном GUT один walk-тест упал (см. §3.3).
4. **Запуск игры работает**, но MCP `take_screenshot` в этом окружении возвращает «Viewport returned no image». Скриншоты получены отдельным оконным процессом через `tools/audit/qa_capture.gd`; это доказательство рендера, а не ручного прохождения.
5. **Полного непрерывного ручного прохождения нет.** Пролог B01–B16 проверяется headless-тестом `test_campaign_flow`; маршрут после пролога — `test_full_route`. Это не заменяет живой проход.
6. **Экспортной сборки нет.** `export_presets.cfg` отсутствует; `--export-release` завершается ошибкой «This project doesn't have an export_presets.cfg file». Шаблоны экспорта тоже не подтверждены.
7. **Сохранения появились** (`SaveSystem`, F5/F6, `user://campaign_save.bin`), unit round-trip зелёный; живой F5/F6 в кампании не проверялся.
8. **Производительность на ключевых кадрах выше 60 FPS** на RTX 3060 Laptop: парк 162 FPS / 253 draw calls / 1.07 GB VRAM; пролог с игроком и UI 152 FPS / 718 draw calls / 1.08 GB; Лабиринт-вход 142 FPS / 1299 draw calls / 3.84M primitives / 796 MB. Это uncapped-бенчмарк, не гарантия стабильных 60 FPS в бою и на всех зонах.
9. **Главные риски демо:** красный полный GUT, отсутствие экспорта, отсутствие ручного прохода, нестабильность Лабиринта на стыках маршрута, зелёная POC-модель Санни, незавершённый арт Лабиринта и `project.godot`, который менялся параллельно.
10. **Вердикт baseline: NOT READY.** Демо-стержень логически проходит headless, но release gate не выполнен.

## 1. Метод и границы

Прочитано:

- `README.md`, `AGENTS.md`, `docs/DECISIONS.md` (выборочно, хвост), `docs/AI_HANDOFF_AFTER_S3_2.md`;
- `docs/design/first_nightmare_scene_matrix.md`, `first_nightmare_route_verification.md`, `level_brief_labyrinth_first_fragment.md`;
- `docs/demo_sprint/README.md`, `BASELINE.md`, `EXPECTED_REPORTS.md`, `OWNERSHIP.md`, `design/00_DEMO_SCOPE_AND_CONTRACT.md`, `design/01_CONTENT_MATRIX.md`, `design/side_quests.md`, `implementation/ACTIVE_CLAIMS.md`, `implementation/P0_BOARD.md`;
- ключевые скрипты: `save_system.gd`, `combat_hud.gd`, `nightmare_run_state.gd`, `labyrinth_quest_director.gd`, `labyrinth_first_fragment.gd`, `labyrinth_route_walk.gd`, `test_full_route.gd`, `test_campaign_flow.gd`, `test_labyrinth_first_fragment.gd`, `test_quest_system.gd`, `test_save_system.gd`.

Запущено:

- `godot --version`, `godot --headless --path . --import` (дважды);
- полный GUT и 6 целевых наборов;
- `godot --headless --path . -s tools/audit/qa_resource_audit.gd` (новый read-only инструмент QA);
- оконные capture-прогоны `qa_capture.gd`, `p3_capture.gd`, `p4_capture.tscn`, `location_capture.gd` для Лабиринта;
- `p5_benchmark.gd` и `p5_campaign_probe.tscn`;
- `--export-release` (ожидаемый отказ).

Не проверялось в этой сессии:

- непрерывный ручной проход от меню до финальной карточки;
- прохождение всех 7 квестов Лабиринта живым игроком;
- звук на слух, геймпад, 4K/ultrawide, второе железо;
- свежий клон с нуля;
- экспортированный билд (его нет).

## 2. Структура проекта (факт)

| Показатель | Значение |
|---|---:|
| `.tscn` в `scenes/` | 126 |
| `.gd` в `scripts/` | 221 |
| `.tres` в `resources/` | 237 |
| тестовых `.gd` в `tests/` | 81 |
| записей `git status --short` | 508 |
| `assets/` | ~819 MB, 2277 файлов (по baseline TD) |
| `.godot/` cache | ~1.1 GB, не в Git |

Рост относительно `BASELINE.md` (20:10): сцены 113 → 126, скрипты 195 → 221, тесты 74 → 81. Это подтверждает, что дерево живое; сравнивать результаты между прогонами можно только по времени и HEAD.

## 3. Тесты

### 3.1. Полный GUT (первый прогон)

Команда:

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Результат:

```text
Scripts              74
Tests               577
Passing Tests       575
Failing Tests         2
Asserts           6857/6869
Time              265.354s
EXIT=1
```

Оба падения — в `tests/test_post_nightmare_locations.gd`:

1. `test_each_location_scene_builds_greybox` — у `black_sea_platform` нет модулей `NeckPlatform`, `BrokenCollar`, `ShoulderWest`, `ShoulderEast`, `Chest`, `ChestStars`, `Sword`.
2. `test_black_sea_platform_matches_canonical_statue_neck` — `has_module()` false, `get_module()` null для `NeckPlatform` и `ChestStars`.

Причина: сцена переведена на `StatueKnightLOD`, primitive-модули старого greybox больше не строятся, а тест проверял старый контракт `GreyboxLocation.has_module()`. Это расхождение теста и реализации, а не падение runtime.

**Обновление 20:58:** тест переписан на новый контракт (проверка `StatueKnightColossus/LOD0..2` и `NeckPlatformCollision`). Повторный прогон `test_post_nightmare_locations` — **8/8, 480 asserts, exit 0**. Пункт закрыт; historical baseline остаётся красным.

### 3.2. Целевые наборы

| Набор | Результат | Assert | Exit |
|---|---:|---:|---:|
| `test_full_route.gd` | 3/3 | 220 | 0 |
| `test_campaign_flow.gd` | 11/11 | 82 | 0 |
| `test_save_system.gd` | 2/2 | 14 | 0 |
| `test_quest_system.gd` | 8/8 | 60 | 0 |
| `test_main_menu.gd` | 7/7 | 45 | 0 |
| `test_game_settings.gd` | 6/6 | 41 | 0 |
| `test_labyrinth_first_fragment.gd` (изолированно, 20:31) | 13/13 | 331 | 0 |

### 3.3. Лабиринт: нестабильность

Первый изолированный прогон `test_labyrinth_first_fragment` — 13/13. В полном GUT тот же тест дал падение:

```text
test_walk_down_entry_stairs_into_fork
[Failed]: [10.3532104492188] expected to be < than [5.0]: игрок прошёл от карниза к развилке
at line 245
```

Игрок остановился на x≈10.35 вместо x<5. Причина не установлена: возможен новый коллайдер/декор на развилке после арт-правок или загрязнение физики полного прогона. Это было **S1** на момент снимка.

**Обновление 22:00:** в финальном полном GUT тест снова прошёл; весь набор 624/624. Пункт закрыт как transient, но требует наблюдения: тест проходимости зависит от порядка/состояния, а не только от сцены.

### 3.4. Маршрутный аудит Лабиринта

`tools/audit/labyrinth_route_walk.gd` (headless, скорость 10 м/с) на снимке 20:44 и повторно 21:20:

- OK: 24+ сегмента, включая вход/спуск, развилку, Z07 ramp, Z08, Z10 climb, Z11-high, Z12-high, Z13 north/central, Z15 base/climb, Z16 ridge.
- FAIL (9–13 в разных прогонах): `z07_ridge`, `z07_west`, `z10_base`, `z10_top`, `z10_west`, `z12_high_link`, `z14_bridge_ramp`, `z14_bridge`, `z15_west`; в позднем прогоне также `z16_ridge`, `z17_high` и хвостовой `z03_z04`.
- На `z10_west` игрок оказался в `(38, 7.2, 0)` — точке `Spawns/Start`. Это похоже на падение/возврат к стартовому чекпоинту, а не на успешный спуск.
- На `z14_bridge` игрок остановился на `(-565.6, 6.0, 0)` при цели `(-650, 6.2, 0)`.

Дополнительная проверка коллизий (`qa_probe_collision.gd`):

- **Z14 bridge/ramp — не баг геометрии.** В точке остановки стоят `BridgeCarapace1/2` (CharacterBody3D, layer 4). Маршрут перекрыт врагами, а не мостом. Route-walk должен отключать encounters или считать бой частью сегмента.
- **Z10 base — реальный блокер.** У входа на лестницу Z10 стоит коллизия `Generated/Collision/Z09_BlindTunnel/Col_Z09_ToHill_100` в `(-86.5, 0.36, 20)`, перекрывающая подход к `Z10_Climb`.
- **Z07 ridge — дыра в поле.** В районе `(-10, 7, -52)` не найдено ни одного collision shape; игрок падает с гряды. Это реальный разрыв коллизии.
- **Z12 high link** — в районе `(-202, 5, -40)` не найдено collision shape; высокий переход Z12→Z13 north может отсутствовать.
- **Z10 top** — прямую линию блокирует основание `CampPillar`; возможно, обходится, но требует проверки.
- **Z10 west / Z15 west** — прямые сегменты route-walk могут быть неверны: спуск идёт лестницами, а не по прямой. Это ограничение инструмента, не доказательство бага.

Вывод: как минимум 2 реальных дефекта проходимости (Z07 ridge hole, Z10 base block) и 1 вероятный (Z12 high link). Z14/Z15 — ложные срабатывания инструмента. Нужна проверка владельцем 03 в живой игре и обновление route-walk точек.

## 4. Запуск, runtime и скриншоты

| Проверка | Результат | Доказательство |
|---|---|---|
| Godot MCP editor | connected, 0.6.1 | `get_godot_status` |
| MCP runtime helper | connected | `get_runtime_status` |
| `take_screenshot` MCP | **FAIL** «Viewport returned no image» | два вызова, main menu и campaign |
| Главное меню, оконный запуск | PASS (визуально) | `%TEMP%\opencode\qa_baseline_shots2\main_menu.png` |
| `campaign_entry.tscn`, оконный запуск | PASS (сцена стартует, пролог виден) | `%TEMP%\opencode\qa_baseline_shots\campaign_entry.png` |
| Кнопка «После Кошмара» | присутствует в меню, тест `test_main_menu` 7/7 | скриншот меню |
| Полный ручной проход | **NOT VERIFIED** | — |

Примечание: MCP runtime был подключён к другому процессу/сцене (`LabyrinthFirstFragment`), пока редактор числился простаивающим. Это делает MCP `run_scene`/`take_screenshot` ненадёжным доказательством в общем рабочем дереве. Для QA использован отдельный оконный процесс и `tools/audit/qa_capture.gd`.

### 4.1. Визуальные spot-check'и

| Сцена | Файл | Наблюдение |
|---|---|---|
| Главное меню | `qa_baseline_shots2/main_menu.png` | читаемо; кнопки «Играть», «Настройки», «Кредиты», «После Кошмара»; внизу осталась подпись «Шаблон: графика, звук и управление…» |
| Campaign entry / парк | `qa_baseline_shots/campaign_entry.png` | пролог стартует; Санни — зелёная POC-капсула, не финальная модель; цель и подсказка видны |
| Марш каравана | `qa_p3_shots/road_player.png` | читаемая дорога, цепь, караван; модели людей — placeholder |
| Стоянка | `qa_p3_shots/site_wide.png` | читаются повозка, костёр, люди, лошадь; лошадь/персонажи схематичны |
| Тропа | `qa_p3_shots/trail_player.png` | читается; NPC стоят неестественно, но сцена не чёрная |
| Святилище | `qa_p3_shots/sanctuary_nave.png` | читается, но пол/обломки пересвечены, композиция требует полировки |
| Лабиринт, вход | `qa_labyrinth_shots/entrance.png` | HUD, цель, прилив; коралл читается как красные скалы, не финальный арт |
| Лабиринт, мост | `qa_labyrinth_shots/bridge.png` | костяной мост и карапакс видны; геометрия и полотно моста требуют проверки проходимости |
| Лабиринт, шторм | `qa_labyrinth_shots/storm.png` | шторм читается, но дорога/скалы выглядят как отдельные блоки |

Все пути — временные, `%TEMP%`; это не committed evidence.

## 5. Сохранения

`SaveSystem` — autoload, `user://campaign_save.bin`, версия 1, F5/F6, интеграция с чекпоинтами, квестами и BeatDirector.

- `test_save_system` — 2/2, 14 asserts, exit 0.
- Round-trip покрывает флаги, квесты, валюту, Memory, чекпоинт.
- Повреждённый файл возвращает пустой результат, `load_game` возвращает false.
- **NOT VERIFIED:** живое F5/F6 в кампании, загрузка в другой сцене, поведение при смерти во время сохранения.

## 6. Производительность

| Кадр | FPS (uncapped) | Draw calls | Primitives | VRAM |
|---|---:|---:|---:|---:|
| Парк, 1920×1080, фикс. камера | 161.98 | 252.9 | 1.57M | 1071.1 MB |
| Пролог: игрок + UI | 151.97 | 718.0 | 1.86M | 1081.0 MB |
| Лабиринт, вход | 142.42 | 1299.0 | 3.84M | 796.3 MB |
| Лабиринт, мост | 164.89 | 529.0 | 1.15M | 796.3 MB |

Вывод: на RTX 3060 Laptop ключевые кадры выше 60 FPS. Бюджет draw calls <1500 соблюдён; primitives в Лабиринте на входе 3.84M выше заявленного бюджета 2.5–3.5M. Это **PASS WITH LIMITATIONS**: нет vsync/термо-соака, нет боя и всех 18 зон.

## 7. Экспорт и сборка

```powershell
godot --headless --path . --export-release "Windows Desktop" <temp>\ShadowSlave.exe
```

Результат: **exit 1**:

```text
ERROR: This project doesn't have an `export_presets.cfg` file at its root.
Create an export preset from the "Project > Export" dialog and try again.
```

- `export_presets.cfg` отсутствует.
- Каталог `build/`, `dist/`, `release/`, `export/` отсутствует.
- Артефакта сборки нет.
- Шаблоны экспорта не проверялись, потому что экспорт не дошёл до них.

Вердикт: **BLOCKED**. Для демонстрации на другом ПК это S0, если планируется запуск не из редактора.

## 8. Целостность ресурсов

Новый read-only инструмент `tools/audit/qa_resource_audit.gd` загрузил:

```text
checked=469 scenes=136 resources=333 failures=0
```

То есть все `.tscn` и `.tres` в `scenes/`, `resources/`, `assets/` загружаются без битых `ext_resource`. Это не проверяет отсутствующие node path, логику и физику — только загрузку ресурсов.

## 9. Расхождения «документ ↔ факт»

| Документ | Утверждение | Факт |
|---|---|---|
| `README.md:17` | 35 scripts / 255 tests / 2473 asserts | на baseline 74 скрипта / 577 тестов / 6857 asserts; README устарел |
| `docs/design/first_nightmare_route_verification.md` | 35/255/2473 | устарело |
| `docs/demo_sprint/BASELINE.md` | `[rendering]` удалён | на 20:50 блок восстановлен; проверять перед финалом |
| `docs/demo_sprint/BASELINE.md` | Лабиринт — greybox без NPC/врагов/квестов | к 20:50 есть 7 квестов, NPC, враги, арт-слой, звук/VFX |
| `docs/demo_sprint/design/side_quests.md` | SQ-FS-01…05 реализуются | в `resources/quests/` только 7 старых квестов, SQ-FS-01…05 отсутствуют |
| `docs/demo_sprint/design/00_DEMO_SCOPE_AND_CONTRACT.md` | milestone — пост-Кошмарная цепочка | меню теперь имеет кнопку «После Кошмара», но ручной проход цепочки не выполнен |
| `README.md:102` | полный ручной проход не выполнялся | всё ещё верно |

## 10. P0 / P1 / P2

### P0 — блокирует демо или release gate

1. **Экспорт невозможен:** нет `export_presets.cfg` и, вероятно, шаблонов. Владелец: TD + Chat 10. Без этого «показать демо» можно только из редактора.
2. **Нет полного ручного прохода** CR-01. Владелец: Chat 10; это главный невыполненный критерий приёмки.
3. **Проходимость Лабиринта:** 2 подтверждённых дефекта route-walk (Z07 ridge hole, Z10 base block) + вероятный Z12 high link. Z14/Z15 — ложные срабатывания инструмента. Владелец: Chat 03 + Chat 07; нужно подтвердить в живой игре.

### P1 — заметно, но не блокирует P0-маршрут

5. **POC-модель Санни** (зелёная капсула) в прологе/кампании; для демо это выглядит как заглушка. Владелец: Chat 06.
6. **Арт Лабиринта** — красные скалы/плоские плоскости, костяной мост и шторм не финальные. Владелец: Chat 07.
7. **HUD Лабиринта:** панель «Противник 65/65» показывается первые 4 секунды как reveal, даже без боя. Решить, оставлять ли. Владелец: Chat 08.
8. **Меню:** подпись «Шаблон: графика, звук и управление…» осталась после P4. Владелец: Chat 08.
9. **Тёмные/пересвеченные места:** святилище, альков, пещера — визуальная читаемость. Владелец: Chat 07.
10. **`take_screenshot` MCP** не работает в этом окружении; QA использует отдельные capture-скрипты. Владелец: TD / MCP.

### P2 — после демо

11. SQ-FS-01…05 не реализованы, дизайн есть.
12. Пост-Кошмарная цепочка не имеет полного контента (NPC/диалоги/цели) и ручного прохода.
13. Нет геймпада/переназначения, 4K, чистой установки, термического соака.
14. Документация README/route verification устарела по числам тестов.

## 11. Владение и точные задачи

| ID | Владелец | Файлы | Задача |
|---|---|---|---|
| QA-B-01 | Chat 03 + Chat 10 | `scenes/locations/post_nightmare/black_sea_platform.tscn`, `tests/test_post_nightmare_locations.gd` | **Закрыто 20:58:** тест обновлён на `StatueKnightLOD` + `NeckPlatformCollision`, 8/8. |
| QA-B-02 | TD | `export_presets.cfg`, `project.godot` | Добавить Windows Desktop preset, проверить шаблоны, собрать `build/ShadowSlave.exe`, запустить артефакт. |
| QA-B-03 | Chat 03 + 07 | `labyrinth_first_fragment.gd`, `.tscn`, `labyrinth_art.gd` | Проверить 8 FAIL route-walk; исправить стыки Z07/Z10/Z12/Z14; повторить `labyrinth_route_walk.gd` и `test_labyrinth_first_fragment`. |
| QA-B-04 | Chat 03 | `tests/test_labyrinth_first_fragment.gd` / сцена | Устранить зависимость `test_walk_down_entry_stairs_into_fork` от порядка полного GUT; повторить 3 раза. |
| QA-B-05 | Chat 06 | `assets/characters/sunny_realistic_poc/*`, `scenes/characters/sunny.tscn` | Для демо заменить POC-капсулу на принятую модель или явно объявить заглушку в отчёте. |
| QA-B-06 | Chat 08 | `scripts/ui/main_menu/main_menu.gd`, `scenes/ui/main_menu/main_menu.tscn` | Убрать «Шаблон…» или заменить на честную подпись демо. |
| QA-B-07 | Chat 10 | `docs/demo_sprint/qa/*`, `tests/*` | Полный GUT, CR-01, save/load F5/F6, финальный отчёт. |

## 12. NOT TESTED

- Непрерывный ручной проход `main_menu → campaign_entry → … → finale`, с вводом с клавиатуры/мыши.
- Все 7 квестов Лабиринта в живой игре (unit-тесты не равны прохождению).
- SQ-FS-01…05 — не реализованы.
- Живой F5/F6 и загрузка в другой сцене.
- Звук на слух, геймпад, 4K/ultrawide, минимальное железо.
- Экспортированный билд.
- Свежий клон с нуля.
- Термический соак и стабильность 60 FPS в бою/на всех зонах.

## 13. Критерий повторного аудита

Baseline можно считать снятым с красного на зелёный, когда одновременно выполнено:

1. `--import` exit 0 без parse errors.
2. Полный GUT: 0 необъяснённых падений.
3. CR-01 пройден и записан (скриншоты + флаги).
4. `export_presets.cfg` есть, релизный артефакт запускается.
5. Все P0 из §10 закрыты или явно приняты TD с обходом.
6. Финальный отчёт обновлён по фактическому прогону, а не по этому снимку.

## 14. Обновление после baseline (21:18–22:12)

1. **Импорт:** `godot --headless --path . --import` → **exit 0**, 0 строк `ERROR:/SCRIPT ERROR/Parse Error`.
2. **Полный GUT:** **81 скрипт, 624 теста, 624 pass, 0 fail, 7274 asserts, 228.0 с, exit 0.** Это финальный результат на момент отчёта; он привязан к снимку дерева 21:55.
3. **`test_post_nightmare_locations`:** 8/8, 480 asserts — 2 baseline-падения исправлены обновлением теста под `StatueKnightLOD`.
4. **`test_labyrinth_first_fragment`:** 13/13, 331 assert — transient-падение в полном GUT не воспроизвелось.
5. **Prologue tour:** `tools/audit/qa_prologue_tour.gd` прошёл B01→B16 за 151 кадр в fast mode; сняты `B01_park`, `B03_doze`, `B15_caravan`, `B16_runes`. Это автоматизированный графический прогон, не ручной.
6. **Route-walk:** 9 FAIL, но после проверки коллизий Z14/Z15 — ложные срабатывания (враги/неверная прямая), Z07 ridge и Z10 base — подтверждённые дефекты. См. §3.4.
7. **`project.godot`:** `[rendering]` восстановлен; P5-настройки на месте.
8. **Экспорт:** по-прежнему **BLOCKED**, `export_presets.cfg` отсутствует.
9. **Ручной проход:** по-прежнему **NOT VERIFIED**.

Итог: технический baseline стал значительно лучше, но release gate всё ещё не пройден из-за экспорта, ручного прохода и двух дефектов проходимости Лабиринта.
