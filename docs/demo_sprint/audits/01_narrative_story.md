# Narrative & Story — аудит

**Дата:** 2026-11-02  
**Автор:** Chat 01 — Lead Narrative Designer / Story Designer  
**Ветка / HEAD:** `s3-park-art` / `0335a5c346901af2146413b5a159b442d326d8de`  
**Статус:** статический аудит; игровые файлы не менялись; полный ручной проход — **NOT TESTED**.  
**Полный аудит:** `docs/demo_sprint/audits/narrative.md` (расширенная версия).  
**Предложения:** `docs/demo_sprint/design/narrative_design.md`.

## 0. Сводка

1. **Демо-стержень подтверждён:** Первый Кошмар S00–S15 — единственная законченная и подключённая сюжетная арка. Пост-Кошмар и Лабиринт narratively не готовы и не должны быть основным демо.
2. **Маршрут в целом собран:** P01–N26 связаны, ключевые гейты и финальный флаг на месте; смерти и отсутствия персонажей в основном соблюдены.
3. **N18 отсутствует в исполнении.** Beat и `CP-N18` есть, кровь/следы/`Inspectable`/мысли стоят, но после падения Шифти сцена сразу уходит в рассвет. `shifty_larva_killed` никогда не ставится; N19 обходится без N18.
4. **N07 противоречит канону.** Санни ест Bloodbane и выживает; предупреждение Учёного лежит в неиспользуемом `camp_bloodbane.tres`. Это ломает причинность отравления фляг в N13.
5. **N25 теряет первое деяние личинки.** Единственная строка `appraisal_deed_larva` скрывается, если не убита личинка Шифти; каноническое деяние первой личинки не показывается.
6. **N22/N23 дублируют «Found you».** Один из сильнейших beats произносится дважды.
7. **S08 потерял канонический обмен** «The monster ate the dead» / «How do you know?» / «I heard it».
8. **Пост-Кошмарная цепочка не имеет входа из финала** и не содержит NPC/диалогов; `coral_labyrinth` в ней — старый sandbox с неканоническим святилищем и «пустыми креслами».
9. **Квестовый слой появился параллельно, но не относится к демо.** В `scripts/quests/` и `resources/quests/` есть 7 заданий `forgotten_shore` и `QuestSystem` (autoload), однако scope активируется только в `labyrinth_first_fragment`; ни одна сцена S00–S15 его не включает. Персонажный глоссарий пуст; 30 барков не подключены.
10. **Приоритет для демо:** сначала N07/N18/N25/N22-N23 как нарративные P0; затем N16, бестиарий, P03, N09; глоссарий/барки — P2.

## 1. Метод и границы

**Прочитано:**

- `docs/story/first_nightmare_canonical_timeline.md`, `docs/research/first_nightmare/*`;
- `docs/design/first_nightmare_beat_sheet_v2.md`, `first_nightmare_restoration_spec.md`, `first_nightmare_scene_matrix.md`, `first_nightmare_route_verification.md`, `first_nightmare_prototype_flow.md`;
- `docs/DECISIONS.md` (D01–D14, флаги, гейты);
- `scripts/campaign/*`, `scripts/slice/*`, `scenes/campaign/*`, `scenes/slice/*`, `scenes/locations/*`;
- `resources/dialogue/**/*.tres` (47 последовательностей, 232 строки);
- `resources/campaign/**/*.tres`, `resources/spell/*.tres`, `data/dialogues/sunny_barks.json`;
- `docs/research/post_first_nightmare_dream_realm/07_gameplay_adaptation.md` и пост-Кошмарные сцены — как отдельный, не входящий в демо прототип.

**Не запускалось в этой сессии:**

- полный GUT и целевые тесты;
- кампания, сцены и переходы в живом окне;
- ручной проход, бой, звук, VO, субтитры, тайминги.

**Базовая линия TD:**

- HEAD `0335a5c`;
- импорт — exit 0;
- GUT — 74 скрипта, 577 тестов, 575 pass, 2 fail, 6857/6869 assert, exit 1;
- оба падения — `test_post_nightmare_locations.gd` (старый контракт `greybox` против нового `StatueKnightLOD`);
- главное меню и `campaign_entry` запускаются; полный проход — **NOT TESTED**.

Цифры baseline не перепроверялись в этой сессии; они взяты из `docs/demo_sprint/BASELINE.md`.

**Живое дерево.** Во время аудита параллельно появились `scripts/quests/*`, `resources/quests/*`, `QuestSystem` в autoload и `labyrinth_quest_director.gd`. Их текущее состояние проверено статически; runtime и GUT для них — **NOT TESTED**. К S00–S15 они не подключены.

## 2. Фактическое состояние

| Элемент | Файл | Что реально есть | Чего нет |
|---|---|---|---|
| P01–P04 | `scripts/slice/slice_director.gd` | Скамейка → участок → изолятор → видение → руны; B01–B16 | Нет ответа о Рейн; брифинг сжат |
| N05–N06 | `prologue.tscn`, `first_nightmare_pass.tscn` | Руны, марш, четыре барка, прибытие, коридор цепи и рывки | Нет подключённых барков; нет физики натяжения/падений соседей |
| N07 | `caravan_site_arrival.tscn` | Паёк, ягоды, узнавание, атака | Нет предупреждения Bloodbane; Санни ест ягоды; узнавание в основном флаг |
| N08–N10 | `caravan_site_arrival.tscn` | Камнепад, Тиран, личинка, ключ, вторая личинка, повозка | N09 может приписать убийство Герою, если добил игрок |
| N11–N13 | `caravan_site_arrival.tscn` | Совет, фляги, ветеран, Silver Bell, ночь, рассвет | Отравление — постановка без выбора (D06, допустимо) |
| N14–N17 | `pilgrim_path_arrival.tscn` | Провал, меч, альков, слепота, падение Шифти | Нет канонического обмена о слепоте |
| N18 | `pilgrim_path_arrival.tscn` | Beat, `CP-N18`, кровь, следы, `Inspectable`, мысли, бестиарий | Нет арены, личинки, боя, `shifty_larva_killed`, гейта N19 |
| N19–N23 | `pilgrim_path_arrival.tscn` | Учёный, пещера, стелс, колокольчик, подъём, страж | Дубль «Found you»; Учёный открывается без N18; страж спорит с текстом |
| N24 | `sanctuary_arrival.tscn` | Семь сообщений, Тиран, тени, три сообщения | Мёртвая карточка «Первый Кошмар пройден» в сцене |
| N25 | `appraisal_arrival.tscn` | Shroud, glorious, True Name, Shadow Slave, Shadow Bond, First Seal | Первая личинка теряется; Auro/тиран/благословение не гейтятся по флагам |
| N26 | `finale_arrival.tscn` | Shadow Core, Shadow Control, Flaw без имени, карточка, `R` | Нет `flaw_received` (опционально) |
| Пост-Кошмар | `scenes/locations/post_nightmare/*` | Восемь greybox-локаций, порталы | Вход из финала, NPC, диалоги, триггеры, сюжет |
| Лабиринт | `labyrinth_first_fragment` | Частичный quest/NPC-слой, Nephis/Cassia, портал в `tide_descent` | Нет входа из `tide_descent`/кампании; не входит в демо |
| Квесты | `scripts/quests/`, `resources/quests/` | 7 `QuestDefinition` (`forgotten_shore`), `QuestSystem` (autoload), `QuestCatalog`, `LabyrinthQuestDirector` | Scope активируется только в `labyrinth_first_fragment`; нет активации в S00–S15; задания не про Первый Кошмар |
| Глоссарий персонажей | `resources/campaign/glossary/characters/` | README и `.gitkeep` | Записи |
| Барки | `data/dialogues/sunny_barks.json`, `BarkUI` | 30 строк, UI-сцена | Инстанс UI, вызовы, `auto_barks = false` |

## 3. Расхождения «документ ↔ реализация»

| Документ | Утверждение | Факт | Риск |
|---|---|---|---|
| `README.md` | 35 скриптов / 255 тестов; страж храма B3 не реализован | Baseline: 74 / 577; страж-триггер и визуальное искажение есть, финального визуала нет | Нельзя доверять статусу «готово» |
| `first_nightmare_scene_matrix.md` | Все 20 блоков имеют реализацию | N18 (утверждённый D10) не имеет игровой сцены | Демо выглядит сломанным в середине |
| `first_nightmare_route_verification.md` | 18 шагов покрывают маршрут | Шаг 12–13 перескакивает N18 | Тест не ловит главный narrative gap |
| `playtest_checklist.md` | N18 нужно проверить вручную | Сцены нет | Чек-лист требует невозможного |
| `DECISIONS.md` | D10 утверждён; `defeated_larva()` зависит от `shifty_larva_killed` | Флаг нигде не ставится; первая личинка потеряна | D14 не доставлен |
| `level_transitions.md` | Пост-Кошмарная цепочка подключена | `finale.gd` не ссылается на `police_precinct`; связи только внутри цепочки | Игрок не может продолжить после финала |
| `first_nightmare_restoration_spec.md` | S02 требует предупреждение Bloodbane | `camp_berries` — Санни ест ягоды; `camp_bloodbane` не используется | Канон и логика яда нарушены |
| `first_nightmare_restoration_spec.md` | S08 требует обмен о слепоте | В `pilgrim_alcove`/`pilgrim_shifty` обмена нет | Потерян характерный beat |
| `level_brief_labyrinth_first_fragment.md` | Не добавлять святилище, алтарь, звезду, пустые кресла | `coral_labyrinth.gd` содержит всё перечисленное | В кампании показывается неканонический sandbox |
| `00_DEMO_SCOPE_AND_CONTRACT.md` | Quest Framework — stretch, не стержень | 7 заданий и `QuestSystem` уже созданы; scope активен только в `labyrinth_first_fragment`, не в S00–S15 | При случайной активации в демо внешняя цель перекроет beat-цель |

## 4. Готовность к демо

| Область | Готовность | Что нужно для P0 |
|---|---:|---|
| Пролог P01–P04 | 85% | P03: ответ о Рейн; проверка текста |
| Цепь N05–N10 | 75% | N07 Bloodbane; N09 атрибуция; N10 visual-проверка |
| Ночь N11–N13 | 85% | Проверка монтажа и флагов; без блокеров |
| Подъём N14–N17 | 70% | S08 обмен; читаемость тёмных мест (03/07) |
| N18 | **10%** | Арена, личинка, бой/сброс, флаг, гейт N19 |
| N19–N23 | 70% | Гейт N19, один «Found you», страж |
| N24 | 85% | Убрать мёртвую карточку; визуал теней (07) |
| N25 | 65% | Разделить деяния личинок; гейты строк |
| N26 | 90% | Финальная карточка и `R` (проверка 01/08) |
| Пост-Кошмар | 5% | Не входит в демо; отдельный stretch |
| Квесты/глоссарий/барки | 5–15% | Quest Framework частичный, активен только в Лабиринте; глоссарий пуст; барки не подключены; P2, не блокирует стержень |

## 5. P0 / P1 / P2

> Здесь **P0** — нарративный приоритет, а не release gate TD. Для проходимости S00–S15 ни один из этих пунктов не обязан быть закрыт: маршрут доходит до финала и без N18. Но демо нельзя показывать как «историю без дыр», пока они открыты.

### P0 — нарративная целостность

1. **N07:** убрать поедание Bloodbane; вернуть предупреждение Учёного; `camp_bloodbane_seen` ставить после предупреждения.
2. **N18:** добавить сцену личинки Шифти (утверждённое D10, не канон); ставить `shifty_larva_killed`; открыть N19 только по нему. Если TD не берёт N18 в 3-часовой спринт, **не добавлять гейт N19** отдельно — это даст soft-lock; оставить gap и не выдавать его за норму.
3. **N25:** первая личинка — всегда по `larva_killed`; личинка Шифти — отдельная строка.
4. **N22/N23:** оставить один «Found you»; согласовать стража.

### P1 — заметно улучшает демо

5. **N16:** добавить «The monster ate the dead» / «How do you know?» / «I heard it».
6. **Бестиарий:** открывать «Горного Короля» по `tyrant_sighting_seen`, а не по `stealth_completed`.
7. **N09:** запретить игроку добивать вторую личинку или добавить альтернативный диалог.
8. **P03:** добавить уклончивый ответ о сестре.
9. **N23:** не называть стража невидимым, если он визуально читается; не делать боссом.
10. **N07:** перенести `camp_hero_gaze` в конец N07, чтобы узнавание и гром были до атаки.

### P2 — после демо

11. Глоссарий персонажей (6–8 записей).
12. Подключение 30 барков.
13. Побочные наблюдения (кольца Шифти, своя фляга, колокольчик, слепота).
14. Пост-Кошмарная цепочка P01–P09/B01–B05.
15. Замена/подключение нового `labyrinth_first_fragment`.
16. Синхронизация `README`, `scene_matrix`, `route_verification`, `playtest_checklist`.
17. Quest Framework: scope/UI-контракт и 7 заданий `forgotten_shore` уже есть; подключать к демо только как stretch, не в S00–S15.

## 6. Владение файлами

**Готов взять как Narrative (01):**

- `resources/dialogue/**` — новые и исправленные последовательности;
- `resources/spell/**` — строки алтаря/оценки/пробуждения;
- `data/dialogues/**` — барки;
- `docs/story/**`, `docs/design/first_nightmare_*` — только текст/канон;
- `docs/demo_sprint/audits/narrative.md`, `docs/demo_sprint/audits/01_narrative_story.md`, `docs/demo_sprint/design/narrative_design.md`.

**Требует владельца / TD:**

- `scenes/locations/**`, `scripts/locations/**` — 03 World & Level: арена N18, точка крови, триггеры, коллизии.
- `resources/campaign/beats/**`, `resources/campaign/bestiary/**`, `resources/campaign/journal/**`, `scripts/campaign/**`, `scripts/guide/**` — 04 Gameplay & Quest Systems: гейт N19, `appraisal.gd`, `campaign_guide.gd`, beat-ресурсы.
- `scripts/combat/**`, `scenes/enemies/**`, `resources/combat/**` — 05 Combat & Enemy AI: личинка, урон, поведение.
- `scripts/quests/**`, `resources/quests/**` — 02 Side Quest Design / 04: квестовый слой; Narrative его не активирует и не переписывает.
- `resources/campaign/glossary/**` — 08 UI/UX: формат и отображение; тексты пишет 01.
- `tests/**` — 10 QA & Release.

**Не трогать:** `project.godot`, `NightmareRunState`, `CampaignGuide`, карты, квестовый фреймворк, персонажные ассеты, art-сцены, sandbox, пост-Кошмар.

## 7. Риски интеграции

| Риск | Вероятность | Влияние | Смягчение |
|---|---|---|---|
| N18 добавят как гейт без сцены | средняя | **soft-lock** после N17 | сначала сцена, потом гейт; тест «без N18 N19 закрыт» |
| N07 исправят только текст, но оставят вызов `camp_berries` | высокая | ошибка останется | заменить ссылку/ресурс и проверить порядок вызовов |
| N25 изменит тесты `test_appraisal_dormant_humans` | средняя | красный GUT | обновить ожидания вместе с 10 |
| N18 потребует новой геометрии | средняя | выход за 3 часа | использовать существующие `ShiftyLedge`/кровь/следы; минимальная арена |
| Пост-Кошмар уведёт силы | средняя | стержень не готов | не включать в P0; stretch только после зелёного S00–S15 |
| QuestSystem активируют в демо | средняя | внешняя цель перекроет beat-цель | не активировать scope в S00–S15 до TD; задания только для `forgotten_shore` |
| QuestSystem autoload ломает старт | низкая–средняя | демо не запустится | импорт/целевой тест `quests`; autoload не должен требовать сценовых узлов |
| Документы противоречат коду | высокая | спорная приёмка | синхронизировать после P0, одной записью |

## 8. Проверки

**Реально выполнено в этой сессии:**

- статическое чтение документов, сцен, скриптов и ресурсов;
- подсчёт диалогов: 47 последовательностей, 232 строки;
- сверка beat-условий, флагов и фактических вызовов;
- проверка наличия/отсутствия N18, пост-Кошмарной связи, глоссария, квестового слоя и барков.

**Не выполнялось:**

- полный GUT и целевые тесты — **NOT TESTED**;
- запуск кампании и ручной проход — **NOT TESTED**;
- бой, звук, VO, субтитры — **NOT TESTED**;
- Quest Framework (7 заданий `forgotten_shore`) — **NOT TESTED**;
- пост-Кошмар и Лабиринт — **NOT TESTED**.

## 9. Ссылки

- Полный аудит: `docs/demo_sprint/audits/narrative.md`
- Дизайн-предложение: `docs/demo_sprint/design/narrative_design.md`
- Демо-контракт: `docs/demo_sprint/design/00_DEMO_SCOPE_AND_CONTRACT.md`
- Владение: `docs/demo_sprint/OWNERSHIP.md`
- Канон: `docs/story/first_nightmare_canonical_timeline.md`
- Beat sheet: `docs/design/first_nightmare_beat_sheet_v2.md`
- Спецификация: `docs/design/first_nightmare_restoration_spec.md`
- Решения: `docs/DECISIONS.md`
