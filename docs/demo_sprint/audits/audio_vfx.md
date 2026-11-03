# Аудит аудио и VFX — демо-фрагмент Лабиринта

**Дата:** 2026-11-02  
**Автор:** Chat 09 — Lead Audio Designer / VFX Artist  
**Область:** `labyrinth_first_fragment` (18 зон), боевые и интерактивные события, HUD/квестовые звуки, VFX окружения и боя.  
**Статус:** технический аудит + реализованный demo-слой. Это **не финальный микс** и **не слуховой тест**.

---

## 1. Краткий итог

До этой сессии у Лабиринта был рабочий каркас `AudioDirector`, но сам фрагмент звучал почти пусто:

- 18 зон имели ambience-записи, но без выраженных шторма, костра, прилива-предупреждения и существ;
- бой и карапаксы существовали в коде, но без собственных голосов, impact/death VFX;
- подбор предметов, NPC, костёр и квестовые сигналы не имели отдельных звуков;
- VFX ограничивались `HitSpark`/`HitFlash`; не было дождя, молний, брызг прилива, пыли, мошек и смерти карапакса;
- `SfxPool` при переполнении мог вытеснить критический звук низкоприоритетным;
- в рабочем `project.godot` отсутствовал autoload `AudioDirector` — звук демо-сцены не запускался бы вообще.

Добавлен project-owned demo-слой:

| Что | Объём |
|---|---:|
| Новые SFX-cue | 12 |
| Новые music-cue | 1 (`labyrinth_storm`, 3 слоя) |
| Новые ambience-петли | 2 (костёр, штормовой дождь) |
| Новые аудиофайлы | 17 (12 WAV + 5 OGG), ≈1,9 МБ |
| Новые VFX-сцены | 6 |
| Новые particle emitters в сцене | 15, суммарно 1478 частиц |
| Итоговая таблица | 61 SFX, 14 music, 29 ambience-зон |

Все новые звуки сгенерированы процедурно и принадлежат проекту. Внешних сэмплов, чужих треков и новых лицензионных обязательств нет.

---

## 2. Архитектура, которая уже была

| Компонент | Файл | Роль | Состояние |
|---|---|---|---|
| `AudioDirector` | `scripts/audio/audio_director.gd` | autoload-фасад, шины, ducking, reverb, pause, captions | работает; autoload был потерян в рабочем `project.godot`, восстановлен |
| `MusicDirector` | `scripts/audio/music_director.gd` | 3-слойные music-cue, crossfade, intensity | работает |
| `AmbienceDirector` | `scripts/audio/ambience_director.gd` | bed/mid + random details, crossfade | работает |
| `SfxPool` | `scripts/audio/sfx_pool.gd` | 16 3D + 12 2D + 4 UI голоса, cooldown, priority | исправлена семантика priority |
| `VoiceDirector` | `scripts/audio/voice_director.gd` | VO, ducking, missing-line no-op | работает; VO Лабиринта отсутствует |
| `AudioLibrary` | `scripts/audio/audio_library.gd` | typed cue table + merge addendum | расширен demo-аддендумом |
| `AudioOcclusion` | `scripts/audio/audio_occlusion.gd` | один raycast на старте 3D-звука | базовый уровень |
| `LabyrinthAudio` | `scripts/locations/forgotten_shore_labyrinth/labyrinth_audio.gd` | зона → ambience/music intensity/detail | расширен storm-cue |
| `default_bus_layout.tres` | — | Master/Music/Ambience/SFX/Voice/UI/Reverb + limiter | без изменений |

### 2.1. Шины и маршрутизация

```text
Master (compressor + limiter)
├── Music     → Reverb
├── Ambience  → Reverb
├── SFX       → Master (dry)
├── Voice     → Master
├── UI        → Master
└── Reverb    → Master
```

- 3D SFX используют `AudioStreamPlayer3D` с `ATTENUATION_LOGARITHMIC`, `unit_size` и `max_distance` из cue.
- 2D SFX (шаги, UI) идут в `SFX`/`UI`; шаги не панорамируются, что корректно для игрока.
- Голос ducking: музыка −8 дБ, ambience −4 дБ, release 0.35 с.
- Новые VFX-звуки не создают собственных шин и не обходят `AudioDirector`.

---

## 3. Инвентарь звука

### 3.1. Базовые ресурсы (до demo-слоя)

| Категория | Количество | Комментарий |
|---|---:|---|
| Шаги | 27 WAV | 9 поверхностей × 3 варианта |
| Боевые | 12 WAV | swing/hit/block/dodge/larva/tyrant |
| Мир | 17 WAV | двери, ключ, pickup, вода, камень, прилив, шторм, кость, коралл, колокол, whip, ритуал |
| UI | 14 WAV | hover/click/back/tab/slider/toggle/error/confirm/map/quest/item/skill |
| Музыка | 13 cue × 3 слоя | menu/park/caravan/camp/sanctuary/labyrinth/pilgrim/finale + короткие cue |
| Ambience | 29 зон | включая `labyrinth` и `labyrinth_z01…z18` |
| Голос | 146 lines + 30 barks | SAPI, временно; в Лабиринте не используется |

### 3.2. Новый demo-слой

| Файл | Назначение | Длина | Пик |
|---|---|---:|---:|
| `creature_carapace_chitter_01.wav` | потрескивание/шипение карапакса | 0.95 с | −2.9 dBFS |
| `creature_carapace_click_01.wav` | шаговые щелчки хитина | 0.22 с | −4.2 dBFS |
| `creature_carapace_attack_01.wav` | замах/щелчок клешни | 0.42 с | −3.9 dBFS |
| `creature_carapace_death_01.wav` | треск панциря + оседание | 1.45 с | −4.5 dBFS |
| `world_tide_warning_01.wav` | низкий сигнал подъёма воды | 3.20 с | −3.1 dBFS |
| `world_water_splash_01.wav` | всплеск/брызги | 0.85 с | −3.3 dBFS |
| `world_wind_gust_01.wav` | порыв ветра | 2.20 с | −4.4 dBFS |
| `world_azure_blade_01.wav` | холодный звон Азурного клинка | 2.40 с | −5.8 dBFS |
| `world_soul_shard_01.wav` | кристаллический осколок | 1.80 с | −4.8 dBFS |
| `world_echo_whisper_01.wav` | безсловесное присутствие Эха | 2.80 с | −6.0 dBFS |
| `world_stone_shift_01.wav` | подвижка камня | 1.70 с | −5.2 dBFS |
| `world_campfire_rest_01.wav` | вспышка/треск костра при отдыхе | 1.90 с | −3.6 dBFS |
| `ambience/campfire_loop_01.ogg` | позиционная петля костра | 7.65 с | −4.3 dBFS |
| `ambience/storm_rain_loop_01.ogg` | штормовой дождь/ветер | 15.65 с | −4.4 dBFS |
| `music/labyrinth_storm_base.ogg` | низкий дрон | 15.40 с | −4.8 dBFS |
| `music/labyrinth_storm_pulse.ogg` | редкие удары | 15.40 с | −5.0 dBFS |
| `music/labyrinth_storm_melody.ogg` | высокие стеклянные обертоны | 15.40 с | −4.3 dBFS |

### 3.3. Что подключено к событиям

| Событие | Звук | Точка подключения |
|---|---|---|
| Шаг по поверхности | `footstep_mud/coral/bone/stone/wood/metal` | `SurfaceDetector` (существующий) |
| Замах игрока | `combat_swing_armed/unarmed` | `CombatController.try_light_attack` |
| Уклонение/блок/guard break | `combat_dodge/block_*/guard_break` | `CombatController` |
| Попадание по живой цели | `combat_hit_flesh/bone/carapace/armor` | `Hurtbox.receive_hit` |
| Смертельный удар | без hit-cue, затем death-cue владельца | `Hurtbox` + `CarapaceEnemy._on_died` |
| Телеграф карапакса | `creature_carapace_chitter` | `CarapaceEnemy._enter(TELEGRAPH)` |
| Атака карапакса | `creature_carapace_attack` | `CarapaceEnemy.attack_started_audio` |
| Смерть карапакса | `creature_carapace_death` + `death_carapace.tscn` | `CarapaceEnemy._on_died` |
| Подбор Азурного клинка | `world_azure_blade` | `LabyrinthAtmosphere._configure_gameplay_interactions` |
| Подбор осколка | `world_soul_shard` | там же |
| Разговор с NPC | `ui_confirm` | там же |
| Отдых у костра | `world_campfire_rest` | там же |
| Прилив: предупреждение | `world_tide_warning` | `LabyrinthAtmosphere._poll_tide` |
| Прилив: гейты | `world_tide_surge` | `LabyrinthAudio._poll_tide` |
| Шторм: музыка | `labyrinth_storm` | `LabyrinthAudio._apply_zone` |
| Шторм: гром | `world_storm_rumble` | `LabyrinthAtmosphere._flash_lightning` |
| Вход в зону | зональный ambience + один event-cue | `LabyrinthAudio` + `LabyrinthAtmosphere` |
| Квест начат/цель/завершён | `ui_quest_update` / `ui_skill_unlock` | `LabyrinthAtmosphere._connect_quest_audio` |

---

## 4. VFX-инвентарь

| Сцена | Назначение | Частиц | Синхронизация |
|---|---|---:|---|
| `impact_ichor.tscn` | лазурные брызги при попадании | 26 + 10 | `Hurtbox.receive_hit` |
| `impact_dust.tscn` | пыль/крошка при ударе о камень/кость | 18 | `Hurtbox.receive_hit`, зоны |
| `death_carapace.tscn` | осколки панциря + ихор + пыль | 34 + 18 + 14 | `CarapaceEnemy._on_died` |
| `tide_spray.tscn` | брызги/пена при открытии шлюзов | 42 + 16 | `TideController.is_high_water` |
| `storm_rain.tscn` | дождь + дымка, следует за игроком | 800 + 48 | зона Z16–Z18 |
| `azure_motes.tscn` | медленные лазурные мошки | 22 | Azure Blade / осколки |

Дополнительно:

- `nm_fire_flame.tscn` + `p3_camp_smoke.tscn` — костёр в Z10; статичная колба пламени скрыта, чтобы не было двойного огня.
- `nm_tide_water.gdshader` — вода с fresnel/foam; применена к `Tide/WaterPlane`.
- `HitSpark`/`HitFlash` — существующие hit-подтверждения, не дублируются новыми сценами без нужды.

### 4.1. Бюджет

| Показатель | Значение |
|---|---:|
| Постоянные emitters | 15 |
| Постоянные частицы | 1478 |
| Одно попадание | ≈36 частиц (ichor) + 18 (dust) |
| Смерть карапакса | 66 частиц, 1.4 с |
| Прилив | 58 частиц на точку, 1.4 с |
| Дождь | 848 частиц, 30 fixed FPS |
| One-shot очистка | `OneShotVfx` timer + `queue_free` |

---

## 5. Найденные и исправленные дефекты

### 5.1. Отсутствовал `AudioDirector` autoload — Critical

В рабочем `project.godot` не было строки `AudioDirector` и секции `[audio] buses/default_bus_layout`. `AudioDirector` был `null`; любой `play_sfx`/`play_music` в демо-сцене не работал, аудио-тесты падали с `AudioDirector autoload` = null.

**Исправлено:** autoload и `[audio]` восстановлены. `[rendering]` P5-настройки позже восстановил другой чат; проверено.

### 5.2. `SfxPool` мог вытеснить критический звук — High

При переполнении пула `_acquire` выбирал голос без сравнения с приоритетом входящего cue: тихий шаг/UI мог занять место `CRITICAL`. Кроме того, выбор жертвы был инвертирован относительно enum.

**Исправлено:** `_can_replace` не даёт низкому приоритету вытеснять более высокий; `_acquire` крадёт **наименее важный** голос, а при равном приоритете — самый старый.

### 5.3. Мировые объекты щёлкали UI-звуком — Medium

`Interactable.interact()` всегда играл `ui_click`; подбор клинка, осколка, костёр и NPC звучали как кнопка меню.

**Исправлено:** `Interactable` получил `interact_cue`/`interact_volume_db`; мир по умолчанию использует `world_pickup`, а конкретные объекты — свои cue. `ui_*` остаётся для UI.

### 5.4. Не было demo-слоя существа/шторма/костра — High

Карапакс имел только `combat_swing_unarmed` и `combat_hit_carapace`; шторм — только редкий rumble; костёр — статичную колбу без звука.

**Исправлено:** 4 creature-cue, `labyrinth_storm`, `campfire_loop`, `storm_rain_loop`, event-cue.

### 5.5. Петли могли щёлкать — Medium

Новые OGG-петли изначально имели стерео-декорреляцию через circular roll; граница петли попадала на несглаженный участок. Проверка `check_demo_audio.py` показывала скачок.

**Исправлено:** одинаковые каналы, crossfade 0.35 с и 12-мс zero-edge fade; boundary seam 0.00088/0.00481.

### 5.6. Смертельный удар дублировал hit + death — Medium

`Hurtbox` играл hit-cue даже когда урон смертельный, а `CarapaceEnemy` сразу играл death-cue. Два события накладывались.

**Исправлено:** при `health.is_dead()` hit-cue и impact VFX не играют; остаётся death-cue + death VFX.

### 5.7. `labyrinth_quest_director.gd` не парсился — High (чужой файл)

`Array[StringName]([...])` и `Array[StringName]()` в позиции аргумента давали parse error. Сцена Лабиринта не загружалась.

**Исправлено:** заменено на `[]`; владельцу 04 нужно проверить типизацию `required_flags`. Это единственная правка в чужом quest-файле.

---

## 6. Оставшиеся пробелы и риски

### Critical / High

1. **Слуховой тест не выполнялся.** Все выводы о балансе — по метрикам и коду, не по ушам. `NOT TESTED`.
2. **VO Нефис/Кассии отсутствует.** Диалоги текстовые; `DialogueRunner` пытается `play_voice`, `VoiceDirector` тихо возвращает false. SAPI в Лабиринт не добавлялся.
3. **Полный GUT не завершён.** Целевые 77 тестов (53 audio/VFX + 24 combat regression) зелёные; полный прогон оборвался на внешнем тесте (`test_test_enemy`), итоговой сводки нет. Это состояние общего дерева, не audio/VFX.

### Medium

4. **Музыка процедурная.** `labyrinth_storm` — temp-тема; нет bar-sync, переходов по фразам, живых стемов.
5. **Ambience-петли 16 с.** Повторяемость слышна на длинной дистанции; random details смягчают, но не решают.
6. **Окклюзия — один raycast на старте.** Длинные loop-звуки костра/шторма не обновляют фильтр; ambience не окклюдируется.
7. **SFX bus dry.** Нет per-cue reverb send; в туннеле Z09 удар звучит суше, чем хотелось бы.
8. **Треугольники сцены ≈8,1 млн.** Выше бюджета 2,5–3,5 млн; это арт-слой, не VFX, но влияет на FPS.
9. **FPS на целевом железе не измерен.** `scene_stats` headless даёт `fps=5` первого кадра — не результат.

### Low

10. **Нет отдельных cue для Nephis/Cassia presence.** Только `ui_confirm` при старте диалога.
11. **Нет sound captions для новых событий, кроме tide warning.** Caption задан только у `world_tide_warning`.
12. **Нет автоматического теста на clipping полного микса.** Есть per-file peak и limiter.

---

## 7. Лицензии и распространение

- Все 17 новых аудиофайлов — project-owned, сгенерированы `tools/audio/generate_demo_audio.py`; сторонних сэмплов нет.
- Все VFX-сцены и скрипты — project-owned.
- Референсы из `docs/audio/AUDIO_DESIGN_DOCUMENT.md` остаются ссылками; в сборку не входят.
- SAPI-голос в Лабиринте не используется. Для остальной кампании SAPI остаётся временным и не должен распространяться как voice pack.
- `assets/audio/sanctuary/stone_door_large_001.ogg` (CC BY 4.0, DWOBoyle) относится к святилищу, не к Лабиринту. Если сборка включает святилище, нужна атрибуция.
- Новые записи внесены в `docs/ASSET_LICENSES.md`.

---

## 8. Проверка

| Проверка | Результат |
|---|---|
| `godot --headless --path . --import` | exit 0 |
| `test_audio_system.gd` | 19/19, 193 assert |
| `test_audio_playback.gd` | 7/7, 36 assert |
| `test_labyrinth_audio.gd` | 6/6, 65 assert |
| `test_demo_audio_vfx.gd` | 8/8, 66 assert |
| `test_labyrinth_first_fragment.gd` | 13/13, 332 assert |
| `test_carapace_enemy.gd` (regression) | 9/9, 43 assert |
| `test_combat_controller.gd` (regression) | 9/9, 53 assert |
| `test_sunny_combat.gd` (regression) | 6/6, 30 assert |
| `audio_vfx_probe.gd` | exit 0; 15 emitters / 1478 particles; pickup/death VFX true |
| `location_capture.gd` | exit 0; 25 PNG; campfire и rain визуально видны |
| `check_demo_audio.py` | 17 файлов; clipping/DC/seam в норме |
| `measure_loudness.py` | значения ниже; не заменяет слуховой тест |
| Полный GUT | **не завершён** (exit −1 на внешнем тесте); не считается доказательством |

### 8.1. Метрики громкости

| Файл | I, LUFS | TP, dBTP |
|---|---:|---:|
| campfire_loop | −22.2 | −4.1 |
| storm_rain_loop | −12.7 | −4.0 |
| labyrinth_storm_base | −12.2 | −4.8 |
| labyrinth_storm_pulse | −19.2 | −5.0 |
| labyrinth_storm_melody | −13.5 | −4.3 |
| tide_warning | −15.7 | −3.1 |
| campfire_rest | −17.5 | −3.6 |

Это исходная громкость файлов; runtime-твики (`bed_db`, `volume_db`) применяются отдельно. Полный микс не измерялся.

---

## 9. NOT TESTED

- Прослушивание на мониторах/наушниках, разборчивость, баланс, утомляемость.
- Полный ручной проход 18 зон с боями, приливом и штормом.
- Синхронизация с фактическими анимациями карапакса/Санни в живом окне.
- FPS/draw calls на RTX 3060 Laptop при 1080p.
- Окклюзия длинных loop-звуков и reverb-переходы на краях зон.
- Распространение сборки и юридическая проверка SAPI/CC BY.
- Полный GUT с итоговой сводкой.

---

## 10. Вердикт

Demo-слой **технически пригоден** для показа: звуки и VFX подключены к реальным сигналам, целевые тесты зелёные, сцена запускается, probe подтверждает события. Это **не финальный саунд-дизайн**: нет слухового теста, VO, живой музыки и оптимизации сцены. Все оставшиеся риски перечислены выше и в `docs/demo_sprint/qa/audio_vfx_report.md`.

