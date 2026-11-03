# Межсценовые переходы и точки входа

Дата: 2026-10-26, обновлено 2026-11-01  
Статус: **компонент и контракт реализованы; цепочка после Первого Кошмара подключена; headless-тесты зелёные; полный ручной графический проход NOT TESTED.**

Документ описывает техническую основу переходов между сценами. Он не меняет
art-сцены, `.blend`, GLB, материалы и не задаёт композицию локаций.

## 1. Что уже было и что добавлено

В проекте уже есть несколько разных механизмов, и они не дублируют друг друга:

| Механизм | Ответственность |
|---|---|
| `SliceDirector` + `SliceLocation` | Локальные переключения локаций внутри пролога, `Spawns/<name>`, `play_cutscene()`, `FadeLayer`. |
| Оболочки `scenes/campaign/*_arrival.tscn` | Сюжетный маршрут кампании, диалоги, флаги и переход к следующей сцене. |
| `FadeLayer` | Затемнение; не знает, куда и зачем идёт переход. |
| `TriggerZone`, `Interactable` | События «игрок вошёл» / «игрок нажал E»; не загружают сцены. |
| `NightmareRunState` | Только сюжетные флаги и предметы, переживающие смену сцены. |
| `LevelPortal` | Новый переиспользуемый узел для одной двери/прохода/лестницы/выхода. |

`LevelPortal` — не второй менеджер уровней и не autoload. Это компонент,
который превращает одно событие прохождения в один запрос смены сцены,
переиспользуя существующие `FadeLayer`, `Interactable` и `play_cutscene()`.
Маршрут кампании по-прежнему принадлежит оболочкам, а локальная режиссура
пролога — `SliceDirector`.

## 2. Контракт `LevelPortal`

Файл: `scripts/world/level_portal.gd`, `class_name LevelPortal`, `extends Area3D`.

### Основные свойства

| Свойство | Назначение |
|---|---|
| `destination_scene: String` | Путь к `.tscn` назначения. Проверяется через `ResourceLoader.exists()`. |
| `destination_spawn: StringName` | Имя маркера `Spawns/<name>` в сцене назначения. Может быть пустым, если оболочка сама знает вход по умолчанию. |
| `transition_style: Style` | `FADE` — только затемнение; `CUTSCENE` — сначала `play_cutscene()`, затем затемнение. |
| `cutscene_id: StringName` | id постановки для `CUTSCENE`; пустой id означает обычный fade. |
| `fade_out_duration: float` | Длительность затемнения перед загрузкой. |
| `fade_layer: FadeLayer` | Явный слой затемнения. Если не задан, ищется первый `FadeLayer` в текущей сцене. |
| `enabled: bool` | Выключатель портала. |
| `trigger_on_body: bool` | Срабатывать при входе в `Area3D`. |
| `body_trigger_ignore_frames: int` | Сколько первых физических кадров после загрузки игнорировать вход. По умолчанию 10; защищает от зацикливания, если spawn оказался внутри триггера. |
| `trigger_mask: int` | Маска `Area3D`; по умолчанию 2 — слой Санни. |
| `interactable: Interactable` | Необязательная дверь с нажатием E; портал сам подключается к `interacted`. |
| `lock_player: bool` | Блокировать ввод на время затемнения и загрузки. |
| `one_shot: bool` | Не разрешать повторное срабатывание в пределах жизни узла. |
| `one_shot_flag: StringName` | Флаг, который переживает перезагрузку сцены и закрывает портал. |
| `required_flags: Array[StringName]` | Портал доступен только при всех флагах. |
| `set_flags_on_use: Array[StringName]` | Флаги, которые выставляются после успешного запроса смены сцены. |

### События

- `transition_started(destination_scene, destination_spawn)` — портал прошёл
  проверки и начал постановку/затемнение.
- `transition_finished(destination_scene, destination_spawn)` — смена сцены
  запрошена у `SceneTree`; новая сцена загрузится в конце кадра.
- `transition_aborted(reason)` — переход отменён; ввод игрока восстановлен.

### Обязательные условия

1. У портала должен быть `FadeLayer`. Без него переход запрещён, чтобы не
   превращаться в необъяснимый телепорт. Причина пишется в лог, ввод
   возвращается, сигнал `transition_aborted` отправляется.
2. `destination_scene` должен существовать. Иначе переход не начинается.
3. Для `CUTSCENE` у родителя должен быть метод `play_cutscene()`; иначе
   переход отменяется. Обычно это `SliceLocation` пролога.
4. При `trigger_on_body = true` нужен дочерний `CollisionShape3D`. Портал не
   создаёт форму автоматически: размер и посадка двери/лестницы — решение
   сборщика локации.
5. Портал ставится на проходимой стороне двери/прохода. Игрок сам входит в
   зону или нажимает E; портал не перемещает его внутри текущей сцены.
6. Одновременно активен только один `LevelPortal`: статическая блокировка не
   даёт двум разным порталам запросить две сцены в одном кадре. Ссылка слабая,
   поэтому после загрузки старого портала блокировка снимается автоматически.
   `LevelPortal.clear_active_transition()` нужен только тестам и нестандартным
   загрузчикам, которые не освобождают старый портал.
7. Физический вход в первые `body_trigger_ignore_frames` кадров после загрузки
   сцены игнорируется. Если игрок появился прямо внутри прохода, он не будет
   отправлен обратно тем же переходом; после выхода и повторного входа портал
   снова доступен. Для намеренного мгновенного срабатывания задайте `0` или
   вызовите `activate()` из сценария.

## 3. Контракт точек появления

Точка входа — существующий `Marker3D` с именем `Spawns/<name>` у локации.
Никаких новых координат в коде оболочки быть не должно.

Порядок передачи:

1. Портал вызывает `LevelPortal.set_pending_spawn(destination_scene, spawn)`.
2. `SceneTree.change_scene_to_file()` загружает назначение.
3. Оболочка назначения в своём `_ready()` вызывает:
   ```gdscript
   var requested := LevelPortal.take_pending_spawn(SCENE_PATH)
   var spawn := LevelPortal.resolve_spawn(_location, requested, DEFAULT_SPAWN)
   ```
4. `take_pending_spawn()` читает запрос только для своей сцены и сразу его
   очищает. Чужая сцена запрос не забирает.
5. `resolve_spawn()` ищет `Spawns/<name>`. Если запрошенной точки нет, он
   использует `fallback` и пишет предупреждение; игрок не остаётся в
   случайной позиции.

Запрос хранится в статическом поле `LevelPortal`, потому что
`change_scene_to_file()` не принимает параметры. Это не сюжетное состояние:
`NightmareRunState` по-прежнему хранит только флаги и предметы. Начало новой
кампании очищает возможный устаревший запрос через
`LevelPortal.clear_pending_spawn()` и снимает глобальную блокировку перехода.

## 4. Как собрать переход

### Дверь с нажатием E

1. Добавить `LevelPortal` в игровую/оболочечную сцену, не в art-сцену.
2. Добавить дочерний `CollisionShape3D` и настроить его под дверной проём.
3. Указать `destination_scene` и `destination_spawn`.
4. Выключить `trigger_on_body`.
5. Назначить существующий `Interactable` в `interactable`. Портал подпишется
   на его `interacted`; отдельный менеджер не нужен.
6. Включать `Interactable.enabled` сценарием в нужный момент.

### Проход, лестница, выход

1. Добавить `LevelPortal` с `CollisionShape3D` в проходимой точке.
2. Оставить `trigger_on_body = true`.
3. Указать `destination_scene` и `destination_spawn`.
4. Для необратимого выхода включить `one_shot` и, если нужно пережить
   перезагрузку, задать `one_shot_flag`.

### Постановочный переход

1. Поставить портал у точки, где заканчивается постановка.
2. Выбрать `transition_style = CUTSCENE`.
3. Задать `cutscene_id`, который реально существует у родительской
   `SliceLocation`.
4. Если постановка уже проигрывается оболочкой кампании, оставить `FADE` и
   вызвать `activate()` после неё; портал не должен запускать вторую сцену.

## 5. Текущая интеграция маршрута

| Сцена | Вход по умолчанию | Что передаёт дальше |
|---|---|---|
| `campaign_entry` | пролог внутри | очищает старый запрос; в `first_nightmare_pass` передаёт `Chain`. |
| `first_nightmare_pass` | `Chain` | в `caravan_site_arrival` передаёт `Chain`. |
| `caravan_site_arrival` | `Chain` | в `pilgrim_path_arrival` передаёт `Start`. |
| `pilgrim_path_arrival` | `Start` | в `sanctuary_arrival` передаёт `SanctuaryEntrance`. |
| `sanctuary_arrival` | `SanctuaryEntrance` | в оценку перехода с точкой входа нет. |

`sanctuary_arrival` теперь явно применяет
`Sanctuary/Spawns/SanctuaryEntrance`, а не полагается на стартовую
позицию Санни, зашитую в `shadow_sanctuary.tscn` (z = 6.2 при маркере z = 7.0).

Старая песочница `caravan_ambush` пока ведёт в святилище по умолчанию; при
необходимости другой точки входа её можно перевести на тот же контракт без
изменения art-сцен.

## 6. Проверки

Целевой набор:

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_level_transition.gd -gexit
```

Фактический результат: `20/20` тестов, `76` assert'ов, все прошли.
Тест безопасного fallback намеренно запрашивает несуществующий spawn, поэтому
в логе GUT есть ожидаемое предупреждение `using 'Chain'`; это не падение.

Регрессионные наборы маршрута (`test_campaign_flow`, `test_full_route`,
`test_slice_director`, `test_pilgrim_path`, `test_camp_exit_geometry`,
`test_shadow_sanctuary`, `test_appraisal_and_finale`): `52/52` теста,
`669` assert'ов, все прошли.

Совместный прогон нового и регрессионных наборов: `72/72` теста,
`745` assert'ов, все прошли.

Что покрыто:

- однократность перехода и защита от повторного `activate()`;
- глобальная защита: два разных портала не могут запросить две сцены;
- блокировка и восстановление ввода при отмене;
- запрет перехода без `FadeLayer`;
- `required_flags`, `one_shot_flag`, `set_flags_on_use`;
- порядок «постановка → запрос сцены»;
- дверь через `Interactable` и физический вход в `Area3D`;
- защита от зацикливания, если player spawn оказался внутри триггера;
- адресность и очистка pending spawn;
- применение `SanctuaryEntrance`;
- произвольная точка входа в `pilgrim_path_arrival` и `caravan_site_arrival`;
- безопасный fallback на `Chain` при неизвестном spawn;
- отсутствие дублей переходов у храма, рассвета и святилища;
- очистка устаревшего spawn при старте кампании.

## 7. Ограничения и что осталось

- В прологовые art-сцены портал пока не добавлен: это работа сборки локаций,
  а не технической основы. В сценах после Первого Кошмара порталы уже стоят в
  `.tscn`; art-геометрию и материалы ради портала менять не нужно.
- Тесты не вызывают настоящий `change_scene_to_file()`: `RecordingPortal`
  переопределяет `_commit_scene_change()`. Полный ручной графический проход
  NOT TESTED.
- Для `CUTSCENE` нужен реальный `play_cutscene()` у родителя. Базовая
  `SliceLocation` при неизвестном id пишет warning и возвращает управление;
  портал после этого всё равно завершит переход затемнением. id нужно
  проверять при сборке постановки.
- Если сцена назначения не вызывает `take_pending_spawn()`, запрос останется
  до следующего перехода или до старта кампании. Новые оболочки с точками
  входа обязаны читать контракт в `_ready()`.
- Портал не создаёт `CollisionShape3D` автоматически; без формы сработает
  только ручной `activate()` или `Interactable`.
- Блокировка ввода рассчитана на `SunnyController` (группа `player`,
  `input_enabled`, `forced_velocity`). Для другого контроллера нужно расширить
  `_resolve_player()` и `_lock_player()` в `LevelPortal`.

## 8. Цепочка после Первого Кошмара (2026-11-01)

Маршрут из восьми сцен:

`police_precinct` → `academy_approach` → `academy_gate` → `academy_campus`
→ `academy_sleeper_center` → `black_sea_platform` → `tide_descent`
→ `coral_labyrinth`.

Три связующие сцены — `academy_approach`, `academy_campus`, `tide_descent` —
остаются расширяемыми серыми прокладками, а не финальным арт-эталоном. Пять
основных локаций сохраняют авторские `Spawns`, `Shots`, `Markers`,
`WorldEnvironment`, `Player` и `UI/Fade`; порталы лежат в `.tscn` и не
генерируются строителем.

| Откуда | Портал | Куда | Spawn назначения |
|---|---|---|---|
| `police_precinct` | `ToAcademyApproach` | `academy_approach` | `FromPrecinct` |
| `academy_approach` | `ToPrecinct` | `police_precinct` | `FromApproach` |
| `academy_approach` | `ToAcademyGate` | `academy_gate` | `FromApproach` |
| `academy_gate` | `ToApproach` | `academy_approach` | `FromGate` |
| `academy_gate` | `ToCampus` | `academy_campus` | `FromGate` |
| `academy_campus` | `ToGate` | `academy_gate` | `FromCampus` |
| `academy_campus` | `ToSleeper` | `academy_sleeper_center` | `FromCampus` |
| `academy_sleeper_center` | `ToCampus` | `academy_campus` | `FromSleeper` |
| `academy_sleeper_center` | `ToBlackSea` | `black_sea_platform` | `FromSleeper` |
| `black_sea_platform` | `ToCoral` | `tide_descent` | `FromPlatform` |
| `tide_descent` | `ToPlatform` | `black_sea_platform` | `FromCoral` |
| `tide_descent` | `ToCoral` | `coral_labyrinth` | `FromPlatform` |
| `coral_labyrinth` | `ToPlatform` | `tide_descent` | `FromCoral` |

- **Темп.** Обычные проходы используют короткое затемнение: `0.22` с наружу
  и `0.28–0.3` с внутри. Переход из палаты снов в
  Чёрное море — сюжетный порог: `1.35` с наружу и `1.55` с внутри. `LevelPortal`
  предзагружает сцену назначения, а `FadeLayer` следующей сцены начинает кадр
  с чёрного, поэтому между сценами нет вспышки.
- **Направление взгляда.** `Marker3D` точки прибытия задаёт не только позицию,
  но и `rotation.y`; `SunnyController.apply_spawn_orientation()` ставит модель,
  а `ThirdPersonCamera.set_yaw()` — камеру. Поэтому игрок продолжает путь
  лицом вглубь локации, а не смотрит в только что пройденный проём.
- **Чёрное море.** `black_sea_platform` следует канону глав 30–32: круглая
  площадка около 12 м — срез шеи колоссальной статуи рыцаря; голова
  отсутствует, на нагруднике семь звёзд, меч опущен к земле, вокруг чёрная
  вода без луны и звёзд. Промышленный пирс, контейнеры, кран и турели удалены.
- **Спуск.** `tide_descent` — минимальный открытый спуск по рельефу статуи,
  без тоннеля под наплечником. Его дальнейшая художественная детализация
  вынесена за рамки этой задачи и не считается финальной.
- **Проверка.** `test_post_nightmare_locations.gd` — 7/7, 473 assert, exit 0;
  `test_level_transition.gd` — 22/22, 83 assert, exit 0. Полный GUT — 49
  скриптов, 397/397 тестов, 4910 assert, exit 0. Через Godot MCP проверены
  реальные переходы `black_sea_platform → tide_descent → coral_labyrinth` и
  `tide_descent → black_sea_platform` перемещением игрока в зону портала;
  игрок появился на ожидаемых маркерах.
  Полный ручной проход всей цепочки от участка до лабиринта и обратно —
  **NOT TESTED**.
