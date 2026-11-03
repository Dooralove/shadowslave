# BUG REGISTRY — Stage 3 Baseline

Дата: 2026-11-03  
Проверяющий: Chat 10 — Independent Lead QA / Release Engineer  
Branch: `demo/integration`  
HEAD: `ab8fe304f5b4c9915d1d5579851f1402d2cf8b18` (`demo/integration`, Stage 4; working tree dirty)  
Правило: **Critical → High → Medium → Low.** QA не исправляет чужие файлы; фиксирует владельца и доказательство.

---

## 0. Integration resolution @ `ab8fe30` (authoritative)

Проверено на `demo/integration` HEAD `ab8fe30`:

- `--import` exit 0; full GUT **86 scripts / 683 tests / 683 pass / 7676 asserts**.
- `route_reachability` — **18/18 зон, 51/51 POI**.
- `labyrinth_route_walk` — **51/51 сегментов**.
- `test_post_nightmare_locations` 15/15; `test_labyrinth_first_fragment` 13/13; `test_ui_demo` 10/10; `test_quest_extensions` 12/12; `test_side_quests` 8/8.

**RESOLVED at `ab8fe30`:** BUG-003, BUG-004, BUG-005, BUG-006, BUG-007, BUG-008, BUG-009, BUG-010, BUG-018, BUG-019, BUG-020, BUG-021, BUG-022, BUG-023, BUG-024.

**RESOLVED QA-fix после `ab8fe30`:** BUG-013 (меню), BUG-015 (route-walk false positives), BUG-016 (`qa_script_audit`).

**STILL OPEN:** BUG-001 (no export/build), BUG-002 (no manual pass), BUG-011 (draw calls), BUG-012/BUG-032 (Black Sea readability), BUG-014 (HUD reveal), BUG-017 (MCPRuntime release).

**RESOLVED QA-fix:** BUG-013 (menu text), BUG-015 (route-walk false positives), BUG-016 (`qa_script_audit`).

**STAGE 4 (2026-11-03):** добавлены BUG-025…BUG-033; главный итог — SQ-02/SQ-03/SQ-04/SQ-05 и tech demo Z11–Z18 не проходятся в обычном сценарии. Полный отчёт — раздел «STAGE 4 — COMPLETE DEMO PLAYTEST» ниже.

> Status-поля в исторических записях ниже могут оставаться `OPEN`; этот раздел — актуальный итог. Закрытие BUG-003…024 подтверждено интеграционными прогонами, а не только branch-local.

---

## BUG-001 — Нет export preset и Windows build

- **Severity:** Critical
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `export_presets.cfg`, `build/ShadowSlave.exe`
- **Шаги:**
  1. `godot --headless --path . --export-release "Windows Desktop" <temp>\ShadowSlave.exe`
- **Ожидаемый результат:** preset найден; export exit 0; артефакт `ShadowSlave.exe` запускается.
- **Фактический результат Stage 5:** локальный `export_presets.cfg` создан (gitignored), шаблоны `4.7.2.stable` установлены локально; `build/ShadowSlave.exe` (109 MB) и `ShadowSlave.pck` (962 MB) собраны, `--headless --quit-after 5` — exit 0. Для этого дерева нужен `script_export_mode=0`: binary-token export давал parse errors autoload и bark-JSON.
- **Доказательство:** `%TEMP%\opencode\stage5_export7.log`, `stage5_build_boot5.log`; `build/ShadowSlave.exe`
- **Ответственный:** A00 (clean release-only rebuild), A10 (проверка)
- **Status:** **MITIGATED LOCALLY / PASS WITH LIMITATIONS** — preset/templates machine-local, PCK includes tools/tests/MCPRuntime; clean-commit rebuild required.

---

## BUG-002 — Нет непрерывного ручного прохода M1

- **Severity:** High
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `docs/demo_sprint/qa/`, M1 chain P05→Z10
- **Шаги:**
  1. Запустить build или editor.
  2. Пройти `main_menu → police_precinct → academy_approach → academy_gate → academy_campus → academy_sleeper_center → black_sea_platform → tide_descent → labyrinth Z01–Z10`.
  3. Записать время, флаги, soft-lock, скриншоты.
- **Ожидаемый результат:** один непрерывный проход 18–25 минут с записанным результатом.
- **Фактический результат:** проход не выполнялся; есть только headless-тесты и отдельные captures. **NOT VERIFIED.**
- **Доказательство:** `docs/demo_sprint/qa/BASELINE_RESULTS.md` §10
- **Ответственный:** A10 (исполнитель), A00 (приёмка)
- **Status:** OPEN

---

## BUG-003 — Z04 MudHollow запечатан (G1)

- **Severity:** High
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`, `scripts/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.gd`
- **Шаги:**
  1. `godot --headless --path . -s tools/audit/route_reachability.gd -- --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`
  2. Проверить `z03_z04` в route-walk.
- **Ожидаемый результат:** Z04 достижим из Z03; `z03_z04` PASS.
- **Фактический результат:** `Z04 MudHollow FAIL`, nearest cell `(-30,7,-57)`, `dxz=15.0`, `dy=9.8`; `z03_z04` FAIL; route result 16/18.
- **Доказательство:** `%TEMP%\opencode\stage3_route_reach.log`, `stage3_route_walk.log`
- **Ответственный:** A03
- **Status:** OPEN

---

## BUG-004 — Z11 low route: западная лестница утоплена (G2)

- **Severity:** High
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`, `labyrinth_first_fragment.gd`
- **Шаги:**
  1. Запустить `labyrinth_route_walk.gd`.
  2. Проверить сегмент `z11_low`.
- **Ожидаемый результат:** `Z11 low → Z12` проходим без прыжка.
- **Фактический результат:** `FAIL 47 z11_low pos=(-149.65,-1.0,0)` target `(-153,0.2,0)`, `frames=576`; лестница не выводит на пол Z12.
- **Доказательство:** `%TEMP%\opencode\stage3_route_walk.log`
- **Ответственный:** A03
- **Status:** OPEN

---

## BUG-005 — Z08→Z09: устье перекрыто (G3)

- **Severity:** High
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`, `labyrinth_first_fragment.gd`
- **Шаги:**
  1. `labyrinth_route_walk.gd`, сегмент `z08_z09`.
- **Ожидаемый результат:** игрок входит в туннель Z09 напрямую.
- **Фактический результат:** `FAIL 46 z08_z09 pos=(-57.64,0.0,18.15)`, target `(-70,0.2,20)`, `frames=451`; вход читается как стена.
- **Доказательство:** `%TEMP%\opencode\stage3_route_walk.log`
- **Ответственный:** A03
- **Status:** OPEN

---

## BUG-006 — Z05→Z06: 2-м разрыв (G4)

- **Severity:** High
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`, `labyrinth_first_fragment.gd`
- **Шаги:**
  1. `labyrinth_route_walk.gd`, сегмент `z05_z06`.
- **Ожидаемый результат:** проход в Z06 без прыжка; путь к Тео/SQ-01 доступен.
- **Фактический результат:** `FAIL 44 z05_z06 pos=(-1279.68,8.0,1.27)`, target `(-50,6.2,40)`, `frames=442`; движение не достигает Z06. **Важно:** позиция похожа на сбой телепорта/чекпоинта в route-walk после Z18, поэтому это не чистое доказательство геометрии; G4 известен из level audit, нужен targeted repro.
- **Доказательство:** `%TEMP%\opencode\stage3_route_walk.log`
- **Ответственный:** A03 (+A10 — уточнить harness)
- **Status:** OPEN / REPRO INCONCLUSIVE

---

## BUG-007 — Z03→Z05: тесный V-угол без площадки (G5)

- **Severity:** High
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`, `labyrinth_first_fragment.gd`
- **Шаги:**
  1. `labyrinth_route_walk.gd`, сегмент `z03_z05`.
- **Ожидаемый результат:** площадка 6×6 и проход без падения.
- **Фактический результат:** `FAIL 43 z03_z05 pos=(-1281.94,8.0,0.62)`, target `(-30,0.2,21)`, `frames=471`. **Важно:** позиция указывает на сбой телепорта в harness после Z18; G5 известен из level audit, нужен targeted repro.
- **Доказательство:** `%TEMP%\opencode\stage3_route_walk.log`
- **Ответственный:** A03 (+A10 — уточнить harness)
- **Status:** OPEN / REPRO INCONCLUSIVE

---

## BUG-008 — Z07 ridge: дыра в коллизии

- **Severity:** High
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`, `labyrinth_first_fragment.gd`
- **Шаги:**
  1. `godot --headless --path . -s tools/audit/qa_probe_collision.gd -- --at=-10,7,-52 --radius=10`
  2. `labyrinth_route_walk.gd`, сегменты `z07_ridge` / `z07_west`.
- **Ожидаемый результат:** пол гряды имеет коллизию; игрок идёт от рампа к Z08.
- **Фактический результат:** `COLLISION_SUMMARY found=0`; игрок падает на `(13.35,0.0,-10.65)`; `z07_ridge`/`z07_west` FAIL.
- **Доказательство:** `%TEMP%\opencode\stage3_probe_z07.log`, `stage3_route_walk.log`
- **Ответственный:** A03 (+A07 только visual)
- **Status:** OPEN

---

## BUG-009 — Z10 base: коллайдер перекрывает вход на лестницу

- **Severity:** High
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `labyrinth_first_fragment.tscn`, `labyrinth_first_fragment.gd`
- **Шаги:**
  1. `qa_probe_collision.gd --at=-85,1,18 --radius=8`
  2. `labyrinth_route_walk.gd`, сегмент `z10_base`.
- **Ожидаемый результат:** игрок подходит к `Z10_Climb` и поднимается на холм.
- **Фактический результат:** `Col_Z09_ToHill_100` в `(-86.5,0.36,20)` и стены Z09 перекрывают подход; `z10_base` останавливается на `(-85,1.0,16.15)`.
- **Доказательство:** `%TEMP%\opencode\stage3_probe_z10base.log`, `stage3_route_walk.log`
- **Ответственный:** A03
- **Status:** OPEN

---

## BUG-010 — Z12 high link: высокий переход не подтверждён

- **Severity:** High
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `labyrinth_first_fragment.tscn`, `labyrinth_first_fragment.gd`
- **Шаги:**
  1. `qa_probe_collision.gd --at=-202,5,-40 --radius=12`
  2. `labyrinth_route_walk.gd`, сегмент `z12_high_link`.
- **Ожидаемый результат:** высокий маршрут Z12→Z13 North непрерывен.
- **Фактический результат:** `found=0`; `z12_high_link` останавливается на `(-200.09,5.0,-21.65)` при цели `(-204,5.2,-90)`.
- **Доказательство:** `%TEMP%\opencode\stage3_probe_z12link.log`, `stage3_route_walk.log`
- **Ответственный:** A03
- **Status:** OPEN

---

## BUG-011 — Labyrinth draw calls 1593 > 1500

- **Severity:** Medium
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`
- **Шаги:**
  1. `godot --path . -s tools/audit/labyrinth_perf.gd -- --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn --w=1920 --h=1080`
- **Ожидаемый результат:** draw calls <1500, VRAM <4 GB (D-26).
- **Фактический результат:** на baseline `fps=93.1`, `draw_calls=1593`; на integration `ab8fe30` — `fps=99.7`, `draw_calls=1677.0`, `primitives=4,598,448`, `video_mem=786.5 MB`. Бюджет `<1500` всё ещё превышен.
- **Доказательство:** `%TEMP%\opencode\stage3_perf_lab.log`, `stage3_intfinal_perf.log`
- **Ответственный:** A07 (+A03)
- **Status:** OPEN

---

## BUG-012 — Black Sea platform: низкая читаемость статуи

- **Severity:** Medium
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `scenes/locations/post_nightmare/black_sea_platform.tscn`
- **Шаги:**
  1. Запустить сцену.
  2. Камера `Shots/Overview`.
- **Ожидаемый результат:** статуя-колосс, семь звёзд и меч читаются без дополнительного света.
- **Фактический результат:** фон почти чёрный; статуя видна silhouetted, звёзды/меч читаются слабо. Кадр: `stage3_shots/black_sea_platform_Shots_Overview.png`.
- **Доказательство:** `%TEMP%\opencode\stage3_shots\black_sea_platform_Shots_Overview.png`
- **Ответственный:** A07 (+A03)
- **Status:** OPEN

---

## BUG-013 — Main menu: осталась подпись «Шаблон…»

- **Severity:** Low
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `scenes/ui/main_menu/main_menu.tscn`
- **Шаги:**
  1. Запустить `main_menu.tscn`.
  2. Посмотреть под кнопками.
- **Ожидаемый результат:** нет prototype-подписи; demo label.
- **Фактический результат:** было «Шаблон: графика, звук и управление. Изменения сохраняются».
- **Исправление:** текст заменён на «Демо-сборка: графика, звук и управление. Изменения сохраняются.»; `test_main_menu` 7/7.
- **Доказательство:** `scenes/ui/main_menu/main_menu.tscn:180`, `%TEMP%\opencode\qa_menu_fix.log`
- **Ответственный:** A08/A10
- **Status:** **RESOLVED (QA fix, integration working tree)**; закоммитить в integration

---

## BUG-014 — HUD Лабиринта показывает врага вне боя первые 4 с

- **Severity:** Low
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `scripts/ui/combat_hud.gd`, `labyrinth_first_fragment.tscn`
- **Шаги:**
  1. Запустить Лабиринт.
  2. Посмотреть HUD сразу после входа.
- **Ожидаемый результат:** панель врага скрыта, пока нет боя/урона.
- **Фактический результат:** «Противник 65/65» виден первые `first_reveal_seconds=4.0`; это может быть намеренный reveal, требует решения A08.
- **Доказательство:** `%TEMP%\opencode\stage3_shots\labyrinth_first_fragment_Shots_Entrance.png`
- **Ответственный:** A08
- **Status:** OPEN / design review

---

## BUG-015 — `labyrinth_route_walk` даёт ложные FAIL

- **Severity:** Low
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `tools/audit/labyrinth_route_walk.gd`
- **Шаги:**
  1. Запустить route-walk.
  2. Сравнить `z14_bridge` с `combat_labyrinth_probe`.
- **Ожидаемый результат:** tool не путает врагов/respawn с геометрией.
- **Фактический результат:** на baseline `z14_bridge`/`z14_bridge_ramp` упирались в `BridgeCarapace1/2`; `z10_west`/`z15_west` могли сбрасывать/идти напрямую.
- **Исправление/проверка:** на integration `ab8fe30` `labyrinth_route_walk` — **51/51**, ложные FAIL не воспроизводятся.
- **Доказательство:** `%TEMP%\opencode\stage3_intfinal_walk.log`
- **Ответственный:** A10/A03
- **Status:** **RESOLVED at `ab8fe30`**

---

## BUG-016 — `qa_script_audit.gd` не работает

- **Severity:** Low
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `tools/audit/qa_script_audit.gd`
- **Шаги:**
  1. `godot --headless --path . -s tools/audit/qa_script_audit.gd`
- **Ожидаемый результат:** проверяет все `.gd` без ошибок инструмента.
- **Фактический результат:** было `Script ERROR: Cannot call method 'load' on a null value` и незавершённый процесс.
- **Исправление:** `qa_script_audit.gd` переведён на `load()` + `can_instantiate()`, исключены `tools/**`; проверка 355 game/tests скриптов — 0 failures.
- **Доказательство:** `%TEMP%\opencode\qa_script_audit_fixed2.log`
- **Ответственный:** A10
- **Status:** **RESOLVED (QA fix)**; закоммитить в integration

---

## BUG-017 — `MCPRuntime` остаётся autoload для релиза

- **Severity:** Medium
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `project.godot`
- **Шаги:**
  1. Открыть `project.godot`.
  2. Проверить `[autoload]`.
- **Ожидаемый результат:** в release build `MCPRuntime` отсутствует; dev-сборка может его содержать.
- **Фактический результат:** `MCPRuntime="*res://addons/godot_mcp/runtime/mcp_runtime.gd"` активен; build-конфигурация исключения не зафиксирована.
- **Доказательство:** `project.godot`, строка autoload; `stage3_export.log` (build не создан)
- **Ответственный:** A00
- **Status:** OPEN

---

## BUG-018 — Z15 Refuge/checkpoint не находится route_reachability

- **Severity:** Medium
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `labyrinth_first_fragment.tscn`, `Spawns/Refuge`, `Markers/RefugeCheckpoint`
- **Шаги:**
  1. `route_reachability.gd --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`
  2. Проверить Z15/Spawns/Refuge.
- **Ожидаемый результат:** верхняя полка +18 достижима; spawn/checkpoint на полу.
- **Фактический результат:** `Z15 HighRefuge FAIL`; nearest floor `(-706.5,2,-28.5)`, `dy=-16.2`; `Spawns/Refuge`, `RefugeReturn`, `RefugeCheckpoint`, `TideSafePoints/S15_Refuge`, `Triggers/Refuge` FAIL. Возможно ложное отрицание сетки, но checkpoint требует проверки.
- **Доказательство:** `%TEMP%\opencode\stage3_route_reach.log`
- **Ответственный:** A03 (+A10 — проверить grid)
- **Status:** OPEN / VERIFY

---

## BUG-019 — Z16/Z17 route-сегменты не классифицированы

- **Severity:** Medium
- **Commit:** `ee973250e45e8d0b661de243badce095621ffbdf`
- **Файл/сцена:** `labyrinth_first_fragment.tscn`, `labyrinth_first_fragment.gd`
- **Шаги:**
  1. `labyrinth_route_walk.gd`.
  2. Проверить `z16_ridge`, `z17_high`, `z16_low`.
- **Ожидаемый результат:** сегменты Z16/Z17 проходятся или провал объяснён чекпоинтом/боем.
- **Фактический результат:** `z16_ridge` FAIL на `(-700.27,18.88,-19.85)`; `z17_high` FAIL на `(-1145.36,8.0,0)`; `z16_low` FAIL на `(-870.1,0.0,-3.99)`. Причина не отделена от длинных сегментов/respawn; нужна targeted проверка.
- **Доказательство:** `%TEMP%\opencode\stage3_route_walk.log`
- **Ответственный:** A03 (+A10 — harness)
- **Status:** OPEN / VERIFY

---

## BUG-020 — UI branch: `test_ui_demo` не находит цель P05

- **Severity:** Medium
- **Commit:** `fb8cc42` (`demo/ui-ux`; HEAD branch-local, **не в integration**)
- **Файл/сцена:** `scripts/ui/objective_line.gd`, `scripts/ui/post_nightmare_objectives.gd`, `scenes/locations/post_nightmare/police_precinct.tscn`
- **Шаги:**
  1. В worktree `shadowslave-demo-08` выполнить `test_ui_demo`.
  2. Открыть `test_post_nightmare_scene_gets_hud_and_objective`.
- **Ожидаемый результат:** `ObjectiveLine.get_objective_text()` содержит текст цели P05.
- **Фактический результат:** `test_ui_demo` 9/10; assert `Expected text and search strings to be non-empty. You passed "" and "участке"` на строке 165. UI commit удалил fallback `PostNightmareObjectives`; цель должна приходить из `CampaignGuide.set_external_objective` (A04), но в branch-local комбинации её нет.
- **Доказательство:** `%TEMP%\opencode\stage3_ui4_test.log`
- **Ответственный:** A08 + A04 (интеграционный контракт цели)
- **Status:** **RESOLVED at `ab8fe30`** — full GUT 683/683, targeted `test_ui_demo` 10/10. Branch-local `855cb0e` падал 9/10; integration merge исправил.

---

## BUG-024 — Integration: у 6 пост-Кошмарных сцен потерян скрипт корня

- **Severity:** Critical
- **Commit:** `f057d6c` (`demo/integration`, merge A09)
- **Файл/сцена:**
  - `scenes/locations/post_nightmare/police_precinct.tscn`
  - `scenes/locations/post_nightmare/academy_approach.tscn`
  - `scenes/locations/post_nightmare/academy_gate.tscn`
  - `scenes/locations/post_nightmare/academy_campus.tscn`
  - `scenes/locations/post_nightmare/academy_sleeper_center.tscn`
  - `scenes/locations/post_nightmare/black_sea_platform.tscn`
  - `scenes/locations/post_nightmare/tide_descent.tscn`
- **Шаги:**
  1. На `demo/integration` выполнить `test_post_nightmare_locations`.
  2. Или открыть любой `.tscn` и проверить, где стоит `script = ExtResource("1_location")`.
- **Ожидаемый результат:** корневой узел сцены имеет script и наследует `GreyboxLocation`; загружается HUD, цели, порталы, интерактивы.
- **Фактический результат:** `script = ExtResource(...)` и `location_id` находятся под дочерним `ArtOverlay`, а корневой `Node3D` — без скрипта. `test_post_nightmare_locations` — **5/15**, 10 fail; 6 сцен не проходят `as GreyboxLocation`, плюс cascading `rp_child is null`.
- **Доказательство:** `%TEMP%\opencode\stage3_fullint_post.log`, `stage3_fullint_gut.log`
- **Ответственный:** A00 (merge resolution) + A03 (scenes)
- **Status:** **RESOLVED at `ab8fe30`** — `test_post_nightmare_locations` 15/15; full GUT 683/683. Исторически был Critical integration regression.

---

## BUG-021 — Integration: `test_post_nightmare_locations` ждёт Джулиуса в M1

- **Severity:** High (full GUT red)
- **Commit:** `f9d40bf` (`demo/integration`; merge A04 gameplay + current UI)
- **Файл/сцена:** `scenes/locations/post_nightmare/academy_sleeper_center.tscn`, `tests/test_post_nightmare_locations.gd`
- **Шаги:**
  1. На `demo/integration` выполнить `test_post_nightmare_locations` или full GUT.
  2. Проверить `test_academy_sleeper_center_has_capsule`.
- **Ожидаемый результат:** тест соответствует M1-дизайну, где Джулиус — M2, а не M1.
- **Фактический результат:** integration full GUT **653/654**; `test_post_nightmare_locations` 14/15; `Expected [<null>] ... Джулиус существует` строка 306 и `Джулиус интерактивен` 307, хотя M1 намеренно убрал Джулиуса (M2).
- **Доказательство:** `%TEMP%\opencode\stage3_int2_gut.log`
- **Ответственный:** A03 (сцена) + A10 (тест)
- **Status:** **RESOLVED** — integration `a964d55`; test updated to M1 contract (no Julius, Rock/Kasper/Cassia present); `test_post_nightmare_locations` 15/15; full GUT 683/683.

---

## BUG-022 — Level branch: `test_labyrinth_first_fragment` ждёт включённый `ToWest`

- **Severity:** Medium
- **Commit:** `23d6219` (`demo/level-design`; HEAD branch-local, **не в integration**)
- **Файл/сцена:** `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`, `tests/test_labyrinth_first_fragment.gd`
- **Шаги:**
  1. В worktree `shadowslave-demo-03` выполнить `test_labyrinth_first_fragment`.
  2. Проверить `test_spawns_portals_shots_and_landmarks`, строка 137.
- **Ожидаемый результат:** тест соответствует новой M1/tech-demo логике `DemoEndZone`/`FinalZone`.
- **Фактический результат:** branch-local `23d6219` — 12/13, `ToWest.enabled=false`; на integration `f057d6c` targeted тест — **13/13, 334 assert**, но в full GUT тот же тест один раз упал на ToWest. Похоже на order/state flakiness, не постоянный дефект геометрии.
- **Доказательство:** `%TEMP%\opencode\stage3_level2_lab.log`, `stage3_fullint_lab2.log`, `stage3_fullint_gut.log`
- **Ответственный:** A03 + A10
- **Status:** **RESOLVED at `ab8fe30`** — full GUT 683/683, targeted `test_labyrinth_first_fragment` 13/13.

---

## BUG-023 — Integration working tree содержит незакоммиченные UI/input изменения

- **Severity:** Medium
- **Commit:** `1a39998` + dirty working tree (HEAD `demo/integration`)
- **Файл/сцена:** `scenes/ui/main_menu/main_menu.tscn`, `scripts/ui/main_menu/main_menu.gd`, `scripts/ui/pause_menu/pause_menu.gd`, `scripts/settings/game_settings.gd`, `tests/test_main_menu.gd`, `tests/test_game_settings.gd`, `tests/test_ui_demo.gd`, `scripts/settings/input_bindings.gd` (untracked), `scripts/ui/input_binding_row.gd` (untracked)
- **Шаги:**
  1. `git status` в `demo/integration`.
  2. Запустить full GUT/UI-тесты.
- **Ожидаемый результат:** все изменения, влияющие на PASS, зафиксированы в commit; результат воспроизводим из HEAD.
- **Фактический результат:** integration HEAD `1a39998` содержит UI commit, но поверх него есть незакоммиченные UI/input changes. Full GUT 656/656 и UI-тесты зелёные **только на dirty working tree**; из HEAD они не воспроизводятся.
- **Доказательство:** `git status`, `%TEMP%\opencode\stage3_integration_gut.log`, `stage3_integration_test_ui_demo.log`
- **Ответственный:** A00 + A08 (закоммитить/подтвердить)
- **Status:** **RESOLVED** — integration `f9d40bf` clean; UI/input tests в full GUT зелёные

---

## Branch-local фиксы уровня (не закрывать до merge)

На commit `61b15df` ветки `demo/level-design`:

- `route_reachability` — **18/18 зон, 51/51 POI** (Z04/Z15 PASS);
- `labyrinth_route_walk` — **51/51 сегментов**, exit 0.

Это branch-local доказательство, что BUG-003…BUG-010, BUG-018, BUG-019 исправлены на уровне. **Статусы не закрывать**, пока commit не попадёт в `demo/integration` и интеграционный прогон не повторит 51/51.

---

## 1. Приоритет исправления (после integration `ab8fe30`)

1. **Critical:** BUG-001 (нет export preset/build).
2. **High:** BUG-002 (нет непрерывного ручного прохода).
3. **Medium:** BUG-011 (draw calls 1677, optimization — вне текущего фикса), BUG-012 (Black Sea readability), BUG-017 (MCPRuntime в release).
4. **Low:** BUG-014 (HUD reveal, design review).

**RESOLVED at `ab8fe30` + QA fixes:** BUG-003…BUG-010, BUG-018…BUG-024, BUG-013 (меню «Шаблон»), BUG-015 (route-walk false positives), BUG-016 (`qa_script_audit` исправлен).

## STAGE 4 — COMPLETE DEMO PLAYTEST (2026-11-03)

### S4-0. Снимок и gates

- HEAD: `ab8fe304f5b4c9915d1d5579851f1402d2cf8b18` (`demo/integration`).
- Рабочее дерево: **dirty**, 30+ незакоммиченных файлов других агентов (`world_frame*`, `labyrinth_art.gd`, armor/loot, audio). Результаты ниже относятся к **рабочему дереву HEAD + dirty changes**, а не к чистому `ab8fe30`.
- `--import`: exit 0.
- Full GUT: **692/692, 7718 asserts** на снимке Stage 4; после Stage 4 fixes — **711/711, 7811 asserts, exit 0** (после `--import`).
- `qa_script_audit`: **378 скриптов, 0 failures** (tools/** исключены).
- `route_reachability`: **18/18 зон, 51/51 POI**.
- `labyrinth_route_walk` @10 м/с: **NOT COMPLETED**; дошёл до `z16_to_z17` (34/51) и не завершился за 10+ минут. @30 м/с: 47/51, но FAIL 31/33/36/50 вызваны высокой скоростью/телепортами, не геометрией. Нужен повтор на commit/оптимизированной сборке.

### S4-1. Итог по сценарию

| Блок | Статус | Доказательство |
|---|---|---|
| Main menu → P05 | **PASS** | реальный клик «После Кошмара · ДЕМО»; `post_nightmare_started=true` |
| P05 Jett + mirror | **PASS** | `p05_jett_talked`, `p05_mirror_seen`, `shadow_sight_unlocked` |
| P05→P06→P07→P08→P09→B01→B02→Labyrinth | **PASS** | реальные `LevelPortal.activate()`; все сцены загрузились |
| Objective/HUD B01/B02 | **PASS** | цели «Осмотреть статую…», «Спуститься к коралловому лабиринту…» |
| 7 base quests Z01–Z14 | **PASS** | `first_day`, `first_blood`, `azure_blade`, `crystal_cache`, `hunt_pack`, `camp_rest`, `bridge_stand` |
| E01/E02/E03 combat | **PASS** | aggro/damage, player melee kills, kill credit |
| SQ-01 «Девятый жетон» | **PASS** | token, traces, Theo, `sq_fs_01_complete` |
| SQ-02 «Голос из слепого туннеля» | **PASS** | `echo_polyp.tscn` создан; polyp killed, `destroy_polyp=1`, cloak/core, `sq_fs_02_complete` |
| SQ-03 «Правда без лжи» | **PASS** | `QuestChoicePanel` + controller; truth choice, `sq_fs_03_resolved`, cord/cache |
| SQ-04 «Соляной ящик» | **PASS** | маркеры/runtime, low tide, levers [LOW,HIGH,LOW], box, +2 shards |
| SQ-05 «Хозяин костяного моста» | **PASS** | Old Shell killed, alpha reward, shell cutter +2 shards |
| M1 finale Z10 | **PASS** | фактический переход в `PostNightmareFinale`, карточка «ПЕРВЫЙ ДЕНЬ», `ContinueButton` → Z11 |
| Tech demo Z11–Z18 | **PASS** | `TechDemoButton` в меню, `demo_mode_full`, Z01–Z18; `qa_stage4_menu_tech` 7/7 |
| Tech finale Z18 | **PASS** | FinalZone → `PostNightmareFinale`, `post_nightmare_completed`; `qa_stage4_final_save` 41/41 |
| Save/load F5/F9 | **PASS** | позиция, флаги, валюта, respawn врагов, reload сцены |
| Re-entry | **PASS** | runtime пересобран; мёртвый E01 не возрождается; SQ-01 token не повторяется |
| Checkpoint death | **PASS** | respawn в 1.0 м от checkpoint, без softlock |
| Tide cycle | **PASS** | low/high, 8 gates, открытие/закрытие |
| Inventory/pause UI | **PASS WITH LIMITATIONS** | открываются, objective/HP/tide видны; inventory — demo-набор, не из прохождения |

### S4-2. Новые баги

## BUG-025 — Tech demo Z11–Z18 недостижим в обычном прохождении

- **Severity:** Critical
- **Commit:** `ab8fe30` + dirty working tree
- **Где:** `scenes/ui/main_menu/main_menu.tscn`, `scripts/campaign/post_nightmare_finale.gd`, `scripts/world/quest_finale_zone.gd`, `project.godot`
- **Шаги:** main menu → «После Кошмара · ДЕМО» → пройти M1 до Z10 → карточка финала.
- **Ожидалось:** выбор tech demo (Z11–Z18) или кнопка «Продолжить» после M1.
- **Факт:** `demo_mode_full` не выставляется ни одним меню/entry; в меню только M1; карточка M1 пишет «Технический фрагмент продолжается после западного спуска», но предлагает только «В главное меню». Z11–Z18, SQ-04 и SQ-05 недоступны.
- **Доказательство:** `grep demo_mode_full` — только читатели/тесты; `stage4_final_shots/F02_m1_finale_card.png`, `F04_main_menu.png`; `stage4_final2.log`.
- **Ответственные:** A00-08 (режим/entry), A08-09 (меню), A04-11 (FinalZone/переход).
- **Исправление:** main menu получил `TechDemoButton` (`start_tech_demo` ставит `demo_mode_full`, `Z01`); M1-карточка получила `ContinueButton` → `CampReturn` + `demo_mode_full`; текст карточки исправлен.
- **Проверка:** `qa_stage4_menu_tech` 7/7 (реальный клик), `qa_stage4_final_save` 41/41 (continuation), `test_main_menu` 8/8; `stage4_menu_tech_shots/`.
- **Status:** **RESOLVED (QA fix, integration working tree)**.

## BUG-026 — SQ-02 невозможно завершить: отсутствует `echo_polyp.tscn`

- **Severity:** Critical
- **Commit:** `ab8fe30` + dirty working tree
- **Где:** `scripts/locations/forgotten_shore_labyrinth/labyrinth_narrative_director.gd:432-452`, `scenes/enemies/`, `resources/quests/sq_fs_02_echo_tunnel.tres`
- **Шаги:** SQ-01 complete → войти в `Narrative_SQ02_Tunnel` → собрать 3 эха → искать полипа.
- **Ожидалось:** `SQ02_EchoPolyp` с `QuestKillCredit(enemy_tag=echo_polyp)`, затем cloak/core.
- **Факт:** сцена `res://scenes/enemies/echo_polyp.tscn` отсутствует (`push_warning`), `sq_fs_02_polyp_dead` не выставляется, `destroy_polyp` = 0, cloak/core locked, `sq_fs_02_complete` не выставляется. SQ-03 остаётся заблокированным.
- **Доказательство:** `stage4_lab8.log` (`SQ-02 polyp node absent`, `cannot complete`, `destroy_polyp stuck at 0`); `stage4_b01_actual.png` не относится; warning в консоли.
- **Ответственные:** A05-01/A05-03 (enemy scene + kill credit), A02-02 (SQ runtime), A03-09 (marker).
- **Исправление:** добавлена `scenes/enemies/echo_polyp.tscn` (CarapaceEnemy AI, 55 HP, `echo_polyp` profile); kill credit и SQ-02 runtime проверены.
- **Проверка:** `qa_stage4_labyrinth` 161/161: polyp killed, `destroy_polyp=1`, cloak/core taken, `sq_fs_02_complete`; `fix_stage4_lab2.log`.
- **Status:** **RESOLVED (QA fix, integration working tree)**.

## BUG-027 — SQ-03 невозможно завершить: нет choice panel и `sq_fs_03_resolved`

- **Severity:** Critical
- **Commit:** `ab8fe30` + dirty working tree
- **Где:** `scenes/quests/gameplay_hud.tscn`, `scripts/ui/quest_choice_panel.gd`, `scripts/locations/forgotten_shore_labyrinth/labyrinth_narrative_director.gd:459-495`
- **Шаги:** форсировать `sq_fs_02_complete` → поговорить с TheoReturn.
- **Ожидалось:** после диалога choice panel пишет `sq_fs_03_resolved`, квест завершается.
- **Факт:** в HUD нет `QuestChoicePanel`; `sq_fs_03_resolved` не выставляется ни одним runtime-узлом (только тест вручную). После диалога `sq_fs_03_returned=true`, но quest active/not complete.
- **Доказательство:** `stage4_lab8.log` (`SQ-03 choice flag never set`, `choice panel absent`, `SQ03 NOT_IMPLEMENTED`).
- **Ответственные:** A04-06 (backend), A08-02 (UI), A02-03 (SQ data/runtime).
- **Исправление:** `QuestChoicePanel` + `QuestChoiceController` создаются narrative-директором; TheoReturn `dialogue_finished` открывает 3 выбора; truth/omission/unknown пишут `sq_fs_03_*`, `sq_fs_03_resolved`, кэш/нить.
- **Проверка:** `qa_stage4_labyrinth` 161/161: choice panel active, truth accepted, SQ-03 complete, cord/cache taken; `stage4_lab_fixed2_shots/L12a_SQ03_choice.png`.
- **Status:** **RESOLVED (QA fix, integration working tree)**.

## BUG-028 — SQ-04 не реализован

- **Severity:** High
- **Commit:** `ab8fe30` + dirty working tree
- **Где:** `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`, `labyrinth_narrative_director.gd:502-503`, `tide_controller.gd`
- **Шаги:** искать `Gameplay/Quests/SQ_FS_04`, пройти Z11, ждать отлив.
- **Ожидалось:** маркеры, `QuestTideLock`, 3 рычага, сундук, `sq_fs_04_complete`.
- **Факт:** маркеров и runtime нет, `build_sq_04=false`, `TideController.advance_to_low/high` отсутствуют (только `set_phase`). Квест нельзя начать.
- **Доказательство:** `stage4_lab8.log` (`SQ-04 markers absent`, `runtime absent`, `tide API absent`); `stage4_lab_shots/L13_SQ04_absent.png`.
- **Ответственные:** A04-07 (tide API/QuestTideLock), A02-04 (SQ data/runtime), A03-09/A03-10 (markers/Z11).
- **Исправление:** добавлены `SQ_FS_04` маркеры (Ledge/LowSill/Box/Chart/Levers A/B/C), runtime-директор, `TideController.advance_to_low/high` + `tide_changed`, `QuestLever`; box требует low tide + [LOW,HIGH,LOW], даёт 2 shards.
- **Проверка:** `qa_stage4_labyrinth` 161/161: SQ-04 started, low tide, levers, box, complete, +2 shards; `stage4_lab_fixed2_shots/L13_SQ04_complete.png`.
- **Status:** **RESOLVED (QA fix, integration working tree)**.

## BUG-029 — SQ-05: Old Shell отсутствует, доступен только bypass

- **Severity:** High
- **Commit:** `ab8fe30` + dirty working tree
- **Где:** `labyrinth_narrative_director.gd:606-632`, `scenes/enemies/`
- **Шаги:** Z14 Bridge/Trail → chum → bait → искать Old Shell → WestEnd.
- **Ожидалось:** Old Shell с `enemy_tag=sq_fs_05_old_shell`, убийство → `sq_fs_05_alpha_dead`, reward `sq_fs_05_shell_cutter` + 2 shards.
- **Факт:** `old_shell.tscn`/`carapace_old_shell.tscn` отсутствуют; alpha нельзя убить; reward pickup locked; квест завершается только через `Narrative_SQ05_WestEnd` (spare), без награды.
- **Доказательство:** `stage4_lab8.log` (`Old Shell absent`, `alpha cannot be killed`, `reward locked`, `complete via bypass`).
- **Ответственные:** A05-03 (Old Shell enemy), A02-05 (SQ runtime/reward), A03-09 (markers).
- **Исправление:** добавлена `scenes/enemies/old_shell.tscn` (180 HP, `sq_fs_05_old_shell` profile); alpha kill credit, reward pickup, shell cutter +2 shards.
- **Проверка:** `qa_stage4_labyrinth` 161/161: alpha killed, reward taken, `sq_fs_05_complete`; `stage4_lab_fixed2_shots/L14_SQ05_complete.png`.
- **Status:** **RESOLVED (QA fix, integration working tree)**.

## BUG-030 — Finale zones меняют сцену внутри physics callback

- **Severity:** High
- **Commit:** `ab8fe30` + dirty working tree
- **Где:** `scripts/locations/forgotten_shore_labyrinth/demo_end_zone.gd:47-65`, `final_zone.gd:24-56`
- **Шаги:** войти в `DemoEndZone` или `FinalZone`.
- **Ожидалось:** `call_deferred("_enter_finale")` / отложенный переход.
- **Факт:** `get_tree().change_scene_to_file()` вызывается из `body_entered`/`_try_fire`;引擎: `Removing a CollisionObject node during a physics callback is not allowed...`.
- **Доказательство:** `stage4_final.log`, `stage4_final2.log`, MCP errors; `demo_end_zone.gd:65`.
- **Ответственные:** A04-10/A04-11 + A03-08/A03-10.
- **Исправление:** `DemoEndZone._try_fire` и `FinalZone._try_fire` теперь вызывают `call_deferred("_enter_finale")`; физический callback больше не меняет сцену.
- **Проверка:** `qa_stage4_final_save` 41/41, `qa_stage4_input_combat` 15/15; в логах больше нет `Removing a CollisionObject...`.
- **Status:** **RESOLVED (QA fix, integration working tree)**.

## BUG-031 — B01 `Portals/ToCoral` не включается после `shroud_summoned`

- **Severity:** Medium
- **Commit:** `ab8fe30` + dirty working tree
- **Где:** `scripts/locations/post_nightmare/black_sea_platform.gd:648-663, 694-702`
- **Шаги:** B01 → Stars → Shroud → проверить портал / войти в него.
- **Ожидалось:** после `shroud_summoned` портал открыт.
- **Факт:** `portal.enabled` остаётся `false`; включается только в `_on_descent_interacted` (DescentInteract). Игрок, идущий в портал, получает «Проход ещё закрыт», хотя флаги выполнены; работает только E на DescentInteract.
- **Доказательство:** `stage4_post2.log` (`B01 coral portal enabled after shroud` FAIL); `B01_02_shroud.png`.
- **Ответственные:** A03-06/A04-02.
- **Исправление:** `_on_shroud_interacted` теперь включает `Portals/ToCoral`.
- **Проверка:** `qa_stage4_post_nightmare` 62/62, `B01 coral portal enabled after shroud`.
- **Status:** **RESOLVED (QA fix, integration working tree)**.

## BUG-032 — B01 Black Sea readability (подтверждение BUG-012)

- **Severity:** Medium
- **Commit:** `ab8fe30` + dirty working tree
- **Где:** `scenes/locations/post_nightmare/black_sea_platform.tscn`, `black_sea_platform.gd`
- **Факт:** на спавне статуя/платформа почти не читаются, большая часть кадра чёрная; интерактивный маркер — маленький ромб. Игрок не понимает, куда идти, без подсказки.
- **Доказательство:** `addons/godot_mcp/cache/screenshots/stage4_b01_actual.png`, `B01_01_statue.png`.
- **Ответственные:** A07-04/A09-04.
- **Исправление:** добавлен `StatueReadFill` SpotLight3D (240 м, 4.5) для статуи; это смягчает, но не заменяет art-pass.
- **Проверка:** `stage4_post_fixed2_shots/B01_01_statue.png` — платформа всё ещё слишком тёмная; **нужен A07 art-pass**.
- **Status:** **OPEN — mitigated, art pass required** (BUG-012 не закрыт).

## BUG-033 — Tutorial overlay остаётся на B01/B02

- **Severity:** Low
- **Commit:** `ab8fe30` + dirty working tree
- **Где:** `greybox_location.gd:136-143`, `scenes/quests/gameplay_hud.tscn`
- **Факт:** в B01/B02 поверх кадра висит «WASD — движение · мышь — обзор · Shift — бег», хотя HUD создаётся с `tutorial_enabled=false`. Мешает чтению сцены, особенно B01.
- **Доказательство:** `stage4_b01_actual.png`, `stage4_b02_actual.png`.
- **Ответственные:** A08-01/A08-05.
- **Исправление:** `GreyboxLocation._setup_post_nightmare_demo` теперь всегда выставляет `tutorial_enabled=false`, включая HUD, уже лежащий в сцене.
- **Проверка:** `stage4_post_fixed2_shots/B01_01_statue.png` — tutorial-overlay отсутствует.
- **Status:** **RESOLVED (QA fix, integration working tree)**.

### S4-3. Точные задания владельцам

| Владелец | Задание | Приёмка |
|---|---|---|
| **A05** | Принять/проверить QA-сцены `echo_polyp.tscn` и `old_shell.tscn`; заменить placeholder-модели на финальные, сохранить kill credit | SQ-02/SQ-05 проходят; kill credit live |
| **A02** | Принять SQ-02/03/04/05 runtime и маркеры; проверить диалоги/тексты/выбор | SQ-01…05 в одном live-прохождении; нет softlock |
| **A04** | Принять `advance_to_low/high`, `QuestChoiceController`, deferred finale; проверить контракты | SQ-03 choice, SQ-04 tide, финалы без physics error |
| **A08** | Принять `TechDemoButton`, `ContinueButton`, choice panel; проверить 16:9/4K | Меню/карточка ведут в Z11–Z18; choice UI работает |
| **A00** | Закоммитить QA fixes + dirty changes, зафиксировать `demo_mode_full`; release build | Clean commit; 0 fail; build exists |
| **A03** | Проверить `route_walk` на commit и B01/Z11–Z18; маркеры SQ-04 | 18/18, 51/51, 51/51 |
| **A07** | B01 readability (BUG-012/032); проверить Z17 и стоимость кадра | B01 читается; route_walk @10 м/с завершается |
| **A10** | Повторить Stage 4 на clean commit: import, full GUT, reachability, walk, live save/load, SQ-01…05 | PASS/FAIL по каждому блоку, без “NOT TESTED” |

### S4-4. Ограничения

- Полный **человеческий** 50–70-минутный проход не выполнялся; использованы actual Godot scenes + input/portal/combat API, скриншоты и live MCP.
- Результаты получены на dirty working tree; после коммита их нужно повторить.
- Tech demo теперь доступен через `TechDemoButton` и `ContinueButton`; проверен реальным кликом (`qa_stage4_menu_tech` 7/7).
- `labyrinth_route_walk` @10 м/с не завершился; @30 м/с 47/51 с speed-induced FAIL; считать **NOT VERIFIED** до чистого прогона.
- BUG-011 (draw calls) и оптимизация не менялись по указанию пользователя.
- BUG-032 (B01 readability) смягчён светом, но требует art-pass A07.

### S4-5. Fixes applied (QA-owned, 2026-11-03)

- **Tech demo entry:** `TechDemoButton` в main menu; `ContinueButton` на M1-карточке; `demo_mode_full` выставляется до загрузки лабиринта.
- **SQ-02:** `scenes/enemies/echo_polyp.tscn` + `resources/combat/enemies/echo_polyp.tres`; kill credit `echo_polyp`.
- **SQ-03:** `QuestChoicePanel` + `QuestChoiceController` в narrative director; TheoReturn choice, `sq_fs_03_resolved`.
- **SQ-04:** маркеры `SQ_FS_04`; `TideController.advance_to_low/high` + `tide_changed`; `QuestLever`; box/chart/reward.
- **SQ-05:** `scenes/enemies/old_shell.tscn` + `old_shell.tres`; alpha kill credit + reward.
- **Finale:** `DemoEndZone`/`FinalZone` scene changes deferred.
- **B01:** portal enabled after shroud; fill light for readability (partial).
- **Tutorial:** post-nightmare HUD always `tutorial_enabled=false`.

### Verification after fixes

| Run | Result |
|---|---|
| Full GUT | **711/711, 7811 asserts, exit 0** |
| `qa_stage4_labyrinth` | **161/161, 0 fail** |
| `qa_stage4_post_nightmare` | **62/62, 0 fail** |
| `qa_stage4_final_save` | **41/41, 0 fail** |
| `qa_stage4_input_combat` | **15/15, 0 fail** |
| `qa_stage4_menu_tech` | **7/7, 0 fail** |
| `test_main_menu` | **8/8, 51 asserts** |
| `test_post_nightmare_locations` | **16/16, 518 asserts** |
| `qa_script_audit` | **378 scripts, 0 failures** |
| `route_reachability` | **18/18, 51/51** |

## STAGE 5 — RELEASE CANDIDATE VALIDATION (2026-11-03)

- **Full report:** `docs/demo_sprint/qa/FINAL_QA_REPORT.md`.
- **Full GUT:** **717/717, 7,849 asserts, exit 0** after clean `--import`.
- **Resource audit:** 715 checked, 211 scenes, 504 resources, 0 failures.
- **Route:** `route_reachability` 18/18 zones, 51/51 POI; `labyrinth_route_walk` 51/51 at 15 m/s after removing runtime enemies from the static audit.
- **Gameplay:** First Nightmare 9/9; main menu M1 5/5; finale→P05 5/5; portal chain 23/23; post-nightmare 62/62; labyrinth/SQ 161/161; finale/save 41/41; input/F5/F9 15/15; tech menu 7/7.
- **UI:** menu, settings, HUD, journal, inventory, map, pause, choice panel, finale cards — 8/8 open/capture checks; limitations: demo inventory, map header overlap.
- **Characters:** 74/74 animation/character tests; 18 Sunny state captures + 8 NPC captures; M1 NPCs remain mannequin placeholders.
- **Performance:** labyrinth 108.8 FPS @1920×1080, **1,661 draw calls > 1,500**, 825 MB VRAM; P05 125.6 FPS/370; B01 155.9 FPS/225.
- **Export:** **PASS WITH LIMITATIONS** — local preset `script_export_mode=0`, `4.7.2.stable` templates installed locally; `build/ShadowSlave.exe` (109 MB) + `ShadowSlave.pck` (962 MB) produced; headless boot exit 0. Preset/templates are machine-local, PCK includes tools/tests/MCPRuntime; clean release-only rebuild required.
- **Export note:** binary-token script export produced autoload type-resolution and bark-JSON errors; text script mode is required for this tree.
- **Critical/High escalation:** BUG-001 (build) Critical; BUG-002 (human pass) High; BUG-017 (`MCPRuntime` release) High; BUG-032 (B01 readability) Medium; BUG-011 (draw calls) Medium.
- **Known non-fatal runtime cleanup:** `Can't use get_node() with absolute paths...` on F9 reload; reflection-probe error on one transition; 7 texture RIDs leaked at exit.
- **Release gate:** **FAIL / NOT RELEASE-READY** until clean commit + export build + human pass.

## 2. Правило проверки после commit

Для каждого нового commit:

1. Записать commit hash и затронутые пути.
2. Запустить `--import`.
3. Запустить целевые тесты затронутой зоны + `test_post_nightmare_locations` / `test_labyrinth_first_fragment` при изменениях Лабиринта.
4. Для route-изменений повторить `route_reachability` и `labyrinth_route_walk`.
5. Обновить статус соответствующего BUG.
6. Не закрывать BUG только по словам автора: нужен лог/скриншот/повторный прогон.

## 3. Stage 5 integration status (2026-11-03)

| ID / область | Статус после Stage 5 | Комментарий |
|---|---|---|
| BUG-001 (build) | **MITIGATED LOCALLY / OPEN** | Temp Stage 5 exe+PCK собран и boot exit 0; нужен clean release-only rebuild. |
| BUG-002 (manual pass) | **OPEN / NOT TESTED** | M1, tech demo и Academy вручную не пройдены. |
| BUG-011 (draw calls) | **OPEN** | 1 661 draw calls в Лабиринте; FPS приемлем, бюджет превышен. |
| BUG-012/BUG-032 (B01 readability) | **OPEN** | Нужен art pass A07. |
| BUG-017 (MCPRuntime в release) | **OPEN** | Dev autoload остаётся в PCK. |
| BUG-021 (P09 Julius) | **RESOLVED** | M1-контракт без Julius; Rock/Kasper/Cassia на месте. |
| BUG-026…BUG-031, BUG-033 (SQ/finale) | **RESOLVED** | SQ-02/03/04/05, FinalZone и tutorial overlay закрыты в интеграции. |
| A06 authored hit/death clips | **RESOLVED** | `carapace_hit`, `larva_hit`, `larva_death` регистрируются в AnimationLibrary. |
| Input rebind / gamepad | **RESOLVED (code) / NOT TESTED (live)** | Меню и пауза используют `InputBindingRow`; дефолты геймпада добавлены. |
| Academy segment | **INTEGRATED (headless) / NOT TESTED (manual)** | Меню → Academy Grounds/Sleeper Center; 24/24 квестов в walkthrough-probe. |
| Cutscene system | **INTEGRATED (headless) / NOT TESTED (manual)** | 5 M1-катсцен; skip/completion flags проверены GUT. |
| FinalCard component | **PARTIAL** | Живой финал использует собственную карточку; отдельный FinalCard остаётся альтернативным UI. |

**Release gate:** по-прежнему **FAIL / NOT RELEASE-READY** до clean rebuild, human pass и 1080p/listening test.
