# AI Cutscene Authoring Guide

**Для кого:** AI-агент, который создаёт, редактирует и проверяет кат-сцены в ShadowSlave.  
**Статус:** фреймворк реализован (Stage 5); примеры M1 лежат в `scripts/cutscene/content/m1/` и `resources/cutscene/m1/`.  
**Движок:** Godot 4.7.2, GDScript.  
**Главное правило:** кат-сцена — это **манифест + скрипт + stage**, а не набор ручных правок сцены.

---

## 0. Что читать перед задачей

1. `docs/design/cutscene_system_rfc.md` — архитектура и решения.
2. Этот гайд — правила и шаблоны.
3. `docs/design/first_nightmare_beat_sheet_v2.md` — формат события, длительность, можно ли пропускать.
4. `docs/story/first_nightmare_canonical_timeline.md` — канон, если сцена сюжетная.
5. `docs/design/level_transitions.md` — если сцена связана с переходом между локациями.
6. Ближайший пример в `scripts/cutscene/content/<chapter>/` (когда появится).
7. `AGENTS.md` — правила проекта, Git, LFS, MCP, тесты.

Если документ противоречит памяти/догадке — прав документ. Расхождение фиксируется в `docs/DECISIONS.md` (после починки кодировки) или в RFC.

---

## 1. Термины

| Термин | Значение |
|---|---|
| **Cutscene** | Короткая постановочная сцена с блокировкой управления. |
| **Stage** | `Node3D`-контейнер: `Markers/`, `Shots/`, `Props/`, опционально актёры. Живёт в сцене уровня. |
| **Script** | Одноразовый `Node` с `run(ctx)`. Создаётся директором, удаляется после сцены/пропуска. |
| **Definition** | `.tres`-манифест: id, скрипт, политика пропуска, эффекты завершения. |
| **Context (`ctx`)** | Фасад, через который скрипт говорит с камерой, актёрами, UI, звуком, состоянием. |
| **Run** | Один запуск: снапшоты, таймер, результат, отмена. |
| **Skip** | Отмена выполнения + восстановление + применение `completion_*`. Не «перемотка таймера». |

---

## 2. Жёсткие правила

### 2.1. Что можно

- Писать `run(ctx)` на GDScript с `await`.
- Использовать только методы `ctx.*` (см. §5).
- Создавать stage-сцену, маркеры, ракурсы, триггеры через MCP.
- Создавать `CutsceneDefinition` через генератор или `ResourceSaver`.
- Добавлять новые `DialogueSequence`/`ActionClipMap`/audio cues по правилам проекта.
- Добавлять тесты и CLI-инструменты.

### 2.2. Что нельзя

| Запрет | Почему | Правильно |
|---|---|---|
| `Input.*`, `InputMap.*` в скрипте | Ломает единого владельца ввода | `ctx`/`CutsceneDirector` |
| `get_tree().paused = ...` | Конфликт с pause menu/modal | `CutsceneDirector` |
| `Camera3D.make_current()` | Склейка, утечка камеры | `ctx.camera.shot/player` |
| `player.input_enabled = ...` | Не восстанавливается | `player.set_cutscene_mode()` |
| `camera_rig.*` | То же | `ctx.camera` |
| `change_scene_to_file()` | Сцена меняется вне портала | `LevelPortal`/оболочка |
| `queue_free()` актёра/пропа | Сломает сцену и restore | `ctx.actor.hide()`; для пропсов — `tracked_props` |
| `await get_tree().create_timer(...)` | Не паузируется | `await ctx.wait(...)` |
| Сюжетный флаг без манифеста | Skip разъедется | `ctx.flag` + `completion_flags` |
| `randf()` без seed | Недетерминированные тесты | `ctx.rng`/фиксированный seed |
| Абсолютные пути/секреты | Правила проекта | `res://`, `user://` |
| BOM в `.gd/.tres/.tscn` | Godot ломает парсинг | UTF-8 без BOM |

Не используйте `@onready` на узлы сцены: доступ к актёрам/пропсам — только через `ctx`. Изменяемые пропсы должны быть в `tracked_props`, иначе пропуск не восстановит их.

### 2.3. Длительность и пропуск
- Без ввода — **≤ 60 секунд**. Больше — разбить действием игрока или на две сцены.
- `skip_policy`:
  - `AFTER_FIRST_VIEW` — по умолчанию;
  - `NEVER` — сцена не пропускается никогда (обязательное действие, например «лечь на алтарь»), только с обоснованием;
  - `ALWAYS` — короткие служебные сцены;
  - `DEBUG_ONLY` — только для тестов.
- Для ключевых смертей/оценки: `AFTER_FIRST_VIEW` + `key_scene = true` + непустая `skip_summary`. Первый показ обязателен, повторный можно сократить.
- Если сцену можно пропустить, `skip_summary` обязательна.
- Ключевые интерактивные действия (звонок, ключ, алтарь, «лечь») не пропускаются.

---

## 3. Структура файлов

```
scripts/cutscene/content/<chapter>/<id>.gd      # CutsceneScript
resources/cutscene/<chapter>/<id>.tres          # CutsceneDefinition
scenes/cutscene/<chapter>/<id>.tscn             # optional standalone stage
```

**ID:** `chapter/slug`, snake_case: `prologue/doze`, `caravan/n13_montage`, `temple/n24_altar`.

**Stage в уровне:** `Node3D` с именем `CutsceneStage_<id>` (или уникальным), дети:
```
CutsceneStage_doze/
  Markers/
    BenchStand
    BinThrow
  Shots/
    DozeShot          # Camera3D
      LookAt          # Marker3D
    RoomShot
  Props/
    CoffeeCup
  tracked_props = [Props/CoffeeCup]
```

**Актёры** — не в stage, а на персонажах:
```
Sunny/
  CutsceneActor       # actor_id = "sunny"
```
Или NPC:
```
Hero/
  CutsceneActor       # actor_id = "hero"
```

---

## 4. Пошаговый процесс

### Шаг 1. Собрать каталог

```powershell
godot --headless --path . -s tools/cutscene/dump_catalog.gd `
  -- --scene=res://scenes/locations/.../scene.tscn `
  --out=user://cutscene_catalog.json
```

Прочитать JSON: актёры, клипы, ракурсы, маркеры, диалоги, звук. Не придумывать id — брать из каталога.

### Шаг 2. Создать шаблон

```powershell
godot --headless --path . -s tools/cutscene/new_cutscene.gd `
  -- --id=prologue/doze --chapter=prologue --template=in_place
```

Или вручную через MCP:
- `create_scene` для stage;
- `create_script` для `cutscene_script`;
- `write_file`/`ResourceSaver` для `.tres`.

### Шаг 3. Заполнить манифест

Минимум:
```gdscript
id = &"prologue/doze"
display_name = "Дремота"
chapter = &"prologue"
cutscene_script = ExtResource("...")  # CutsceneScript
skip_policy = 1                       # AFTER_FIRST_VIEW
key_scene = false                     # true для ключевых смертей/оценки
max_duration = 20.0
completion_flags = Array[StringName]([&"doze_seen"])
skip_summary = Array[String](["Санни клюёт носом и приходит в себя от шлепка по щеке."])
moves_player = false
```

Если сцена двигает игрока:
```gdscript
moves_player = true
skip_end_player_marker = &"AfterDoze"
```

### Шаг 4. Написать `run(ctx)`

```gdscript
extends CutsceneScript
## Кат-сцена: Дремота
## Манифест: res://resources/cutscene/prologue/doze.tres
## Канон: first_nightmare_beat_sheet_v2.md, P01
##
## Санни клюёт носом, кадр мутнеет, шлепок возвращает ясность.
## Управление заблокировано; пропуск после первого просмотра.

func run(ctx: CutsceneContext) -> void:
    ctx.ui.letterbox(true)
    await ctx.camera.shot(&"DozeShot", 0.8)
    await ctx.ui.drowsiness(0.95, 2.5)
    await ctx.ui.fade_to(0.85, 0.6)
    await ctx.wait(0.6)
    ctx.ui.fade_clear()
    await ctx.camera.shake(0.35, 0.08)
    await ctx.camera.player(0.5)
    ctx.ui.letterbox(false)
```

### Шаг 5. Валидация

```powershell
godot --headless --path . -s tools/cutscene/validate_cutscenes.gd -- --id=prologue/doze
```

Ожидаемо: `0 errors`. Warning'и объяснить.

### Шаг 6. Headless-прогон

```powershell
godot --headless --path . -s tools/cutscene/run_cutscene.gd -- --id=prologue/doze --fast
```

Ожидаемо: `COMPLETED`.

### Шаг 7. Runtime + скриншоты

Через MCP:
1. `run_scene` с `wait_for_runtime:true`.
2. `call_method("/root/CutsceneDirector", "start_by_id", ["prologue/doze"], runtime:true)`.
3. `query_runtime_node("/root/CutsceneDirector")` — `get_debug_state`.
4. `take_screenshot` на каждом ракурсе.
5. `get_errors` — 0 ошибок кат-сцены.
6. `stop_scene`.

### Шаг 8. Пропуск

```js
await tools.godot.call_method({
  node_path: "/root/CutsceneDirector",
  method: "request_skip",
  args: [true],
  runtime: true
});
```

Проверить:
- `get_debug_state().state == "IDLE"` (или `FINISHED`);
- ввод/камера/HUD восстановлены;
- `NightmareRunState.snapshot()` содержит `completion_*`;
- нет orphan nodes.

### Шаг 9. GUT

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd `
  -gtest=res://tests/test_cutscene_framework.gd `
  -gtest=res://tests/test_cutscene_<id>.gd -gexit
```

Приложить фактический вывод. Не писать «прошло», если не запускал.

### Шаг 10. Отчёт

```text
Cutscene: prologue/doze
Files: ...
Changed: ...
Validation: 0 errors / N warnings
Runtime: no errors; shots captured: 3
Skip: 5/5; state equivalent
Tests: ...
Not tested: full manual playthrough, 1080p
```

---

## 5. Команды `ctx`

### 5.1. Время

```gdscript
await ctx.wait(1.5)                 # паузируемая пауза
await ctx.next_frame()              # следующий кадр
await ctx.wait_until(callable, 10)  # ждать условие/таймаут
```

### 5.2. Камера

```gdscript
await ctx.camera.shot(&"DozeShot", 0.8)          # бленд
await ctx.camera.hard_cut(&"Impact")             # склейка
await ctx.camera.player(0.6)                     # вернуть игровую
await ctx.camera.orbit(center, 8.0, 3.0, 90.0, 4.0)
await ctx.camera.shake(0.35, 0.08)
ctx.camera.follow(node, Vector3(0, 2, 4), 0.15)  # до следующего shot
```

- `blend` 0.4–0.8 — обычный переход.
- `0.0` — акцент/склейка.
- Не более 6–8 ракурсов на 60 с.
- `shot` копирует transform/FOV/DOF; не менять `attributes` игровой камеры.

### 5.3. Актёры

```gdscript
var sunny := ctx.actor(&"sunny")
await sunny.play(&"sit_idle")
await sunny.move_to(ctx.marker(&"BenchStand"), 0.8)
await sunny.walk_to(ctx.marker(&"BinThrow"), 1.4)
await sunny.face(ctx.marker(&"BinThrow"), 0.3)
sunny.hide()
sunny.show()
```

- `play` возвращает длину клипа.
- `ctx.actor` при первом обращении сам включает cinematic-режим и делает снапшот; `begin()` вызывать не обязательно.
- `move_to`/`walk_to` работают при выключенной физике; не двигать `global_position` вручную.
- `face` — кратчайшая дуга.
- Для NPC используйте `ctx.actor(&"hero")`, если на нём есть `CutsceneActor`.

### 5.4. Диалоги

```gdscript
await ctx.dialogue(&"prologue/sip_1")       # resources/dialogue/prologue/sip_1.tres
await ctx.dialogue_resource(sequence)       # готовый DialogueSequence
await ctx.say("Холодно.", &"sunny", 1.5)    # одноразовая реплика
```

- Реплики с `duration <= 0` ждут ввода; в `fast_mode` тест должен пролистывать или использовать `auto_advance`.
- Voice запускается автоматически по `voice_id`/имени.

### 5.5. UI

```gdscript
await ctx.ui.fade_to(1.0, 0.5)
ctx.ui.fade_clear()
await ctx.ui.letterbox(true, 0.4)
await ctx.ui.hint("E — отпить", 2.0)
await ctx.ui.title("Первый Кошмар", "Глава 1", 2.0)
ctx.ui.flash(Color(0.8, 0.1, 0.1, 0.4), 0.2)
ctx.ui.set_hud_visible(false)
```

- `set_hud_visible(false)` скрывает `GameplayHud`; восстановление автоматически.
- `drowsiness` — только если в сцене есть соответствующий overlay (пролог); иначе no-op.

### 5.6. Звук

```gdscript
ctx.audio.music(&"park", 2.0)
ctx.audio.ambience(&"park", 2.0)
ctx.audio.reverb(&"outdoor")
ctx.audio.sfx(&"world_pickup", ctx.prop(&"cup"))
ctx.audio.duck(-6.0, 0.5)
```

- `restore_audio=true` в манифесте — вернуть музыку/эмбиент после сцены.
- Иначе звук остаётся как после сцены (осознанно).

### 5.7. Состояние

```gdscript
ctx.flag(&"doze_seen")                       # должно быть в completion_flags
ctx.clear_flag(&"chain_restrained")           # должно быть в completion_clear_flags
ctx.item(&"key", 1)                          # минимальное итоговое количество
ctx.remove_item(&"water", 1)                 # снять при завершении/пропуске
ctx.checkpoint(&"CP-N08", pos, true)
ctx.journal(&"rules_of_nightmare")
ctx.bestiary(&"mountain_king_seen")
ctx.event(&"door_open")
await ctx.await_event(&"interact:coffee", 15.0)
```

- `ctx.flag/item/checkpoint/journal/bestiary` журналируются.
- При пропуске директор применит `completion_*` из манифеста, а не недоигранные вызовы.
- `ctx.event` — для внешних слушателей; `await_event` — для интерактивных вставок (Phase 2).

### 5.8. Служебное

```gdscript
ctx.fail("Нет ракурса DozeShot")   # abort
ctx.commit()                       # применить completion_* досрочно
var tween := ctx.create_tween()    # кастомный твин; умирает вместе со скриптом
```

---

## 6. Паттерны

### 6.1. Shot / reverse shot

```gdscript
await ctx.camera.shot(&"Wide", 0.5)
await ctx.dialogue(&"caravan/camp_arrival")
await ctx.camera.shot(&"CloseHero", 0.5)
await ctx.dialogue(&"caravan/camp_attack")
await ctx.camera.shot(&"Wide", 0.5)
```

### 6.2. Walk-and-talk

```gdscript
ctx.actor(&"sunny").begin()
await ctx.actor(&"sunny").walk_to(ctx.marker(&"PathEnd"), 1.4)
await ctx.dialogue(&"prologue/walk_talk")
```

### 6.3. Монтаж

```gdscript
for shot_id in [&"M1", &"M2", &"M3"]:
    await ctx.camera.shot(shot_id, 0.0)
    await ctx.wait(0.8)
```

### 6.4. Видение / флешбэк

```gdscript
await ctx.ui.fade_to(1.0, 0.5)
await ctx.camera.shot(&"VisionWide", 0.0)
ctx.audio.music(&"vision", 0.5)
await ctx.wait(2.0)
await ctx.camera.orbit(center, 12.0, 4.0, 120.0, 5.0)
await ctx.ui.fade_to(1.0, 1.0)
```

### 6.5. Интерактивная вставка (Phase 2)

```gdscript
# Требует отдельного решения: CutsceneDirector не блокирует Interactor,
# или ctx.set_interaction_enabled().
await ctx.await_event(&"interact:altar", 30.0)
```

---

## 7. Анти-паттерны

| Плохо | Почему | Хорошо |
|---|---|---|
| `await get_tree().create_timer(1.0).timeout` | Пауза меню не остановит | `await ctx.wait(1.0)` |
| `player.input_enabled = false` | Утечка/конфликт | `player.set_cutscene_mode(true)` |
| `camera.make_current()` | Склейка, чужая камера | `await ctx.camera.shot(...)` |
| `queue_free()` NPC | Сцена потеряет актёра | `ctx.actor(&"npc").hide()` |
| `change_scene_to_file()` | Обход `LevelPortal` | `LevelPortal`/оболочка |
| `ctx.flag("x")` без манифеста | Skip разъедется | `completion_flags` |
| `randf()` | Недетерминизм | seed/`ctx.rng` |
| 10 ракурсов на 5 с | Клиповый монтаж | 3–5 ракурсов, читаемость |
| Пустой `skip_summary` | Игрок теряет смысл | 2–4 субтитра/карточка |

---

## 8. Пример полной сцены

### 8.1. Манифест

`resources/cutscene/prologue/doze.tres`:
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

### 8.2. Скрипт

`scripts/cutscene/content/prologue/doze.gd`:
```gdscript
extends CutsceneScript
## Кат-сцена: Дремота
## Манифест: res://resources/cutscene/prologue/doze.tres
## Канон: first_nightmare_beat_sheet_v2.md, P01
##
## Санни клюёт носом, кадр мутнеет, шлепок возвращает ясность.

func run(ctx: CutsceneContext) -> void:
    ctx.ui.letterbox(true)
    await ctx.camera.shot(&"DozeShot", 0.8)
    await ctx.ui.drowsiness(0.95, 2.5)
    await ctx.ui.fade_to(0.85, 0.6)
    await ctx.wait(0.6)
    ctx.ui.fade_clear()
    await ctx.camera.shake(0.35, 0.08)
    await ctx.camera.player(0.5)
    ctx.ui.letterbox(false)
```

### 8.3. Stage

`scenes/locations/.../park_street.tscn`:
```
CutsceneStage_doze (Node3D, script = cutscene_stage.gd)
  Markers/
    BenchStand (Marker3D)
    BinThrow (Marker3D)
  Shots/
    DozeShot (Camera3D)
      LookAt (Marker3D)
    RoomShot (Camera3D)
      LookAt (Marker3D)
  Props/
    CoffeeCup (Node3D)
  tracked_props = [Props/CoffeeCup]
```

### 8.4. Триггер

```
CutsceneTrigger_doze (Area3D, script = cutscene_trigger.gd)
  CollisionShape3D
  cutscene_id = &"prologue/doze"
  required_flags = [&"coffee_drunk"]
  one_shot = true
```

---

## 9. Проверка и отчёт

### 9.1. Обязательный минимум

```powershell
# 1. Парсинг скрипта
godot --headless --path . -s tools/cutscene/validate_cutscenes.gd -- --id=prologue/doze

# 2. Headless-прогон
godot --headless --path . -s tools/cutscene/run_cutscene.gd -- --id=prologue/doze --fast

# 3. GUT
godot --headless --path . -s addons/gut/gut_cmdln.gd `
  -gtest=res://tests/test_cutscene_framework.gd `
  -gtest=res://tests/test_cutscene_doze.gd -gexit
```

### 9.2. Runtime

- `run_scene` + `start_by_id`.
- `get_errors` — 0 ошибок кат-сцены.
- `take_screenshot` на каждом ракурсе.
- `request_skip` на 0/25/50/75/100%.
- `get_debug_state` — `IDLE`/`FINISHED`, `locked=false`.

### 9.3. Что писать в отчёте

- Файлы и изменения.
- Фактические команды и результаты.
- Скриншоты (пути).
- Skip-проверки.
- Что **не** проверено (полный ручной проход, 1080p, геймпад).
- Если тест не запускался — `NOT TESTED`.

---

## 10. Частые ошибки и что делать

| Симптом | Причина | Решение |
|---|---|---|
| `CutsceneDirector: BUSY` | Уже играет другая сцена | Дождаться `finished`/не запускать из триггера |
| `INVALID: missing shot` | Нет `Shots/<id>` в stage/scene | Добавить камеру + `LookAt`, проверить id |
| `INVALID: missing actor` | Нет `CutsceneActor` с `actor_id` | Добавить компонент на персонажа |
| `missing clip` | `ActionClipMap` не содержит действие | Добавить маппинг в `ActionClipMap` или использовать существующий клип |
| Субтитры не видны | Нет `CutsceneUI`/`SubtitleUI` | Проверить autoload/сцену |
| Ввод остался заблокирован | Скрипт упал до cleanup | Смотреть `get_debug_state`, `get_errors`; watchdog должен abort-ить |
| Камера осталась чужая | `make_current` в обход `ctx` | Убрать прямой вызов |
| Пропуск не работает | `skip_policy=NEVER` или нет `has_seen` | Проверить политику/историю |
| Флаги после skip не те | Нет `completion_flags` | Добавить в манифест |
| Таймеры не паузаются | `create_timer` без `false` | `ctx.wait` |

---

## 11. Ссылки

- RFC: `docs/design/cutscene_system_rfc.md`
- Канон: `docs/story/first_nightmare_canonical_timeline.md`
- Beat sheet: `docs/design/first_nightmare_beat_sheet_v2.md`
- Переходы: `docs/design/level_transitions.md`
- Архитектурный аудит: `docs/design/13_systems_architecture_audit.md`
- Правила проекта: `AGENTS.md`
- MCP: `.opencode/skills/mcp-operations/SKILL.md`
