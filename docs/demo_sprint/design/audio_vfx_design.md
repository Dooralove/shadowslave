# Дизайн аудио и VFX — демо-фрагмент Лабиринта

**Дата:** 2026-11-02  
**Автор:** Chat 09 — Lead Audio Designer / VFX Artist  
**Область:** `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn` — 18 зон, три акта, полный цикл прилива и шторм.  
**Связанные документы:** `docs/demo_sprint/audits/audio_vfx.md`, `docs/demo_sprint/qa/audio_vfx_report.md`, `docs/audio/AUDIO_DESIGN_DOCUMENT.md`, `docs/design/level_brief_labyrinth_first_fragment.md`, `docs/art/labyrinth_model_map.md`.

---

## 1. Задача и границы

Демо-фрагмент должен звучать как **одно живое место**, а не как набор заглушек:

- у каждой из 18 зон есть свой фон, детали и поведение при приливе;
- бой читается по звуку и VFX без UI;
- предметы, NPC и костёр звучат по-разному;
- шторм — не «громкий эмбиент», а смена музыки, света и частиц;
- ни один звук не играет «просто так» и не дублируется на одном событии.

**Не входит:** финальный саундтрек, полная озвучка, лицевая анимация, финальный микс, концертный surround. Это demo-слой на процедурных project-owned ассетах.

---

## 2. Звуковая идентичность

**«Холодный свет, тёплая кровь».**

| Опора | Решение |
|---|---|
| Мир | камень, соль, вода, кость, хитин, ветер |
| Люди | дыхание, ткань, огонь, тихий голос |
| Музыка | редкая, низкая, без трейлерного эпика; появляется как присутствие |
| Тишина | полноценный слой; после крупного события 2–3 с без музыки |
| Заклятие/Эхо | один тон/шёпот, искажённый средой, без «скримера» |
| Карапакс | сухой хитин, щелчки, мокрый треск — не рычание |

### 2.1. Что запрещено

- Эпический хор, «braam», постоянный dark-ambient drone.
- Скримеры и резкие визги на каждое событие.
- Современные биты/EDM/lo-fi.
- Прямое копирование Witcher 3 / Bloodborne / Elden Ring.
- Чужие музыкальные файлы в сборке. Референсы — только ссылки.

---

## 3. Микс и пространство

### 3.1. Шины

```text
Master (compressor + limiter, ceiling −1 dB)
├── Music     → Reverb
├── Ambience  → Reverb
├── SFX       → Master (dry)
├── Voice     → Master
├── UI        → Master
└── Reverb    → Master
```

### 3.2. Целевые уровни

| Категория | Цель | Проверка |
|---|---|---|
| Voice | −18…−16 LUFS integrated | ducking музыки −8 дБ, ambience −4 дБ |
| Music | −20…−18 LUFS | слои `base/pulse/melody`, intensity 0.3–0.95 |
| Ambience | −24…−20 LUFS | bed/mid + редкие details |
| SFX | пики −12…−6 dBFS | per-file peak, limiter |
| UI | −20…−16 LUFS | тише игрового SFX |
| Общий микс | −16…−14 LUFS | не «война громкости» |

### 3.3. Пространственность

- Все новые игровые SFX — `spatial=true`, mono-источники; 2D — только шаги игрока, UI, музыка/ambience.
- `unit_size`/`max_distance` заданы для каждого cue; костёр — 4/26 м, карапакс — 7/35 м, прилив — 20/120 м.
- Окклюзия — один raycast на старте; для loop-звуков (костёр/шторм) это ограничение, не финальное решение.
- Reverb-профили: `outdoor`, `coral_cave`, `bone_cave`, `tunnel`, `water`, `refuge`, `storm`.

### 3.4. Политика тишины

| Ситуация | Музыка | Ambience | Остаётся |
|---|---|---|---|
| Исследование | 1–2 слоя, тихо | полный | шаги, ветер, вода |
| Первое раскрытие зоны | 20–40 с cue | полный | cue уходит |
| Диалог | duck −8 дБ | duck −4 дБ | голос/текст, дыхание |
| Бой | intensity ↑ | −6 дБ | удары, хитин, крики |
| Смерть | резкий спад | −12 дБ | один death-cue |
| Туннель | без melody | приглушённый | капли, шаги, дыхание |
| Шторм | `labyrinth_storm` | rain/wind | гром, дождь, бег |

---

## 4. Музыка

### 4.1. Основная тема

| Параметр | Значение |
|---|---|
| Cue | `labyrinth` (3 слоя) |
| BPM/тональность | 44 BPM, D minor |
| Инструменты | низкий дрон, сердцебиение-пульс, стеклянные обертоны |
| Слои | `base` всегда; `pulse` при движении/опасности; `melody` редко |
| Интенсивность | из `audio_zones.tres`: 0.3 (Z01/Z02) → 0.95 (Z17) |
| Переход | 4 с crossfade между зонами |
| Тишина | после смерти/крупного события — 2–3 с без музыки |

### 4.2. Штормовая тема

| Параметр | Значение |
|---|---|
| Cue | `labyrinth_storm` (3 слоя) |
| BPM/тональность | 48 BPM, D minor |
| Инструменты | суб-бас D2/A2/F3, редкие удары 3+3+2, высокие стеклянные обертоны |
| Где | Z16–Z18; переход 4 с |
| Правило | не «босс-тема», а погода; мелодия не разрешается |

### 4.3. Что не делаем

- Не ставим готовые треки из игр/фильмов даже как temp в коммит.
- Не делаем отдельную тему на каждую зону: одна тема + интенсивность + штормовой вариант.
- Не запускаем полную тему в Z09 (туннель): только `base`/`pulse` на низкой интенсивности; главное — ambience и шаги.

---

## 5. Зоны: музыка, фон, атмосфера

| Зона | Музыка | Фон (bed/mid) | Атмосферные детали |
|---|---|---|---|
| **Z01 Порог статуи** | `labyrinth`, intensity 0.30 | `labyrinth_z01`: ветер + низкий гул | редкий `world_stone_shift`, `world_wind_gust`; далёкий прилив |
| **Z02 Туша** | `labyrinth`, 0.30 | `labyrinth_z02`: bone bed + низкий mid | `world_bone_creak`, `creature_carapace_click`; мокрое оседание |
| **Z03 Первая развилка** | `labyrinth`, 0.35 | `labyrinth_z03`: коралл + воздух | `creature_carapace_chitter`; удар камня; Эхо ещё нет |
| **Z04 Мутная низина** | `labyrinth`, 0.35 | `labyrinth_z04`: water bed + mud mid | `world_water_drip`, `world_water_splash`; пузыри в грязи |
| **Z05 Костяной проход** | `labyrinth`, 0.40 | `labyrinth_z05`: bone bed | `world_bone_creak`, шаги по кости; капли |
| **Z06 Сухой карман** | `labyrinth`, 0.35 | `labyrinth_z06`: сухой ветер | `world_wind_gust`; осколок души звенит |
| **Z07 Смотровая гряда** | `labyrinth`, 0.40 | `labyrinth_z07`: высокий ветер | `world_wind_gust`; далёкий шторм; скрип костей |
| **Z08 Прогалина** | `labyrinth`, 0.40 | `labyrinth_z08`: коралл + воздух | `world_echo_whisper` при первой встрече; ткань/шаги NPC |
| **Z09 Слепой туннель** | `labyrinth`, 0.45; melody на минимуме | `labyrinth_z09`: tunnel bed | `world_water_drip`, `world_stone_shift`; дыхание; шаги |
| **Z10 Коралловый холм / лагерь** | `labyrinth`, 0.45 | `labyrinth_z10`: camp bed + ветер | костёр (3D loop), треск, ветер; `world_wind_gust` |
| **Z11 Приливной канал** | `labyrinth`, 0.50 | `labyrinth_z11`: water bed + low mid | `world_tide_warning`, `world_tide_surge`, splash; гейты |
| **Z12 Западный перешеек** | `labyrinth`, 0.55 | `labyrinth_z12`: ветер + вода | `world_wind_gust`; далёкий шторм; шаги по мокрому камню |
| **Z13 Охотничьи угодья** | `labyrinth`, 0.70 | `labyrinth_z13`: storm bed + bone mid | `creature_carapace_chitter` (2–3 источника), `world_storm_rumble` |
| **Z14 Костяной мост** | `labyrinth`, 0.55 | `labyrinth_z14`: bone bed | `world_bone_creak`, `world_echo_whisper`; ветер в рёбрах |
| **Z15 Высокое убежище** | `labyrinth`, 0.50 | `labyrinth_z15`: refuge bed | `world_soul_shard`, ветер; тише бой |
| **Z16 Территория стаи** | `labyrinth_storm`, 0.80 | `labyrinth_z16`: storm bed | `creature_carapace_chitter`; дождь; далёкий гром |
| **Z17 Гроза** | `labyrinth_storm`, 0.95 | `labyrinth_z17`: rain bed + storm mid | rain loop, thunder, wind; lightning |
| **Z18 Утёсы** | `labyrinth_storm`, 0.70 | `labyrinth_z18`: storm bed | `world_wind_gust`, `world_stone_shift`; гром; прилив |

**Правило фона:** bed/mid всегда тише шагов и боя; детали — не чаще 1 события в 8–18 с (AmbienceDirector randomizer). Зональные event-cue играют один раз за визит, не на каждом кадре.

---

## 6. Зоны: движение, интерактив, NPC, противники, бой, квесты, VFX

| Зона | Шаги | Интерактив | NPC | Противники | Бой | Квест/событие | VFX |
|---|---|---|---|---|---|---|---|
| **Z01** | stone, coral, mud | — | — | — | — | вход, первый objective | ветер/пыль, без боя |
| **Z02** | mud, bone | — | — | карапаксы-декор | — | тупик-риск | пыль, ихор-следы, кости |
| **Z03** | coral, mud, bone | **Азурный клинок** (beacon) | — | **Wounded Scavenger** | swing/hit/block/dodge; death | первый бой, `azure_blade`; после боя клинок доступен | ichor/dust impact, death burst, azure motes |
| **Z04** | mud, stone | — | — | — | — | низкий маршрут, прилив | splash/spray, мокрые следы |
| **Z05** | bone, stone | — | — | будущие карапаксы | — | узкий проход | пыль, костяная крошка |
| **Z06** | coral, stone | **Осколок души** | — | — | — | награда за тупик | motes, chime |
| **Z07** | coral, stone | — | — | — | — | верхний обход | ветер, пыль |
| **Z08** | coral, mud | — | **Нефис, Кассия** | — | — | первая встреча, диалог | `ui_confirm`, шёпот Эха, лёгкая пыль |
| **Z09** | stone, mud | — | — | — | — | срез, скрытность | пыль в луче, капли |
| **Z10** | coral, mud, wood | **Костёр** (отдых) | — | — | — | лагерь, чекпоинт | fire/smoke, тёплый свет, dust |
| **Z11** | stone, coral, water→mud | — | — | — | — | приливной шлюз | tide warning, surge, spray, foam |
| **Z12** | stone, mud | — | — | — | — | развилка низ/верх | ветер, брызги |
| **Z13** | mud, coral, bone | — | — | **3 карапакса** (стая) | полноценный бой | охота, `hunt_pack` | chitter, death bursts, dust |
| **Z14** | bone, mud | **Осколок души** | **Эхо** (маркер) | **2 карапакса** | бой на мосту | мост, `bridge_stand` | bone creak, whisper, ichor/dust |
| **Z15** | coral, stone | — | — | — | — | убежище, чекпоинт | тёплый свет, ветер |
| **Z16** | mud, coral | — | — | **стая (future)** | — | давление, гроза | rain start, lightning, chitter |
| **Z17** | coral, stone, mud | — | — | — | возможен бег | шторм, `storm` | rain, lightning, wind, spray |
| **Z18** | stone, coral | — | — | — | — | финал, `cliffs` | rain, wind, stone shift, lightning |

### 6.1. Ключевые зоны подробнее

#### Z03 — Первая развилка

- **До боя:** `creature_carapace_chitter` с направления туши/развилки; музыка intensity 0.35; ветер.
- **Бой:** Wounded Scavenger (65 HP) — телеграф-читет, атака-щелчок, шаговые клики; попадания — `combat_hit_carapace` + ichor/dust; смерть — `creature_carapace_death` + `death_carapace`.
- **После боя:** Азурный клинок становится доступен; при приближении — `world_azure_blade`, motes; подбор — тот же cue, но тише, без UI-клика.
- **Правило:** death-cue не накладывается на hit-cue; `Hurtbox` пропускает hit для смертельного удара.

#### Z10 — Коралловый холм / лагерь

- **Фон:** `labyrinth_z10` bed + ветер; костёр — отдельный 3D loop `campfire_loop` с attenuation 4/26 м, не 2D-петля на всю зону.
- **Визуал:** `nm_fire_flame` + `p3_camp_smoke`; статичная колба `Z10_Campfire_Flame` скрыта, чтобы огонь не двоился.
- **Интерактив:** отдых — `world_campfire_rest`; чекпоинт; тихий `ui_confirm` при подтверждении.
- **Музыка:** intensity 0.45; после отдыха не менять cue, только короткий release.

#### Z11 — Приливной канал

- **За 12 с до гейта:** `world_tide_warning` (низкий рог + вода), caption «Прилив поднимается».
- **При закрытии:** `world_tide_surge`; брызги `tide_spray` у Z11/Z14/Z16/Z17; foam на воде.
- **После:** вода остаётся высокой; низкий маршрут закрыт; ambience water bed.
- **Правило:** warning и surge не играют одновременно; warning — заранее, surge — на пороге.

#### Z13 — Охотничьи угодья

- **Фон:** storm bed; `world_storm_rumble` редко; chitter с 2–3 точек.
- **Бой:** 3 карапакса; death VFX; после боя — тишина 2–3 с, затем ambience.
- **Квест:** `hunt_pack`; цель обновляется через `QuestSystem` → `ui_quest_update`.
- **VFX:** пыль от рывков, ихор, осколки; без дождя до Z16 (шторм ещё «на горизонте»).

#### Z14 — Костяной мост

- **Фон:** bone bed; `world_bone_creak`; `world_echo_whisper` у маркера Эха.
- **Бой:** 2 карапакса; узкий мост; смерть одного не должна сбрасывать второго.
- **VFX:** пыль/крошка, ихор; при высоком приливе — spray снизу.
- **Квест:** `bridge_stand`; Эхо — без VO, только шёпот и субтитр.

#### Z17 — Гроза

- **Музыка:** `labyrinth_storm`; intensity 0.95; rain loop; wind; thunder.
- **Молния:** каждые 7–15 с; flash 4.2 → 0.2 → 2.1 → 0 за ~0.5 с; thunder через 0.35–1.2 с.
- **VFX:** rain 800 + mist 48, following player; lightning DirectionalLight; spray at low gate.
- **Правило:** не играть thunder одновременно с `world_tide_warning`; cooldown 2 с у rumble.

---

## 7. VFX-дизайн

### 7.1. Боевые атаки

| Событие | VFX | Статус |
|---|---|---|
| Замах игрока | Анимация меча; `HitSpark` только на попадании | реализовано |
| Рывок карапакса | Пыль у земли (`impact_dust`) в точке выпада | реализовано |
| Попадание по карапаксу | Ихор + пыль; `HitSpark` | реализовано |
| Попадание по броне/кости | Пыль/крошка, без ихора | реализовано |
| Блок | `HitSpark` + металлический cue; без крови | реализовано |
| Guard break | Крупный hit + стаггер; без отдельного VFX | реализовано частично |
| Смерть карапакса | Осколки панциря + ихор-туман + пыль | реализовано |
| Смерть игрока | Пыль у земли; анимация смерти | реализовано |

### 7.2. Особые события

| Событие | VFX | Звук |
|---|---|---|
| Прилив | `tide_spray` у шлюзов, foam шейдера воды | warning → surge |
| Шторм | rain + mist + lightning flash | storm music + thunder |
| Костёр | flame + smoke + flicker light | 3D fire loop + rest cue |
| Азурный клинок | azure motes + emissive pickup | `world_azure_blade` |
| Осколок души | motes + emissive prism | `world_soul_shard` |
| Эхо | whisper; без модели | `world_echo_whisper` |
| Пыль в туннеле | dust motes в световом луче | water drip / stone shift |

### 7.3. Бюджет и правила

- Постоянно: 15 emitters / 1478 particles. Это ниже 2000 — разумно для 3060 Laptop.
- Одно-hit VFX: 36–58 particles, жизнь < 1.5 с; `OneShotVfx` освобождает узел по таймеру.
- Дождь: 800 particles, `fixed_fps=30`, `local_coords=false`, follows player; не более одного экземпляра.
- Молния: один DirectionalLight, без теней; без второго источника.
- Не ставить VFX на каждую реплику/шаг; пыль и мошки — фоновые, не событийные.
- Все VFX-сцены не имеют коллизий и не влияют на геймплей.

---

## 8. Реализация: сигналы и файлы

| Событие | Сигнал/точка | Обработчик |
|---|---|---|
| Попадание | `Hurtbox.hit_received` / `receive_hit` | `Hurtbox._play_cue`, `_spawn_impact` |
| Смерть врага | `HealthComponent.died` | `CarapaceEnemy._on_died` |
| Телеграф/атака | `CarapaceEnemy._enter` | `_play_cue`, `VFX.spawn_dust` |
| Подбор | `QuestPickup.interact` → `Interactable.interact` | `LabyrinthAtmosphere._configure_gameplay_interactions` |
| NPC | `QuestNpc` + `Interactable` | там же |
| Костёр | `Interactable` | там же |
| Прилив | `TideController.is_high_water`, `is_rising`, `seconds_until_high` | `LabyrinthAtmosphere._poll_tide`, `LabyrinthAudio._poll_tide` |
| Шторм | зона Z16–Z18 | `LabyrinthAudio._apply_zone`, `LabyrinthAtmosphere._set_storm` |
| Квест | `QuestSystem.quest_started/objective_completed/completed` | `LabyrinthAtmosphere._connect_quest_audio` |
| Зона | `LabyrinthAudio._apply_zone` | `LabyrinthAtmosphere._enter_zone` |

**Файлы demo-слоя:**

```text
assets/audio/demo/sfx/*.wav                 12 коротких cue
assets/audio/demo/ambience/*.ogg            2 петли
assets/audio/demo/music/labyrinth_storm_*   3 слоя
resources/audio/audio_cue_library_demo.tres аддендум
scenes/environment/vfx/*.tscn               6 VFX-сцен
scripts/vfx/one_shot_vfx.gd                 one-shot helper
scripts/audio/labyrinth_atmosphere.gd       зоны/прилив/шторм/костёр
```

**Правило сборки:** после изменения базовых ambience-зон в `audio_cue_library.tres` пересобрать аддендум `godot --headless --path . --script res://tools/audio/build_demo_cues.gd`. Иначе override-зоны сохранят старое bed/mid.

---

## 9. Приёмка

- [x] Все 18 зон имеют музыку/фон/детали в матрице.
- [x] Бой, подбор, NPC, костёр, прилив, шторм и квесты подключены к сигналам.
- [x] Нет UI-клика на мировых объектах.
- [x] Нет death + hit дубля на смертельном ударе.
- [x] Постоянные частицы ≤ 2000; один дождь; один lightning.
- [x] Новые ассеты project-owned; лицензии записаны.
- [x] Целевые 77 тестов зелёные (53 audio/VFX + 24 combat regression).
- [ ] Слуховой тест и ручной проход — **NOT TESTED**.
- [ ] Финальный микс/LUFS всего микса — **NOT TESTED**.
- [ ] Финальная музыка/VO — **не входит в demo-слой**.

---

## 10. Лицензии и распространение

- Новые аудиофайлы: `tools/audio/generate_demo_audio.py`, project-owned, без сторонних сэмплов.
- VFX-сцены/скрипты: project-owned.
- Референсы из ADD — только ссылки, не файлы.
- SAPI-голос в Лабиринте не используется; для остальной кампании остаётся временным.
- CC BY 4.0 `stone_door_large_001.ogg` относится к святилищу; при включении в сборку нужна атрибуция.
- Никакие чужие треки не коммитить и не выдавать за оригинальный саундтрек.

