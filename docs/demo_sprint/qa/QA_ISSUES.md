# QA ISSUES — живые дефекты и задачи

Дата: 2026-11-02, 21:15 +03:00  
Автор: Chat 10 — Independent Lead QA / Release Engineer  
Правило: **QA не правит чужие системы молча.** Каждый пункт содержит владельца, файлы, шаги и ожидаемое поведение.

## 0. Сводка

| ID | Severity | Статус | Владелец | Кратко |
|---|---|---|---|---|
| QA-01 | S0 | OPEN | TD + 10 | Нет `export_presets.cfg`; релизная сборка невозможна |
| QA-02 | S0 | OPEN | 10 | Нет непрерывного ручного прохождения CR-01 |
| QA-03 | S1 | OPEN | 03 + 07 | Route-walk: Z07 ridge hole, Z10 base block; Z12 link под вопросом |
| QA-04 | S1 | RESOLVED | 03 | `test_labyrinth_first_fragment` прошёл в полном GUT 624/624 |
| QA-05 | S1 | OPEN | 06 | В кампании видна POC-капсула Санни вместо модели |
| QA-06 | S1 | OPEN | 03 + 07 | Пост-Кошмарная цепочка — серый blockout, не демо-качество |
| QA-07 | S2 | OPEN | 08 | В меню осталась подпись «Шаблон: графика, звук…» |
| QA-08 | S2 | OPEN | TD | MCP `take_screenshot` не работает; нужен workaround для доказательств |
| QA-09 | S2 | OPEN | 03 + 07 | HUD Лабиринта показывает «Противник 65/65» вне боя первые 4 с |
| QA-10 | S1 | NOT VERIFIED | 09 | Звук не прослушан; captions/шины проверены только тестами |

## QA-01 — Нет экспортного пресета и сборки

**Severity:** S0 (релизный gate).  
**Владелец:** Technical Director; исполнитель — Chat 10 (release).  
**Файлы:** `export_presets.cfg`, `project.godot`, `build/`.

Шаги:

```powershell
godot --headless --path . --export-release "Windows Desktop" "$env:TEMP\ShadowSlave.exe"
```

Фактически:

```text
ERROR: This project doesn't have an `export_presets.cfg` file at its root.
```

Ожидаемо: пресет Windows Desktop, успешный экспорт, `.exe`/`.pck` запускаются вне редактора.

Ограничение: добавление `export_presets.cfg` — общий файл, нужен TD. QA не создаёт его самовольно.

## QA-02 — Нет полного ручного прохождения

**Severity:** S0 (главный критерий демо).  
**Владелец:** Chat 10.  
**Файлы:** `docs/demo_sprint/qa/FINAL_QA_REPORT.md`, evidence.

Шаги: `main_menu` → «Играть» → B01–B16 → S01–S15 → финальная карточка → `R`.

Фактически: пройдены headless-тесты `test_campaign_flow` и `test_full_route`, сняты статические кадры сцен. Непрерывного прохождения с живым вводом нет.

Ожидаемо: один непрерывный сеанс, записанные флаги/скриншоты/время, отсутствие soft-lock.

## QA-03 — Route-walk Лабиринта: подтверждённые и ложные FAIL

**Severity:** S1 (stretch/tech demo; может стать S0, если Лабиринт — часть демо-маршрута).  
**Владелец:** Chat 03 (геометрия/маршрут) + Chat 07 (арт/коллизии).  
**Файлы:** `scripts/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.gd`, `labyrinth_greybox.gd`, `labyrinth_art.gd`, `tools/audit/labyrinth_route_walk.gd`.

Команда:

```powershell
godot --headless --path . -s tools/audit/labyrinth_route_walk.gd -- \
  --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn
```

Фактически (20:44 и повтор 21:20):

```text
FAIL 07 z07_ridge        pos=(13.35, 0.00, -10.65) target=(-25, 7, -55)
FAIL 08 z07_west         pos=(-43.65, 7.00, -49.43) target=(-50, 7, -48)
FAIL 12 z10_base         pos=(-85, 1.00, 16.15) target=(-85, 1.2, 20)
FAIL 14 z10_top          pos=(-105, 18.00, -6.74) target=(-105, 18.2, -10)
FAIL 15 z10_west         pos=(38, 7.2, 0) target=(-125, 6.2, -20)
FAIL 18 z12_high_link    pos=(-200, 5.0, -21.65) target=(-204, 5.2, -90)
FAIL 22 z14_bridge_ramp  pos=(-548, 4.98, 0) target=(-550, 6.2, 0)
FAIL 23 z14_bridge       pos=(-565.6, 6.0, 0) target=(-650, 6.2, 0)
FAIL 29 z15_west         pos=(-707.45, 18.0, -20) target=(-750, 2.2, -20)
```

Дополнительная проверка `qa_probe_collision.gd`:

- **Z14 bridge/ramp — ложное срабатывание.** В точке остановки стоят `BridgeCarapace1/2` (CharacterBody3D, layer 4). Мост перекрыт врагами, а не коллизией геометрии; в живом прохождении это бой.
- **Z10 base — подтверждённый блокер.** У входа на лестницу Z10 стоит `Generated/Collision/Z09_BlindTunnel/Col_Z09_ToHill_100` в `(-86.5, 0.36, 20)`, перекрывающая подход к `Z10_Climb`.
- **Z07 ridge — подтверждённая дыра.** В районе `(-10, 7, -52)` не найдено ни одного collision shape; игрок падает с гряды.
- **Z12 high link — вероятный разрыв.** В районе `(-202, 5, -40)` не найдено collision shape; высокий переход Z12→Z13 north может отсутствовать.
- **Z10 top** — прямую линию блокирует основание `CampPillar`; возможно, обходится.
- **Z10 west / Z15 west** — прямые сегменты route-walk могут быть неверны: спуск идёт лестницами, а не по прямой; это ограничение инструмента, не доказательство бага.

Ожидаемо: Z07 ridge и Z10 base исправлены; Z12 high link либо подтверждён, либо route-walk обновлён. Z14/Z15 — не считать багами без живой проверки.

## QA-04 — Нестабильный тест проходимости входа — RESOLVED

**Severity:** S1 (был).  
**Владелец:** Chat 03.  
**Файлы:** `tests/test_labyrinth_first_fragment.gd`, `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`.

Изолированно: 13/13. В одном полном GUT был transient-сбой `test_walk_down_entry_stairs_into_fork` (x≈10.35 вместо x<5). В финальном полном GUT 22:00 тест прошёл; весь набор 624/624. Пункт закрыт, но тест остаётся чувствительным к порядку/состоянию — при повторных сбоях вернуть в работу.

## QA-05 — POC-модель Санни в кампании

**Severity:** S1 (визуальная готовность демо).  
**Владелец:** Chat 06.  
**Файлы:** `assets/characters/sunny_realistic_poc/*`, `scenes/characters/sunny.tscn`, `scripts/slice/mannequin.gd`.

Факт: в `campaign_entry` и на марше Санни выглядит как зелёная капсула с остроконечным капюшоном. Это заявленный POC, но для демонстрации выглядит как заглушка.

Ожидаемо: принятая модель или явная пометка в демо-сценарии, что модель — placeholder. Не выдавать POC за финал.

## QA-06 — Пост-Кошмарная цепочка — blockout

**Severity:** S1 (если цепочка входит в демо).  
**Владелец:** Chat 03 + 07.  
**Файлы:** `scenes/locations/post_nightmare/*.tscn`.

Факт: `police_precinct`, `academy_approach`, `academy_gate`, `academy_campus`, `academy_sleeper_center`, `black_sea_platform`, `tide_descent` — серые/синие блоки, без финального арта. `black_sea_platform` — тёмная статуя с парящими звёздами, читаемость низкая. Кадры: `%TEMP%\opencode\qa_postnm_shots\`.

Ожидаемо: либо честно назвать tech demo/blockout, либо довести ключевые кадры (статуя, ворота, капсулы) до демо-уровня.

## QA-07 — Подпись «Шаблон…» в главном меню

**Severity:** S2.  
**Владелец:** Chat 08.  
**Файлы:** `scenes/ui/main_menu/main_menu.tscn`, `scripts/ui/main_menu/main_menu.gd`.

Факт: под кнопками остаётся «Шаблон: графика, звук и управление. Изменения сохраняются». P4 заявлял удаление prototype-подписей.

Ожидаемо: убрать или заменить на «Демо-сборка» без слова «шаблон».

## QA-08 — MCP screenshot не работает

**Severity:** S2 (QA-инфраструктура).  
**Владелец:** TD / MCP.  
**Файлы:** `addons/godot_mcp/*`, `tools/audit/qa_capture.gd`.

Факт: `take_screenshot` возвращает «Viewport returned no image» при запущенной сцене; MCP runtime может быть подключён к другому процессу. Workaround: отдельный оконный процесс + `qa_capture.gd`/`p3_capture.gd`/`location_capture.gd`.

Ожидаемо: либо исправить MCP-скриншоты, либо зафиксировать workaround в QA-доках и не использовать MCP как единственное доказательство.

## QA-09 — HUD Лабиринта показывает врага вне боя

**Severity:** S2.  
**Владелец:** Chat 08.  
**Файлы:** `scripts/ui/combat_hud.gd`.

Факт: при входе в Лабиринт панель «Противник 65/65» видна первые 4 секунды (`first_reveal_seconds`) даже без боя. Это может быть намеренный reveal, но выглядит как ошибка: враг далеко, игрок не в бою.

Ожидаемо: решить, оставлять ли reveal; если да — показывать только при реальном обнаружении/уроне.

## QA-10 — звук не прослушан

**Severity:** S1 (NOT VERIFIED).  
**Владелец:** Chat 09.  
**Файлы:** `assets/audio/**`, `resources/audio/**`, `scripts/audio/**`.

Факт: `test_demo_audio_vfx` 8/8, `test_audio_system`/`test_audio_playback` есть; на слух музыка/эмбиент/SFX не проверялись. Нельзя ставить PASS за «звук готов».

Ожидаемо: живой проход с включённым звуком, проверка музыки, эмбиента, SFX, VO, captions, отсутствия клиппинга.

## Шаблон для нового дефекта

```markdown
## QA-XX — <краткое название>

**Severity:** S0/S1/S2/S3  
**Владелец:** Chat XX  
**Файлы:** ...
**Шаги:** ...
**Фактически:** ...
**Ожидаемо:** ...
**Доказательство:** ...
```
