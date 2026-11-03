# MASTER AUDIT — Shadow Slave

Дата консолидации: 2026-11-03  
Автор: Chat 00 — Technical Director / Integration Lead  
Ветка: `s3-park-art`  
HEAD: `0335a5c346901af2146413b5a159b442d326d8de`  
Рабочее дерево: **574 записи** `git status` (185 modified, 389 untracked); дерево живое, параллельные чаты продолжают писать.  
Статус: **аудит завершён для текущего снимка; release-аудит — нет.** Полный ручной проход, экспортная сборка и слуховой тест отсутствуют.

> Этот документ — не сумма отчётов. Каждое существенное утверждение сверено с кодом, сценами, ресурсами или фактическим прогоном. Там, где проверка не выполнялась, стоит **NOT TESTED**.

> **Stage 5 update (2026-11-03):** часть строк ниже устарела. Уже интегрированы: Academy playable segment (2 локации, 24 квеста), CutsceneDirector + 5 M1-катсцен, input rebind + gamepad defaults, authored carapace/larva hit/death clips. Full GUT **748/748, 8 035 asserts, exit 0**; temp release export boot exit 0. Строки «MISSING gamepad/rebind», «кат-сцен нет» и «Academy не в меню» читать как закрытые. Актуальный снимок — `docs/demo_sprint/qa/BASELINE_RESULTS.md` §15.

---

## 0. Исполнительный вердикт

1. **Проект живой и технически богатый, но не release-ready.** Есть 81 тестовый скрипт, 634 теста, 221 GDScript, 126 сцен, 237 `.tres`, 819 МБ ассетов, работающие бой, квесты, сохранения, HUD, пауза, аудио и арт. При этом нет экспортной сборки, нет непрерывного ручного прохода и нет стабильного «замороженного» состояния дерева.
2. **Демо-маршрут, выбранный пользователем, — пост-Кошмарная цепочка:** `main_menu → police_precinct → academy_approach → academy_gate → academy_campus → academy_sleeper_center → black_sea_platform → tide_descent → labyrinth_first_fragment → post_nightmare_finale`. Он связан порталами, получил вход из меню, HUD целей, NPC/диалоги, финальную карточку и базовый аудио-слой.
3. **Первый Кошмар S00–S15 остаётся второй, уже собранной аркой.** В ней закрыты N07 (Bloodbane), N18 (личинка Шифти) и N25 (деяния личинок); но полный ручной проход по-прежнему **NOT TESTED**.
4. **Лабиринт — не «готовая локация», а tech demo с сильным арт-слоем.** 18 зон, коралловый кит, прилив, 7 квестов-каркасов, Нефис/Кассия, карапаксы; при этом 5 подтверждённых геометрических дефектов, 28 «призрачных полов», 3238 смертельных краёв и отсутствие полного ручного прохода.
5. **Главный блокер — не отсутствие кода, а доказательство и стабильность.** Полный GUT в живом дереве колеблется между 632/632 и 633/634 из-за параллельных записей, class-cache и незавершённых ассетов. Это не «зелёный релиз».
6. **Главный производственный блокер — модели.** Каст существует, но P1 Nightmare Sunny, Hero, Shifty, Scholar, Veteran, BroadSlave, Mountain King и Carapace — не финального качества. Hyper3D web UI выбран пользователем, но массовая генерация ещё не выполнена.
7. **Главный контентный блокер — сюжет после Лабиринта.** Acts C–D (утёсы, Кость-Хребет, Пепельная пустошь, Древо Души) и западный город (замок Гунлауга, собор, Чёрный Рыцарь) не начаты.
8. **Главный процессный блокер — конфликт scope.** Отчёты 03 и UI/UX писались под Первый Кошмар/Лабиринт, 02 — под Лабиринт, а решение пользователя — пост-Кошмарная цепочка. Консолидация фиксирует новую иерархию: M1 — цепочка, M2 — академия, M3 — Лабиринт, M4 — Первый Кошмар, M5–M6 — поздний сюжет, M7 — релиз.

---

## 1. Входные данные и полнота

### 1.1. Прочитанные отчёты

| # | Отчёт | Полная версия | Статус |
|---:|---|---|---|
| 00 | `audits/00_TECHNICAL_DIRECTOR_GLOBAL_AUDIT.md` | — | принят |
| 01 | `audits/01_narrative_story.md` | `audits/narrative.md` | принят |
| 02 | `audits/quests.md` | `design/side_quests.md` | принят как эквивалент `02_side_quest_design.md` |
| 03 | `audits/03_world_level_design.md` | `audits/level_design.md` | принят |
| 04 | `audits/04_gameplay_quest_systems.md` | `audits/gameplay_systems.md` | принят |
| 05 | `audits/05_combat_enemy_ai.md` | `audits/combat_ai.md` | принят |
| 06 | `audits/characters_animation.md` | — | принят как эквивалент `06_character_animation.md` |
| 07 | `audits/07_environment_art.md` | `audits/environment_art.md` | принят |
| 08 | `audits/ui_ux.md` | `design/ui_ux_design.md` | принят как эквивалент `08_ui_ux.md` |
| 09 | `audits/09_audio_vfx.md` | `audits/audio_vfx.md` | принят |
| 10 | `audits/10_qa_release.md` | `audits/qa_baseline.md`, `qa/*` | принят |

### 1.2. Проверки, выполненные при консолидации

| Проверка | Результат |
|---|---|
| `godot --headless --path . --import` | exit 0 |
| Полный GUT (стабильный срез) | 632/632, 7314 assert, exit 0 (до N18) |
| Полный GUT (после N18/N07/N25, живое дерево) | 633/634; единственное падение — транзиентный parse error `caravan_site.tscn` во время параллельной записи |
| Целевой набор Stage 2 | 9 скриптов, 68 тестов, 68 pass, 1123 assert, exit 0 |
| `test_post_nightmare_locations` | 15/15, 513 assert |
| `test_pilgrim_path` | 10/10, 260 assert |
| `test_full_route` | 3/3, 220 assert |
| `test_appraisal_and_finale` | 9/9, 102 assert |
| `test_quest_system` + `test_labyrinth_quest_content` + `test_save_system` + `test_ui_demo` | в составе 68/68 |
| `export_presets.cfg` | **отсутствует** |
| MCP editor | **не подключён** после перезапуска Godot |

### 1.3. Чего в аудите нет

- Непрерывного ручного прохода ни по одной цепочке.
- Экспортированного билда.
- Слухового теста.
- 4K/ultrawide, геймпада, переназначения клавиш.
- Свежего клона с нуля.
- Термического/VRAM-соака.
- Полного контента Acts C–D и западного города.

---

## 2. Реальное состояние систем

### 2.1. Движок и инструменты

| Компонент | Факт | Статус |
|---|---|---|
| Godot | 4.7.2.stable.official.ed1daf0bf | работает |
| GUT | 9.7.1 | работает |
| Blender | 5.1.1, addon 1.8 / protocol 15 | работает |
| Godot MCP | 0.6.1, editor не подключён после перезапуска | **BLOCKED для live** |
| Blender MCP | Sketchfab и Hyper3D включены; Poly Haven/Poly Pizza выключены | drift от AGENTS |
| Hyper3D | web UI выбран пользователем; API Creator недоступен | **внешняя зависимость** |
| Экспорт | `export_presets.cfg` нет | **BLOCKED** |

### 2.2. Проект, импорт, тесты

- 81 тестовый скрипт, 634 теста, 7314+ asserts.
- 126 `.tscn`, 221 `.gd`, 237 `.tres`, 819 МБ ассетов, 1081 LFS-файл.
- `project.godot` содержит 10 autoload: `MCPRuntime`, `NightmareRunState`, `DialogueManager`, `MapSystem`, `PlayerMenuSystem`, `PauseMenuSystem`, `CampaignGuide`, `QuestSystem`, `SaveSystem`, `AudioDirector`.
- `[rendering]` восстановлен: S3TC/BPTC, occlusion culling, mesh LOD threshold 1.5.
- Class cache нестабилен при параллельной записи: лечится удалением `.godot/global_script_class_cache.cfg` + `--import`.
- Полный GUT зависит от порядка/состояния дерева; в живом дереве возможны ложные падения.

**Вердикт:** техническая база пригодна, но требует freeze и одного чистого прогона.

### 2.3. Первый Кошмар S00–S15

| Область | Факт | Статус |
|---|---|---|
| Маршрут | `campaign_entry → prologue → first_nightmare_pass → caravan_site → pilgrim_path → sanctuary → appraisal → finale` | READY по коду |
| Пролог | B01–B16, art-локации, HUD, диалоги | READY по коду; ручной проход NOT TESTED |
| Стоянка | N07 Bloodbane исправлен, N08–N13, второй личинка, повозка, ветеран, Silver Bell | READY по коду |
| Тропа | N14–N17, N18 личинка Шифти, N19 гейт, N20–N23 | READY по коду; бой N18 NOT TESTED вручную |
| Святилище | N24, алтарь, Тиран, тени | READY по коду |
| Оценка | N25, две личинки считаются | READY по коду |
| Финал | N26, карточка, `R`, кнопка «Продолжить» | READY по коду |
| Ручной проход | — | **NOT TESTED** |
| Визуал | альков/пещера тёмные, тени-руки | PARTIAL |
| Документация | README/route verification устарели | STALE |

### 2.4. Пост-Кошмарная цепочка M1/M2

| Сцена | Факт | Статус |
|---|---|---|
| `main_menu` | кнопка «После Кошмара», пресет состояния, `transition_enabled` для тестов | READY |
| `police_precinct` | дежурный, офицер допросной, пробуждение, зеркало, выход | READY (placeholders) |
| `academy_approach` | Джет, диалог, КПП, охрана | READY (placeholders) |
| `academy_gate` | охрана, проверка, портал в кампус после проверки | READY |
| `academy_campus` | проводник, диалог | READY (placeholders) |
| `academy_sleeper_center` | медик, Джулиус, капсула, портал в Чёрное море | READY |
| `black_sea_platform` | статуя, звёзды, меч, спуск, портал после осмотра | READY |
| `tide_descent` | предупреждение о приливе, портал в Лабиринт | READY |
| `labyrinth_first_fragment` | вход, 18 зон, прилив, квесты, NPC, бой | PARTIAL |
| `post_nightmare_finale` | финальная карточка, возврат в меню | READY |
| Ручной проход | — | **NOT TESTED** |
| NPC/модели | `Mannequin`-плейсхолдеры | PARTIAL |
| Контент | мало сюжетных сцен, нет индукционного зала/Hollow | PARTIAL |

### 2.5. Forgotten Shore Labyrinth M3

| Область | Факт | Статус |
|---|---|---|
| Геометрия | 18 зон, ~1.5 км, 907 мешей, ~4.95 млн tris | PARTIAL |
| Маршруты | 36/51 сегментов; 5 подтверждённых дефектов G1–G5 | **FAIL** |
| Коллизии | 3238 смертельных краёв, 28 ghost floor, 1 смертельный прыжок | **FAIL** |
| Прилив | 120-секундный прототип, 8 шлюзов; нет 16-мин цикла, утопления, штормового сценария | PARTIAL |
| Арт | коралловый кит, статуя, кости, вода, дождь, небо; 123.8 FPS, 857 MB VRAM, 1593 draw calls | READY/PARTIAL |
| NPC | Нефис/Кассия — QuestNpc; Тео — только дизайн | PARTIAL |
| Бой | 1 карапакс Z03, 3 Z13, 2 Z14; баланс и групповой бой NOT TESTED | PARTIAL |
| Квесты | 7 каркасов; 5 нарративных SQ-FS не реализованы | PARTIAL |
| Карта | схема зон, маркеры; `MapScreen` flags-баг | PARTIAL |
| Ручной проход | — | **NOT TESTED** |

### 2.6. Soul Sea / Memories

| Область | Факт | Статус |
|---|---|---|
| Soul Sea | сцена, HUD, 63 GLB, модальный контроллер в `combat_arena` | tech demo |
| В кампании | входа нет | **MISSING** |
| Memories | реестр в `NightmareRunState`, но каталога/слотов/наград нет | PARTIAL |
| Инвентарь | `InventoryPrototype` + `RpgDemoSession`, не связан с state | **DEMO ONLY** |

### 2.7. Бой и враги

| Область | Факт | Статус |
|---|---|---|
| Игрок | удар, блок, уклонение, i-frames, выносливость | READY |
| Враг | `TestEnemy`, `LarvaEnemy`, `CarapaceEnemy`, `MountainKing` | READY |
| Контакт | `contact_time` выровнен по клипам; карапакс 0.40, Mountain King 0.35/0.20 | READY |
| Встречи | Z03/Z13/Z14; второй личинка на стоянке; Mountain King — cinematic | PARTIAL |
| Групповой бой | 3 карапакса Z13, 2 Z14 — не проверены | NOT TESTED |
| Weak spot | `Inspectable`, не отдельный hurtbox/множитель | PARTIAL |
| HUD | HP/выносливость, полоса врага | READY |
| Баланс | 95 HP × 3 при 12 уроне — 24 удара; Azure Blade не в боевом режиме | PARTIAL |
| Звук/VFX | cue и hit/death VFX есть; слуховой тест нет | PARTIAL |

### 2.8. Персонажи и анимации

| Ассет | Факт | Статус |
|---|---|---|
| Sunny v3 | 84 175 tri, 52 bones, 2K PBR, 10 native clips, AnimationTree | лучший герой |
| Sunny Nightmare P1 | 48 518 tri, 53 bones, UAL, 3 LOD, визуально слабый | PARTIAL |
| Hero v6 | 90 000 tri, 52 bones, 7 native clips | PARTIAL (нет LOD) |
| P1 каст | 47–65k tri, double-sided, без tangents | PARTIAL |
| Mountain King p3 | 75 643 tri, без UV/текстур | **fallback** |
| Carapace generated | 120 000 tri, 38 bones, 5 clips | PARTIAL (нет LOD) |
| Larva | 49 508 tri, 3 LOD, PBR | READY |
| Horse v2 | 23.5 MB GLB, импортирован | PARTIAL |
| Nephis/Cassia | манекены-плейсхолдеры | **MISSING models** |
| Kai/Effie/Gunlaug/Black Knight/Great Devil | нет | **MISSING** |

### 2.9. Environment art

| Область | Факт | Статус |
|---|---|---|
| Лабиринт | коралловый кит, статуя, кости, вода, дождь, небо, свет | READY для Z01–Z14/Z16–Z17 |
| Z15/Z18 | плоские платформы, не скальные полки | PARTIAL |
| Z02/Z13 | модульные туша/скелет, не hero | PARTIAL |
| Decals | крови/когтей/водорослей/ракушек нет | MISSING |
| Производительность | 123.8 FPS, 857 MB VRAM, 1593 draw calls | READY/PARTIAL |
| S00–S15 | P2–P5 арт, тёмные места | PARTIAL |
| Soul Sea kit | 63 GLB, не интегрирован в кампанию | PARTIAL |

### 2.10. UI/UX

| Область | Факт | Статус |
|---|---|---|
| HUD | `GameplayHud`: цель, prompt, субтитры, бой, тост, прилив | READY |
| Меню | главное меню, настройки, кредиты, пауза | READY |
| Журнал | live QuestSystem → CampaignGuide → DEMO fallback | READY/PARTIAL |
| Карта | схема зон, маркеры; flags-баг | PARTIAL |
| Инвентарь | DEMO, не связан с state | **DEMO ONLY** |
| Памяти | черновик | **MISSING** |
| Диалоги | субтитры, счётчик, клик; выбора нет | PARTIAL |
| Масштабирование | 1920×1080, canvas_items; 4K/ultrawide NOT TESTED | PARTIAL |
| Геймпад/rebind | нет | **MISSING** |

### 2.11. Audio/VFX

| Область | Факт | Статус |
|---|---|---|
| Шины | Master/Music/Ambience/SFX/Voice/UI/Reverb, limiter | READY |
| Музыка | 14 cue, 3 слоя, storm | READY |
| SFX | 61 cue, бой, подборы, NPC, костёр, прилив | READY |
| Ambience | 29 зон | READY |
| VO | SAPI-плейсхолдеры, 83 реплики без файлов | PARTIAL |
| VFX | дождь, молнии, брызги, пыль, смерть карапакса | READY |
| Слуховой тест | — | **NOT TESTED** |
| Окклюзия/reverb | базовые, без динамики | PARTIAL |

### 2.12. Квесты

| Область | Факт | Статус |
|---|---|---|
| Framework | `QuestSystem`, 7 `.tres`, 7 типов целей, награды, журнал, tracking | READY |
| 7 каркасов | `first_day`, `first_blood`, `azure_blade`, `crystal_cache`, `hunt_pack`, `camp_rest`, `bridge_stand` | PARTIAL (каркас) |
| 5 нарративных SQ-FS | дизайн, не реализованы | **MISSING** |
| Мировые адаптеры | `QuestPickup`, `QuestNpc`, `QuestTriggerZone`, `CheckpointZone`, `QuestKillCredit` | READY |
| Чего нет | `start_quest_id`, `QuestInspectable`, `QuestChoicePanel`, `QuestTideLock`, `advance_to_low` | **MISSING** |
| Карта | 5 маркеров, `hide_when_flag`; `MapScreen` flags-баг | PARTIAL |
| Награды | item/currency/memory/flag/heal, идемпотентны | READY |

### 2.13. Состояние и сохранения

| Область | Факт | Статус |
|---|---|---|
| `NightmareRunState` | flags, items, bestiary, quests, currency, memories, checkpoint, snapshot/restore | READY |
| `SaveSystem` | `user://campaign_save.bin`, F5/F9, автосейв на чекпоинтах/квестах | READY (unit) |
| Живой F5/F9 | — | **NOT TESTED** |
| Слоты/список/миграции | нет | **MISSING** |
| Инвентарь | DEMO, не связан | **DEMO ONLY** |

### 2.14. Переходы и сцены

| Область | Факт | Статус |
|---|---|---|
| `LevelPortal` | fade, spawn, gates, one-shot, cutscene | READY |
| Кампания | 7 оболочек, 18 шагов | READY по коду |
| Пост-Кошмар | 8 сцен, 13 порталов | READY по коду |
| Лабиринт | `ToDescent`/`ToWest`; ToWest ведёт в финальную карточку | READY |
| Прямой запуск | поздние сцены имеют гейты/редиректы | READY |
| Ручной проход | — | **NOT TESTED** |

### 2.15. Производительность

| Сцена | FPS / draw calls / VRAM | Статус |
|---|---|---|
| Парк | 162 FPS / 253 / 1.07 GB | READY |
| Пролог с игроком/UI | 152 FPS / 718 / 1.08 GB | READY |
| Лабиринт-вход | 142 FPS / 1299 / 796 MB | READY |
| Лабиринт art | 123.8 FPS / 1593 / 857 MB | PARTIAL (draw calls >1500) |
| Бой/все зоны | — | **NOT TESTED** |

### 2.16. Release/export

| Область | Факт | Статус |
|---|---|---|
| `export_presets.cfg` | нет | **BLOCKED** |
| Windows build | нет | **BLOCKED** |
| Артефакт запускается | — | **NOT TESTED** |
| CI/clean clone | нет | **MISSING** |
| MCPRuntime в релизе | autoload | **TODO** |

---

## 3. Критические баги

| ID | Баг | Доказательство | Влияние | Владелец |
|---|---|---|---|---|
| BUG-001 | Полный GUT нестабилен в живом дереве | 632/632 → 633/634 → 620/634 в разных прогонах; transient parse errors | нельзя заявить готовность | 10 + TD |
| BUG-002 | Нет `export_presets.cfg` и сборки | `Test-Path export_presets.cfg` = False; `--export-release` fail | нет демонстрируемого билда | TD + 10 |
| BUG-003 | Нет непрерывного ручного прохода | QA baseline, все отчёты | проходимость не доказана | 10 |
| BUG-004 | Лабиринт: Z04 запечатан | `labyrinth_first_fragment.gd:219-240` | низкий маршрут не работает | 03 |
| BUG-005 | Лабиринт: западная лестница Z11 утоплена | `:429-440` | низкий маршрут — тупик | 03 |
| BUG-006 | Лабиринт: устье Z08→Z09 перекрыто | `:352-354`, `:365-400` | прямой вход читается как стена | 03 |
| BUG-007 | Лабиринт: 2-м разрыв Z05→Z06 | `:280`, `:288-300` | Тео/квесты требуют прыжка | 03 |
| BUG-008 | Лабиринт: тесный угол Z03→Z05 | `:211`, `:256-282` | новичок может не найти путь | 03 |
| BUG-009 | 28 ghost floor, 3238 deadly edges | `boundary_audit` | падения и недоверие к геометрии | 03/07 |
| BUG-010 | `MapScreen` передаёт `{}` вместо флагов | quests report, map tests | маркеры не скрываются | 08/04 |
| BUG-011 | Нет `start_quest_id` у pickup/NPC/trigger | quests report | часть квестов автостартует | 04 |
| BUG-012 | Нет `QuestChoicePanel`/`QuestTideLock`/`QuestInspectable` | quests report | SQ-03/SQ-04 невозможны | 04/02 |
| BUG-013 | Weak spot — только `Inspectable`, не hurtbox-множитель | combat report | «слабое место» не влияет на урон | 05 |
| BUG-014 | Враги сохраняют урон после смерти игрока | combat report | баланс/респавн | 03/04/05 |
| BUG-015 | Sunny P1 Nightmare визуально слабый | characters report | главный герой не демо-уровня | 06 |
| BUG-016 | Нет LOD у v3/Hero/Carapace/Mountain King | characters report | 84–120k tri в кадре | 06 |
| BUG-017 | Draw calls Лабиринта 1593 > 1500 | environment report | риск просадки | 07 |
| BUG-018 | 83 реплики без VO, SAPI — плейсхолдер | audio report | не финальный звук | 09 |
| BUG-019 | Инвентарь/Памяти — DEMO, не связаны со state | gameplay/UI reports | награды не видны | 04/08 |
| BUG-020 | Нет экспортного/CI-контура | QA report | нельзя выпустить | TD/10 |
| BUG-021 | `MCPRuntime` остаётся autoload | project.godot | лишний runtime в релизе | TD |
| BUG-022 | Документация устарела по числам/сценам | README, route verification, AI_HANDOFF | ложные ожидания | 01/10/TD |
| BUG-023 | Пост-Кошмарные NPC — `Mannequin`-плейсхолдеры | our M2 pass | визуал не финальный | 06 |
| BUG-024 | Нет индукционного зала/Hollow/массовки | 03/01 | академия неполная | 03/07 |
| BUG-025 | Нет Acts C–D и западного города | research docs | сюжет не завершён | 03/01 |
| BUG-026 | `white_horse_v2` invalid UID/parse error | QA/UI reports; GLB импортирован позже | лошадь/кавалькада может не грузиться | 06 + 10 |
| BUG-027 | `caravan_site.tscn` transient missing path | полный GUT 633/634 | ложное падение теста | 03 |
| BUG-028 | Autoload churn (`QuestSystem`/`SaveSystem`/`PauseMenuSystem`) | `project.godot` менялся параллельно | порядок загрузки/дубли | TD |

---

## 4. Недостающие элементы

### 4.1. Контент

- Индукционный зал, Hollow, общежитие, столовая, додзё, библиотека, медцентр — как играбельные сцены.
- Тео, Эхо-полип, альфа-карапакс, Центурион, Сколопендра, Worm Knot, Blood Flower — модели/встречи.
- SQ-FS-01…05 — пять нарративных заданий.
- Штормовой сценарий, 16-минутный прилив, утопление, tide lock.
- Acts C–D: утёсы, Кость-Хребет, Пепельная пустошь, Древо Души, Великий Дьявол.
- Западный город: стена, замок Гунлауга, собор, Чёрный Рыцарь.
- Soul Sea в кампании, Memories, экономика, расходники.
- Финальная карта Лабиринта и маркеры квестов.

### 4.2. Модели

- Jet, Julius, Theo, Nephis, Cassia, Kai, Effie, Gunlaug, Black Knight, Great Devil, Sleepers, массовка академии.
- Carapace Centurion, Centipede, Worm Knot, Blood Flower, Echo.
- Финальные Sunny Nightmare, Hero, Shifty, Scholar, Veteran, BroadSlave, Mountain King.
- LOD1/2 для v3/Hero/Carapace/Mountain King.

### 4.3. Системы/UI

- `QuestChoicePanel`, `QuestTideLock`, `QuestInspectable`, `advance_to_low`.
- Реальный инвентарь/Памяти/экономика.
- Слоты сохранений с UI.
- Геймпад, rebind, локализация, accessibility.
- Экспортный preset/build/CI.

### 4.4. Доказательства

- Непрерывный ручной проход.
- Скриншоты/видео ключевых сцен.
- Слуховой тест.
- 1080p/60 в бою, 4K/ultrawide, минимальное железо.
- Чистый клон.

---

## 5. Конфликты документации и реализации

| # | Документ | Утверждение | Факт | Решение |
|---:|---|---|---|---|
| 1 | `README.md` | 35 scripts / 255 tests | 81 / 634 | обновить README |
| 2 | `README.md` | звука нет | 601 аудиофайл, AudioDirector, 26 аудиотестов | обновить |
| 3 | `AI_HANDOFF_AFTER_S3_2.md` | main scene `main.tscn` | `main_menu.tscn` | обновить |
| 4 | `AGENTS.md` | runtime helper не подключается | подключался; после restart — нет | обновить статус |
| 5 | `AGENTS.md` | Blender libraries/generators off | Sketchfab/Hyper3D on | зафиксировать drift |
| 6 | `level_transitions.md` | цепочка после Кошмара подключена | теперь есть вход из меню/финала | обновить |
| 7 | `first_nightmare_scene_matrix.md` | страж храма не реализован | 13 тестов TempleGuard | обновить |
| 8 | `first_nightmare_scene_matrix.md` | N18 готов | был не готов; теперь реализован | обновить |
| 9 | `first_nightmare_scene_matrix.md` | N07 Bloodbane | был неверен; теперь исправлен | обновить |
| 10 | `docs/design/11_combat_system.md` | боевых встреч в кампании нет | второй личинка на стоянке | обновить |
| 11 | `docs/design/12_inventory...` | инвентарь не реализован | demo inventory + quests/currency | обновить |
| 12 | `p5_optimization.md` | `[rendering]` включён | был удалён; восстановлен | зафиксировать |
| 13 | `labyrinth_first_fragment_implementation.md` | 381 меш / 38k tris | 907 мешей / 4.95M tris | обновить |
| 14 | `level_brief...` | Z15 +25 | as built +18 | обновить |
| 15 | `side_quests.md` | демо = Лабиринт | решение пользователя = пост-Кошмарная цепочка | зафиксировать в DECISIONS |
| 16 | `quests.md` (ранний) | Quest Framework нет | 7 квестов + QuestSystem | обновить |
| 17 | `ui_ux.md` | демо = Лабиринт | цепочка включает Лабиринт как финал | согласовать |
| 18 | `README.md` | полный ручной проход не выполнялся | всё ещё верно | оставить |
| 19 | `not_tested_inventory.md` | 150 вхождений | устарело | пересчитать |
| 20 | `docs/DECISIONS.md` | 73/572 тестов | 634 теста | обновить хвост |

---

## 6. Проблемы интеграции

| ID | Проблема | Влияние | Смягчение |
|---|---|---|---|
| INT-01 | Живое дерево: 574 записи, параллельные чаты | конфликты, ложные тесты | freeze, ACTIVE_CLAIMS, один writer на файл |
| INT-02 | Class cache/import race | ложные parse errors | удалить cache + `--import`, затем тест |
| INT-03 | Autoload churn (`QuestSystem`, `SaveSystem`, `PauseMenuSystem`) | порядок загрузки/дубли | зафиксировать в DECISIONS |
| INT-04 | Два Лабиринта (`coral_labyrinth`, `labyrinth_first_fragment`) | путаница контента | `coral_labyrinth` — sandbox; новый — демо |
| INT-05 | Общий `NightmareRunState` для S00–S15 и Лабиринта | scope-конфликт | QuestSystem scope только Лабиринт |
| INT-06 | MCP editor один на все чаты | гонки runtime | headless QA; live — по очереди |
| INT-07 | Нет экспортного контура | нельзя показать билд | P0 preset/build |
| INT-08 | Модели Hyper3D — внешняя зависимость | каст не финальный | web UI + Blender cleanup |
| INT-09 | Отчёты писались под разные demo scope | противоречивые P0 | MASTER_AUDIT + DECISIONS |
| INT-10 | `project.godot` менялся параллельно | потеря `[rendering]`/autoload | TD-only edits |

---

## 7. Матрица готовности

| Система | Готовность | Доказательство | Блокер |
|---|---:|---|---|
| Импорт/тесты | 85% | import 0; 68/68 targeted; 632/632 stable | freeze/full run |
| Первый Кошмар | 85% | tests, N07/N18/N25 | manual pass |
| Пост-Кошмар M1/M2 | 65% | chain, NPC, HUD, finale | models/content/manual |
| Лабиринт M3 | 60% | art, 18 zones, quests | 5 defects, ghost floor, manual |
| Бой | 80% | 111/111 combat tests | group fight, balance |
| Персонажи | 55% | v3/Hero/Larva | P1 Nightmare, LOD, models |
| Environment art | 80% | captures, 123 FPS | Z15/Z18, Z02/Z13, decals |
| UI/UX | 75% | HUD, menu, pause, journal | inventory, map flags, choice |
| Audio/VFX | 75% | 77 tests, probe | listening, VO |
| Quests | 65% | 7 frameworks, 15/15 | SQ-01..05, adapters |
| Save | 70% | unit 2/2 | live F5/F9, slots |
| Performance | 75% | 123–162 FPS | combat/all zones, draw calls |
| Release | 25% | — | export, manual, QA gate |

---

## 8. Что изменилось после отчётов

- **M2-контент:** полицейский участок, подъезд, ворота, кампус, Sleeper Center, Чёрное море, спуск получили NPC, диалоги, интерактивы, HUD и аудио.
- **N07:** `camp_berries` заменён на `camp_bloodbane.tres`; Санни не ест ягоды.
- **N18:** добавлена личинка Шифти, `shifty_larva_killed`, гейт N19.
- **N25:** `defeated_larva()` считает обе личинки.
- **Финал:** `post_nightmare_finale` + `ToWest`.
- **project.godot:** `[rendering]` восстановлен; autoloads зафиксированы.
- **Тесты:** 81 скрипт, 634 теста; targeted 68/68; stable full 632/632; последний full 633/634 с транзиентным parse error.

---

## 9. Проверка полноты аудита

### 9.1. Чек-лист

- [x] Прочитаны все 11 отчётов (00–10) и их полные версии.
- [x] Сверены ключевые утверждения с кодом/сценами/ресурсами.
- [x] Проверены импорт, целевые тесты, полный GUT (с оговоркой).
- [x] Зафиксированы баги, missing elements, doc-conflicts, integration problems.
- [x] Определены P0–P3 и владельцы.
- [x] Определён demo flow.
- [x] Отдельно выделены системы «с нуля».
- [x] `BACKLOG.md`: 130 открытых задач + 17 закрытых, 147 уникальных ID, 0 дублей, у всех 7 полей (ID, описание, причина, приоритет, зависимости, владелец, критерии).
- [x] `DEMO_FLOW.md`: 8 актов, 3 уровня fallback, mandatory/optional/backlog/from-scratch.
- [x] `DECISIONS.md`: 27 решений и 8 открытых вопросов.
- [ ] Полный ручной проход — **NOT TESTED**.
- [ ] Экспортная сборка — **BLOCKED**.
- [ ] Слуховой тест — **NOT TESTED**.
- [ ] 4K/ultrawide/gamepad — **NOT TESTED**.
- [ ] Acts C–D и западный город — **NOT IMPLEMENTED**.

### 9.2. Вывод о полноте

Аудит **полон для текущего кодового снимка**: все заявленные системы имеют фактический статус, все существенные разрывы вынесены в `BACKLOG.md`, все конфликты зафиксированы.  
Аудит **не является release-аудитом**: без ручного прохода, экспортной сборки и слухового теста нельзя ставить PASS на демо.

---

## 10. Следующий шаг

1. Заморозить дерево и получить один чистый полный GUT.
2. Собрать `export_presets.cfg` и Windows build.
3. Пройти DEMO_FLOW вручную.
4. Закрыть P0 из `BACKLOG.md`.
5. Только после этого — массовая реализация M3/M5/M6.

Никаких массовых изменений кода до утверждения `BACKLOG.md` и `DEMO_FLOW.md`.
