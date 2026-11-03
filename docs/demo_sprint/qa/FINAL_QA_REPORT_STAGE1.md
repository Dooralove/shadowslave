# FINAL QA REPORT — Demo Sprint / Release Gate

> **Исторический Stage 1 снимок.** Актуальная implementation spec DP-1.0:  
> `docs/demo_sprint/implementation/qa_release_implementation.md`.  
> Числа 624/7274 относятся к снимку 2026-11-02; текущий Stage 2 rerun — 636/7333.

Дата: 2026-11-02, 22:12 +03:00  
Автор: Chat 10 — Independent Lead QA / Release Engineer  
HEAD: `0335a5c346901af2146413b5a159b442d326d8de` (`feat: complete P2.5-P5 art, UI and optimization`)  
Ветка: `s3-park-art`  
Рабочее дерево: **грязное** (542 записи `git status --short`), HEAD не менялся; результаты привязаны к снимку 21:55–22:00.  
Baseline: `docs/demo_sprint/audits/qa_baseline.md`  
План: `docs/demo_sprint/qa/TEST_PLAN.md`  
Дефекты: `docs/demo_sprint/qa/QA_ISSUES.md`

## 0. Итоговый вердикт

**Демо-стержень технически проходит автоматизированно, но релизный gate НЕ ПРОЙДЕН.**

Что подтверждено:

- проект открывается и импортируется без ошибок;
- полный GUT **624/624, 7274 asserts, exit 0**;
- автоматизированный сквозной проход S00–S15 проходит 9/9 фаз, включая B01–B16, лагерь, тропу, святилище, оценку и финал;
- все 137 сцен и 336 ресурсов в `scenes/`, `resources/`, `assets/` загружаются без битых зависимостей;
- 7 квестов Лабиринта, бой, анимации, UI, сохранения и переходы покрыты зелёными тестами;
- ключевые кадры держат >60 FPS на RTX 3060 Laptop в uncapped-бенчмарке.

Что блокирует демонстрацию без сюрпризов:

1. **Нет экспортной сборки.** `export_presets.cfg` отсутствует, `--export-release` возвращает exit 1. Демо можно показать только из редактора.
2. **Нет непрерывного ручного прохождения с живым вводом.** Автоматизированный тур не заменяет человеческий проход.
3. **Лабиринт имеет подтверждённые разрывы проходимости:** дыра в коллизии Z07 ridge и блокер у Z10 base; Z12 high link вероятно отсутствует.
4. **Визуал не демо-уровня в ключевых местах:** POC-капсула Санни, серый blockout пост-Кошмарной цепочки, тёмные тропа/альков/пещера, незавершённый арт Лабиринта.

Итог: **FAIL / NOT RELEASE-READY**, но **PASS WITH LIMITATIONS** для внутреннего технического показа из редактора, если заранее объявить заглушки и не вести гостя в Лабиринт по низу/западу.

## 1. Статус по пунктам

| Пункт | Статус | Доказательство |
|---|---|---|
| Открытие проекта / импорт | **PASS** | `--import` exit 0, 0 `ERROR/Parse Error` |
| Запуск игры | **PASS** | main menu, campaign entry, окно 1920×1080; скриншоты |
| Полный демосценарий | **PASS WITH LIMITATIONS** | автоматизированный тур 9/9; живой ручной проход **NOT VERIFIED** |
| Все побочные квесты | **PASS WITH LIMITATIONS** | 7 реализованных квестов — тесты 9/9; SQ-FS-01…05 не реализованы |
| Ключевые механики | **PASS WITH LIMITATIONS** | бой, взаимодействия, цепь, лагерь, тропа, святилище, оценка, финал — тесты и тур |
| Анимации | **PASS WITH LIMITATIONS** | `test_sunny_animation` 16/16, `test_enemy_animation` 7/7, `test_carapace_enemy` 9/9; POC/скольжение не проверены вживую |
| UI | **PASS WITH LIMITATIONS** | меню, HUD, глоссарий, карта, медитация — тесты; 4K/клавиатурная навигация не проверены |
| Save/Load | **PASS WITH LIMITATIONS** | `test_save_system` 2/2; живой F5/F6 **NOT VERIFIED** |
| Проходимость S00–S15 | **PASS WITH LIMITATIONS** | `test_full_route` 3/3, `test_campaign_flow` 11/11, тур 9/9 |
| Проходимость Лабиринта | **FAIL** | route-walk: Z07 ridge hole, Z10 base block; Z12 link под вопросом |
| Производительность | **PASS WITH LIMITATIONS** | 152–165 FPS на ключевых кадрах; не бой/не все зоны |
| GUT | **PASS** | 81 скрипт, 624 теста, 624 pass, 7274 asserts, 228 с |
| Ошибки Godot | **PASS WITH LIMITATIONS** | 0 ошибок импорта; в GUT только ожидаемые negative-test errors |
| Скриншоты | **PASS** | 18 кадров тура + P3/P4/Лабиринт/пост-Кошмар |
| Экспорт / сборка | **FAIL / BLOCKED** | нет `export_presets.cfg`, exit 1, артефакта нет |
| Release gate | **FAIL** | см. §7 |

## 2. Фактические прогоны

### 2.1. Импорт

```powershell
godot --headless --path . --import
```

```text
IMPORT_EXIT=0
IMPORT_ERRORS=0
```

### 2.2. Полный GUT

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

```text
Scripts              81
Tests               624
Passing Tests       624
Failing Tests         0
Asserts            7274
Time              227.991s
GUT_EXIT=0
---- All tests passed! ----
```

Лог: `%TEMP%\opencode\gut_final4.log`; повторный контрольный прогон в 22:10 дал тот же результат 624/624 (лог `%TEMP%\opencode\gut_final5.log`).

Предыдущие прогоны были нестабильны из-за параллельных правок: 575/577, затем 619/621, затем 622/622. Финальный прогон 624/624 — единственный, который считается доказательством. Дерево после него больше не менялось в проверенных путях.

### 2.3. Автоматизированный сквозной тур S00–S15

Команда:

```powershell
godot --path . res://tools/audit/qa_campaign_tour.tscn -- --out=%TEMP%\opencode\qa_campaign_tour_final
```

Фактически:

```text
QA_TOUR_PASS prologue B01-B16
QA_TOUR_PASS march chain restrained
QA_TOUR_PASS S01 march
QA_TOUR_PASS camp tethered
QA_TOUR_PASS S02-S06 camp
QA_TOUR_PASS S07-S12 pilgrim
QA_TOUR_PASS S13 sanctuary
QA_TOUR_PASS S14 appraisal
QA_TOUR_PASS S15 finale
QA_TOUR_RESULT pass=9 fail=0
```

Это **автоматизированный** прогон: сцены реальные, но реплики/интеракции продвигаются кодом, а не клавиатурой. Он проверяет флаги, переходы и финальную карточку; он **не** является ручным прохождением. Тур инстанцирует обёртки напрямую после пролога; предупреждение `FirstNightmarePass: нет prologue_completed` — артефакт тура, а не игровой дефект (реальный гейт покрыт `test_campaign_flow`).

18 кадров: `%TEMP%\opencode\qa_campaign_tour_final\01…18_*.png`. Ключевые:

- `01_B01_park.png` — пролог, парк;
- `03_S01_march.png` — марш;
- `04_S02_camp_arrival.png` — лагерь;
- `08_S05_wagon.png` — повозка;
- `12_S07_road.png` — тропа;
- `16_S13_altar.png` — святилище;
- `18_S15_finale.png` — финальная карточка.

### 2.4. Целевые наборы (для отчёта)

| Набор | Результат |
|---|---:|
| `test_full_route` | 3/3, 220 asserts |
| `test_campaign_flow` | 11/11, 82 asserts |
| `test_labyrinth_first_fragment` | 13/13, 331 asserts |
| `test_labyrinth_quest_content` | 4/4, 41 assert |
| `test_quest_system` | 9/9, 63 asserts |
| `test_save_system` | 2/2, 14 asserts |
| `test_main_menu` | 7/7, 45 asserts |
| `test_game_settings` | 6/6, 41 assert |
| `test_rpg_menu_glossary` | 10/10, 43 asserts |
| `test_player_menu_system` | 7/7, 47 asserts |
| `test_map_system` | 22/22, 836 asserts |
| `test_sunny_animation` | 16/16, 75 asserts |
| `test_enemy_animation` | 7/7, 38 asserts |
| `test_carapace_enemy` | 9/9, 43 asserts |
| `test_demo_audio_vfx` | 8/8, 66 asserts |
| `test_post_nightmare_locations` | 8/8, 480 asserts |

## 3. Критические маршруты

### CR-01 — Полный Первый Кошмар: PASS WITH LIMITATIONS

- B01–B16: автоматизированный прогон 151 кадр, `mark_of_divinity` выставлен, руны открылись.
- S01–S15: 9/9 фаз, финальный флаг `first_nightmare_completed` выставлен только в S15.
- `R` и закрытые гейты покрыты `test_appraisal_and_finale` / `test_full_route`.
- **Ограничение:** непрерывного ручного ввода нет; визуал POC/тёмных сцен не принимается как финальный.

### CR-02 — Пост-Кошмарная цепочка: PASS WITH LIMITATIONS

- `test_post_nightmare_locations` 8/8: все сцены, порталы, spawn, карта, финальная карточка.
- Кнопка «После Кошмара» присутствует в меню, тест `test_main_menu` 7/7.
- **Ограничение:** это серый blockout; живого прохода нет. `black_sea_platform` тёмный, статуя читается плохо.

### CR-03 — Лабиринт, высокий маршрут: FAIL

`test_labyrinth_first_fragment` 13/13 проверяет телепорты/пол, но `labyrinth_route_walk.gd` при реальном движении даёт разрывы:

- Z07 ridge: в районе `(-10, 7, -52)` нет collision shape; игрок падает с гряды.
- Z10 base: `Col_Z09_ToHill_100` в `(-86.5, 0.36, 20)` перекрывает подход к `Z10_Climb`.
- Z12 high link: в районе `(-202, 5, -40)` нет collision shape; высокий переход под вопросом.
- Z14/Z15 FAIL — ложные срабатывания: Z14 перекрыт карапаксами (`BridgeCarapace1/2`), Z15 требует спуска лестницей, а не прямой.

### CR-04 — Лабиринт, низкий маршрут/прилив: PASS WITH LIMITATIONS

- `test_tide_cycle_opens_and_closes_gates` проходит; ворота закрываются/открываются, вода меняет высоту.
- `test_labyrinth_quest_content` 4/4 и `test_quest_system` 9/9 покрывают квестовый слой.
- **Ограничение:** живой проход низом/приливом не выполнялся; route-walk нестабилен.

### CR-05 — Смерть/восстановление: PASS WITH LIMITATIONS

- `test_fall_recovery`, `test_act4_stealth`, `test_combat_arena`, `test_save_system` покрывают чекпоинты/респавн.
- **Ограничение:** живая смерть в каждой зоне не проверялась.

### CR-06 — Save/Load: PASS WITH LIMITATIONS

- `test_save_system` 2/2: round-trip флагов, квестов, валюты, Memory, чекпоинта; повреждённый файл не роняет.
- **Ограничение:** F5/F6 в живом окне и загрузка в другой сцене — **NOT VERIFIED**.

## 4. Обнаруженные дефекты и риски

### Блокеры

1. **Экспорт.** `godot --headless --path . --export-release "Windows Desktop" ...` → exit 1:

   ```text
   ERROR: This project doesn't have an `export_presets.cfg` file at its root.
   ```

   Владелец: TD + Chat 10. Артефакта нет.

2. **Нет ручного прохождения.** Автоматизированный тур 9/9 и GUT 624/624 не заменяют живой сеанс. Владелец: Chat 10.

3. **Z07/Z10 Лабиринта.** Подтверждённые дыра/блокер коллизий; Z12 — вероятный. Владелец: Chat 03 + Chat 07. Файлы: `labyrinth_first_fragment.gd`, `.tscn`, `labyrinth_art.gd`.

### Заметные ограничения

4. **POC-капсула Санни** в прологе и на марше. Кампания использует `sunny_waking.tscn` (Rogue_Hooded), а не принятую реалистичную модель. Владелец: Chat 06.
5. **Пост-Кошмарная цепочка — blockout.** `police_precinct`, `academy_*`, `black_sea_platform`, `tide_descent` — серые/синие блоки; статуя тёмная. Владелец: Chat 03 + 07.
6. **Тёмные/пересвеченные места.** Тропа/альков/пещера почти чёрные в кадрах; святилище пересвечено. Владелец: Chat 07.
7. **Арт Лабиринта.** Красные скалы/плоские плоскости, костяной мост и шторм не финальные. Владелец: Chat 07.
8. **Меню.** Осталась подпись «Шаблон: графика, звук и управление…». Владелец: Chat 08.
9. **HUD Лабиринта.** «Противник 65/65» показывается первые 4 секунды как reveal, даже без боя. Решить, намеренно ли. Владелец: Chat 08.
10. **MCP `take_screenshot`** возвращает «Viewport returned no image»; QA использовал отдельные capture-скрипты. Владелец: TD/MCP.

### Что не является дефектом

- Z14 bridge/ramp FAIL в route-walk — карапаксы на мосту, а не дыра в геометрии.
- Z15 west FAIL — инструмент идёт напрямую, а маршрут требует спуска лестницей.
- Два старых падения `test_post_nightmare_locations` — исправлены обновлением теста под `StatueKnightLOD`.
- Transient-падения GUT 575/577 и 619/621 — следствие параллельных правок; финальный прогон 624/624 зелёный.

## 5. Визуальные доказательства

| Что | Путь | Наблюдение |
|---|---|---|
| Главное меню | `%TEMP%\opencode\qa_baseline_shots2\main_menu.png` | кнопки «Играть», «Настройки», «Кредиты», «После Кошмара»; видна подпись «Шаблон…» |
| Пролог B01 | `qa_prologue_shots/B01_park.png` | парк, POC-капсула, NPC, HUD |
| Пролог B16 | `qa_prologue_shots/B16_runes.png` | руны, статус, Mark of Divinity |
| Марш | `qa_campaign_tour_final/03_S01_march.png` | цепь, караван, placeholder-люди |
| Лагерь | `qa_campaign_tour_final/04_S02_camp_arrival.png` | читаемые повозка/костёр/люди, но greybox-качество |
| Лабиринт, вход | `qa_labyrinth_shots/entrance.png` | HUD, цель, прилив, красный коралл |
| Лабиринт, мост | `qa_labyrinth_shots/bridge.png` | костяной мост и карапакс |
| Лабиринт, шторм | `qa_labyrinth_shots/storm.png` | шторм читается, геометрия блочная |
| Пост-Кошмар, статуя | `qa_postnm_shots/black_sea_platform_Shots_Overview.png` | тёмная статуя, парящие звёзды |
| Пост-Кошмар, финал | `qa_postnm_shots/post_nightmare_finale.png` | финальная карточка, возврат в меню |
| Combat arena | `qa_combat_shots/combat_arena.png` | HUD, карапакс, POC-Санни |

Все пути — `%TEMP%`, не коммитятся. Команды для пересоздания — в `TEST_PLAN.md`.

## 6. Производительность

| Кадр | FPS (uncapped) | Draw calls | Primitives | VRAM |
|---|---:|---:|---:|---:|
| Парк 1920×1080 | 161.98 | 252.9 | 1.57M | 1071 MB |
| Пролог: игрок + UI | 151.97 | 718.0 | 1.86M | 1081 MB |
| Лабиринт, вход | 142.42 | 1299.0 | 3.84M | 796 MB |
| Лабиринт, мост | 164.89 | 529.0 | 1.15M | 796 MB |

Вывод: **PASS WITH LIMITATIONS**. Бюджет draw calls <1500 соблюдён; primitives Лабиринта на входе 3.84M выше 2.5–3.5M. Нет vsync, термо-соака, боя и всех 18 зон.

## 7. Release gate

| # | Критерий | Статус |
|---:|---|---|
| 1 | Импорт exit 0 | PASS |
| 2 | Полный GUT 0 fail | PASS (624/624) |
| 3 | Главное меню | PASS |
| 4 | Кампания / проход | PASS WITH LIMITATIONS (автотур, не ручной) |
| 5 | Непрерывный ручной проход | **NOT VERIFIED** |
| 6 | `R` / сброс | PASS (тесты) |
| 7 | Консоль без новых ошибок | PASS WITH LIMITATIONS (warnings) |
| 8 | Пост-Кошмарные сцены | PASS WITH LIMITATIONS (blockout) |
| 9 | Лабиринт | **FAIL** (Z07/Z10, Z12 под вопросом) |
| 10 | Аудио | **NOT VERIFIED** (тесты есть, на слух нет) |
| 11 | Экспорт | **FAIL / BLOCKED** |
| 12 | Скриншоты | PASS |

**Release gate: FAIL.**

## 8. Что должен сделать разработчик перед показом

1. Закрыть экспорт: добавить `export_presets.cfg`, проверить шаблоны, собрать `.exe`, запустить вне редактора.
2. Пройти CR-01 вручную одним сеансом и записать результат.
3. Починить Z07 ridge hole и Z10 base block; проверить Z12 high link. После — повторить `labyrinth_route_walk.gd`.
4. Решить, что показывать: POC-Санни и серый blockout пост-Кошмара нужно либо заменить, либо честно назвать заглушками.
5. Убрать «Шаблон…» из меню и решить судьбу HUD-reveal врага.
6. Проверить звук на слух и живой F5/F6.
7. Повторить полный GUT на замороженном дереве перед показом.

## 9. Ограничения отчёта

- Отчёт не утверждает, что ручной проход выполнен; он **не выполнен**.
- Все числа привязаны к снимку 21:55–22:00; дерево грязное (542 записи), другие чаты могут изменить его после.
- Скриншоты — временные артефакты в `%TEMP%`; они не входят в Git.
- Аудио, геймпад, 4K/ultrawide, минимальное железо, свежий клон и термический соак **NOT VERIFIED**.

## 10. Ссылки

- `docs/demo_sprint/audits/qa_baseline.md`
- `docs/demo_sprint/qa/TEST_PLAN.md`
- `docs/demo_sprint/qa/QA_ISSUES.md`
- `docs/demo_sprint/design/00_DEMO_SCOPE_AND_CONTRACT.md`
- `docs/demo_sprint/implementation/P0_BOARD.md`
- логи: `%TEMP%\opencode\gut_final4.log`, `import_final4.log`, `qa_campaign_tour_final.log`, `qa_export_final.log`
