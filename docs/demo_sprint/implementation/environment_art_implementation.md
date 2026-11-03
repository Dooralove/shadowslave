# Environment Art — Implementation Specification (Stage 2)

**Домен:** A07 — Environment Art / Technical Art  
**Дата:** 2026-11-03  
**Статус:** **спецификация, не реализация.** Игровые файлы в этом этапе не изменялись.  
**База:** `docs/demo_sprint/MASTER_AUDIT.md`, `MASTER_PLAN.md`, `BACKLOG.md`, `FILE_OWNERSHIP.md`, `INTEGRATION_CONTRACTS.md`, `design/world_layout.md`, `design/poi_manifest.md`, `design/side_quests.md`, `design/environment_art_direction.md`, `audits/environment_art.md`.  
**Ветка-предложение:** `a07-environment-stage2` от `s3-park-art` после freeze TD.  
**Правило:** до утверждения `MASTER_PLAN`/`FILE_OWNERSHIP` и этой спецификации A07 не меняет игровые сцены, скрипты, ресурсы и ассеты.

---

## 0. Короткий вывод

1. **A07 может выполнить почти всю работу в отдельной ветке**, не трогая файлы A03/A04/A05/A06/A08/A09/A10. Для этого вводится A07-owned `EnvironmentArtOverlay` + `EnvironmentArtProfile` под `scenes/environment/common/` и art-сцены под `scenes/environment/<location>/`. A03 добавляет по одной art-сцене в локацию; вся замена материалов, света, воды и сет-дрессинг происходит внутри A07-слоя.
2. **M1 (P05–B03/Z10) — приоритет.** A07-01…A07-06 делаются до M1 gate. Z11–Z18, SQ-FS-01…05, Z15/Z18, Z02/Z13 hero, decals и полный арт-пасс — после M1 PASS.
3. **Главный технический риск — не текстуры, а маршрут.** 28 ghost floor / 3238 deadly edges уже есть; арт не должен добавлять визуальные массы в проходимую зону. Все декоративные меши получают группы `art_visual_only`/`art_underfloor`; крупные массы в коридоре — `art_blocker` и переносятся/получают коллизию через A03.
4. **Главный производственный риск — бюджет.** Сейчас 907 мешей / ~4,95 млн tris / 1593 draw calls / 123,8 FPS / 857 МБ VRAM. Цель — <1500 draw calls и 2,5–3,5 млн tris; без MultiMesh/LOD/occlusion новые decals и растительность нельзя добавлять.
5. **M1 в 3 дня и полный A07-объём несовместимы.** Реальная оценка 3-дневного subset — 6–10 artist-days, полного M1-арта — 16–24, полного A07-объёма — 35–45 artist-days. TD должен выбрать: (а) M1-минимум с placeholders, (б) tech demo после M1, (в) полный арт-пасс. Это вынесено в §16.

---

## 1. Что входит и что не входит

### 1.1. Входит

- P05 `police_precinct`: материалы, свет, дождь/мокрые поверхности, реквизит, зеркало, камеры, двор.
- P06 `academy_approach`: дорога, КПП, машина/остановка, фонари, туман, силуэт академии.
- P07 `academy_gate`: красные ворота, стена, башни, звезда Академии, площадь, очередь.
- P08 `academy_campus`: галерея, колонны, корпуса, дорожки, вечерний свет.
- P09 `academy_sleeper_center`: 12 капсул, индукционный зал, медкрыло, холодный свет, туман.
- B01 `black_sea_platform`: статуя/звёзды/меч, платформа, море, Плащ, спуск.
- B02 `tide_descent`: коралловый спуск, арка, вода/мокрота, убрать cyan-glow.
- B03 Z01–Z10 (M1) и Z11–Z18 (tech demo): коралловый кит, свет, вода, прилив, сет-дрессинг, Z10 camp, Z15/Z18 полки, Z02/Z13 hero, decals.
- P05–B03 art-сцены, материалы, профили, ассеты, превью, QA-инструменты A07.
- S00–S15 art pass — только P2/M4, после M1/tech demo.

### 1.2. Не входит

- Новые gameplay-системы, autoload, QuestSystem, inventory, save, dialogue.
- Изменение `Generated/Collision`, `Spawns`, `Portals`, `Markers`, `Gameplay`, `TideController`.
- Изменение `labyrinth_first_fragment.gd`, `labyrinth_greybox.gd`, `scenes/locations/**` — это A03.
- Изменение UI/HUD, боевых формул, AI, character assets, VFX-сцен/скриптов.
- Полировка старого `coral_labyrinth` как финальной локации.
- Новые внешние ассеты/генерации без решения пользователя/TD.
- Массовая реализация Z11–Z18 до M1 PASS.

---

## 2. Текущий baseline

| Параметр | Факт | Источник |
|---|---|---|
| Лабиринт | 18 зон, 907 мешей, ~4,95 млн tris, 723 коллайдера, 19 камер | MASTER_AUDIT §2.5 |
| Арт | коралловый кит, статуя, кости, вода, дождь, небо | MASTER_AUDIT §2.9 |
| Производительность | 123,8 FPS, 857 МБ VRAM, 1593 draw calls | MASTER_AUDIT §2.15 |
| Коллизии | 3238 deadly edges, 28 ghost floor, 1 deadly jump | MASTER_AUDIT §2.5 |
| Геометрия | G1–G5 не закрыты | BACKLOG SS-005…SS-009 |
| M1 | Z01–Z10, финал у костра `POI-Z10-09` | MASTER_PLAN §4.2 |
| Tech demo | Z11–Z18, `FinalZone` | MASTER_PLAN §4.2 |
| M1 cast | Mannequin placeholders | MASTER_PLAN §6 |
| P05–B02 | Greybox/primitive, кроме статуи B01 | MASTER_AUDIT §2.4 |
| Z15/Z18 | плоские платформы; саммит +25 не построен | MASTER_AUDIT §2.9, BACKLOG SS-112 |
| Z02/Z13 | модульные туша/скелет, не hero | MASTER_AUDIT §2.9, BACKLOG SS-042/043 |
| Decals/растительность | отсутствуют | MASTER_AUDIT §2.9, BACKLOG SS-044/045 |

### 2.1. Уже сделанный Stage 1 art pass

В дереве уже есть:

- `scripts/locations/forgotten_shore_labyrinth/labyrinth_art.gd` — A07-owned арт-слой: стены/массы, опоры, Landmarks, вода/небо/дождь, decals, `bone_skull`.
- `assets/environments/nightmare/coral/*.glb` — 60 GLB кита + `bone_skull.glb`.
- `resources/locations/forgotten_shore_labyrinth/materials/*` — PBR-материалы примитивов, вода, дождь, `nm_skull_dark`.
- `docs/demo_sprint/audits/environment_art.md`, `design/environment_art_direction.md`.
- `docs/art/previews/forgotten_shore/environment_art/`.

**Но** в Stage 1 были изменения вне A07-owned зоны:

| Файл | Владелец | Что сделано | Действие Stage 2 |
|---|---|---|---|
| `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn` | A03 | Sun, SkyFill, вода, камеры, CampLight | A03 review/claim; A07 больше не правит |
| `scripts/locations/.../labyrinth_first_fragment.gd` | A03 | `ArtFinal` hook, удаление 11 corridor omni | A03 review/claim; A07 не правит |
| `scripts/locations/.../labyrinth_greybox.gd` | A03 | metadata `art_*` | A03 review/claim; A07 только читает |
| `resources/locations/forgotten_shore_labyrinth/env_labyrinth.tres` | A03 | AgX/fog/etc. | A03 review; A07 предлагает профиль |
| `resources/.../sky_labyrinth_material.tres` | A03 | shader-небо | A03 review; A07 предлагает ресурс |
| `tools/audit/location_capture.gd` | A10 | `--tide` | A10 review; A07 использует read-only |

Это **legacy cross-zone debt**. TD должен либо назначить A03/A10 claim и сохранить изменения, либо откатить их. A07 в своей ветке их не трогает.

---

## 3. Ownership и branch model

### 3.1. A07-owned (можно менять в ветке)

```text
assets/environments/forgotten_shore/**
assets/environments/post_nightmare/**
assets/environments/nightmare/**
assets/shaders/**
scenes/environment/common/**
scenes/environment/forgotten_shore/**
scenes/environment/post_nightmare/**
resources/locations/**/materials/**
scripts/locations/forgotten_shore_labyrinth/labyrinth_art.gd
tools/art/**
docs/art/**
docs/demo_sprint/design/environment_art_direction.md
docs/demo_sprint/audits/07_environment_art.md
docs/demo_sprint/audits/environment_art.md
docs/demo_sprint/implementation/environment_art_implementation.md
```

### 3.2. Не A07-owned (только integration package для владельца)

```text
scenes/locations/post_nightmare/*.tscn                  A03
scenes/locations/forgotten_shore_labyrinth/*.tscn       A03
scripts/locations/post_nightmare/*.gd                   A03
scripts/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.gd  A03
scripts/locations/forgotten_shore_labyrinth/labyrinth_greybox.gd         A03
resources/locations/**/env_*.tres, sky_*.tres           A03
scripts/quests/**, resources/quests/**                  A04/A02
scenes/characters/**                                     A06
scenes/environment/vfx/**, scripts/vfx/**, audio        A09
tests/**, tools/audit/**, qa/**                          A10
project.godot, licenses, master docs, claims             A00
```

### 3.3. Branch rules

1. A07 branch содержит только A07-owned пути.
2. A07 не коммитит и не push; коммит делает TD.
3. A03 integration package — отдельный список патчей/сцен, применяется A03 в своём окне.
4. Если A03 меняет геометрию/POI, A07 получает уведомление и обновляет art placement/профиль.
5. Перед правкой — `git status --short`, `ACTIVE_CLAIMS.md`, `FILE_OWNERSHIP.md`.
6. Если файл уже правит другой агент — не перезаписывать; писать в отчёт.

---

## 4. Архитектура A07: overlay + profile + art scenes

### 4.1. Проблема

P05–B02 — `GreyboxLocation`-сцены, собранные из примитивов в A03-скриптах. A07 не может править эти скрипты/сцены. Нельзя и просто «положить модели рядом»: примитивы останутся видимыми, материалы — плоскими, свет — старым.

### 4.2. Решение

A07 создаёт **три слоя**, все A07-owned:

```text
scenes/environment/common/
  environment_art_overlay.gd      # runtime-применение профиля к родительской локации
  environment_art_profile.gd      # Resource: env, material swaps, hide rules, light/water overrides
  environment_material_swap.gd    # Resource: from path -> Material
scenes/environment/post_nightmare/
  police_precinct_art.tscn
  academy_approach_art.tscn
  academy_gate_art.tscn
  academy_campus_art.tscn
  academy_sleeper_center_art.tscn
  black_sea_platform_art.tscn
  tide_descent_art.tscn
assets/environments/post_nightmare/
  police/**  academy/**  black_sea/**  tide_descent/**
assets/environments/forgotten_shore/
  coral/**  carcass/**  skeleton/**  decals/**  props/**  far/**
```

`police_precinct_art.tscn` — root `ArtOverlay` с `EnvironmentArtOverlay` и дочерними props/lights. A03 инстанцирует одну art-сцену в локацию. Overlay:

1. Ждёт `layout_built` родителя (или `call_deferred`).
2. Находит `Generated/Structure`, `Generated/Props`, `Generated/Visual`, `WorldEnvironment`, `Sun`, `Tide/WaterPlane`/`SeaBelow`.
3. Применяет `EnvironmentArtProfile`:
   - `environment: Environment` → `WorldEnvironment.environment`;
   - `material_swaps` → `material_override` на совпавших мешах;
   - `hide_name_prefixes`/`hide_name_contains` → скрывает примитивы (не удаляет);
   - `sun_rotation/color/energy`, `ambient`/fog overrides → существующие light/env;
   - `water_material` → вода;
   - `extra_lights`/`art props` — уже в art-сцене.
4. Никогда не меняет коллизии, Spawns, Portals, Markers, Gameplay, TideController.

### 4.3. Контракт art-сцены

```text
ArtOverlay (Node3D, environment_art_overlay.gd, profile)
├── Props (Node3D)      # статичный реквизит, без коллизии
├── Lights (Node3D)     # мотивированные источники
├── Decals (Node3D)     # projected decals
└── Debug (Node3D)      # только для preview, выключен в игре
```

Правила:
- root в `(0,0,0)`, без масштаба/поворота;
- `profile: EnvironmentArtProfile` задаёт env/material/hide/light/water;
- overlay ищет родителя через `get_parent()`, а не absolute path;
- overlay подключается к `layout_built`, если сигнал есть, иначе `call_deferred`;
- art-сцена не содержит `Spawns`, `Portals`, `Markers`, `Gameplay`, `Tide`, `Generated/Collision`;
- A03 инстанцирует ровно один `ArtOverlay` на локацию.

### 4.4. Почему это безопасно

- A03 не меняет свои скрипты; добавляет один child `ArtOverlay`.
- Overlay работает поверх blockout, не заменяет коллизию.
- Если A03 меняет материал/имя примитива, overlay просто не найдёт его и оставит как есть; ошибка не ломает сцену.
- A07 может тестировать art-сцену в отдельной preview-сцене без игровой локации.
- A07 может откатить всю арт-интеграцию, удалив один child.

### 4.5. Labyrinth

`labyrinth_art.gd` уже является A07-owned overlay-ом. Stage 2:

- добавить группы/meta `art_visual_only`, `art_underfloor`, `art_blocker`;
- добавить профиль `LabyrinthArtProfile` или расширить существующие константы;
- разделить placement на `M1`/`W4` секции;
- добавить runtime `MultiMesh` для seaweed/shells/bones;
- добавить `VisibilityRange` для дальних props;
- не менять `Generated/Collision`, `labyrinth_first_fragment.gd` (hook остаётся A03).

### 4.6. Что должен сделать A03 (integration package)

| Сцена | Действие A03 | Проверка |
|---|---|---|
| P05 | instance `police_precinct_art.tscn` as child `ArtOverlay` | `test_post_nightmare_locations`, capture |
| P06 | instance `academy_approach_art.tscn` | то же |
| P07 | instance `academy_gate_art.tscn` | то же |
| P08 | instance `academy_campus_art.tscn` | то же |
| P09 | instance `academy_sleeper_center_art.tscn` | то же |
| B01 | instance `black_sea_platform_art.tscn` | то же |
| B02 | instance `tide_descent_art.tscn` | то же |
| B03 | сохранить `ArtFinal` hook / `labyrinth_art.gd` | GUT 13/13, capture |
| Z10 | не перекрывать `POI-Z10-09`/`DemoEndZone` | M1 gate |
| Z15/Z18 | G1–G5, +25 summit, final platform | route_walk/boundary |

**A07 не делает эти правки сам.**

---

## 5. Что исправить в существующих элементах

| ID | Проблема | Где | Действие A07 | Владелец сцены |
|---|---|---|---|---|
| F-01 | P05/academy — плоские примитивы, нет PBR/света | P05–P08 | материалы, art scenes, light profiles | A07 + A03 |
| F-02 | Sleeper Center без индукционного зала/капсул | P09 | capsule kit, induction ring, light | A07 + A03 |
| F-03 | B01 спуск/море primitive; Плащ не читается | B01 | platform/sea/shroud/stars art | A07 + A03 |
| F-04 | B02 cyan-glow, primitive arch/stairs | B02 | coral arch, wet stone, remove cyan via overlay | A07 + A03 |
| F-05 | Z10 camp пустой, DemoEndZone не оформлен | Z10 | 6+ props, fire/pillar, end-zone frame | A07 + A03 |
| F-06 | Z15/Z18 плоские платформы | Z15/Z18 | coral shelf/mesa kit | A07 + A03 |
| F-07 | Z02 модульная туша | Z02 | hero carcass | A07 (A06 optional) |
| F-08 | Z13 модульный скелет | Z13 | hero skull/spine/ribs | A07 |
| F-09 | Нет decals крови/когтей/мокрых следов | Z02/Z13/Z14 | 1K atlas + Decal | A07 |
| F-10 | Нет водорослей/ракушек/мокрых камней | Z01–Z18 | MultiMesh kit | A07 |
| F-11 | 28 ghost floor / 3238 deadly edges | Labyrinth | tag art, move blockers, A03 collision | A07 + A03/A10 |
| F-12 | 1593 draw calls >1500 | Labyrinth | MultiMesh/LOD/occlusion/merge | A07 + A03/A10 |
| F-13 | Z10/Z15 лагерь без мяса/верёвок/мешков | Z10/Z15 | 6+ camp props | A07 |
| F-14 | Дальний горизонт/остров/sea stacks | Z17/Z18 | far silhouettes | A07 |
| F-15 | `env_coral`/post-nightmare sky bug | post-nightmare | verify Sky wrappers; A03 claim | A07/A03 |
| F-16 | P05/academy snow/weather не подтверждён каноном | P06–P08 | не добавлять снег без решения; wet asphalt | A07 + A01/TD |
| F-17 | S00–S15 тёмные альков/пещера/святилище | M4 | lighting pass (P2) | A07 + A03 |

---

## 6. Новые элементы

### 6.1. Asset families (минимальный набор)

| Семейство | Варианты | Tris LOD0 | Где | Приоритет |
|---|---|---:|---|---|
| `carcass_shark_hero` | 1 | 15–25k | Z02 | P1 (M3) |
| `giant_skeleton_hero` | 1 | 15–25k | Z13 | P1 (M3) |
| `bone_skull` | есть | 1,8k | Z02/Z13 | baseline |
| `coral_shelf` a/b/c | 3 | 8–14k | Z15/Z18 | P1 (M3) |
| `coral_mesa` a/b/c | 3 | 10–18k | Z18 | P1 (M3) |
| `seaweed` a/b/c | 3 | 0,3–1k | Z01–Z18 | P1 |
| `shell_cluster` a/b/c | 3 | 0,3–0,8k | Z01–Z18 | P1 |
| `coral_brain/fan/crust/rubble` | 2–3 each | 1–4k | Z01–Z18 | P2 |
| `camp_meat_rack`, `rope_coil`, `camp_supplies` | 2–3 | 0,3–1k | Z10/Z15 | P1 |
| `azure_blade`, `soul_shard`, `token`, `cloak`, `salt_box`, `echo_polyp`, `bone_trophy` | 1–2 each | 0,2–2k | SQ-01…05 | P1 (M3) |
| `academy_capsule`, `academy_lamp`, `academy_bench`, `academy_gate_star`, `academy_fence_module` | 1–3 | 1–6k | P05–P09 | P0 (M1) |
| `police_bed`, `police_locker`, `police_desk`, `mirror_frame` | 1–2 | 0,5–3k | P05 | P0 (M1) |
| `black_sea_shroud`, `statue_star` | 1–2 | 0,5–2k | B01 | P0 (M1) |
| `far_island`, `sea_stack` | 2–3 | 2–6k | Z17/Z18 | P2 |
| `decals_atlas_1k` | 6 decals | — | Z02/Z13/Z14 | P1 |

**Не делать** «сотни» новых ассетов: M1 minimum — ~20–25 новых/переработанных props + 3 hero; tech demo — +15–20. Остальное — существующий кит.

#### 6.1.1. M1 asset list (минимум)

| Файл / семейство | Назначение | Tris LOD0 | Материал |
|---|---|---:|---|
| `police_bed_a.glb` | койка Санни/камеры | 1–2k | `art_police_metal` + linen |
| `police_locker_a.glb` | шкафчик «дом» | 1–2k | `art_police_metal` |
| `police_desk_a.glb` | стойка/допрос | 1–3k | `art_police_wood/metal` |
| `mirror_frame_a.glb` | зеркало допросной | 0,5–1k | `art_police_mirror` |
| `academy_gate_star_a.glb` | звезда Академии | 0,5–1k | `art_academy_star` |
| `academy_fence_module_a.glb` | забор/КПП | 1–2k | `art_academy_metal` |
| `academy_bench_a.glb` | очередь/скамьи | 0,5–1k | `art_academy_wood` |
| `academy_lamp_a.glb` | фонарь | 0,5–1k | `art_academy_metal` + emissive |
| `academy_terminal_a.glb` | терминал кампуса | 0,5–1k | `art_academy_glass` |
| `academy_capsule_a.glb` | 12 капсул | 2–4k | `art_sleeper_glass/metal` |
| `academy_induction_ring_a.glb` | индукционное кольцо | 1–3k | `art_sleeper_ring` |
| `black_sea_shroud_a.glb` | Плащ на статуе | 0,5–1k | `art_shroud` |
| `camp_meat_rack_a.glb` | лагерь Z10 | 0,5–1k | wood/bone |
| `camp_rope_a.glb` | верёвки | 0,2–0,5k | `art_rope` |
| `camp_supplies_a.glb` | мешки/фляги | 0,2–0,6k | leather/cloth |
| `decals_atlas_1k.png` | 6 decals | — | `art_decal_*` |

#### 6.1.2. M3 asset list

| Файл | Назначение | Tris LOD0 |
|---|---|---:|
| `carcass_shark_hero.glb` | Z02 hero-туша | 15–25k |
| `giant_skeleton_hero.glb` | Z13 hero-скелет | 15–25k |
| `coral_shelf_a/b/c.glb` | Z15/Z18 полки | 8–14k |
| `coral_mesa_a/b/c.glb` | Z18 финал | 10–18k |
| `seaweed_a/b/c.glb` | MultiMesh | 0,3–1k |
| `shell_cluster_a/b/c.glb` | MultiMesh | 0,3–0,8k |
| `azure_blade_a.glb` | Z03 pickup | 1–2k |
| `soul_shard_a.glb` | Z06/Z09/Z14 | 0,1–0,3k |
| `ninth_token_a.glb` | SQ-01 | 0,2–0,5k |
| `cloak_a.glb` | SQ-02 | 0,3–0,8k |
| `salt_box_a.glb` | SQ-04 | 0,3–0,8k |
| `echo_polyp_a.glb` | SQ-02 | 2–5k |
| `far_island_a/b.glb` | горизонт | 2–6k |
| `sea_stack_a/b/c.glb` | Z17/Z18 | 3–6k |

### 6.2. Art scenes

| Art scene | Назначение | M1? |
|---|---|---|
| `police_precinct_art.tscn` | props/lighting/rain/mirror | да |
| `academy_approach_art.tscn` | road/checkpoint/car/lights | да |
| `academy_gate_art.tscn` | gate/star/towers/plaza | да |
| `academy_campus_art.tscn` | gallery/columns/paths | да |
| `academy_sleeper_center_art.tscn` | capsules/induction/light | да |
| `black_sea_platform_art.tscn` | platform/sea/shroud/stars | да |
| `tide_descent_art.tscn` | coral arch/ramp/wet | да |
| `labyrinth_art` layer | Z01–Z18 | Z01–Z10 M1; Z11–Z18 W4 |
| `forgotten_shore/art_preview.tscn` | dev preview only | — |

### 6.3. Materials

M1:
- `art_police_concrete`, `art_police_tile`, `art_police_metal`, `art_police_glass`, `art_police_mirror`, `art_police_rain`.
- `art_academy_asphalt`, `art_academy_concrete`, `art_academy_red`, `art_academy_metal`, `art_academy_glass`, `art_academy_star`.
- `art_sleeper_white`, `art_sleeper_glass`, `art_sleeper_ring`, `art_sleeper_floor`.
- `art_black_sea_stone`, `art_black_sea_water` (reuse `nm_tide_water`), `art_shroud`, `art_star`.
- `art_tide_coral`, `art_tide_wet_stone`, reuse `nm_coral_live`.

M3:
- `art_shelf_rock`, `art_shelf_wet`, `art_carcass_flesh`, `art_carcass_bone`, `art_skeleton_bone`, `art_seaweed`, `art_shell`, `art_salt`, `art_decal_blood`, `art_decal_claw`, `art_decal_wet`.

Все — PBR, 1K/2K, external `.tres`, world-triplanar где возможно. Не использовать flat `StandardMaterial3D` в близком кадре.

### 6.4. Lighting profiles

| Scene | Профиль |
|---|---|
| P05 | холодный флуоресцентный верх, тёплая лампа допросной, синий маяк во дворе, дождь за окнами |
| P06 | пасмурный рассвет/вечер, фары машины, тёплый КПП, мокрый асфальт, туман |
| P07 | прожекторы ворот, красный камень/металл, звезда Академии emissive, холодная площадь |
| P08 | вечерние окна, тёплые фонари, мокрая плитка, синий час |
| P09 | холодный медицинский белый, индукционное кольцо, капсулы, туман |
| B01 | чёрное море, статуя key light, звёзды/меч, Плащ |
| B02 | бледный риф, вода/мокрая линия, коралловая арка |
| Z10 | тёплый костёр, пасмурный/закатный верх, столб |
| Z15/Z18 | шторм, холодный fill, молнии (A09), дождь |

---

## 7. Файлы и ресурсы

### 7.1. A07 files (create/modify)

| Путь | Что |
|---|---|
| `scripts/locations/forgotten_shore_labyrinth/labyrinth_art.gd` | M1/W4 art layer, tags, MultiMesh, profiles |
| `scenes/environment/common/environment_art_overlay.gd` | runtime overlay |
| `scenes/environment/common/environment_art_profile.gd` | Resource profile |
| `scenes/environment/common/environment_material_swap.gd` | Resource swap |
| `scenes/environment/post_nightmare/*.tscn` | 7 art scenes |
| `scenes/environment/forgotten_shore/art_preview.tscn` | dev preview |
| `assets/environments/post_nightmare/**` | P05–B02 assets |
| `assets/environments/forgotten_shore/**` | Z02/Z13/shelves/decals/seaweed/far |
| `assets/environments/nightmare/**` | existing kit exports/updates |
| `assets/shaders/**` | new shaders if needed |
| `resources/locations/post_nightmare/materials/art_*.tres` | M1 materials |
| `resources/locations/forgotten_shore_labyrinth/materials/*.tres` | M3 materials/decals |
| `tools/art/**` | build/validate/capture/perf/preview |
| `docs/art/**` | previews/manifests |
| `docs/demo_sprint/...` | art direction/audit/implementation |

### 7.2. Existing resources to reuse

- 60 GLB coral kit + `bone_skull.glb`.
- `assets/environments/nightmare/remains/`, `mountain/`, `temple/`, `caravan/`, `site/`.
- Poly Haven CC0: `coral_fort_wall_01/02/03`, `coral_ground_02`, `coral_mud_01`, `low_tide_rocks`, `coral_gravel`, `damp_beach_sand` (staged; register).
- `statue_knight_colossus.glb` + LOD1/2 (CC BY 4.0).
- Existing `nm_layered_triplanar`, `nm_coral_triplanar`, `nm_tide_water`, `sky_labyrinth`, `nm_rain_curtain`.
- Existing `p3_blood.png`, `p3_footprint.png`, `p3_chain_scrape.png` for decals (project-owned).

**KayKit / Quaternius:** локально отсутствуют; CC0 low-poly стилистически не совпадают с semi-realistic PBR рифа. В A07-ветке не используются. Новые внешние пакеты — только по решению пользователя/TD и с записью в `docs/ASSET_LICENSES.md` (A00).

### 7.3. Budget

| Ресурс | Бюджет |
|---|---|
| Новые текстуры | 1K decals/seaweed/shells; 2K только hero; без 4K |
| VRAM | <4 ГБ, цель ≤1,2 ГБ |
| Tris | 2,5–3,5 млн отрисованных; текущий 4,95 млн — сначала сократить |
| Draw calls | <1500; текущий 1593 |
| LOD | 3 уровня для hero; auto-LOD для kit |
| MultiMesh | seaweed/shells/bones/rubble |
| Collision | ноль новой коллизии в art-слоях; hero base — box/cylinder |
| Git LFS | `.glb`, `.png`, `.jpg`, `.blend`; текстовые — plain |

---

## 8. Инструменты

| Инструмент | Использование | Ограничение |
|---|---|---|
| Blender 5.1 background | новые GLB, kit, LOD, UV/tangents | скрипты в `source/`; MCP — только осмотр |
| `nm_lib.py`, `nm_coral_lib.py`, `nm_props.py` | генерация, masks, collision, export | не дублировать |
| `nm_coral_materials.py`, `make_coral_textures.py`, `make_godot_materials.py` | материалы/текстуры | external `.tres` |
| glTF-Transform 4.5.1 | inspect/validate/optimize/dedup | LOD0/1/2 |
| Krita 5.3.4.1 / Pillow | decals, atlas, cleanup | 1K atlas |
| Materialize 1.78 | normal/roughness/height | только если нужно |
| Godot 4.7.2 headless | import, GUT, capture, perf | MCP editor не обязателен |
| A07 `tools/art/` | preview, capture, perf, POI clearance, asset validate | A10 tools read-only |
| `git diff --check` | whitespace/secret check | — |

**Не использовать:** Material Maker/MaterialPilot (экспериментально), Hyper3D/Meshy для финального A07-ассета без решения пользователя, новые MCP/плагины.

---

## 9. Зависимости и интеграция

| Специалист | Что даёт A07 | Что A07 даёт | Контракт |
|---|---|---|---|
| A00 TD | freeze, ownership, shared-file claims, licenses, `project.godot` | спецификация, asset manifest, integration package | A07 не коммитит; shared files — через A00 |
| A03 World/Level | сцены, POI, коллизии, G1–G5, Z15 +25, Z18 final, art hook | art scenes/profiles/assets | A03 инстанцирует art scene; A07 не правит сцены |
| A02 Side Quest | SQ точки/ID/текст | props: token, traces, cloak, polyp, salt box, lair | A02 задаёт точку, A07 — визуал, A03/A04 — placement |
| A04 Gameplay | QuestPickup/NPC/trigger, flags | pickup visual meshes | A07 не меняет `scripts/quests/**` |
| A05 Combat | E01–E03, telegraphs, weak spot | читаемые арены/силуэты, свет | A07 не меняет бой |
| A06 Character | NPC scale/rig, placeholders | материалы окружения, не character assets | A07 не правит `assets/characters/**` |
| A08 UI | HUD/tide/final cards | контраст фона, lighting | A07 не правит UI |
| A09 Audio/VFX | rain/lightning/spray/audio | water/fog/surfaces, VFX anchors | A07 не правит VFX scenes |
| A10 QA | GUT/route/boundary/perf/captures | tags/groups, art previews | A07 запускает read-only, не правит tests/tools |

### 9.1. Integration package для A03 (создаёт A07, применяет A03)

1. Добавить `ArtOverlay` child в P05–B02.
2. Сохранить `ArtFinal` hook в B03.
3. Не менять `Generated/Collision`, Spawns, Portals, Markers, Gameplay, Tide.
4. После instancing — `test_post_nightmare_locations` / `test_labyrinth_first_fragment`.
5. Для B01/B02 — A03 geometry fixes (ramp/stairs) до art placement.
6. Для Z15/Z18 — A03 geometry (G1–G5, +25, final platform) до A07-07a/12.

### 9.2. Integration package для A10

- Игнорировать `art_visual_only`/`art_underfloor` в ghost-floor/hanging counters.
- Отдельно считать `art_blocker`; 0 на main route.
- Использовать A07 groups; не менять art-геометрию.
- Perf/capture после каждого A07 art scene.

---

## 10. Ошибки и конфликты

| ID | Риск | Вероятность/влияние | Митигация |
|---|---|---|---|
| R-01 | A07 правит A03-файлы | H/H | branch isolation, integration package, claims |
| R-02 | Art mass blocks route / ghost floor | H/H | tags, POI no-decor radii, A03/A10 route audit |
| R-03 | Draw calls/tris растут | H/H | MultiMesh/LOD/merge, budget gate |
| R-04 | Overlay `_ready` раньше `layout_built` | M/M | connect `layout_built` + deferred |
| R-05 | Material path/name mismatch | M/M | profile swaps by path/name; fallback keep |
| R-06 | Missing external material / pink meshes | M/M | `.import` external `.tres`, import check |
| R-07 | Z15 +25 / Z18 geometry not built | H/H | A03 dependency, defer A07-07a1/a2/12a |
| R-08 | Hero carcass/skeleton quality/time | H/M | modular baseline, LOD, M3 post-M1 |
| R-09 | M1 3-day scope vs full art | H/H | TD chooses 6?10-day subset or moves M1 gate; placeholders marked |
| R-10 | Lighting too dark/overbright | M/M | 3-angle captures, AgX, contrast check |
| R-11 | Decals z-fighting/overdraw | M/M | projected decals, fade, limit size |
| R-12 | MultiMesh culling/LOD pop | M/M | visibility range, LOD test |
| R-13 | New external asset license | L/H | no new assets without A00/user |
| R-14 | `MCPRuntime`/parse errors block QA | M/M | headless import/GUT; A10 owns |
| R-15 | SQ props overlap pickup radius | M/H | A02/A04 POI check, no-decor radius |

---

## 11. Как проверять готовность

### 11.1. Общие gates

```powershell
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_post_nightmare_locations.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_labyrinth_first_fragment.gd -gexit
godot --headless --path . -s tools/audit/boundary_audit.gd -- --out=<temp> --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn --step=1.5 --jump=1
gltf-transform validate <asset>.glb
gltf-transform inspect <asset>.glb
```

A07 также использует `tools/art/art_capture.gd`, `art_perf.gd`, `asset_validate.py`, `poi_clearance_check.gd` (создать в A07-00).

### 11.2. Per-element acceptance

| Элемент | Проверка |
|---|---|
| P05 art | 3 кадра (spawn/mirror/yard), 1,5 м материалы, mirror читается, rain/wet, `test_post_nightmare_locations` 15/15, draw delta <120 |
| P06 art | 3 кадра (car/checkpoint/approach), read academy silhouette, wet road, draw delta <120 |
| P07 art | 3 кадра (approach/gate/plaza), red gate/star, silhouette, draw delta <120 |
| P08 art | 3 кадра (gate/gallery/north), evening light, no flat walls, draw delta <120 |
| P09 art | 3 кадра (dorm/induction/medical), 12 capsules, cold light, no collision change |
| B01 art | 3 кадра (neck/chest/sword), stars/sword/shroud/sea, no collision change |
| B02 art | 3 кадра (top/stairs/arch), coral/wet/no cyan, ramp pass |
| Z10 camp | 3 кадра (approach/camp/night), 6+ props, DemoEndZone clear, GUT |
| Z15/Z18 | route capture, no flat platform silhouette, boundary unchanged, no `art_blocker` |
| Z02 carcass | hero asset preview + 3 in-game angles, LOD, no route block |
| Z13 skeleton | hero preview + 3 angles, no route block, no ghost floor |
| Decals | 6 types, 1K atlas, no z-fight, draw calls delta <20 |
| Seaweed/shells | MultiMesh, 200+ instances, <20 draw calls, no physics |
| Materials | no pink/black, normal/roughness/AO, 1,5 м close-up |
| Lighting | 1080p ≥60, contrast, no black tunnels, no blown whites |
| Draw calls | <1500 at 1080p, tris 2,5–3,5M or TD exception |
| Every asset | GLB valid, origin/scale, LOD, material slots, preview, license/manifest |

### 11.3. Evidence

- `docs/art/previews/forgotten_shore/environment_art/` — low/high tide.
- `docs/art/previews/post_nightmare/` — P05–B02.
- `docs/art/previews/forgotten_shore/heroes/` — carcass/skeleton/shelves.
- `docs/art/environment_asset_manifest.md` — tris/LOD/material/license/scene.
- A07 capture/preview scenes; A10 captures remain read-only.

---

## 12. Список задач

> **Effort** — artist-days (реалистично, не «идеально»). **Risk** — L/M/H с причиной.  
> **A07-00, A07-11…A07-14** — новые spec-level ID; TD должен добавить их в `AGENT_TASKS.md` или переназначить.

| Task ID | Description | Files | Dependencies | Priority | Effort | Risk | Acceptance Criteria |
|---|---|---|---|---|---:|---|---|
| **A07-00** | Environment art overlay/profile infra, art-scene template, preview/validation harness, baseline captures | `scenes/environment/common/*.gd`, `tools/art/**`, `docs/art/environment_asset_manifest.md` | A00 lock; A03 scene contract | P0 | 2–3 | M — ready order/shared contract | overlay applies env/material/light/water to dev scene; import 0; no collision changes; A03 instancing test |
| **A07-01** | P05 police precinct art: materials, lighting, rain/wet, props, mirror, yard | `scenes/environment/post_nightmare/police_precinct_art.tscn`, `assets/environments/post_nightmare/police/**`, `resources/locations/post_nightmare/materials/art_police_*` | A03 P05 geometry/POI; A07-00 | P0 | 2–3 | M — greybox mismatch | 3 angles; 1,5 м PBR; mirror; rain/wet; draw delta <120; test 15/15 |
| **A07-02a** | P06 academy approach: road, checkpoints, car, lamps, wet asphalt | `academy_approach_art.tscn`; `assets/.../academy/approach/**` | A03 P06; A07-00 | P0 | 1,5–2,5 | M — coords/car | 3 angles; wet road; car/checkpoint; draw delta <100; test 15/15 |
| **A07-02b** | P07 academy gate: red gate, star, towers, plaza, queue props | `academy_gate_art.tscn`; `assets/.../academy/gate/**` | A03 P07; A07-00 | P0 | 1,5–2,5 | M — gate silhouette | 3 angles; gate/star/towers; draw delta <100; test 15/15 |
| **A07-02c** | P08 campus: gallery, columns, paths, evening light | `academy_campus_art.tscn`; `assets/.../academy/campus/**` | A03 P08; A07-00 | P0 | 1,5–2,5 | M — 3 zones | 3 angles; gallery/columns; draw delta <100; test 15/15 |
| **A07-03** | Sleeper Center: capsule kit, induction hall, medical light | art scene; `assets/.../sleeper/**`; `art_sleeper_*` | A03 P09; A07-00 | P0 | 3–5 | M — 12 capsules/room | 12 capsules; induction ring; cold light; no collision change; capture |
| **A07-04** | B01: platform/sea/shroud/stars/sword art | art scene; `assets/.../black_sea/**`; materials | A03 B01; A07-00 | P0 | 2–3 | M — statue/sea | 3 angles; stars/sword/shroud; no collision change; capture |
| **A07-05** | B02: coral arch/ramp/wet descent; remove cyan via overlay | art scene; `assets/.../tide_descent/**`; materials | A03 B02 ramp; A07-00 | P0 | 1,5–2,5 | M — ramp/collision | 3 angles; coral/wet; no cyan; ramp pass |
| **A07-06** | Z10 camp: 6+ props, fire/pillar, DemoEndZone frame | `labyrinth_art.gd`; `assets/.../camp/**`; materials | A03 Z10; A07 hook | P0 | 2–3 | M — end-zone | 6+ props; DemoEndZone clear; GUT 13/13; capture |
| **A07-07a1** | Z15 coral shelf/mesa; remove flat refuge platform silhouette | `assets/.../shelves/z15/**`; `labyrinth_art.gd`; materials | A03 G1–G5/Z15; M1 PASS | P1 (M3) | 3–5 | H — geometry/route | route capture; no flat platform; boundary unchanged; no art_blocker |
| **A07-07a2** | Z18 cliffs/final backdrop coral mesas; remove final table | `assets/.../shelves/z18/**`; `labyrinth_art.gd`; materials | A03 Z18 final; M1 PASS | P1 (M3) | 3–5 | H — final geometry | final capture; no flat table; portal/final clear |
| **A07-07b** | Z02 hero carcass (jaw/ribs/flesh, LOD) | `assets/.../carcass/**`; `labyrinth_art.gd` | A03 Z02/SQ-01; M1 PASS | P1 (M3) | 5–7 | H — hero quality | preview + 3 angles; LOD; no route block; tri budget |
| **A07-07c** | Z13 hero skeleton (skull/spine/ribs, LOD) | `assets/.../skeleton/**`; `labyrinth_art.gd` | A03 Z13; M1 PASS | P1 (M3) | 4–6 | H — hero quality | preview + 3 angles; no route block; no ghost floor |
| **A07-07d** | Decals: azure blood, claws, drag, wet; 1K atlas | `assets/.../decals/**`; materials; `labyrinth_art.gd` | A07-07a1/a2/b/c; A03 Z02/Z13/Z14 | P1 (M3) | 2–3 | L/M — z-fight | 6 types; no z-fight; draw delta <20; capture |
| **A07-08a** | PBR/material library: P05–B03, shelves, carcass, skeleton, decals | `resources/locations/**/materials/**`; `assets/shaders/**` | A07-00 | P1 | 2–3 | M — import/material paths | 8–12 materials; no pink/black; 1,5 м close-up |
| **A07-08b** | Seaweed/shells/wet rocks MultiMesh kit | `assets/.../seaweed|shells/**`; `labyrinth_art.gd` | A07-08a; A03 zones | P1 | 2–3 | M — draw calls | 200+ instances; <20 draw calls; no physics; capture |
| **A07-09** | Lighting/atmosphere/captures: P05–B03, AgX/fog/3-point, tide/storm support | art profiles; `tools/art/**`; docs | A07-01…06; A09 VFX | P1 | 3–5 | M — readability | 3 angles/scene; 1080p ≥60; no black tunnels; captures |
| **A07-10** | Draw calls <1500: MultiMesh/LOD/occlusion/merge, profiling | `labyrinth_art.gd`; art scenes; materials; `tools/art/**` | A07-07/08; A03/A10 | P1 | 4–6 | H — budget | 1080p <1500; tris 2,5–3,5M or TD exception; no visual regression |
| **A07-11** | SQ visual props: token, traces, Theo bed, polyp, cloak, salt box, lair, trophy | `assets/.../quests/**`; materials | A02/A03/A04 SQ POIs; A07-08 | P1 (M3) | 3–5 | M — placement | props match POIs; no pickup radius overlap; capture; tests |
| **A07-12a** | Z15 summit +25 and Z18 finale art; storm debris | `assets/.../z15_z18/**`; `labyrinth_art.gd`; env profile | A03 Z15/Z18; A09 storm; M1 PASS | P1 (M3) | 2–3 | M/H — geometry | summit/final capture; no collision change; no FPS regression |
| **A07-12b** | Far island/sea stacks, horizon silhouettes, LUT/vignette | `assets/.../far/**`; `resources/.../materials/**`; env profile | A07-12a; A09; M1 PASS | P2 | 2–3 | M — horizon/LUT | 3 far silhouettes; LUT in 3 scenes; capture |
| **A07-13** | S00–S15 art pass (P2): alcove/cave/sanctuary lighting, props | `assets/environments/nightmare/**`; art profiles; docs | M1/tech demo PASS | P2 | 8–12 | H — many scenes | 6 scenes captured; readable; no route/collision changes |
| **A07-14** | Asset manifest/licensing/QA: every asset tris/LOD/material/scene/preview/license | `docs/art/environment_asset_manifest.md`; `tools/art/**` | all A07 tasks | P1 | 1,5–2 | L — bookkeeping | manifest complete; import 0; no unlicensed asset; previews |

### 12.1. M1 minimum (если 3-дневный спринт)

Если TD подтверждает 3 дня, реально выполним только минимальный subset:

- A07-00 (2–3 дня) — infra/QA.
- A07-01 (2–3 дня) — P05.
- A07-02a/02b overlay-материалы/свет (2–3 дня без hero props).
- A07-06 (1–2 дня) — Z10 camp.

Это 6–10 artist-days; P08/P09/B01/B02 остаются placeholders. Полный M1-арт (A07-01…06) — 16–24 artist-days. TD должен выбрать явно.

---

## 13. Порядок выполнения

| Волна | Задачи | Условие |
|---|---|---|
| **W0** | TD freeze, claims, A07-00 | MASTER_PLAN/FILE_OWNERSHIP утверждены |
| **W1 (M1)** | A07-01…A07-06, A07-09/10 partial | A03 G1–G5/P05–Z10 geometry |
| **W2 (M1 QA)** | A07-09/10, A07-14, captures | M1 content/flags |
| **W3 (M1 gate)** | M1 PASS | GUT, build, manual, flags |
| **W4 (tech demo)** | A07-07a…d, A07-08, A07-11, A07-12 | M1 PASS; A03 Z11–Z18 |
| **W5** | A07-13 S00–S15 | tech demo PASS |

**Правило:** W4 не начинается до M1 PASS. Z11–Z18 не трогать в M1.

---

## 14. Матрица приёмки по сценам

| Сцена | M1 | Tech demo | Арт-минимум | Полный арт |
|---|---|---|---|---|
| P05 | да | — | A07-01 | A07-01 + props |
| P06 | да | — | A07-02 overlay | полный academy kit |
| P07 | да | — | A07-02 overlay | gate hero |
| P08 | да | — | A07-02 overlay | campus kit |
| P09 | да | — | A07-03 capsules | induction hall |
| B01 | да | — | A07-04 | shroud/sea hero |
| B02 | да | — | A07-05 | coral arch hero |
| Z01–Z10 | да | — | current art + A07-06/09/10 | A07-07b/d, 08 |
| Z11–Z18 | нет | да | current art + A07-12 | A07-07a/c, 11, 12 |
| S00–S15 | нет | нет | — | A07-13 (P2) |

---

## 15. Definition of Done для A07

- [ ] Все A07-файлы в ветке; нет правок A03/A04/A05/A06/A08/A09/A10.
- [ ] `--import` exit 0; targeted GUT 0 fail.
- [ ] Каждая art scene имеет 3+ capture, 1,5 м close-up, no pink/black.
- [ ] Нет `art_blocker` на main route; boundary metrics не хуже baseline.
- [ ] 1080p ≥60 FPS; draw calls <1500 или TD exception; VRAM <4 ГБ.
- [ ] LOD/MultiMesh/occlusion проверены; нет LOD pop.
- [ ] Все ассеты в manifest: tris, LOD, materials, scene, license, preview.
- [ ] Нет новых внешних ассетов без A00/user.
- [ ] HUD/quests/tide/portals/spawns не изменены.
- [ ] Ручной проход и полный GUT — только если A10 подтвердил; иначе **NOT TESTED**.

---

## 16. Спорные вопросы для Technical Director

1. **Legacy cross-zone debt.** В дереве уже есть Stage 1 изменения `labyrinth_first_fragment.tscn`, `labyrinth_first_fragment.gd`, `labyrinth_greybox.gd`, `env_labyrinth.tres`, `sky_labyrinth_material.tres`, `tools/audit/location_capture.gd`. Назначить A03/A10 claims и сохранить — или откатить? A07 в своей ветке их не трогает.
2. **Overlay architecture.** Разрешить A07-owned `EnvironmentArtOverlay`/`EnvironmentArtProfile` под `scenes/environment/common/` и art scenes под `scenes/environment/<location>/`? Это не autoload и не gameplay-система, но новый runtime-код.
3. **Environment resource ownership.** A07 предлагает env/sky/water профили в `assets/environments/**`, overlay применяет их runtime; альтернатива — A03 статически меняет `env_labyrinth.tres`/`WorldEnvironment`. Какой вариант канонический?
4. **Ghost floor semantics.** A10 должен игнорировать `art_visual_only`/`art_underfloor` и отдельно считать `art_blocker`; иначе 28 ghost floor будут вечно «красными». Утвердить формулу.
5. **M1 scope vs 3 дня.** 3-дневный subset — 6–10 artist-days; полный M1-арт — 16–24. Что режем: P08/P09/B01/B02 до placeholders или сдвигаем M1 gate?
6. **Hero carcass/skeleton pipeline.** SS-042 указывает Hyper3D + 06; A07 предлагает Blender-модульный hero (без внешней генерации). Какой pipeline утверждается?
7. **Z15 +25 и Z18 finale.** A03 должен построить геометрию/маршрут; A07 не может art-ить несуществующий саммит/финал. Подтвердить, что это W4, не M1.
8. **Draw calls/tris budget.** 1593/4,95 млн > целей; A07 может снизить MultiMesh/LOD, но не гарантирует <1500 без A03 merge/occlusion. Нужен либо TD exception по FPS, либо приоритет на оптимизацию.
9. **SQ visual props ownership.** A07 делает меши, A03/A04 ставят `QuestPickup`/`QuestNpc`; кто отвечает за no-decor radius и визуальное совпадение с POI?
10. **P05/academy weather/canon.** Убрать ли снег из `academy_approach`? Какой сезон/погода каноничны для M1? Нужен ответ A01/TD.
11. **S00–S15 art pass.** SS-090/071/072 — P2/M4; подтвердить, что A07 не начинает до M1/tech demo.
12. **Внешние ассеты.** Подтвердить: новых Poly Haven/KayKit/Quaternius/Hyper3D ассетов в A07-ветке нет; только существующие CC0/CC BY и project-owned.

---

## 17. Итог для TD

- A07 может работать **в отдельной ветке** и не трогать чужие файлы, если утверждены overlay/profile + art scenes и A03 применяет integration package.
- **3-дневный subset** реалистичен за 6–10 artist-days; полный M1-арт — 16–24, без сокращения P08/P09/B01/B02 не влезает.
- **Tech demo** (Z15/Z18, Z02/Z13 hero, decals, SQ props) — ещё 20–28 artist-days после M1 PASS.
- **Главные блокеры:** ownership/legacy debt, ghost-floor semantics, draw calls/tris budget, Z15 +25/Z18 geometry, hero asset pipeline.
- **До решения TD:** игровые файлы не меняются; спецификация остаётся design-only.
