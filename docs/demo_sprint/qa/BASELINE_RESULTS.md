# BASELINE RESULTS — Stage 3

Дата: 2026-11-03, 02:03–02:50 +03:00  
Автор: Chat 10 — Independent Lead QA / Release Engineer  
Branch: `demo/integration`  
HEAD: `ee973250e45e8d0b661de243badce095621ffbdf` (`docs: record DP-1.0 baseline commit`)  
Base implementation commit: `75f1423` (`baseline: DP-1.0 design package and current implementation`)  
Working tree: clean except `opencode.json` (не игровой файл) на начало прогона; после создания QA-документов появились только `BASELINE_RESULTS.md`, `BUG_REGISTRY.md` и правка `qa/README.md`.  
Git status at snapshot (до QA-документов): 1 modified file

---

## 0. Итог baseline

| Область | Статус | Кратко |
|---|---|---|
| Импорт | **PASS** | exit 0, 0 ошибок |
| Полный GUT | **PASS** | 81 скрипт, 636 тестов, 636 pass, 7333 asserts, exit 0 |
| Запуск main menu / campaign / 9 основных сцен | **PASS** | 0 ошибок при headless boot |
| Ресурсы | **PASS** | 495 проверено, 145 сцен, 350 ресурсов, 0 failures |
| Performance | **PASS WITH LIMITATIONS** | FPS высокий; Labyrinth draw calls 1593 > 1500 |
| Route reachability | **FAIL** | 16/18 зон, 43/48 POI |
| Route walk | **FAIL** | 34/51 сегментов |
| Build/export | **FAIL** | нет `export_presets.cfg`, exit 1 |
| Ручной проход | **NOT VERIFIED** | не выполнялся |
| Визуал | **PASS WITH LIMITATIONS** | POC/placeholder, тёмный Black Sea, blockout |

**Вердикт baseline:** технический тестовый baseline зелёный, **release baseline — FAIL / NOT READY**. Причины: отсутствие build и ручного прохода, подтверждённые разрывы маршрута Лабиринта, превышение draw-call бюджета.

Дефекты: `docs/demo_sprint/qa/BUG_REGISTRY.md`.

---

## 1. Commit watch

```text
ee97325 docs: record DP-1.0 baseline commit
75f1423 baseline: DP-1.0 design package and current implementation
0335a5c feat: complete P2.5-P5 art, UI and optimization
```

- `75f1423` — большой baseline-коммит DP-1.0: design package, текущая реализация, аудио/VFX/quests.
- `ee97325` — только 4 design-документа; игровые файлы не менялись.
- На момент проверки новых specialist-коммитов после `ee97325` нет.
- Единственное изменение дерева — `opencode.json`; в QA-прогонах не участвует.
- **Правило:** каждый следующий commit проверяется только после появления в `demo/integration`; до этого совместимость не утверждается.

### 1.1. Watch log

| Время | Новый commit | Действие |
|---|---|---|
| 02:03 | — | baseline start, HEAD `ee97325` |
| 02:39 | — | повторная проверка: новых specialist-коммитов нет; дерево содержит только `opencode.json` + QA-документы |
| 02:44 | — | повторная проверка: HEAD всё ещё `ee97325`; новых коммитов нет |
| 02:47 | `demo/narrative`: `41d3957`, `a087741`, `85a262a` | **не в `demo/integration`**; совместимость не проверялась и не утверждается |
| 02:50 | — | повторная проверка: HEAD `ee97325`; новых коммитов в integration нет |
| 02:52 | `demo/gameplay`: `41a35bf` | **не в `demo/integration`**; branch-local `test_quest_extensions` 11/11, 41 assert; интеграционная совместимость не проверена |
| 02:54 | `demo/quests`: `8faac4d` → `0cdec32`; `demo/ui-ux`: `04e3f22` → `64f82e0` | ветки переписаны/уточнены; **не в integration**; branch-local тесты ниже |
| 02:56 | — | UI branch-local `test_ui_demo` 9/10 (BUG-020); quests branch-local `test_side_quests` 3/3 на `8faac4d`; integration HEAD всё ещё `ee97325` |
| 03:01 | `demo/ui-ux`: `1da74d6` | ветка переписана; `test_ui_demo` снова 9/10, BUG-020 воспроизведён; **не в integration** |
| 03:02 | `demo/gameplay`: `5795900`; `demo/ui-ux`: `fb8cc42` | ветки переписаны; UI `test_ui_demo` снова 9/10 (BUG-020); gameplay worktree dirty, commit не тестировался чисто; **не в integration** |
| 03:11 | `demo/gameplay`: `a817fd2` | branch-local: `test_quest_extensions` 12/12, `save_system` 2/2, `full_route` 3/3, `campaign_flow` 11/11, `post_nightmare` 15/15; **не в integration** |
| 03:12 | `demo/audio-vfx`: `2449a61` | branch-local: `audio_system` 19/19, `demo_audio_vfx` 8/8, `labyrinth_audio` 6/6, `audio_playback` 7/7; **не в integration** |
| 03:16 | `demo/audio-vfx`: `c069416` | ветка переписана; повторно 19/19, 8/8, 6/6, 7/7; **не в integration** |
| 03:26 | `demo/audio-vfx`: `1330c0c` | stage 6 polish; повторно 19/19, 8/8, 6/6, 7/7; **не в integration** |
| 03:38 | `demo/audio-vfx`: `d55b43a` | stage 7 polish; повторно 19/19, 8/8, 6/6, 7/7; **не в integration** |
| 03:36 | `demo/combat-ai`: `e911af9` | enemy AI/weak spot/respawn; worktree dirty после commit, чистый commit-прогон не выполнен; **не в integration** |
| 03:47 | `demo/characters`: `6ac4aba`, `9620ac9` | character/animation wave + handoff; worktree dirty; чистый commit-прогон не выполнен; **не в integration** |
| 03:26 | `demo/quests`: `29ecbb1` | branch-local: `test_side_quests` 8/8, 142 assert; `test_labyrinth_quest_content` 4/4; **не в integration** |
| 04:02 | `demo/environment`: `4a7a2f0` | branch-local: `post_nightmare` 15/15, `labyrinth` 13/13, `location_art_decor` 3/3; **не в integration** |
| 04:05 | `demo/ui-ux`: `855cb0e` | branch-local: `test_ui_demo` 9/10 (BUG-020), `main_menu` 7/7, glossary 10/10, menus 7/7, map 22/22; **не в integration** |
| 04:07 | `demo/combat-ai`: `b22448e` | group pressure/E01 polish; worktree dirty после commit, чистый commit-прогон не выполнен; **не в integration** |
| 04:12 | `demo/characters`: `8db8c7e` | branch-local: `sunny_animation` 16/16, `sunny_poc` 10/10, `sunny_waking` 10/10, `enemy_animation` 7/7; **не в integration** |
| 04:15 | `demo/environment`: `b13d553` | branch-local: `post_nightmare` 15/15, `labyrinth` 13/13, `location_art_decor` 3/3; **не в integration** |
| 04:18 | `demo/characters`: `7a9931e` | docs-only «final full-suite result»; код не менялся; **не в integration** |
| 04:27 | `demo/environment`: `7452b71` | camp/refuge silhouettes; branch-local `labyrinth` 13/13, `location_art_decor` 3/3; **не в integration** |
| 04:28 | `demo/combat-ai`: `a38b90c` | branch-local: combat AI 10/10, carapace 10/10, controller 9/9, arena 6/6; **не в integration** |
| 04:40 | `demo/characters`: `79851da` | NPC presentation; branch-local `sunny_animation` 16/16, `slice_locations` 8/8, `caravan_march` 7/7, `pilgrim_path` 10/10; **не в integration** |
| 04:47 | `demo/level-design`: `61b15df` | branch-local: `route_reachability` **18/18, 51/51 POI**, `labyrinth_route_walk` **51/51**; GUT: post-nightmare 14/15 (Julius test stale), labyrinth 12/13 (ToWest test stale); см. BUG-021/022; **не в integration** |
| 05:10 | `demo/level-design`: `23d6219` | interaction state/re-entry hardening; `level_transition` 22/22; Julius test 14/15 и ToWest 12/13 остаются (BUG-021/022); **не в integration** |
| 05:10 | `demo/integration`: `1a39998` | первый integration-commit (UI vitals); поверх — незакоммиченные UI/input changes (BUG-023); остальные 8 веток не влиты |
| 05:14 | integration working tree | `--import` 0; full GUT **83 scripts / 656 tests / 656 pass / 7424 asserts**; `test_ui_demo` 12/12, `test_main_menu` 7/7, `test_game_settings` 12/12, `test_input_binding_row` 6/6; **dirty tree, не HEAD** |
| 05:28 | `demo/level-design`: `56f8f4f` | M1 presentation; `test_post_nightmare_locations` 14/15 (Julius test stale, BUG-021); **не в integration** |
| 05:32 | `demo/quests`: `8a23875` | stage 7 fallback; branch-local `test_side_quests` 8/8, `labyrinth_quest_content` 4/4; **не в integration** |
| 05:33 | `demo/integration`: `f9d40bf` | merge A04 gameplay + UI; full GUT **653/654**, 1 fail (BUG-021); import 0; dirty UI/input BUG-023 закрыт |

### 1.2. Pending worktrees (snapshot 05:33)

| Branch | Last commit | Uncommitted entries in its worktree | Integration status |
|---|---|---:|---|
| `demo/narrative` | `85a262a` | 0 | **3 commits ahead; not merged** |
| `demo/quests` | `8a23875` | 0 | **3 commits ahead; not merged**; branch-local SQ tests 8/8 + 4/4 |
| `demo/level-design` | `56f8f4f` | 0 | **3 commits ahead; not merged**; route 51/51 и reach 18/18 на 61b15df; 2 test mismatches |
| `demo/gameplay` | `a817fd2` | 0 | **3 commits ahead; not merged**; branch-local quest/save/route/campaign tests green |
| `demo/combat-ai` | `a38b90c` | 0 | **3 commits ahead; not merged**; branch-local combat tests green |
| `demo/characters` | `79851da` | 0 | **5 commits ahead; not merged**; branch-local animation/scene tests green |
| `demo/environment` | `7452b71` | 0 | **3 commits ahead; not merged**; branch-local scene/art tests green |
| `demo/ui-ux` | `855cb0e` | 0 | **2 commits ahead; not merged**; test_ui_demo 9/10 (BUG-020) |
| `demo/audio-vfx` | `d55b43a` | 0 | **3 commits ahead; not merged**; branch-local audio suites green |

**Не тестировать эти изменения до слияния в `demo/integration`.** После слияния — целевые тесты по затронутым сценам/системам; результат привязать к новому commit.

### 1.3. Integration validation (05:33)

- `demo/integration` HEAD: `f9d40bf` (`merge: A04 gameplay and quest systems`), поверх UI `1a39998`.
- В integration влиты **UI + A04 gameplay/quests**; narrative/quests/level/combat/characters/environment/audio ветки ещё не влиты.
- `--import`: exit 0, 0 ошибок.
- Full GUT: **83 scripts, 654 tests, 653 pass, 1 fail, 7394/7396 asserts, exit 1**, 249.4 s.
- Единственное падение — `test_post_nightmare_locations::test_academy_sleeper_center_has_capsule`: тест ждёт Джулиуса в M1, сцена его намеренно убрала (BUG-021). Это **integration blocker** для full GUT.
- `test_ui_demo` в составе full GUT проходит; BUG-020 на integration больше не воспроизводится.
- BUG-023 (dirty UI/input working tree) закрыт: integration clean после merge.
- Вывод: UI+gameplay слой интегрирован, но полный GUT красный из-за stale-теста; M1/tech demo совместимость остальных веток не проверена.

Для narrative-ветки после merge проверить:

- `test_dialogue`, `test_dialogue_barks`, `test_campaign_flow`;
- `test_post_nightmare_locations` (15/15 baseline);
- P05/P06/P09/B01/B02/B03 dialogue resources вживую;
- speaker IDs/display names по `INTEGRATION_CONTRACTS.md`;
- отсутствие дублей legacy-файлов (`precinct_wake` vs `p05_jett_awakening` и т.п.).

Для gameplay-ветки после merge проверить:

- `test_quest_extensions` (branch-local сейчас 11/11, 41 assert);
- `test_quest_system`, `test_labyrinth_quest_content`, `test_save_system`;
- `test_full_route`, `test_campaign_flow`, `test_post_nightmare_locations`;
- scope isolation (`QuestSystem.active_scope == &""` вне B03);
- новые `QuestInspectable`, `QuestChoiceController`, `QuestTideLock/Wait`, `QuestFinaleZone` на сценах, а не только unit.

---

## 2. Импорт

```powershell
godot --headless --path . --import
```

```text
EXIT=0
ERROR_LINES=0
```

Лог: `%TEMP%\opencode\stage3_import.log`.

### 2.1. Project config

- 10 autoloads присутствуют: `MCPRuntime`, `NightmareRunState`, `DialogueManager`, `MapSystem`, `PlayerMenuSystem`, `PauseMenuSystem`, `CampaignGuide`, `QuestSystem`, `SaveSystem`, `AudioDirector`.
- `[rendering]` P5-настройки присутствуют: S3TC/BPTC, occlusion culling, mesh LOD threshold 1.5.
- `export_presets.cfg` отсутствует — build заблокирован.

---

## 3. Полный GUT

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

```text
Scripts              81
Tests               636
Passing Tests       636
Failing Tests         0
Asserts            7333
Time              402.629s
EXIT=0
---- All tests passed! ----
```

Лог: `%TEMP%\opencode\stage3_gut.log`.

### 3.1. Ожидаемые error-сообщения

В логе 4 строки `ERROR`, все — проверки negative-path `DialogueManager`:

- `test_invalid_barks.json` — ожидаемый parse error;
- `test_missing_barks.json` — ожидаемый missing-file error.

Они не являются падением GUT; `Failing Tests = 0`.

### 3.2. Целевые наборы

| Набор | Результат | Assert | Exit |
|---|---:|---:|---:|
| `test_post_nightmare_locations` | 15/15 | 513 | 0 |
| `test_labyrinth_first_fragment` | 13/13 | 332 | 0 |
| `test_main_menu` | 7/7 | 45 | 0 |
| `test_full_route` | 3/3 | 220 | 0 |

Логи: `%TEMP%\opencode\stage3_<suite>.log`.

---

## 4. Запуск Godot и основных сцен

### 4.1. Boot main scene

```powershell
godot --headless --path . --quit-after 120
```

```text
EXIT=0
ERRORS=0
```

### 4.2. Boot campaign entry

```powershell
godot --headless --path . --quit-after 120 res://scenes/campaign/campaign_entry.tscn
```

```text
EXIT=0
ERRORS=0
```

### 4.3. Boot пост-Кошмарных сцен

Каждая сцена запускалась headless с `--quit-after 60`:

| Сцена | Exit | Ошибки |
|---|---:|---:|
| `police_precinct` | 0 | 0 |
| `academy_approach` | 0 | 0 |
| `academy_gate` | 0 | 0 |
| `academy_campus` | 0 | 0 |
| `academy_sleeper_center` | 0 | 0 |
| `black_sea_platform` | 0 | 0 |
| `tide_descent` | 0 | 0 |
| `labyrinth_first_fragment` | 0 | 0 |
| `post_nightmare_finale` | 0 | 0 |

Логи: `%TEMP%\opencode\stage3_boot_<scene>.log`.

### 4.4. Визуальные кадры

| Кадр | Файл | Наблюдение |
|---|---|---|
| Main menu | `%TEMP%\opencode\stage3_shots\main_menu.png` | «Играть», «Настройки», «Кредиты», «После Кошмара»; внизу осталась подпись «Шаблон: графика, звук…» |
| Campaign entry | `...\campaign_entry.png` | пролог стартует; POC-капсула Санни, HUD цели |
| Police precinct | `...\police_precinct_Shots_Overview.png` | серый blockout, читается |
| Black Sea platform | `...\black_sea_platform_Shots_Overview.png` | статуя и звёзды видны, фон почти чёрный |
| Labyrinth entrance | `...\labyrinth_first_fragment_Shots_Entrance.png` | красный коралл, HUD, прилив; игрок — placeholder, панель «Противник 65/65» видна первые 4 с |
| Post-nightmare finale | `...\post_nightmare_finale.png` | финальная карточка, возврат в меню |

Все пути — временные. Скриншоты не коммитятся.

---

## 5. Загрузка ресурсов

```powershell
godot --headless --path . -s tools/audit/qa_resource_audit.gd -- --out=<temp>
```

```text
QA_RES_SUMMARY checked=495 scenes=145 resources=350 failures=0
EXIT=0
```

Проверены все `.tscn` и `.tres` в `scenes/`, `resources/`, `assets/`: битых `ext_resource` нет. Лог: `%TEMP%\opencode\stage3_resources.log`.

---

## 6. Производительность

Все замеры — uncapped, 1920×1080, реальный Forward+ рендер; не заменяют ручной проход.

| Кадр | FPS avg | Draw calls | Primitives | VRAM | Вывод |
|---|---:|---:|---:|---:|---|
| Park, фикс. камера | 164.9 | 252.9 | 1.57M | 1117.5 MB | PASS |
| Prologue, player+UI | 165.8 | 718.0 | 1.86M | 1127.4 MB | PASS |
| Labyrinth entrance | 93.1 | 1593.0 | 4.78M | 756.9 MB | FPS PASS; draw calls >1500 |

Логи:

- `%TEMP%\opencode\stage3_perf_park.log`
- `%TEMP%\opencode\stage3_perf_campaign.log`
- `%TEMP%\opencode\stage3_perf_lab.log`

**Ограничение:** нет боя E01–E03, Z18, 4K, vsync, thermal soak; Labyrinth draw calls 1593 превышают бюджет D-26 (<1500).

---

## 7. Route reachability

```powershell
godot --headless --path . -s tools/audit/route_reachability.gd -- --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn
```

```text
zone_result=16/18
poi_result=43/48
```

Провалы:

- **Z04 MudHollow** — `poi=(-30,-2.8,-42)`, nearest floor cell `(-30,7,-57)`, `dxz=15.0`, `dy=9.8`; вход/пол не достигаются (G1).
- **Z15 HighRefuge** — `poi=(-700,18.2,-20)`, nearest floor `(-706.5,2,-28.5)`, `dy=-16.2`; сетка не видит верхнюю полку (ложное отрицание или реальный разрыв; проверить).
- **Spawns/Refuge, RefugeReturn, RefugeCheckpoint, TideSafePoints/S15_Refuge, Gameplay/Triggers/Refuge** — все привязаны к Z15 и падают по той же причине.

Лог: `%TEMP%\opencode\stage3_route_reach.log`.

---

## 8. Route walk

```powershell
godot --headless --path . -s tools/audit/labyrinth_route_walk.gd -- --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn
```

```text
route_walk result: 34/51 segments passed
EXIT=1
```

Провалы (сырые):

```text
z07_ridge, z07_west, z10_base, z10_top, z10_west,
z12_high_link, z14_bridge_ramp, z14_bridge, z15_west,
z16_ridge, z17_high, z03_z04, z03_z05, z05_z06,
z08_z09, z11_low, z16_low
```

Классификация:

- **Подтверждённые дефекты геометрии:** Z07 ridge, Z10 base, Z04/Z11/Z08/Z05 G1–G5.
- **Вероятный дефект:** Z12 high link.
- **Ложные срабатывания инструмента:** Z14 bridge/ramp (карапаксы), Z15 west (прямая вместо лестницы), Z10 west (reset на стартовый чекпоинт), часть Z16/Z17 (длинные сегменты/сброс).

Лог: `%TEMP%\opencode\stage3_route_walk.log`.

### 8.1. Collision probes

| Точка | Результат | Вывод |
|---|---|---|
| `(-10,7,-52)` Z07 ridge | `COLLISION_SUMMARY found=0` | дыра в коллизии |
| `(-85,1,18)` Z10 base | `Col_Z09_ToHill_100` в `(-86.5,0.36,20)` + стены Z09 | блокер входа на лестницу |
| `(-202,5,-40)` Z12 high link | `found=0` | высокий переход не подтверждён |

Логи: `%TEMP%\opencode\stage3_probe_z07.log`, `stage3_probe_z10base.log`, `stage3_probe_z12link.log`.

### 8.2. Combat probe

```text
PLAYER combat_enabled=true controls=true pos=(38,6,0) attack_damage=12.0
ENEMIES count=6
WoundedScavenger 65 HP
PackCarapace1..3 95 HP
BridgeCarapace1..2 95 HP
```

Это подтверждает наличие боевого слоя; баланс/бой вручную **NOT TESTED**. Лог: `%TEMP%\opencode\stage3_combat_probe.log`.

---

## 9. Build/export

```powershell
godot --headless --path . --export-release "Windows Desktop" <temp>\ShadowSlave.exe
```

```text
EXIT=1
ERROR: This project doesn't have an `export_presets.cfg` file at its root.
NO_BUILD
```

Лог: `%TEMP%\opencode\stage3_export.log`.

---

## 10. Что не проверено

- Непрерывный ручной проход M1 и M4.
- Бой E01–E03, смерть/респавн, групповой бой.
- Живой F5/F9 и загрузка в другой сцене.
- Слуховой тест музыки/эмбиента/SFX/VO.
- 4K/ultrawide, геймпад, rebind.
- Экспортированный билд и clean machine.
- Clean clone.
- SQ-FS-01…05.
- Термический/VRAM soak.

---

## 11. Вывод

1. **Технический baseline зелёный:** import, GUT, boot сцен, ресурсы.
2. **Route baseline красный:** 34/51 и 16/18; часть провалов — реальные G1–G5/Z07/Z10, часть — ограничения инструмента.
3. **Release baseline красный:** нет build и ручного прохода; draw calls Лабиринта выше бюджета.
4. Следующий шаг — зарегистрировать дефекты в `BUG_REGISTRY.md`, передать владельцам и повторить затронутые проверки после каждого нового commit.

---

## 12. Evidence

| Артефакт | Путь |
|---|---|
| Import log | `%TEMP%\opencode\stage3_import.log` |
| Full GUT | `%TEMP%\opencode\stage3_gut.log` |
| Resource audit | `%TEMP%\opencode\stage3_resources.log` |
| Boot logs | `%TEMP%\opencode\stage3_boot_*.log` |
| Performance | `%TEMP%\opencode\stage3_perf_*.log` |
| Route | `%TEMP%\opencode\stage3_route_reach.log`, `stage3_route_walk.log` |
| Collision probes | `%TEMP%\opencode\stage3_probe_*.log` |
| Screenshots | `%TEMP%\opencode\stage3_shots\` |
| Export | `%TEMP%\opencode\stage3_export.log` |

---

## 13. Stage 4 integration final

| Проверка | Результат |
|---|---|
| Integration HEAD | `a964d55` (`integrate: use M1 audio profiles for post-nightmare scenes`); equipment alpha `0a593e6`, SQ marker layer `583c3b6` also integrated |
| Merged branches | A04, A01, A06, A05, A07, A08, A03, A02, A09 + equipment alpha |
| Import | exit 0 |
| Full GUT | **683/683 passed, 7676 asserts, 86 scripts, 240.1 s, exit 0** |
| `test_post_nightmare_locations` | 15/15, 516 asserts |
| `test_labyrinth_first_fragment` | 13/13, 334 asserts |
| `test_quest_system` | 9/9, 83 asserts (12-quest catalog) |
| `test_side_quests` | 8/8, 142 asserts |
| `test_combat_ai_integration` | 10/10, 41 asserts |
| `test_equipment_alpha` | 11/11, 46 asserts |
| Manual M1 / tech demo | **NOT TESTED** |
| Export build | **NO_BUILD** (`export_presets.cfg` отсутствует) |

Integration fixes applied: A07 `ArtOverlay` in P05–B02; canonical A01 dialogue paths; P09 Rock/Kasper/Cassia contract; `DemoEndZone`/`FinalZone` test contracts; 5 SQ entries in `quest_catalog.tres`; camp-night dialogue hook; equipment alpha merged. The QA suite is green, but this is **not** a manual playthrough pass.

## 14. Stage 4 playtest (2026-11-03)

Full report: docs/demo_sprint/qa/STAGE4_PLAYTEST.md. Snapshot: HEAD ab8fe30 + dirty working tree. M1 PASS WITH LIMITATIONS; full demo PASS in live harness after Stage 4 fixes (tech demo entry, SQ-01...05); remaining: BUG-032 readability, route walk @10 m/s, clean commit/build.

## 15. Stage 5 integration final (2026-11-03)

| Проверка | Результат |
|---|---|
| Integration HEAD | `8952c64` (Stage 5 code + docs; code commit `9c908f5`) |
| Branches merged | A01–A09 + equipment alpha + `feature/academy-gameplay` + `feature/cutscene-wip-2` + `feature/input-rebind-wip` |
| Boot / parse | `godot --headless --path . --quit` exit 0, 0 script errors |
| Full GUT | **92 scripts / 749 tests / 749 pass / 8 039 asserts / 229.0 s / exit 0** |
| `test_academy_segment` | 5/5, 20 asserts |
| `test_cutscene_integration` | 4/4, 53 asserts |
| `test_ui_demo` | 12/12, 71 asserts |
| `test_player_menu_system` | 7/7, 47 asserts |
| `test_map_system` | 22/22, 836 asserts |
| `test_combat_ai_integration` | 11/11, 46 asserts |
| `test_post_nightmare_locations` | 16/16, 518 asserts |
| `test_labyrinth_first_fragment` | 14/14, 341 asserts |
| `test_game_settings` | 14/14, 82 asserts |
| `test_input_binding_row` | 6/6, 20 asserts |
| Academy probes | gameplay 0 failures; interaction 0; navigation 0; walkthrough 24/24 quests, 0 failures |
| Route reachability | **61/61 POI**, exit 0 |
| Boundary audit | 0 lethal jumps, 2 residual Z10 art ghost cells, 115 floating |
| Manual M1 / tech demo / Academy | **NOT TESTED** |
| 1080p/60 FPS / listening test | **NOT TESTED** |
| Export build | **PASS WITH LIMITATIONS** — temp build `ShadowSlave.exe` 109,268,480 B + `ShadowSlave.pck` 1,000,473,040 B; headless boot exit 0. Includes `tools/**`, `tests/**`, `MCPRuntime`; clean release-only rebuild still required. |

Stage 5 integrated three previously unmerged workstreams: Academy playable segment (2 locations, 24 quests, 23 NPC, 11 loot caches), CutsceneDirector + 5 M1 cutscenes, and shared input rebinding with gamepad defaults. Authored carapace/larva hit/death clips are now registered at runtime. The suite is green, but this is still **not** a manual playthrough pass.
