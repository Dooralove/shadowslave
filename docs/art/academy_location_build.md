# Academy locations — build report

Дата: 2026-11-03  
Статус: **standalone art locations + playable gameplay wrappers built.**  
Арт-сцены остаются чистыми окружениями; игровой слой (игрок, HUD, NPC, диалоги, 24 квеста, лут, порталы, коллизии) собран в отдельных `*_playable.tscn` и не меняет M1-маршрут.  
Проверки: script audit 392/0, resource audit 762/0, full GUT 723/723 (7882 asserts), targeted 16/16 + 3/3 + 33/33, headless gameplay/interaction/navigation/walkthrough probes — **0 failures**, walkthrough completes **24/24** quests. Полный ручной проход, 1080p/60 FPS и финальный art pass — **NOT TESTED**.

---

## 1. Что сделано

Две самостоятельные арт-локации и два игровых wrapper'а:

| Слой | Локация | Сцена | Назначение |
|---|---|---|---|
| Art | **Academy Grounds** | `scenes/locations/academy/academy_grounds.tscn` | Окружение Академии: подъезд, КПП, ров, красные ворота, стена, башни, плац, галерея, Sleeper Center, столовая, додзё, академическое крыло, медицинский корпус, зимний ландшафт и дальний город. |
| Art | **Sleeper Center** | `scenes/locations/academy/academy_sleeper_center_building.tscn` | Здание изнутри: тамбур, дортуар с 12 капсулами, общая комната, душевые, наблюдательный пункт, медицинский коридор, галерея Hollow, палата погружения, жилой коридор и комната 07. |
| Playable | **Academy Grounds** | `scenes/locations/academy_playable/academy_grounds_playable.tscn` | Игрок, HUD, fade, спавны, портал в Sleeper Center, NPC, интерактивы, лут и квесты экстерьера. |
| Playable | **Sleeper Center** | `scenes/locations/academy_playable/academy_sleeper_center_playable.tscn` | Игрок, HUD, fade, спавны, портал обратно, NPC, интерактивы, лут и квесты интерьера. |

Арт-сцены остаются **чистым окружением**: в них нет `Player`, `Spawns`, `Portals`, `QuestNpc`, `Interactable`, диалогов и HUD. Игровой слой добавляется отдельными wrapper-сценами и `AcademyGameplayDirector`, поэтому геометрию можно дальше менять независимо от квестов. M1-сцены `academy_approach.tscn`, `academy_gate.tscn`, `academy_campus.tscn`, `academy_sleeper_center.tscn` не изменялись.

---

## 2. Файлы

### 2.1. Сцены

- `scenes/locations/academy/academy_grounds.tscn`
- `scenes/locations/academy/academy_sleeper_center_building.tscn`

### 2.2. Ассеты

- `assets/environments/academy/academy_grounds.glb` — 1675 объектов, 76 194 полигона (Blender).
- `assets/environments/academy/academy_sleeper_center.glb` — 1390 объектов, 70 032 полигона (Blender).
- `.glb.import` — импорт Godot; GLB хранятся в Git LFS согласно `.gitattributes`.

### 2.3. Blender-исходники

- `assets/environments/academy/source/academy_kit.py` — общая библиотека: координаты Godot → Blender, материалы, примитивы, окна, лестницы, ограждения, светильники, скамьи, кадки, турели, стены, комнаты.
- `assets/environments/academy/source/build_academy_grounds.py` — экстерьер.
- `assets/environments/academy/source/build_academy_sleeper_center.py` — интерьер.

### 2.4. Godot-скрипты

- `scripts/locations/academy/academy_materials.gd` — PBR-материалы по именам материалов GLB, трипланарные текстуры, стекло, эмиссия.
- `scripts/locations/academy/academy_grounds_art.gd` — зимнее небо, туман, солнце, практические источники, снег, камеры, коллизии, вывески.
- `scripts/locations/academy/academy_sleeper_center_art.gd` — интерьерный свет, камеры, коллизии, вывески.
- `scripts/locations/academy/academy_playable_location.gd` — общий wrapper: player/HUD/fade, включение academy-scope, камера игрока.
- `scripts/locations/academy/academy_gameplay_director.gd` — data-driven спавн NPC, интерактивов, триггеров, лута и порталов; визуальные пропсы интерактивов; связь с `QuestSystem` и `NightmareRunState`.
- `scripts/quests/quest_system.gd` — загрузка двух каталогов (`forgotten_shore` + `academy`) и фильтрация по активному scope без изменения поведения M1.
- `tools/audit/build_academy_quests.gd` — генератор 24 квестов и 3 loot-пулов.
- `tools/audit/academy_gameplay_probe.gd` — headless-проверка каталога, лут-пулов и состава playable-сцен.
- `tools/audit/academy_interaction_probe.gd` — реальные `Interactable` / `QuestNpc` / `LootCache` / портал, дистанции и флаги.
- `tools/audit/academy_navigation_probe.gd` — проход игрока по маршруту, мост, ступени Sleeper Center, двери, прачечная и портал.
- `tools/audit/academy_walkthrough_probe.gd` — сквозное прохождение 12 основных и 12 побочных квестов через настоящие взаимодействия.
- `tools/audit/academy_gameplay_capture.gd` — rendered gameplay-кадры обеих playable-сцен.
- `tools/audit/academy_dialogue_capture.gd` — кадр диалога и открытых ворот для превью.
- `tools/audit/academy_capture.gd` — read-only рендер камер `Shots` и аудит мешей/материалов.

### 2.5. Документация

- `docs/design/academy_chapter_roadmap.md`
- `docs/design/academy_location_map.md`
- `docs/design/academy_main_quests.md`
- `docs/design/academy_side_quests.md`
- `docs/design/academy_campus_map.svg`
- этот отчёт.

---

## 3. Academy Grounds — состав

### 3.1. Маршрут и зоны

```text
A0 подход (асфальт, тротуары, КПП, машина, снег)
 └─ A1 ворота (ров, мост, красные створки, башни, турели, стена)
     └─ A2 плац (галерея, мемориал, флаги, указатели)
         ├─ A4 столовая (стеклянный павильон, тёплый свет)
         ├─ A5 додзё (тёмный объём, красные рёбра, эмблема)
         ├─ A6 академическое крыло (белый блок, библиотечное стекло)
         ├─ A7 медицинский корпус (белый блок, красный крест)
         └─ A3 Sleeper Center (белый монолит, вход-павильон, лобби)
```

### 3.2. Что читается в кадре

- Красные ворота — главный landmark, видны от подъезда и с плаца.
- Стена с башнями и турелями, ров и мост.
- Стеклянная галерея с тёплыми полосами ведёт от ворот к Sleeper Center.
- Sleeper Center — белый монолит с горизонтальными окнами, вертикальными рёбрами, знаком и заглублённым лобби.
- Столовая — низкий стеклянный павильон с тёплым интерьером.
- Додзё — тёмный объём с красными рёбрами и круглой эмблемой.
- Академическое крыло — белый блок с библиотечным остеклением.
- Медицинский корпус — белый блок с красным крестом.
- Дальний город — силуэты башен с приглушёнными тёплыми окнами.
- Снег, сугробы, следы, фонари, болларды, кадки с геометрическими деревьями.

### 3.3. Свет и атмосфера

- Низкое холодное зимнее солнце, длинные тени.
- Процедурное небо, туман, SSAO/SSIL, glow, ACES.
- Тёплые практические источники в галерее, столовой, у входа; холодные — у Sleeper Center и медкорпуса; красные — у ворот и турелей.
- Снегопад из `m1_snow_drift.tscn` в нескольких зонах.

---

## 4. Sleeper Center — состав

### 4.1. Помещения

```text
вход/тамбур
 └─ дортуар (12 капсул, 4 ряда, доска статуса, шкафчики, лавки)
     ├─ общая комната (стол, кухня, автомат, софа, экран-окно)
     ├─ душевые (8 кабин, раковины, зеркала, лавки, шкафчики)
     ├─ наблюдательный пункт (стекло в дортуар, мониторы)
     │    └─ медицинский коридор
     │         ├─ галерея Hollow (16 кресел, простыни, мемориал)
     │         └─ палата погружения (3 койки, капсула, кольцо, мониторы)
     └─ жилой коридор (8 дверей, комната 07, прачечная)
```

### 4.2. Что читается

- Дортуар: симметрия капсул, центральный проход, холодный свет, доска статуса, шкафчики.
- Общая комната: тёплый свет, дерево, кухня, стол, софа, экран-окно.
- Душевые: кафель, кабины, раковины, зеркала, дренаж, лавки.
- Наблюдение: стол, мониторы, стеклянная стена в дортуар, холодный свет.
- Медкоридор: белый кафель, каталка, шкаф, двери.
- Hollow: ряды кресел с укрытыми телами, мемориальная стена, холодный свет.
- Палата: три койки, центральная капсула с кольцом и открытой рамой, мониторы, терминал, синий свет.
- Комната 07: койка, стол, стул, шкафчик, зеркало, экран-окно, полка, коврик.

---

## 4A. Игровой слой (playable wrappers)

### 4A.1. Что добавлено

- **Игрок и камера.** `sunny_waking_poc.tscn`, `SunnyController`, `ThirdPersonCamera`; на старте камера принудительно переключается с арт-камер на камеру игрока.
- **HUD.** `gameplay_hud.tscn`: здоровье, мини-карта, трекер задания, подсказки управления, быстрое снаряжение, субтитры.
- **Переходы.** `LevelPortal` grounds ↔ sleeper с `FadeLayer`, spawn-маркерами `FromGrounds` / `FromSleeper` и защитой от повторного срабатывания.
- **Красные ворота.** До разговора с охраной створки закрыты, а проём перекрыт коллайдером. После флага `academy_gate_passed` створки разворачиваются внутрь, коллайдер снимается, и игрок проходит в кампус.
- **NPC.** 18 на экстерьере и 5 в Sleeper Center. Это `QuestNpc` с `Interactable`, диалогом, флагом завершения и опциональными `required_flags`. Скрытые NPC появляются, когда флаг-предусловие выставлен.
- **Интерактивы.** 12 на экстерьере и 11 в интерьере: терминалы, доски, шкафчики, датчик, костёр, маркеры, панель ручного сброса. Визуалы — не голые цветные кубы: рамка, экран, эмиссия, подпись, у маркеров — маяк и подпись.
- **Лут.** 5 тайников на экстерьере и 6 в интерьере; три пула (`academy_locker_pool`, `academy_supply_pool`, `academy_medical_pool`), детерминированный ролл, флаг открытия и запись в `NightmareRunState`.
- **Квесты.** 24 ресурса: 12 основных (`AC-MQ-01…12`) и 12 побочных (`AC-SQ-01…12`), каталог `resources/quests/academy/quest_catalog_academy.tres`, отдельный scope `academy`. Основные квесты auto-start и идут по prerequisite-флагам; побочные запускаются NPC или интерактивом.
- **Локации не переписаны.** Арт-сцены не содержат игровых узлов; всё добавлено wrapper-слоем. M1-сцены не тронуты.

### 4A.2. Как запустить

Playable-сцены доступны из главного меню кнопкой **«Академия · ALPHA»** и напрямую; это отдельный сегмент, который не меняет M1-маршрут. Запуск напрямую:

```powershell
godot --path . res://scenes/locations/academy_playable/academy_grounds_playable.tscn
godot --path . res://scenes/locations/academy_playable/academy_sleeper_center_playable.tscn
```

В редакторе Godot: открыть сцену и нажать **F6** (Current Scene). Переход между экстерьером и Sleeper Center — через портал; отдельный запуск интерьера ставит игрока у стойки регистрации.

| Действие | Клавиша |
|---|---|
| Движение | `WASD` |
| Бег | `Shift` |
| Взаимодействие / диалог | `E` |
| Карта | `M` |
| Пропуск реплики | ЛКМ / `E` (по `advance_dialogue`) |

### 4A.3. Квестовый поток

- `QuestSystem` загружает оба каталога, но `get_active_quests()`, `get_completed_quests()`, `get_available_quests()`, `start_quest()` и журнал фильтруют по `active_scope`. Переключение scope не сбрасывает `forgotten_shore`.
- Точки «дойти до…» используют не одноразовый `REACH`, а `FLAG`-цель с флагом `academy_reached_*`. Триггер выставляет флаг один раз; если игрок уже был в этой зоне до старта квеста, цель при старте сразу считается выполненной. Это устраняет конфликт между one-shot триггерами и квестами, которые открываются позже.
- Награды — валюта, предметы и флаги; выдача идёт через существующий `QuestSystem`/`NightmareRunState`, без отдельного инвентаря.

### 4A.4. Коллизии и проходимость

- Мост у красных ворот получил две короткие рампы: 0,4 м ступенька блокировала `CharacterBody3D`.
- Центральная лестница Sleeper Center — наклонный коллайдер, боковые части платформы остаются твёрдыми.
- Прачечная получила настоящий дверной проём в западной стене (Blender + коллизия); без него два побочных квеста были недоступны.
- Добавлены торцевые стены коротких коннекторов дортуара и жилого коридора, чтобы игрок не выходил через щели между комнатами.
- Внутренние двери дортуара, общей комнаты, душевых, наблюдения, медкоридора, Hollow, палаты, комнаты 07 и прачечной проверены проходом игрока.

---

## 5. Пайплайн

1. **Blender base** — геометрия строится скриптами в фоновом Blender 5.1; один GLB на локацию.
2. **Godot art pass** — материалы по именам GLB, трипланарные PBR-текстуры, свет, туман, камеры, коллизии.
3. **Проверка** — headless import, script/resource audit, rendered captures.

Команды:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python assets\environments\academy\source\build_academy_grounds.py
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" -b --python assets\environments\academy\source\build_academy_sleeper_center.py
godot --headless --path . --import
godot --headless --path . -s tools\audit\build_academy_quests.gd
godot --headless --path . -s tools\audit\academy_gameplay_probe.gd
godot --headless --path . -s tools\audit\academy_interaction_probe.gd
godot --headless --path . -s tools\audit\academy_navigation_probe.gd
godot --headless --path . -s tools\audit\academy_walkthrough_probe.gd
godot --path . -s tools\audit\academy_capture.gd -- --scene=res://scenes/locations/academy/academy_grounds.tscn --out=<folder>
godot --path . -s tools\audit\academy_capture.gd -- --scene=res://scenes/locations/academy/academy_sleeper_center_building.tscn --out=<folder>
godot --path . -s tools\audit\academy_gameplay_capture.gd -- --scene=res://scenes/locations/academy_playable/academy_grounds_playable.tscn --out=<folder>
godot --path . -s tools\audit\academy_gameplay_capture.gd -- --scene=res://scenes/locations/academy_playable/academy_sleeper_center_playable.tscn --out=<folder>
```

---

## 6. Проверки

| Проверка | Команда | Результат |
|---|---|---|
| Скрипты | `qa_script_audit.gd` | **392 проверено, 0 failures** |
| Ресурсы | `qa_resource_audit.gd` | **762 проверено: 218 сцен, 544 ресурса, 0 failures** |
| Post-nightmare локации | `test_post_nightmare_locations.gd` | **16/16 passed, 518 asserts** |
| Сквозной маршрут | `test_full_route.gd` | **3/3 passed, 220 asserts** |
| Квесты (M1/Labyrinth) | `test_quest_system`, `test_quest_extensions`, `test_side_quests`, `test_labyrinth_quest_content` | **33/33 passed, 313 asserts** |
| Полный GUT | `addons/gut/gut_cmdln.gd -gdir=res://tests` | **723/723 passed, 7882 asserts** |
| Academy content | `academy_gameplay_probe.gd` | **24/24 квеста, 3 loot-пула, обе сцены загружаются, 0 failures** |
| Academy interactions | `academy_interaction_probe.gd` | **диалог, флаг, лут, скрытый NPC, ворота, портал и spawn — 0 failures** |
| Academy navigation | `academy_navigation_probe.gd` | **закрытые/открытые ворота, мост, ступени, додзё, академия, дортуар, медкорридор, Hollow, комната 07, прачечная, портал — 0 failures** |
| Academy walkthrough | `academy_walkthrough_probe.gd` | **12 основных + 12 побочных квестов завершены, 0 failures** |
| Headless import | `--headless --path . --import` | завершён; exit code 1 из-за выгрузки MCP-плагина, не из-за ассетов |
| Рендер-кадры | `academy_capture.gd`, `academy_gameplay_capture.gd` | арт-кадры + игровые кадры обеих playable-сцен |
| Ручной проход мышью/геймпадом | — | **NOT TESTED** |
| 1080p/60 FPS | — | **NOT TESTED** |

### 6.1. Статистика геометрии

| Локация | MeshInstance3D / objects | Полигоны (Blender) | Материалы |
|---|---:|---:|---|
| Academy Grounds | 1675 | 76 194 | 21 исходный + PBR-оверрайды |
| Sleeper Center | 1390 | 70 032 | 21 исходный + PBR-оверрайды |

Это геометрия **в кадре** при съёмке, не полный бюджет сцены; LOD/occlusion не внедрены.

---

## 7. Известные ограничения

1. **Ручной проход мышью/геймпадом не выполнен** — проверки идут через headless-симуляцию ввода и реальные `Interactable`/`QuestNpc`/портал; живой манипулятор, захват мыши и геймпад **NOT TESTED**.
2. **1080p/60 FPS не замерен** — 1675 и 1390 объектов могут быть тяжёлыми; нужен merge/LOD/occlusion и профилирование.
3. **Финальный art pass не сделан** — Hollow, комната 07, общая комната, лобби Sleeper Center, дальний план и лица NPC остаются greybox/placeholder.
4. **Интерьеры столовой, додзё, академического крыла и медкорпуса не смоделированы** — их NPC и интерактивы стоят у фасадов. Это осознанное упрощение текущего этапа.
5. **Звук не подключён** — в playable-сценах нет шагов, вентиляции, гула Hollow и капсул; музыка/эмбиент M1 переиспользуются только на уровне вызова.
6. **Текстуры** — используются существующие CC0-текстуры проекта; новые не скачивались.
7. **Hyper3D не использовался** — архитектура и hard-surface пропсы сделаны процедурно в Blender.
8. **Git LFS в рабочем дереве нестабилен** — `git status` падает на clean-фильтре `.glb`; это не влияет на импорт Godot, но коммит требует отдельной проверки LFS.
9. **`docs/DECISIONS.md` не изменялся** — файл содержит повреждённые участки кодировки; решения этого этапа записаны в разделе 10 ниже.

---

## 8. Следующие шаги

1. Живой ручной проход: мышь, геймпад, захват курсора, субтитры, все 24 квеста без телепортации в тесте.
2. LOD/merge/occlusion, замер 1080p/60 FPS и профилирование draw calls.
3. Финальный art pass: Hollow, комната 07, общая комната, лобби, дальний план, лица/одежда NPC.
4. Достроить интерьеры столовой, додзё, академического крыла и медкорпуса или перенести их NPC внутрь.
5. Аудио: вентиляция, шаги, гул галереи, Hollow, капсулы, музыкальные переходы.
6. Подключение к M2-full: следующие главы, сохранения прогресса между сессиями, проверка `SaveSystem` с academy-флагами.
7. Починить кодировку `docs/DECISIONS.md` и перенести туда решения из раздела 10.

---

## 9. Превью

### Арт-локации

- `docs/art/previews/academy/academy_grounds_overview.png`
- `docs/art/previews/academy/academy_gate.png`
- `docs/art/previews/academy/academy_axis.png`
- `docs/art/previews/academy/academy_sleeper_entrance.png`
- `docs/art/previews/academy/academy_dojo.png`
- `docs/art/previews/academy/academy_sleeper_dorm.png`
- `docs/art/previews/academy/academy_sleeper_dream.png`
- `docs/art/previews/academy/academy_sleeper_hollow.png`

### Игровой слой

- `docs/art/previews/academy/gameplay/academy_gameplay_gate_guard.png`
- `docs/art/previews/academy/gameplay/academy_gameplay_dialogue.png`
- `docs/art/previews/academy/gameplay/academy_gameplay_gate_open.png`
- `docs/art/previews/academy/gameplay/academy_gameplay_gallery.png`
- `docs/art/previews/academy/gameplay/academy_gameplay_dojo.png`
- `docs/art/previews/academy/gameplay/academy_gameplay_academic.png`
- `docs/art/previews/academy/gameplay/academy_gameplay_sleeper_entry.png`
- `docs/art/previews/academy/gameplay/academy_gameplay_sleeper_dorm.png`
- `docs/art/previews/academy/gameplay/academy_gameplay_medical.png`
- `docs/art/previews/academy/gameplay/academy_gameplay_room07.png`
- `docs/art/previews/academy/gameplay/academy_gameplay_laundry.png`

---

## 10. Decision log

1. **Две отдельные арт-сцены, два playable wrapper'а.** Экстерьер и интерьер — разные локации с разным светом, масштабом и производительностью. Игровой слой вынесен в `academy_*_playable.tscn`, чтобы арт-сцены оставались переиспользуемыми.
2. **Существующие gameplay-сцены не изменялись.** `academy_approach.tscn`, `academy_gate.tscn`, `academy_campus.tscn`, `academy_sleeper_center.tscn` остаются как есть. M1-маршрут не затронут; вход в сегмент добавлен отдельной кнопкой главного меню.
3. **Blender — основной инструмент.** Архитектура и hard-surface пропсы построены процедурно; Hyper3D не использовался, потому что генератор не даёт лучшего контроля для модульных стен, капсул и мебели.
4. **Материалы — runtime-фабрика.** `academy_materials.gd` собирает PBR-материалы по именам GLB и применяет их к мешам. Это позволяет переиспользовать существующие CC0-текстуры и не плодить `.tres` для каждого варианта.
5. **Коллизии — простые боксы + рампы.** Пол, стены, капсулы и крупная мебель получили box-коллайдеры; ступени моста и Sleeper Center — наклонные коллайдеры, потому что `CharacterBody3D` не умеет автоматически шагать на 0.4–1.4 м.
6. **`docs/DECISIONS.md` не изменялся.** Файл в текущем дереве читается как повреждённый/двояко закодированный; правка могла бы ухудшить его. Этот раздел — временная запись решений; при починке кодировки её нужно перенести в `docs/DECISIONS.md`.
7. **Игровой контент — data-driven.** `AcademyGameplayDirector` создаёт NPC, интерактивы, триггеры, лут и порталы из массивов данных, а не из сотни ручных узлов `.tscn`. Арт-сцены не знают о квестах.
8. **Academy — отдельный scope.** `QuestSystem` загружает второй каталог и фильтрует журнал/старт/завершение по `active_scope`. Существующий `forgotten_shore` не сбрасывается и не смешивается с academy-квестами.
9. **Точки «дойти» — FLAG, не one-shot REACH.** Триггер выставляет `academy_reached_*`; квестовая цель читает этот флаг и при старте сразу учитывает уже посещённую зону. Это важно, потому что игрок может попасть в дортуар, Hollow или медкорридор до открытия соответствующего квеста.
10. **Лут — существующие пулы и флаги.** Используются `LootCache`/`LootPool`, а не отдельный инвентарь. Открытие хранится в `NightmareRunState`, поэтому перезагрузка не даёт фармить тот же тайник.
11. **Визуалы интерактивов — процедурные пропсы.** Вместо цветных кубов — рамки, экраны, эмиссия, стойки и подписи. Это ещё не финальный art pass, но объекты читаются в кадре и не выглядят отладочными.
12. **Прачечная — исключение из «закрытых комнат».** Два побочных квеста требуют вентиляцию и корзину внутри; поэтому в западной стене сделан настоящий проём, а не только декоративная дверь.

---

## 11. Итог

Сделаны **две цельные арт-локации и два playable-сегмента**: экстерьер Академии с воротами, стеной, плацем, галереей и четырьмя зданиями; интерьер Sleeper Center с дортуаром, общей комнатой, душевыми, наблюдением, Hollow и палатой погружения. Игровой слой добавляет игрока, HUD, портал, 23 NPC, 23 интерактивных пропса, 11 тайников и 24 квеста (12 основных + 12 побочных). Сквозной headless-walkthrough проходит все 24 квеста через настоящие взаимодействия; навигационный probe подтверждает, что мост, ступени Sleeper Center, двери и прачечная проходимы. Осталось: живой ручной проход, 1080p/60 FPS, финальный art pass и звук.
