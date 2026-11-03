# QA & Release — Implementation Specification

**Design Package:** DP-1.0 (Stage 2 → Stage 3 handoff)  
**Дата:** 2026-11-03  
**Автор:** Chat 10 — Independent Lead QA / Release Engineer  
**Базовая точка:** `0335a5c346901af2146413b5a159b442d326d8de`, ветка `s3-park-art`, dirty tree  
**Статус:** **спецификация; игровые файлы не изменялись.** Реализация начинается только после подтверждения `MASTER_PLAN.md`, `FILE_OWNERSHIP.md` и `INTEGRATION_CONTRACTS.md` Technical Director.

---

## 0. Назначение и границы

Этот документ описывает, как построить независимый QA/release-контур для демо Shadow Slave: от замороженного commit до запускаемого Windows build и ручного прохождения.

Главный принцип: **QA не чинит игру, чтобы тест стал зелёным.** QA создаёт доказательства, воспроизводимые проверки и точные дефекты с владельцем. Любая правка игрового файла — через владельца из `FILE_OWNERSHIP.md`.

### 0.1. Что входит в домен

- тесты `tests/**`;
- read-only аудиты и capture-инструменты `tools/audit/**`;
- QA-документы `docs/demo_sprint/qa/**`, `docs/demo_sprint/audits/10_qa_release.md`, `docs/demo_sprint/audits/qa_baseline.md`;
- release-документы `docs/production/**`;
- прогоны, логи, отчёты, release gate;
- проверка build, clean clone, save/load, performance, ручного прохождения.

### 0.2. Что не входит

- исправление игровых сцен, скриптов, ресурсов и ассетов;
- `project.godot`, `export_presets.cfg`, `build/**` — принадлежат A00;
- диалоги, квестовые `.tres`, боевые данные, UI, аудио — принадлежат A01–A09;
- новые autoload, второй state/save/quest/HUD;
- «зелёный» отчёт без фактического прогона.

### 0.3. Критерий успеха домена

Разработчик может запустить **один воспроизводимый gate** и получить:

1. import result;
2. полный GUT result;
3. целевые M1/tech demo результаты;
4. route/POI/quest/save проверки;
5. performance CSV;
6. build и clean-clone результат;
7. 20+ durable screenshot evidence;
8. отчёт PASS / PASS WITH LIMITATIONS / FAIL / NOT VERIFIED, где каждое утверждение имеет лог или запись.

---

## 1. Исходное состояние (факты Stage 2)

| Показатель | Факт | Источник |
|---|---|---|
| Скрипты GDScript | 221 | MASTER_AUDIT |
| Сцены `.tscn` | 126 | MASTER_AUDIT |
| Ресурсы `.tres` | 237 | MASTER_AUDIT |
| Тестовые скрипты | 81 | MASTER_AUDIT / `tests/` |
| Тесты | 634 | MASTER_AUDIT |
| Полный GUT (Stage 2, независимый rerun 2026-11-03 01:35) | **81 скрипт, 636 тестов, 636 pass, 7333 assert, exit 0, 294 с** | `stage2_gut.log` |
| Полный GUT (исторический срез) | 632/632, 7314 assert, exit 0 | MASTER_AUDIT |
| Полный GUT (после N18/N07/N25) | 633/634; транзиентный parse error `caravan_site.tscn` | MASTER_AUDIT |
| Импорт (независимый rerun 2026-11-03 01:36) | exit 0, 0 `ERROR/Parse Error` | `stage2_import.log` |
| Целевой Stage 2 набор | 68/68, 1123 assert, exit 0 | MASTER_AUDIT |
| `test_post_nightmare_locations` | 15/15, 513 assert | MASTER_AUDIT |
| `test_full_route` | 3/3, 220 assert | MASTER_AUDIT |
| `test_appraisal_and_finale` | 9/9, 102 assert | MASTER_AUDIT |
| `test_labyrinth_first_fragment` | 13/13, 332 assert | Stage 2 baseline |
| `export_presets.cfg` | **отсутствует** | `Test-Path` |
| Windows build | **отсутствует** | нет `build/**` |
| MCP editor | **не подключён** после restart | MASTER_AUDIT |
| Ручной проход M1/M4 | **NOT TESTED** | все отчёты |
| Слуховой тест | **NOT TESTED** | A09 |
| 4K/ultrawide/gamepad | **NOT TESTED** | A08/A10 |
| Clean clone | **NOT TESTED** | A10 |
| Durable screenshots | частично; MCP не работает | QA baseline |

**Вывод:** кодовая база богатая, но release-доказательств нет. Основная работа A10 — не «написать ещё тесты», а **сделать результат воспроизводимым, изолированным и привязанным к commit**.

---

## 2. Целевая архитектура QA/release

```text
[TD: freeze commit]
        │
        ▼
[A10 preflight]  git hash + tree hash + versions + export preset check
        │
        ▼
[QA worktree]  отдельный worktree, без editor, без .godot из живого дерева
        │
        ├─ import
        ├─ GUT smoke → GUT target → GUT full
        ├─ contract audit (POI, portals, flags, IDs)
        ├─ M1 route harness
        ├─ quest outcome matrix
        ├─ save/load harness
        ├─ performance suite
        ├─ evidence capture
        ├─ build/export + artifact launch
        └─ clean clone
        │
        ▼
[release evidence]  qa/runs/<run_id>/run.json + logs + manifest + report
        │
        ▼
[A00 M1 gate]  PASS / FAIL / PASS WITH LIMITATIONS
```

### 2.1. Ключевые принципы

1. **Один commit — один run.** Dirty tree не является доказательством.
2. **Один Godot-процесс за раз.** Никаких параллельных GUT/editor/capture.
3. **Отдельный worktree.** QA не работает в живом дереве агентов и не ломает `.godot` cache.
4. **Freeze hash.** Если файлы изменились во время run — run недействителен.
5. **Read-only к игре.** QA не сохраняет сцены, не меняет state вне `user://qa_*`.
6. **Доказательство первично.** Нет лога — нет PASS.
7. **Два gate:** M1 (Z10) и tech demo (Z18). M1 всегда первый.

---

## 3. Что конкретно предстоит реализовать

### 3.1. Исправить существующее

| ID | Проблема | Файлы | Что сделать | Владелец |
|---|---|---|---|---|
| QA-FIX-01 | Полный GUT нестабилен: 632/632 → 633/634 → 620/634 | `tests/**`, class cache, параллельные записи | Ввести freeze + clean worktree + `--import` + один прогон; не считать 633/634 PASS | A10 + A00 |
| QA-FIX-02 | `export_presets.cfg` отсутствует, build нет | `export_presets.cfg`, `build/**` | A00 создаёт preset/build; A10 проверяет артефакт | A00 + A10 |
| QA-FIX-03 | Нет сквозного M1 route-теста | `tools/audit/qa_m1_route.gd` (new) | Прогон P05→Z10 с флагами, порталами, взаимодействиями | A10 |
| QA-FIX-04 | `qa_campaign_tour.gd` — M4-тур, не M1; предупреждение `prologue_completed` | `tools/audit/qa_campaign_tour.gd` | Оставить как M4 regression, не использовать как M1 gate; исправить ложное предупреждение | A10 |
| QA-FIX-05 | `labyrinth_route_walk.gd` 34/51, ложные FAIL от врагов/respawn | `tools/audit/labyrinth_route_walk.gd` | Изолировать state, отключать encounters, различать геометрию/чекпоинт/врага | A10 + A03 |
| QA-FIX-06 | `qa_script_audit.gd` не работает (`ResourceLoader` null) | `tools/audit/qa_script_audit.gd` | Починить или удалить; не оставлять сломанный инструмент | A10 |
| QA-FIX-07 | `qa_capture.gd` снимает одну сцену, нет manifest | `tools/audit/qa_capture.gd` | Добавить batch/flow-режим, manifest, hash | A10 |
| QA-FIX-08 | `qa_resource_audit.gd` проверяет только load, не node path/POI | `tools/audit/qa_resource_audit.gd` | Расширить или добавить `qa_poi_audit.gd` | A10 |
| QA-FIX-09 | `test_quest_system` ждёт 7 квестов; после SQ будет 7+5 | `tests/test_quest_system.gd` | Сделать проверку data-driven (`>=7`, затем 12) по согласованию A02/A04 | A10 |
| QA-FIX-10 | QA-документы расходятся по числам (624/634/632) | `qa/**`, `audits/10_qa_release.md` | Обновить после единственного freeze-run; числа брать из `run.json` | A10 |
| QA-FIX-11 | Нет durable evidence; MCP screenshot не работает | `tools/audit/qa_evidence_capture.gd` (new) | Отдельный оконный capture + manifest + policy хранения | A10 |
| QA-FIX-12 | Нет clean-clone/CI-контура | `tools/audit/qa_clean_clone.ps1` (new) | Локальный clean worktree + import + GUT + build | A10 |
| QA-FIX-13 | Нет live save/load теста | `tools/audit/qa_save_load.gd` (new) | F5/F9, другая сцена, смерть/чекпоинт, temp slot | A10 |
| QA-FIX-14 | Нет performance suite для боя/всех зон | `tools/audit/qa_perf_suite.gd` (new) | 5+ сцен, E01–E03, Z18, CSV | A10 |
| QA-FIX-15 | Нет POI/contract audit | `tools/audit/qa_poi_audit.gd`, `tests/test_qa_contracts.gd` | Сверить manifest ↔ scene nodes ↔ coordinates | A10 + A03/A04 |

### 3.2. Создать новое

| Элемент | Назначение | Файл |
|---|---|---|
| Release gate orchestrator | Один запуск всех проверок, JSON/MD output, exit code | `tools/audit/qa_gate.ps1` |
| Run manifest | Зафиксировать commit, tree hash, версии, stages, PASS/FAIL | `tools/audit/qa_gate.ps1`, `qa/runs/<id>/run.json` |
| M1 route harness | P05→Z10, флаги, порталы, NPC, финал | `tools/audit/qa_m1_route.gd` |
| Tech demo route harness | Z10→Z18, 7 квестов, E01–E03, finale | `tools/audit/qa_tech_demo_route.gd` |
| Quest outcome matrix | 7 базовых + SQ-01…03/04/05, все исходы | `tools/audit/qa_quest_matrix.gd`, `tests/test_quest_outcomes.gd` |
| Save/load harness | F5/F9, другая сцена, death/checkpoint | `tools/audit/qa_save_load.gd` |
| Performance suite | 1080p, 5+ сцен, E01–E03, Z18, CSV | `tools/audit/qa_perf_suite.gd` |
| POI/contract audit | 100+ POI, 13 portals, canonical flags/IDs | `tools/audit/qa_poi_audit.gd` |
| Evidence capture | 20+ кадров, manifest, hash | `tools/audit/qa_evidence_capture.gd` |
| Test isolation | clean `user://qa_*`, state reset, class cache | `tools/audit/qa_clean_state.gd` |
| Clean clone | fresh worktree/clone, LFS, import, GUT, build | `tools/audit/qa_clean_clone.ps1` |
| Build check | preset, export, artifact launch, MCPRuntime check | `tools/audit/qa_build_check.ps1` |
| Release checklist | Runbook для разработчика | `docs/demo_sprint/qa/release_gate_checklist.md` |
| Run template | Формат `qa/runs/<id>/README.md` | `docs/demo_sprint/qa/runs/README.md` |
| M1 acceptance | Чек-лист 10 флагов/13 переходов/4 квестов | `docs/demo_sprint/qa/M1_ACCEPTANCE.md` |
| Defect board | ID, severity, owner, repro, status | `docs/demo_sprint/qa/QA_ISSUES.md` |
| Audio report | Слуховой протокол A09 | `docs/demo_sprint/qa/audio_listening_report.md` |
| Resolution report | 1080p/1440p/4K | `docs/demo_sprint/qa/ui_resolution_report.md` |

---

## 4. Файлы и владение

### 4.1. QA-owned (можно менять в ветке QA)

```text
tests/**
tools/audit/**
docs/demo_sprint/qa/**
docs/demo_sprint/audits/10_qa_release.md
docs/demo_sprint/audits/qa_baseline.md
docs/production/**
```

### 4.2. Read-only (только читать/запускать)

```text
project.godot
export_presets.cfg
build/**
scenes/**
scripts/**
resources/**
assets/**
docs/demo_sprint/design/**
docs/demo_sprint/implementation/**
```

### 4.3. Shared/request-only (меняет A00 или владелец)

| Файл | Владелец | QA-действие |
|---|---|---|
| `project.godot` | A00 | запрос на MCPRuntime/autoload/render settings |
| `export_presets.cfg` | A00 | запрос preset; QA проверяет |
| `build/**` | A00 | QA запускает, не коммитит бинарник |
| `README.md` | A00 | QA передаёт verified numbers |
| `docs/DECISIONS.md` | A00 | QA предлагает запись |
| `tests/test_quest_system.gd` | A10 | правка только по согласованию A02/A04 |
| `tools/audit/labyrinth_route_walk.gd` | A10 (использует A03) | maintenance contract с A03 |

### 4.4. Ресурсы

| Ресурс | Требование | Назначение |
|---|---|---|
| Godot | 4.7.2.stable.official.ed1daf0bf | import, GUT, export, headless |
| GUT | 9.7.1 | тесты |
| Export templates | 4.7.2 Windows x86_64 | build |
| PowerShell | 5.1+ / 7 | gate, clean clone, process control |
| Git / Git LFS | 3.5.1 | worktree, clean clone, 1081 LFS-файл |
| Windows | 10/11 x64 | целевая платформа M1 |
| GPU | RTX 3060 Laptop или эквивалент | performance baseline 1080p |
| RAM/диск | 16 GB RAM; ≥3 GB свободно | project + `.godot` + build |
| Display | 1920×1080; опционально 1440p/4K | UI/perf |
| Audio | headphones/monitors | listening test A09 |
| Screen capture | OBS / Windows Game Bar | manual pass evidence |
| Human QA | 1 QA engineer | runs, reports, defects |
| Human player | 1 (QA or TD) | manual pass; нельзя автоматизировать |
| Build owner | A00 | preset/build/MCPRuntime |
| Freeze window | 60–90 минут без записи в дерево | воспроизводимый run |
| Test data | `poi_manifest.md`, `INTEGRATION_CONTRACTS.md`, `quest_catalog.tres`, `DEMO_FLOW.md` | contracts/acceptance |
| External assets | **не требуются** | QA не импортирует ассеты |

---

## 5. Список задач

> Effort — инженерные часы без ожидания других агентов. Risk — вероятность, что задача не закроется с первого прогона. Все задачи выполняются только после `A00-01` freeze, кроме документации.

### 5.1. M1 release gate (P0)

| Task ID | Description | Files | Dependencies | Priority | Effort | Risk | Acceptance Criteria |
|---|---|---|---|---|---:|---:|---|
| **A10-01** | Freeze + clean full GUT | `qa/runs/<id>/`, `tools/audit/qa_gate.ps1` | A00-01 | P0 | 1.0 h | Medium | tree hash unchanged during run; import exit 0; full GUT 0 fail; log + `run.json` |
| **A10-02** | Build verification | `qa_build_check.ps1`, `qa/runs/<id>/` | A00-02 | P0 | 1.5 h | High | preset exists; 9 release autoloads (10 dev minus MCPRuntime); export exit 0; `build/ShadowSlave.exe` launches; menu→demo→exit; no MCPRuntime; log |
| **A10-03** | M1 route harness | `qa_m1_route.gd`, `tests/test_m1_demo_flow.gd`, run log | A00-06, A03-01…08, A04-01/02/10, A08-01/04 | P0 | 2.5 h | High | P05 cell→P06→P07→P08→P09→B01→B02→Z01–Z10; 10 canonical flags; 4 quests; no soft-lock; manual timing in A10-07 |
| **A10-04** | Live save/load | `qa_save_load.gd`, `qa/runs/<id>/` | A04-08 | P0 | 1.5 h | Medium | F5/F9; save/load in another scene; death/checkpoint; no duplicate rewards; temp slot cleanup |
| **A10-06** | Quest reachability matrix | `qa_quest_matrix.gd`, `tests/test_quest_outcomes.gd` | A02-01…03, A03-09, A04-03 | P0 | 2.0 h | High | 7 base + SQ-01…03 each start/progress/complete/reward once; 32 POI reachable; no soft-lock; snapshot |
| **A10-07** | M1 manual pass | `qa/M1_RUN_<date>.md`, evidence | A10-03, A10-02 | P0 | 2.0 h | Medium | human pass 18–25 min; flags/time/defects; screenshots; not automated |
| **A10-09** | Clean clone gate | `qa_clean_clone.ps1`, run log | A00-02, A10-01 | P0 | 1.5 h | High | fresh worktree/clone; LFS; import 0; GUT 0; build launch |
| **A10-10** | Final QA report | `FINAL_QA_REPORT.md`, `10_qa_release.md` | all P0 | P0 | 1.0 h | Low | PASS/FAIL/NOT VERIFIED for each gate; logs; no false PASS |
| **A10-11** | Release gate orchestrator | `qa_gate.ps1`, `qa/runs/README.md` | A10-01/02 | P0 | 2.5 h | Medium | one command; preflight/import/GUT/target/contracts/route/perf/capture/build; nonzero on P0; JSON/MD |
| **A10-12** | Test isolation | `qa_clean_state.gd`, `qa_gate.ps1` | A10-01 | P0 | 1.0 h | Medium | clears `user://qa_*`; resets autoloads; class cache refresh; 3 consecutive runs same result |
| **A10-14** | POI/contract audit | `qa_poi_audit.gd`, `tests/test_qa_contracts.gd` | A03-09, A04-01 | P0 | 2.0 h | Medium | 100% POI nodes/coords; 13 portals; 10 M1 flags; 7+3 quest IDs; no duplicate IDs |
| **A10-15** | Evidence capture + manifest | `qa_evidence_capture.gd`, `qa/evidence/README.md` | A07-09, A08-04 | P0 | 1.5 h | Low | 20+ M1 frames; manifest with scene/time/hash; reproducible; storage policy |
| **A10-16** | Defect triage board | `QA_ISSUES.md`, `release_gate_checklist.md` | all P0 | P0 | 0.5 h | Low | every FAIL has ID/severity/owner/repro/expectation/status; gate mapping |
| **A10-22** | M1 acceptance checklist | `M1_ACCEPTANCE.md` | all M1 | P0 | 1.0 h | Low | 10 flags/13 transitions/8 scenes/4 quests/cards verified |

### 5.2. Tech demo / quality (P1)

| Task ID | Description | Files | Dependencies | Priority | Effort | Risk | Acceptance Criteria |
|---|---|---|---|---|---:|---:|---|
| **A10-05** | Tech demo route + 7 quests + E01–E03 | `qa_tech_demo_route.gd`, `qa_quest_matrix.gd`, run log | A00-08, A03-10, A05-02/03, A02-01…03 | P1 | 3.5 h | High | Z10→Z18; 7 quests; E01–E03; `post_nightmare_finale`; 50–70 min; no soft-lock |
| **A10-08** | Performance suite | `qa_perf_suite.gd`, CSV | A07-10, A05-02/03 | P1 | 1.5 h | Medium | 5+ scenes, E01–E03, Z18; 1080p ≥60 FPS; draw calls <1500; VRAM <4 GB; CSV |
| **A10-13** | M4 First Nightmare regression | `qa_prologue_tour.gd`, `qa_campaign_tour.gd`, run log | A10-01 | P1 | 2.0 h | Medium | B01–B16; S00–S15; `R`; no regression; captures |
| **A10-17** | Audio listening test | `qa/audio_listening_report.md` | A09-08 | P1 | 1.0 h | Low | 3 scenes; music/ambience/SFX/VO/captions; no clipping; else NOT TESTED |
| **A10-18** | 4K/ultrawide UI | `qa/ui_resolution_report.md`, screenshots | A08-07 | P1 | 1.0 h | Medium | 1920×1080, 2560×1440, 3840×2160; no clipping; HUD readable |
| **A10-19** | Build on clean profile/machine | `qa_build_check.ps1`, run log | A10-02 | P1 | 1.0 h | High | artifact launches without editor; menu→demo; no MCPRuntime; clean user profile |
| **A10-20** | Gate runbook | `release_gate_checklist.md`, `tools/audit/README.md` | A10-11 | P1 | 0.5 h | Low | prerequisites/commands/outputs/ownership documented |
| **A10-21** | SQ-04/SQ-05 outcomes (P2 scope) | `qa_quest_matrix.gd`, run log | A02-04/05, A04-07 | P2 | 2.0 h | High | tide lock/levers; kill/tide/spare; no duplicate reward |
| **A10-23** | Combat performance/soak | `qa_perf_suite.gd`, CSV | A05-02/03, A07-10 | P1 | 2.0 h | High | E01–E03 + Z18; ≥60 FPS; no spike/soft-lock; 10-min soak |
| **A10-24** | Verified numbers/doc sync | `VERIFIED_NUMBERS.md`; request A00/A01 | A10-01/10 | P1 | 0.5 h | Low | README/DECISIONS/route verification match final logs |
| **A10-25** | Credits/licenses build audit | `qa/credits_audit.md` | A09, A00, A10-02 | P1 | 0.5 h | Low | menu credits; `ASSET_LICENSES.md` complete; no unlicensed asset in build |

### 5.3. Mapping на BACKLOG

| A10 | BACKLOG |
|---|---|
| A10-01 | SS-001 |
| A10-02 | SS-002, SS-022 |
| A10-03 | SS-003, SS-025 |
| A10-04 | SS-130 |
| A10-05 | SS-003, SS-013 |
| A10-06 | SS-013 |
| A10-07 | SS-003 |
| A10-08 | SS-070, SS-096 |
| A10-09 | SS-023, SS-075 |
| A10-10 | SS-025 |
| A10-11 | SS-001, SS-075 |
| A10-12 | SS-001 |
| A10-13 | SS-109 |
| A10-14 | SS-010, SS-025 |
| A10-15 | SS-114 |
| A10-16 | SS-025 |
| A10-17 | SS-062 |
| A10-18 | SS-065 |
| A10-19 | SS-022 |
| A10-20 | SS-075 |
| A10-21 | SS-076/077 |
| A10-22 | SS-003 |
| A10-23 | SS-070 |
| A10-24 | SS-069 |
| A10-25 | SS-074 |

---

## 6. Детали ключевых инструментов

### 6.1. `qa_gate.ps1`

Обязательные стадии и exit code:

| Stage | Команда/действие | P0 fail |
|---|---|---|
| preflight | `git rev-parse HEAD`; `git status --porcelain` hash; Godot/GUT versions; preset check | да |
| import | `godot --headless --path . --import` | да |
| gut-smoke | `test_smoke`, `test_main_menu`, `test_game_settings` | да |
| gut-target-m1 | `test_post_nightmare_locations`, `test_campaign_flow`, `test_save_system`, `test_main_menu` | да |
| gut-full | all tests | да |
| contracts | `qa_poi_audit.gd`, `test_qa_contracts.gd`, `qa_quest_matrix.gd` | да |
| m1-route | `qa_m1_route.gd` | да |
| save-load | `qa_save_load.gd` | да |
| perf | `qa_perf_suite.gd` | нет (P1) |
| capture | `qa_evidence_capture.gd` | нет (P1) |
| build | `qa_build_check.ps1` | да (M1) |
| clean-clone | `qa_clean_clone.ps1` | да (M1) |
| report | JSON + Markdown summary | да |

Требования:

- run id: `YYYYMMDD-HHMM_<commit7>`;
- output: `docs/demo_sprint/qa/runs/<run_id>/`;
- `run.json`: commit, tree hash, versions, stage statuses, timings, evidence paths;
- `--skip-build`, `--skip-manual`, `--smoke-only` для локальной работы;
- при изменении tree hash во время run — `INVALID_RUN`, не PASS;
- не запускать параллельно с editor/другим GUT;
- kill stale Godot processes перед стартом (только свои, по PID).

### 6.2. `qa_m1_route.gd`

Проверяет **не телепорты, а порядок и гейты**:

1. `main_menu.start_post_nightmare()` → state preset.
2. P05: spawn в камере; `p05_jett_talked`; зеркало; `p05_mirror_seen`; портал.
3. P06: `jett_advice_heard`; КПП; `p06_completed`.
4. P07: `academy_gate_passed`; `nephis_seen_at_gate`; портал.
5. P08: `dorm_assigned`; портал.
6. P09: `induction_seen`, `kasper_met`, `cassia_seen`, `capsule_entered`, `p09_completed`.
7. B01: `statue_seen`, `shroud_summoned`, `b01_completed`.
8. B02: `b02_completed`.
9. Z01–Z10: `shore_entry`, `first_blood`, `azure_blade`, `camp_rest`, `shore_first_day_complete`, `camp_night_seen`, `post_nightmare_demo_completed`.
10. Финал: карточка «ПЕРВЫЙ ДЕНЬ»; возврат в меню; нет `post_nightmare_completed`.

Каждый шаг — запись `{step, scene, flag, pass, position, time}`. При провале — screenshot + путь + последний flag.

**Важно:** M1 route harness запускается с реальными таймингами и коллизиями, `fast_mode=false`; ускорять можно только реплики, но не порталы/переходы/бой. Иначе тест не поймает soft-lock, который увидит игрок.

### 6.3. `qa_tech_demo_route.gd`

- M1 route + Z11–Z18.
- 7 quests: `first_day`, `first_blood`, `azure_blade`, `crystal_cache`, `hunt_pack`, `camp_rest`, `bridge_stand`.
- E01 (Z03), E02 (Z13), E03 (Z14).
- `post_nightmare_completed`; `post_nightmare_finale`.
- 50–70 min; отдельный отчёт.
- E01–E03 не пропускаются через `fast_mode`: бой, смерть/респавн, HP и kill credit проверяются реально.

### 6.4. `qa_quest_matrix.gd`

Для каждого quest:

- `QuestDefinition` валиден, id уникален, `completion_flag` не пуст;
- objectives имеют корректный `kind/target_id/required`;
- `start_quest` идемпотентен;
- `notify_event` не стартует неактивный quest;
- обязательные objectives завершают quest;
- optional не блокируют;
- reward выдаётся один раз (`reward_claimed`);
- snapshot/restore на каждом этапе;
- SQ-03: 3 выбора, ложь заблокирована, `sq_fs_03_resolved`;
- SQ-05: kill/tide/spare, `sq_fs_05_resolved`;
- нет изменения `first_nightmare_completed`, `temple_reached`, `appraisal_completed`, `CampaignGuide.base_objective`.

### 6.5. `qa_save_load.gd`

- использовать `user://qa_save_<run_id>.bin`;
- save → mutate → load → verify flags/items/quests/currency/memories/checkpoint;
- load in another scene: pending scene + position/rotation;
- death/checkpoint: `FallRecovery` returns to named checkpoint;
- удалить temp save в `finally`;
- не трогать `user://campaign_save.bin` пользователя.

### 6.6. `qa_perf_suite.gd`

Сцены/кадры:

1. `park_street_art` — 1920×1080;
2. prologue player+UI;
3. `labyrinth_first_fragment` entrance;
4. Z10 camp;
5. Z14 bridge;
6. E01/E02/E03 combat;
7. Z18 finale.

Метрики: avg FPS, 1% low (если доступно), draw calls, primitives, objects, VRAM, orphan nodes. CSV + Markdown. Порог: ≥60 FPS, draw <1500, VRAM <4 GB. 4K — P2.

### 6.7. `qa_poi_audit.gd`

- читает `docs/demo_sprint/design/poi_manifest.md`;
- проверяет каждый POI: scene существует, node path существует, координаты ±1 м, `Spawns/Portals` соответствуют contracts;
- проверяет 13 portals, 10 M1 flags, 7+3 quest IDs, отсутствие дублей;
- результат: `poi_audit.json` + список `MISSING/DRIFT/DUPLICATE`;
- не меняет сцены.

### 6.8. `qa_evidence_capture.gd`

- отдельный оконный процесс, не MCP;
- сцена/камера/время/POI/flag в manifest;
- PNG + SHA256;
- 20+ кадров M1: меню, P05 камера/зеркало, P06 Джет, P07 ворота/Нефис, P08 терминал, P09 капсула, B01 статуя/плащ, B02 спуск, Z01, Z03 бой, Z08 встреча, Z10 финал;
- tech demo: Z11, Z13, Z14, Z15, Z17, Z18, finale;
- при LFS-политике — A00 решает, куда коммитить binary.

### 6.9. Build contract (A00 + A10)

A00 создаёт `export_presets.cfg`; QA не пишет preset в общий файл. Минимальные требования:

| Параметр | Значение |
|---|---|
| Preset name | `Windows Desktop` (совпадает с командой QA) |
| Platform | Windows Desktop x86_64 |
| Export path | `build/ShadowSlave.exe` |
| Build type | Release |
| PCK | embed или отдельный `.pck`; зафиксировать в отчёте |
| Export filter | all resources, но без `tests/**`, `tools/**`, `docs/**`, `experiments/**`, `incoming_models/**` |
| MCP addon | исключён; `MCPRuntime` отсутствует в release autoload |
| GUT | исключён |
| Rendering | `[rendering]` P5 settings сохранены |
| Product/version | `ShadowSlave Demo`, версия из `project.godot` |
| Console wrapper | выключен для release |
| Templates | Godot 4.7.2 Windows x86_64 установлены |

QA проверяет:

1. `export_presets.cfg` существует и содержит preset `Windows Desktop`;
2. `godot --headless --path . --export-release "Windows Desktop" <path>` → exit 0;
3. артефакт запускается без editor;
4. в build нет `MCPRuntime`, `tests/`, `tools/`;
5. меню → «После Кошмара» → P05 → выход;
6. лог экспорта и скриншот меню приложены.

**Спорный момент:** как именно A00 исключает `MCPRuntime` из release (release-копия `project.godot`, отдельная ветка, feature-tag guard или post-export patch) — решение TD; QA только проверяет результат.

---

## 7. Зависимости и интеграция

### 7.1. Матрица зависимостей

| A10 | Зависит от | Что получает | Что отдаёт |
|---|---|---|---|
| A10-01 | A00-01 | freeze commit/tree hash | clean GUT log |
| A10-02 | A00-02 | preset/build path | build launch log |
| A10-03 | A03-01…08, A04-01/02/10, A08-01/04 | scene nodes, flags, cards | M1 route result |
| A10-04 | A04-08 | save/load contract | live save result |
| A10-05 | A00-08, A03-10, A05-02/03, A02-01…03 | Z11–Z18, combat, SQ | tech demo result |
| A10-06 | A02-01…03, A03-09, A04-03 | SQ data, POI, scope | quest matrix |
| A10-07 | A10-03, A10-02 | build + route | manual pass |
| A10-08 | A07-10, A05-02/03 | optimized scenes | CSV |
| A10-09 | A00-02, A10-01 | build + commit | clean clone |
| A10-11 | A10-01/02 | scripts | gate run |
| A10-12 | A10-01 | clean state | repeatable runs |
| A10-14 | A03-09, A04-01 | POI/contracts | audit |
| A10-15 | A07-09, A08-04 | art/UI states | screenshots |
| A10-17 | A09-08 | audio protocol | listening report |
| A10-18 | A08-07 | UI scaling | resolution report |
| A10-19 | A10-02 | build | clean-machine result |
| A10-21 | A02-04/05, A04-07 | SQ-04/05 | outcome matrix |
| A10-23 | A05-02/03, A07-10 | combat/perf | soak CSV |

### 7.2. Что QA запрашивает у других

- **A00:** freeze commit, export preset, build path, clean worktree, MCPRuntime release exclusion, decision on binary evidence.
- **A01:** canonical speaker IDs/display names, dialogue sequence paths, flags.
- **A02:** SQ `.tres` paths, objective mapping, outcome flags, 32 POI.
- **A03:** final POI manifest, G1–G5 fixes, `DemoEndZone`/`FinalZone`, portal/spawn contract, route-walk maintenance.
- **A04:** canonical flags, scope isolation, save/load API, M1 final logic, map flags.
- **A05:** E01–E03 spawn/HP data, kill credit tags, respawn behavior.
- **A06:** placeholder marking, animation clips, LOD/performance stats.
- **A07:** capture angles, lighting/readability acceptance, perf budget.
- **A08:** HUD/card state, resolution support, map flags UI.
- **A09:** cue list, captions, listening protocol, VO status.

### 7.3. Что QA не делает

- не правит `scenes/**`, `scripts/**`, `resources/**`, `assets/**`;
- не «подгоняет» тест под баг без владельца;
- не добавляет autoload/второй state/save/quest;
- не выдаёт `PASS` по чужому отчёту;
- не коммитит build binary.

---

## 8. Риски и конфликты

| ID | Риск | Влияние | Мitigation |
|---|---|---|---|
| QA-R01 | Параллельная запись во время GUT | transient parse errors, ложный FAIL | freeze hash, worktree, abort on change |
| QA-R02 | Class cache stale | ложные parse errors | `--import` + clean cache, verify script count |
| QA-R03 | Нет commit для теста (dirty tree) | run невоспроизводим | A00 creates freeze commit; otherwise `PASS WITH LIMITATIONS` not PASS |
| QA-R04 | MCP editor disconnected | no live screenshots | use `qa_evidence_capture.gd`; MCP optional |
| QA-R05 | Export templates missing/mismatch | build blocked | A00 preflight; QA checks `export_presets.cfg` + templates |
| QA-R06 | MCPRuntime in release | dev dependency leaks | build inspect + A00 removal |
| QA-R07 | Test count drift | docs/report stale | numbers from `run.json`, not hardcoded |
| QA-R08 | `user://` save collision | tests overwrite user save | unique temp slot, cleanup, never default path |
| QA-R09 | Manual pass not performed | M1 FAIL | gate requires human; no auto-substitute |
| QA-R10 | tech demo 50–70 min | time sink | M1 first; tech demo separate P1 gate |
| QA-R11 | `labyrinth_route_walk` false positives | wrong defect reports | disable encounters/reset state, classify fail |
| QA-R12 | LFS missing in clean worktree | import/test fail | `git lfs pull`; verify pointer files |
| QA-R13 | Binary evidence LFS conflict | repo bloat/ownership | TD policy; prefer external + manifest |
| QA-R14 | QA test changes conflict with A05/A06 | merge conflicts | A10 owns tests but claims; coordinate test additions |
| QA-R15 | Scope creep: QA tries to fix game | ownership violation | defect handoff only |

---

## 9. Проверка готовности каждого элемента

| Элемент | Метод | PASS | Evidence |
|---|---|---|---|
| Import | `godot --headless --path . --import` | exit 0; no `ERROR/Parse Error` | `import.log` |
| Full GUT | GUT `-gdir=res://tests -gexit` | scripts >0; tests >0; 0 fail; exit 0 | `gut_full.log`, `run.json` |
| M1 route | `qa_m1_route.gd` | all steps; 10 flags; no soft-lock | `m1_route.json` + screenshots |
| Tech demo | `qa_tech_demo_route.gd` | Z10→Z18; 7 quests; E01–E03; finale | JSON + captures |
| Quests | `qa_quest_matrix.gd` | 7+3 (or 7+5) complete; rewards once; no main flags | `quest_matrix.json` |
| POI | `qa_poi_audit.gd` | 100% nodes/coords; no duplicates | `poi_audit.json` |
| Save/load | `qa_save_load.gd` | round-trip; other scene; death; no dup | `save_load.json` |
| Performance | `qa_perf_suite.gd` | ≥60 FPS; draw <1500; VRAM <4 GB | `perf.csv` |
| Build | `qa_build_check.ps1` | export 0; artifact launch; no MCPRuntime | `build.log` + screenshot |
| Clean clone | `qa_clean_clone.ps1` | import 0; GUT 0; build launch | `clean_clone.log` |
| UI | `qa_evidence_capture.gd` + manual | 1080p/1440p/4K; no clipping | `ui_resolution_report.md` |
| Audio | A09 protocol + QA | 3 scenes; cues/captions; no clipping | `audio_listening_report.md` |
| Evidence | `qa_evidence_capture.gd` | 20+ frames; manifest/hash | `manifest.json` |
| Docs | manual comparison | numbers match `run.json`; no false PASS | `VERIFIED_NUMBERS.md` |

---

## 10. Ветка, worktree, freeze

### 10.1. Рекомендуемая схема

```text
integration branch: s3-park-art (TD)
        │
        ├── commit/tag: stage3-m1-freeze
        │   (only with user approval; otherwise byte-level snapshot + tree hash)
        │
        └── QA worktree: ../shadowslave-qa
                branch: qa/a10-release-gate
                only: tests/**, tools/audit/**, docs/demo_sprint/qa/**
```

### 10.2. Почему так

- QA не редактирует игровые файлы;
- отдельный `.godot` исключает class-cache race;
- отдельный worktree позволяет запускать GUT без editor/других агентов;
- QA branch можно переносить на новый freeze commit без merge конфликтов;
- build/preset changes остаются у A00.

### 10.3. Freeze protocol

1. A00 объявляет freeze: commit hash + `git status --porcelain` hash.
2. QA запускает `qa_gate.ps1`; в начале и конце сравнивает tree hash.
3. Если hash изменился — `INVALID_RUN`, не PASS; повтор после нового freeze.
4. Если freeze commit нет — используется byte-level snapshot (копия рабочего дерева + SHA256 манифеста); результат получает `PASS WITH LIMITATIONS` с явной пометкой «dirty tree».
5. После run A00 снимает freeze; QA не держит блокировку дольше 60–90 минут.
6. Коммит/tag создаётся только с разрешения пользователя (D-27); QA не коммитит и не делает push.

### 10.4. Коммиты

Согласно `FILE_OWNERSHIP.md`, специалисты не коммитят. QA готовит изменения в worktree; A00 коммитит после review. QA не делает push.

---

## 11. Трудоёмкость и порядок

### 11.1. Реальная оценка

| Пакет | Задачи | Инженерные часы | Комментарий |
|---|---|---:|---|
| M1 gate | A10-01…04, 06, 07, 09, 10, 11, 12, 14, 15, 16, 22 | **18–22 h** | После freeze; включает 2–3 повторных прогона |
| Tech demo | A10-05, 08, 13, 17, 18, 19, 20, 23 | **10–13 h** | После M1 PASS |
| Release/full | A10-21, 24, 25, clean clone, docs | **4–6 h** | Windows-only baseline |
| **Итого** | | **32–41 h** | Без ожидания чужих правок |

Для 3-часового окна реалистично только:

- A10-01 freeze + full GUT (1 h);
- A10-03 M1 route (2.5 h) — при готовых сценах;
- A10-07 manual pass (2 h) — не помещается одновременно.

Поэтому **M1 QA нельзя честно закрыть за 3 часа**; нужен отдельный QA-день или готовая инфраструктура из A10-11/12/14/15.

### 11.2. Порядок

```text
W0  A00 freeze + A10-11/12 infrastructure
W1  A10-01, A10-02, A10-14
W2  A10-03, A10-04, A10-06
W3  A10-07 manual, A10-09 clean clone, A10-10 report
W4  A00 M1 gate
W5  A10-05 tech demo, A10-08/23 perf
W6  A10-13 M4, A10-17/18 quality
W7  A10-19/24 release
```

---

## 12. Открытые вопросы для Technical Director

| ID | Вопрос | Варианты | Почему важно |
|---|---|---|---|
| QA-Q01 | Какой commit считать freeze? | commit / tag / dirty snapshot | без него нет воспроизводимого PASS |
| QA-Q02 | Кто создаёт `export_presets.cfg` и где build? | A00 only / A00+A10 | FILE_OWNERSHIP: A00 |
| QA-Q03 | Есть ли export templates 4.7.2? | yes / install | build blocker |
| QA-Q04 | Где хранить binary evidence? | `docs/demo_sprint/qa/evidence` + LFS / external `user://` / `docs/art/previews` | repo size/ownership |
| QA-Q05 | Кто выполняет ручной M1 pass? | A10 / TD / user | A10 не может «сыграть» без человека |
| QA-Q06 | Кто выполняет listening test? | A09 / user / A10 records | D-13 требует |
| QA-Q07 | `test_quest_system` 7 → 12: когда? | after SQ data / now | test count drift |
| QA-Q08 | SQ scope в tech demo | SQ-01…03 / +04/05 | effort/risk |
| QA-Q09 | `labyrinth_route_walk.gd` owner | A10 maintain / A03 maintain | shared tool |
| QA-Q10 | MCPRuntime release exclusion | build flag / project copy | build verification |
| QA-Q11 | Clean clone: local LFS fetch allowed? | yes / offline copy | no remote push, but fetch may be network |
| QA-Q12 | 4K/ultrawide scope | P1 / P2 | effort |
| QA-Q13 | Один слот save или 3 | D-21: 1 | test matrix |
| QA-Q14 | M1 manual pass до или после build? | build first / editor first | gate order |
| QA-Q15 | Кто обновляет README/DECISIONS числа? | A00/A01 / A10 supplies | doc ownership |
| QA-Q16 | Кто добавляет тесты A05/A06/A08 при A10-владении `tests/**`? | A10 writes / author writes + A10 review | merge conflicts |
| QA-Q17 | Как проверять отсутствие MCPRuntime в build? | `project.godot` release copy / pck scan / runtime flag | build contract |

---

## 13. Definition of Done домена

### 13.1. M1 QA done

- [ ] A00 freeze commit; tree hash stable.
- [ ] import exit 0.
- [ ] full GUT 0 fail, log + run.json.
- [ ] M1 route P05→Z10: all flags, 4 quests, no soft-lock.
- [ ] M1 manual pass recorded, 18–25 min.
- [ ] save/load F5/F9 live.
- [ ] POI/contract audit 100%.
- [ ] build/export + artifact launch.
- [ ] clean clone/import/GUT/build.
- [ ] 20+ evidence screenshots + manifest.
- [ ] QA report with PASS/FAIL/NOT VERIFIED.
- [ ] no false PASS; all blockers have owner.

### 13.2. Tech demo QA done

- [ ] M1 done.
- [ ] Z10→Z18 route.
- [ ] 7 base quests + SQ-01…03 (or declared scope).
- [ ] E01–E03.
- [ ] `post_nightmare_finale`.
- [ ] performance 1080p/60 in combat/all zones.
- [ ] tech demo manual pass 50–70 min.
- [ ] audio listening report.
- [ ] 4K/ultrawide or explicit NOT TESTED.
- [ ] separate QA report.

### 13.3. Release QA done

- [ ] clean machine build.
- [ ] no MCPRuntime.
- [ ] credits/licenses.
- [ ] localization decision.
- [ ] platform decision.
- [ ] full manual pass.
- [ ] final release report.

---

## 14. Handoff checklist

Перед передачей TD:

- [ ] `qa_release_implementation.md` создан (этот файл).
- [ ] `TEST_PLAN.md` обновлён под M1/tech demo.
- [ ] `QA_ISSUES.md` содержит все известные блокеры.
- [ ] `FINAL_QA_REPORT.md` не выдаёт старые 624/634 за финал.
- [ ] нет изменений игровых файлов.
- [ ] список open questions передан TD.
- [ ] QA branch/worktree plan согласован.
- [ ] first gate run назначен после freeze.

---

## 15. Ссылки

- `docs/demo_sprint/MASTER_AUDIT.md`
- `docs/demo_sprint/MASTER_PLAN.md`
- `docs/demo_sprint/BACKLOG.md`
- `docs/demo_sprint/DEMO_FLOW.md`
- `docs/demo_sprint/DECISIONS.md`
- `docs/demo_sprint/FILE_OWNERSHIP.md`
- `docs/demo_sprint/implementation/AGENT_TASKS.md`
- `docs/demo_sprint/implementation/INTEGRATION_CONTRACTS.md`
- `docs/demo_sprint/design/side_quests.md`
- `docs/demo_sprint/design/world_layout.md`
- `docs/demo_sprint/design/poi_manifest.md`
- `docs/demo_sprint/design/level_implementation_plan.md`
- `docs/demo_sprint/qa/TEST_PLAN.md`
- `docs/demo_sprint/qa/QA_ISSUES.md`
- `docs/demo_sprint/qa/FINAL_QA_REPORT.md`
