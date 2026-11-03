# Character & Animation — Implementation Specification

**Domain:** A06 — Character & Animation  
**Stage:** 2 — technical design; implementation not started  
**Date:** 2026-11-03  
**Base:** Design Package DP-1.0, commit `0335a5c346901af2146413b5a159b442d326d8de`  
**Status:** **SPEC READY FOR TD REVIEW.** Game files, scenes, assets, tests and project settings were **not changed** in this stage.  
**Stage 3 implementation report:** `docs/demo_sprint/implementation/character_animation_stage3_report.md`.
**Stage 4 implementation report:** `docs/demo_sprint/implementation/character_animation_stage4_report.md`.
**Companion docs:** `MASTER_PLAN.md`, `BACKLOG.md`, `FILE_OWNERSHIP.md`, `AGENT_TASKS.md`, `INTEGRATION_CONTRACTS.md`, `design/02_MODEL_PIPELINE.md`, `audits/characters_animation.md`.

---

## 0. Короткий вывод

1. **M1 не должен ждать финальный каст.** По MASTER_PLAN M1 принимается с помеченными placeholders; финальные Jett, Rock, Kasper, Cassia, Nephis — M2/M3. P0 A06 — это стабильный `Mannequin`, читаемые placeholder-силуэты и корректные M1-анимации Санни/карапакса.
2. **Лучший технический фундамент уже есть:** v3 Sunny с native clips + `AnimationTree`, P1 Nightmare с UAL + `AnimationTree`, `FootGrounder`, `GuardPoseModifier`, `Mannequin.WalkClean`. Спецификация расширяет это, а не строит второй animation framework.
3. **Главные разрывы:** NPC меняют позы без blend; P1 Nightmare визуально слабый; v3/Hero/Carapace/Mountain King без LOD; у врагов нет authored hit/death clips; sword guard/combo/parry и turn-in-place отсутствуют; weapon hitbox не на мече.
4. **Работа режется на независимые ветки:** A06-owned assets/scripts; для `scenes/locations/**` A03, `scenes/enemies/**` A05, `resources/combat/**` A05, `tests/**`/`qa/**` A10. A06 не правит чужие зоны.
5. **Внешняя зависимость:** финальные модели требуют Hyper3D web UI и решения пользователя по кредитам. Без этого M1 идёт на явно помеченных placeholders; это не блокер M1 по MASTER_PLAN.

---

## 1. Что конкретно предстоит реализовать

### 1.1. Волна M1 — P0, до M1 gate

| Направление | Результат | Можно ли placeholder |
|---|---|---|
| Стабильность | `Mannequin`, `SunnyAnimator`, `WalkClean`, `FootGrounder`, `GuardPose` без parse errors и без дублей клипов | нет |
| Jett | читаемый placeholder `mass_female` в тёмно-синей форме; idle/talk/point/lean/walk | **да**, помечен |
| Rock | крупный `mass_male`; idle/talk/широкий жест | **да** |
| Kasper | `mass_male`, форма с золотом; idle/talk/скрещённые руки | **да** |
| Cassia | `mass_female`, белая форма, незрячий взгляд; idle/listen/поворот головы | **да** |
| Nephis | `mass_female`, серебряные волосы, белый плащ, копьё; idle/spear guard/walk | **да** |
| Sunny M1 | sit/stand/sleep/interact/equip/Плащ/cinematic; без T-pose | нет |
| Carapace E01 | idle/walk/telegraph/attack/death; contact 0.40; без сломанного рига | нет |
| NPC placement | A06 даёт prefab/profile, A03 ставит в P05–P09/Z08/Z10 | — |

**M1 не требует:** финальных Jett/Julius/Rock/Kasper/Cassia/Nephis, LOD1/2, facial/finger animation, sword combo, turn-in-place, authored enemy hit clips.

### 1.2. Волна tech demo / M3 — P1

- Shared NPC `AnimationTree` (idle/talk/point/walk/listen) для `Mannequin`.
- LOD1/2 для v3 Sunny, Hero v6, Carapace, Mountain King.
- Authored hit/death clips для Carapace и Larva; A05 подключает состояния.
- Sword guard pose, combo 2–3, parry/riposte; A05 настраивает `AttackData`.
- Weapon socket → hitbox на клинке (совместно с A05).
- Turn-in-place (90°/180°) и foot IK/foot lock.
- Dodge/roll tail: анимация и движение синхронизированы.
- Финальные Nephis/Cassia (Z08/Z10) и Theo (Z06, SQ-01).
- Echo polyp: 5 клипов для SQ-02.
- NPC gestures wave/point/argue.

### 1.3. Волна M2 / поздний сюжет — P1/P2

- Julius (M2), Theo (M3), финальный Sunny Nightmare, финальные Hero/Shifty/Scholar/Veteran/BroadSlave, Mountain King, Carapace Centurion/Centipede/Worm Knot/Blood Flower, Kai/Effie, Gunlaug/Black Knight/Great Devil.
- Facial animation/blink/lip sync, finger animation, ragdoll — P2/P3.

---

## 2. Какие существующие элементы требуется исправить

| Проблема | Текущее состояние | Что делать | Владелец |
|---|---|---|---|
| P1 Nightmare визуально слабый | 48 518 tri, 53 bones, UAL, 3 LOD; «манекенное» тело | Оставить как **помеченный fallback** в M1; финальная модель — M2/M3; не выдавать за финал | A06 |
| P1 каст | 47–65k tri, double-sided, без tangents, 20–86 prims | Не переделывать в M1; для финального каста — retopo/tangents/single-sided/LOD | A06 |
| LOD у v3/Hero/Carapace/MK | 84k/90k/120k/75k tri, LOD нет | LOD1/2, visibility ranges, tri budget; не менять сцены A03 | A06 |
| NPC transitions | `Mannequin` меняет pose без blend | Shared NPC `AnimationTree`; не новый framework | A06 |
| NPC placeholders | Jett/Rock/Kasper/Cassia/Nephis — Mannequin/`mass_*` | Читаемые силуэты, uniforms, hair/cloak/spear, пометка placeholder | A06 + A03 |
| Carapace/Larva hit/death | процедурный flinch; нет authored клипов | Authored hit/death clips; A05 подключает | A06 + A05 |
| Weapon hitbox | сфера перед персонажем | Socket на клинке + hitbox по мечу; A05 ведёт бой | A06 + A05 |
| Sword guard/combo/parry | один `Sword_Attack`, low guard | Guard pose, combo 2–3, parry/riposte; contact times | A06 + A05 |
| Turn-in-place / foot IK | контроллер резко поворачивает, стопы скользят | Turn-клипы, foot lock/IK, замер slide | A06 |
| Dodge/roll tail | клип длиннее движения | hold/roll синхронизировать | A06 + A05 |
| `white_horse_v2` UID/parse | invalid UID/parse error | Исправить asset/import; A10 проверяет | A06 + A10 |
| v3/Hero native walk | root-motion take | `WalkClean` уже создан; проверить в сценах | A06 |
| Mannequin/animator stability | `WalkClean`, `FootGrounder`, `GuardPose` добавлены, но нет полного regression | Targeted GUT + no warnings; A06-06 | A06 |

---

## 3. Какие новые элементы требуется создать

### 3.1. Ресурсы и prefab-ы (A06-owned)

| Элемент | Путь | Назначение |
|---|---|---|
| NPC animation profiles | `resources/characters/npc_profiles/<id>.tres` | archetype, material overrides, idle/talk/walk/point/gesture clips, height/width, placeholder flag |
| Shared NPC tree | `resources/characters/npc_animation_tree.tres` | idle/talk/point/walk/listen blend + one-shot gestures |
| Jett prefab | `scenes/characters/npc/jett.tscn` | Mannequin + profile; A03 instantiates |
| Rock/Kasper/Cassia/Nephis prefabs | `scenes/characters/npc/<id>.tscn` | same |
| Theo prefab | `scenes/characters/npc/theo.tscn` | M3; noncombatant |
| Julius prefab | `scenes/characters/npc/julius.tscn` | M2 only |
| NPC gesture clips | `assets/animations/npc/gestures/*.glb` | wave/point/argue/listen/head turn |
| Combat clips | `assets/animations/combat/*.glb` | guard, combo, parry, riposte, turn, enemy hit/death |
| LOD variants | `assets/characters/**/..._LOD1.glb`, `_LOD2.glb` | v3/Hero/Carapace/MK |
| Validation tool | `tools/anim/validate_character_assets.py` | read-only tri/UV/tangent/bones/clips/LOD/license audit |
| Tree builders | `tools/anim/build_npc_tree.gd`, `build_sunny_combat_tree.gd` | regenerate `.tres` reproducibly |

### 3.2. Новые клипы

| Актор | Клипы | Приоритет |
|---|---|---|
| Jett | idle, talk, point, lean, walk away | M1 |
| Guard | idle, talk, check/pass | M1 |
| Rock | idle, talk, wide gesture | M1 |
| Kasper | idle, talk, crossed arms | M1 |
| Cassia | idle, listen, head turn | M1 |
| Nephis | idle, spear guard, walk | M1 |
| Sunny | sit, stand, sleep, interact, equip/shroud, cinematic | M1 |
| Carapace | idle, walk, telegraph, attack, death, hit | M1 verify; P1 hit/death authored |
| Larva | hit, death variant | P1 |
| Sunny combat | guard, combo A/B/C, parry, riposte, turn 90/180 | P1 |
| NPC gestures | wave, point, argue | P1 |
| Theo | idle, talk, kneel, dead | M3 |
| Echo polyp | pulse, inhale, core open, tendril cut, fall | M3 |
| Later cast | per design | P2 |

### 3.3. Что не создавать

- Второй `AnimationTree`-framework, второй `Mannequin`, второй `SunnyAnimator`, второй `EnemyAnimator`.
- Второй state/quest/inventory/audio/tide.
- Новые autoload.
- Дубликаты NPC ID/сцен.
- Новые MCP-серверы/плагины без решения пользователя.

---

## 4. Какие файлы предстоит изменить

### 4.1. A06-owned — можно менять в ветке A06

| Файл/каталог | Изменение |
|---|---|
| `assets/characters/**` | новые модели, LOD, текстуры, prefab-сцены |
| `assets/animations/**` | новые клипы, retarget/bake, library `.tres` |
| `scenes/characters/**` кроме `mountain_king.tscn` | Sunny/NPC prefab-сцены |
| `scripts/player/sunny_animator.gd` | tree states, combat/turn/IK hooks |
| `scripts/player/sunny_controller.gd` | только turn/foot-lock hooks, без смены геймплея |
| `scripts/slice/mannequin.gd` | NPC profiles, tree, gestures, placeholder flags |
| `resources/characters/**` | animation trees, profiles, clip maps |
| `tools/anim/**` | build/validate scripts |
| `docs/demo_sprint/audits/characters_animation.md` | обновление аудита |
| `docs/art/character_animation_pipeline_audit.md` | обновление pipeline-документа |

### 4.2. Shared/request-only — A06 не правит напрямую

| Файл/каталог | Владелец | Как A06 участвует |
|---|---|---|
| `scenes/locations/**` | A03 | A06 даёт prefab/profile; A03 ставит NPC и порталы |
| `scenes/characters/mountain_king.tscn` | A05 | A06 даёт модель/клипы; A05 собирает сцену |
| `scenes/enemies/**` | A05 | A06 даёт GLB/клипы; A05 подключает состояния |
| `resources/combat/**` | A05 | A06 даёт clips/socket; A05 настраивает `AttackData`, hitbox, contact |
| `tests/**` | A10 | A06 просит targeted tests; A10 пишет/запускает |
| `docs/demo_sprint/qa/**` | A10 | A06 даёт evidence; A10 пишет PASS/FAIL |
| `project.godot` | A00 | не менять |
| `resources/quests/**` | A04/A02 | A06 только NPC/clip hooks |
| `scenes/ui/**` | A08 | A06 даёт portrait/render, A08 вставляет |
| `assets/audio/**`, `scripts/audio/**` | A09 | A06 не трогает |

### 4.3. Спорный ownership

`scripts/characters/**` (`foot_grounder.gd`, `guard_pose_modifier.gd`, `character_lod_visibility.gd`) **не указан** в FILE_OWNERSHIP. До решения TD A06 либо:
- просит TD закрепить `scripts/characters/**` за A06; или
- переносит helpers в `scripts/player/`/`scripts/slice/` (A06-owned).

Это первый вопрос TD (§11).

---

## 5. Какие ресурсы потребуются

| Ресурс | Кол-во/объём | Источник | Лицензия/условие |
|---|---|---|---|
| Jett placeholder | 1 prefab + 1 profile + 5 clips | `mass_female` + material override; UAL | MPFB/MakeHuman CC0; UAL CC0 |
| Rock/Kasper/Cassia/Nephis placeholders | 4 prefabs + 4 profiles + clips | `mass_male`/`mass_female` + hair/cloak/spear props | CC0; project-owned props |
| Sunny M1 clips | 6–8 clips | native v3 + UAL + Blender | project-owned; UAL CC0 |
| Carapace/Larva hit/death | 4–6 clips | Blender authoring on existing rigs | project-owned |
| Sword guard/combo/parry | 4–6 clips | Blender authoring/UAL source | project-owned; UAL CC0 |
| Turn/foot IK | 2 turn clips + runtime IK | Blender + Godot | project-owned |
| LODs | 4 assets × 2 LOD | Blender decimate + glTF-Transform | project-owned |
| Final Jett/Nephis/Cassia/Theo/Julius | 5+ GLB | Hyper3D web UI + Blender cleanup | user-approved generation; license registration |
| Later cast | 10+ GLB | Hyper3D web UI / stock | user decision; license check |
| Textures | 1K/2K PBR | Krita/Materialize/Poly Haven CC0 | register in `ASSET_LICENSES.md` |
| Animation source | UAL 46, KayKit 76, native v3/Hero | local | CC0/project-owned; no Mixamo raw redistribution |

**Бюджет:** M1 placeholders — только существующие ассеты, 0 кредитов. Tech demo — LOD/clips на существующих ассетах, 0 кредитов. Финальный каст — Hyper3D web UI, по одному ассету с приёмкой; массовая генерация запрещена до решения TD/пользователя.

---

## 6. Какие инструменты использовать

| Инструмент | Роль | Ограничение |
|---|---|---|
| Blender 5.1.1 background | retopo, decimate, weights, LOD, clip authoring/bake, GLB export | нет встроенного retarget; slotted actions API |
| Blender MCP | preview/status, scene inspection | production — background scripts; не править чужие сцены |
| Godot 4.7.2 | AnimationTree, BoneAttachment3D, SkeletonModifier3D, import, GUT | class cache нестабилен; freeze/import перед тестом |
| glTF-Transform 4.5.1 | inspect, tangents, optimize, LOD validation | не заменяет DCC |
| Krita 5.3.4.1 / Materialize 1.78 | texture cleanup/PBR maps | не использовать без лицензии |
| `tools/anim/**` | build trees, validate assets, capture | read-only для чужих зон |
| GUT 9.7.1 | targeted/full tests | A10 запускает; A06 не правит tests |

**Не использовать:** новые MCP-серверы, плагины, второй animation framework, второй autoload, Hyper3D CLI без активной подписки.

---

## 7. Зависимости

### 7.1. Внутренние

| Зависимость | Что нужно от неё | Когда |
|---|---|---|
| A00 | DP-1.0 lock, file ownership, freeze, shared-file gate | до старта |
| A01 | канон внешности/реплик Jett/Nephis/Cassia/Theo; speaker IDs | до профилей/диалогов |
| A03 | точки NPC/POI, размещение prefab-ов, сцены P05–P09/Z06/Z08/Z10 | параллельно M1 |
| A04 | флаги/квесты Theo/Echo; `QuestNpc` hooks | M3 |
| A05 | attack timing/hitbox/contact; enemy state hooks | M1/P1 |
| A07 | материалы окружения/свет для capture; не character assets | M1 |
| A08 | portrait/choice UI, HUD prompts | M1/M3 |
| A09 | VFX Плаща/тени/эха; audio cues | M1/M3 |
| A10 | targeted/full GUT, import, performance, manual pass | каждый gate |

### 7.2. Внешние

- Hyper3D web UI и кредиты — только по решению пользователя; без активного доступа финальный каст не начинается.
- Лицензии: UAL/KayKit/MakeHuman/Poly Haven CC0; Sketchfab CC BY — атрибуция; Mixamo/Rokoko/MoCap — только после проверки.
- `white_horse_v2` UID/parse — совместно A10.

---

## 8. Интеграция с другими специалистами

| Специалист | Контракт | A06 делает | A06 не делает |
|---|---|---|---|
| A03 World/Level | prefab + profile + POI | создаёт `scenes/characters/npc/<id>.tscn`; сообщает scale/height/anim set | не правит `scenes/locations/**` |
| A05 Combat/AI | clips + socket + timings | создаёт guard/combo/parry/hit/death clips, weapon socket; сообщает contact time | не правит `resources/combat/**`, `scenes/enemies/**` |
| A04 Gameplay | NPC/quest hooks | `Mannequin` profile, `QuestNpc`-compatible prefab; Theo noncombatant | не правит `scripts/quests/**` |
| A01 Narrative | appearance/dialogue | silhouette, uniform, hair/cloak/spear; placeholder flag | не пишет диалоги |
| A08 UI | portrait/choice | render portrait/capture; no UI edits | не правит `scenes/ui/**` |
| A09 Audio/VFX | VFX hooks | cloth/shadow mesh, clip events | не правит audio/VFX scenes |
| A10 QA | tests/evidence | runs read-only probes, provides captures/logs | не пишет tests/qa PASS |
| A00 TD | shared files/contracts | claim + handoff | не коммитит, не меняет project.godot |

---

## 9. Ошибки и конфликты, которые могут возникнуть

| Риск | Причина | Смягчение |
|---|---|---|
| Смешение 3 ригов | v3/Hero 52, P1 53, KayKit 41 | не переносить клипы между ригами; native clips для v3/Hero, UAL для P1 |
| UAL→v3 артефакты | rest pose/кости | UAL на v3 отклонён; использовать native clips; retarget только после проверки |
| `AnimationTree` vs `CinematicActor` | два источника позы | `SunnyAnimator.cinematic` выключает tree; `CinematicActor` играет player напрямую |
| `FootGrounder` vs `CharacterBody3D` | визуальный offset | двигать только mesh, не body; disable в jump/fall/dodge/death |
| LOD duplicate skeleton/player | GLB LOD копии | LOD в одном GLB, общая арматура, `_LOD1/_LOD2`, один AnimationPlayer |
| NPC pose snap | нет blend | shared NPC tree; 0.15–0.25 s xfade |
| Shared scene conflict | A03/A05 владеют сценами | A06 даёт prefab/asset; сцену собирает владелец |
| `white_horse_v2` UID | stale import | A06 фиксит asset, A10 проверяет import |
| Hyper3D кредиты | внешний доступ | M1 на placeholders; финальный каст — после решения |
| `scripts/characters/**` ownership | не указан | TD decision; до этого helpers в A06-owned path |
| Weapon hitbox ownership | A05 бой, A06 socket | A06 даёт socket/transform; A05 двигает hitbox и тестирует |
| Full GUT flaky | class cache/parallel writes | freeze, delete cache + `--import`, A10 baseline |
| Performance | 84–120k tri без LOD | LOD1/2, 1K textures, visibility ranges; A10 замер |

---

## 10. Как проверить готовность каждого элемента

### 10.1. Общие проверки (A10)

```powershell
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=<targets> -gexit
```

- import **exit 0**;
- targeted GUT **0 fail**;
- full GUT **0 fail** (если 633/634 — FAIL);
- нет новых parse errors/warnings в A06-файлах;
- M1 manual pass P05→Z10; tech demo Z18;
- 1080p ≥60 FPS в E01–E03 и Z18;
- placeholders помечены.

### 10.2. Проверки по элементам

| Элемент | Проверка | Критерий |
|---|---|---|
| Jett/Rock/Kasper/Cassia/Nephis placeholder | P06/P09/Z08/Z10 capture | силуэт читается; не блокирует; помечен placeholder |
| NPC tree | idle→talk→point→walk→idle | 3 перехода, нет snap >5°, нет T-pose |
| Sunny M1 | sit/stand/sleep/interact/equip/Плащ | клип играет; `CinematicActor` не конфликтует; reset idle |
| Carapace E01 | idle/walk/telegraph/attack/death | contact 0.40; нет broken rig; тест 9/9 |
| LOD | 3 дистанции, tri count | LOD0/1/2 переключаются; нет popping; budget |
| Enemy hit/death | E01 hit/kill | клип играет; A05 state; нет procedural flinch в финале |
| Sword guard/combo/parry | attack sequence | 2–3 combo; contact внутри active; нет clipping |
| Weapon socket/hitbox | sword follows hand; hit test | socket на `RightHand`; hitbox на клинке; A05 test |
| Turn/foot IK | 90/180 turn, slope | slide <5% stride; foot lock; no snap |
| Dodge/roll tail | dodge in motion | hold совпадает с движением; нет «хвоста» |
| Theo/Echo | Z06/Z09 | noncombatant; 5 клипов; SQ-01/02 |
| Final cast | import/scene capture | 3 LOD; PBR; rig; clips; license |

### 10.3. Метрики приёмки

| Метрика | Цель |
|---|---|
| T-pose в игре | 0 кадров |
| Foot slide | <5% длины шага; drift <2 см |
| Loop seam | <2 см / 2° |
| Pose snap на transition | <5° ключевых костей |
| Weapon tip ↔ hitbox | 100% active frames |
| LOD tri budget | hero LOD0 ≤50k; NPC ≤30k; crowd ≤15k (или TD exception) |
| Draw calls | <1500 в Лабиринте; A10 замер |
| Placeholder marking | 100% |

---

## 11. Task list

**Формат:** Task ID | Description | Files | Dependencies | Priority | Effort | Risk | Acceptance Criteria.  
**Effort** — идеальные часы/дни без внешней генерации; **Risk** — Low/Medium/High.  
**Правило:** задачи с пометкой **[request]** требуют правки чужой зоны; A06 делает только A06-часть и передаёт владельцу.

**ID policy:** `A06-01…A06-10` already exist in `AGENT_TASKS.md`; `A06-11…A06-26` are proposed sub-tasks for TD/A00 to merge into `AGENT_TASKS.md`/`BACKLOG.md`. They do not replace or duplicate existing `SS-*`/`A06-*` IDs; mapping is in §11.4.

### 11.1. M1 — P0

| Task ID | Description | Files | Dependencies | Priority | Effort | Risk | Acceptance Criteria |
|---|---|---|---|---|---|---|---|
| **A06-01** | Jett placeholder: `mass_female` + dark-blue uniform, 5 poses (idle/talk/point/lean/walk). Prefab + profile. | `scenes/characters/npc/jett.tscn`, `resources/characters/npc_profiles/jett.tres`, `scripts/slice/mannequin.gd`, `assets/characters/p1/models/mass_female.glb` | A00, A01, A03 | P0 | 3–4 h | Low | P06 capture; 5 poses; no blocking; placeholder flag; no parse error |
| **A06-02** | Rock/Kasper/Cassia/Nephis placeholders: Rock idle/talk/wide gesture; Kasper idle/talk/crossed arms; Cassia idle/listen/head turn; Nephis idle/spear guard/walk; mass models + uniform/hair/cloak/spear; profiles; prefabs. | `scenes/characters/npc/{rock,kasper,cassia,nephis}.tscn`, `resources/characters/npc_profiles/*.tres`, `scripts/slice/mannequin.gd`, `assets/characters/p1/models/mass_*.glb` | A00, A01, A03 | P0 | 4–6 h | Low | P09/Z08 captures; 4 NPCs; Cassia blind gaze; Nephis silver hair/cloak/spear; no blocking |
| **A06-06** | Stabilize `Mannequin`/`SunnyAnimator`: `WalkClean`, `FootGrounder`, `GuardPose`, no parse errors, no duplicate clips. | `scripts/slice/mannequin.gd`, `scripts/player/sunny_animator.gd`, `assets/characters/generated/sunny_real_v3/sunny_v3_model.gd`, `scripts/characters/foot_grounder.gd`, `scripts/characters/guard_pose_modifier.gd` | A00 | P0 | 3–4 h | Medium | `test_labyrinth_first_fragment` 13/13; no warnings; `WalkClean` exists; no duplicate |
| **A06-11** | Sunny M1 animation set: sit/stand/sleep/interact/equip/Плащ/cinematic; ensure `CinematicActor` and tree don't conflict. | `scenes/characters/sunny.tscn`, `scripts/player/sunny_animator.gd`, `resources/characters/sunny_animation_tree.tres`, `sunny_v3_animation_tree.tres`, `assets/characters/**` | A06-06, A03 | P0 | 4–6 h | Medium | all clips exist; no T-pose; `reset_to_idle`; `test_sunny_animation`/`test_sunny_poc` pass |
| **A06-12** | Carapace E01 animation verification: idle/walk/telegraph/attack/death, contact 0.40, no rig break. | `assets/characters/enemies/carapace_generated/*`, `assets/animations/enemies/carapace/*` | A05, A06-06 | P0 | 2–3 h | Low | `test_carapace_enemy` 9/9; E01 capture; contact 0.40 |
| **A06-13** | NPC placement handoff: prefab scale/height/anim profile for A03; no scene edits. | `scenes/characters/npc/*.tscn`, `resources/characters/npc_profiles/*.tres` | A03 | P0 | 1–2 h | Low | A03 instantiates at POI; no floating; no collision block |

### 11.2. Tech demo / M3 — P1

| Task ID | Description | Files | Dependencies | Priority | Effort | Risk | Acceptance Criteria |
|---|---|---|---|---|---|---|---|
| **A06-05** | Shared NPC `AnimationTree`: idle/talk/point/walk/listen, 0.15–0.25 s xfade; no new framework. | `resources/characters/npc_animation_tree.tres`, `scripts/slice/mannequin.gd`, `resources/characters/npc_profiles/*.tres` | A06-01/02, A06-06 | P1 | 1–2 d | Medium | 3 transitions; no snap >5°; P06/P09/Z08 captures; no T-pose |
| **A06-07** | LOD1/2 for v3/Hero/Carapace/MK; same armature, one player; budget. | `assets/characters/generated/sunny_real_v3/*`, `hero_auro_v6/*`, `enemies/carapace_generated/*`, `p1/models/mountain_king_p3.glb`, `scripts/characters/character_lod_visibility.gd` | A06-04/05, A10 | P1 | 2–4 d | Medium-High | 3 LOD; switch at 10/22 m; no popping; tri budget; capture |
| **A06-10** | Carapace/Larva authored hit/death clips; A05 integrates states. | `assets/animations/enemies/carapace_hit.glb`, `larva_hit.glb`, `assets/characters/enemies/**` | A05-01 | P1 | 2–3 d | Medium | 2–3 clips; E01 hit/kill; no procedural flinch in final; A05 test |
| **A06-14** | Sword guard/combo/parry/riposte; contact times; tree states. | `assets/animations/combat/*.glb`, `resources/characters/sunny_animation_tree.tres`, `scripts/player/sunny_animator.gd` | A06-06, A05 | P1 | 3–5 d | High | guard pose; 2–3 combo; parry/riposte; contact inside active; no clipping |
| **A06-15** | Weapon socket → hitbox on blade; A05 owns combat test. | `assets/characters/p1/sunny_p1_model.tscn`, `scripts/player/sunny_animator.gd`, `scenes/characters/sunny.tscn` | A06-14, A05 | P1 | 2–3 d | High | socket follows `RightHand`; hitbox on blade; A05 test; no sphere-only fallback |
| **A06-16** | Turn-in-place 90/180 + foot IK/foot lock; measure slide. | `assets/animations/locomotion/turn_*.glb`, `scripts/player/sunny_animator.gd`, `scripts/player/sunny_controller.gd`, `scenes/characters/sunny.tscn` | A06-06, A10 | P1 | 3–5 d | High | 90/180 turn; slide <5%; no snap; manual check |
| **A06-17** | Dodge/roll tail: sync clip hold with movement; no tail. | `scripts/player/sunny_animator.gd`, `resources/characters/**`, `assets/animations/locomotion/*` | A06-16, A05 | P1 | 1–2 d | Medium | hold matches dodge; no slide/tail; manual check |
| **A06-04** | Final Nephis/Cassia models + rig + clips + LOD; Z08/Z10. | `assets/characters/npcs/nephis/*`, `cassia/*`, `scenes/characters/npc/*.tscn`, `resources/characters/npc_profiles/*.tres` | A00, A03, generation | P1 | 3–5 d + gen | High | 2 GLB + rig + 5 clips + LOD; Z08/Z10; no blocking; license |
| **A06-09** | Theo model/rig/clips (idle/talk/kneel/dead); noncombatant; Z06. | `assets/characters/npcs/theo/*`, `scenes/characters/npc/theo.tscn`, `resources/characters/npc_profiles/theo.tres` | A02-01, A03, generation | P1 | 2–3 d + gen | High | 1 GLB + 4 clips + LOD; Z06; SQ-01; noncombatant |
| **A06-18** | Echo polyp: 5 clips (pulse/inhale/core open/tendril cut/fall). | `assets/characters/enemies/echo_polyp/*`, `assets/animations/enemies/echo_polyp/*` | A02-02, A05 | P1 | 2–3 d | Medium | 5 clips; SQ-02; no blocking; A05 scene |
| **A06-19** | NPC gestures: wave/point/argue; profiles + tree. | `assets/animations/npc/gestures/*.glb`, `resources/characters/npc_profiles/*.tres`, `scripts/slice/mannequin.gd` | A06-05 | P1 | 1–2 d | Medium | 3 gestures; no snap; one scene capture |
| **A06-03** | Julius M2 model/rig/clips; not in M1. | `assets/characters/npcs/julius/*`, `scenes/characters/npc/julius.tscn`, profile | A00, generation | P1 | 2–4 d + gen | High | M2 scene; absent in M1; LOD/clips |

### 11.3. Full program — P2

| Task ID | Description | Files | Dependencies | Priority | Effort | Risk | Acceptance Criteria |
|---|---|---|---|---|---|---|---|
| **A06-08** | Final Sunny Nightmare: GLB + rig + LOD + 10 clips; replace P1 fallback. | `assets/characters/sunny/nightmare/*`, `scenes/characters/sunny_waking_nightmare.tscn`, `resources/characters/**` | A00, generation, A05 | P2 | 4–6 d + gen | High | 3 LOD; 10 clips; no P1 fallback; M1/M3 capture |
| **A06-20** | Final Hero/Shifty/Scholar/Veteran/BroadSlave: 5 GLB + rig + LOD + clips. | `assets/characters/cast/*`, `scenes/characters/npc/*`, profiles | A00, generation | P2 | 8–12 d + gen | High | 5 assets; LOD; clips; scenes; licenses |
| **A06-21** | Final Mountain King: UV/PBR, rig, 5 clips, LOD. | `assets/characters/monsters/mountain_king/*` | A05, generation | P2 | 4–6 d + gen | High | UV/PBR; 5 clips; LOD; A05 scene |
| **A06-22** | Carapace Centurion/Centipede/Worm Knot/Blood Flower: 4 GLB + rig + clips. | `assets/characters/monsters/*`, `assets/animations/monsters/*` | A05, generation | P2 | 8–12 d + gen | High | 4 assets; AI data A05; LOD; encounters |
| **A06-23** | Kai/Effie/Gunlaug/Black Knight/Great Devil: 5 GLB + rig + clips. | `assets/characters/cast/*`, `scenes/characters/**` | A01/A03, generation | P2 | 10–15 d + gen | High | 5 assets; scenes; clips; LOD; license |
| **A06-24** | Facial animation/blink/lip sync; 3 emotions. | `assets/characters/**`, `scripts/player/sunny_animator.gd` | A06-08/20 | P3 | 3–5 d | High | blink; 3 emotions; VO sync; no jaw break |
| **A06-25** | Finger animation: 2–3 gestures. | `assets/animations/**`, `resources/characters/**` | A06-24 | P3 | 1–2 d | Medium | 2–3 gestures; no clipping |
| **A06-26** | Ragdoll/death physics for 1–2 enemies. | `scenes/enemies/**` [request A05], `scripts/combat/**` [request A05] | A06-22, A05 | P3 | 2–4 d | High | 1–2 enemies; no bugs; A05 owns scene |

### 11.4. Mapping to existing backlog

| A06 task | Backlog | AGENT_TASKS |
|---|---|---|
| A06-01 | SS-029 | A06-01 |
| A06-02 | M1-05 | A06-02 |
| A06-06 | SS-016 | A06-06 |
| A06-05 | SS-120 | A06-05 |
| A06-07 | SS-054 | A06-07 |
| A06-10 | SS-121 | A06-10 |
| A06-04 | SS-078 | A06-04 |
| A06-09 | SS-031 | A06-09 |
| A06-03 | SS-030 | A06-03 |
| A06-08 | SS-050 | A06-08 |
| A06-14 | SS-056 | — |
| A06-15 | SS-055 | — |
| A06-16 | SS-057 | — |
| A06-17 | SS-117 | — |
| A06-19 | SS-122 | — |
| A06-20 | SS-051 | — |
| A06-21 | SS-052 | — |
| A06-22 | SS-053 | — |
| A06-24 | SS-099 | — |
| A06-25 | SS-100 | — |
| A06-26 | SS-101 | — |

### 11.5. Capacity check — важное расхождение

Суммарная идеальная трудоёмкость A06 P0 (M1) — **17–25 часов**:

| Задача | Идеальные часы |
|---|---:|
| A06-06 stability | 3–4 |
| A06-01 Jett | 3–4 |
| A06-02 Rock/Kasper/Cassia/Nephis | 4–6 |
| A06-11 Sunny M1 | 4–6 |
| A06-12 Carapace verify | 2–3 |
| A06-13 handoff | 1–2 |
| **Итого** | **17–25** |

Это **не влезает в один 3-часовой sprint** из `00_DEMO_SCOPE_AND_CONTRACT.md`, если A06 делает всё с нуля. Уже существующие v3 tree, P1 tree, `FootGrounder`, `GuardPose` и `Mannequin.WalkClean` сокращают часть работы, но не весь P0. Варианты для TD:

1. Растянуть A06 P0 на W1–W2 (рекомендуется).
2. Разделить A06 на двух исполнителей: «placeholders + Mannequin» и «Sunny/Carapace animation».
3. Сократить M1-каст до Jett + Cassia/Nephis (Rock/Kasper — только силуэты без отдельных профилей), если окно 3 часа жёсткое.

Без решения TD спецификация не обещает 3-часовой результат для всего A06 P0.

---

## 12. Branch / execution plan

### 12.1. Branch strategy

```text
feature/a06-character-animation
  ├─ A06-owned assets/characters, assets/animations
  ├─ A06-owned scenes/characters (except mountain_king.tscn)
  ├─ A06-owned scripts/player, scripts/slice/mannequin.gd
  ├─ A06-owned resources/characters
  ├─ A06-owned tools/anim
  └─ docs/demo_sprint/audits/characters_animation.md
```

- A06 branch **не содержит** правок `scenes/locations/**`, `scenes/enemies/**`, `resources/combat/**`, `tests/**`, `project.godot`.
- Для shared-зон A06 делает prefab/asset и передаёт A03/A05; интеграция — в их ветках.
- Коммит/merge — только A00.

### 12.2. Порядок

1. **W0:** TD lock, ownership, claim; A06-06 stability.
2. **W1 M1:** A06-01/02/11/12/13; A03 places; A10 targeted.
3. **W2 M1:** capture/QA; fix; A10 manual.
4. **W3 M1 gate:** A10 full GUT/build/manual.
5. **W4 tech demo:** A06-05/07/10/14/15/16/17/18/19; A05/A03 integrate.
6. **W5 M2/M3:** A06-03/04/09; final cast.
7. **W6 P2:** A06-08/20–26.

---

## 13. Открытые вопросы для TD

| # | Вопрос | Варианты | Рекомендация A06 |
|---|---|---|---|
| Q1 | Кому принадлежит `scripts/characters/**`? | A06 / shared / move to `scripts/player` | Закрепить за A06; иначе helpers в `scripts/player`/`scripts/slice` |
| Q2 | Единый риг финального каста? | 53-bone UE / 52-bone native / оба | 53-bone для всех финальных humanoid; native clips ретаргетить; v3/Hero временно 52 |
| Q3 | LOD0 budget для v3/Hero? | 50k / 60k / 84–90k exception | LOD0 50k, LOD1 20k, LOD2 8k; иначе exception для tech demo |
| Q4 | M1 placeholders приемлемы? | да / нет | Да, по MASTER_PLAN; финальный каст — M2/M3 |
| Q5 | Кто двигает weapon hitbox? | A05 / A06 / совместно | A05; A06 даёт socket/clip, A05 тестирует |
| Q6 | NPC AnimationTree — новый framework? | да / нет | Нет: shared `.tres` + Mannequin extension |
| Q7 | Procedural flinch в M1? | да / authored clips | Да для M1; authored — P1 |
| Q8 | Hyper3D кредиты/аккаунт? | web UI / CLI / stock | Web UI, по одному ассету; M1 не блокируется |
| Q9 | `white_horse_v2` ownership? | A06 / A10 | A06 asset/import; A10 verification |
| Q10 | Финальный Sunny Nightmare: v3 mesh или новая генерация? | v3 weight-transfer / new gen | New gen/approved concept; P1 fallback в M1 |
| Q11 | Facial/finger/ragdoll — P2/P3? | да / нет | P3; не блокирует M1/tech demo |
| Q12 | NPC gestures scope | 3 / 5 | 3 (wave/point/argue) |
| Q13 | A06 P0 не влезает в 3-часовой sprint (17–25 h) | растянуть W1–W2 / разделить A06 / сократить M1-каст | Растянуть W1–W2; 3 часа — только stability + один placeholder |

---

## 14. Acceptance / Definition of Done for A06

Задача A06 закрыта, если:

1. Изменены только A06-owned файлы или есть shared-file claim A00.
2. Нет нового autoload/animation framework/quest/inventory/HUD.
3. Targeted test запущен; вывод приложен; если не запускался — **NOT TESTED**.
4. Placeholder помечен в имени/профиле/отчёте.
5. Модель/клип прошли pipeline: tri/UV/tangents/rig/weights/LOD/import/scene.
6. Лицензия зарегистрирована в `docs/ASSET_LICENSES.md`.
7. A10 подтвердил targeted/full GUT и capture.
8. Нет T-pose, broken rig, floating parts, missing clips.
9. M1 gate не требует финальный каст; tech demo не выдаёт placeholder за финал.

---

## 15. Итог для Technical Director

- Спецификация готова; **игровые файлы не менялись**.
- M1 можно закрыть на A06-01/02/06/11/12/13 без Hyper3D.
- Tech demo требует A06-05/07/10/14–19; главный риск — sword combat и LOD.
- Финальный каст — отдельная внешняя волна; без кредитов Hyper3D она не начинается.
- Нужны решения TD по Q1–Q13, особенно Q1 (`scripts/characters/**`), Q2 (риг), Q3 (LOD budget), Q5 (hitbox ownership), Q13 (capacity).

## 16. Handoff to TD — что нужно решить до старта ветки A06

1. **Ownership:** закрепить `scripts/characters/**` за A06 или разрешить перенос helpers в `scripts/player/`/`scripts/slice/`.
2. **Rig standard:** 53-bone UE-style для финального каста; v3/Hero 52-bone — временно. Утвердить или выбрать «оба рига».
3. **LOD budget:** LOD0 ≤50k для hero; v3 84k/Hero 90k требуют decimate или официального exception.
4. **M1 placeholders:** подтвердить, что Jett/Rock/Kasper/Cassia/Nephis — помеченные placeholders, финальный каст M2/M3.
5. **Weapon hitbox:** A05 двигает hitbox на клинок; A06 даёт socket/clip. Подтвердить границу.
6. **Capacity:** A06 P0 = 17–25 идеальных часов; 3-часовой sprint не покрывает всё. Утвердить W1–W2 или сокращение M1-каста.
7. **Hyper3D:** подтвердить web UI/кредиты и правило «один ассет — приёмка — следующий»; без этого финальный каст не стартует.

**Конец спецификации.**
