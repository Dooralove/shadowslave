# FILE OWNERSHIP — Shadow Slave / Design Package DP-1.0

**Дата:** 2026-11-03  
**Статус:** обязательный контракт Stage 3. Заменяет `docs/demo_sprint/OWNERSHIP.md` как рабочий источник владения.  
**Принцип:** **один файл — один владелец**. Совместные файлы меняются только через Technical Director (A00).  
**Базовая точка:** commit `75f1423d536ae63b073f59bb897d13f052cdbe8a`, branch `demo/integration`, clean tree кроме unstaged `opencode.json`.

---

## 1. Зачем это нужно

В одном рабочем дереве работают 10 направлений. Во время Stage 2 параллельные чаты уже записали `scripts/quests/*`, изменения `NightmareRunState` и материалы Лабиринта. Без file-level ownership следующая волна снова перезапишет чужие изменения и создаст «почти зелёные» тесты.

Правила:

1. Перед правкой — `git status --short` и `docs/demo_sprint/implementation/ACTIVE_CLAIMS.md`.
2. Файл, который уже правит другой агент, не перезаписывается. Нужен claim и подтверждение TD.
3. Агент не «чинит» чужую зону, даже если видит ошибку. Он пишет отчёт и задачу владельцу.
4. Коммиты и push делает только TD; специалисты не коммитят.
5. Удаление сцен, скриптов, ресурсов и ассетов — только с подтверждением пользователя.

---

## 2. Матрица владения

| Agent | Owned Files/Directories | Allowed Changes | Forbidden Changes | Dependencies |
|---|---|---|---|---|
| **A00 — Technical Director / Integration** | `project.godot`; `opencode.json`; `.mcp.json`; `.gitattributes`; `.gitignore`; `export_presets.cfg`; `build/**`; `README.md`; `docs/DECISIONS.md`; `docs/ASSET_LICENSES.md`; `docs/demo_sprint/MASTER_PLAN.md`; `docs/demo_sprint/FILE_OWNERSHIP.md`; `docs/demo_sprint/DEMO_FLOW.md`; `docs/demo_sprint/DECISIONS.md`; `docs/demo_sprint/MASTER_AUDIT.md`; `docs/demo_sprint/BACKLOG.md`; `docs/demo_sprint/BASELINE.md`; `docs/demo_sprint/EXPECTED_REPORTS.md`; `docs/demo_sprint/README.md`; `docs/demo_sprint/implementation/AGENT_TASKS.md`; `docs/demo_sprint/implementation/INTEGRATION_CONTRACTS.md`; `docs/demo_sprint/implementation/ACTIVE_CLAIMS.md`; `docs/demo_sprint/design/00_DEMO_SCOPE_AND_CONTRACT.md`; `addons/**` | Менять autoload/настройки проекта; утверждать ID и контракты; вести merge; создавать export preset/build; обновлять процессные документы; разрешать shared-file claims | Менять игровые сцены, скрипты, ресурсы и ассеты, принадлежащие A01–A10; переписывать дизайн-документы «за автора»; коммитить без указания пользователя | Все агенты; пользователь для D-01…D-30 и удаления ассетов |
| **A01 — Narrative & Story** | `docs/story/**`; `docs/design/first_nightmare_*` (только текст/канон); `docs/demo_sprint/design/narrative_design.md`; `docs/demo_sprint/audits/01_narrative_story.md`; `docs/demo_sprint/audits/narrative.md`; `resources/dialogue/**`; `data/dialogues/**`; `resources/spell/**` (только тексты/сообщения) | Писать диалоги, narration, barks, тексты карточек; предлагать флаги и speaker ID; править канон-текст | Менять сцены, `NightmareRunState`, квестовые `.tres`, боевые данные, UI-разметку, `scripts/dialogue/**` (A04) | A03 — размещение NPC/триггеров; A04 — флаги/state; A08 — субтитры/карточки |
| **A02 — Side Quest & Content** | `docs/demo_sprint/design/side_quests.md`; `docs/demo_sprint/audits/quests.md`; `resources/quests/sq_fs_*.tres`; `scripts/locations/forgotten_shore_labyrinth/labyrinth_narrative_director.gd` (new, carve-out) | Создавать 5 SQ `.tres`; писать SQ runtime director; задавать objectives/rewards/flags; готовить SQ-01…03 для M3 | Менять `scripts/quests/**` (A04), `resources/quests/quest_catalog.tres` (A04), `labyrinth_quest_director.gd` (A03), сцены (A03), диалоги (A01), UI (A08) | A01 — текст; A03 — точки/сцены; A04 — QuestSystem/каталог; A05 — энкаунтеры; A08 — choice UI |
| **A03 — World & Level** | `scenes/locations/**`; `scripts/locations/**` **кроме** `labyrinth_narrative_director.gd` (A02), `labyrinth_art.gd` (A07), `labyrinth_audio.gd` (A09); `resources/locations/**` **кроме** `**/materials/**` (A07); `resources/map/locations/**`; `tools/map/**`; `docs/demo_sprint/design/world_layout.md`; `docs/demo_sprint/design/poi_manifest.md`; `docs/demo_sprint/design/level_implementation_plan.md`; `docs/demo_sprint/audits/03_world_level_design.md`; `docs/demo_sprint/audits/level_design.md` | Сцены, спавны, порталы, коллизии, POI, route-геометрия, level-скрипты, map locations, G1–G5, `DemoEndZone`/`FinalZone` | Менять `project.godot`; art-ассеты и материалы (A07); `scripts/campaign/**`, `scripts/quests/**`, `resources/quests/**` (A04/A02); диалоги (A01); боевые формулы (A05) | A04 — state/portal; A07 — art/materials; A01 — тексты; A05 — враги; A09 — audio/VFX |
| **A04 — Gameplay & Quest Systems** | `scripts/campaign/**`; `scripts/systems/**`; `scripts/dialogue/**`; `scripts/interaction/**`; `scripts/inspect/**`; `scripts/guide/**`; `scripts/map/**`; `scripts/quests/**`; `scripts/world/**`; `resources/campaign/**`; `resources/map/**` **кроме** `resources/map/locations/**` (A03); `resources/quests/quest_catalog.tres`; `resources/quests/first_day.tres`; `resources/quests/first_blood.tres`; `resources/quests/azure_blade.tres`; `resources/quests/crystal_cache.tres`; `resources/quests/hunt_pack.tres`; `resources/quests/camp_rest.tres`; `resources/quests/bridge_stand.tres`; `resources/inspect/**`; `scenes/campaign/**`; `scenes/quests/**`; `scenes/guide/**`; `docs/demo_sprint/design/gameplay_architecture.md`; `docs/demo_sprint/audits/04_gameplay_quest_systems.md`; `docs/demo_sprint/audits/gameplay_systems.md` | State, QuestSystem, save, portal logic, interactables, map logic, inspect, guide, canonical flags, M1 finale logic | Менять UI-сцены/скрипты (A08), локации (A03), диалоговые данные `resources/dialogue/**` (A01), бой (A05), персонажей (A06), аудио (A09) | A00 — project; A01 — dialogue data; A03 — nodes/POI; A05 — kill events; A08 — UI; A09 — audio |
| **A05 — Combat & Enemy AI** | `scripts/combat/**`; `scenes/enemies/**`; `scenes/characters/mountain_king.tscn`; `resources/combat/**`; `resources/enemies/**`; `docs/demo_sprint/design/combat_encounters.md`; `docs/demo_sprint/audits/05_combat_enemy_ai.md`; `docs/demo_sprint/audits/combat_ai.md` | Боевые профили, AI, hurtbox, weak spot, групповой бой, E01–E03, Mountain King combat | Менять `scripts/player/**`/animator (A06); сцены локаций (A03); HUD-разметку (A08); quest data (A04); модели/анимации (A06) | A06 — animator/клипы; A03 — spawn points; A08 — HUD; A04 — kill credit; A10 — тесты |
| **A06 — Character & Animation** | `assets/characters/**`; `assets/animations/**`; `scenes/characters/**` **кроме** `mountain_king.tscn` (A05); `scripts/player/**`; `scripts/slice/mannequin.gd`; `resources/characters/**`; `tools/anim/**`; `docs/art/character_animation_pipeline_audit.md`; `docs/art/enemy_model_audit_2026-11-02.md`; `docs/demo_sprint/audits/characters_animation.md` | Модели, rig, weights, клипы, LOD, sockets, animator, player controller/animator, NPC placeholders | Менять боевые формулы/данные (A05); сцены локаций (A03); UI (A08); квесты (A04); аудио (A09) | A05 — тайминги боя; A03 — размещение; A07 — материалы окружения; A10 — performance |
| **A07 — Environment Art** | `assets/environments/**`; `assets/shaders/**`; `scenes/environment/**` **кроме** `scenes/environment/vfx/**` (A09); `resources/locations/**/materials/**`; `scripts/locations/forgotten_shore_labyrinth/labyrinth_art.gd`; `tools/art/**`; `docs/art/**` **кроме** `character_animation_pipeline_audit.md` и `enemy_model_audit_2026-11-02.md` (A06); `docs/demo_sprint/design/environment_art_direction.md`; `docs/demo_sprint/audits/07_environment_art.md`; `docs/demo_sprint/audits/environment_art.md` | Арт окружения, PBR-материалы, свет, decals, LOD, композиция, captures | Менять `scenes/locations/**` без A03; gameplay-скрипты; character assets; audio; импортировать внешние ассеты без лицензии | A03 — геометрия; A09 — VFX; A06 — персонажи; A00 — лицензии |
| **A08 — UI/UX** | `scenes/ui/**`; `scripts/ui/**`; `assets/ui/**`; `resources/ui/**`; `resources/rpg_menu/**`; `resources/campaign/glossary/**`; `docs/demo_sprint/design/ui_ux_design.md`; `docs/demo_sprint/audits/ui_ux.md` | HUD, меню, субтитры, карта-UI, темы, `QuestChoicePanel` UI, финальные карточки, pause/settings | Менять state/quest data (A04); сцены локаций (A03); диалоговые тексты (A01); аудио (A09) | A04 — данные; A03 — anchors; A01 — тексты; A09 — UI-звук |
| **A09 — Audio & VFX** | `assets/audio/**`; `scripts/audio/**`; `scripts/vfx/**`; `scripts/locations/forgotten_shore_labyrinth/labyrinth_audio.gd`; `resources/audio/**`; `scenes/environment/vfx/**`; `default_bus_layout.tres`; `docs/audio/**`; `docs/demo_sprint/design/audio_vfx_design.md`; `docs/demo_sprint/audits/09_audio_vfx.md`; `docs/demo_sprint/audits/audio_vfx.md` | Шины, cue, музыка, SFX, VO, VFX-сцены/скрипты, captions audio | Менять `default_bus_layout.tres` без A00; environment scenes (A07); gameplay (A04); UI-разметку (A08) | A07 — окружение; A08 — UI hooks; A00 — лицензии; A10 — listening |
| **A10 — QA & Release** | `tests/**`; `tools/audit/**`; `docs/demo_sprint/qa/**`; `docs/production/**`; `docs/demo_sprint/audits/10_qa_release.md`; `docs/demo_sprint/audits/qa_baseline.md` | Писать/запускать тесты, route/boundary/perf-аудиты, QA-отчёты, clean clone, build verification | Менять игровые файлы «чтобы тест прошёл» без владельца; `project.godot`; удалять ассеты; писать PASS без лога | Все; A00 — build; A03 — route; A04 — state; A05 — combat |

---

## 3. Общие файлы — только через A00

| Файл | Почему общий | Кто может просить |
|---|---|---|
| `project.godot` | autoload, main scene, input map, rendering | все, но меняет только A00 |
| `export_presets.cfg` | build | A00, A10 |
| `opencode.json`, `.mcp.json` | MCP-конфигурация | A00 |
| `.gitattributes`, `.gitignore` | LFS/репозиторий | A00 |
| `README.md` | общее описание | A00 |
| `docs/DECISIONS.md` | архитектурные решения | A00 |
| `docs/ASSET_LICENSES.md` | лицензии | A00/A07/A09 |
| `resources/quests/quest_catalog.tres` | единый каталог | A04; A02 просит добавить SQ |
| `scenes/locations/**` | геометрия/спавны/порталы | A03; A01/A05/A07/A09 просят |
| `scenes/campaign/**` | вход/финал | A04; A08/A01 просят |
| `scenes/ui/main_menu/**` | точка входа | A08; A00 утверждает main scene |
| `scripts/campaign/nightmare_run_state.gd` | общее состояние | A04 |
| `scripts/guide/campaign_guide.gd` | общая цель/журнал | A04 |
| `scripts/world/level_portal.gd` | общий контракт переходов | A04 |
| `scripts/systems/save_system.gd` | сохранение | A04 |
| `scripts/audio/audio_director.gd` | общий аудио-контракт | A09 |
| `default_bus_layout.tres` | общий микшер | A09; A00 утверждает |
| `scenes/characters/sunny.tscn` | игрок | A06 |
| `scenes/characters/mountain_king.tscn` | босс | A05; A06 дает модель |
| `scenes/environment/**` | окружение | A07; A09 только `vfx/**` |
| `resources/dialogue/**` | все диалоги | A01; A02 просит SQ-тексты |
| `resources/locations/**` | локации | A03; A07 только `materials/**` |
| `resources/map/**` | карта | A04; A03 только `locations/**` |

**Протокол shared-file:**

1. Записать в `docs/demo_sprint/implementation/ACTIVE_CLAIMS.md`: агент, файл, зачем, до какого времени.
2. Получить подтверждение A00 в том же файле.
3. Не держать claim дольше согласованного окна.
4. После правки — targeted test и запись результата.
5. Если файл уже изменён другим агентом — не перезаписывать.

---

## 4. Независимые зоны разработки

| Зона | Владелец сцены/скрипта | Контент | Интегратор | Запрещено одновременно |
|---|---|---|---|---|
| **P05–P09: город и академия** | A03 | A01, A06, A08, A09 | A04 | A01/A06/A08/A09 не правят `.tscn`/`scripts/locations/post_nightmare/**` |
| **B01–B02: Чёрное море и спуск** | A03 | A07, A09, A04 | A04 | A07/A09 не правят `black_sea_platform.tscn`/`tide_descent.tscn` |
| **B03 Z01–Z10: M1 Лабиринт** | A03 | A02, A05, A06, A07, A09 | A04 | A02/A05/A06/A07/A09 не правят `labyrinth_first_fragment.tscn` и `labyrinth_first_fragment.gd` |
| **Z11–Z18: tech demo** | A03 | A02, A05, A07, A09 | A04 | не начинать до M1 gate |
| **Quest framework** | A04 | A02 | A00 | A02 не правит `scripts/quests/**`; A04 не правит SQ `.tres` |
| **UI/HUD** | A08 | A04, A01 | A00 | A04/A01 не правят `scenes/ui/**` |
| **Character pipeline** | A06 | A05 | A00 | A05 не правит `assets/characters/**` |
| **Environment art** | A07 | A03 | A00 | A03 не правит `assets/environments/**`/`materials/**` |
| **Audio/VFX** | A09 | A07 | A00 | A07 не правит `scenes/environment/vfx/**` |
| **QA/release** | A10 | A00 | A00 | A10 не правит игровые файлы ради теста |

**Правило пересечения зон:** если задача требует правки двух зон, она разбивается на две задачи с явными зависимостями; один агент не делает обе правки в одном окне.

---

## 5. Исключения и carve-outs

| Файл | Владелец | Исключение |
|---|---|---|
| `scripts/locations/forgotten_shore_labyrinth/labyrinth_narrative_director.gd` | A02 | новый файл; A03 не редактирует его, но предоставляет точки/маркеры |
| `scripts/locations/forgotten_shore_labyrinth/labyrinth_art.gd` | A07 | A03 не меняет арт-слой |
| `scripts/locations/forgotten_shore_labyrinth/labyrinth_audio.gd` | A09 | A03 не меняет аудио-слой |
| `scenes/characters/mountain_king.tscn` | A05 | A06 поставляет модель/анимации, но сцену собирает A05 |
| `scenes/ui/main_menu/**` | A08 | A00 только утверждает main scene в `project.godot` |
| `resources/quests/quest_catalog.tres` | A04 | A02 присылает entries; A04 добавляет |
| `resources/map/locations/labyrinth_first_fragment.tres` | A03 | A02 присылает SQ-маркеры; A03 добавляет |
| `resources/dialogue/labyrinth/sq_fs_*` | A01 | A02 пишет черновик; A01 утверждает и коммитит текст |

---

## 6. Приоритет конфликтов

1. **Канон и сюжет** (A01) — выше удобства кода.
2. **Проходимость и отсутствие soft-lock** (A03/A10) — выше визуальной полировки.
3. **Контракты состояния и ID** (A04/A00) — выше локальных удобств.
4. **Визуал/звук** (A07/A09) — ниже проходимости, но выше «красоты ради красоты».
5. **Оптимизация** — только после стабильного кадра и зелёных тестов.

---

## 7. Запрещённые действия

- Массовый reformat чужих файлов.
- Удаление сцен, скриптов, ресурсов и ассетов без подтверждения пользователя.
- Переименование общих классов/autoload без A00.
- Новые MCP-серверы, плагины, внешние ассеты и генерации без решения пользователя.
- Правка `project.godot` «по пути».
- Коммит секретов, `.env`, абсолютных путей в общих конфигах.
- Запись в `docs/demo_sprint/audits/` чужих отчётов «за автора».
- Одновременная правка общей сцены или общего скрипта двумя агентами.

---

## 8. Аварийная остановка

Если обнаружен конфликт или сломанный общий контракт:

1. Остановить правки в затронутой зоне.
2. Записать инцидент в `docs/demo_sprint/implementation/ACTIVE_CLAIMS.md` (секция `INCIDENTS`).
3. Уведомить A00 через отчёт/файл.
4. Не «чинить» чужую зону самостоятельно.
5. После решения A00 — обновить claim и продолжить.

---

## 9. Document control

| Поле | Значение |
|---|---|
| Design Package | `DP-1.0` |
| Base commit | `75f1423d536ae63b073f59bb897d13f052cdbe8a` |
| Branch | `demo/integration` |
| Working tree | clean, кроме unstaged `opencode.json`; baseline commit создан |
| Supersedes | `docs/demo_sprint/OWNERSHIP.md` (historical draft) |
| Companion docs | `MASTER_PLAN.md`, `docs/demo_sprint/implementation/AGENT_TASKS.md`, `docs/demo_sprint/implementation/INTEGRATION_CONTRACTS.md` |

**Конец FILE_OWNERSHIP.**
