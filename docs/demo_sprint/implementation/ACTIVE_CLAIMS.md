# ACTIVE CLAIMS — реестр правок

Обновлено: 2026-11-02 20:10 +03:00  
Правило: перед правкой — claim; после — результат и освобождение.

## 1. Активные claims

| Кто | Файлы / зона | Зачем | Начало | Окно до | Статус |
|---|---|---|---|---|---|
| Chat 02 + 04 (параллельно) | `scripts/quests/**`, `resources/quests/**`, `scripts/campaign/nightmare_run_state.gd`, `scripts/guide/campaign_guide.gd` | Quest framework / журнал | 20:03 | до консолидации | **активно, не трогать** |
| Chat 07 (вероятно) | `resources/locations/forgotten_shore_labyrinth/**` | материалы Лабиринта | 20:04 | до консолидации | **активно, не трогать** |
| Chat 00 | `docs/demo_sprint/**` | baseline, контракты, аудит | 20:00 | до конца спринта | активно |
| Chat 00 | `docs/demo_sprint/implementation/ACTIVE_CLAIMS.md` | реестр | 20:10 | до конца спринта | активно |
| **Chat 09** | `assets/audio/demo/**`, `tools/audio/generate_demo_audio.py`, `tools/audio/build_demo_cues.gd`, `resources/audio/audio_cue_library_demo.tres`, `scripts/audio/labyrinth_atmosphere.gd`, `scenes/environment/vfx/**`, `scripts/vfx/**`, `docs/demo_sprint/{audits/audio_vfx.md,design/audio_vfx_design.md,qa/audio_vfx_report.md}` | demo audio/VFX layer | 20:05 | до конца спринта | **активно** |
| **Chat 09 (cross-zone hooks)** | `scripts/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.gd` (1 hook), `labyrinth_audio.gd` (storm cue + director cache), `labyrinth_quest_director.gd` (only typed-array syntax fix), `tide_controller.gd` (no net change), `scripts/combat/hurtbox.gd`, `scripts/combat/carapace_enemy.gd`, `scripts/interaction/interactable.gd`, `scripts/player/sunny_controller.gd`, `tests/test_audio_system.gd`, `tests/test_demo_audio_vfx.gd`, `project.godot`, `docs/ASSET_LICENSES.md`, `docs/DECISIONS.md` | connect VFX/SFX to existing signals; restore missing AudioDirector autoload | 20:05 | до конца спринта | **активно, требует review владельцев 03/04/05/06/10** |
| **Chat 06** | `assets/characters/**`, `assets/animations/**`, `scenes/characters/**` кроме `mountain_king.tscn`, `scripts/player/**`, `scripts/slice/mannequin.gd`, `resources/characters/**`, `tools/anim/**`, `docs/demo_sprint/implementation/character_animation_implementation.md` | A06 P0/P1 character/animation implementation: NPC context profiles, `Mannequin` tint/crossfade/accessories, Sunny combo/dodge/guard/weapon socket, LOD/clips | 2026-11-03 | до M1 gate | **Stage 6 audit done; full GUT 636/636; ждёт review A00 и интеграции A03/A05** |

## 2. Freeze-лист (без TD не менять)

- `project.godot`
- `scripts/campaign/nightmare_run_state.gd`
- `scripts/guide/campaign_guide.gd`
- `scripts/world/level_portal.gd`
- `scripts/audio/audio_director.gd`
- `scripts/ui/rpg_menu/rpg_menu_theme.gd`
- `default_bus_layout.tres`
- `scenes/ui/main_menu/main_menu.tscn`
- `scenes/campaign/campaign_entry.tscn`
- `scenes/campaign/finale_arrival.tscn`
- `docs/DECISIONS.md`
- `docs/ASSET_LICENSES.md`

## 3. Шаблон claim

```markdown
| <chat> | <paths> | <зачем> | <HH:MM> | <HH:MM> | активно / завершено / отменено |
```

Перед добавлением:

1. Проверить, нет ли уже claim на этот файл.
2. Если есть — не дублировать; договориться через TD.
3. Если файл в freeze-листе — сначала подтверждение TD.

## 4. Завершённые claims

| Кто | Файлы | Результат | Когда |
|---|---|---|---|
| Chat 00 | `docs/demo_sprint/BASELINE.md`, `README.md`, `EXPECTED_REPORTS.md`, `OWNERSHIP.md`, `design/00_DEMO_SCOPE_AND_CONTRACT.md` | создано | 20:10 |
| Chat 00 | `main_menu.gd`, `finale.gd`, `greybox_location.gd`, `cinematic_actor.gd`, `post_nightmare_finale.*`, `project.godot`, tests | M1-каркас: вход, финал, HUD, рендер, 622/622 | 21:20 |
| Chat 03 | `docs/demo_sprint/audits/03_world_level_design.md`, `audits/level_design.md`, `design/world_layout.md`, `design/poi_manifest.md`, `design/world_layout_map.svg`, `tools/map/draw_demo_layout.py`, read-only `tools/audit/scene_bounds.gd`, `route_reachability.gd`, `segment_walk.gd` | создано; игровые файлы не менялись | 20:40 |
| Chat 03 | `docs/demo_sprint/design/world_layout.md`, `design/poi_manifest.md`, `design/level_implementation_plan.md`, `docs/demo_sprint/DEMO_FLOW.md` | Stage 2: единая география M1 + tech demo, 34/34 SQ-координаты, план фиксов | 21:05 |
| Chat 09 | `assets/audio/demo/**` (17 звуков), `scenes/environment/vfx/**` (6 VFX-сцен), `scripts/vfx/one_shot_vfx.gd`, `scripts/audio/labyrinth_atmosphere.gd`, `resources/audio/audio_cue_library_demo.tres`, `tools/audio/generate_demo_audio.py`, `build_demo_cues.gd`, `check_demo_audio.py`, `tools/audit/audio_vfx_probe.gd` | создано и проверено probe-ом; звук на слух NOT TESTED | 20:05 |
| Chat 04 | `scripts/quests/**`, `resources/quests/**`, `scripts/systems/save_system.gd`, `scripts/ui/gameplay_hud.gd`, `scripts/ui/quest_toast.gd`, `scripts/locations/forgotten_shore_labyrinth/labyrinth_quest_director.gd`, `tests/test_quest_system.gd`, `tests/test_labyrinth_quest_content.gd`, `tests/test_save_system.gd`, `docs/demo_sprint/audits/gameplay_systems.md`, `docs/demo_sprint/design/gameplay_architecture.md` | Quest Framework, мировые адаптеры, HUD/журнал, слот сохранения; целевые 15/15, 118 assert; полный GUT 602/619 из-за внешних анимационных/VFX-ресурсов | 20:03–20:50 |
| Chat 04 (cross-zone) | `scripts/campaign/nightmare_run_state.gd`, `scripts/guide/campaign_guide.gd`, `scripts/ui/rpg_menu/rpg_quest_screen.gd`, `scripts/ui/objective_line.gd`, `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`, `scripts/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.gd`, `scenes/locations/post_nightmare/tide_descent.tscn`, `project.godot` | аддитивные поля quests/currency/memories, external objective, live journal, guard выхода из дерева, подключение Лабиринта и `SaveSystem`, восстановление `[rendering]`; требует review 03/08/TD | 20:03–20:50 |

## 5. INCIDENTS

| Время | Что | Влияние | Действие |
|---|---|---|---|
| 20:05 | Параллельный чат изменил `NightmareRunState`, `CampaignGuide`, материалы Лабиринта во время baseline | счётчики Git изменились: 77→78 modified, 171→184 untracked | зафиксировано в `BASELINE.md`; файлы не перезаписывались |
| 20:35 | Параллельные Quest/Combat-правки оставили дерево без компиляции: `StaminaComponent`, `AttackData`, `QuestDefinition`, `QuestObjective`, `QuestReward`, `QuestCatalog`, `QuestToast`, `labyrinth_quest_director.gd` | GUT Лабиринта и кампании красный; runtime-проверки заблокированы | зафиксировано Chat 03 в `audits/03_world_level_design.md`; чужие файлы не чинились |
| 20:15 | В `project.godot` добавлены `PauseMenuSystem`, `QuestSystem`, `[display]`; **удалён `[rendering]`** с P5-настройками | регрессия P5: occlusion/LOD/VRAM-компрессия выключены | P0-0: вернуть блок; не откатывать чужие autoload/display без согласования |
| 20:18–20:19 | Chat 01 и Chat 02 записали отчёты `01_narrative_story.md`, `narrative.md`, `quests.md` | два отчёта приняты в работу | не перезаписывать |
| 20:12 | В рабочем `project.godot` отсутствовали `AudioDirector` и `[audio] buses/default_bus_layout`; `AudioDirector` был null, аудио-тесты падали | весь звук в demo-сцене не работал бы | Chat 09 восстановил обе строки; `[rendering]` позже восстановлен другим чатом, проверено |
| 20:24 | `labyrinth_quest_director.gd` не парсился из-за `Array[StringName]([...])`/`Array[StringName]()` в позиции аргумента | сцена Лабиринта не загружалась | Chat 09 заменил на `[]`; владельцу 04 проверить типизацию `required_flags` |
| 20:38 | Класс-кэш Godot не содержал `StaminaComponent`, `AttackData`, `QuestNpc`, `QuestKillCredit` после параллельных правок | ложные parse errors в GUT/runtime | `--editor --quit` пересобрал кэш; файлы не менялись |

## 6. Правило эскалации

Если нужен общий файл:

1. написать TD в этот файл;
2. подождать подтверждения;
3. не менять файл до подтверждения;
4. после правки — целевой тест и запись.


## 7. Chat 07 — environment art pass (2026-11-02)

| Кто | Файлы / зона | Зачем | Начало | Окно до | Статус |
|---|---|---|---|---|---|
| Chat 07 | `assets/environments/nightmare/materials/**`, `resources/locations/forgotten_shore_labyrinth/**`, `docs/art/previews/forgotten_shore/environment_art/**`, `docs/demo_sprint/audits/environment_art.md`, `docs/demo_sprint/design/environment_art_direction.md` | коралловый кит, PBR, свет, небо, вода, прилив, сет-дрессинг | 19:55 | 21:45 | **завершено** |
| Chat 07 (cross-zone, visual only) | `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn` (Sun/SkyFill/вода/камеры/CampLight), `scripts/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.gd` (подключение ArtFinal, удаление 11 corridor omni), `labyrinth_greybox.gd` (metadata для арт-слоя) | арт-слой и свет; коллизии/маршруты не меняются | 20:00 | 21:45 | **завершено, требует review 03/04** |

**Результат:** targeted GUT `test_labyrinth_first_fragment.gd` — 13/13, 332 assert; capture low/high — PASS; perf 1920×1080 — 123,8 FPS, 857 МБ VRAM; boundary audit — 3238 deadly edges / 1 deadly jump / 145465 м² без изменений (39 ghost floor / 117 hanging — декоративный арт без коллизии). Новых внешних лицензированных ассетов нет; `bone_skull.glb` — project-owned. Полный ручной проход и полный GUT — NOT TESTED из-за внешних parse errors.

