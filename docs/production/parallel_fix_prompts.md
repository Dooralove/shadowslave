# Промты для параллельного ремонта показа

База: `demo/stage5` @ `c903772`, Godot 4.7.2, проект `C:\Users\user\Desktop\shadowslave`.
Каждый агент работает в **своём worktree/ветке** `fix/<stream>` и не коммитит в `demo/stage5`.
Общие правила вставлены в каждый промт. Перед стартом все агенты читают
`AGENTS.md`, `docs/production/show_repair_plan.md`, `docs/production/remaining_show_issues.md`.

## Матрица владения файлами (чтобы не конфликтовать)

| Поток | Владеет | Не трогает |
|---|---|---|
| A. Пролог-локации | `scenes/slice/locations/park/*`, `park_street*`, `station_lobby*`, `containment_room*`, `scenes/slice/locations/p2_*` | `scripts/slice/slice_director.gd`, `project.godot` |
| B. Текст/шрифты | все `.tscn/.tres/.gd/.json` **только** строки/шрифты, `assets/fonts/**`, `resources/theme/**` | сцены/геометрию |
| C. Игрок | `scenes/characters/*`, `assets/characters/p1/sunny_*`, `scripts/player/*`, `project.godot` (input) | `scripts/slice/locations/*` |
| D. Лагерь | `scenes/locations/caravan_site/*`, `scripts/slice/locations/caravan_site.gd`, `scenes/campaign/caravan_site_arrival*`, `scripts/campaign/caravan_site_arrival.gd`, `scenes/slice/locations/caravan_road*` | `scripts/guide/*`, `scripts/quests/*` |
| E. Цели/карта | `scripts/guide/campaign_guide.gd`, `scripts/quests/quest_system.gd`, `resources/map/**`, `scripts/map/**`, `scripts/ui/hud_minimap*` | `caravan_site.gd`, `pilgrim_path.gd` |
| F. Подъём/пещера | `scenes/locations/pilgrim_path/*`, `scripts/slice/locations/pilgrim_path.gd`, `scripts/campaign/pilgrim_path_arrival.gd`, `scripts/stealth/**` | `scripts/guide/*`, `scripts/quests/*` |
| G. Постановка NPC | `scripts/slice/mannequin.gd`, `scripts/cutscene/**`, `scenes/campaign/*` (камеры/позы), позы в `caravan_site.gd`/`pilgrim_path.gd` — **только через отдельный коммит после D/F** | геометрию локаций |
| H. Координатор | merge, full GUT, туры, экспорт, docs | код потоков |

---

## Общий преамбул (вставить в начало каждого промта)

```text
Ты работаешь в проекте ShadowSlave (Godot 4.7.2, GDScript, Windows).
Корень: C:\Users\user\Desktop\shadowslave. Базовая ветка: demo/stage5 @ c903772.
Создай отдельный worktree/ветку fix/<stream> и работай только в ней.
Не коммить в demo/stage5, не делай force push, не удаляй сцены/ассеты без замены.
Не трогай файлы других потоков (см. матрицу владения в docs/production/parallel_fix_prompts.md).
Перед изменениями прочитай AGENTS.md, docs/production/show_repair_plan.md,
docs/production/remaining_show_issues.md и профильные docs/design|art.
Проверяй каждый шаг:
  godot --headless --path . --quit
  godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=<test> -gexit
  godot --path . res://tools/audit/qa_campaign_tour.tscn -- --out=$env:TEMP\opencode\tour
  godot --path . res://tools/audit/scene_shot.gd -- --scene=<scene> --out=<png> --pos=x,y,z --look=x,y,z --fov=70
Не пиши «исправлено», если не запускал проверку и не смотрел скриншот.
В конце: список изменённых файлов, команды проверки, результаты, скриншоты, commit hash.
```

---

## A. Пролог: парк, полицейский участок, комната содержания

```text
[вставить общий преамбул]
Поток A: закрыть «пустоту» в прологе.
Проблемы: (1) на месте парка пустота, зданий не видно; (2) полицейский участок —
пустая коробка без интерьера; комната содержания — пустая.

Сделай:
1. Парк (scenes/slice/locations/park/park_street_art.tscn, p2_park_set.tscn,
   park_street.tscn): земля/дорога/тротуар, фасады со всех сторон, откуда игрок
   может смотреть; убрать чёрные провалы; добавить уличные фонари и силуэт города.
   Переиспользуй существующие ассеты assets/environments/prologue/** и
   scenes/slice/locations/park/*; не создавай новые текстуры без нужды.
2. Полицейский участок (station_lobby_art.tscn): стойка, терминал, плакаты/плиты,
   потолочные лампы, пол с материалом; допросная — стол, стулья, стекло, лампа.
3. Комната содержания (containment_room_art.tscn): кресло с ремнями, смотровое
   окно, панели стен, свет; никакой пустой коробки.
Критерии: на кадрах qa_prologue_tour B01_park, B07_lobby, B08_desk нет пустых
чёрных зон там, где должны быть стены/пол/здания; видны здания из парка.
Проверки: test_prologue_art, test_park_art, test_slice_director; 3 скриншота.
```

## B. Текст и шрифты

```text
[вставить общий преамбул]
Поток B: кодировка и читаемость текста.
Проблема: в игре встречаются «кракозябры»/вопросительные знаки вместо русского.

Сделай:
1. Прогони по всем .tscn/.tres/.gd/.json поиск double-encoded UTF-8
   (последовательности «РџСЂ…», «Ð…», «Ñ…», U+FFFD) и исправь найденное.
2. Проверь шрифты UI/диалогов/подсказок: все веса должны иметь кириллицу.
   Добавь fallback-шрифт, если глифов нет.
3. Проверь resources/dialogue/**, resources/spell/**, подсказки InteractionPrompt
   и Label3D: русский текст должен отображаться, а не «????».
Критерии: скрипт-сканер возвращает 0 совпадений; на кадрах B01/B07/B15 и в
диалоге каравана нет «????» и «Ð».
Проверки: test_dialogue*, test_ui*, test_caravan_site; 2 скриншота.
```

## C. Игрок: модель, прыжок, удары

```text
[вставить общий преамбул]
Поток C: игрок.
Проблемы: (3) в игре тестовая модель вместо персонажа; (9) удары нельзя
прожимать вне боя; (16) нет прыжка.

Сделай:
1. Найди все сцены игрока (scenes/characters/*, assets/characters/p1/sunny_*).
   В прологе и кампании должна быть одна и та же боевая модель Sunny, не chibi
   и не mannequin. Проверь campaign_entry.tscn, pilgrim_path_arrival.tscn,
   caravan_site_arrival.tscn, sanctuary_arrival.tscn.
2. Прыжок: action "jump" в project.godot, controller разрешает его в прологе и
   кампании, есть анимация, нет блокировки combat_enabled.
3. Удары: action "attack" работает вне боя; анимация и хитбокс не ломают
   управление; удар не требует combat_enabled.
Критерии: скриншоты модели спереди/сбоку; скрипт-тест на jump/attack в
campaign_entry; никакой тестовой модели в кадре.
Проверки: test_sunny_poc, test_player_controller, test_campaign_flow; GUT.
```

## D. Лагерь: Горный король, камера повозки, плавающие объекты, ветеран

```text
[вставить общий преамбул]
Поток D: лагерь каравана.
Проблемы: (5) Горный король висит; (6) камера ломается при столкновении повозки;
(7) дерево в воздухе; (8) следы в воздухе; (10) ветеран должен лежать при смерти;
(12) камни летают; (15) маркер в воздухе; (19) выход за границы/затекстурье.

Сделай:
1. Горный король: ступни на уступе. Проверь raycast от Тирана вниз; верх
   TyrantLedge должен быть в пределах 0.1 м от ступней.
2. Камера повозки (caravan_site_arrival.tscn WagonCamera): вынести из кузова,
   проверить кадр при столкновении; никакого клиппинга/переворота.
3. Дерево, следы, камни, маркеры: ни один объект не должен висеть >0.15 м над
   полом. Используй tools/audit/floating_objects.gd и raycast-пробы.
4. Ветеран: поза «лежит при смерти» у тёмного края, лицом к игроку, не в стену.
   Герой — на колене. Шифти/Учёный — по beat sheet.
5. Границы: закрыть дыры, убрать проход в затекстурье.
Критерии: 3 кадра лагеря; probe-скрипт печатает зазоры <0.15; test_caravan_site,
test_location_art_decor.
```

## E. Цели и миникарта

```text
[вставить общий преамбул]
Поток E: задания и карта.
Проблемы: (13) цель «собрать фляги» висит, когда фляги уже собраны;
(14) миникарта нужна для всех локаций.

Сделай:
1. Приоритет целей: внешняя цель сцены (CampaignGuide.set_external_objective)
   должна перекрывать базовую цель QuestSystem. После 3 фляг — «подойти к
   ветерану»; после ветерана — «вернуться к повозке»; после боя/пещеры — своя.
   Убери «собрать фляги», когда собрано 3/3.
2. Миникарта: составь список всех играбельных сцен (пролог, лагерь, дорога,
   подъём, святилище, M1, Академия, tech, лабиринт). Для каждой — MapDefinition
   в resources/map/locations/ + запись в map_atlas.tres, либо общий fallback.
   HudMinimap не должен скрываться в играбельной локации.
Критерии: скрипт обходит список сцен и проверяет карту; test_map_system,
test_campaign_flow; кадр HUD в 3 локациях.
```

## F. Подъём и пещера

```text
[вставить общий преамбул]
Поток F: pilgrim_path.
Проблемы: (17) на подъёме проходим только очень узкий участок; (19) камни в
воздухе, можно выйти за границы, видно затекстурье; (20) задача «выжить»:
врагов нет, в пещеру не зайти.

Сделай:
1. Расширить проходимую полосу карниза до >=2.2 м, убрать невидимые щели,
   добавить/поправить рельсы, чтобы нельзя было упасть в щель.
2. Убрать плавающие камни/декали; закрыть границы; проверить, что нет
   затекстурных зон (камера не видит пустоту за геометрией).
3. Пещера: сделать реально входимое пространство (арт-ассет ущелья + проход,
   либо аккуратная скальная оболочка), внутри — враги/событие «выжить»,
   понятная цель. Игрок должен войти, увидеть угрозу, пережить и выйти.
Критерии: route_probe — пол под всеми точками; boundary-проба — 0 утечек;
живой кадр входа в пещеру, врагов и выхода; test_pilgrim_path.
```

## G. Визуальная постановка NPC

```text
[вставить общий преамбул]
Поток G: показать действия, а не только написать.
Проблемы: (11) действия NPC проговариваются только текстом; (18) всё описывается
текстом, игрок должен видеть это глазами.

Сделай:
1. Добавь позы/жесты в Mannequin (scripts/slice/mannequin.gd): «лежит при
   смерти», «на колене», «читает», «указывает», «падает». Применяй их в
   caravan_site.gd и pilgrim_path.gd в ключевых beat (ветеран, герой, учёный,
   шифти), но не меняй геометрию локаций.
2. Для 6 ключевых beat добавь камеру/мизансцену через CutsceneDirector или
   существующие shots: нападение, смерть ветерана, рана в пещере, захват героя.
3. Убери T-pose и «смотрит в стену»: актёр должен быть повёрнут к игроку/событию.
Критерии: 6 скриншотов ключевых beat, на каждом видно действие; test_caravan_site,
test_cutscene_integration, test_pilgrim_path.
```

## H. Координатор (для меня/главного агента)

```text
Ты координатор ремонта показа ShadowSlave. База: demo/stage5 @ c903772.
1. Собери ветки fix/A..fix/G, реши конфликты по матрице владения.
2. После каждого merge: godot --headless --path . --quit; профильный тест.
3. Финальный прогон: full GUT, qa_campaign_tour, qa_prologue_tour,
   qa_stage5_portal_chain, qa_stage5_scenario_chain, qa_stage5_menu_m1,
   qa_stage5_ui_tour.
4. Пересобери экспорт: powershell -File tools/build/export_windows.ps1
   (скрипт сам пересобирает кэш классов и делает boot-тест).
5. Обнови docs/production/remaining_show_issues.md и show_repair_plan.md.
6. Запушь в origin/demo/stage5 без force. Не утверждай «готово», пока не
   пройдены ручной проход и замеры 1080p/60.
```

---

## Порядок запуска и merge

1. Параллельно: **A, B, C, D, E, F** (разные файлы).
2. После D и F: **G** (позы/камеры), потому что он трогает те же `.gd`-файлы.
3. **H** — после всех.

## Быстрые проверки для любого агента

```powershell
godot --headless --path . --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_caravan_site.gd -gexit
godot --path . res://tools/audit/qa_prologue_tour.tscn -- --out=$env:TEMP\opencode\prologue
godot --path . res://tools/audit/qa_campaign_tour.tscn -- --out=$env:TEMP\opencode\tour
godot --headless --path . -s tools/audit/route_probe.gd
godot --path . -s tools/audit/scene_shot.gd -- --scene=res://scenes/locations/caravan_site/caravan_site_art.tscn --out=$env:TEMP\opencode\camp.png --pos=8,5,8 --look=0,1,0 --fov=60
```
