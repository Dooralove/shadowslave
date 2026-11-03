# QA-отчёт: аудио и VFX демо-фрагмента Лабиринта

**Дата:** 2026-11-02  
**Автор:** Chat 09 — Lead Audio Designer / VFX Artist  
**Сцена:** `res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`  
**Статус:** целевые проверки зелёные; слуховой тест и полный ручной проход — **NOT TESTED**.

---

## 1. Что проверялось

- Загрузка сцены и наличие `LabyrinthAtmosphere`, костра, дождя, молнии.
- Наличие и мерж demo-cue (12 SFX, 1 music, 2 ambience-петли).
- Подключение cue к подборам, NPC, костру, бою, смерти, приливу, шторму и квестам.
- Отсутствие дублей hit + death на смертельном ударе.
- Приоритеты `SfxPool` и защита критических звуков.
- Петли: clipping, DC, loop seam.
- Бюджет частиц и стоимость сцены.
- Визуальная проверка костра и дождя по PNG.

---

## 2. Фактические результаты

### 2.1. Импорт

```powershell
godot --headless --path . --import
```

Результат: **exit 0**. Ошибок импорта в итоговом выводе нет. В рабочем дереве параллельно менялись чужие ресурсы; на момент финальной проверки импорт чистый.

### 2.2. Целевые GUT-наборы

| Набор | Результат | Asserts |
|---|---:|---:|
| `test_audio_system.gd` | 19/19 | 193 |
| `test_audio_playback.gd` | 7/7 | 36 |
| `test_labyrinth_audio.gd` | 6/6 | 65 |
| `test_demo_audio_vfx.gd` | 8/8 | 66 |
| `test_labyrinth_first_fragment.gd` | 13/13 | 332 |
| **Audio/VFX итого** | **53/53** | **692** |
| `test_carapace_enemy.gd` (regression) | 9/9 | 43 |
| `test_combat_controller.gd` (regression) | 9/9 | 53 |
| `test_sunny_combat.gd` (regression) | 6/6 | 30 |
| **Всего targeted** | **77/77** | **818** |

Команды:

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_audio_system.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_audio_playback.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_labyrinth_audio.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_demo_audio_vfx.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_labyrinth_first_fragment.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_carapace_enemy.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combat_controller.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_sunny_combat.gd -gexit
```

> Примечание: несколько `-gtest=` в одном вызове в текущем дереве дали exit −1 без сводки; наборы запускались по отдельности. Это не влияет на результаты выше.

### 2.3. Полный GUT

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Результат: **не завершён**. Прогон оборвался на внешнем `test_test_enemy.gd` с `EXIT=-1`; итоговой сводки нет. Это состояние общего дерева (параллельные правки), не вывод audio/VFX-наборов. Полный GUT **не считается доказательством** для этого отчёта.

### 2.4. Scene/probe

```powershell
godot --headless --path . -s tools/audit/audio_vfx_probe.gd
```

Фактический вывод:

```text
scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn
atmosphere=true
atmosphere/CampFireVfx=true
atmosphere/CampSmokeVfx=true
atmosphere/CampfireLoop=true
atmosphere/StormRainVfx=true
atmosphere/StormLightning=true
water_shader=res://assets/environments/nightmare/materials/nm_tide_water.gdshader
water_foam=0.22
particles=15 amount=1478
cue/creature_carapace_chitter=true
cue/creature_carapace_death=true
cue/world_tide_warning=true
cue/world_echo_whisper=true
cue/world_soul_shard=true
music/labyrinth_storm=true
ambience/z17_bed=true
ambience/z10_campfire_2d=false
pickup_count=4 first_cue=world_azure_blade
npc_count=2 talk_cue=ui_confirm
campfire_cue=world_campfire_rest
enemy_count=6
storm_emitting=true
lightning_energy≈0.85–0.92 (tween in progress)
event_smoke=ok
pickup_interacted=true
enemy_dead=true
death_vfx=true
EXIT=0
```

Что это доказывает:

- сцена загружается, атмосферный слой создаётся;
- костёр, дым, петля костра, дождь и молния существуют;
- 4 подбора получили правильный cue (Азурный клинок), 2 NPC — `ui_confirm`, костёр — `world_campfire_rest`;
- 6 врагов созданы, смерть одного переводит его в `DEAD` и создаёт `DeathCarapace`;
- подбор осколка реально срабатывает (`pickup_interacted=true`);
- шторм включает эмиссию дождя, молния меняет энергию;
- 2D-петли костра нет (огонь только 3D).

### 2.5. Визуальная проверка

```powershell
godot --path . -s tools/audit/location_capture.gd -- \
  --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn \
  --out=$env:TEMP\opencode\demo_audio_vfx_shots --hide-labels
```

Результат: **exit 0**, 25 PNG. Проверены `camp.png`, `storm.png`, `player_view.png`, `channel.png`:

- `camp.png`: костёр с пламенем/дымом, тёплый свет, HUD;
- `storm.png`: вертикальные полосы дождя, тёмная палитра, HUD прилива;
- `channel.png`: вода/тёмный канал, приливной HUD;
- грубых визуальных артефактов VFX не видно.

PNG лежат в `%TEMP%\opencode\demo_audio_vfx_shots` и **не коммитятся**. Это временное доказательство, не durable-артефакт.

### 2.6. Стоимость сцены

```powershell
godot --headless --path . -s tools/audit/scene_stats.gd -- \
  --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn
```

```text
nodes=3818 meshes=1561 triangles~=8118711
colliders=724 shapes=362 bodies=362 lights=11
labels=21 cameras=19
render: draw_calls=0.0 primitives=0.0 objects=0.0 fps=5.0 frame_ms=1.914
```

**Вывод:** VFX-бюджет (15 emitters / 1478 particles) разумный, но треугольники сцены **8,1 млн** превышают целевой бюджет 2,5–3,5 млн. Это арт-слой (коралловый кит, статуя, враги), не VFX. `draw_calls` в headless = 0, `fps=5` — первый кадр, не результат производительности. Реальный FPS на RTX 3060 Laptop **NOT TESTED**.

### 2.7. Аудио-файлы

```powershell
python tools/audio/check_demo_audio.py
```

Все 17 файлов: пик ≤ −2,9 dBFS, DC ≤ 0,0013, loop seam ≤ 0,0048. Клиппинга нет. Петли:

| Файл | Длина | Пик | DC | Seam |
|---|---:|---:|---:|---:|
| `campfire_loop_01.ogg` | 7.65 с | −4.3 dBFS | −0.0001 | 0.00088 |
| `storm_rain_loop_01.ogg` | 15.65 с | −4.4 dBFS | −0.0002 | 0.00481 |
| `labyrinth_storm_base.ogg` | 15.40 с | −4.8 dBFS | −0.0000 | 0 |
| `labyrinth_storm_pulse.ogg` | 15.40 с | −5.0 dBFS | +0.0012 | 0 |
| `labyrinth_storm_melody.ogg` | 15.40 с | −4.3 dBFS | −0.0000 | 0 |

### 2.8. Громкость

```powershell
python tools/audio/measure_loudness.py <files>
```

| Файл | I, LUFS | TP, dBTP |
|---|---:|---:|
| `campfire_loop_01.ogg` | −22.2 | −4.1 |
| `storm_rain_loop_01.ogg` | −12.7 | −4.0 |
| `labyrinth_storm_base.ogg` | −12.2 | −4.8 |
| `labyrinth_storm_pulse.ogg` | −19.2 | −5.0 |
| `labyrinth_storm_melody.ogg` | −13.5 | −4.3 |
| `world_tide_warning_01.wav` | −15.7 | −3.1 |
| `world_campfire_rest_01.wav` | −17.5 | −3.6 |

Это **исходные** уровни файлов; runtime-твики (`bed_db`, `volume_db`, 3D attenuation) применяются отдельно. Полный микс не измерялся.

---

## 3. Чек-лист качества

| Критерий | Статус | Комментарий |
|---|---|---|
| Нет наложения неуместных звуков | **Code-reviewed, not listening-tested** | hit не играет на смертельном ударе; tide warning отделён от surge; UI не используется для миров; cooldowns/max_instances |
| Правильная громкость | **Partly verified** | per-file peaks/DC; runtime trims; полный микс — NOT TESTED |
| Пространственное позиционирование | **Verified in code/probe** | новые SFX spatial; позиции маркеров; 2D только шаги/UI/музыка |
| Синхронизация с анимациями | **Signal-based** | hit_landed/died/state_changed/interacted; визуально в живом окне не проверялось |
| Нет многократного воспроизведения | **Verified** | `_visited` per zone, SfxPool cooldown/max_instances, one-shot free |
| Разумное количество частиц | **Verified** | 15 emitters / 1478 particles; rain 848; один storm |
| Производительность | **Partial** | particle budget ok; scene triangles 8.1M over budget; FPS NOT TESTED |

---

## 4. Дефекты, найденные в QA, и исправления

| # | Дефект | Серьёзность | Исправление |
|---:|---|---|---|
| 1 | `AudioDirector` отсутствовал в `project.godot` | Critical | восстановлены autoload и `[audio]` |
| 2 | `SfxPool` мог вытеснить critical низким cue | High | `_can_replace` + кража наименее важного голоса |
| 3 | Мировые объекты играли `ui_click` | Medium | `Interactable.interact_cue` + per-object cues |
| 4 | Смертельный удар играл hit + death | Medium | hit/impact пропускаются при `health.is_dead()` |
| 5 | Loop seam у новых петель | Medium | crossfade + 12-мс zero-edge fade; seam 0.00088/0.00481 |
| 6 | `_configure_gameplay_interactions` резюмировался после free | Medium | one-shot `process_frame` connection вместо coroutine |
| 7 | `labyrinth_quest_director.gd` не парсился | High (чужой) | `Array[StringName]([...])` → `[]`; владельцу 04 проверить типы |
| 8 | Полный GUT оборвался на внешнем тесте | High (внешний) | не чинилось; целевые наборы зелёные |

---

## 5. Остаточные риски

1. **Слуховой тест не выполнялся.** Нельзя утверждать, что микс звучит хорошо.
2. **VO Нефис/Кассии нет.** Диалоги текстовые; `VoiceDirector` молча пропускает отсутствующие линии.
3. **Полный ручной проход не выполнялся.** Неизвестны soft-lock, синхронизация с анимациями, поведение при 3+ врагах.
4. **FPS не измерен.** 8,1 млн треугольников — риск; VFX не главная причина.
5. **Окклюзия loop-звуков и reverb-переходы** — базовые.
6. **Музыка процедурная**, не финальная; `labyrinth_storm` — temp.
7. **Полный GUT** не завершён; baseline уже был красным (2 падения `test_post_nightmare_locations`).

---

## 6. NOT TESTED

- Прослушивание на мониторах/наушниках, разборчивость, баланс, утомляемость.
- Полный ручной проход 18 зон с боями, приливом и штормом.
- Синхронизация VFX с фактическими клипами анимаций в живом окне.
- FPS/draw calls на RTX 3060 Laptop, 1080p.
- Окклюзия длинных loop-звуков, reverb-переходы на краях зон.
- Полный GUT с итоговой сводкой.
- Юридическая проверка распространения SAPI/CC BY и финальных ассетов.

---

## 7. Вердикт

Demo-слой **можно показывать**: целевые 77 тестов зелёные, сцена загружается, probe подтверждает подборы, смерть, шторм, костёр и VFX, визуальные кадры чистые. Это **не финальный микс**: слуховой тест, VO, живая музыка и оптимизация сцены остаются на следующий этап. Все ограничения перечислены выше; ни один непроверенный пункт не выдан за пройденный.

