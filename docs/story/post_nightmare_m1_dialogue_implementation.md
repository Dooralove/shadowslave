# Post-Nightmare M1 — A01 implementation report

Дата: 2026-11-03

Автор: Chat 01 — Narrative & Story

Ветка: `demo/narrative`

База: `ee973250e45e8d0b661de243badce095621ffbdf`

## 1. Статус

Реализованы **диалоговые данные P0** для M1: 17 канонических `DialogueSequence` в `resources/dialogue/post_nightmare/` и 3 черновика SQ в `resources/dialogue/labyrinth/`. Дополнительно 12 legacy-файлов, которые всё ещё preload-ит текущий A03, синхронизированы с каноническим текстом как временные compatibility mirrors. Игровые сцены, скрипты, квестовые `.tres`, UI и тесты не изменялись.

Флаги и переходы **не могут выставляться из `DialogueSequence`**: это делают `QuestNpc`/`Interactable`/`QuestTriggerZone` в сценах (A03) через state (A04). Ниже — точная карта интеграции.

## 1.1. Статус задач

| Задача | Статус A01 | Что осталось |
|---|---|---|
| A01-01 P05 | данные готовы | A03: Джет у койки/зеркало/портал; A04: flags/listener |
| A01-02 P06 | данные готовы | A03: Джет у машины/КПП; A04: flags/portal gate |
| A01-03 P07 | данные готовы | A03: GateGuard/силуэт Нефис/trigger; A04: flags |
| A01-04 P08 | данные готовы | A03: терминал; A04: `dorm_assigned` |
| A01-05 P09 | данные готовы | A03: Рок/Каспер/Кассия/медик/капсула; A04: flags |
| A01-06 B01 | данные готовы | A03: статуя/Плащ/портал; A04: flags |
| A01-07 B02 | данные готовы | A03: спуск; A04: optional `tide_seen` |
| A01-08 B03 | данные готовы | A03/A04: camp trigger/first_day gate; A08: final card |
| A01-09 P1 SQ drafts | черновики готовы | `sq_fs_01_theo`/`sq_fs_03_theo` используются A02; SQ-02 echo draft ждёт точки/choice; A04/A08 choice |
| A01-10 speakers | список готов | A04-12 применить в `DialogueRunner` |

## 2. Созданные ресурсы

| Ресурс | Строк | Назначение |
|---|---:|---|
| `p05_jett_awakening.tres` | 23 | P05: Джет, `[Clear Conscience]`, ложь, три дня, Академия |
| `p05_mirror.tres` | 6 | P05: независимая тень, Shadow Sight |
| `p05_exit.tres` | 3 | P05: выход к машине |
| `p06_jett_advice.tres` | 10 | P06: три совета Джет |
| `p06_checkpoint.tres` | 4 | P06: КПП, `p06_checkpoint_passed` |
| `p06_environment.tres` | 3 | P06: опциональные barks машины/стены/вывески |
| `p07_gate.tres` | 8 | P07: проверка, молчаливый силуэт Нефис |
| `p08_campus.tres` | 4 | P08: терминал, «Sleeper Center, сектор B» |
| `p09_induction.tres` | 14 | P09: медик, Рок, Каспер, Кассия без реплик |
| `p09_time_skip.tres` | 5 | P09: текстовые карточки месяца |
| `p09_capsule.tres` | 6 | P09: капсула, «чёрная вода» |
| `b01_statue.tres` | 8 | B01: прибытие, статуя, семь звёзд, меч |
| `b01_shroud.tres` | 3 | B01: призыв `Puppeteer's Shroud` без награды |
| `b02_descent.tres` | 4 | B02: отлив, предупреждение о приливе, спуск |
| `b03_camp_night_full.tres` | 8 | Z10: полный финал с Кассией |
| `b03_camp_night_short.tres` | 6 | Z10: короткий финал без Кассии |
| `b03_m1_final_card.tres` | 3 | Текст карточки «ПЕРВЫЙ ДЕНЬ» |

Legacy compatibility mirrors (не новые канонические пути, но именно их сейчас preload-ит A03):

| Legacy | Источник |
|---|---|
| `precinct_wake.tres` | `p05_jett_awakening.tres` |
| `precinct_mirror.tres` | `p05_mirror.tres` |
| `precinct_exit.tres` | `p05_exit.tres` |
| `academy_jet.tres` | `p06_jett_advice.tres` |
| `academy_checkpoint.tres` | общий P06/P07 checkpoint (4 строки) |
| `academy_campus_guide.tres` | `p08_campus.tres` |
| `academy_julius.tres` | `p09_induction.tres` |
| `academy_capsule.tres` | `p09_time_skip.tres` + `p09_capsule.tres` (временный UI-бридж: месяц виден до капсулы) |
| `black_sea_stars.tres` | первая половина `b01_statue.tres` |
| `black_sea_sword.tres` | вторая половина `b01_statue.tres` |
| `black_sea_descent.tres` | короткий B01 descent |
| `tide_descent_warning.tres` | `b02_descent.tres` |

SQ-черновики (P1):

| Ресурс | Строк | Назначение |
|---|---:|---|
| `labyrinth/sq_fs_01_theo.tres` | 16 | SQ-01: первая встреча с Тео, принятие просьбы |
| `labyrinth/sq_fs_02_echo.tres` | 6 | SQ-02: голос Лиссы/пересмешник, draft для эхо-точек |
| `labyrinth/sq_fs_03_theo.tres` | 7 | SQ-03: возврат к Тео, вопрос «Она жива?», без выбора исхода |

Все строки имеют `duration = 0.0` (ожидание ввода игрока), кроме текстовых карточек, которые A08 может показывать как UI-текст.

## 3. Canonical speaker names

Для A04-12 в `DialogueRunner.speaker_names`:

| Canonical | Display | Legacy/alias |
|---|---|---|
| `jett` | Джет | `jet` (read-only) |
| `rock` | Рок | — |
| `kasper` | Каспер | `casper` (read-only) |
| `cassia` | Кассия | — |
| `medic` | Медик | `technician` (read-only) |
| `theo` | Тео | M3 only; в M1 не используется |
| `lissa_echo` | Эхо Лиссы | SQ-02 draft; A04 уже содержит ключ |
| `guard` | Охрана | уже есть |
| `nephis` | Нефис | уже есть |

Новые ресурсы используют только canonical `jett`; `jet` остаётся для старых файлов до миграции A04. A01 не правил `scripts/dialogue/**`.

## 4. Карта флагов для A03/A04

| Ресурс | Completion/trigger flag | Где ставится |
|---|---|---|
| `p05_jett_awakening` | `p05_jett_talked` | `QuestNpc` Джет |
| `p05_jett_awakening` | `flaw_revealed`, `flaw_clear_conscience` | listener `dialogue_finished` P05 |
| `p05_mirror` | `p05_mirror_seen` | interactable/QuestNpc зеркала |
| `p05_mirror` | `shadow_sight_unlocked` | listener P05 |
| `p05_exit` | `p05_completed` | портал P05 |
| `p06_jett_advice` | `jett_advice_heard` | `QuestNpc` Джет P06 |
| `p06_checkpoint` | `p06_checkpoint_passed` | interactable КПП P06 |
| `p07_gate` | `academy_gate_passed` | `QuestNpc`/interactable охраны |
| `p07_gate` | `nephis_seen_at_gate` | отдельный trigger у арки |
| `p08_campus` | `dorm_assigned` | терминал/проводник |
| `p09_induction` | `induction_seen` | `QuestNpc` Рока |
| `p09_induction` | `kasper_met` | listener/триггер сцены |
| `p09_induction` | `cassia_seen` | триггер у угла |
| `p09_time_skip` | `academy_month_passed` | scene controller после индукции |
| `p09_capsule` | `capsule_entered` | капсула/терминал |
| `b01_statue` | `statue_seen` | `QuestNpc`/inspectable статуи |
| `b01_shroud` | `shroud_summoned` | interactable Плаща; без повторной награды |
| `b02_descent` | `tide_seen` | optional; переход от него не зависит |
| `b03_camp_night_full/short` | `camp_night_seen` | обработчик костра после `shore_first_day_complete` |
| `b03_m1_final_card` | `post_nightmare_demo_completed` | A08/A04 final card |

`p06_environment.tres` — опциональный сценовый диалог/barks; глобальный `sunny_barks.json` не менялся, потому что `test_dialogue_barks.gd` жёстко ожидает 30 записей. A04 может либо проигрывать этот ресурс через `play_dialogue`, либо перенести три строки в новый bark context и обновить ожидание теста отдельной задачей.

## 5. Проверки

Выполнено:

- `godot --headless --path . --script C:\Users\user\AppData\Local\Temp\opencode\validate_a01_dialogues.gd` — **32/32 resources loaded, 0 failures** (17 canonical M1 + 12 legacy mirrors + 3 SQ; `academy_capsule` теперь 11 строк и содержит time-skip bridge); проверены непустые строки, speaker IDs, non-negative duration;
- `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_dialogue.gd -gexit` — **5/5 passed, 110 asserts**;
- `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_dialogue_barks.gd -gexit` — **13/15 passed, 270/272 asserts**; два падения вызваны внешними отсутствующими/битыми UID ассетами (`Rogue_Hooded.glb`, `mountain_king_v2`), не изменениями A01. Барки не менялись;
- `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_post_nightmare_locations.gd -gexit` — **2/15 passed, 510/526 asserts**; падения связаны с внешними отсутствующими `Rogue_Hooded.glb`, `statue_knight_colossus*.glb`/LOD и UID, не с диалоговыми ресурсами A01.

Не проверено:

- полный `--import`/`--editor --quit` — команда не завершилась за 240 с и была остановлена по таймауту; **NOT TESTED** (ресурсы отдельно загружены валидатором);
- интеграция ресурсов в P05–B03 (A03 ещё не подключил новые пути) — **NOT TESTED**;
- флаги/повторный вход в сценах — **NOT TESTED**, зависят от A03/A04;
- полный GUT — **NOT TESTED**;
- ручной проход M1 — **NOT TESTED**.

## 6. Блокеры/зависимости

1. **A03** ещё preload-ит legacy `precinct_wake.tres`, `academy_jet.tres`, `academy_checkpoint.tres`, `academy_julius.tres`, `academy_capsule.tres`, `black_sea_*`, `tide_descent_warning.tres`; их **содержимое синхронизировано** с canonical, поэтому текст уже попадает в игру. Для устранения дублирования A03 должен перейти на canonical-пути; точный список — `docs/story/a01_integration_proposal.md`.
2. **A03/A04** должны добавить camp-night обработчик у костра Z10; без него `b03_camp_night_*` и финальная карточка не запускаются.
3. **A04-12** должен сохранить canonical speakers `jett`, `rock`, `kasper`, `medic`, `theo`, `lissa_echo`; иначе имена отобразятся как сырые StringName.
4. **A04/A08** должны реализовать choice после `sq_fs_03_theo.tres` (`truth`/`partial`/`unknown` → `sq_fs_03_resolved`); диалог намеренно заканчивается вопросом, а не исходом.
5. **A08** должен использовать `b03_m1_final_card.tres`/`p09_time_skip.tres` для карточек или утвердить собственные тексты.

## 6.1. Stage 4 audit

Дополнительно проверено:

- **нереализованное состояние:** P09 `academy_month_passed`/time-skip отсутствует в текущем A03; camp night отсутствует в B03; `b01_shroud` не проигрывается в A03 (только флаг).
- **недостающие переходы:** P07 использует общий `academy_checkpoint` (теперь синхронизирован, но не отдельный `p07_gate`); P09 использует `academy_julius` вместо `p09_induction` (содержимое синхронизировано); B01 shroud не имеет диалога. В legacy `academy_capsule` добавлен time-skip bridge, но canonical `academy_month_passed` всё ещё должен ставить A03.
- **незавершённые сценарии:** SQ-03 заканчивается вопросом, выбор и `sq_fs_03_resolved` должны быть добавлены A04/A08; SQ-01 tone-choice (вода/группа/уйти) в драфте не ветвится; SQ-02 echo draft пока не подключён к эхо-точкам.
- **сохранение:** A01 не пишет state; флаги/идемпотентность зависят от A03/A04. `NightmareRunState` уже хранит флаги и квесты; новых полей A01 не требует.
- **визуальные/ресурсные пробелы:** нет новых моделей; A06 placeholders. A01 не создаёт альтернативные UI/сцены.
- **финальная карточка:** текущий A08-вариант в `demo-08` показывает общий «Конец демонстрационного фрагмента» и всегда ставит `post_nightmare_completed`; для M1 нужен текст «ПЕРВЫЙ ДЕНЬ»/«Конец M1» и `post_nightmare_demo_completed`. A01 передал `b03_m1_final_card.tres`, но UI должен ветвить режим.
- **использование контента:** `sq_fs_01_theo.tres` и `sq_fs_03_theo.tres` уже являются путями в `LabyrinthNarrativeDirector` A02; после merge они начнут использоваться. M1-текст уже попадает в текущий A03 через legacy mirrors; canonical-пути ждут path migration.

## 6.2. Stage 7 quality pass

Исправлены наиболее заметные для игрока места, которые можно было исправить только в A01-owned dialogue data:

- **P09 time-skip bridge:** legacy `academy_capsule.tres` теперь начинается с «МЕСЯЦ В АКАДЕМИИ» и 5 строк перехода, затем идёт капсула. Это устраняет визуальный провал «индукция → сразу капсула» в текущем A03; canonical `academy_month_passed` всё ещё должен ставить A03.
- **B01 shroud continuity:** legacy `black_sea_descent.tres` теперь acknowledges «Плащ лёг на плечи» перед спуском; сам shroud interactable всё ещё должен проигрывать `b01_shroud` (A03).
- **P06 environment feedback:** legacy `academy_jet.tres` дополнен тремя мыслями о машине/стене/Академии. Это даёт видимый payoff вместо неиспользуемого `p06_environment.tres`; canonical p06 advice остаётся отдельным.
- Все изменения — compatibility mirrors; canonical resources остаются источником для миграции A03.

## 7. Границы

A01 не менял: `scenes/**`, `scripts/**`, `resources/quests/**`, `tests/**`, `project.godot`, `docs/demo_sprint/**`. Все изменения — в `resources/dialogue/post_nightmare/**`, `resources/dialogue/labyrinth/sq_fs_*.tres` и отчётах в `docs/story/**`.
