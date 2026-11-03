# Владение файлами и защита от конфликтов

Дата: 2026-11-02  
Статус: рабочий контракт на время демо-спринта.  
Принцип: **один файл — один владелец**. Совместные файлы меняются только через Technical Director.

## 1. Почему это обязательно

Все чаты работают в одном рабочем дереве `C:\Users\user\Desktop\shadowslave` на ветке `s3-park-art`. Во время снятия baseline параллельный чат уже записал `scripts/quests/*`, изменения `NightmareRunState` и материалы Лабиринта. Без распределения файлов десять направлений перезапишут друг друга.

## 2. Матрица владения

### 2.1. Эксклюзивные зоны

| Владелец | Пути | Что можно | Что нельзя |
|---|---|---|---|
| **01 Narrative** | `docs/story/**`, `docs/design/first_nightmare_*` (только текст/канон), `resources/dialogue/**`, `resources/spell/**`, `data/dialogues/**` | тексты, последовательности, флаги-предложения | менять сцены, `NightmareRunState`, боевые ресурсы |
| **02 Side Quest** | `docs/design/side_quest*`, `docs/demo_sprint/design/side_quest*`, `scripts/quests/**`, `resources/quests/**` | концепты, typed-ресурсы квестов, квестовые обёртки | трогать `NightmareRunState`, `CampaignGuide`, UI без согласования с 04/08 |
| **03 World & Level** | `scenes/locations/**`, `scripts/locations/**`, `resources/locations/**`, `scenes/campaign/**` (геометрия/спавны), `tools/map/**` | спавны, порталы, коллизии, композиция, level-скрипты | менять art-ассеты, `project.godot`, общие autoload |
| **04 Gameplay & Quest Systems** | `scripts/campaign/**`, `scripts/systems/**`, `scripts/interaction/**`, `scripts/inspect/**`, `scripts/guide/**`, `scripts/map/**`, `resources/campaign/**`, `resources/map/**` | state, beat, guide, interactions, inventory logic | менять UI-темы, боевые формулы, сцены локаций |
| **05 Combat & Enemy AI** | `scripts/combat/**`, `scripts/enemies/**`, `scenes/enemies/**`, `scenes/characters/mountain_king.tscn`, `resources/combat/**`, `resources/enemies/**`, `tests/test_*combat*`, `tests/test_*enemy*` | AI, урон, HUD-контракт, арены, боевые тесты | менять `SunnyController`/аниматор без 06; менять канонические сцены без 03 |
| **06 Character & Animation** | `assets/characters/**`, `scenes/characters/**` (кроме `mountain_king.tscn`), `scripts/player/**`, `scripts/slice/mannequin.gd`, `resources/characters/**`, `resources/animation/**` | модели, rig, клипы, LOD, socket, animator | генерировать новых персонажей; менять боевые данные без 05 |
| **07 Environment Art** | `assets/environments/**`, `scenes/environment/**`, `resources/environments/**`, `resources/locations/**/materials/**`, `docs/art/**` | арт, материалы, свет, LOD, превью | менять `scenes/locations/**` без 03; импортировать без лицензии |
| **08 UI/UX** | `scenes/ui/**`, `scripts/ui/**`, `assets/ui/**`, `resources/rpg_menu/**`, `resources/campaign/glossary/**` | меню, HUD, субтитры, карта-UI, темы | менять игровые данные и state |
| **09 Audio & VFX** | `assets/audio/**`, `scripts/audio/**`, `resources/audio/**`, `scenes/environment/*vfx*`, `scenes/environment/p*_*`, `docs/audio/**` | шины, cue, музыка, SFX, VO, VFX-сцены | менять микшер `default_bus_layout.tres` без TD; импортировать внешний звук без лицензии |
| **10 QA & Release** | `tests/**`, `tools/audit/**`, `docs/demo_sprint/qa/**`, `docs/production/**` | тесты, аудиты, чек-листы, release gate | менять игровые файлы «чтобы тест прошёл» без владельца |

### 2.3. M1: пост-Кошмарная цепочка

| Зона | Владелец | Пути |
|---|---|---|
| Участок | 03 + 07 | `scenes/locations/post_nightmare/police_precinct.tscn`, `scripts/locations/post_nightmare/police_precinct.gd` |
| Академия (подход/ворота/кампус) | 03 + 07 | `academy_approach`, `academy_gate`, `academy_campus` |
| Sleeper Center | 01 + 03 + 08 | `academy_sleeper_center`, диалоги, UI |
| Чёрное море | 03 + 07 | `black_sea_platform`, `statue_knight_lod`, материалы |
| Спуск | 03 + 07 | `tide_descent` |
| Лабиринт | 03 + 04 + 07 | `labyrinth_first_fragment`, `labyrinth_quest_director`, `labyrinth_art` |
| Старый лабиринт | 03 | `coral_labyrinth` — только по решению TD |
| Вход/финал | 01 + 08 + TD | `main_menu`, `finale`, `campaign_entry` |

### 2.2. Общие файлы — только через TD

| Файл | Почему общий |
|---|---|
| `project.godot` | autoload, main scene, input map, rendering |
| `opencode.json`, `.mcp.json` | MCP-конфигурация |
| `.gitattributes`, `.gitignore` | LFS и правила репозитория |
| `README.md` | общее описание проекта |
| `docs/DECISIONS.md` | архитектурные решения |
| `docs/ASSET_LICENSES.md` | лицензии |
| `docs/demo_sprint/README.md`, `BASELINE.md`, `EXPECTED_REPORTS.md`, `OWNERSHIP.md` | процесс |
| `docs/demo_sprint/design/00_DEMO_SCOPE_AND_CONTRACT.md` | единый контракт |
| `docs/demo_sprint/design/01_INTEGRATION_PLAN.md` | порядок интеграции |
| `docs/demo_sprint/implementation/ACTIVE_CLAIMS.md` | реестр активных правок |
| `scripts/campaign/nightmare_run_state.gd` | общее состояние кампании |
| `scripts/guide/campaign_guide.gd` | общая цель/журнал |
| `scripts/world/level_portal.gd` | общий контракт переходов |
| `scripts/ui/rpg_menu/rpg_menu_theme.gd` | общая тема UI |
| `scripts/audio/audio_director.gd` | общий аудио-контракт |
| `default_bus_layout.tres` | общий микшер |
| `scenes/ui/main_menu/main_menu.tscn` | точка входа |
| `scenes/campaign/campaign_entry.tscn` | точка входа кампании |
| `scenes/campaign/finale_arrival.tscn` | финальный гейт |

Для изменения общего файла нужно:

1. написать в `docs/demo_sprint/implementation/ACTIVE_CLAIMS.md` строку: кто, какой файл, зачем, до какого времени;
2. получить подтверждение TD (запись в том же файле);
3. не держать правку дольше согласованного окна;
4. после правки запустить целевой тест и записать результат.

## 3. Правила веток и коммитов

- Все работают в `s3-park-art`; отдельные ветки не создаются без TD.
- Специалисты **не коммитят** и **не push**. Коммиты делает TD после интеграции.
- Незакоммиченные чужие изменения не удаляются, не форматируются и не «чинятся» массово.
- Перед началом правки — `git status --short` и проверка `ACTIVE_CLAIMS.md`.
- Если файл уже изменён другим чатом — не перезаписывать; согласовать через TD.

## 4. Приоритет конфликтов

1. **Канон и сюжет** (01) — выше удобства кода.
2. **Проходимость и отсутствие soft-lock** (03/10) — выше визуальной полировки.
3. **Контракты состояния** (04) — выше локальных удобств.
4. **Визуал/звук** (07/09) — ниже проходимости, но выше «красоты ради красоты».
5. **Оптимизация** — только после стабильного кадра и зелёных тестов.

## 5. Запрещённые действия

- Массовый `gofmt`/переформат чужих файлов.
- Удаление сцен, скриптов, ресурсов и ассетов без подтверждения пользователя.
- Переименование общих классов и autoload без TD.
- Добавление новых MCP-серверов, плагинов, внешних ассетов и генераций без решения пользователя.
- Правка `project.godot` «по пути».
- Коммит секретов, `.env`, абсолютных путей в общих конфигах.
- Запись в `docs/demo_sprint/audits/` чужих отчётов «за автора».

## 6. Аварийная остановка

Если обнаружен конфликт или сломанный общий контракт:

1. остановить правки в затронутой зоне;
2. записать инцидент в `docs/demo_sprint/implementation/ACTIVE_CLAIMS.md` (секция `INCIDENTS`);
3. уведомить TD через отчёт/файл;
4. не «чинить» чужую зону самостоятельно.

## 7. Текущие активные зоны (на 20:10)

| Зона | Кто | Файлы |
|---|---|---|
| Quest framework | Chat 02/04 (параллельная работа) | `scripts/quests/**`, `scripts/campaign/nightmare_run_state.gd`, `scripts/guide/campaign_guide.gd` |
| Labyrinth materials | Chat 07 (вероятно) | `resources/locations/forgotten_shore_labyrinth/**` |
| Документы demo_sprint | Chat 00 | `docs/demo_sprint/**` |

Перед правкой любой из этих зон — проверить `ACTIVE_CLAIMS.md` и текущий `git status`.
