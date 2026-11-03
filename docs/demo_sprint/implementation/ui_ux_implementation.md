# UI/UX — Implementation Specification (Stage 2)

**Design Package:** DP-1.0  
**Дата:** 2026-11-03  
**Автор:** A08 — UI/UX  
**Базовая точка:** `0335a5c346901af2146413b5a159b442d326d8de`, ветка `s3-park-art`, dirty tree  
**Статус:** **спецификация; игровые файлы в Stage 2 не изменялись.** Реализация начинается только после фиксации Technical Director документов `MASTER_PLAN.md`, `FILE_OWNERSHIP.md` и `INTEGRATION_CONTRACTS.md`, а также после решения спорных пунктов из раздела 12.

> Этот документ — не второй дизайн UI и не разрешение править чужие файлы. Это план работ A08: что уже есть, что исправить, что создать, в каких файлах, с какими зависимостями и как доказать готовность. Все игровые изменения выполняются в отдельной ветке и только в зоне A08 либо по подтверждённому shared-file claim.

---

## 0. Краткое резюме для Technical Director

1. **Основная проблема UI сейчас — не отсутствие компонентов, а несколько источников истины для одной цели.** `ObjectiveLine` читает `resources/ui/post_nightmare_objectives.tres`, `GreyboxLocation` уже вызывает `CampaignGuide.set_external_objective`, а `QuestSystem` использует тот же `CampaignGuide` для Лабиринта. В результате HUD может показывать не ту строку, которая записана в `CampaignGuide`. Это нарушает `MASTER_PLAN` §8 и должно быть исправлено первым.
2. **HUD-сцена лежит в `scenes/quests/gameplay_hud.tscn`, то есть в зоне A04.** Скрипт — A08, композиция — A04. Нужно решение TD: carve-out этой одной сцены для A08 (рекомендуется) либо перемещение/разделение сцены. Без этого A08 не может гарантировать композицию HUD в своей ветке.
3. **Финальные карточки принадлежат A04 по файлам, но A08 по задаче.** Рекомендуется: A08 делает переиспользуемый `FinalCard` в `scenes/ui/**`, A04 встраивает его в `scenes/campaign/**`, A01 утверждает текст. Это сохраняет владение и не создаёт вторую финальную сцену.
4. **`QuestChoicePanel` пока отсутствует.** Нужен один UI-компонент с сигналом `choice_selected`, без вызовов `QuestSystem` и без второго диалогового движка. По `side_quests.md` §11.5 панель должна поддерживать до четырёх вариантов (три правды + заблокированная ложь), хотя `MASTER_PLAN.md` §8 и `AGENT_TASKS.md` говорят «2–3». Кроме того, в схеме `INTEGRATION_CONTRACTS.md` §14.2 нет полей `locked`/`lock_reason`, поэтому показ заблокированной лжи требует аддитивного расширения. Это спорные пункты D-UI-09 и D-UI-13.
5. **`MapScreen._build_marker_list()` передаёт `{}` вместо флагов**, поэтому условные маркеры в полноэкранной карте остаются в списке. Это точечная правка A08, зависимость — API A04.
6. **Журнал всё ещё имеет DEMO-fallback и демонстрационную панель.** Для M1 допустим только живой `QuestSystem`/`CampaignGuide`; DEMO-каталог должен перестать быть источником данных, а не просто быть подписан «DEMO».
7. **Масштаб противоречив:** `MASTER_AUDIT.md` указывает 1920×1080, текущий `project.godot` — 1600×900, а дизайн-документ A08 — 1600×900. Нужно решение TD; иначе проверка 4K/ultrawide будет проверять не тот baseline.
8. **Часть Stage 1 уже лежит в рабочем дереве, но пересекает чужие зоны.** Это `project.godot`, `scenes/locations/post_nightmare/**`, `scripts/locations/post_nightmare/**`, `scripts/locations/forgotten_shore_labyrinth/tide_controller.gd`, `resources/map/**`, `scripts/map/**`, `scripts/dialogue/dialogue_runner.gd`, `scenes/quests/gameplay_hud.tscn`, `scenes/campaign/post_nightmare_finale.*`, `scripts/campaign/post_nightmare_finale.*`, `tests/test_ui_demo.gd`. До принятия TD это **не** считается закрытой работой A08 и не должно молча переноситься в ветку.
9. **A08 не пишет тесты в `tests/**`.** Тесты принадлежат A10. A08 даёт acceptance matrix и test hooks; A10 реализует и запускает targeted/full GUT. Если TD хочет иначе — нужен явный carve-out.
10. **M1 — основной gate.** Tech demo и Первый Кошмар используют те же компоненты, но не должны добавлять второй HUD, второй журнал или второй autoload.

---

## 1. Входные документы и границы домена

### 1.1. Прочитано для спецификации

- `docs/demo_sprint/MASTER_AUDIT.md`
- `docs/demo_sprint/BACKLOG.md`
- `docs/demo_sprint/MASTER_PLAN.md`
- `docs/demo_sprint/FILE_OWNERSHIP.md`
- `docs/demo_sprint/implementation/INTEGRATION_CONTRACTS.md`
- `docs/demo_sprint/implementation/AGENT_TASKS.md`
- `docs/demo_sprint/design/side_quests.md`
- `docs/demo_sprint/design/world_layout.md`
- `docs/demo_sprint/design/poi_manifest.md`
- `docs/demo_sprint/design/ui_ux_design.md`
- `docs/demo_sprint/audits/ui_ux.md`
- текущий код UI, HUD, карты, журнала, паузы, диалогов и финальной сцены.

### 1.2. Что входит в A08

- `scenes/ui/**`
- `scripts/ui/**`
- `assets/ui/**`
- `resources/ui/**`
- `resources/rpg_menu/**`
- `resources/campaign/glossary/**`
- `docs/demo_sprint/design/ui_ux_design.md`
- `docs/demo_sprint/audits/ui_ux.md`

### 1.3. Что не входит в A08

- `project.godot`, autoload, display settings — A00.
- `scenes/locations/**`, `resources/map/locations/**`, `tools/map/**` — A03.
- `scripts/quests/**`, `resources/quests/**`, `scripts/map/**`, `resources/map/**` (кроме `locations/**`), `scripts/campaign/**`, `scenes/campaign/**`, `scripts/guide/**`, `scripts/dialogue/**` — A04.
- `resources/dialogue/**`, `data/dialogues/**` — A01.
- `resources/quests/sq_fs_*.tres`, тексты SQ — A02.
- `tests/**`, `tools/audit/**` — A10.
- `scripts/locations/post_nightmare/**`, включая `greybox_location.gd` — A03.
- `assets/audio/**`, `scripts/audio/**`, UI-звуковые cue — A09.

### 1.4. Критерий успеха домена

1. Один HUD на игровую сцену; один `ObjectiveLine`; один `QuestSystem`; один `CampaignGuide`; один `MapSystem`; один `SaveSystem`.
2. HUD показывает цель из канонического источника: `QuestSystem` в Лабиринте, `CampaignGuide` в M1/P05–B02 и Первом Кошмаре.
3. Нет второго журнала, инвентаря, диалогового движка, autoload или второй карты.
4. Все семь пост-Кошмарных сцен M1 и Лабиринт имеют читаемый HUD без перекрытий.
5. `QuestChoicePanel` выдаёт ровно один сигнал выбора, не пишет флаги сам и не конфликтует с паузой.
6. `MapScreen` и `RpgMapScreen` передают реальные флаги и не показывают скрытые маркеры.
7. Журнал показывает только живые данные; DEMO-fallback не является источником в игровом прохождении.
8. Финальная карточка M1 и tech demo различаются текстом и флагом; возврат в меню не зависает.
9. UI проверен на согласованном reference-разрешении и на 4K/ultrawide; всё непроверенное помечено **NOT TESTED**.
10. Изменения A08 можно собрать в отдельной ветке без постоянных правок A01/A03/A04/A10.

---

## 2. Исходное состояние и конкретные дефекты

### 2.1. Что уже существует в рабочем дереве

Stage 1 уже содержит прототип, который нужно либо принять как baseline, либо перенести в правильные зоны:

| Элемент | Файлы | Состояние |
|---|---|---|
| `GameplayHud` | `scripts/ui/gameplay_hud.gd`, `scenes/quests/gameplay_hud.tscn` | HUD собирает prompt, objective, subtitles, combat, toast, tide, world markers |
| `ObjectiveLine` | `scripts/ui/objective_line.gd`, `scenes/ui/objective_line.tscn` | Читает `QuestSystem`, затем UI-таблицу, затем `CampaignGuide` |
| `TideIndicator` | `scripts/ui/tide_indicator.gd`, `scenes/ui/tide_indicator.tscn` | Работает по `TideController`, виден только при наличии контроллера |
| `HudWorldMarkers` | `scripts/ui/hud_world_markers.gd`, `scenes/ui/hud_world_markers.tscn` | Маркеры интерактивных объектов и компас цели |
| `CombatHud` | `scripts/ui/combat_hud.gd`, `scenes/ui/combat_hud.tscn` | HP/выносливость, числа, вспышка урона, критическое состояние |
| `SubtitleUI` | `scripts/ui/subtitle_ui.gd` | Клик, счётчик реплик, `E / Space / Enter` |
| `PauseMenu` | `scripts/ui/pause_menu/**`, `scripts/ui/pause_menu_system.gd`, `scenes/ui/pause_menu/**` | Esc-пауза, настройки, управление, выход |
| `RpgQuestScreen` | `scripts/ui/rpg_menu/rpg_quest_screen.gd` | Живой журнал + DEMO-fallback |
| `RpgMapScreen` | `scripts/ui/rpg_menu/rpg_map_screen.gd` | Флаги, локальные карты, подсветка цели |
| `MapScreen` | `scripts/ui/map/map_screen.gd` | Флаги передаются в canvas, но не в список маркеров |
| `MainMenu` | `scripts/ui/main_menu/main_menu.gd` | «Играть», «После Кошмара», настройки, кредиты |
| `Finale` | `scenes/campaign/post_nightmare_finale.tscn`, `scripts/campaign/post_nightmare_finale.gd` | Финальная карточка tech demo, **зона A04** |

**Исторические доказательства Stage 1** (из журнала предыдущей сессии, в Stage 2 не перезапускались):

- `test_ui_demo` — 10/10;
- `test_post_nightmare_locations` — 15/15;
- полный GUT — исторически 636/636, 7333 assert, но повторный прогон после параллельных изменений ассетов — 616/636 из-за UID `mountain_king_v2.glb` / `white_horse_v2.glb`.

Это другой срез, чем 632/632 в `MASTER_AUDIT.md`; числа нельзя сравнивать без commit hash. Эти цифры **не являются доказательством для новой ветки**. В этом документе они помечены как исторические; полный ручной проход M1 и экспортная сборка — **NOT TESTED**.

### 2.2. Дефекты, которые надо исправить

| # | Где | Факт | Приоритет | Решение |
|---|---|---|---|---|
| D-01 | `scripts/ui/objective_line.gd:10`, `:107–111`, `:170–179`, `:190–191` | `ObjectiveLine` предпочитает `resources/ui/post_nightmare_objectives.tres` цели `CampaignGuide`. При этом `scripts/locations/post_nightmare/greybox_location.gd:120–125` уже вызывает `CampaignGuide.set_external_objective(..., &"post_nightmare")`. Два источника дают разные тексты одной цели. | P0 | Удалить preload и fallback; оставить `QuestSystem -> CampaignGuide`. |
| D-02 | `scripts/ui/map/map_screen.gd:220` | `_build_marker_list()` вызывает `displayed_map.visible_markers({})` вместо `_game_flags()`, поэтому скрытые маркеры остаются в списке. | P0 | Передать `_game_flags()`; проверить, что canvas и список используют один набор флагов. |
| D-03 | `scripts/ui/rpg_menu/rpg_quest_screen.gd:200–203` | Если живого источника нет, журнал показывает `catalog` (`RpgDemoQuestCatalog`). Это честный fallback, но в игровом прохождении он показывает несуществующий прогресс. | P1 | Убрать DEMO-каталог как источник; оставить пустое состояние с объяснением. |
| D-04 | `scenes/ui/rpg_menu/quest_screen.tscn:195–208`, `:356`, `:383` | В сцене остались `DemoPanel`, `DEMO · НАЗВАНИЕ ЗАПИСИ` и пояснение демо-записи. | P1 | Удалить/скрыть демо-панель, заменить плейсхолдеры на нейтральные. |
| D-05 | `scripts/ui/pause_menu/pause_menu.gd:225–251`, `:372–373` | Настройки паузы содержат громкость и fullscreen, но не содержат captions/mono/dynamic range; `_connect_settings()` пуст. | P1 | Добавить доступность и сохранение через `GameSettings`; не менять `AudioDirector` вручную. |
| D-06 | `scripts/ui/pause_menu_system.gd:91–108` | Проверка модальных окон не знает о `QuestChoicePanel`; Esc может открыть паузу поверх панели выбора. | P0 | Добавить группу `quest_choice_panel` и проверку `is_open()` в `_is_modal_open()`. |
| D-07 | `scenes/campaign/post_nightmare_finale.tscn:43`, `scripts/campaign/post_nightmare_finale.gd:14` | Финальная карточка жёстко показывает «Конец демонстрационного фрагмента», а скрипт ставит только `post_nightmare_completed`; M1 и tech demo не различаются. | P0 | A08 делает `FinalCard`-компонент, A04 передаёт вариант M1/tech demo и правильный флаг. |
| D-08 | `scripts/ui/main_menu/main_menu.gd` | Есть оба входа и кредиты, но нет видимой пометки демо-фрагмента. | P1 | Добавить `ДЕМО`/`ДЕМО-ФРАГМЕНТ` в главное меню; не выдавать демо за полную игру. |
| D-09 | `project.godot:28–33` | Reference 1600×900; `MASTER_AUDIT.md:207` говорит 1920×1080. | P1 | Решение TD; после него — единый reference и проверка 4K/ultrawide. |
| D-10 | `scenes/quests/gameplay_hud.tscn` | Сцена HUD принадлежит A04 (`scenes/quests/**`), а его композиция — задача A08. | P0 (ownership) | TD: carve-out сцены для A08 или разделение HUD на A08-обёртку и A04-сцену. |
| D-11 | `scripts/ui/rpg_menu/rpg_inventory_screen.gd:52`, `:70` | Инвентарь работает на `RpgDemoSession`; реальные предметы/валюта/Памяти не отображаются. | P2 | P2-адаптер к `NightmareRunState`; без второго инвентаря. |
| D-12 | `tests/test_ui_demo.gd` | Файл создан вне A10; `tests/**` принадлежит A10. | P0 (process) | A10 принимает файл или TD даёт A08 carve-out на `tests/ui/**`. |
| D-13 | `scripts/locations/post_nightmare/greybox_location.gd:70–79` | В A03-скрипте есть вторая таблица текстов целей, отличная от A08-таблицы. | P1 (content) | После удаления A08-таблицы HUD показывает текст A03; A01 утверждает канонический текст; A03 хранит его в одном месте. |
| D-14 | `tests/test_ui_demo.gd:150–165` | Тест добавляет `GreyboxLocation` ребёнком, поэтому `_setup_post_nightmare_demo()` выходит раньше установки guide-цели; после удаления A08-fallback строка цели будет пустой. | P0 (test) | A10 обновляет тест: либо выставляет `CampaignGuide.set_external_objective` вручную, либо запускает сцену как current_scene. |

### 2.3. Что уже работает и не требует переписывания

- `RpgMapScreen` уже передаёт `_game_flags()` и поддерживает локальные карты M1.
- `MapMarker.hide_when_flag` уже существует; менять его не нужно.
- `SubtitleUI` уже поддерживает клик, счётчик и Enter; нужна проверка интеграции, а не второй компонент.
- `PauseMenuSystem` уже владеет паузой и мышью; нельзя создавать второй pause autoload.
- `QuestSystem` уже пушит внешнюю цель в `CampaignGuide`; нельзя создавать второй quest HUD.
- `GameplayHud` уже добавлен в семь сцен M1 и Лабиринт (в текущем рабочем дереве); это нужно проверить, а не дублировать.

---

## 3. Целевая архитектура UI

```text
                         ┌──────────────────────────────┐
                         │ A04: QuestSystem / Guide      │
                         │ NightmareRunState / MapSystem│
                         └──────────────┬───────────────┘
                                        │ сигналы / snapshot / flags
             ┌──────────────────────────┼──────────────────────────┐
             ▼                          ▼                          ▼
   ┌──────────────────┐      ┌────────────────────┐     ┌──────────────────┐
   │ A08: ObjectiveLine│      │ A08: RpgQuestScreen │     │ A08: MapScreen / │
   │ QuestSystem →     │      │ live journal        │     │ RpgMapScreen     │
   │ CampaignGuide     │      │ no DEMO fallback    │     │ flags → markers  │
   └────────┬─────────┘      └────────────────────┘     └──────────────────┘
            │
            ▼
   ┌──────────────────┐      ┌────────────────────┐     ┌──────────────────┐
   │ A08: GameplayHud │      │ A08: SubtitleUI     │     │ A08: PauseMenu   │
   │ prompt/HP/tide/  │◄────►│ DialogueRunner (A04)│     │ settings/credits │
   │ toast/markers    │      │                    │     │ choice-aware     │
   └──────────────────┘      └────────────────────┘     └──────────────────┘
            │
            ▼
   ┌──────────────────┐      ┌────────────────────┐
   │ A08: FinalCard   │◄─────│ A04: finale scene   │
   │ reusable UI      │      │ milestone flags     │
   └──────────────────┘      └────────────────────┘
```

### 3.1. Правила источников истины

1. **Цель HUD:**
   - `QuestSystem.is_scope_active()` → `get_tracked_objective_text()`;
   - иначе `CampaignGuide.get_display_objective()`.
   - Пост-Кошмарная M1-сцена задаёт внешнюю цель через `CampaignGuide.set_external_objective(..., &"post_nightmare")` (A03/A04), а не через UI-ресурс.
2. **Журнал:**
   - `QuestSystem.get_journal_entries()` при активном scope;
   - иначе история `CampaignGuide.get_history()`;
   - иначе честное пустое состояние.
3. **Карта:**
   - `NightmareRunState.snapshot()["flags"]` → `MapDefinition.visible_markers(flags)`;
   - UI не хранит собственные флаги и не вычисляет скрытие маркеров.
4. **Выбор:**
   - A04 вызывает `QuestChoicePanel.present(prompt, choices)`;
   - UI только показывает и испускает `choice_selected(choice_id)`;
   - A04 пишет флаг и вызывает `QuestSystem.notify_event`/аналог. UI не знает о `QuestSystem`.
5. **Финальная карточка:**
   - A08 отображает переданные строки и испускает `return_requested`;
   - A04 выбирает M1/tech demo, ставит `post_nightmare_demo_completed` или `post_nightmare_completed`, сохраняет и меняет сцену.
6. **Пауза:**
   - один `PauseMenuSystem`;
   - пауза не открывается поверх карты, меню, инвентаря, Моря Души и `QuestChoicePanel`;
   - UI не управляет `get_tree().paused` напрямую, кроме существующего `PauseMenuSystem`.

### 3.2. Ограничения

- Не создавать `QuestHud`, `JournalManager`, `InventoryManager`, `ChoiceManager`, второй `PauseMenuSystem` или второй `MapSystem`.
- Не добавлять autoload.
- Не менять `project.godot` без A00.
- Не менять `scenes/locations/**`, `scenes/campaign/**`, `scenes/quests/**` без TD/владельца.
- Не переписывать `RpgMenuTheme` целиком; тема заморожена, менять только точечно по разрешению.
- Не удалять DEMO-ресурсы и старые сцены без подтверждения пользователя; их можно перестать использовать.

---

## 4. Что реализовать: исправления и новые элементы

| Область | Исправить | Создать | Приоритет |
|---|---|---|---|
| HUD / цель | `ObjectiveLine`: убрать UI-таблицу и fallback; проверить prompt/subtitles/tide/markers; устранить перекрытия | нет нового HUD | P0 |
| Выбор в диалоге | нет | `QuestChoicePanel` (UI + сигнал, без backend) | P0 (контракт; M3-потребитель) |
| Карта | `MapScreen` flags в списке маркеров; проверить `RpgMapScreen` | нет второй карты | P0 |
| Финальная карточка | убрать жёстко зашитый tech-demo текст из UI-пути | `FinalCard` — переиспользуемый компонент A08 | P0 |
| Пауза | captions/mono/dynamic range; credits; проверка choice-модалки | `CreditsDialog`/данные кредитов A08 | P0/P1 |
| Журнал | убрать DEMO-fallback и DemoPanel; добавить пустое состояние | нет второго журнала | P1 |
| Главное меню | видимая DEMO-пометка; проверить оба входа | нет дублирующего меню | P0 |
| Масштаб | единый reference; 4K/ultrawide/контраст | нет UI-системы | P1 |
| Инвентарь/Памяти | реальные данные из state | адаптер отображения, без второго инвентаря | P2 |
| Доказательства | обновить UI-аудит | capture/acceptance matrix | P1 |

### 4.1. HUD M1 (A08-01)

Состав HUD на сцену:

- `ObjectiveLine` — одна строка цели, не список;
- `Prompt` — `E — ...`;
- `CombatHud` — HP/выносливость, числа, враг;
- `Subtitles` — реплики, счётчик, клик;
- `QuestToast` — старт/финиш/награда;
- `TideIndicator` — только при наличии `TideController`;
- `HudWorldMarkers` — взаимодействия и компас цели.

Что проверить:

1. На каждой из сцен `police_precinct`, `academy_approach`, `academy_gate`, `academy_campus`, `academy_sleeper_center`, `black_sea_platform`, `tide_descent` ровно один `GameplayHud`.
2. В P05–B02 цель приходит из `CampaignGuide`, потому что `GreyboxLocation` уже вызывает `set_external_objective`. После удаления A08-таблицы текст должен совпасть с guide.
3. В `labyrinth_first_fragment` цель приходит из `QuestSystem`, а `CampaignGuide` не перекрывает её.
4. В Первом Кошмаре цель приходит из `CampaignGuide` (beat), без пост-Кошмарной таблицы.
5. При смене сцены HUD не падает на `get_node()` вне дерева; `ObjectiveLine.refresh_from_sources()` уже проверяет `is_inside_tree()`.
6. Подсказка обучения не перекрывает диалог; таймеры сбрасываются.
7. `TideIndicator` не появляется в сценах без `tide_controller`.
8. Мировые маркеры не видны в паузе/меню/карте/диалоге.
9. При 1600×900 и 1920×1080 цель, подсказка, прилив и субтитры не накладываются.

### 4.2. `QuestChoicePanel` (A08-02)

**Контракт** (`INTEGRATION_CONTRACTS.md` §14.2):

```gdscript
class_name QuestChoicePanel
extends CanvasLayer

signal choice_selected(choice_id: StringName)

func present(prompt: String, choices: Array[Dictionary]) -> void
func close() -> void
```

`choices[i]`: `{ id: StringName, text: String, flag: StringName, quest_event: StringName, quest_subject: StringName }`.

**Пробел контракта:** в §14.2 нет полей `locked`/`lock_reason`, а SQ-03 требует показать заблокированную ложь. Нужно аддитивное расширение схемы (`locked: bool`, `lock_reason: String`) с версией DP-1.1 или отдельный `disabled_choices`; иначе UI не может отличить «недоступный» вариант от обычного. См. D-UI-13.

Поведение:

- нижняя панель, не весь экран; затемнение только вокруг;
- 2–4 варианта (SQ-03: три правды + заблокированная ложь);
- клавиши `1–4`, стрелки + Enter, мышь; видимый focus;
- заблокированный вариант: disabled, замок/подпись «Flaw не позволяет», не только цвет;
- без таймера; игрок может думать;
- `Esc` не должен открывать паузу и не должен молча выбирать вариант; `close()` вызывает A04 после решения;
- ровно один сигнал на выбор; повторное нажатие после выбора игнорируется;
- UI не вызывает `QuestSystem`, не пишет флаги, не создаёт второй диалоговый движок;
- A08 добавляет `QuestChoicePanel` в проверку `PauseMenuSystem._is_modal_open()` через группу `quest_choice_panel` (файл pause-системы принадлежит A08).

### 4.3. Карта (A08-03)

- `MapScreen._build_marker_list()` должен использовать `visible_markers(_game_flags())`.
- `RpgMapScreen` уже использует флаги; проверить, что список и canvas совпадают.
- Скрытые маркеры не должны быть ни в списке, ни на canvas.
- Флаги берутся из `NightmareRunState.snapshot()["flags"]`; UI не хранит копию.
- Локальные карты M1 — данные A03/A04; A08 только отображает.
- Не создавать вторую карту и не дублировать `MapDefinition`.

### 4.4. Финальная карточка (A08-04)

A08 создаёт:

```gdscript
class_name FinalCard
extends CanvasLayer

signal return_requested

func present(kicker: String, title: String, body: String, hint: String) -> void
func close() -> void
```

- Никаких канонических текстов внутри UI; тексты передаёт A04/A01.
- `R`/`Esc` работают только когда карточка видима; испускают один `return_requested`.
- Кнопка «В главное меню» также испускает `return_requested`.
- A04 встраивает компонент в `scenes/campaign/**`, выбирает вариант:
  - M1: `ПЕРВЫЙ ДЕНЬ` / `Конец M1`, флаг `post_nightmare_demo_completed`;
  - tech demo: `Конец демонстрационного фрагмента`, флаг `post_nightmare_completed`.
- A04 отвечает за сохранение, смену сцены и флаги; A08 не меняет `scripts/campaign/**`.

### 4.5. Пауза, настройки, кредиты (A08-05)

- Один `PauseMenu` + существующий `PauseMenuSystem`.
- Настройки паузы должны совпадать с главным меню по смыслу:
  - master/music/ambience/sfx/voice/ui volume;
  - fullscreen;
  - captions;
  - mono downmix;
  - dynamic range;
  - reset.
- Все значения читаются/пишутся через `GameSettings`; `AudioDirector.apply_accessibility(...)` вызывается из `GameSettings.apply()` или существующего пути, не вручную из UI.
- Кредиты: доступны из паузы; текст берётся из одного источника A08 (например, `resources/ui/credits.tres`), лицензии валидирует A00/A07.
- Пауза не открывается поверх `QuestChoicePanel`, карты, меню, инвентаря, Моря Души.
- `MCPRuntime` не должен отображаться в UI; это release-задача A00/A10, не добавлять UI-индикатор.
- Esc/Enter/мышь и focus сохраняются.

### 4.6. Журнал (A08-06)

- Источник: `QuestSystem` → `CampaignGuide` → пустое состояние.
- Убрать `RpgDemoQuestCatalog` как fallback из `RpgQuestScreen`; DEMO-ресурсы не удалять без разрешения.
- Убрать/скрыть `DemoPanel` и все `DEMO`-подписи в сцене журнала.
- M1: 7 базовых заданий Лабиринта + история кампании.
- Полный набор: 7 базовых + 5 SQ (12 записей) после появления SQ `.tres` A02.
- Секции: активные, доступные, завершённые; статусы, tracked, прогресс.
- «Последствие/цепочка»: показывать `note`/`description` из живого entry; не добавлять новое поле в контракт без версии DP. Если A04/A02 хотят отдельное поле — это изменение контракта, а не самодеятельность UI.
- Кнопка tracking остаётся только для активного задания.

### 4.7. Главное меню (A08-09)

- «Играть» → Первый Кошмар (`campaign_entry`).
- «После Кошмара» → `police_precinct` с демо-состоянием; кнопка уже есть.
- «Кредиты и лицензии» — проверить, не удалять.
- Видимая пометка `ДЕМО`/`ДЕМО-ФРАГМЕНТ`; не выдавать за полную игру.
- Не менять главную сцену в `project.godot` (A00).

### 4.8. Масштаб и доступность (A08-07)

- Reference выбирает TD: 1600×900 (текущий UI) или 1920×1080 (`MASTER_AUDIT`).
- `canvas_items` + `expand`; без ручного scale в каждом экране, кроме существующего `RpgMenuPrototype` (проверить, не двойной ли scale).
- Проверить 1600×900, 1920×1080, 2560×1440, 3840×2160, 21:9.
- Минимальный читаемый размер 14 px для боевых/квестовых подписей; контраст: ориентир 4.5:1 для мелкого текста и 3:1 для крупного; не только цвет.
- Проверить кириллицу и fallback шрифта; не считать консольный вывод доказательством повреждения текста.

### 4.9. Инвентарь и Памяти (A08-08, P2)

- Текущий `RpgInventoryScreen` — демо-прототип на `RpgDemoSession`.
- Нужен read-only адаптер к `NightmareRunState.snapshot()`: предметы, валюта, памяти.
- Не создавать второй инвентарь и не менять state.
- Если у A04 нет каталога предметов/памятей, задача блокируется и остаётся P2; UI показывает честное пустое состояние.

---

## 5. Список задач A08

### 5.1. Формат и оценка

- `1 d` = 6 часов сфокусированной работы одного разработчика.
- Оценка включает реализацию и самопроверку, но не включает ревью TD, ожидание чужих задач и полный GUT.
- Risk: **L** — локальный UI-файл; **M** — есть зависимость/спорный контракт; **H** — нет данных или несколько владельцев.
- Все задачи выполняются только в A08-файлах, если в колонке Files нет пометки `shared`; shared-правки вынесены в раздел 6.
- ID `A08-10…A08-13` — дополнительные атомарные задачи; они не отменяют и не дублируют A08-01…A08-09 из `AGENT_TASKS.md`, а уточняют их.

### 5.2. P0 — блокирует M1/контракт

| Task ID | Description | Files | Dependencies | Priority | Effort | Risk | Acceptance Criteria |
|---|---|---|---|---|---|---|---|
| **A08-00** | Подготовить чистую ветку A08: отделить UI-файлы от Stage 1 cross-zone изменений, зафиксировать claims, не тащить чужие правки | нет игровых файлов; `docs/demo_sprint/implementation/ACTIVE_CLAIMS.md` (через TD) | TD lock `MASTER_PLAN`/`FILE_OWNERSHIP`; D-UI-01…D-UI-07 | P0 | 0.25 d | L | Ветка `feature/a08-ui-m1` создана от интеграционного commit TD; `git diff --name-only` содержит только A08-пути; cross-zone файлы перечислены в claims и не входят в A08-коммит; проект открывается без parse errors |
| **A08-01** | HUD/ObjectiveLine: один источник цели; убрать `post_nightmare_objectives.tres` из логики; проверить prompt/tide/markers/toast/hint и отсутствие перекрытий | `scripts/ui/objective_line.gd`, `scripts/ui/gameplay_hud.gd`, `scenes/ui/objective_line.tscn`; проверка `scenes/ui/tide_indicator.tscn`, `scenes/ui/hud_world_markers.tscn` | UI-EXT-04 (текст/установка цели), UI-EXT-05 (контракт guide), UI-EXT-12 (тест); UI-EXT-03 — только если нужна правка композиции HUD | P0 | 1.0 d | M | `ObjectiveLine` не содержит preload/post-nightmare таблицы; при активном `QuestSystem` показывает его цель, иначе `CampaignGuide.display_objective`; в P05–B02 текст совпадает с guide; в Лабиринте — с tracked quest; нет второго HUD; нет наложений на 1600×900 и 1920×1080; targeted UI test A10 зелёный; если не запускался — статус **NOT TESTED**, задача не закрыта |
| **A08-02** | `QuestChoicePanel`: новая UI-панель 2–4 вариантов, клавиши/мышь/focus, locked-вариант, сигнал; пауза не открывается поверх | **new:** `scenes/ui/quest_choice_panel.tscn`, `scripts/ui/quest_choice_panel.gd`; **modify:** `scripts/ui/pause_menu_system.gd` | UI-EXT-06 (backend), UI-EXT-09 (тексты), UI-EXT-10 (SQ-03), D-UI-09, D-UI-13 | P0 | 1.5 d | M | `present()` показывает 2–4 варианта; `1–4`/стрелки/Enter/мышь работают; focus видим; locked нельзя выбрать; `choice_selected` испускается ровно один раз; `Esc` не выбирает и не открывает паузу; `close()` скрывает; UI не вызывает `QuestSystem`; ручная проверка + A10 test |
| **A08-03** | `MapScreen`: передать реальные флаги в список маркеров; проверить `RpgMapScreen` и локальные карты | `scripts/ui/map/map_screen.gd`; проверка `scripts/ui/rpg_menu/rpg_map_screen.gd`, `scripts/ui/map/map_canvas.gd` | UI-EXT-07 (`visible_markers`/flags), A03 map data | P0 | 0.25 d | L | `MapScreen._build_marker_list()` использует `_game_flags()`; скрытый маркер отсутствует и в списке, и на canvas; `RpgMapScreen` ведёт себя так же; UI не меняет `scripts/map/**`; targeted test A10 |
| **A08-04** | `FinalCard`: переиспользуемый компонент с сигналом возврата; без канонических текстов и без смены сцены | **new:** `scenes/ui/final_card.tscn`, `scripts/ui/final_card.gd` | UI-EXT-09 (тексты), D-UI-03; интеграция — отдельная UI-EXT-08 | P0 | 0.75 d | M | `present(kicker,title,body,hint)` показывает карточку; `return_requested` испускается один раз по кнопке/`R`/`Esc`; UI не меняет сцену и флаги; A04-интеграция показывает M1 и tech demo варианты; общий gate — A10/manual |
| **A08-05** | Пауза: доступность (captions/mono/dynamic range), кредиты, conflict с choice/menus; настройки сохраняются | `scripts/ui/pause_menu/pause_menu.gd`, `scenes/ui/pause_menu/**`, `resources/ui/credits.tres` (new, optional) | D-UI-08 (autoload approval); UI-EXT-11 (UI cues) — optional; conflict с choice проверяется после A08-02 | P0 | 1.25 d | M | Пауза открывается/закрывается Esc; не открывается поверх карты/меню/инвентаря/Моря Души; captions/mono/dynamic range меняются и сохраняются; credits доступны; `MCPRuntime` не виден; нет второго autoload; conflict с choice — после A08-02, иначе **NOT TESTED**; ручная проверка + A10 test |
| **A08-09** | Главное меню: видимая DEMO-пометка, оба входа, кредиты; без переписывания меню | `scripts/ui/main_menu/main_menu.gd`, `scenes/ui/main_menu/main_menu.tscn` | UI-EXT-02 (freeze exception), UI-EXT-01 (main scene) | P0 | 0.25 d | L | «Играть» ведёт в Первый Кошмар; «После Кошмара» ведёт в `police_precinct`; кредиты открываются; видна пометка `ДЕМО`; нет DEMO-каталога в основном потоке; скриншот 1600×900 |

### 5.3. P1 — качество M1/tech demo

| Task ID | Description | Files | Dependencies | Priority | Effort | Risk | Acceptance Criteria |
|---|---|---|---|---|---|---|---|
| **A08-06** | Журнал: убрать DEMO-fallback и демо-панель; живой источник + пустое состояние | `scripts/ui/rpg_menu/rpg_quest_screen.gd`, `scenes/ui/rpg_menu/quest_screen.tscn`, `scripts/ui/rpg_menu/rpg_quest_row.gd` | A04 journal entries, UI-EXT-12 | P1 | 1.0 d | M | В живом прохождении нет `DEMO`-строк; журнал читает QuestSystem/Guide; при отсутствии данных показывает «Записей пока нет»; 7 базовых заданий видны; tracking работает; A10 test |
| **A08-06.1** | Полный журнал 7+5 SQ: секции, статусы, последствия/цепочка через `note`/`description`; без нового поля контракта | `scripts/ui/rpg_menu/rpg_quest_screen.gd`, `scenes/ui/rpg_menu/quest_screen.tscn` | A08-06, UI-EXT-10 (5 SQ), A04 journal entries, UI-EXT-09 | P1 | 0.75 d | M | При полном каталоге 12 записей: 7 базовых + 5 SQ; нет дублей; активные/доступные/завершённые корректны; consequence/chain читается из `note`/`description`; нет нового поля без DP-1.1 |
| **A08-07** | Масштаб/4K/ultrawide/контраст: единый reference, 4 разрешения, читаемость, screenshots | `scripts/ui/**`, `scenes/ui/**` только при необходимости; `docs/demo_sprint/audits/ui_ux.md` | UI-EXT-01 (reference), A08-01…A08-06.1, UI-EXT-12 (captures) | P1 | 1.0 d | M | Проверены 1600×900, 1920×1080, 2560×1440, 3840×2160; нет обрезки/наложений; текст ≥14 px в ключевых местах; контраст 4.5:1/3:1 по ориентиру; 4+ screenshots, включая 21:9; всё непроверенное — **NOT TESTED** |
| **A08-10** | Диалоги/субтитры: проверить клик/E/Space/Enter, счётчик, перенос, пустую последовательность; не дублировать `SubtitleUI` | `scripts/ui/subtitle_ui.gd`, `scenes/ui/prologue_ui.tscn` (только UI) | A04 DialogueRunner, UI-EXT-12 | P1 | 0.25 d | L | Клик по панели и E/Space/Enter продвигают; счётчик `N / M`; длинный текст переносится; пустая последовательность не зависает; ввод не проходит сквозь модалку; существующий `DialogueRunner` не заменён |
| **A08-11** | Карта UI: локальные карты M1, пустые состояния, подсветка цели; без изменения map data | `scripts/ui/rpg_menu/rpg_map_screen.gd`, `scripts/ui/map/map_screen.gd`, `scripts/ui/map/map_canvas.gd` | A08-03, A03 map data, UI-EXT-07 | P1 | 0.5 d | M | P05–B02 показывают локальную карту текущей сцены; Лабиринт — карту региона; при отсутствии данных — понятное пустое состояние; target marker подсвечивается; скрытые маркеры отсутствуют |
| **A08-12** | UI evidence pack: обновить аудит, собрать screenshots и acceptance matrix; честно отметить NOT TESTED | `docs/demo_sprint/audits/ui_ux.md`; временные screenshots вне Git | UI-EXT-12, A08-01…A08-11 | P1 | 0.75 d | L | В отчёте есть список проверок, команды, разрешения, скриншоты; нет PASS без лога; ручной проход M1 отмечен корректно; ссылки на тесты A10 |

### 5.4. P2 — после M1

| Task ID | Description | Files | Dependencies | Priority | Effort | Risk | Acceptance Criteria |
|---|---|---|---|---|---|---|---|
| **A08-08** | Реальный инвентарь/Памяти: read-only адаптер к `NightmareRunState`, без demo-подмены | `scripts/ui/rpg_menu/rpg_inventory_screen.gd`, `rpg_character_screen.gd`, `rpg_menu_prototype.gd`, `scenes/ui/rpg_menu/**`, `resources/rpg_menu/**` | A04 item/memory data, A06 character data, UI-EXT-12 | P2 | 2.5 d | H | Предметы/валюта/Памяти берутся из state; нет `RpgDemoSession` в основном потоке; действия не мутируют state без A04 API; пустое состояние; не создан второй инвентарь |
| **A08-13** | UI-звук: проверить, что choice/pause/tide/toast используют существующие cue A09, без нового аудиослоя | `scripts/ui/**` (только вызовы), без `scripts/audio/**` | A08-02, A08-05, UI-EXT-11 | P2 | 0.25 d | L | Нет нового AudioDirector/шины; cue вызываются через `AudioDirector.play_ui`; отсутствие cue не ломает UI; слуховой тест — A09 |

**Итого:** ~12.25 dev-days; M1 critical path (без P2 и полного SQ-журнала) — примерно 5.0–6.5 dev-days. Choice panel входит в контракт P0, но не в M1-маршрут; его можно сдать отдельным PR после M1 gate.

---

## 6. Внешние задачи и интеграции (не файлы A08)

Эти задачи должны выполнить владельцы зон. A08 не делает их в своей ветке. Оценки effort/risk по внешним задачам здесь не ставятся: их даёт владелец зоны; A08 фиксирует только зависимость и acceptance.

| ID | Owner | Task | Files | Depends | Priority | Acceptance |
|---|---|---|---|---|---|---|
| **UI-EXT-01** | A00 | Зафиксировать reference-разрешение и display policy: 1600×900 или 1920×1080; `canvas_items`/`expand`; обновить `MASTER_AUDIT`/`DECISIONS` | `project.godot`, `docs/DECISIONS.md`, `docs/demo_sprint/MASTER_AUDIT.md` | D-UI-04 | P0 | Одно значение во всех документах; проект запускается; A08-07 проверяет именно его |
| **UI-EXT-02** | A00 | Принять/отклонить Stage 1 cross-zone изменения; выдать или отклонить shared-file claims; снять/подтвердить freeze `main_menu`/`RpgMenuTheme` | `ACTIVE_CLAIMS.md`, `FILE_OWNERSHIP` (если нужен carve-out), `docs/DECISIONS.md` | D-UI-05, D-UI-07 | P0 | Каждый файл имеет владельца; A08-ветка не содержит чужих правок; freeze exceptions записаны |
| **UI-EXT-03** | A00 | Решить ownership `scenes/quests/gameplay_hud.tscn`: carve-out A08 или перенос/разделение | `scenes/quests/gameplay_hud.tscn`, `FILE_OWNERSHIP.md` | D-UI-01 | P0 | A08 может менять композицию HUD без нарушения A04; путь не ломает 8 сцен |
| **UI-EXT-04** | A03 | Семь пост-Кошмарных сцен: ровно один `GameplayHud`, установка/сброс `CampaignGuide.set_external_objective`; убрать дублирующую таблицу или оставить один источник | `scenes/locations/post_nightmare/**`, `scripts/locations/post_nightmare/greybox_location.gd` | UI-EXT-09, UI-EXT-03 | P0 | В каждой сцене один HUD; цель из guide; при выходе/сбросе нет чужой цели; нет второго HUD |
| **UI-EXT-05** | A04 | Контракт `CampaignGuide.set_external_objective`/`clear_external_objective`; очистка при reset/смене сценария; тест | `scripts/guide/**`, `scripts/quests/**`, `scripts/campaign/**` | UI-EXT-04 | P0 | Guide — единственный источник M1-цели; `QuestSystem` не перекрывает guide вне scope; тест |
| **UI-EXT-06** | A04 | Backend `QuestChoicePanel`: слушать `choice_selected`, писать флаг/событие, не создавать второй dialogue engine | `scripts/dialogue/**`, `scripts/quests/**`, `resources/quests/sq_fs_03*` | UI-EXT-10 | P0 | Выбор пишет флаг; повтор не дублирует; UI не знает QuestSystem; тест |
| **UI-EXT-07** | A04 | `MapDefinition.visible_markers(flags)` + `MapMarker.hide_when_flag`; flags из `NightmareRunState.snapshot()` | `scripts/map/**`, `resources/map/**` (кроме `locations/**`) | — | P0 | Скрытые маркеры не возвращаются API; UI получает корректный список; тест |
| **UI-EXT-08** | A04 | Интегрировать `FinalCard` в `scenes/campaign/**`; M1/tech demo тексты и флаги; сохранение и возврат | `scenes/campaign/**`, `scripts/campaign/**` | A08-04, UI-EXT-09, A03 final zones | P0 | M1: «ПЕРВЫЙ ДЕНЬ»/«Конец M1» + `post_nightmare_demo_completed`; tech: «Конец демонстрационного фрагмента» + `post_nightmare_completed`; R/Esc/кнопка; нет зависания |
| **UI-EXT-09** | A01 | Канонические тексты: цели P05–B02, финальные карточки, choice-реплики, speaker names; один источник вместо A03/A08 таблиц | `resources/dialogue/**`, `data/dialogues/**`, `docs/story/**`, карточки | D-UI-02 | P0 | Тексты утверждены; нет расхождения A03/A08; A08 не хранит канон |
| **UI-EXT-10** | A02 | SQ-03 choice data и journal metadata: 3 правды + locked lie, consequence/chain; 5 SQ `.tres` | `resources/quests/sq_fs_*.tres`, `resources/quests/quest_catalog.tres` (через A04) | UI-EXT-09, D-UI-09, D-UI-13 | P0 for M3 / P1 full journal | SQ-03 данные полны; locked lie имеет `locked`/`lock_reason`; журнал 12 записей; без дублей |
| **UI-EXT-11** | A09 | UI cues для выбора/паузы/тостов/прилива; captions; не менять UI-разметку | `resources/audio/**`, `scripts/audio/**` | — | P1 | Cue существуют; отсутствие cue не ломает UI; слуховой тест A09 |
| **UI-EXT-12** | A10 | Тесты и доказательства: `tests/ui/**` или принятие `test_ui_demo.gd`; обновить M1-тест под guide-only (D-14); targeted/full GUT; captures; route | `tests/**`, `tools/audit/**`, `docs/demo_sprint/qa/**` | D-UI-06, A08-00 | P0 | Тесты запущены с логом; UI acceptance matrix закрыта; full GUT без ложного PASS |

---

## 7. Файлы, ресурсы, инструменты

### 7.1. A08-файлы, которые будут меняться

| Файл | Изменение | Задача |
|---|---|---|
| `scripts/ui/objective_line.gd` | убрать `POST_NIGHTMARE_OBJECTIVES`, `_post_nightmare_objective()`, проверки в `_on_guide_objective_changed`; оставить QuestSystem → Guide | A08-01 |
| `scripts/ui/gameplay_hud.gd` | проверить bindings/таймеры/перекрытия; без второго HUD | A08-01 |
| `scripts/ui/tide_indicator.gd` | проверить скрытие без контроллера, читаемость | A08-01 |
| `scripts/ui/hud_world_markers.gd` | проверить скрытие в модалках/диалоге; не добавлять M1-цели в Лабиринт | A08-01 |
| `scripts/ui/combat_hud.gd` | проверить числа/пороговые цвета/вспышку; не менять боевые данные | A08-01 |
| `scripts/ui/map/map_screen.gd` | `_build_marker_list()` → `_game_flags()` | A08-03 |
| `scripts/ui/rpg_menu/rpg_map_screen.gd` | проверить flags/local map/target highlight | A08-03/A08-11 |
| `scripts/ui/rpg_menu/rpg_quest_screen.gd` | убрать demo fallback; пустое состояние; consequence/chain | A08-06/06.1 |
| `scripts/ui/rpg_menu/rpg_quest_row.gd` | проверить typed/RefCounted duck typing; без нового поля | A08-06 |
| `scenes/ui/rpg_menu/quest_screen.tscn` | убрать DemoPanel/DEMO-подписи | A08-06 |
| `scripts/ui/pause_menu/pause_menu.gd` | captions/mono/dynamic range/credits | A08-05 |
| `scripts/ui/pause_menu_system.gd` | `_is_modal_open()` + `quest_choice_panel` | A08-02 |
| `scripts/ui/main_menu/main_menu.gd` | DEMO-пометка; проверить оба входа | A08-09 |
| `scenes/ui/main_menu/main_menu.tscn` | только если нужна статическая пометка; freeze claim | A08-09 |
| `scenes/ui/quest_choice_panel.tscn` | **new** | A08-02 |
| `scripts/ui/quest_choice_panel.gd` | **new** | A08-02 |
| `scenes/ui/final_card.tscn` | **new** | A08-04 |
| `scripts/ui/final_card.gd` | **new** | A08-04 |
| `resources/ui/credits.tres` | **new, optional**; текст кредитов | A08-05 |
| `resources/ui/post_nightmare_objectives.tres` | **deprecated**, не удалять без разрешения; убрать из кода | A08-01 |
| `scripts/ui/post_nightmare_objectives.gd` | **deprecated**, не удалять без разрешения | A08-01 |
| `docs/demo_sprint/design/ui_ux_design.md` | обновить источник цели, финальные карточки, статус | A08-01/A08-12 |
| `docs/demo_sprint/audits/ui_ux.md` | обновить доказательства, NOT TESTED | A08-12 |

### 7.2. Shared/чужие файлы — только через владельца

| Файл | Владелец | Что нужно | Не делать |
|---|---|---|---|
| `scenes/quests/gameplay_hud.tscn` | A04 (нужен TD carve-out) | композиция HUD | не править без D-UI-01 |
| `scenes/locations/post_nightmare/**` | A03 | HUD instance, external objective | не добавлять HUD вручную |
| `scripts/locations/post_nightmare/greybox_location.gd` | A03 | один источник цели | не переносить логику в A08 |
| `scenes/campaign/**`, `scripts/campaign/**` | A04 | FinalCard integration, flags | не создавать второй finale |
| `scripts/guide/**`, `scripts/quests/**`, `scripts/map/**` | A04 | API/contracts | не вызывать внутренности |
| `resources/map/**` (кроме `locations/**`) | A04 | flags/markers | не менять |
| `resources/map/locations/**` | A03 | map data | не менять |
| `scripts/dialogue/dialogue_runner.gd` | A04 | subtitles/choice integration | не менять UI-задачей |
| `scripts/locations/.../tide_controller.gd` | A03/A04 | tide API | не менять UI-задачей |
| `project.godot` | A00 | display/autoload | не править |
| `tests/**` | A10 | tests/evidence | не писать A08-тесты без carve-out |
| `scenes/ui/main_menu/**` | A08, но freeze | только разрешённая правка | не переписывать |
| `scripts/ui/rpg_menu/rpg_menu_theme.gd` | A08, но freeze | точечные изменения только с TD | не рестайлить |

### 7.3. Ресурсы

**Новые A08-ресурсы:**

- `scenes/ui/quest_choice_panel.tscn`
- `scripts/ui/quest_choice_panel.gd`
- `scenes/ui/final_card.tscn`
- `scripts/ui/final_card.gd`
- `resources/ui/credits.tres` (если решено унифицировать кредиты; иначе `AcceptDialog` в pause)

**Существующие, которые переиспользуются:**

- `RpgMenuTheme` (`scripts/ui/rpg_menu/rpg_menu_theme.gd`) — не дублировать;
- шрифты/иконки `assets/ui/rpg_menu/**`;
- `resources/rpg_menu/**` — только как demo, не источник живого прогресса;
- `resources/campaign/glossary/**` — глоссарий;
- `resources/map/**` — данные A03/A04, не копировать в UI;
- UI-звуки — A09.

**Не нужны:**

- новые 3D-модели, текстуры, HDRI, шрифты без лицензии;
- новый шрифт для кириллицы, если текущий проходит проверку;
- второй theme-ресурс.

### 7.4. Инструменты

| Инструмент | Использование | Ограничение |
|---|---|---|
| Godot 4.7.2 | запуск сцен, инспектор, импорт, UI | версия из `MASTER_AUDIT` |
| GUT 9.7.1 | targeted/full тесты | тесты пишет/запускает A10 |
| Godot MCP / `tools/audit/location_capture.gd` | screenshots и live-проверка | MCP editor может быть не подключён; использовать headless/capture fallback |
| `git diff --check`, `git status --short` | чистота ветки/пробелы | не коммитить без TD |
| `docs/demo_sprint/audits/ui_ux.md` | evidence | не писать PASS без лога |
| Blender/Krita/Materialize | **не нужны** для UI-задач | не менять 3D/текстуры |

---

## 8. Зависимости и интеграция по специалистам

| Специалист | Что A08 получает | Что A08 отдаёт | Точка контакта |
|---|---|---|---|
| **A00 TD** | ownership, scale, freeze exceptions, autoload approval, merge | спецификация, список рисков, branch scope | D-UI-01…D-UI-12 |
| **A01 Narrative** | канонические тексты целей/финалов/choice, speaker names | форматы карточек/субтитров, ограничения длины | UI-EXT-09 |
| **A02 Side Quest** | SQ-03 choices, journal metadata/consequence, 5 SQ entries | `QuestChoicePanel` API, journal rendering | UI-EXT-06/10 |
| **A03 World** | 7 scenes, HUD instances, guide objectives, local map data, final zones | HUD anchors, local map UI, no duplicate HUD | UI-EXT-04 |
| **A04 Gameplay** | QuestSystem, CampaignGuide, MapSystem, state flags, final integration, choice backend | UI consumers only, no direct state writes | UI-EXT-05/06/07/08 |
| **A05 Combat** | health/stamina/enemy signals | CombatHud display, no combat data changes | A08-01 |
| **A06 Character** | player group, anim/character visuals | no UI changes to character assets | A08-01 |
| **A07 Environment** | lighting/contrast context, captures | UI readability feedback | A08-07 |
| **A09 Audio** | UI cue IDs, captions policy | UI call sites, no audio bus changes | UI-EXT-11 |
| **A10 QA** | tests, captures, full GUT, route evidence | acceptance matrix, test hooks, screenshots | UI-EXT-12 |

### 8.1. Порядок интеграции

```text
TD: ownership + scale decision
        │
        ├─ A00: HUD carve-out / display / freeze
        ├─ A01: texts (objectives, final cards, choice)
        ├─ A03: 7 scenes + guide objective + map data
        ├─ A04: guide/quest/map/final/choice backend
        │
        ▼
A08 branch: HUD→choice→map→final→pause→journal→menu→scale
        │
        ▼
A10: targeted UI tests → full GUT → captures → M1 manual
        │
        ▼
TD: merge + acceptance
```

---

## 9. Ошибки, конфликты и меры

| ID | Риск/конфликт | Влияние | Мера | Владелец |
|---|---|---|---|---|
| R-01 | `scenes/quests/gameplay_hud.tscn` принадлежит A04, а UI-задача A08 | A08 не может менять композицию; возможен второй HUD | TD carve-out одной сцены; не создавать вторую HUD-сцену | A00 |
| R-02 | Три источника цели: A08 `.tres`, A03 `greybox_location.gd`, `CampaignGuide` | HUD показывает не тот текст; рассинхрон с квестом | A08 удаляет свой fallback; A03/A01 оставляют один текст в guide | A08/A03/A01 |
| R-03 | Финальная карточка в `scenes/campaign/**` (A04), задача A08 | A08 не может интегрировать; дубль финальной сцены | `FinalCard` A08 + интеграция A04; без второго finale | A00/A04 |
| R-04 | 1600×900 vs 1920×1080 | 4K-проверка бессмысленна; UI может поехать | TD фиксирует один reference; A08 проверяет именно его | A00 |
| R-05 | Freeze `main_menu`/`RpgMenuTheme` | A08-09/тема блокируются | ограниченный claim на DEMO-пометку; без рестайла | A00 |
| R-06 | `tests/test_ui_demo.gd` создан вне A10 | нет легального автоматического доказательства | A10 принимает/переписывает; или carve-out `tests/ui/**` | A00/A10 |
| R-07 | `MapScreen` flags и map data в разных зонах | скрытые маркеры/неверная карта | A08 правит только UI; A04/A03 API/данные | A04/A03 |
| R-08 | Esc одновременно у PauseMenu, MapSystem, PlayerMenu, ChoicePanel | пауза поверх выбора/карты; input leak | `_is_modal_open()` + groups; `set_input_as_handled`; тест | A08/A04 |
| R-09 | Удаление DEMO-fallback оставляет пустой журнал до загрузки контента | игрок думает, что журнал сломан | честное пустое состояние + загрузка после `catalog_loaded` | A08/A04 |
| R-10 | Нет каталога реальных предметов/Памятей | P2-инвентарь нельзя завершить | P2 blocked; не подменять demo за канон | A04/A06 |
| R-11 | Кириллица/шрифт/UTF-8 в TSCN | «кракозябры» в подсказках | проверить UTF-8 и шрифт; не чинить консольный вывод | A08 |
| R-12 | Полный GUT нестабилен из-за UID GLB | ложный FAIL/ PASS | targeted UI + A10 clean run; не заявлять full green | A10 |
| R-13 | UI-перегрузка на 4K/ultrawide | нечитаемость/наложения | anchors, safe margins, screenshots, max width | A08/A10 |
| R-14 | `RpgQuestRow` работает с `Resource`/`RefCounted` duck typing | runtime-ошибки при новых entries | не менять тип без A04; targeted test | A08/A10 |
| R-15 | `QuestChoicePanel` поддерживает 2–3 или 2–4 | SQ-03 locked lie не помещается | TD решает; рекомендуется 2–4 | A00/A08 |
| R-16 | `test_ui_demo` проверяет M1-цель без current_scene и опирается на A08-fallback | после удаления fallback тест упадёт, хотя игра работает | A10 обновляет тест: prime `CampaignGuide` или current_scene; не возвращать дубль ради теста | A10/A08 |

---

## 10. Проверка готовности каждого элемента

Тесты пишет и запускает A10; A08 предоставляет acceptance matrix и UI hooks. Если тест не запускался, в отчёте — **NOT TESTED**, не «готово».

| Элемент | Автоматическая проверка (A10) | Ручная/визуальная проверка | Критерий |
|---|---|---|---|
| `ObjectiveLine` / M1 HUD | `test_ui_demo` + новый UI test: guide-only, quest priority, clear | `police_precinct`, `academy_gate`, `tide_descent`, `labyrinth_first_fragment` | цель совпадает с guide/quest; нет второго HUD; нет наложений 1600/1920 |
| `QuestChoicePanel` | unit: `present`, key 1–4, mouse, locked, one signal, pause blocked | SQ-03 / preview scene | 2–4 варианта; locked; signal; no QuestSystem |
| `MapScreen` flags | `test_map_system` + UI test: hidden marker absent from list/canvas | карта с флагом и без; локальная карта M1 | скрытые маркеры не видны; flags из snapshot |
| `FinalCard` | unit: present/close/return signal; integration test A04 | M1 final + tech demo final | правильный текст/флаг; R/Esc/кнопка; нет зависания |
| Pause/settings | `test_player_menu_system`/pause test; settings persist | Esc в игре; choice открыт; карта открыта | пауза не поверх модалок; captions/mono/dynamic range сохраняются; credits |
| Journal | `test_ui_demo`/journal test: 7 base, no DEMO, empty state | открыть C → задания в M1 и Лабиринте | 7/12; нет DEMO; tracking; consequence |
| Main menu | `test_main_menu` | оба входа; DEMO label; credits | оба маршрута; пометка; без demo fake |
| Subtitles | `test_dialogue`/UI test | клик/E/Space/Enter; длинная реплика | счётчик; перенос; нет input leak |
| 4K/ultrawide | нет полноценной автоматики | 1600×900, 1920×1080, 2560×1440, 3840×2160, 21:9 | нет обрезки; 14 px; контраст; screenshots |
| Inventory/Memories (P2) | `test_inventory_state` (A10) | открыть рюкзак/Памяти | state-driven; нет demo; без второго инвентаря |

### 10.1. M1 UI gate (ручной)

1. Главное меню: видна DEMO-пометка; «После Кошмара» ведёт в `police_precinct`; «Играть» — в Первый Кошмар.
2. P05–B02: в каждой сцене один HUD; цель из `CampaignGuide`; prompt/subtitles/tide работают; M открывает локальную карту; Esc — пауза; пауза закрывается.
3. Лабиринт: цель из `QuestSystem`; прилив виден; маркеры скрываются в диалоге/паузе; карта региона и flags; журнал показывает живые задания.
4. Финал M1: карточка «ПЕРВЫЙ ДЕНЬ» / «Конец M1»; R/Esc/кнопка возвращают в меню; флаг `post_nightmare_demo_completed`.
5. Tech demo: карточка «Конец демонстрационного фрагмента»; флаг `post_nightmare_completed`.
6. Все шаги — со скриншотами/логом; иначе **NOT TESTED**.

---

## 11. План ветки и слияния

### 11.1. Предусловия

- TD зафиксировал `MASTER_PLAN`, `FILE_OWNERSHIP`, `INTEGRATION_CONTRACTS`.
- TD принял/отклонил Stage 1 cross-zone правки и выдал claims.
- TD решил ключевые D-UI-01…D-UI-07 (минимум: HUD ownership, objective source, final card, scale, tests, Stage 1 claims).
- Создан интеграционный commit/чистый worktree; A08 не работает поверх чужого dirty tree.
- Если интеграционный baseline уже содержит Stage 1 HUD и вызовы `set_external_objective`, A08-01 можно начинать параллельно с A03/A04. Если baseline чистый (только HEAD), сначала должны прийти UI-EXT-04/05, иначе HUD M1 будет пустым.

### 11.2. Ветка

- Предлагаемое имя: `feature/a08-ui-m1`.
- Ветку создаёт TD от интеграционного commit; A08 работает в отдельном worktree.
- Коммиты/merge/push делает TD; A08 не коммитит (правило `FILE_OWNERSHIP`).
- Если TD делегирует коммиты, атомарные сообщения:
  1. `ui: single objective source and hud polish`
  2. `ui: add quest choice panel`
  3. `ui: respect map flags in marker list`
  4. `ui: add reusable final card`
  5. `ui: pause accessibility and credits`
  6. `ui: live-only quest journal`
  7. `ui: main menu demo label`
  8. `ui: resolution and evidence pass`

### 11.3. Состав ветки

- Только A08-файлы из §7.1.
- Shared-файлы не входят; их изменения идут отдельными задачами A00/A03/A04/A10.
- DEMO-ресурсы не удаляются; только перестают использоваться.
- `post_nightmare_objectives.tres` остаётся до решения пользователя об удалении; из кода убирается.

### 11.4. Порядок merge

1. A00 ownership/scale.
2. A03/A04 data/contracts (guide, map, final, choice backend).
3. A08 UI (HUD → choice → map → final → pause → journal → menu).
4. A09 UI cues.
5. A10 tests/evidence.
6. TD merge + M1 manual gate.

### 11.5. Definition of Done A08

- Изменены только A08-файлы; shared-правки имеют claim.
- Нет нового autoload/quest framework/inventory/HUD/interactor/tide controller.
- Targeted test запущен и приложен; если нет — **NOT TESTED**.
- Обновлены `ui_ux_design.md` и `docs/demo_sprint/audits/ui_ux.md`; нет ложного PASS.
- Скриншоты/логи приложены; ручной M1-проход отмечен честно.
- TD подтвердил интеграцию и ownership.

---

## 12. Спорные пункты, требующие решения Technical Director

| ID | Вопрос | Варианты | Рекомендация A08 | Что блокирует |
|---|---|---|---|---|
| **D-UI-01** | Кому принадлежит `scenes/quests/gameplay_hud.tscn`? | (A) carve-out A08; (B) перенести в `scenes/ui/hud/`; (C) оставить A04 и просить каждую правку | **A**: одна сцена, минимум churn, не ломает 8 ссылок | A08-01 (композиция HUD) |
| **D-UI-02** | Кто источник текста цели P05–B02? | (A) `CampaignGuide.set_external_objective` + текст A01/A03; (B) UI-таблица A08 | **A**: соответствует `MASTER_PLAN` §8; убрать A08-таблицу; A03-таблицу свести к одному тексту A01 | A08-01, UI-EXT-04, UI-EXT-09 |
| **D-UI-03** | Кому принадлежит финальная карточка? | (A) `FinalCard` A08 + интеграция A04; (B) A08 правит `scenes/campaign/**` по claim | **A**: сохраняет ownership, нет второй финальной сцены | A08-04, UI-EXT-08 |
| **D-UI-04** | Reference 1600×900 или 1920×1080? | (A) 1600 (текущий UI); (B) 1920 (`MASTER_AUDIT`) | **A**, если меню/UI уже стабильны на 1600; иначе B и A08 пересчитывает anchors. Главное — один reference | A08-07, UI-EXT-01 |
| **D-UI-05** | Снимать ли freeze с `main_menu`/`RpgMenuTheme`? | (A) точечный claim на DEMO-пометку; (B) полный рестайл | **A**: только пометка/проверка, без рестайла | A08-09 |
| **D-UI-06** | Кому принадлежат UI-тесты? | (A) A10 adopts `test_ui_demo.gd` + `tests/ui/**`; (B) carve-out A08 | **A**: A10 владеет тестами; A08 даёт acceptance matrix | A08-01…A08-12 verification |
| **D-UI-07** | Что делать со Stage 1 cross-zone изменениями? | (A) принять и передать владельцам; (B) откатить; (C) оставить как claims | **A**: принять полезное, передать A03/A04/A00/A10; A08-ветка чистая | A08-00, все A08 |
| **D-UI-08** | `PauseMenuSystem` autoload утверждён? | (A) оставить; (B) убрать/заменить | **A**: уже используется; не добавлять второй | A08-05 |
| **D-UI-09** | `QuestChoicePanel`: 2–3 или 2–4 варианта? | (A) 2–4 (SQ-03: 3 правды + locked lie); (B) 2–3 | **A**: иначе SQ-03 не реализуется; обновить `MASTER_PLAN` §8 и `AGENT_TASKS` | A08-02, A02 SQ-03 |
| **D-UI-10** | Когда журнал 7+5? | (A) M1 только 7 базовых; 5 SQ — M3; (B) 12 сразу | **A**: не блокировать M1; A08-06 сейчас, A08-06.1 после A02 | A08-06.1 |
| **D-UI-11** | Инвентарь/Памяти в M1? | (A) P2/deferred; (B) P0 | **A**: M1 не требует; не подменять demo | A08-08 |
| **D-UI-12** | Тексты и флаги финалов | (A) `DEMO-END-M1` → `post_nightmare_demo_completed`; `DEMO-END-FULL` → `post_nightmare_completed`; (B) один общий флаг | **A**: соответствует `INTEGRATION_CONTRACTS` §12.3 | UI-EXT-08, A10 final route |
| **D-UI-13** | Как показывать заблокированную ложь в SQ-03, если в схеме `QuestChoicePanel` нет `locked`? | (A) аддитивно добавить `locked: bool`, `lock_reason: String` в DP-1.1; (B) отдельный `disabled_choices`; (C) не показывать вариант | **A**: минимальное расширение, UI читает поля, A04/A02 заполняют; без него требование `side_quests.md` §11.5 невыполнимо | A08-02, UI-EXT-06, UI-EXT-10 |

### 12.1. Минимальный набор решений до старта

Если TD хочет начать A08-ветку как можно раньше, достаточно:

1. D-UI-01 — HUD scene ownership.
2. D-UI-02 — objective source (разрешить удалить A08-таблицу).
3. D-UI-03 — FinalCard split.
4. D-UI-04 — reference.
5. D-UI-06 — test ownership.
6. D-UI-07 — Stage 1 claims.
7. D-UI-09/D-UI-13 — только если A08-02 стартует до M1 gate (иначе можно позже).

Остальные можно решать параллельно; они не блокируют A08-01/A08-03.

---

## 13. Передача Technical Director

**Что передаётся:**

1. Эта спецификация.
2. Список задач A08-00…A08-13 с оценками и acceptance.
3. Список внешних задач UI-EXT-01…UI-EXT-12.
4. Спорные пункты D-UI-01…D-UI-13.
5. Явное предупреждение: **игровые файлы в Stage 2 не изменялись**; Stage 1 cross-zone изменения не считаются принятыми.

**Что нужно от TD:**

- Подтвердить/изменить ownership HUD-сцены.
- Утвердить единый источник цели и разрешить удалить UI-таблицу из кода.
- Разделить финальную карточку на A08 UI + A04 интеграцию.
- Зафиксировать reference-разрешение.
- Принять решение по DEMO-fallback, SQ-03 (2–4), тестам и Stage 1 claims.
- Выдать A08 чистую ветку/worktree и окно для работы.

**Статус доказательств:**

- Полный ручной проход M1 — **NOT TESTED**.
- Tech demo — **NOT TESTED**.
- 4K/ultrawide — **NOT TESTED**.
- Полный GUT на новой ветке — **NOT TESTED**.
- Исторические Stage 1 тесты не являются доказательством текущей ветки.

---

**Конец UI/UX implementation specification.**
