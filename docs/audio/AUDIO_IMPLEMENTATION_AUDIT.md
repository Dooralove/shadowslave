# Аудит аудиоработы ShadowSlave

**Дата:** 2026-11-02  
**Область:** `AudioDirector`, `MusicDirector`, `AmbienceDirector`, `SfxPool`, `VoiceDirector`, `SurfaceDetector`, шины, настройки, интеграция в сцены, плейсхолдеры, тесты.  
**Режим:** статический разбор + GUT + headless import + сценовые smoke-тесты. Слуховой тест не выполнялся.

---

## 1. Краткий итог

Каркас рабочий: шины, autoload, настройки, SFX-пулы, музыка/ambience, шаги, Лабиринт, reverb-профили и голосовой pipeline существуют и проходят автоматические проверки. P0/P1 закрыты: появились реальные playback-тесты, SAPI-плейсхолдеры, raycast-окклюзия, 3-слойная музыка, randomizer, OGG/mono-сжатие, data-driven зоны и master-цепочка. P2 добавил pause-политику, typed cue table, UI/ritual/finale-звуки и accessibility. Главные оставшиеся риски — **непроверенный слуховой баланс**, **42 МБ SAPI voice**, **полировка окклюзии/reverb**, 83 неозвученные реплики и **NOT TESTED** слепой слуховой тест.

В ходе аудита найдены и исправлены несколько реальных дефектов:

- голосовой `stop()` не отправлял `voice_finished`, из-за чего музыка/ambience могли остаться в ducking;
- `get_reverb_profile()` не обновлялся при `push/pop` reverb-зоны;
- `SurfaceDetector` принимал `"Office"`/`"Police"` за лёд из-за подстроки `"ice"`;
- `MusicDirector.stop()` и `AmbienceDirector.stop()` могли остановить новый cue, начатый во время fade out;
- `AudioLibrary` дублировал looped-потоки для каждого ambience-зона;
- несколько старых `AudioStreamPlayer` обходили шины `Ambience`/`SFX`;
- у некоторых музыки-петель был обрезан хвост на границе цикла;
- order-dependent тест лабиринта был сделан устойчивым (ожидание приземления вместо 6 фиксированных кадров).

---

## 2. Что проверено

- `test_audio_system` — **19/19**, 180 assert.
- `test_audio_playback` — **7/7**, 36 assert (playing, volume_db, cooldown, max_instances, stop/play race, voice ducking, raycast occlusion).
- `test_labyrinth_audio` — **6/6**, 65 assert.
- `test_game_settings` — 6/6.
- `test_main_menu` — 6/6.
- `test_slice_director` — 11/11.
- `test_caravan_march` — 7/7.
- `test_shadow_sanctuary` — 11/11.
- `test_campaign_flow` — 10/10.
- `test_pilgrim_path` — 10/10.
- `test_condition_feedback` — 1/1.
- `test_labyrinth_first_fragment` — 13/13 (standalone).
- `test_shadow_sanctuary` — 11/11; `test_appraisal_and_finale` — 8/8; `test_campaign_flow` — 10/10.
- `godot --headless --path . --import` — без ошибок парсинга аудио-скриптов.
- Смоук-сцены меню, пролога, каравана, лагеря, паломнического пути и Лабиринта — exit 0; аудио-плееры не дают утечек в проверенных сценах.

**Полный GUT: NOT PASSED из-за внешних ошибок** `scenes/slice/locations/park/park_street_art.tscn` и зависимых `sunny`/combat-скриптов. Аудио-набор (73 targeted теста: audio system/playback/lab/menu/settings/sanctuary/appraisal/campaign) — **73/73**, Лабиринт — **13/13**. Полный прогон не считается доказательством для P2, пока внешние сцены не восстановлены.

---

## 3. Найденные и исправленные дефекты

### 3.1. Ducking мог «залипнуть» — High

`VoiceDirector.stop()` останавливал плеер и обнулял `_current`, но не испускал `voice_finished`. `AudioDirector` снимал ducking только по этому сигналу. Если игрок проматывал реплику, закрывал bark или сцена останавливала голос, музыка оставалась приглушённой до 60 секунд.

**Исправлено:** `stop()` теперь испускает `voice_finished` для активной реплики; в headless `play_line()` немедленно закрывает lifecycle; `DialogueRunner`/`BarkUI` получают корректное освобождение.

### 3.2. Reverb-профиль возвращал устаревшее значение — Medium

`push_reverb_profile()`/`pop_reverb_profile()` меняли `_reverb_stack`, но не `_reverb_profile`, поэтому `get_reverb_profile()` показывал старое значение, хотя эффект уже переключился.

**Исправлено:** профиль обновляется при push/pop и при выборе fallback `outdoor`.

### 3.3. `SurfaceDetector` путал `"Office"` с `"ice"` — High

Проверка `name.contains("ice")` срабатывала на `OfficeFloor`, `PoliceStation`, `Service...`. Игрок получал ледяные шаги в офисных/служебных локациях.

**Исправлено:** лёд определяется по началу имени, `ice_`, `_ice`, `icicle`, `frozen`, `glacier`; добавлены регрессионные assert для `OfficeFloor`/`PoliceStation`.

### 3.4. Гонка `stop()` и нового cue — Medium

`MusicDirector.stop(fade)` после `await _fade_out()` безусловно останавливал все слои. Если во время fade уже запускался новый cue, `stop()` убивал его. То же было в `AmbienceDirector.stop()`.

**Исправлено:** оба метода фиксируют request id и после await не трогают более новый запрос. `play_cue`/`play_zone` также не эмитят `cue_changed`/`zone_changed`, если запрос уже устарел.

### 3.5. Дублирование looped-потоков — High (память/старт)

`AudioLibrary.ambience_zones()` создавал looped-копии WAV для каждого зона. 29 зон используют небольшой набор источников, но копии множились. Добавлен кэш `_stream_cache` и кэши словарей `music_cues`/`sfx_cues`/`ambience_zones`; кэш очищается в `AudioDirector._exit_tree`.

Замер `tools/audit/audio_library_probe.gd`: cold-load ~**149 мс** (music 25, SFX 96, ambience 28), ~**36 МБ** static memory. Это не стриминг, но повторные копии устранены.

### 3.6. Часть старых плееров обходила шины — High

`ConditionFeedback` (cold breath/noise), `RockfallHazard` (warning) и `PilgrimPath` (wind/guard/creak) создавали плееры без `bus`, то есть играли в `Master`. Ползунки Ambience/SFX и per-source occlusion на них не действовали.

**Исправлено:** `ConditionFeedback` → `Ambience`; `RockfallHazard` → `SFX`; wind/guard → `Ambience`; creak → `SFX`. Добавлена очистка стримов в `_exit_tree`.

### 3.7. Обрезанные хвосты looped-музыки — Medium

В `park_music` и `pilgrim_music` последняя фраза начиналась слишком поздно и обрезалась на 16-секундной границе, создавая потенциальный щелчок на loop seam.

**Исправлено:** последние фразы сдвинуты внутрь петли; WAV перегенерированы.

### 3.8. Хрупкий тест лабиринта — Low/Medium

`test_player_starts_on_floor` ждал ровно 6 physics frames. При изменении порядка тестов и загрузки сцены игрок иногда ещё не успевал приземлиться. Теперь тест ждёт до 60 кадров до `is_on_floor()`.

### 3.9. P1: слои, randomizer, сжатие, данные зон, reverb, master-цепочка

- 7 music cue переведены на 3 реальных стема `base/pulse/melody` (21 OGG).
- `AmbienceDirector` использует `AudioStreamRandomizer` и редкие one-shot с интервалом 8–18 с.
- Музыка/ambience сжаты в OGG; SFX — mono/22,05 кГц. Объём аудио 47,9 МБ вместо ~94 МБ.
- 18 зон Лабиринта вынесены в `resources/locations/forgotten_shore_labyrinth/audio_zones.tres`; сцена назначает ресурс, `LabyrinthAudio` только читает данные.
- Для всех 18 зон есть reverb-профиль и `ReverbZone`.
- В `Master` добавлены compressor/limiter; `AudioDirector` содержит `AudioEffectCapture`, approximate peak/RMS API и target −18 LUFS; `tools/audio/measure_loudness.py` считает integrated LUFS/TP.

### 3.10. P2: pause, cue table, UI/ritual/finale, accessibility

- Pause: музыка, ambience и UI продолжаются; 3D/2D SFX и voice получают `stream_paused`; добавлен `AudioDirector.apply_pause_policy()` и тест.
- Cue data: 13 music / 49 SFX / 29 ambience вынесены в `resources/audio/audio_cue_library.tres`; `AudioLibrary` — загрузчик typed resource. Первый cold-load ~623 мс, дальше кэш; это цена self-contained table.
- UI: hover/focus sounds в главном меню; ритуальный `world_ritual_offering` вместо `combat_hit_flesh`; `finale` — 3 стема.
- Accessibility: `AudioCaptionOverlay`, captions важных SFX, mono downmix (`AudioEffectStereoEnhance.pan_pullout=0`), full/reduced dynamic range, настройки в Sound-вкладке.
- Слепой слуховой тест не выполнен: протокол `docs/audio/BLIND_LISTENING_TEST.md`, статус **NOT TESTED**.

---

## 4. Оставшиеся риски и улучшения

### Critical / High

1. **Реальный звук всё ещё не прослушан.**  
   `test_audio_playback` проверяет `playing`, `volume_db`, cooldown, max_instances, stop/play race и voice ducking на dummy-драйвере. Но loop seam, клиппинг, разборчивость SAPI и баланс громкостей проверяются только на слух, а он ещё не проводился. Нужен ручной аудиотест на реальных сценах.

2. **Voice озвучен частично.**  
   146 реплик пролога/каравана + 30 барков синтезированы Windows SAPI (Microsoft Irina). 83 реплики остаются без файлов. SAPI — временный голос, не финальное VO; условия использования требуют замены перед релизом.

3. **Окклюзия базовая.**  
   `AudioOcclusion` делает один raycast listener→source на момент запуска, меняет `attenuation_filter_cutoff_hz`/`attenuation_filter_db` конкретного 3D-плеера. Нет многолучевого сглаживания, учёта материала, динамического обновления для длинных loop-звуков и окклюзии ambience/музыки. Для Лабиринта это ещё требует полировки.

### Medium

5. **Музыка теперь трёхслойная, но стемы всё ещё процедурные.**  
   7 cue имеют `base/pulse/melody`; интенсивность реально меняет микс. Но это синтетические 16-секундные петли без фразировки и переходов по барам; для финала нужны утверждённые стемы и музыкальные transition-правила.

6. **Ambience randomizer есть, но материал редкий.**  
   `AudioStreamRandomizer` и one-shot добавлены; детали пока разрежены и привязаны к ограниченному набору звуков. Нужны weather/tide/time-of-day правила и больше вариантов, чтобы 16-секундные bed-петли не читались как повтор.

7. **Данные зон вынесены, но не связаны с визуальными bounds.**  
   `audio_zones.tres` — источник истины для аудио, но координаты всё ещё нужно синхронизировать с `Generated/Visual/<Zone>` вручную. Нужна проверка/генерация из AABB сцены.

8. **Reverb-зоны теперь есть для всех 18 зон, но статичны.**  
   Все зоны получают профиль; нет плавного перехода по краю, учёта размера/материала и per-source send. Нужна полировка reverb-переходов.

9. **Master-chain и LUFS-контроль — базовые.**  
   Compressor + limiter + `AudioEffectCapture` + `measure_loudness.py` есть. Runtime meter — приблизительный RMS/peak, не K-weighted LUFS; нет автоматического gate/динамического range. Нужен настоящий LUFS-метр и проверка пиков на всех ассетах.

10. **Cue-данные — закрыто в P2.**  
    `AudioLibrary` теперь загружает `resources/audio/audio_cue_library.tres`; 13 music cue, 49 SFX и 29 ambience-зон редактируются как typed Resources.

11. **Pause policy — закрыто в P2.**  
    Музыка, ambience и UI продолжаются; 3D/2D SFX и voice получают `stream_paused`. Остаётся ручная проверка в реальном pause-меню/катсцене.

12. **Ducking проверен не до конца.**  
    Ducking музыки/ambience реализован; playback-тест проверяет `_duck_db`, но не фактическую громкость каждого слоя/плеера после tween.

### Low

13. **Строгая подстрочная эвристика поверхностей.**  
    Лёд исправлен, но `stone`/`wood`/`metal` всё ещё используют `contains`; имена вроде `Milestone` могут дать ложное срабатывание. Лучше metadata `surface` везде или token-boundary helper.

14. **Основной объём теперь — SAPI voice.**  
    Музыка/ambience в OGG, SFX mono/22,05 кГц; общий объём 47,9 МБ, из них ~42 МБ — 176 SAPI voice WAV. Следующий шаг — VO в OGG/Opus и замена SAPI.

15. **UI hover/navigation — закрыто в P2.**  
    Меню озвучивает mouse_entered/focus_entered через `ui_hover`; остаётся оценить громкость на слух.

16. **Ritual sound — закрыто в P2.**  
    `SanctuaryController.begin_offering()` использует `world_ritual_offering`, а не `combat_hit_flesh`.

17. **Finale theme — закрыто в P2.**  
    `finale` получил 3 стема `finale_base/pulse/melody`; appraisal остаётся без отдельной темы.

18. **Нет автоматической проверки loop seam.**  
    Можно добавить анализ первых/последних сэмплов WAV и тест на DC/скачок; слепой слуховой тест — `docs/audio/BLIND_LISTENING_TEST.md`, статус **NOT TESTED**.

---

## 5. Рекомендуемый порядок работ

1. Прочитать/исправить баланс на слух после P1; проверить SAPI-разборчивость в прологе/караване.
2. Сжать оставшиеся 42 МБ SAPI voice в OGG/Opus и заменить SAPI лицензированным VO.
3. Довести музыкальные стемы: фразировка, bar-sync, transition-правила, больше вариаций.
4. Расширить ambience: weather/tide/time-of-day, больше one-shot и playlist.
5. Полировать окклюзию: multi-ray/материалы/динамика; reverb-переходы по краям зон.
6. Связать `audio_zones.tres` с AABB визуальных зон и добавить проверку.
7. Сделать runtime-метр настоящим LUFS (K-weighting) и автоматический gate/peak-check.
8. Cue-данные — **сделано** в P2 (`audio_cue_library.tres`).
9. Pause-политика и accessibility — **сделано** в P2; остаётся ручная проверка.
10. Провести слепой слуховой тест на реальных сценах — **NOT TESTED**, протокол готов.

---

## 6. Вердикт

Аудиосистема пригодна как **технический каркас и набор временных заглушек**, но не как финальный саунд-дизайн. P0/P1/P2 закрыты по коду и targeted-тестам: playback/occlusion, 3-слойная музыка, randomizer, OGG/mono-сжатие, data-driven зоны, 18 reverb-профилей, master limiter/compressor/LUFS tool, typed cue table, pause-политика и accessibility. Полный GUT **NOT PASSED** из-за внешних `park_street_art.tscn`/`sunny`; аудио-набор 73/73. Главные улучшения — слуховой баланс, замена SAPI/83 реплик, более живые стемы, настоящий LUFS-метр, полировка окклюзии и человеческий слепой тест.
