# Audio & VFX Implementation Specification — A09

**Дата:** 2026-11-03  
**Автор:** Chat 09 — Lead Audio Designer / VFX Artist  
**Статус:** **SPEC — AWAITING TD APPROVAL. Игровые файлы не изменялись.**  
**Design Package:** DP-1.0  
**Базовая точка:** commit `0335a5c346901af2146413b5a159b442d326d8de`, branch `s3-park-art`, dirty tree.  
**Область:** M1 post-Nightmare chain + tech demo Z11–Z18, только аудио, музыка, SFX, VO-учёт, captions и VFX.  
**Не является:** вторым `AudioDirector`, вторым микшером, вторым particle framework, вторым HUD/quest/state.

---

## 0. Executive summary

### 0.1. Что уже есть

- `AudioDirector` + `MusicDirector` + `AmbienceDirector` + `SfxPool` + `VoiceDirector`; 7 шин и limiter.
- 61 SFX-cue, 14 music-cue, 29 ambience-зон; 17 demo-файлов Лабиринта.
- Работающий VFX-слой Лабиринта: дождь, молния, брызги прилива, пыль, смерть карапакса, костёр.
- Целевые 77 тестов зелёные, `audio_vfx_probe` и `location_capture` работают.
- В `project.godot` есть 10 autoload, включая `AudioDirector`.

### 0.2. Главный разрыв

Пост-Кошмарная цепочка **технически звучит**, но только через generic-карту:

```text
police_precinct      → lobby / lobby
academy_approach     → park / park
academy_gate         → park / park
academy_campus       → park / park
academy_sleeper_center → cell / cell
black_sea_platform   → black_sea / labyrinth
tide_descent         → black_sea / labyrinth
```

Нет отдельных звуков машины, КПП, радио, зеркала, терминала, индукции, капсулы, чёрной воды, спуска, Плаща и ночи у костра. VFX города/академии/моря отсутствуют; VFX Лабиринта не покрывают M1-финал. VO Нефис/Кассии и M1-диалогов отсутствует; 83 реплики без файлов. Слуховой тест — **NOT TESTED**.

### 0.3. Решение архитектуры

A09 не редактирует `scenes/locations/**`, `scripts/locations/post_nightmare/**` и `scripts/campaign/**`. Вместо этого добавляется **A09-owned runtime-слой**:

```text
AudioDirector (autoload, существующий)
└── SceneAudioDirector (new, A09)
    ├── SceneAudioProfile .tres (new, A09)
    ├── local 3D loops (car, HVAC, sea, capsule)
    └── SceneVfxDirector (new, A09)
        └── SceneVfxProfile .tres (new, A09)
```

`SceneAudioDirector` реагирует на смену `current_scene`, читает профиль сцены, применяет music/ambience/reverb, назначает `interact_cue` существующим `Interactable`, слушает `TriggerZone.triggered` и `NightmareRunState.flag_changed`, запускает локальные loop-звуки и VFX. Сцены A03 остаются нетронутыми.

**Единственная shared-правка:** 3–5 строк в `scripts/audio/audio_director.gd`, чтобы добавить child `SceneAudioDirector`. Это требует claim A00. Если A00 откажет — fallback: A03 добавляет один `SceneAudioDirector` node в `GreyboxLocation`, что дороже и создаёт A03-зависимость.

### 0.4. Оценка

| Объём | Оценка | Что входит |
|---|---:|---|
| **M1 minimum viable audio/VFX** | **50–70 ч** | runtime-профили, 8–10 SFX, 2–3 VFX, переиспользование существующей музыки/ambience, text-only VO |
| **M1 quality pass** | **70–95 ч** | 5 новые music-cue, 6 ambience-зон, 18–20 SFX, 6 VFX, captions, mix |
| **Tech demo + polish** | **+24–41 ч** | Z11–Z18, storm polish, SQ-01…03 audio/VFX, listening/mix, occlusion/reverb |
| **Полная спецификация** | **99–149 ч** | всё ниже, без финального VO и без внешних моделей |

Это оценка производства, а не 3-часового окна Stage 2. До M1 gate A09 делает только P0-подмножество; P1/P2 не начинаются раньше.

---

## 1. Границы и non-goals

### 1.1. Что A09 делает

- `assets/audio/**`, `scripts/audio/**`, `scripts/vfx/**`, `resources/audio/**`, `scenes/environment/vfx/**`.
- `scripts/locations/forgotten_shore_labyrinth/labyrinth_audio.gd` — explicit A09 carve-out.
- `scripts/audio/labyrinth_atmosphere.gd` — A09-owned.
- `docs/audio/**`, `docs/demo_sprint/design/audio_vfx_design.md`, `docs/demo_sprint/audits/audio_vfx.md`.
- `docs/ASSET_LICENSES.md` — только через A00/A07; A09 присылает строки.

### 1.2. Что A09 не делает

- Не правит `scenes/locations/**`, `scripts/locations/post_nightmare/**`, `scripts/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.gd`.
- Не правит `scripts/campaign/**`, `scripts/quests/**`, `scripts/interaction/**`, `scripts/guide/**`, `scripts/ui/**`.
- Не добавляет autoload, второй микшер, второй `AudioDirector`, второй particle framework.
- Не меняет `project.godot` и `default_bus_layout.tres` без A00.
- Не коммитит, не пушит и не merge-ит; коммит/merge — A00.
- Не выдаёт SAPI/placeholder за финальный VO.

### 1.3. Правило branch isolation

A09 работает в отдельном worktree/ветке от утверждённого DP-1.0 baseline. В diff допускаются только A09-owned файлы и один A00-approved shared hook. Всё, что требует A03/A04/A08/A01, оформляется как **integration request** в §10, а не как правка чужого файла.

```powershell
# создаёт/подтверждает A00; A09 не коммитит
git worktree add ../shadowslave-a09 -b a09/audio-vfx <approved-base>
```

Перед merge:

```powershell
git diff --name-only <base>...HEAD
```

Ожидаемо: только `assets/audio/**`, `scripts/audio/**`, `scripts/vfx/**`, `resources/audio/**`, `scenes/environment/vfx/**`, `docs/audio/**`, `docs/demo_sprint/design/audio_vfx_design.md`, `docs/demo_sprint/audits/audio_vfx.md`, плюс `scripts/audio/audio_director.gd` с claim A00.

---

## 2. Фактическое состояние (audit snapshot)

| Область | Факт | Статус |
|---|---|---|
| Шины | Master/Music/Ambience/SFX/Voice/UI/Reverb | READY |
| Музыка | 14 cue, 3 слоя, `labyrinth_storm` | READY, процедурная |
| SFX | 61 cue, бой/подборы/карапакс/прилив/костёр | READY для Лабиринта |
| Ambience | 29 зон; Лабиринт 18 зон | READY |
| Post-Nightmare | generic `lobby/park/cell/black_sea` | **PARTIAL** |
| P05–P09 SFX | нет car/radio/capsule/induction/gate/terminal | **MISSING** |
| B01–B02 | нет sea/water/shroud/descent слоя | **MISSING** |
| M1 camp night | нет отдельного night bed/stinger | **MISSING** |
| VFX M1 | нет дождя/снега/пара/induction/shroud/sea mist | **MISSING** |
| VFX Лабиринта | rain/lightning/spray/dust/death/campfire | READY |
| VO | 83 реплики без файлов; SAPI — placeholder | **PARTIAL** |
| Captions | `world_tide_warning` и некоторые SFX | **PARTIAL** |
| Occlusion/reverb | один raycast; статичные reverb-зоны | **PARTIAL** |
| Listening test | — | **NOT TESTED** |
| M1 manual pass | — | **NOT TESTED** |
| Full GUT | 633/634 в live tree; 632/632 stable | **NOT RELIABLE** |

### 2.1. Расхождения «документ ↔ факт»

| Документ | Утверждение | Факт | Решение |
|---|---|---|---|
| `AUDIO_DESIGN_DOCUMENT.md` §4.19 | пост-Кошмар — «ПРЕДЛОЖЕНИЕ» | реализована generic-карта | этот spec заменяет предложение на конкретные ID |
| `MASTER_AUDIT.md` §2.11 | audio 75% | верно для Лабиринта, не для M1 | A09-01…06 закрывают M1 |
| `AGENT_TASKS.md` A09-01…09 | M1 audio/VFX | задач 9, без runtime-архитектуры | добавлены A09-10…18 |
| `FILE_OWNERSHIP.md` | A09 не правит сцены | верно | runtime-профили вместо сцен |
| `INTEGRATION_CONTRACTS.md` §13.4 | `AudioDirector` API | нет scene-profile API | добавить child, не менять публичные методы |

---

## 3. Целевая архитектура

### 3.1. Схема

```text
AudioDirector (autoload)
├── MusicDirector
├── AmbienceDirector
├── SfxPool
├── VoiceDirector
├── AudioCaptionOverlay
└── SceneAudioDirector (new)
    ├── SceneAudioProfile (typed Resource)
    ├── local_loop_players: AudioStreamPlayer3D[]
    ├── profile event bindings
    └── SceneVfxDirector (new)
        └── SceneVfxProfile (typed Resource)
```

### 3.2. Поток применения

```text
scene change / current_scene
  → SceneAudioDirector._detect_scene()
  → profile = profiles[location_id or scene_path]
  → if none: no-op (generic GreyboxLocation map remains)
  → apply music_id, ambience_id, reverb_profile, music_intensity
  → assign Interactable.interact_cue by interaction_id
  → connect TriggerZone.triggered → profile.triggers
  → connect NightmareRunState.flag_changed → profile.flags
  → connect DialogueRunner.line_started/finished → music/ambience duck/release
  → spawn local loops at POI positions
  → SceneVfxDirector.apply(profile.vfx)
  → on scene exit: stop loops, disconnect, free VFX
```

### 3.3. Правила

1. **Один writer.** Профили — единственный источник scene-specific аудио; сцена не содержит звуковых скриптов.
2. **Fallback.** Если профиля нет, `GreyboxLocation.POST_NIGHTMARE_AUDIO` остаётся fallback; A09 не ломает старые сцены.
3. **No double.** Если `GreyboxLocation` уже вызвал music/ambience, профиль делает один crossfade, а не второй параллельный director. После A03-map update generic-вызовы заменяются, а не дублируются.
4. **Interactable.** A09 назначает `interact_cue`; не подключает второй signal для того же `interacted`, иначе звук сыграет дважды.
5. **TriggerZone.** Профиль слушает `triggered` только для событий, у которых нет `Interactable`.
6. **Loops.** `SfxPool` не поддерживает loop; локальные петли — отдельные `AudioStreamPlayer3D` на `Ambience` bus, не более 4 на сцену.
7. **Cleanup.** При смене сцены все локальные игроки и VFX освобождаются; никаких утечек.
8. **No scene edits.** Все координаты — из `poi_manifest.md` или именованных узлов; A03 не правит сцену ради A09.

### 3.4. SceneAudioProfile

```gdscript
class_name SceneAudioProfile
extends Resource

@export var id: StringName
@export var scene_path: String
@export var location_id: StringName
@export var music_id: StringName
@export var ambience_id: StringName
@export var music_intensity := 0.45
@export var reverb_profile: StringName = &"outdoor"
@export var duck_music := -8.0
@export var loops: Array[SceneAudioEvent] = []
@export var enter_events: Array[SceneAudioEvent] = []
@export var interactions: Dictionary = {} # interaction_id -> SfxCue id
@export var triggers: Dictionary = {}     # trigger_id -> SfxCue id
@export var flags: Dictionary = {}        # flag -> SfxCue id
```

`SceneAudioEvent`: `cue_id`, `position`, `radius`, `volume_db`, `delay`, `loop`, `caption`.  
Все ID — `StringName`; позиции — локальные/мировые по контракту сцены.

### 3.5. SceneVfxProfile

```gdscript
class_name SceneVfxProfile
extends Resource

@export var scene_path: String
@export var location_id: StringName
@export var enter_effects: Array[SceneVfxEvent] = []
@export var flag_effects: Dictionary = {}
@export var trigger_effects: Dictionary = {}
@export var loops: Array[SceneVfxEvent] = []
```

`SceneVfxEvent`: `scene_path`, `position`, `rotation_y`, `scale`, `one_shot`, `delay`, `attach_to` (optional NodePath), `particle_budget`.

---

## 4. Что конкретно реализовать

### 4.1. M1 audio by scene

| Сцена | Music | Ambience | Local loops | Key one-shots | VFX |
|---|---|---|---|---|---|
| `police_precinct` P05 | `m1_precinct` (fallback `lobby`) | `m1_precinct` (fallback `lobby`), reverb `precinct_hall` | HVAC, radio hiss, window rain | cell door, mirror whisper, paper, checkpoint tone | window rain, breath vapor, dust |
| `academy_approach` P06 | `m1_academy` (fallback `park`) | `m1_academy` (fallback `park`), reverb `outdoor` | car idle at POI-P06-02, wind | car door, checkpoint beep, snow step | snow drift, exhaust, breath |
| `academy_gate` P07 | `m1_academy` | same | flag/turret servo | gate scan, checkpoint, turret | snow, flag flap, gate scan light |
| `academy_campus` P08 | `m1_academy` | same, reverb `academy_hall` | crowd walla, HVAC | terminal beep, glass door | snow, steam vents |
| `academy_sleeper_center` P09 | `m1_sleeper` (fallback `cell`) | `m1_sleeper` (fallback `cell`), reverb `sleeper_hall` | HVAC, capsule hum, clock | induction tone, capsule hiss, crowd murmur | induction pulse, steam, capsule glow |
| `black_sea_platform` B01 | `m1_black_sea` (fallback `black_sea`) | `m1_black_sea` (fallback `labyrinth`), reverb `black_sea` | sea lap, wind | statue groan, metal ring, shroud flare | black-sea mist, shroud ribbons, star motes |
| `tide_descent` B02 | `m1_descent` (fallback `black_sea`) | `m1_descent` (fallback `labyrinth`), reverb `descent` | water flow, wind | wave crash, small rockfall, tide warning | tide foam, spray, wet dust |
| Z01–Z10 B03 | existing `labyrinth` / `labyrinth_storm` | existing 18 zones | campfire, storm | existing zone events | existing + camp night |
| Z10 M1 end | `camp` at final beat | `labyrinth_z10` → `m1_camp_night` on `camp_night_seen` | campfire | `m1_camp_night_stinger` on `camp_night_seen` | fire/smoke, night dust |

**Z10 note:** ночной профиль Z10 применяет `LabyrinthAudio`/A09-05, а не generic `SceneAudioDirector`, чтобы не дублировать существующий слой Лабиринта.

### 4.2. M1 minimum viable (если окно короткое)

- Использовать **существующие** `lobby`, `park`, `cell`, `black_sea`, `labyrinth` music/ambience, не создавать 5 новых music-cue.
- Добавить только 8 SFX: cell door, mirror whisper, car idle, checkpoint beep, terminal beep, induction tone, capsule hiss, shroud flare.
- Добавить 3 VFX: `m1_rain_light`, `m1_snow_drift`, `m1_shroud_ribbons`.
- VO — text-only, без SAPI; captions для tide/checkpoint/capsule.
- Это даёт M1 «не тихо», но не финальный саунд-дизайн. Оценка 50–70 ч.

### 4.3. Tech demo (после M1 gate)

- Z11–Z18: SQ-01…03 звуковые точки, Z17 storm polish, Z18 final wind/void.
- SQ-01: token pickup/inspect, Theo talk, trail; SQ-02: echo points, polyp, cloak/core; SQ-03: choice panel cue, Theo return.
- Не начинать до `A00-08` (M1 PASS).

### 4.4. VFX scope

| Событие | VFX | Источник |
|---|---|---|
| P05 rain / breath | лёгкий дождь за окном, пар дыхания | new `m1_rain_light`, existing `p3_breath_puff` |
| P06/P08 snow | снежная крупа/порывы | new `m1_snow_drift` |
| P09 induction | кольца/импульс, пар, свечение капсулы | new `m1_induction_pulse`, `m1_steam_vents` |
| B01 shroud | ленты/тени Плаща | new `m1_shroud_ribbons` |
| B01 sea | низкий туман/брызги | new `m1_black_sea_mist` |
| B02 tide | пена/брызги на спуске | existing `tide_spray` + new foam |
| Z10 camp | огонь/дым/ночная пыль | existing fire/smoke/dust |
| Z17 storm | дождь/молнии/порывы | existing `storm_rain`, lightning |

### 4.5. VO и captions

- M1 принимается с text-only диалогами; `VoiceDirector.play_line` остаётся no-op для отсутствующих файлов.
- `voice_manifest_m1.json` фиксирует: line_id, speaker, duration, has_voice, source/license.
- SAPI — только dev-placeholder, не в release build; финальный VO — P1 после решения пользователя.
- Captions: tide warning, checkpoint, gate scan, capsule, mirror whisper, shroud, induction, camp night. Строки — в `SfxCue.caption`; UI не меняется.

---

## 5. Что исправить в существующем

| # | Элемент | Проблема | Владелец | Действие A09 |
|---:|---|---|---|---|
| F1 | `GreyboxLocation.POST_NIGHTMARE_AUDIO` | generic `lobby/park/cell/black_sea` | A03 | прислать новые ID; A03 обновляет map; A09 не правит файл |
| F2 | `GreyboxLocation` reverb | всегда `outdoor` | A09 + A03 | A09 profile задаёт `precinct_hall`/`academy_hall`/`sleeper_hall`/`black_sea`/`descent` после scene load; A03 опционально убирает hardcoded `outdoor` |
| F3 | `Interactable` generic cue | зеркало/терминал/капсула/статуя звучат как pickup | A09 runtime | `SceneAudioDirector` назначает `interact_cue` по `interaction_id` |
| F4 | `AudioDirector` | нет scene-profile API | A09 + A00 | 3–5 строк child hook; публичные методы не меняются |
| F5 | `AudioLibrary` | один addendum | A09 | расширить существующий `audio_cue_library_demo.tres`; builder обязан сохранить 12 labyrinth-cue, не пересобирать их «с нуля»; не создавать второй loader |
| F6 | `SfxPool` | не играет loop | A09 | локальные `AudioStreamPlayer3D` в `SceneAudioDirector`; pool не менять |
| F7 | `LabyrinthAudio` | нет camp-night перехода | A09 carve-out | слушать `camp_night_seen`, crossfade в night bed/stinger |
| F8 | `AudioCaptionOverlay` | captions только у части cue | A09 + A08 | заполнить `SfxCue.caption`; UI уже есть |
| F9 | `VoiceDirector` | 83 реплики без файлов | A09 + A01 | manifest/coverage, не выдавать за VO |
| F10 | `AudioOcclusion` | один raycast, loops не обновляются | A09 P2 | multi-ray/loop update после M1 |
| F11 | `MusicDirector` | процедурные 16-с петли | A09 P1/P2 | новые M1-стемы; финальные — после listening |
| F12 | M1 VFX | отсутствуют | A09 | `SceneVfxDirector` + профили; без правки сцен |
| F13 | `AudioDirector` autoload | был потерян в раннем дереве | A00 | проверить в baseline; не менять без A00 |
| F14 | `test_audio_system` counts | exact counts ломаются при новых cue | A10 | A09 просит `assert_gte` + новые проверки; не правит tests |

---

## 6. Новые элементы

| ID | Тип | Описание | Файл |
|---|---|---|---|
| N01 | `SceneAudioDirector` | runtime-профили сцен | `scripts/audio/scene_audio_director.gd` |
| N02 | `SceneAudioProfile` | typed Resource профиля | `scripts/audio/scene_audio_profile.gd` |
| N03 | `SceneAudioEvent` | typed событие/loop | `scripts/audio/scene_audio_event.gd` |
| N04 | `SceneVfxDirector` | runtime VFX-профили | `scripts/vfx/scene_vfx_director.gd` |
| N05 | `SceneVfxProfile` | typed Resource VFX | `scripts/vfx/scene_vfx_profile.gd` |
| N06 | `SceneVfxEvent` | typed VFX-событие | `scripts/vfx/scene_vfx_event.gd` |
| N07 | M1 music | 5 cue × 3 слоя: `m1_precinct`, `m1_academy`, `m1_sleeper`, `m1_black_sea`, `m1_descent` | `assets/audio/m1/music/*.ogg` |
| N08 | M1 ambience | 6 зон: `m1_precinct`, `m1_academy`, `m1_sleeper`, `m1_black_sea`, `m1_descent`, `m1_camp_night` | `assets/audio/m1/ambience/*.ogg` |
| N09 | M1 SFX | 18–20 cue: door/radio/mirror/car/checkpoint/gate/terminal/crowd/induction/capsule/sea/statue/shroud/water/rockfall | `assets/audio/m1/sfx/*.wav` |
| N10 | VFX scenes | rain/snow/steam/induction/sea mist/shroud/foam | `scenes/environment/vfx/m1_*.tscn` |
| N11 | Scene profiles | 8 audio + 8 VFX `.tres` | `resources/audio/scene_profiles/`, `resources/audio/scene_vfx_profiles/` |
| N12 | Captions | 10 ключевых неречевых сигналов | cue fields |
| N13 | VO coverage | manifest + отчёт | `resources/audio/voice_manifest_m1.json`, `docs/audio/VO_M1_COVERAGE.md` |
| N14 | QA probe | M1 audio/VFX probe | `tools/audio/check_m1_audio.py`, `tools/audit/audio_vfx_probe_m1.gd` (A10 claim) |
| N15 | Integration request | точные запросы A03/A04/A08/A01 | этот документ §10 |

---

## 7. Файлы

### 7.1. A09-owned (прямые изменения)

```text
assets/audio/m1/**
scripts/audio/scene_audio_director.gd
scripts/audio/scene_audio_profile.gd
scripts/audio/scene_audio_event.gd
scripts/audio/audio_library.gd
scripts/audio/labyrinth_atmosphere.gd
scripts/locations/forgotten_shore_labyrinth/labyrinth_audio.gd   # carve-out A09
scripts/vfx/scene_vfx_director.gd
scripts/vfx/scene_vfx_profile.gd
scripts/vfx/scene_vfx_event.gd
scripts/vfx/one_shot_vfx.gd
scenes/environment/vfx/m1_*.tscn
resources/audio/audio_cue_library_demo.tres
resources/audio/scene_profiles/*.tres
tools/audio/generate_demo_audio.py
tools/audio/build_demo_cues.gd
docs/audio/VO_M1_COVERAGE.md
docs/demo_sprint/design/audio_vfx_design.md
docs/demo_sprint/audits/audio_vfx.md
```

### 7.2. Shared (только A00 approval)

| Файл | Зачем | Минимальная правка |
|---|---|---|
| `scripts/audio/audio_director.gd` | child `SceneAudioDirector` | 3–5 строк в `_ready`; публичный API не меняется |
| `tools/audio/**` | существующие генераторы/проверки | A09 carve-out для audio tooling; не runtime |
| `default_bus_layout.tres` | SFX reverb send / mix | только P2, отдельный claim |
| `project.godot` | нет | не менять; autoload не добавлять |
| `docs/ASSET_LICENSES.md` | новые ассеты | A09 присылает строки, A00 вносит |
| `docs/DECISIONS.md` | архитектурное решение | A00 вносит |

### 7.3. Запросы другим владельцам (A09 не правит)

| Владелец | Файл/данные | Запрос | Зачем |
|---|---|---|---|
| A03 | `scripts/locations/post_nightmare/greybox_location.gd` | обновить `POST_NIGHTMARE_AUDIO` на `m1_*` ID; reverb per scene | убрать generic-карту |
| A03 | `scenes/locations/post_nightmare/*.tscn` | опционально `AudioAnchors`/`VfxAnchors` Marker3D | убрать hardcoded coords |
| A03 | `labyrinth_first_fragment.gd` | `camp_night_seen` beat/trigger | M1 night audio |
| A04 | `NightmareRunState` | signals `flag_changed` уже есть; подтвердить canonical flags | profile flags |
| A04 | `QuestSystem` | `quest_started/objective/completed` уже есть | quest cues |
| A04 | `DialogueRunner` | `line_started/finished` уже есть; ducking hook | voice/text ducking |
| A08 | `AudioCaptionOverlay`/settings | captions уже есть; volume sliders | captions/accessibility |
| A01 | `resources/dialogue/post_nightmare/*.tres` | canonical line IDs/voice_id | VO coverage |
| A07 | shroud/visual anchors | shroud mesh/ribbon art if needed | VFX readability |
| A10 | `tests/**`, `tools/audit/**` | tests/probe ownership | verification |

### 7.4. Запрещено

- `scripts/locations/post_nightmare/**` — A03.
- `scripts/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.gd` — A03.
- `scripts/campaign/**`, `scripts/quests/**`, `scripts/interaction/**` — A04.
- `scenes/ui/**`, `scripts/ui/**` — A08.
- `resources/dialogue/**` — A01.
- `project.godot`, `default_bus_layout.tres` без A00.
- `tests/**` без A10 claim.

---

## 8. Ресурсы

### 8.1. Аудиоформаты

| Тип | Формат | Требование |
|---|---|---|
| 3D SFX | WAV mono 44.1 kHz 16-bit | peak −6…−3 dBFS, trim < 2 с, no DC |
| Loops | OGG stereo 44.1 kHz | 15–20 с, crossfade/12 мс edge fade, seam < 0.005 |
| Music | OGG stereo, 3 слоя | 15–20 с, base/pulse/melody, loop seam 0 |
| UI | WAV mono 44.1 kHz | −20…−16 LUFS, short |
| VO | WAV/OGG mono 48 kHz | final only; SAPI dev-only |

### 8.2. Новые аудио-ассеты (полный набор)

| ID | Тип | Назначение | Длина |
|---|---|---|---:|
| `p05_cell_door` | SFX | металлическая решётка/дверь | 1.2 с |
| `p05_radio_chatter` | loop/SFX | радио без слов | 4–6 с |
| `p05_mirror_whisper` | SFX | тень в зеркале | 1.5 с |
| `p05_paper_rustle` | SFX | бумаги/шкафчик | 0.6 с |
| `p06_car_idle` | loop | машина Джет | 3–4 с |
| `p06_car_door` | SFX | дверь машины | 0.7 с |
| `p06_checkpoint_beep` | SFX | КПП | 0.4 с |
| `p07_gate_scan` | SFX | сканер/турникет | 1.0 с |
| `p07_flag_flap` | SFX/loop | флаги на ветру | 2.0 с |
| `p08_terminal_beep` | SFX | терминал | 0.4 с |
| `p08_crowd_walla` | loop | студенты без слов | 6–8 с |
| `p09_hvac` | loop | вентиляция | 6–8 с |
| `p09_induction_tone` | SFX | индукция | 2.5 с |
| `p09_capsule_hiss` | SFX | капсула | 1.2 с |
| `p09_capsule_hum` | loop | капсула | 3–4 с |
| `b01_sea_lap` | loop | чёрная вода | 8–12 с |
| `b01_statue_groan` | SFX | камень статуи | 2.0 с |
| `b01_shroud_flare` | SFX | Плащ | 2.0 с |
| `b02_water_flow` | loop | спуск/вода | 6–8 с |
| `b02_wave_crash` | SFX | волна | 1.5 с |
| `b02_rockfall_small` | SFX | осыпь | 1.2 с |

**Переиспользовать:** `world_wind_gust`, `world_water_splash`, `world_tide_warning`, `world_tide_surge`, `world_stone_shift`, `world_coral_groan`, `world_door_metal`, `footstep_snow_packed`, `footstep_stone`, `footstep_mud`, `ui_*`, `combat_*`.

### 8.3. VFX-сцены

| Сцена | Назначение | Бюджет |
|---|---|---:|
| `m1_rain_light.tscn` | дождь за окном/улица | 350–450 |
| `m1_snow_drift.tscn` | снежная крупа/порыв | 400–600 |
| `m1_steam_vents.tscn` | пар кампуса/капсул | 120–180 |
| `m1_induction_pulse.tscn` | кольца/импульс | 80–120 |
| `m1_black_sea_mist.tscn` | низкий туман/брызги | 250–350 |
| `m1_shroud_ribbons.tscn` | тени/ленты Плаща | 60–100 |
| `m1_tide_foam.tscn` | пена/брызги | 120–180 |

**Правило:** M1-сцена — не более 2 постоянных emitter'ов и 800 частиц; дождь/снег не включать в диалоговых интерьерах; VFX не должен перекрывать UI/субтитры.

### 8.4. Профили

`resources/audio/scene_profiles/`:

```text
p05_police_precinct.tres
p06_academy_approach.tres
p07_academy_gate.tres
p08_academy_campus.tres
p09_sleeper_center.tres
b01_black_sea.tres
b02_tide_descent.tres
z10_camp_night.tres
```

`resources/audio/scene_vfx_profiles/`:

```text
p05_police_precinct_vfx.tres
p06_academy_approach_vfx.tres
p07_academy_gate_vfx.tres
p08_academy_campus_vfx.tres
p09_sleeper_center_vfx.tres
b01_black_sea_vfx.tres
b02_tide_descent_vfx.tres
z10_camp_night_vfx.tres
```

### 8.5. Лицензии

- Все новые аудио/ VFX — project-owned procedural, без сторонних сэмплов.
- Любой внешний CC0/CC BY — только после записи в `docs/ASSET_LICENSES.md` и решения A00/A07.
- SAPI — dev-only, не в release; финальный VO — отдельное решение.
- Не коммитить чужие треки и temp music.

---

## 9. Инструменты

| Инструмент | Использование |
|---|---|
| Godot 4.7.2 | импорт, GUT, runtime-профили, VFX-сцены |
| GUT 9.7.1 | targeted audio/labyrinth/post-nightmare tests |
| Python 3.13 + numpy/scipy/soundfile | генерация WAV/OGG, loop seam |
| imageio-ffmpeg / `measure_loudness.py` | LUFS/true peak |
| `tools/audio/generate_demo_audio.py` | образец процедурной генерации |
| `tools/audio/build_demo_cues.gd` | образец typed cue builder |
| `tools/audio/check_demo_audio.py` | peak/DC/seam probe |
| `tools/audit/audio_vfx_probe.gd` | образец scene probe |
| `tools/audit/location_capture.gd` | визуальная проверка VFX |
| `tools/audit/scene_stats.gd` | triangles/particles/performance snapshot |
| Blender 5.1 | только если нужен ribbon/mesh для Плаща; иначе GPUParticles |
| Krita 5.3 | только если нужна текстура для VFX; иначе procedural gradient |
| Godot MCP | **не использовать для live**, если editor disconnected; headless/capture |

---

## 10. Зависимости и интеграция

| Направление | Что нужно | Формат | Блокирует |
|---|---|---|---|
| A00 | утвердить DP-1.0; разрешить `audio_director.gd` hook; license rows; build | claim + review | A09-10 |
| A01 | canonical line IDs/voice_id для P05–B02; speaker names | `resources/dialogue/**` | A09-07 |
| A03 | `location_id`, POI coords, trigger IDs; `POST_NIGHTMARE_AUDIO` map; reverb per scene; `AudioAnchors` optional | map update / markers | A09-01…06 |
| A04 | flags `p05_*`, `camp_night_seen`, `shroud_summoned`; signals; interactable IDs | existing API | A09-01…06 |
| A05 | E01–E03 events; death/hit signals | existing API | A09-06 |
| A06 | animation timing for hit/death; no new hooks | existing | A09-06 |
| A07 | shroud/visual anchors; light/material readability | assets/scene art | A09-06 |
| A08 | captions overlay; volume sliders; credits | existing UI | A09-07/17 |
| A10 | tests/probe ownership; listening QA; build | tests/QA | A09-14 |
| User | listening/VO/licensing decisions | sign-off | A09-07/08 |

### 10.1. Integration requests (A09 → owners)

1. **A03-REQ-1:** `GreyboxLocation.POST_NIGHTMARE_AUDIO` — заменить generic mapping на:
   ```gdscript
   police_precinct: [&"m1_precinct", &"m1_precinct"]
   academy_approach/gate/campus: [&"m1_academy", &"m1_academy"]
   academy_sleeper_center: [&"m1_sleeper", &"m1_sleeper"]
   black_sea_platform: [&"m1_black_sea", &"m1_black_sea"]
   tide_descent: [&"m1_descent", &"m1_descent"]
   ```
   Если A03 не успевает — A09 profile делает crossfade после generic; это допустимый fallback.
2. **A03-REQ-2:** reverb per scene: A09 задаёт `precinct_hall`, `academy_hall`, `sleeper_hall`, `black_sea`, `descent` из profile после scene load; A03 опционально убирает hardcoded `outdoor` в `GreyboxLocation`.
3. **A03-REQ-3:** optional `AudioAnchors`/`VfxAnchors` Marker3D для car/HVAC/capsule/shroud; иначе A09 использует POI manifest.
4. **A04-REQ-1:** подтвердить `flag_changed` для `camp_night_seen`/`shroud_summoned`; A09 слушает.
5. **A08-REQ-1:** captions уже работают; A09 заполняет `caption`; A08 не меняет UI.
6. **A01-REQ-1:** canonical dialogue files + `voice_id`; A09 строит coverage.
7. **A10-REQ-1:** добавить `test_m1_audio_profiles.gd`/`audio_vfx_probe_m1`; A09 даёт cases/команды.
8. **A00-REQ-1:** claim на 3–5 строк `audio_director.gd`; `ASSET_LICENSES` rows; branch base.

---

## 11. Task list

> Базовый формат Stage 2: **Task ID | Description | Files | Dependencies | Priority | Acceptance Criteria.**  
> Колонки `Effort` и `Risk` добавлены по требованию Stage 2; они не заменяют acceptance criteria.  
> `Effort` — реальная оценка одного специалиста, не календарный срок.  
> `Risk` — High/Medium/Low с причиной в описании.  
> Связь с BACKLOG: A09-01…06 = SS-046/SS-062/SS-063/SS-064/SS-129; A09-07/08 = SS-062/SS-063; A09-09 = SS-046; A09-19 = SS-032…034. A00 добавляет/связывает ID в `BACKLOG.md`; A09 не правит BACKLOG.

| ID | Description | Files | Dependencies | Priority | Effort | Risk | Acceptance Criteria |
|---|---|---|---|---|---|---|---|
| **A09-18** | Branch/worktree readiness: отдельная ветка, baseline, claims, diff allow-list | нет игровых файлов | A00-03 | P0 | 1–2 ч | Low | Ветка создана от approved base; `git diff --name-only` только A09 + approved hook; claim записан |
| **A09-15** | Integration request bundle: A03/A04/A08/A01/A10 запросы, ID, owners | этот документ | A00-03 | P0 | 2–3 ч | Low | Каждый shared-file request имеет owner/acceptance; A00 подтвердил |
| **A09-10** | Scene audio runtime: `SceneAudioDirector` + typed profiles + `AudioDirector` child hook | `scripts/audio/scene_audio_director.gd`, `scene_audio_profile.gd`, `scene_audio_event.gd`, `audio_director.gd` (A00 claim), `audio_library.gd` | A09-15, A00-05 | P0 | 8–12 ч | **High** (shared hook/lifecycle) | profile применяется <0.5 с; нет второго autoload; нет double music; probe exit 0 |
| **A09-11** | M1 audio asset pack: 5 music ×3, 6 ambience, 20 SFX; build addendum | `assets/audio/m1/**`, `tools/audio/generate_demo_audio.py`, `tools/audio/build_demo_cues.gd`, `resources/audio/audio_cue_library_demo.tres` | A09-15, A00 license | P0 | 16–24 ч | **High** (music quality/licensing) | Все cue существуют; peaks/seams; `measure_loudness`; project-owned |
| **A09-01** | M1 music/ambience profiles for P05–B02 + Z10 night | `resources/audio/scene_profiles/*.tres` | A09-10/11, A03-REQ-1/2 | P0 | 6–10 ч | Medium (generic map conflict) | 8 профилей; music/ambience/reverb корректны; нет double; probe |
| **A09-02** | P05/P06 SFX: cell, mirror, radio, car, checkpoint, snow | profile + `assets/audio/m1/sfx/p05_*`, `p06_*` | A09-10/11, A03 P05/P06 | P0 | 4–6 ч | Low/Medium | Все interaction ids получают свой cue; car loop 3D; нет UI click |
| **A09-03** | P09: induction, crowd, capsule, HVAC, clock; dialogue duck | profile + `p09_*` assets | A09-10/11, A01/A03 P09 | P0 | 4–6 ч | Medium | capsule cue только после `capsule_entered`; duck при dialogue; нет клиппинга |
| **A09-04** | B01/B02: sea, water, wind, statue, shroud, tide | profile + `b01_*`, `b02_*` assets | A09-10/11, A03/A07 | P0 | 4–6 ч | Medium | sea/water loops; shroud cue на `shroud_summoned`; tide warning; reverb |
| **A09-05** | Z01–Z10 + camp night: existing labyrinth + `camp_night_seen` | `labyrinth_audio.gd`, `labyrinth_atmosphere.gd`, `z10_camp_night.tres` | A09-10, A03/A04 | P0 | 2–4 ч | Low | night bed/stinger on flag; M1 final no audio cut; targeted audio/labyrinth tests 0 fail |
| **A09-12** | Scene VFX runtime: `SceneVfxDirector` + typed profiles, child of SceneAudioDirector | `scripts/vfx/scene_vfx_director.gd`, `scene_vfx_profile.gd`, `scene_vfx_event.gd` | A09-10 | P0 | 6–8 ч | Medium | profile applies; VFX nodes freed; no scene edits; no leaks |
| **A09-13** | M1 VFX asset pack: rain/snow/steam/induction/sea mist/shroud/foam | `scenes/environment/vfx/m1_*.tscn`, `one_shot_vfx.gd` | A09-12, A07 look | P0 | 8–12 ч | Medium | 7 scenes load; particle budgets; `location_capture` |
| **A09-06** | M1 VFX hooks: P05 rain, P06/P07/P08 snow, P09 induction, B01 shroud/sea, B02 tide | VFX profiles + assets | A09-12/13, A03/A07 | P0 | 6–8 ч | **High** (shroud/art) | shroud on flag; tide spray; ≤2 emitters/800 particles; capture |
| **A09-07** | VO coverage + captions: manifest, missing lines, SAPI policy, cue captions | `resources/audio/voice_manifest_m1.json`, `docs/audio/VO_M1_COVERAGE.md`, cue `caption` | A01/A08/A00 | P1 | 6–10 ч | **High** (VO/licensing) | все M1 lines listed; missing documented; no release SAPI; captions show |
| **A09-08** | Listening/mix validation: 3 scenes, LUFS/peaks, protocol | `docs/audio/M1_LISTENING_TEST.md`, QA input | A09-01…06, A10/user | P1 | 4–6 ч | Medium | protocol filled; targets; if not listened → NOT TESTED |
| **A09-09** | Storm Z17 polish: rain/lightning/spray/wind; budget | `labyrinth_atmosphere.gd`, `storm_rain.tscn`, cue addendum | A00-08, A03-10 | P1 | 4–6 ч | Low/Medium | storm reads; 800 rain/48 mist; no new system; FPS |
| **A09-19** | Tech-demo SQ audio/VFX hooks: SQ-01 token/trail/Theo; SQ-02 echo/polyp/cloak; SQ-03 choice/return | profiles/cue addendum/VFX profiles | A02-01…03, A04-03, A03-10 | P1 | 4–6 ч | Low/Medium | SQ cues fire once; no duplicate; no new quest system; probe |
| **A09-14** | QA probe/automation: M1 profile/cue/particle probe; loudness | `tools/audio/check_m1_audio.py`, `tools/audit/audio_vfx_probe_m1.gd` (A10) | A09-10/11, A10 | P0/P1 | 4–6 ч | Low | probe prints profiles/cues/particles; exit 0; A10 integrates |
| **A09-16** | Mix/reverb/occlusion pass: profiles, SFX send, multi-ray; P2 | `audio_director.gd`, `audio_occlusion.gd`, `default_bus_layout.tres` (A00) | A09-01/08, A00 | P2 | 8–12 ч | Medium | 3 scenes within LUFS; no clipping; loops update; not M1 blocker |
| **A09-17** | Release/credits/licensing: credits, CC BY/SAPI status | `docs/ASSET_LICENSES.md` (A00), `docs/audio/CREDITS_AUDIO.md`, A08 credits | A00-02, A08-05 | P1 | 2–4 ч | Low | credits list; no unlicensed asset; SAPI excluded |

### 11.1. Dependency graph

```text
A09-18 branch
  → A09-15 integration requests
    → A09-10 scene audio runtime
      ├─ A09-11 audio assets
      │   ├─ A09-01 M1 profiles
      │   ├─ A09-02 P05/P06
      │   ├─ A09-03 P09
      │   ├─ A09-04 B01/B02
      │   └─ A09-05 Z01–Z10
      ├─ A09-12 VFX runtime
      │   └─ A09-13 VFX assets
      │       └─ A09-06 VFX hooks
      └─ A09-14 QA probe
A09-15 → A09-07 VO/captions (A01/A08)
A09-01…06 → A09-08 listening
A09-08 → A09-16 mix
A00-08 → A09-09 storm
A02-01…03/A04-03 → A09-19 SQ audio/VFX
A00-02/A08-05 → A09-17 credits
```

### 11.2. M1 minimum path

Если TD сокращает объём:

```text
A09-18 → A09-15 → A09-10 → A09-14
  → A09-01 (existing lobby/park/cell/black_sea, no new music)
  → A09-02/03/04/05 (8 SFX, no new music)
  → A09-12 + A09-13 (3 VFX: rain/snow/shroud)
  → A09-07 (text-only captions, no SAPI)
```

Оценка: **50–70 ч**. Не входит: новые music-cue, полный asset pack, storm, mix/occlusion, SQ.

### 11.3. Cut list

1. Новые `m1_*` music-cue — reuse existing cues.
2. 20 SFX → 8 critical.
3. 7 VFX → 3 (rain/snow/shroud).
4. VO/SAPI — text-only.
5. Storm Z17 — после M1.
6. Mix/occlusion — P2.
7. Captions — только tide/checkpoint/capsule/shroud/induction.

---

## 12. Проверка готовности

### 12.1. Команды

```powershell
godot --headless --path . --import
godot --headless --path . -s tools/audit/audio_vfx_probe_m1.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_audio_system.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_audio_playback.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_post_nightmare_locations.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_labyrinth_audio.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_demo_audio_vfx.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_labyrinth_first_fragment.gd -gexit
python tools/audio/check_m1_audio.py
python tools/audio/measure_loudness.py <files>
```

### 12.2. Матрица приёмки

| Элемент | Проверка | Pass |
|---|---|---|
| Scene profile | probe prints `profile=<id>`; no unknown cue | P05–B02, Z10 |
| Music/ambience | probe `music=`, `ambience=`; no double | IDs match profile |
| Interactables | probe lists `interaction_id → cue`; no `ui_click` | all M1 interactions |
| Local loops | probe counts 3D loops; stop on scene exit | ≤4 loops, no leak |
| Flag events | probe triggers `camp_night_seen`/`shroud_summoned` | cue/VFX once |
| VFX | `scene_stats` particle count; `location_capture` | ≤2 emitters/800 particles |
| Captions | `AudioCaptionOverlay` shows key cue | 5 captions |
| VO coverage | manifest count; missing list | no false “final VO” |
| Loudness | `measure_loudness` | SFX peaks ≤−3 dBTP; loops within target |
| Loop seam | `check_m1_audio.py` | seam <0.005 |
| Tests | targeted GUT | 0 fail |
| Branch | `git diff --name-only` | only allowed paths |
| Manual | M1 run | hear each scene; no cut/soft-lock |

### 12.3. M1 acceptance

- P05–P09/B01–B02/Z01–Z10: ни одна сцена не «безмолвна».
- Нет UI-клика на мировых объектах.
- Нет двойного music/ambience при входе.
- Нет audio cut на портале; fade 0.22/0.28.
- Camp night cue один раз по `camp_night_seen`; финальная карточка не обрывает звук.
- VFX P05/P06/P07/P08/P09/B01/B02 читаются и не перекрывают UI.
- Все M1 placeholders/SAPI помечены; release не содержит SAPI.
- `NOT TESTED` перечислены честно.

---

## 13. Ошибки, конфликты и митигации

| # | Риск/конфликт | Влияние | Митигация |
|---:|---|---|---|
| C1 | A00 не разрешает `audio_director.gd` hook | runtime-профили невозможны | fallback: A03 добавляет один node; иначе только A03 map + existing cues |
| C2 | `GreyboxLocation` вызывает generic music/ambience | двойной crossfade/наложение | A03 map update first; profile override after 0.1–0.3 с; no second director |
| C3 | `Interactable` уже играет `world_pickup` | двойной звук | A09 назначает `interact_cue`; не подключает второй signal |
| C4 | `TriggerZone` не в группе | profile не находит | traverse `is TriggerZone`; connect after one frame + `node_added` |
| C5 | `current_scene` null в тестах | profile ломает тесты | no-op in `SceneAudioDirector`; only real scene |
| C6 | POI coords drift | VFX/loops в неверной точке | profiles use POI IDs; A03 anchors or review; log mismatch |
| C7 | `SfxPool` 16 3D voices exhausted | loops/SFX cut | local loops on Ambience bus, max 4; SFX pool capped |
| C8 | VFX particles over budget | FPS drop | per-scene caps; no rain in dialogue; reuse existing scenes |
| C9 | Addendum count tests | false fails | A10 uses `assert_gte`; specific cue checks |
| C10 | SAPI/VO licensing | build cannot ship | text-only M1; SAPI dev-only; credits/license task |
| C11 | Shared `default_bus_layout` change | mix regression | no change in M1; P2 + A00 claim |
| C12 | Parallel A03 edits | files overwritten | no A03 edits; integration requests; TD merge |
| C13 | A09 branch includes shared hook | not branch-isolated | separate commit/claim; A00 cherry-pick; diff allow-list |
| C14 | Listening not performed | false PASS | A09-08 requires user/TD; otherwise NOT TESTED |

---

## 14. Риски и оценка

### 14.1. High

1. **Shared hook** `audio_director.gd` — нужно A00; иначе архитектура деградирует до A03 map.
2. **Music quality** — процедурные 16-с петли; новые M1-темы могут звучать как placeholder; нужен listening.
3. **Shroud VFX** — ленты/тень должны читаться без модели; риск art mismatch A07.
4. **VO/licensing** — SAPI нельзя в release; финальный VO отсутствует.

### 14.2. Medium

5. **Generic map conflict** — двойной crossfade.
6. **POI drift** — hardcoded coords.
7. **Loop/particle budget** — M1 scenes small; rain/snow must be light.
8. **Test ownership** — A10 owns tests/probe; A09 needs carve-out.

### 14.3. Low

9. Caption strings; UI already supports.
10. QA probe; command output.
11. Credits/license rows.

### 14.4. Итоговая оценка

| Объём | Часы |
|---|---:|
| M1 minimum | 50–70 |
| M1 quality | 70–95 |
| Tech demo/polish | +24–41 |
| **Полная A09-спецификация** | **99–149** |

---

## 15. Открытые вопросы для TD

1. **Shared hook:** разрешить 3–5 строк в `scripts/audio/audio_director.gd` для child `SceneAudioDirector`? Если нет — кто добавляет node в `GreyboxLocation` (A03) и когда?
2. **M1 music:** создавать 5 новых `m1_*` cue или переиспользовать `lobby/park/cell/black_sea`? Рекомендация: минимум — reuse, quality — new.
3. **A03 map:** обновляет ли A03 `POST_NIGHTMARE_AUDIO` на новые ID, или A09 делает runtime override? Рекомендация: A03 map.
4. **Anchors:** добавляет ли A03 `AudioAnchors`/`VfxAnchors` Marker3D, или A09 hardcodes POI coords из manifest?
5. **VO:** M1 принимается text-only или нужен SAPI dev-placeholder? Кто разрешает SAPI в build/распространении?
6. **Shroud VFX:** particle-only или mesh ribbon от A07? Для M1 рекомендация — particle-only.
7. **SFX sourcing:** только project-owned procedural или разрешены CC0/CC BY с записью лицензий? Рекомендация: procedural для M1.
8. **SFX bus reverb:** менять `default_bus_layout.tres` в M1 или P2? Рекомендация: P2.
9. **Tests/probe ownership:** A10 пишет `tests/test_m1_audio_profiles.gd` и `tools/audit/audio_vfx_probe_m1.gd` по cases A09, или A09 получает carve-out на `tools/audio/**`? Сейчас `tools/audio/**` не указан ни за A09, ни за A10.
10. **Storm Z17:** подтвердить, что A09-09 не начинается до M1 PASS (`A00-08`), и что Z11–Z18 не входят в M1.
11. **Listening:** кто предоставляет пользователя/наушники/время и подписывает `M1_LISTENING_TEST.md`? A10 или пользователь?
12. **Branch/commit:** A09 работает в worktree без коммитов или может делать локальные commits на `a09/audio-vfx` для TD cherry-pick? FILE_OWNERSHIP говорит «не коммитить», но отдельная ветка требует точки слияния.

---

## 16. NOT TESTED / границы

- Ни один игровой файл в рамках этой спецификации не изменялся.
- Слуховой тест M1 не выполнялся; все уровни — целевые, не подтверждённые на слух.
- Полный ручной проход M1 не выполнялся.
- FPS/VRAM M1-сцен не измерялись.
- 4K/ultrawide, геймпад, локализация — вне A09.
- Финальный VO, лицензии SAPI и внешняя музыка — не решены.
- Полный GUT в live tree нестабилен (633/634); targeted-наборы — единственное доказательство.
- `MCP editor` может быть disconnected; live-скриншоты не гарантированы, использовать headless/capture.

**Конец спецификации.**
