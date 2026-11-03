# RFC: AI-first Cutscene Framework для ShadowSlave

**Дата:** 2026-11-03  
**Статус:** реализовано в Stage 5. `CutsceneDirector` — autoload; M1 использует P05/P09/B01-катсцены. Живой ручной проход — NOT TESTED.  
**Движок:** Godot 4.7.2 stable, Forward+, GDScript.  
**Область:** кат-сцены (cutscenes), кинематографическая камера, блокировка ввода, пропуск, интеграция с диалогами/анимацией/звуком, инструменты для AI-агента.  
**Связанные документы:** `docs/design/13_systems_architecture_audit.md`, `docs/design/level_transitions.md`, `docs/design/first_nightmare_beat_sheet_v2.md`, `docs/story/first_nightmare_canonical_timeline.md`, `docs/AI_HANDOFF_AFTER_S3_2.md`, `docs/DECISIONS.md`.

---

## 0. Краткое решение (TL;DR)

1. **Строим собственный `CutsceneDirector`**, а не берём готовый секвенсор. Он один владеет жизненным циклом кат-сцены, блокировкой ввода/камеры/UI, пропуском, восстановлением состояния и историей просмотров.
2. **Модель исполнения — гибрид:**
   - **`CutsceneDefinition`** (типизированный `.tres`) — контракт и метаданные: id, сцена, скрипт, политика пропуска, лимит времени, условия входа, эффекты завершения, сводка для пропуска.
   - **`CutsceneScript`** (GDScript, `await`) — постановка: камера, актёры, реплики, звук, тайминги. Скрипт пишется агентом как обычный GDScript, но использует только фасад `CutsceneContext`.
   - **Не делаем** собственный текстовый DSL и **не делаем** цепочку из десятков Resource-шагов в MVP. Это дороже в поддержке и хуже отлаживается, а главный автор — AI, который умеет писать типизированный GDScript.
3. **Одна выделенная кинематографическая камера** (`CutsceneCamera3D`) плавно переходит между существующими `Shots/*`, копируя transform/FOV/DOF. Это заменяет `make_current()`-склейки и ручное сохранение yaw/pitch в оболочках кампании.
4. **Пропуск — не «перемотка таймеров», а отмена выполнения + восстановление состояния + применение объявленных эффектов завершения.** Это единственный способ не разъехаться с сюжетными флагами.
5. **Phantom Camera сейчас не внедряем.** Это не секвенсор, а поведение камеры; для 90% наших задач достаточно одной камеры и Tween. Оставляем адаптер на будущее, если понадобятся follow/framing двух актёров, path-dolly, handheld-noise и приоритеты камер.
6. **Инструменты для AI:** линтер кат-сцен, дамп каталога сцены (актёры/клипы/ракурсы/маркеры/диалоги/звук), headless-прогон, захват кадров по ракурсам, генератор шаблона. MCP `godot-mcp-server@0.6.1` уже даёт всё необходимое для сцен/скриптов/запуска/скриншотов; отдельный MCP-сервер не нужен.
7. **Совместимость:** `SliceDirector` и `SliceLocation.play_cutscene()` не ломаем. Новый фреймворк вводится параллельно, первый пилот — некритичная сцена, миграция сюжетных кат-сцен — поэтапно, с регрессионными GUT-тестами.

---

## 1. Цели и не-цели

### 1.1. Цели

- Дать AI-агенту **предсказуемый, проверяемый и повторяемый** способ создавать кат-сцены без ручной работы в редакторе.
- Сделать кат-сцену **диффом в Git**: скрипт + манифест + (опционально) сцена-студия.
- Обеспечить **безопасный пропуск**: игрок не теряет сюжетные флаги, предметы, чекпоинты и не остаётся с заблокированным управлением.
- Убрать размазанную логику камеры/ввода из оболочек кампании (`caravan_site_arrival.gd`, `pilgrim_path_arrival.gd` и др.).
- Дать **headless-валидацию** до запуска игры и **визуальную проверку** после.
- Сохранить канон: кат-сцена без ввода — не длиннее 45–60 секунд; ключевые интерактивные действия не пропускаются; пропуск — после первого просмотра.

### 1.2. Не-цели MVP

- Редактор таймлайна с драг-н-дропом.
- Лицевая анимация, motion capture, сложный root motion.
- Ветвящиеся диалоги с выборами и последствиями (для этого есть `DialogueSequence`; расширение — отдельная задача).
- Локализация и озвучка всех новых реплик.
- Полный перенос пролога B01–B16 на новый фреймворк в первой итерации.
- Замена `NightmareRunState`, `QuestSystem`, `CampaignGuide`, `BeatDirector`.

---

## 2. Аудит текущего проекта

### 2.1. Факты проекта

| Параметр | Значение |
|---|---|
| Движок | Godot 4.7.2 stable, Forward+ |
| Разрешение | 1600×900, stretch `canvas_items`, aspect `expand` |
| GDScript-файлов | ~930 `.gd` (включая addons) |
| GUT-тестов | 83 файла в `tests/`, GUT 9.7.1 |
| Главная сцена | `scenes/ui/main_menu/main_menu.tscn` |
| Вход кампании | `scenes/campaign/campaign_entry.tscn` |
| Autoloads | `MCPRuntime`, `NightmareRunState`, `DialogueManager`, `MapSystem`, `PlayerMenuSystem`, `PauseMenuSystem`, `CampaignGuide`, `QuestSystem`, `SaveSystem`, `AudioDirector` |
| MCP | `godot-mcp-server@0.6.1`, editor connected, runtime helper connected (проверено в этой сессии) |

### 2.2. Как сейчас устроены кат-сцены

Отдельной системы кат-сцен нет. Есть три слоя:

1. **`SliceDirector`** (`scripts/slice/slice_director.gd`) — линейный сценарий B01–B16 для пролога. Он ведёт `Beat`, режимы `FREE / LOOK / LOCKED / CHAINED`, загружает локации в `LocationSlot`, вызывает `location.play_cutscene(id, fast)`, проигрывает диалоги, фейды и звук. Это де-факто эталонный «режиссёр», но он жёстко привязан к прологу.
2. **`SliceLocation.play_cutscene(id, fast)`** — постановки внутри локаций: `park_street.gd`, `containment_room.gd`, `station_lobby.gd`, `spell_void.gd`, `mountain_vision.gd` (и `caravan_road.gd` без постановок). Внутри — `await`, `Tween`, `Camera3D.make_current()`, `AnimationPlayer`, UI-оверлеи.
3. **Оболочки кампании** (`caravan_site_arrival.gd`, `pilgrim_path_arrival.gd`, `sanctuary_arrival.gd`, `appraisal.gd`, `finale.gd`) — длинные линейные последовательности с `await`, ручной блокировкой `player.input_enabled`, ручным сохранением/восстановлением камеры, диалогами и флагами. Только в двух оболочках — 73 `await` и 54 обращения к камере/вводу; `caravan_site_arrival.gd` — 662 строки.

**Вывод:** логика постановок уже существует, но она размазана по трём разным механизмам, не имеет общего жизненного цикла, пропуска, валидации и восстановления.

### 2.3. Персонажи и анимация

| Компонент | Что делает | Чего не хватает для кат-сцен |
|---|---|---|
| `SunnyController` | `CharacterBody3D`, ходьба/бег/прыжок, `input_enabled`, `controls_enabled`, `forced_velocity`, `camera_rig` | Нет единого `set_cutscene_mode()`; нет блокировки урона; нет API перемещения по маркеру |
| `SunnyAnimator` | Выбор клипа по состоянию, прямой `AnimationPlayer`, опциональный `AnimationTree`, флаг `cinematic` | Нет root motion; нет слоёв верх/низ; `cinematic` уже есть и протестирован |
| `CinematicActor` | Логические действия (`sit`, `stand_up`, `throw`) → клипы через `ActionClipMap`; `begin/end/play` | Только анимация; нет движения, поворота, видимости, снапшота, восстановления |
| `Mannequin` | NPC-позы, `get_animation_player()` | Нет общего интерфейса с `CinematicActor`; нет `cinematic` |
| `AnimationTree` | Ресурсы `sunny_animation_tree.tres`, `sunny_v3_animation_tree.tres` | В сценах `AnimationTree` не стоит; анимация идёт напрямую через `AnimationPlayer` |

**Вывод:** фундамент для постановочной анимации есть (`CinematicActor` + `cinematic` + `ActionClipMap`), но его нужно расширить до полноценного актёра сцены и сделать единый интерфейс для Санни и NPC.

### 2.4. Камера

- `ThirdPersonCamera` (`scripts/player/third_person_camera.gd`): yaw на узле, pitch на `SpringArm3D`, `look_enabled`, `input_enabled`, захват мыши.
- Ракурсы — статические `Camera3D` под `Shots/*` с дочерним `LookAt` (или `Shots/<Camera>Target`). В `labyrinth_first_fragment.tscn` — 18 камер; в остальных локациях — обычно 2–3, до 5.
- `SliceLocation.use_shot()` делает `camera.make_current()` — **жёсткая склейка**, без бленда.
- `SliceLocation._ready()` и `GreyboxLocation._aim_shots()` наводят камеры на `LookAt`.
- `resources/cameras/p4_cutscene_dof.tres` назначается всем `Shots/*`; у игровой камеры атрибутов нет, чтобы DOF не протекал в геймплей.
- В оболочках кампании камера сохраняется вручную: `_saved_camera_yaw`, `_saved_camera_pitch`, `_saved_camera_look`, затем `make_current()` игровой камеры.
- `mountain_vision._orbit()` **анимирует саму `Shots/Orbit`**, а не отдельную камеру. Это важно для миграции: новая система должна либо уметь следовать за анимированным shot-узлом, либо переписать орбиту через `ctx.camera.orbit()`.

**Вывод:** нет единого камера-директора, нет плавных переходов, нет валидации ракурсов, нет восстановления после отмены.

### 2.5. Диалоги

- `DialogueSequence` (`.tres`) → `DialogueLine` (speaker, text, duration, voice_id).
- `DialogueRunner` показывает через `SubtitleUI`, ждёт `advance` или таймер, проигрывает voice через `AudioDirector`.
- `fast_mode` пропускает таймеры, но **не** пропускает реплики, ждущие ввода.
- Нет `cancel()`, нет `skip_line()`, нет `auto_advance` для headless-тестов.
- Имена говорящих захардкожены в `DialogueRunner.speaker_names`; новый NPC требует правки кода.

**Вывод:** диалоги пригодны для кат-сцен, но их нужно научить отменяться и автоматически пролистываться в тестовом режиме.

### 2.6. Ввод, UI, пауза

- Блокировка ввода размазана: `player.input_enabled`, `player.controls_enabled`, `camera_rig.look_enabled`, `camera_rig.input_enabled`, `interactor.enabled`, `forced_velocity`, `set_physics_process()`.
- `PauseMenuSystem` открывается по `Esc`/`ui_cancel`, ставит `tree.paused`, проверяет модальные окна через группы. **Про кат-сцены не знает.**
- `PlayerMenuSystem`, `MapSystem`, инвентарь и `SoulSeaController` — каждый сам сохраняет/восстанавливает `paused` и `mouse_mode`.
- `docs/design/13_systems_architecture_audit.md` уже рекомендует единый стек `GameModes` (`push/pop`, `input_context`, `pause_policy`, `time_scale`). Он **не реализован**.
- `GameplayHud` — `CanvasLayer`; группы `gameplay_hud` нет, но скрыть можно по классу/корню.

**Вывод:** для MVP не нужно строить весь `GameModes`, но нужен **один владелец блокировки на время кат-сцены** и защита меню от открытия. Это должен быть `CutsceneDirector`.

### 2.7. Звук

- `AudioDirector` — фасад: `play_music`, `play_ambience`, `play_sfx`, `play_ui`, `play_voice`, `set_reverb_profile`, `duck_music`.
- `MusicDirector` и `AmbienceDirector` хранят `_current_id`, но **не отдают его наружу**. Для восстановления после кат-сцены нужны геттеры.
- Voice ducking уже работает; `DialogueRunner` сам запускает/останавливает voice.

**Вывод:** звук пригоден; нужны геттеры текущих id и тонкая обёртка `CutsceneAudio` для снапшота/восстановления.

### 2.8. Триггеры и переходы

- `TriggerZone` (`Area3D`) — одноразовый: при срабатывании `enabled = false`.
- `Interactable` (`Node3D`) — радиус, `enabled`, звук, сигнал `interacted`.
- `LevelPortal` (`Area3D`) — fade/spawn/one-shot/required_flags; `Style.CUTSCENE` вызывает `play_cutscene()` у родителя.
- `FadeLayer` — затемнение, не знает причину.

**Вывод:** триггеры есть, но нет `CutsceneTrigger`/`CutsceneInteractable`, которые запускают кат-сцену с условиями и одноразовостью.

### 2.9. Тесты и инструменты

| Что | Состояние |
|---|---|
| GUT | 9.7.1, 85 файлов; запускается headless |
| MCP Godot | 0.6.1, editor + runtime helper connected; `run_scene`, `take_screenshot`, `send_input`, `call_method`, `query_runtime_node` работают |
| MCP Blender | не относится к кат-сценам |
| Linter кат-сцен | отсутствует |
| Захват кадров по ракурсам | отсутствует (есть `location_capture.gd` для общих кадров) |
| Генератор кат-сцен | отсутствует |
| GUT через MCP | инструмента нет; нужен shell |

**Проверено в этой сессии:**
- `test_slice_director.gd` + `test_sunny_waking.gd`: **21/21 passed, 93 asserts, 11.359 s**.
- `test_dialogue.gd`: **5/5 passed, 110 asserts, exit 0**.
- `test_dialogue.gd` + `test_level_transition.gd`: **27/27 passed, 193 asserts**, но процесс завершился с кодом 1 из-за ожидаемого предупреждения `LevelPortal: spawn 'MissingSpawn' not found`; это не падение тестов, но зелёным по exit code я это не считаю.
- `run_scene(prologue.tscn)` + `take_screenshot`: успешно, 1600×900; runtime helper подключён; `get_errors` вернул 20 **warning** (shadowed variables, integer division и т.п.), ошибок кат-сцен нет. Скриншот — `addons/godot_mcp/cache/screenshots/cutscene_audit_prologue.png` (не durable).
- Полный GUT в этой сессии **не запускался**; последний зафиксированный в документации результат — 656/656, но он здесь не перепроверен.

### 2.10. Канон и ограничения

- `first_nightmare_beat_sheet_v2.md`: кат-сцена без ввода — **≤ 60 с**, длиннее — делить действием игрока.
- `first_nightmare_restoration_spec.md`: пропуск — **после первого просмотра**, если смысл остаётся в журнале/субтитрах; ключевые интерактивные действия (звонок, ключ, алтарь) **не пропускаются**; первый показ ключевых смертей и оценки **не пропускается**.
- В beat sheet около 10 событий формата «К» и несколько «С» с постановочными вставками; MVP должен закрывать 10–15 кат-сцен, а не сотни.

### 2.11. Критические пробелы

| # | Пробел | Последствие | Приоритет |
|---|---|---|---|
| G1 | Нет жизненного цикла кат-сцены (start/prepare/play/skip/finish/abort) | Каждая сцена сама решает, когда блокировать ввод и что делать при ошибке | CRIT |
| G2 | Нет плавных переходов камеры | Склейки `make_current()`, ручное восстановление yaw/pitch, риск «камера осталась чужая» | CRIT |
| G3 | Нет единого владельца блокировки ввода/UI | Меню/карта/инвентарь могут открыться посреди сцены; утечка `input_enabled` | CRIT |
| G4 | Нет отмены диалогов/твинов | Пропуск невозможен без «дожатия» сцены | CRIT |
| G5 | Нет политики пропуска и истории просмотров | Нельзя выполнить канон «после первого просмотра» | CRIT |
| G6 | Нет состояния, эквивалентного натуральному завершению, при пропуске | Скип ломает флаги/предметы/чекпоинты | CRIT |
| G7 | Нет `CutsceneTrigger`/`CutsceneInteractable` | Приходится вручную включать `Interactable` и ловить сигналы в оболочках | HIGH |
| G8 | Нет линтера и каталога ассетов | AI не видит, какие клипы/ракурсы/диалоги существуют, и узнаёт об ошибке в рантайме | CRIT |
| G9 | Нет захвата кадров по ракурсам | Нельзя автономно проверить композицию | HIGH |
| G10 | Нет `HealthComponent.invulnerable`/паузы врагов | В кат-сцене игрока могут убить | MED |
| G11 | `DialogueRunner` не умеет `cancel`/`auto_advance` | Headless-тесты ждут ввода; пропуск не останавливает реплики | HIGH |
| G12 | Нет геттеров текущей музыки/эмбиента | Нельзя восстановить звук после сцены | MED |
| G13 | `DECISIONS.md` повреждён двойной кодировкой | Нельзя аккуратно дописать решение без предварительной починки | LOW (docs) |

---

## 3. Выбор подхода

### 3.1. Сравнение вариантов

| Критерий | Цепочка Resource-шагов | Собственный текстовый DSL | GDScript-корутины + фасад | Готовый аддон (PCam/Dialogic) |
|---|---|---|---|---|
| Генерация AI | Средняя: многословные `.tres`, легко ошибиться в ссылках | Высокая: простой текст | Высокая: типизированный GDScript, знакомый модели | Средняя: зависит от API аддона |
| Статическая проверка | Загрузка ресурсов + схема | Свой парсер + схема | Парсер GDScript + линтер | Только средствами аддона |
| Выразительность (ветвления, циклы, параллель) | Низкая/средняя | Средняя, но нужен интерпретатор | Высокая | Средняя |
| Отладка | Средняя: нет стека сценария | Плохая: свой интерпретатор | Высокая: стек GDScript, breakpoints | Средняя |
| Diff/merge | Высокий | Высокий | Средний | Средний |
| Порог входа для AI | Средний | Низкий | Низкий | Средний |
| Стоимость поддержки | Средняя (много типов шагов) | Высокая (парсер, команды, версии) | Низкая (язык проекта) | Средняя/высокая (чужой API) |
| Риск «спагетти» | Низкий | Низкий | Средний → снимается фасадом и линтером | Средний |
| Совместимость с проектом | Средняя | Низкая | Высокая: уже есть `SliceDirector` | Низкая/средняя |

### 3.2. Решение

**Гибрид «манифест + GDScript-корутина»**.

- **Манифест `CutsceneDefinition`** — типизированный `.tres`. Он не описывает каждый шаг, а фиксирует контракт: id, глава, скрипт, политика пропуска, лимит, условия входа, эффекты завершения, сводка пропуска, флаги. Это то, что линтер и продюсеры читают без исполнения.
- **Скрипт `CutsceneScript`** — `run(ctx)` с `await`. Он описывает постановку, но только через `CutsceneContext`. Прямые `Input`, `get_tree().paused`, `make_current`, `queue_free` актёров и `change_scene_to_file` запрещены линтером.
- **Почему не чистые Resource-шаги:** для 10–15 линейных сцен это создаст 30–50 типов шагов и многословные `.tres`, а ветвления/циклы всё равно придётся добавлять кодом. AI будет тратить токены на схему, а не на постановку.
- **Почему не DSL:** свой парсер — это ещё один язык, который надо тестировать, версионировать и объяснять агенту. GDScript уже парсится движком, даёт стек ошибок и типы. DSL оправдан, если авторы — не программисты; у нас автор — AI.
- **Почему не готовый аддон:** Phantom Camera решает только камеру; Dialogic конфликтует с существующими диалогами и озвучкой. Секвенсор всё равно нужен свой.

### 3.3. Оценка Phantom Camera

**Факты (на 2026-11-03):**
- Phantom Camera — MIT, Godot 4.3+, последняя версия **0.11.0.4** (27.10.2026).
- 0.11.0.3 исправляет проблему с `PhantomCameraManager` на Godot 4.7.1; пользователи подтверждают работу на 4.7.2.
- Это аддон поведения камеры (follow, look-at, framing, tween, priority, noise), а **не** секвенсор кат-сцен.

**Вердикт:** **не внедрять в MVP.** Причины:
1. Наши ракурсы — статические `Shots/*`, переходы — линейные бленды. Одна `CutsceneCamera3D` + `Tween` покрывает это детерминированно и без нового autoload/плагина.
2. PCam забирает `Camera3D` под управление `PCamHost`; для headless-тестов и AI-диагностики это дополнительный слой скрытого состояния.
3. API молодой (0.11), в отзывах есть шум ошибок; для фундамента игры это лишний риск.
4. Даже с PCam нам всё равно нужны `CutsceneDirector`, skip, state-эквивалентность, линтер и триггеры. PCam не сокращает MVP, а добавляет зависимость.

**Когда пересмотреть:** если появятся:
- follow/framing двух и более актёров в одном кадре;
- path-dolly по `Path3D`;
- handheld/noise-камера с параметрами;
- приоритетный стек камер (геймплей/диалог/кат-сцена/UI);
- split-screen.

**Если внедрять:** только за адаптером `CutsceneCameraBackend`; content-скрипты не импортируют PCam. Версию пинить `0.11.0.4`, добавить в `docs/ASSET_LICENSES.md`, проверить на 4.7.2, не обновлять автоматически.

**Dialogic 2 / готовые диалоговые аддоны:** не рассматриваем. В проекте уже есть `DialogueSequence`/`DialogueRunner`/`SubtitleUI`/voice и русские тексты; аддон создаст второй источник истины и конфликт фокуса/ввода. Если понадобятся ветвления, расширяем `DialogueSequence`, а не меняем систему.

---

## 4. Архитектура

### 4.1. Компоненты

```
CutsceneTrigger (Area3D)     CutsceneInteractable (Interactable)
        │                              │
        └──────────────┬───────────────┘
                       ▼
              CutsceneDirector (autoload)
              ├── CutsceneRegistry          id → CutsceneDefinition
              ├── CutsceneHistory           user://cutscene_history.cfg
              ├── CutsceneRun               текущий запуск
              │   ├── CutsceneDefinition    .tres-манифест
              │   ├── CutsceneStage         Node3D-контейнер: Markers/Shots/Props
              │   ├── CutsceneScript        одноразовый Node с run(ctx)
              │   └── CutsceneContext       фасад для скрипта
              │       ├── CutsceneCamera3D
              │       ├── CutsceneActor(s)
              │       ├── CutsceneUI
              │       └── CutsceneAudio
              └── CutsceneValidator         общий код линтера и рантайма
```

**Ключевое разделение:**
- `CutsceneStage` — **контейнер данных** (маркеры, ракурсы, реквизит, опционально актёры). Он остаётся в сцене уровня.
- `CutsceneScript` — **одноразовый Node**, который создаёт директор и который можно безопасно удалить при пропуске. Скрипт не привязан к сцене через `@onready`; он получает всё через `ctx`.
- `CutsceneRun` — состояние одного запуска: снапшоты, эффекты, таймер, результат, отмена.

### 4.2. Состояния

```
IDLE
  │ start_stage()/start_by_id()
  ▼
PREPARE ── validation error ──► FINISHED(INVALID)  (без блокировки)
  │ snapshot + lock + load
  ▼
PLAYING ── script done ──────► CLEANUP(natural) ──► FINISHED(COMPLETED)
  │
  ├── request_skip() ────────► CLEANUP(skip) ─────► FINISHED(SKIPPED)
  ├── abort()/timeout ───────► CLEANUP(abort) ────► FINISHED(ABORTED)
  └── scene change/exit ─────► CLEANUP(abort) ────► FINISHED(ABORTED)
```

**Инварианты:**
- В `PLAYING` ровно один `CutsceneRun`.
- Ввод/камера/UI блокируются только после успешной валидации.
- `FINISHED` всегда восстанавливает ввод, камеру, HUD и мышь, даже при ошибке.
- Повторный `start_*` во время `PLAYING` возвращает `false` и `BUSY`, ничего не меняет.

### 4.3. Модель данных: `CutsceneDefinition`

```gdscript
class_name CutsceneDefinition
extends Resource

enum SkipPolicy {
    NEVER,              # ключевая сцена, первый показ обязателен
    AFTER_FIRST_VIEW,   # по умолчанию: можно после первого просмотра
    ALWAYS,             # можно всегда (короткие служебные сцены)
    DEBUG_ONLY,         # только в debug/тестах
}

@export var id: StringName                      # &"prologue/doze"
@export var display_name := ""
@export_multiline var description := ""
@export var chapter: StringName = &""
@export var speaker_names: Dictionary[StringName, String] = {}  # доп. имена для субтитров
@export var cutscene_script: Script             # extends CutsceneScript
@export var stage_scene: PackedScene            # optional; иначе stage ищется в сцене
@export var skip_policy := SkipPolicy.AFTER_FIRST_VIEW
@export var key_scene := false                 # ключевая сцена: summary обязательна, первый показ не пропускается
@export var max_duration := 60.0
@export var min_skip_time := 0.5
@export var required_flags: Array[StringName] = []
@export var blocked_by_flags: Array[StringName] = []
@export var completion_flags: Array[StringName] = []
@export var completion_clear_flags: Array[StringName] = []
@export var completion_items: Dictionary[StringName, int] = {}  # минимальное итоговое количество
@export var completion_remove_items: Dictionary[StringName, int] = {}
@export var completion_checkpoint: StringName = &""
@export var completion_checkpoint_position := Vector3.ZERO
@export var completion_checkpoint_has_position := false
@export var completion_beat: StringName = &""
@export var completion_journal: Array[StringName] = []
@export var completion_bestiary: Array[StringName] = []
@export var skip_summary: Array[String] = []
@export var cosmetic_flags: Array[StringName] = []
@export var restore_audio := false
@export var hide_hud := true
@export var letterbox := true
@export var once := true
@export var once_flag: StringName = &""        # пусто → &"cutscene/<id>/done"
@export var moves_player := false
@export var skip_end_player_marker: StringName = &""
@export var realign_camera_on_finish := true
@export var skip_end_markers: Dictionary[StringName, StringName] = {}
@export var skip_end_hidden: Array[StringName] = []
@export var tags: Array[StringName] = []
```

**Правила:**
- `completion_flags` — **все** сюжетные флаги, которые сцена выставляет; `completion_clear_flags` — флаги, которые снимаются. Линтер сверяет с `ctx.flag(...)`/`ctx.clear_flag(...)` в скрипте; косметические — в `cosmetic_flags`.
- `speaker_names` дополняет/переопределяет имена в `DialogueRunner`; если спикер не найден ни там, ни в базовом словаре — warning.
- `completion_items` — **минимальное итоговое количество**, не прибавка. Директор делает `set_item(id, max(current, value))`, поэтому пропуск идемпотентен и не отбирает уже имеющиеся предметы.
- `completion_remove_items` — сколько снять при завершении/пропуске; не пересекается с `completion_items`.
- `completion_checkpoint` — id чекпоинта; `completion_checkpoint_position` + `completion_checkpoint_has_position` — позиция, если нужна.
- `once` использует флаг `once_flag` в `NightmareRunState` (переживает смену сцен, сбрасывается с новым прохождением). `AFTER_FIRST_VIEW` использует `CutsceneHistory` (переживает прохождения).
- `skip_end_player_marker` обязателен, если `moves_player = true`; иначе после пропуска игрок останется в старой точке, а сценарий рассчитывает на новую.
- `realign_camera_on_finish` (по умолчанию true) выравнивает yaw игровой камеры по `player.visual.rotation.y` после сцены; отключить, если сцена намеренно оставляет камеру в старом направлении.
- `stage_scene` — для самостоятельных сцен-студий; если пусто, директор ищет `CutsceneStage` в текущей сцене по `definition.id`.

**Пример `.tres`:**

```gdscript
[gd_resource type="Resource" script_class="CutsceneDefinition" format=3]

[ext_resource type="Script" path="res://scripts/cutscene/cutscene_definition.gd" id="1_def"]
[ext_resource type="Script" path="res://scripts/cutscene/content/prologue/doze.gd" id="2_script"]

[resource]
script = ExtResource("1_def")
id = &"prologue/doze"
display_name = "Дремота"
chapter = &"prologue"
cutscene_script = ExtResource("2_script")
skip_policy = 1
max_duration = 20.0
required_flags = Array[StringName]([&"coffee_drunk"])
completion_flags = Array[StringName]([&"doze_seen"])
skip_summary = Array[String](["Санни клюёт носом и приходит в себя от шлепка по щеке."])
moves_player = false
```

> Типизированные массивы и словари в `.tres` пишутся именно так; генератор `new_cutscene.gd` должен создавать их через `ResourceSaver`, а не через ручной текст.

### 4.4. `CutsceneStage`

```gdscript
class_name CutsceneStage
extends Node3D

@export var definition: CutsceneDefinition
@export var markers_root: NodePath = ^"Markers"
@export var shots_root: NodePath = ^"Shots"
@export var props_root: NodePath = ^"Props"
## Пропсы, которые нужно снапшотить и восстанавливать при пропуске.
@export var tracked_props: Array[NodePath] = []
@export var auto_hide := false
```

- В `_ready()`: если `auto_hide`, `visible = false`; директор показывает stage на старте и прячет после.
- `get_marker(id) -> Node3D`, `get_shot(id) -> Camera3D`, `get_prop(id) -> Node3D` — поиск по именам, с ошибкой, если нет.
- `CutsceneStage` **не содержит `run()`**. Скрипт — отдельный Node.

### 4.5. `CutsceneScript`

```gdscript
class_name CutsceneScript
extends Node

## Единственный метод, который реализует автор кат-сцены.
## Контекст живёт ровно один запуск; после run() Node удаляется.
func run(_ctx: CutsceneContext) -> void:
    push_error("CutsceneScript.run() not implemented in %s" % get_path())
```

**Контракт:**
- `run()` — корутина; можно `await`.
- Не хранить ссылки на `ctx` после возврата.
- Не использовать `@onready` на узлы сцены: всё через `ctx.stage`/`ctx.find`/`ctx.actor`.
- Не вызывать `get_tree().paused`, `Input`, `change_scene_to_file`, `queue_free` актёров, `Camera3D.make_current`.
- Не менять сюжетные флаги напрямую; только `ctx.flag`, `ctx.item`, `ctx.checkpoint`, `ctx.journal`, `ctx.bestiary`.

### 4.6. `CutsceneActor`

Расширяем существующий `CinematicActor`, а не плодим второй класс. Сохраняем `begin/end/play/has_action`, добавляем:

```gdscript
class_name CutsceneActor
extends CinematicActor

@export var actor_id: StringName
@export var body: Node3D                  # CharacterBody3D или Node3D NPC
@export var visual: Node3D                # модель/поворот
@export var movement_root: Node3D         # обычно body
@export var look_root: Node3D             # обычно visual
@export var animation_tree: AnimationTree # optional
@export var tracked := true
@export var freeze_body := true           # CharacterBody3D: physics off on begin
```

Методы:
```gdscript
func play(action: StringName, blend := 0.2, speed := 1.0) -> float
func stop(fade := 0.2) -> void
func move_to(marker: Node3D, duration: float, ease := Tween.EASE_IN_OUT) -> void
func walk_to(marker: Node3D, speed := 1.4) -> void
func face(target: Node3D, duration := 0.3) -> void
func look_at(target: Node3D, duration := 0.3) -> void
func show() -> void
func hide() -> void
func snapshot() -> Dictionary
func restore(snapshot: Dictionary) -> void
func finish(keep_pose := true) -> void
```

**Поведение:**
- `begin()`: `animator.cinematic = true` (если свойство есть), `animation_tree.active = false`, стоп locomotion, `tracked` snapshot.
- `play()`: ищет действие в `ActionClipMap`, затем в `AnimationPlayer`; если клипа нет — `push_error` и `0.0` (линтер должен поймать заранее). В тестах `fast_mode` может сразу `seek(length)`. В базовый `CinematicActor.play()` добавляется опциональный `speed`; вызовы с двумя аргументами остаются совместимыми.
- `move_to()`: `Tween` по `movement_root.global_position`; физика игрока на время сцены выключена. `walk_to()` дополнительно играет `walk`.
- `face()`: кратчайшая дуга по `visual.rotation.y`.
- `finish()`: `animator.cinematic = false`; для Санни это возвращает idle; для NPC последний кадр сохраняется. `restore()` используется при пропуске.

### 4.7. `CutsceneContext`

Фасад — единственная точка контакта скрипта с движком. Все методы, которые ждут, помечены `await`.

```gdscript
class_name CutsceneContext
extends RefCounted

var director: CutsceneDirector
var run: CutsceneRun
var stage: CutsceneStage
var scene: Node
var player: SunnyController
var camera: CutsceneCamera3D
var ui: CutsceneUI
var audio: CutsceneAudio
var fast := false
var cancelled := false

# Время и кадры
func wait(seconds: float) -> void
func next_frame() -> void
func wait_until(condition: Callable, timeout := 10.0) -> bool

# Актёры и сцена
func actor(id: StringName) -> CutsceneActor
func marker(id: StringName) -> Node3D
func shot(id: StringName) -> Camera3D
func prop(id: StringName) -> Node3D
func find(path: NodePath) -> Node

# Диалоги
func dialogue(id: StringName) -> void
func dialogue_resource(sequence: DialogueSequence) -> void
func say(text: String, speaker: StringName, duration := 0.0) -> void

# Состояние
func flag(name: StringName, value := true) -> void
func clear_flag(name: StringName) -> void
func item(id: StringName, count := 1) -> void
func remove_item(id: StringName, count := 1) -> void
func checkpoint(id: StringName, position := Vector3.ZERO, has_position := false) -> void
func journal(id: StringName) -> void
func bestiary(event_id: StringName) -> void
func event(name: StringName) -> void
func await_event(name: StringName, timeout := 10.0) -> bool

# Служебное
func create_tween() -> Tween
func commit() -> void
func fail(reason: String) -> void
```

**Правила:**
- `ctx.wait()` использует **паузируемый** таймер: `get_tree().create_timer(seconds, false)`. Иначе пауза меню не остановит кат-сцену.
- `ctx.fast` = `CutsceneDirector.fast_mode`; в тестах `wait`/твины/реплики пролистываются.
- `ctx.cancelled` проверяется в начале каждого метода; после отмены методы ничего не делают.
- `ctx.dialogue()` ищет `resources/dialogue/<chapter>/<id>.tres`; `id` может быть полным (`prologue/sip_1`).
- `ctx.say()` создаёт одноразовую `DialogueSequence`/`DialogueLine`; удобно для коротких реплик без отдельного `.tres`.
- `ctx.flag/item/checkpoint/journal/bestiary` журналируются в `CutsceneRun`; при пропуске директор применяет `completion_*` из манифеста, а не «недоигранные» вызовы. `ctx.item` задаёт минимальное итоговое количество, не прибавку.
- `ctx.actor(id)` при первом обращении вызывает `begin()` (идемпотентно) и `snapshot()`; скрипту не нужно вручную включать cinematic-режим.
- `ctx.prop()` и `ctx.actor()` снапшотят объект при первом обращении; изменяемые пропсы должны быть в `tracked_props`, иначе пропуск не восстановит их. `ctx.find()` — только для чтения/запроса, не для мутаций.
- `ctx.commit()` применяет `completion_*` досрочно (например, в середине сцены, если дальше идёт UI). Обычно не нужен: директор применяет эффекты в `CLEANUP`.
- `ctx.fail()` немедленно abort-ит сцену; используется для критичных отсутствующих ссылок.

### 4.8. `CutsceneCamera3D`

Одна камера на запуск, создаётся директором и добавляется в текущую 3D-сцену (например, в `CutsceneWorld` под корнем сцены), **не** в `CanvasLayer`.

```gdscript
class_name CutsceneCamera3D
extends Camera3D

func shot(id: StringName, blend := 0.6, ease := Tween.EASE_IN_OUT) -> void
func hard_cut(id: StringName) -> void
func player(blend := 0.6) -> void
func blend_to_transform(xform: Transform3D, fov: float, blend: float, ease) -> void
func follow(node: Node3D, offset := Vector3.ZERO, damping := 0.15) -> void
func look_at_node(node: Node3D, blend := 0.3) -> void
func orbit(center: Vector3, radius: float, height: float, degrees: float, duration: float) -> void
func shake(trauma: float, duration: float) -> void
func set_dof(attributes: CameraAttributes, blend := 0.3) -> void
func restore_player(blend := 0.6) -> void
```

**Реализация:**
- `shot(id)` ищет `stage/Shots/<id>`, затем `scene/Shots/<id>`. Копирует:
  `global_transform`, `fov`, `near`, `far`, `projection`, `size`, `keep_aspect`, `cull_mask`, `environment`, `attributes`.
- Бленд: `position.lerp` + `Quaternion.slerp` + `fov` lerp. Не использовать `look_at` во время бленда — будет рывок.
- `hard_cut` = `blend 0.0`.
- `follow` — опционально; включается только для динамических сцен. `_process` обновляет позицию с демпфированием.
- `orbit` — `Tween`-метод вокруг центра; для `mountain_vision` вместо анимации shot-узла.
- `shake` — аддитивные `h_offset`/`v_offset` с затуханием; масштаб из `GameSettings` (поле `cutscene_shake_scale`, добавить).
- `set_dof` — плавно меняет `attributes`; по умолчанию `p4_cutscene_dof.tres`.
- `restore_player` — бленд к текущему transform игровой камеры, затем `player_camera.make_current()` и `queue_free()` cutscene-камеры.
- **Никогда** не менять `attributes` игровой камеры; DOF не должен протекать в геймплей.

**Почему не `make_current()` между shot-камерами:** две `Camera3D` не дают кроссфейд; `make_current()` — это склейка. Одна камера с блендом даёт плавность и предсказуемый restore.

### 4.9. `CutsceneUI`

`CanvasLayer` (layer 100, ниже pause 120), создаётся директором один раз.

Состав:
- `SubtitleUI` (переиспользуем `scripts/ui/subtitle_ui.gd`);
- `FadeLayer` (переиспользуем `scripts/ui/fade_layer.gd`);
- `Letterbox` — верх/низ `ColorRect`, 2.39:1;
- `SkipPrompt` — «Удерживайте [Backspace] — пропустить» + прогресс;
- `TitleCard` — заголовок/подзаголовок;
- `Hint` — короткая подсказка;
- `Flash` — цветная вспышка.

API:
```gdscript
func fade_to(alpha: float, duration: float) -> void
func fade_clear(duration := 0.0) -> void
func letterbox(on: bool, duration := 0.3) -> void
func show_skip_prompt(on: bool) -> void
func set_skip_progress(value: float) -> void
func hint(text: String, duration := 0.0) -> void
func title(text: String, subtitle := "", duration := 2.0) -> void
func flash(color: Color, duration := 0.3) -> void
func set_hud_visible(on: bool) -> void
func drowsiness(value: float, duration := 0.0) -> void   # адаптер к PrologueUI/DrowsinessOverlay
func snapshot() -> Dictionary
func restore(snapshot: Dictionary) -> void
```

- `set_hud_visible(false)` ищет `GameplayHud` по классу/группе `gameplay_hud`; при отсутствии — no-op.
- `drowsiness` — только если в сцене есть `DrowsinessOverlay`; иначе no-op. Это адаптер для пролога, не общая зависимость.
- В Phase 1 пауза во время кат-сцены **блокируется**; `SkipPrompt` — единственный UI. В Phase 2 добавляем pause-with-skip.

### 4.10. `CutsceneAudio`

```gdscript
class_name CutsceneAudio
extends RefCounted

func music(id: StringName, fade := 1.0) -> void
func ambience(id: StringName, fade := 1.0) -> void
func reverb(profile: StringName) -> void
func sfx(id: StringName, at: Node3D = null, volume_db := 0.0) -> void
func duck(amount_db: float, duration: float) -> void
func stop_music(fade := 1.0) -> void
func stop_ambience(fade := 1.0) -> void
func snapshot() -> Dictionary
func restore(snapshot: Dictionary) -> void
```

- `snapshot` сохраняет `AudioDirector.get_music_id()`, `get_ambience_id()`, `get_reverb_profile()`.
- Для этого добавить геттеры в `MusicDirector`/`AmbienceDirector` и фасад `AudioDirector`.
- `restore` вызывается только если `definition.restore_audio == true`; иначе звук остаётся как после сцены (часто это желаемое поведение).

### 4.11. `CutsceneDirector` (autoload)

```gdscript
extends Node

signal cutscene_started(definition: CutsceneDefinition)
signal cutscene_finished(definition: CutsceneDefinition, result: int)
signal cutscene_skipped(definition: CutsceneDefinition, elapsed: float)
signal cutscene_aborted(definition: CutsceneDefinition, reason: String)
signal shot_changed(shot_id: StringName)
signal skip_availability_changed(available: bool)
signal state_changed(state: int)

enum State { IDLE, PREPARE, PLAYING, CLEANUP, FINISHED }
enum Result { COMPLETED, SKIPPED, ABORTED, BUSY, INVALID, ALREADY_COMPLETED, BLOCKED }

var fast_mode := false
var debug_force_skip := false

# Запуск
func start_stage(stage: CutsceneStage, options := {}) -> bool
func start_by_id(id: StringName, options := {}) -> bool
func start_definition(definition: CutsceneDefinition, parent: Node = null, options := {}) -> bool
func play_stage(stage: CutsceneStage, options := {}) -> int       # корутина
func play_by_id(id: StringName, options := {}) -> int             # корутина
func request_skip(force := false) -> bool
func abort(reason := "") -> void

# Состояние
func is_playing() -> bool
func is_locked() -> bool
func get_state() -> State
func get_current() -> CutsceneDefinition
func get_current_run() -> CutsceneRun
func get_last_result() -> int
func get_debug_state() -> Dictionary

# События и история
func notify_event(name: StringName) -> void
func mark_seen(id: StringName) -> void
func has_seen(id: StringName) -> bool
func clear_history() -> void

# Реестр и тесты
func register(definition: CutsceneDefinition) -> void
func reload_registry() -> void
func get_definition(id: StringName) -> CutsceneDefinition
func get_all_definitions() -> Array[CutsceneDefinition]
func reset_for_tests() -> void
```

**`start_*` vs `play_*`:**
- `start_*` — не корутина, запускает и сразу возвращает `bool`. Нужен для MCP `call_method`, триггеров, UI.
- `play_*` — корутина, ждёт `FINISHED` и возвращает `Result`. Нужен для сценариев и тестов.
- Оба используют один `CutsceneRun`; повторный запуск во время `PLAYING` → `false`/`BUSY`.
- `BLOCKED` — не выполнены `required_flags`/`blocked_by_flags`; `ALREADY_COMPLETED` — сработал `once_flag`. Оба не блокируют ввод и не меняют состояние.

**`get_debug_state()`:**
```gdscript
{
    "state": "PLAYING",
    "id": &"prologue/doze",
    "elapsed": 3.42,
    "shot": &"DozeShot",
    "skip_available": false,
    "locked": true,
    "result": -1,
    "actors": [&"sunny"],
    "warnings": []
}
```
Это то, что AI читает через `query_runtime_node`/`call_method`.

### 4.12. `CutsceneRun`

> `State`/`Result` вынести в отдельный `cutscene_types.gd` (`class_name CutsceneTypes`), чтобы не было циклической зависимости `CutsceneDirector` ↔ `CutsceneRun`. В примерах ниже `CutsceneDirector.State` — сокращение для `CutsceneTypes.State`.

```gdscript
class_name CutsceneRun
extends RefCounted

signal finished(result: int)

var definition: CutsceneDefinition
var stage: CutsceneStage
var script_node: CutsceneScript
var context: CutsceneContext
var state := CutsceneDirector.State.PREPARE
var result := -1
var elapsed := 0.0
var current_shot: StringName = &""
var cancelled := false
var input_snapshot: Dictionary
var camera_snapshot: Dictionary
var ui_snapshot: Dictionary
var audio_snapshot: Dictionary
var actor_snapshots: Dictionary = {}
var prop_snapshots: Dictionary = {}
var applied_effects := {}
var spawned: Array[Node] = []
```

- Снапшоты делаются лениво: при первом `ctx.actor(id)`/`ctx.prop(id)`.
- `tracked_props` из stage снапшотятся на старте.
- `spawned` — зарезервировано для будущего `ctx.spawn`; в MVP не используется.

### 4.13. `CutsceneTrigger` и `CutsceneInteractable`

```gdscript
class_name CutsceneTrigger
extends Area3D

@export var cutscene_id: StringName
@export var required_flags: Array[StringName] = []
@export var blocked_by_flags: Array[StringName] = []
@export var one_shot := true
@export var one_shot_flag: StringName = &""
@export var trigger_on_ready := false
@export var delay := 0.0
```

- `_ready()`: `monitorable = false`, `collision_layer = 0`, `collision_mask = 2`, `body_entered` → `_try_start`.
- `_try_start()`: проверяет `CutsceneDirector.is_playing()`, флаги, `one_shot`; вызывает `start_by_id`.
- Если `start_by_id` вернул `false` из-за `BUSY`/`BLOCKED`, триггер остаётся доступным (не срабатывает повторно в том же кадре). При `INVALID` — disable, чтобы не спамить лог.
- `one_shot`: ставит `one_shot_flag` (если задан) и `enabled = false`.

```gdscript
class_name CutsceneInteractable
extends Interactable

@export var cutscene_id: StringName

func interact() -> void:
    if CutsceneDirector.start_by_id(cutscene_id):
        super.interact()
```

- `Interactable` уже отключается сценарием; `CutsceneInteractable` не ломает контракт.

**`CutsceneStart`** не нужен: любой скрипт может вызвать `CutsceneDirector.start_by_id()`.

### 4.14. Интеграция с `LevelPortal`

В `LevelPortal` **уже есть** поле `cutscene_id` (используется в `Style.CUTSCENE`). Новое поле не нужно. Меняем только ветку `Style.CUTSCENE`:
1. Если `cutscene_id != &""` и в реестре `CutsceneDirector` есть определение с таким id → `await CutsceneDirector.play_by_id(cutscene_id)`.
2. Иначе — текущее поведение: `parent.play_cutscene(cutscene_id, false)`.
3. Затем fade и `change_scene_to_file`.

Если ветка использует `CutsceneDirector`, портал **не** блокирует ввод повторно (`lock_player` игнорируется на время сцены): блокировкой владеет директор, иначе после сцены можно получить двойное восстановление.

Это позволяет новым локациям использовать `CutsceneStage`, не переписывая `SliceLocation`. Старые порталы работают как раньше.

### 4.15. Сосуществование со `SliceDirector`

- `SliceDirector` остаётся владельцем B01–B16 и режимов `FREE/LOOK/LOCKED/CHAINED` до отдельной миграции.
- Новый `CutsceneDirector` **не запускается** внутри сцен, где активен `SliceDirector`, в Phase 1. Граница: пролог — legacy, кампания/локации — новый фреймворк.
- В Phase 2 добавляем опцию `manage_input=false`/`manage_camera=false` для вложенных сцен, чтобы `SliceLocation.play_cutscene()` мог делегировать в `CutsceneDirector`, не конфликтуя с `Mode`.
- В Phase 3 мигрируем пролог: `SliceDirector._cutscene()` вызывает `CutsceneDirector.play_stage(stage, {"manage_input": false})`, а `Mode` остаётся у `SliceDirector`.

### 4.16. Блокировка ввода/UI: порядок

**Старт:**
1. Валидация манифеста/сцены. Ошибка → `INVALID`, без блокировки. Если открыто модальное окно/пауза (`PauseMenuSystem`, `PlayerMenuSystem`, `MapSystem`, инвентарь) → `BUSY`, без блокировки.
2. Снапшоты: player input/camera/physics/health, mouse mode, HUD, audio.
3. `CutsceneUI` создаётся/показывается; HUD скрывается; letterbox/fade. Другие `DialogueRunner` в сцене переводятся в `PROCESS_MODE_DISABLED` (их субтитры не должны перехватывать ввод), восстанавливаются после. `DialogueManager.set_barks_suppressed(true)`, чтобы барки не перекрывали сцену.
4. Блокировка:
   - `player.set_cutscene_mode(true)` (новый метод): `input_enabled=false`, `combat_enabled=false`, `set_process_unhandled_input(false)`, `camera_rig.input_enabled=false`, `camera_rig.look_enabled=false`, `interactor.enabled=false`, `set_physics_process(false)`, `forced_velocity=Vector3.ZERO`, `health.invulnerable=true`. Метод сохраняет все эти поля и восстанавливает их в `set_cutscene_mode(false)`.
   - `PauseMenuSystem`/`PlayerMenuSystem`/`MapSystem` проверяют `CutsceneDirector.is_playing()` и не открываются.
5. `CutsceneCamera3D` создаётся, `make_current()`.
6. Скрипт запускается.

**Финиш:**
1. Остановить скрипт/анимации/твины; удалить `CutsceneScript`.
2. Восстановить камеру (бленд к игровой), при `realign_camera_on_finish` выставить `camera_rig.set_yaw(player.visual.rotation.y)`, затем `make_current()` игровой.
3. Восстановить HUD/letterbox/fade/audio, `process_mode` других `DialogueRunner` и прежнее состояние `DialogueManager` barks.
4. `player.set_cutscene_mode(false)`; восстановить mouse mode.
5. `FINISHED`, сигналы.

**Почему такой порядок:** если разблокировать ввод до восстановления камеры, игрок на один кадр получит управление «чужой» камерой; если восстановить HUD до камеры, будет виден скачок.

### 4.17. Пропуск: политика и эквивалентность состояния

**Политика:**
- `NEVER` — сцена не пропускается **никогда** (обязательное действие, например «лечь на алтарь»); `can_skip()` всегда false, кроме `debug_force_skip`.
- `AFTER_FIRST_VIEW` — по умолчанию; `can_skip()` true только если `CutsceneHistory.has_seen(id)`. Для ключевых смертей/оценки используйте `key_scene=true` + непустую `skip_summary`: первый показ обязателен, повторный — можно сократить.
- `ALWAYS` — короткие служебные сцены; можно всегда.
- `DEBUG_ONLY` — только `OS.is_debug_build()` или `debug_force_skip`.

**Дополнительные условия:**
- `elapsed >= min_skip_time` (0.5 с) — защита от случайного нажатия.
- `interactive_beat_active == false` — если сцена ждёт обязательного действия игрока, пропуск запрещён.
- `CutsceneDirector.is_playing()` и `script_node != null`.

**Механика:**
1. `request_skip()` проверяет политику; если нельзя — `false`, без побочных эффектов.
2. `run.cancelled = true`, `ctx.cancelled = true`.
3. `script_node.queue_free()`; корутина больше не возобновится. Это ключевой приём: не нужно «дожимать» все `await`.
4. `CutsceneUI` скрывает skip prompt; останавливает shake; скрывает субтитры (`DialogueRunner.cancel()`).
5. `CLEANUP(skip)`:
   - восстановить актёров/пропсы из снапшотов;
   - применить `skip_end_markers` (позиция + поворот маркера), `skip_end_hidden`, `skip_end_player_marker` (для игрока — позиция + поворот маркера, velocity = 0);
   - `player.velocity = Vector3.ZERO` после восстановления, чтобы игрок не «выстрелил» из сцены;
   - применить `completion_flags`, `completion_clear_flags`, `completion_items`, `completion_remove_items`, `completion_checkpoint`, `completion_beat`, `completion_journal`, `completion_bestiary`;
   - восстановить камеру/UI/audio/input;
   - **не** помечать `seen` (пропуск не равен просмотру).
6. `FINISHED(SKIPPED)`.

`once_flag` ставится и при натуральном завершении, и при пропуске: сцена считается пройденной для прогрессии. `seen` — только при натуральном завершении.

**Эквивалентность:**
- Прогрессия (флаги/предметы/чекпоинты/beat) после пропуска **должна совпадать** с натуральным завершением.
- Косметика (позы, позиции второстепенных NPC, состояние декораций) может отличаться; это допустимо.
- Линтер проверяет: каждый литеральный `ctx.flag(&"...")` есть в `completion_flags` или `cosmetic_flags`.
- Тест `skip_state_equivalence` сравнивает `NightmareRunState.snapshot()` после натурального прогона и после пропуска на 25/50/75/100%.

**Сводка пропуска:**
- `skip_summary` показывается как 2–4 субтитра или карточка после пропуска. Если сцена содержит сюжетно важный текст, он должен быть в сводке.
- Для `NEVER` сводка не нужна (пропуска нет), но поле можно заполнить для debug.

**Отмена корутин и твинов (обязательно):**
- Удаление `CutsceneScript` останавливает только его собственные `await`; **не** останавливает `DialogueRunner`, твины UI/камеры/актёров и `AudioDirector`.
- `DialogueRunner.cancel()` должен реально завершать цикл: собственный `Timer` (не `SceneTreeTimer`), флаг `_cancelled`, проверка после каждого `await`, скрытие субтитров, остановка voice.
- `CutsceneUI`, `CutsceneCamera3D` и каждый `CutsceneActor` имеют `cancel_tweens()`/`cancel_motion()`; cleanup вызывает их до восстановления снапшотов.
- `ctx.create_tween()` создаёт Tween на `CutsceneScript`, поэтому все helper-твины умирают вместе со скриптом. Не создавать твины на актёрах/UI напрямую.
- Тест: после skip подождать 1 с и проверить, что актёр не продолжил движение, UI не продолжил fade, камера не продолжила бленд.

**UI пропуска:**
- `cutscene_skip` — новая input-действие: `Backspace` + gamepad `Back`.
- Удержание 0.6 с; для `key_scene` — 1.2 с; прогресс в `SkipPrompt`.
- В Phase 1 пауза заблокирована; в Phase 2 — кнопка «Пропустить» в pause menu.

### 4.18. Ошибки, таймауты, повторный вход

- **Валидация до блокировки:** `CutsceneValidator.validate()` — общий код для рантайма и CLI. Ошибки → `push_error`, `INVALID`, без изменения состояния.
- **Watchdog:** `max_duration + 5 с`. При превышении — `abort("timeout")`, применить `completion_*`, восстановить состояние, `ABORTED`.
- **Ошибка в скрипте:** GDScript не даёт `try/catch`; если корутина умирает, watchdog поймает по времени. `ctx.fail()` — явный abort.
- **Смена сцены:** `CutsceneDirector` подписан на `tree_changing`/`scene_changed`; при смене — abort и cleanup. `LevelPortal` не запускается во время кат-сцены.
- **Повторный вход:** `start_*` → `BUSY`, без побочных эффектов.
- **Пауза:** в Phase 1 `PauseMenuSystem.open_menu()` возвращает false, если `CutsceneDirector.is_playing()`. В Phase 2 — пауза разрешена, `ctx.wait` паузируемый, твины паузируются, skip остаётся доступен.
- **Смерть/урон:** `HealthComponent.invulnerable` (новое поле) + `player.set_cutscene_mode(true)`. Враги: на время сцены `process_mode = DISABLED` для группы `enemy` (опция `pause_enemies=true`), восстановить после.
- **Падение:** `FallRecovery` уже считает сценарий «scripted», если `input_enabled=false`; физика игрока выключена, поэтому падения нет.

### 4.19. Производительность

- Одна камера на запуск, один `Tween` на переход; никаких per-frame `load()`.
- `CutsceneDefinition` и `CutsceneScript` предзагружаются через `ResourceLoader.load_threaded_request` в `PREPARE` (Phase 2); в MVP — `load()` до блокировки.
- `CutsceneUI` создаётся один раз и переиспользуется.
- `CutsceneDirector._process` активен только в `PLAYING`; в `IDLE` — `set_process(false)`.
- `ctx` не аллоцирует в `_process`; follow/shake кэшируют векторы.
- Бюджет: ±0.5 мс на кадр в `PLAYING`, без роста draw calls (камера не добавляет проходов).
- `VisibilityEnabler3D`/окклюдеры остаются ответственностью локации; кат-сцена не должна включать весь уровень.

### 4.20. Безопасность и границы

- Кат-сцены — **только GDScript в репозитории**, не данные от пользователя. Никакого `Expression`/`eval` из JSON.
- Запрещены абсолютные пути, токены, `.env`.
- `.tres`/`.tscn`/`.gd` — UTF-8 **без BOM** (правило из `DECISIONS` 2026-11-02).
- Бинарные ассеты — в Git LFS; текстовые — нет.
- Не добавлять новый MCP-сервер без решения пользователя.

---

## 5. Инструменты для AI

### 5.1. Что уже есть в MCP

`godot-mcp-server@0.6.1`, editor connected, runtime helper connected. Доступные инструменты (релевантные):

| Инструмент | Для чего |
|---|---|
| `create_scene`, `add_node`, `set_node_properties`, `instance_scene` | Создание stage-сцены, маркеров, ракурсов, триггеров |
| `attach_script`, `create_script`, `edit_script`, `validate_script` | Скрипт кат-сцены |
| `read_scene`, `find_nodes`, `get_scene_node_properties`, `get_resource_info` | Инвентаризация сцены и ресурсов |
| `batch_execute` | Несколько правок одной транзакцией |
| `run_scene`, `stop_scene` | Запуск/остановка |
| `take_screenshot` | Кадр из runtime |
| `send_input` | Проверка skip/advance |
| `query_runtime_node`, `call_method` | `CutsceneDirector.start_by_id`, `request_skip`, `get_debug_state` |
| `get_errors`, `get_console_log`, `get_runtime_status` | Диагностика |
| `get_performance_monitors` | FPS/draw calls |
| `rescan_filesystem` | После внешних записей |
| `mcp_undo` | Откат правок MCP |
| `classdb_query` | Проверка API перед кодом |

**Чего нет:**
- нет инструмента запуска GUT → используем shell;
- нет `create_resource` для типизированного `.tres` → генератор/`write_file` + линтер;
- нет захвата серии кадров по ракурсам → project CLI;
- нет видео/контактного листа → project CLI + Pillow.

**Новый MCP-сервер не нужен.** Все пробелы закрываются project CLI и существующими инструментами.

### 5.2. CLI-инструменты, которые нужно создать

| Скрипт | Назначение | Вход/выход |
|---|---|---|
| `tools/cutscene/validate_cutscenes.gd` | Линтер всех кат-сцен | `--id=...` или все; JSON в stdout/файл; exit 1 при ошибках |
| `tools/cutscene/dump_catalog.gd` | Каталог сцены для AI | `--scene=res://... --out=user://catalog.json` |
| `tools/cutscene/run_cutscene.gd` | Headless-прогон одной сцены | `--id=... --fast --skip-at=0.5`; JSON результата |
| `tools/cutscene/capture_cutscene.gd` | Кадры на каждом `shot_changed` | `--id=... --out=user://captures/...`; PNG + `capture.json` |
| `tools/cutscene/new_cutscene.gd` | Генератор шаблона | `--id=... --chapter=... --template=in_place`; создаёт `.gd/.tres/.tscn` |
| `tools/cutscene/list_clips.gd` | Список клипов модели | `--scene=res://...`; JSON |
| `tools/cutscene/run_checks.ps1` | Единая проверка | линтер + GUT + smoke + summary |
| `tools/cutscene/contact_sheet.py` | Контактный лист из PNG | Pillow |

**Пример команд:**
```powershell
godot --headless --path . -s tools/cutscene/validate_cutscenes.gd -- --json=user://cutscene_lint.json
godot --headless --path . -s tools/cutscene/run_cutscene.gd -- --id=prologue/doze --fast
godot --path . -s tools/cutscene/capture_cutscene.gd -- --id=prologue/doze --out=user://cutscene_captures
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_cutscene_framework.gd -gexit
```

### 5.3. Каталог сцены (`dump_catalog.gd`)

AI должен видеть, что доступно, до генерации кода. JSON:
```json
{
  "scene": "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn",
  "actors": [
    {"id": "sunny", "node": "Sunny", "clips": ["Idle", "Walking_A", "Running_A", "..."],
     "clip_map": {"sit_idle": "Sit_Chair_Idle"}, "missing_clips": []}
  ],
  "shots": [
    {"id": "Z01_Arrival", "node": "Shots/Z01_Arrival", "position": [0, 3, 12],
     "fov": 60, "attributes": "res://resources/cameras/p4_cutscene_dof.tres"}
  ],
  "markers": [{"id": "Start", "node": "Spawns/Start", "position": [0, 0, 0]}],
  "interactables": [{"id": "coffee", "node": "Props/Coffee/Interactable", "enabled": true}],
  "triggers": [{"id": "station_entrance", "node": "Triggers/StationEntrance", "enabled": false}],
  "dialogue": [{"id": "prologue/sip_1", "path": "res://resources/dialogue/prologue/sip_1.tres",
                "lines": 3, "speakers": ["sunny"]}],
  "audio": {"music": ["park", "..."], "ambience": ["park", "..."], "sfx": ["world_pickup", "..."]}
}
```

### 5.4. Линтер: правила

**Манифест:**
- `id` не пустой, уникальный, совпадает с путём/папкой.
- `cutscene_script` загружается, инстанцируется и наследует `CutsceneScript` (проверка через временный `Node` + `is CutsceneScript`, затем `free()`).
- `stage_scene` загружается (если задан).
- `max_duration` в (0, 120]; warning > 60.
- `skip_policy` валиден; для `NEVER` требуется обоснование в `description`; для `key_scene` с `AFTER_FIRST_VIEW` требуется непустая `skip_summary`.
- `required_flags` не пересекаются с `completion_flags`.
- `completion_flags` и `completion_clear_flags` не пересекаются.
- `moves_player=true` требует `skip_end_player_marker`.
- `completion_items` — неотрицательные минимальные итоговые количества.
- `completion_remove_items` — неотрицательные количества; не пересекается с `completion_items`.
- `once_flag` уникален.

**Скрипт (regex/текстовый анализ):**
- есть `func run(ctx` (или `func run(_ctx`);
- нет `Input.`, `get_tree().paused`, `change_scene_to_file`, `queue_free(`, `.free(`, `make_current`, `player.input_enabled`, `camera_rig.`, `get_tree().create_timer` (без `false`);
- все `ctx.actor(&"...")` есть в каталоге/stage;
- все `ctx.camera.shot(&"...")` есть;
- все `ctx.dialogue(&"...")` загружаются и непустые;
- все `ctx.prop(&"...")` есть в `tracked_props` или `Props/*`;
- все `ctx.flag(&"...")` есть в `completion_flags`/`cosmetic_flags`;
- все `ctx.clear_flag(&"...")` есть в `completion_clear_flags`/`cosmetic_flags`;
- все `ctx.item(&"...")` есть в `completion_items`;
- все `await` — на `ctx.*` (warning на другие);
- нет `while true` без `ctx.wait`/`ctx.next_frame` (warning);
- нет `randf`/`randi` без `seed` (warning).

**Сцена:**
- есть `CutsceneStage` с `definition`;
- `Shots/*` — `Camera3D` с `LookAt`/`*Target`;
- `Markers/*` — `Node3D`;
- у актёров уникальные `actor_id`;
- `tracked_props` существуют;
- `CutsceneTrigger` ссылается на существующий `cutscene_id`.

**Рантайм:**
- `get_debug_state()` без `warnings`;
- нет orphan nodes после cleanup;
- input/camera restored;
- skip на 5 точках;
- state equivalence.

### 5.5. Headless-тесты

**Unit-тесты фреймворка:**
```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_cutscene_framework.gd -gexit
```

**Все кат-сцены (smoke):**
```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_cutscenes.gd -gexit
```

**Одна сцена:**
```powershell
godot --headless --path . -s tools/cutscene/run_cutscene.gd -- --id=prologue/doze --fast
```

**Захват:**
```powershell
godot --path . -s tools/cutscene/capture_cutscene.gd -- --id=prologue/doze --out=user://cutscene_captures
```

### 5.6. MCP-цикл для агента

1. Прочитать `docs/design/cutscene_authoring_guide.md` и пример.
2. `dump_catalog.gd` для сцены; выбрать актёров/ракурсы/маркеры/диалоги.
3. `new_cutscene.gd` (или `create_scene` + `create_script` + `write_file`) создать stage/скрипт/манифест.
4. `validate_script` + `rescan_filesystem`.
5. `validate_cutscenes.gd` — 0 ошибок.
6. `run_cutscene.gd --fast` — `COMPLETED`.
7. `run_scene` с `wait_for_runtime:true`; `call_method("/root/CutsceneDirector", "start_by_id", ["prologue/doze"])`.
8. `get_debug_state`, `get_errors`, `take_screenshot` на каждом ракурсе.
9. `call_method(..., "request_skip", [true])`; проверить restore и флаги.
10. GUT-тест; `stop_scene`; отчёт с фактическими результатами.

**Пример MCP-вызова (через `execute`):**
```js
await tools.godot.run_scene({ scene_path: "res://scenes/locations/.../scene.tscn", wait_for_runtime: true });
await tools.godot.call_method({ node_path: "/root/CutsceneDirector", method: "start_by_id", args: ["prologue/doze"], runtime: true });
const state = await tools.godot.query_runtime_node({ node_path: "/root/CutsceneDirector" });
await tools.godot.take_screenshot({ save_to: "res://addons/godot_mcp/cache/screenshots/cutscene_doze_01.png" });
await tools.godot.call_method({ node_path: "/root/CutsceneDirector", method: "request_skip", args: [true], runtime: true });
await tools.godot.stop_scene();
```

### 5.7. Какие API движка открыть агенту

**Публичные (для MCP/тестов):**
- `CutsceneDirector.start_by_id(id) -> bool`
- `CutsceneDirector.play_by_id(id) -> int`
- `CutsceneDirector.request_skip(force) -> bool`
- `CutsceneDirector.abort(reason)`
- `CutsceneDirector.is_playing() -> bool`
- `CutsceneDirector.get_debug_state() -> Dictionary`
- `CutsceneDirector.get_last_result() -> int`
- `CutsceneDirector.get_current() -> CutsceneDefinition`
- `CutsceneDirector.notify_event(name)`
- `CutsceneDirector.mark_seen(id)` / `has_seen(id)`
- `CutsceneDirector.reset_for_tests()`

**Для скриптов (только `ctx`):**
- камера, актёры, диалоги, UI, звук, флаги, события — см. §4.7.

**Не открывать агенту напрямую:**
- `player.input_enabled`, `camera_rig.*`, `Camera3D.make_current`, `get_tree().paused`, `change_scene_to_file`, `queue_free` актёров, `AnimationPlayer.play` в обход `ctx.actor`.
- Это не «безопасность от злого ума», а защита от рассинхронизации состояния и утечек блокировки.

---

## 6. AI Cutscene Authoring Guide (черновик)

Полная версия — `docs/design/cutscene_authoring_guide.md`. Ниже — ключевые правила, которые должны быть в системном промпте будущего агента.

### 6.1. Перед началом

Прочитать:
1. `docs/design/cutscene_system_rfc.md` (этот документ).
2. `docs/design/cutscene_authoring_guide.md`.
3. Ближайший пример в `scripts/cutscene/content/<chapter>/`.
4. `docs/design/first_nightmare_beat_sheet_v2.md` — формат сцены, длительность, можно ли пропускать.
5. `docs/story/first_nightmare_canonical_timeline.md` — канон, если сцена сюжетная.

Проверить:
- В сцене есть `CutsceneStage` и `CutsceneActor` для нужных персонажей.
- В `Shots/*` есть ракурсы; если нет — создать через MCP и проверить `LookAt`.
- В `resources/dialogue/...` есть реплики; если нет — создать `DialogueSequence`.
- В `AudioLibrary` есть нужные cue id; если нет — добавить cue и ассет по правилам лицензий.

### 6.2. Правила

1. **Одна кат-сцена = один `CutsceneDefinition` + один `CutsceneScript` + один `CutsceneStage`** (stage может быть общим для локации).
2. **ID** — `chapter/slug`, snake_case: `prologue/doze`, `caravan/n13_montage`, `temple/n24_altar`.
3. **`run(ctx)`** — только через `ctx`. Никаких прямых `Input`, `get_tree().paused`, `make_current`, `change_scene_to_file`, `queue_free` актёров.
4. **Длительность без ввода ≤ 60 с.** Если больше — разбить на `ctx.await_event`/интерактивное действие или на две сцены.
5. **Пропуск:**
   - по умолчанию `AFTER_FIRST_VIEW`;
   - `NEVER` — только для ключевых сцен (смерти, оценка, алтарь), с обоснованием в `description`;
   - ключевые интерактивные действия не пропускаются;
   - `skip_summary` обязательна для всего, что можно пропустить.
6. **Сюжетные эффекты** — только в `completion_flags/items/checkpoint/beat/journal/bestiary`; `ctx.flag` только для того, что есть в манифесте (или `cosmetic_flags`).
7. **Игрок:** не двигать `global_position` напрямую; `ctx.actor(&"sunny").move_to/walk_to`. Если сцена перемещает игрока — `moves_player=true` + `skip_end_player_marker`.
8. **Камера:** `ctx.camera.shot(id, blend)`; `blend` 0.4–0.8 для обычных переходов, 0.0 для акцента. Не более 6–8 ракурсов на 60 с.
9. **Свет/погода/декор:** менять через `ctx.prop`/`ctx.find` и возвращать в исходное состояние, если это не сюжетное изменение. Всё, что меняется, — в `tracked_props`.
10. **Звук:** `ctx.audio.*`; voice — через диалог. Не останавливать чужую музыку без `restore_audio`/`ctx.audio.restore`.
11. **Тесты:** минимум smoke + skip на 5 точках. Не считать сцену готовой без `validate_cutscenes` = 0 ошибок и фактического прогона.
12. **Файлы:** UTF-8 без BOM; не добавлять абсолютные пути/секреты; не коммитить без задания.

### 6.3. Шаблон скрипта

```gdscript
extends CutsceneScript
## Кат-сцена: <display_name>
## Манифест: res://resources/cutscene/<chapter>/<id>.tres
## Канон: <ссылка на beat sheet / timeline>
##
## Что происходит: <1–2 предложения>
## Управление: заблокировано; пропуск: <политика>
## Эффекты: <флаги/предметы/чекпоинт>

func run(ctx: CutsceneContext) -> void:
    ctx.ui.letterbox(true)
    await ctx.camera.shot(&"<ShotA>", 0.6)
    await ctx.actor(&"sunny").play(&"idle")
    await ctx.wait(0.4)
    await ctx.dialogue(&"<chapter>/<dialogue_id>")
    await ctx.camera.player(0.6)
    ctx.ui.letterbox(false)
```

### 6.4. Шаблон манифеста

Создавать генератором:
```powershell
godot --headless --path . -s tools/cutscene/new_cutscene.gd -- --id=prologue/doze --chapter=prologue --template=in_place
```
Затем заполнить:
- `display_name`, `description`;
- `cutscene_script`;
- `skip_policy`;
- `max_duration`;
- `required_flags` / `completion_flags` / `completion_items` / `completion_checkpoint`;
- `skip_summary`;
- `moves_player` + `skip_end_player_marker` (если нужно).

### 6.5. Команды `ctx` (краткая шпаргалка)

| Команда | Ждёт | Что делает |
|---|---|---|
| `await ctx.wait(sec)` | да | Паузируемая пауза |
| `await ctx.next_frame()` | да | Следующий кадр |
| `await ctx.camera.shot(&"id", 0.6)` | да | Бленд к ракурсу |
| `await ctx.camera.hard_cut(&"id")` | да | Склейка |
| `await ctx.camera.player(0.6)` | да | Вернуть игровую камеру |
| `await ctx.camera.orbit(center, r, h, deg, sec)` | да | Облёт |
| `await ctx.camera.shake(0.35, 0.08)` | да | Тряска |
| `await ctx.actor(&"sunny").play(&"sit_idle")` | да | Клип |
| `await ctx.actor(&"sunny").move_to(marker, 1.2)` | да | Перемещение |
| `await ctx.actor(&"sunny").walk_to(marker, 1.4)` | да | Идти с клипом walk |
| `await ctx.actor(&"sunny").face(target, 0.3)` | да | Поворот |
| `ctx.actor(&"npc").show()/hide()` | нет | Видимость |
| `await ctx.dialogue(&"prologue/sip_1")` | да | Диалог |
| `await ctx.say("...", &"sunny", 2.0)` | да | Одна реплика |
| `await ctx.ui.fade_to(1.0, 0.5)` | да | Затемнение |
| `ctx.ui.fade_clear()` | нет | Убрать затемнение |
| `await ctx.ui.letterbox(true, 0.4)` | да | Поля |
| `await ctx.ui.hint("...", 2.0)` | да | Подсказка |
| `await ctx.ui.title("...", "...", 2.0)` | да | Карточка |
| `ctx.audio.music(&"park", 2.0)` | нет | Музыка |
| `ctx.audio.sfx(&"world_pickup", node)` | нет | Звук |
| `ctx.flag(&"doze_seen")` | нет | Флаг (журналируется) |
| `ctx.item(&"key", 1)` | нет | Предмет |
| `ctx.checkpoint(&"CP-N08", pos, true)` | нет | Чекпоинт |
| `ctx.journal(&"rules_of_nightmare")` | нет | Журнал |
| `ctx.bestiary(&"mountain_king_seen")` | нет | Бестиарий |
| `ctx.event(&"door_open")` | нет | Событие |
| `await ctx.await_event(&"interact:coffee", 10.0)` | да | Ждать событие |
| `ctx.fail("...")` | нет | Прервать сцену |

### 6.6. Паттерны

**Shot / reverse shot (диалог):**
```gdscript
await ctx.camera.shot(&"A", 0.5)
await ctx.dialogue(&"caravan/camp_arrival")
await ctx.camera.shot(&"B", 0.5)
await ctx.dialogue(&"caravan/camp_attack")
await ctx.camera.shot(&"A", 0.5)
```

**Walk-and-talk:**
```gdscript
ctx.actor(&"sunny").begin()
await ctx.actor(&"sunny").walk_to(ctx.marker(&"PathEnd"), 1.4)
await ctx.dialogue(&"prologue/walk_talk")
```

**Монтаж с флешем:**
```gdscript
for shot_id in [&"M1", &"M2", &"M3"]:
    await ctx.camera.shot(shot_id, 0.0)
    await ctx.wait(0.8)
```

**Интерактивная вставка:**
```gdscript
ctx.actor(&"sunny").begin()
ctx.set_interaction_enabled(&"coffee", true)   # если добавлено
await ctx.await_event(&"interact:coffee", 15.0)
ctx.set_interaction_enabled(&"coffee", false)
```
> В MVP `ctx.set_interaction_enabled` можно не добавлять; для интерактивных сцен используйте `Interactable` + `ctx.await_event`, но тогда `CutsceneDirector` не должен блокировать `interactor`. Это отдельное решение Phase 2.

### 6.7. Анти-паттерны

- `await get_tree().create_timer(1.0).timeout` — не паузируется; используйте `ctx.wait`.
- `player.input_enabled = false` — не восстанавливается; используйте `set_cutscene_mode`.
- `camera.make_current()` — склейка и утечка; используйте `ctx.camera`.
- `queue_free()` актёра/пропа — сломает сцену; используйте `ctx.actor.hide()`; для пропсов — верните видимость/трансформ через `tracked_props`.
- `change_scene_to_file()` внутри кат-сцены — смена сцены должна идти через `LevelPortal`/оболочку.
- Сюжетный флаг без `completion_flags` — пропуск разъедется.
- `randf()` без seed — недетерминированные тесты.
- 10 ракурсов на 5 секунд — «клиповый» монтаж; для канона важнее читаемость.
- Пустой `skip_summary` у пропускаемой сюжетной сцены — игрок теряет смысл.

### 6.8. Чек-лист перед сдачей

- [ ] `validate_script` — 0 ошибок.
- [ ] `validate_cutscenes` — 0 ошибок, 0 warning (или warning объяснён).
- [ ] `run_cutscene --fast` — `COMPLETED`.
- [ ] `run_scene` + `start_by_id` — без ошибок в `get_errors`.
- [ ] Скриншот на каждом ракурсе; композиция читается.
- [ ] `request_skip` на 0/25/50/75/100% — `SKIPPED`, ввод/камера восстановлены.
- [ ] `NightmareRunState.snapshot()` после skip == после natural (для прогрессии).
- [ ] `max_duration` ≤ 60 с без ввода (или сцена разбита).
- [ ] `skip_summary` заполнена, если можно пропустить.
- [ ] GUT smoke/skip — зелёные (фактический вывод).
- [ ] Обновлены `docs/DECISIONS.md` (после починки кодировки) и, если нужно, `docs/ASSET_LICENSES.md`.

### 6.9. Формат отчёта агента

```text
Cutscene: prologue/doze
Files: ...
Changed: ...
Validation: validate_cutscenes 0 errors; GUT 4/4; runtime OK
Screenshots: ...
Skip: 5/5 restored; state equivalent
Not tested: full manual playthrough, 1080p
```

---

## 7. План поэтапного внедрения

### Phase 0 — Baseline и контракты (0.5–1 день)

**Задачи:**
- Зафиксировать baseline: полный GUT, `--import`, текущие warning'и.
- Добавить в `docs/DECISIONS.md` решение о фреймворке (после починки кодировки) или отдельный `docs/design/cutscene_system_rfc.md` как источник истины.
- Согласовать open questions (§10): skip binding, pause policy, первый пилот.

**Выход:** RFC принят; baseline записан; нет изменений кода.

### Phase 1 — Ядро фреймворка + пилот (4–6 дней)

**Код:**
- `scripts/cutscene/cutscene_definition.gd`
- `scripts/cutscene/cutscene_stage.gd`
- `scripts/cutscene/cutscene_script.gd`
- `scripts/cutscene/cutscene_context.gd`
- `scripts/cutscene/cutscene_actor.gd` (наследует `CinematicActor`)
- `scripts/cutscene/cutscene_camera_3d.gd`
- `scripts/cutscene/cutscene_ui.gd` + `scenes/ui/cutscene_ui.tscn`
- `scripts/cutscene/cutscene_audio.gd`
- `scripts/cutscene/cutscene_director.gd` (autoload)
- `scripts/cutscene/cutscene_run.gd`
- `scripts/cutscene/cutscene_history.gd`
- `scripts/cutscene/cutscene_trigger.gd`
- `scripts/cutscene/cutscene_interactable.gd`
- `scripts/cutscene/cutscene_validator.gd`

**Additive changes:**
- `SunnyController.set_cutscene_mode(enabled: bool, freeze_physics := true)`.
- `HealthComponent.invulnerable` + проверка в `take_damage`.
- `DialogueRunner.cancel()`, `DialogueRunner.auto_advance` (для тестов), `DialogueRunner.use_pausable_timers`.
- `MusicDirector.get_current_id()`, `AmbienceDirector.get_current_id()`, `AudioDirector.get_music_id()/get_ambience_id()`.
- `PauseMenuSystem`/`PlayerMenuSystem`/`MapSystem`: guard `CutsceneDirector.is_playing()`.
- `SoulSeaController.enter_soul_sea()` и модальные окна инвентаря/торговли: тот же guard; иначе кат-сцена может открыть чужой UI.
- `SaveSystem`: блокировать quick save/load (F5/F9) во время кат-сцены; иначе можно сохранить полусцену.
- `GameplayHud`: группа `gameplay_hud` (или поиск по классу).
- `ProjectSettings`/`project.godot`: autoload `CutsceneDirector`; input action `cutscene_skip` (Backspace + gamepad Back).

**Пилот:**
- Некритичная сцена в `labyrinth_first_fragment` (Z01 arrival vista) или отдельная тестовая сцена. 3 ракурса, 20–30 с, без сюжетных флагов.
- `CutsceneTrigger` на входе; skip `AFTER_FIRST_VIEW`; capture 3 кадров.

**Тесты:**
- `tests/test_cutscene_framework.gd`: lifecycle, input lock/restore, camera restore, skip, timeout, reentrancy, dialogue cancel.
- `tests/test_cutscene_pilot.gd`: пилот completes/skips.
- Регрессия: `test_slice_director`, `test_sunny_waking`, `test_dialogue`, `test_level_transition`.

**Выход:** пилот создан AI-агентом по шаблону; линтер 0 ошибок; GUT зелёный; скриншоты; skip restore.

### Phase 2 — Инструменты и миграция 3 сцен (7–10 дней)

**Инструменты:**
- `validate_cutscenes.gd` + JSON.
- `dump_catalog.gd`.
- `run_cutscene.gd`.
- `capture_cutscene.gd` + contact sheet.
- `new_cutscene.gd`.
- `run_checks.ps1`.
- `tests/test_cutscenes.gd` (smoke/skip по всем).

**Миграция:**
- `prologue/doze` (in-place, UI/drowsiness/camera) — через `SliceDirector` adapter `manage_input=false` или отдельный пилот.
- `caravan/n13_night_montage` (camera/audio, без движения игрока) — заменить ручную камеру.
- `prologue/p03_briefing` (длинная, диалоги, skip-critical) — проверить skip/state.

**Выход:** 3 сцены мигрированы; старые тесты не сломаны; линтер и capture используются агентом.

### Phase 3 — Пропуск в паузе, доступность, оценка PCam (5–7 дней)

- Pause menu с кнопкой «Пропустить»; `ctx.wait`/твины паузируемые.
- `GameSettings.cutscene_shake_scale`, `cutscene_letterbox`, `cutscene_skip_hold`; captions.
- Оценка Phantom Camera на одной динамической сцене (follow/framing); решение — адаптер или отказ.
- `AnimationTree` слои для верх/низ (если нужно).
- Standalone stage-scene для видений/флешбэков (опционально).

**Выход:** пауза+skip работают; accessibility; решение по PCam зафиксировано.

### Phase 4 — Полная миграция и депрекация legacy (ongoing)

- Перенести B03/B04/B08/B09/B10/B14 из `SliceLocation.play_cutscene` в `CutsceneStage`.
- Перенести `caravan_site_arrival`/`pilgrim_path_arrival` постановки.
- `SliceLocation.play_cutscene` оставить как thin adapter, затем удалить после полной миграции.
- Обновить `docs/DECISIONS.md`, `docs/design/level_transitions.md`, handoff.

**Карта миграции (предлагаемая):**

| Сейчас | Куда | Риск |
|---|---|---|
| `park_street._doze` | `prologue/doze` | Низкий: UI/камера, без флагов |
| `park_street._stand_up/_bin` | `prologue/bin` | Низкий: движение/пропсы |
| `station_lobby._code_black` | `prologue/b09_code_black` | Средний: звук/свет |
| `containment_room` | `prologue/p03_briefing` | Высокий: длинные диалоги, skip |
| `spell_void` | `prologue/b13_spell` | Средний: UI/видение |
| `mountain_vision._vision` | `prologue/b14_vision` | Высокий: орбита/окружение |
| `caravan_site_arrival` N08/N10 | `caravan/n08_tyrant`, `caravan/n10_wagon` | Высокий: бой/чекпоинты |
| `caravan_site_arrival` N11/N13 | `caravan/n11_council`, `caravan/n13_montage` | Средний: камера/монтаж |
| `pilgrim_path_arrival` N19/N22 | `pilgrim/n19_scholar`, `pilgrim/n22_bell` | Высокий: смерть/звук |
| `sanctuary_arrival` N24 | `temple/n24_altar` | Очень высокий: интерактив/смерть |
| `appraisal.gd` | `temple/n25_appraisal` | Высокий: UI/награды |
| `finale.gd` | `temple/n26_awakening` | Средний: UI/финал |

---

## 8. Критерии приёмки и метрики

### 8.1. Функциональные критерии

- AI создаёт 30-секундную кат-сцену за одну сессию: stage, script, manifest, trigger.
- `validate_cutscenes` — 0 ошибок.
- `run_cutscene --fast` — `COMPLETED`.
- Runtime: 3+ скриншота, композиция читается, нет ошибок.
- Skip на 5 точках — `SKIPPED`, ввод/камера/HUD восстановлены.
- Прогрессия после skip == после natural.
- Нет утечки `input_enabled`, `look_enabled`, `mouse_mode`, `paused`.
- Нет orphan nodes после cleanup.
- Legacy-тесты (`test_slice_director`, `test_campaign_flow`, `test_full_route`) проходят.

### 8.2. Метрики

| Метрика | Цель |
|---|---|
| Время создания 30-с сцены агентом | ≤ 20 мин (включая проверки) |
| Время headless-прогона одной сцены (fast) | ≤ 2 с |
| Overhead `CutsceneDirector` | ≤ 0.5 мс/кадр |
| Пропуск: восстановление | ≤ 1 кадр после cleanup |
| Покрытие skip-тестами | 100% кат-сцен × 5 точек |
| Линтер | 100% кат-сцен, 0 ошибок |
| Регрессия GUT | 0 падений |
| Новые autoloads | 1 (`CutsceneDirector`) |

---

## 9. Риски и меры

| Риск | Вероятность | Влияние | Мера |
|---|---|---|---|
| Корутина не отменяется и продолжает менять состояние после skip | Средняя | Высокое | Удалять `CutsceneScript` Node; `ctx.cancelled` guard; тест skip на 5 точках |
| Пропуск разъезжается с флагами | Высокая | Высокое | `completion_*` в манифесте; линтер; state-equivalence тест |
| Камера остаётся чужой / DOF протекает | Средняя | Высокое | Один `CutsceneCamera3D`; restore + `make_current` игровой; тест attributes |
| AI генерирует несуществующие клипы/ракурсы | Высокая | Среднее | `dump_catalog`; линтер; fail-fast `ctx` |
| Спагетти в скриптах | Средняя | Среднее | Фасад + запрещённые API + code review |
| Конфликт со `SliceDirector` | Средняя | Высокое | Не запускать в прологе до Phase 3; adapter `manage_input=false` |
| Таймеры не паузируются | Высокая | Среднее | `create_timer(sec, false)`; `DialogueRunner.use_pausable_timers` |
| Меню открывается в кат-сцене | Средняя | Высокое | Guard в `PauseMenuSystem`/`PlayerMenuSystem`/`MapSystem` |
| Игрока убивают в кат-сцене | Средняя | Высокое | `HealthComponent.invulnerable`; пауза врагов |
| PCam затягивает в зависимость | Низкая | Среднее | Не внедрять в MVP; адаптер |
| `DECISIONS.md` повреждён | Высокая | Низкое | Починить кодировку отдельной задачей; пока RFC — источник |
| Полный GUT нестабилен | Средняя | Среднее | Targeted-тесты; фиксировать baseline; не выдавать за полный прогон |

---

## 10. Открытые вопросы (нужно решение пользователя)

1. **Skip input:** `Backspace` + gamepad `Back` с удержанием 0.6 с — ок? Или `Esc` long-press?
2. **Пауза во время кат-сцены:** блокировать в MVP или сразу делать pause-with-skip?
3. **Первый пилот:** Z01 arrival vista в `labyrinth_first_fragment` (безопасно) или сразу `prologue/doze` (риск для пролога)?
4. **История просмотров:** один профиль (`user://cutscene_history.cfg`) или сразу слоты сохранений?
5. **Phantom Camera:** подтверждаем отказ в MVP?
6. **`SliceDirector`:** оставляем legacy до Phase 3 или мигрируем пролог раньше?
7. **Интерактивные кат-сцены:** нужны ли в MVP `ctx.await_event` + включение `Interactable`, или сначала только неинтерактивные?
8. **Локализация:** сейчас русский текст в `.tres`; нужны ли `tr()`-ключи для новых кат-сцен?

---

## 11. Приложение A: карта файлов (предлагаемая)

```
scripts/cutscene/
  cutscene_types.gd
  cutscene_definition.gd
  cutscene_stage.gd
  cutscene_script.gd
  cutscene_context.gd
  cutscene_actor.gd
  cutscene_camera_3d.gd
  cutscene_ui.gd
  cutscene_audio.gd
  cutscene_run.gd
  cutscene_history.gd
  cutscene_director.gd
  cutscene_trigger.gd
  cutscene_interactable.gd
  cutscene_validator.gd
  content/
    prologue/
      doze.gd
    caravan/
      n13_night_montage.gd
    temple/
      n24_altar.gd
scenes/ui/cutscene_ui.tscn
scenes/cutscene/<chapter>/<id>.tscn          # optional standalone stage
resources/cutscene/<chapter>/<id>.tres
tests/test_cutscene_framework.gd
tests/test_cutscenes.gd
tools/cutscene/validate_cutscenes.gd
tools/cutscene/dump_catalog.gd
tools/cutscene/run_cutscene.gd
tools/cutscene/capture_cutscene.gd
tools/cutscene/new_cutscene.gd
tools/cutscene/list_clips.gd
tools/cutscene/run_checks.ps1
tools/cutscene/contact_sheet.py
```

## 12. Приложение B: тест-матрица

| Тест | Проверяет |
|---|---|
| `test_lifecycle_completes` | `COMPLETED`, сигналы, state |
| `test_lifecycle_invalid_no_lock` | `INVALID`, ввод не заблокирован |
| `test_busy_rejects_second` | `BUSY`, первый run не тронут |
| `test_input_lock_restore` | все поля player/camera/interactor восстановлены |
| `test_camera_blend_restore` | transform/FOV/attributes; player camera current |
| `test_camera_dof_no_leak` | attributes игровой камеры не изменились |
| `test_skip_policy_never` | `request_skip` false |
| `test_skip_policy_after_first_view` | false до `mark_seen`, true после |
| `test_skip_policy_always` | true |
| `test_skip_state_equivalence` | snapshot flags/items/checkpoint равны natural |
| `test_skip_restores_camera_input_ui` | всё восстановлено |
| `test_skip_cancels_dialogue` | субтитры скрыты, runner не running |
| `test_timeout_aborts` | `ABORTED`, cleanup |
| `test_scene_change_aborts` | cleanup |
| `test_pauseable_wait` | пауза останавливает `ctx.wait` |
| `test_missing_actor_fails` | `INVALID`/`ABORTED`, нет утечки |
| `test_missing_clip_lint` | линтер ловит |
| `test_trigger_conditions` | флаги/one-shot |
| `test_quick_save_blocked` | F5/F9 не сохраняют во время сцены |
| `test_portal_cutscene_adapter` | `LevelPortal` играет сцену |
| `test_slice_director_regression` | 11/11 |
| `test_campaign_flow_regression` | 22/22 |
| `test_all_cutscenes_smoke` | все `COMPLETED` |
| `test_all_cutscenes_skip` | все `SKIPPED` + restore |

## 13. Приложение C: что не делать

- Не добавлять `CutsceneDirector` как второй `SliceDirector` с собственными режимами `FREE/LOOK/LOCKED`. Режимы — ответственность `SliceDirector`/`GameModes`; кат-сцена только блокирует/восстанавливает.
- Не хранить ссылки на узлы в `CutsceneDefinition` (кроме optional `stage_scene`): только id/пути, иначе ресурс становится хрупким.
- Не делать `CutsceneDefinition` с массивом шагов в MVP. Если позже понадобится — это будет отдельный `CutsceneTimeline`, компилируемый в те же `ctx`-команды.
- Не использовать `AnimationPlayer` method tracks как основной способ синхронизации: логика спрячется в анимации, AI её не увидит.
- Не добавлять новый MCP-сервер без решения пользователя.
- Не коммитить сгенерированные скриншоты/видео в Git.

---

## 14. Итог

Фундамент должен быть **тонким, но строгим**:

- тонкий слой исполнения — GDScript-корутина;
- строгий контракт — `CutsceneDefinition` + `CutsceneContext`;
- один владелец состояния — `CutsceneDirector`;
- один владелец камеры — `CutsceneCamera3D`;
- один владелец пропуска — `CutsceneDirector` + `CutsceneHistory`;
- один язык для AI — `ctx`-команды + линтер + каталог;
- один способ проверки — headless GUT + runtime screenshots + skip-тесты.

Это даёт AI возможность **писать кат-сцены как код**, а не «кликать сцену», и при этом не ломает существующий пролог, кампанию и боевые системы.

---

## 15. Запись в `docs/DECISIONS.md` (предлагаемая, после починки кодировки)

`docs/DECISIONS.md` сейчас повреждён двойной кодировкой; не добавлять в него новую запись, пока файл не перекодирован. После починки добавить:

```text
## 2026-11-XX — AI-first cutscene framework

- **Cutscenes use a manifest + GDScript coroutine, not a custom DSL or a chain
  of Resource steps.** `CutsceneDefinition` (.tres) declares id, script, skip
  policy, duration cap, entry conditions and completion effects.
  `CutsceneScript.run(ctx)` stages the scene through `CutsceneContext`.
- **One owner.** Autoload `CutsceneDirector` owns lifecycle, input/camera/UI
  lock, skip, cleanup and history. `CutsceneCamera3D` owns the cinematic camera;
  `CutsceneUI` owns subtitles/letterbox/fade/skip prompt.
- **Skip is state-equivalent.** Skip cancels the script, restores snapshots and
  applies `completion_flags/items/checkpoint/beat/journal/bestiary`. Key scenes
  are `NEVER`; default is `AFTER_FIRST_VIEW`.
- **Phantom Camera is not adopted in MVP.** Re-evaluate only if follow/framing,
  path-dolly, handheld noise or priority stacks become necessary; wrap behind a
  camera backend.
- **Legacy `SliceDirector`/`SliceLocation.play_cutscene()` stays until parity.**
  New framework is additive; migration is phased and covered by GUT.
- **AI tooling:** cutscene linter, scene catalog dump, headless runner, shot
  capture, template generator. No new MCP server; use godot-mcp 0.6.1 + CLI.
- **Verification:** full GUT is the gate; targeted tests and runtime screenshots
  are recorded honestly. `NOT TESTED` is used when a check was not run.
```

