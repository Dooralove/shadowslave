# A01 → A03/A04/A08 integration proposal

Дата: 2026-11-03

Автор: Chat 01 — Narrative & Story

Статус: **proposal**, не правка чужих файлов. A01 не менял сцены/скрипты/UI.

## 1. Почему это нужно

A01 создал канонические диалоги в `resources/dialogue/post_nightmare/` и `resources/dialogue/labyrinth/`. Текущая реализация A03 всё ещё preload-ит legacy-файлы; они синхронизированы с canonical как временные compatibility mirrors, поэтому текст уже попадает в игру. Но дублирование нужно убрать миграцией путей, иначе canonical-файлы останутся неиспользуемым источником.

## 2. A03 — точные замены

### P05 `scripts/locations/post_nightmare/police_precinct.gd`

| Сейчас | Заменить на |
|---|---|
| `precinct_wake.tres` | `p05_jett_awakening.tres` |
| `precinct_mirror.tres` | `p05_mirror.tres` |
| `precinct_exit.tres` | `p05_exit.tres` |

Текущая логика уже правильная по смыслу: Jett interact → `_play_wake_once()` → `p05_jett_talked`; mirror → `p05_mirror_seen`; portal required `[p05_jett_talked, p05_mirror_seen]`, set `p05_completed`. После замены путей она начнёт использовать канонические тексты. Дополнительно: `flaw_revealed`/`flaw_clear_conscience`/`shadow_sight_unlocked` нужно выставлять после соответствующего диалога (сейчас A03 ставит только `p05_jett_talked`/`p05_mirror_seen`).

### P06 `scripts/locations/post_nightmare/academy_approach.gd`

| Сейчас | Заменить на |
|---|---|
| `academy_jet.tres` | `p06_jett_advice.tres` |
| `academy_checkpoint.tres` | `p06_checkpoint.tres` |

Текущий `JetTrigger`/`_on_jet_triggered` и `CheckpointInteract` уже ставят `jett_advice_heard`/`p06_checkpoint_passed`; portal already requires `jett_advice_heard`. Legacy `academy_jet.tres` уже содержит три мысли о машине/стене/Академии для текущего A03; canonical `p06_environment.tres` — optional для будущих отдельных barks, без нового HUD.

### P07 `scripts/locations/post_nightmare/academy_gate.gd`

| Сейчас | Заменить на |
|---|---|
| `academy_checkpoint.tres` | `p07_gate.tres` |

Текущий `GateGuard`/`NephisSilhouette`/`NephisGateTrigger` уже ставит `academy_gate_passed` и `nephis_seen_at_gate`; портал требует `academy_gate_passed`. После замены P07 получит правильную реплику «Стоять. Имя и статус» и молчаливый силуэт Нефис, а не общий checkpoint P06.

### P08 `scripts/locations/post_nightmare/academy_campus.gd`

| Сейчас | Заменить на |
|---|---|
| `academy_campus_guide.tres` | `p08_campus.tres` |

Терминал уже выдаёт `dorm_assigned`, портал требует флаг. `CampusGuide` можно оставить optional; канон — терминал. Если оставляете проводника, он должен проигрывать тот же `p08_campus` или короткую отдельную реплику, но не создавать второй флаг.

### P09 `scripts/locations/post_nightmare/academy_sleeper_center.gd`

| Сейчас | Заменить на |
|---|---|
| `academy_julius.tres` | `p09_induction.tres` |
| `academy_capsule.tres` | `p09_capsule.tres` |

Текущая сцена уже расставляет медика, Рока, Каспера, Кассию и ставит `induction_seen`/`kasper_met`/`cassia_seen`; капсула требует `induction_seen`, портал требует `[induction_seen, capsule_entered]`.

**Чего не хватает:** после `_on_rock_interacted`/`induction_seen` должен один раз проигрываться `p09_time_skip.tres` и ставиться `academy_month_passed`. Без этого P09 не объясняет переход «индукция → капсула» и теряет канонический месяц. Рекомендуемая точка: сразу после окончания induction-диалога, до включения капсулы. `QuestNpc`/interactable не должен повторять таймскип при повторном входе.

### B01 `scripts/locations/post_nightmare/black_sea_platform.gd`

| Сейчас | Заменить/добавить |
|---|---|
| `black_sea_stars.tres` | `b01_statue.tres` (первый осмотр) |
| `black_sea_sword.tres` | `b01_statue.tres` только если флаг `statue_seen` ещё не выставлен; иначе короткая реплика/без повтора |
| `black_sea_descent.tres` | `b02_descent.tres`? Нет: спуск B01 остаётся коротким; `b02_descent` — сцена `tide_descent` |
| `_on_shroud_interacted()` | добавить `play_dialogue(b01_shroud.tres)` и `shroud_summoned` |

Текущий shroud interactable только ставит флаг и не показывает текст. Нужно проиграть `b01_shroud.tres` один раз; награды нет, `Puppeteer's Shroud` не выдаётся повторно. Портал уже требует `[statue_seen, shroud_summoned]`. Legacy `black_sea_descent.tres` уже acknowledges Плащ перед спуском, но это не заменяет immediate feedback при нажатии «Призвать Плащ».

### B02 `scripts/locations/post_nightmare/tide_descent.gd`

| Сейчас | Заменить на |
|---|---|
| `tide_descent_warning.tres` | `b02_descent.tres` |

Текущий trigger уже ставит `tide_seen`; портал требует `b01_completed`. Переход не должен требовать `tide_seen`.

### B03 `scripts/locations/forgotten_shore_labyrinth/labyrinth_quest_director.gd`

Нужно добавить camp-night обработчик (A03/A04 shared):

1. При взаимодействии с костром после `shore_first_day_complete`:
   - если `cassia_met` → `b03_camp_night_full.tres`;
   - иначе → `b03_camp_night_short.tres`;
   - поставить `camp_night_seen` один раз.
2. Не запускать camp night без `shore_first_day_complete`.
3. После `camp_night_seen` показать M1 final card (`b03_m1_final_card.tres` + A08 UI), поставить `post_nightmare_demo_completed`.
4. Существующий `camp_rest`/`CP-SHORE-CAMP` не дублировать; camp night — не новый квест.

## 3. A04 — speaker names

В `scripts/dialogue/dialogue_runner.gd` уже есть (в A04 worktree) `jett`, `jet`, `rock`, `kasper`, `casper`, `theo`, `lissa_echo`. Нужно сохранить эти записи при merge; A01 ресурсы используют `jett`, `rock`, `kasper`, `medic`, `theo`, `lissa_echo`. Если merge пойдёт из базы без A04, добавить как минимум:

```text
jett: Джет
jet: Джет (legacy read-only)
rock: Рок
kasper: Каспер
casper: Каспер (legacy read-only)
medic: Медик
technician: Медик (legacy read-only)
theo: Тео
lissa_echo: Эхо Лиссы
```

## 4. A08 — UI-карточки

- `p09_time_skip.tres` — 5 строк; можно показать как последовательность карточек/субтитров, не как одну длинную реплику. В legacy `academy_capsule.tres` уже добавлен временный time-skip bridge перед капсулой; A03 всё равно должен ставить `academy_month_passed`.
- `b03_m1_final_card.tres` — заголовок «ПЕРВЫЙ ДЕНЬ», текст и «Завтра — запад».
- Текущий `post_nightmare_finale.tscn` в `demo-08` показывает общий «Конец демонстрационного фрагмента» и ставит `post_nightmare_completed`; для M1 нужен отдельный title/body/hint и `post_nightmare_demo_completed`. A04-вариант уже выбирает флаг по `demo_mode_m1`; A08 должен ветвить текст.
- Финальная карточка должна ставить `post_nightmare_demo_completed` и возвращать в меню; не показывать её без `shore_first_day_complete` + `camp_night_seen`.
- A01 не менял `scenes/ui/**`.

## 5. A02 — SQ dialogue

A02 `LabyrinthNarrativeDirector` уже ищет:

- `res://resources/dialogue/labyrinth/sq_fs_01_theo.tres` — **создан A01**;
- `res://resources/dialogue/labyrinth/sq_fs_03_theo.tres` — **создан A01**.

`sq_fs_02_echo.tres` создан как draft для эхо-точек; A02/A04 может использовать его на `SQ_FS_02/Echo*` или в `QuestInspectable`, но это не обязательно для прохождения. `sq_fs_01_theo` заканчивается принятием просьбы; `sq_fs_03_theo` заканчивается вопросом «Она жива?» и **не** выбирает исход. A04/A08 choice должен выставить один из флагов:

- `sq_fs_03_choice_truth` — прямое «Нет. Она мертва.»;
- `sq_fs_03_choice_partial` — «Я нашёл только её плащ.»;
- `sq_fs_03_choice_unknown` — «Я не знаю.».

Промпт: «Что сказать Тео?». После выбора — `sq_fs_03_resolved` и `notify_event("resolved", "sq_fs_03_resolved")`; A01-09 не создаёт новых глобальных флагов и не меняет `first_day`. SQ-01 tone-choice (вода/группа/уйти) остаётся в драфте без ветвления; это P1-косметика, не блокер SQ-01.

## 6. Проверки

- A01 dialogue validator: **32/32 resources loaded, 0 failures** (17 canonical M1 + 12 legacy mirrors + 3 SQ drafts).
- A01 не менял A03/A04/A08 файлы.
- Legacy mirrors синхронизированы с canonical; A03 всё ещё должен перейти на canonical-пути, чтобы не поддерживать два текста.
- Runtime M1/A02 не проверялся: **NOT TESTED**.
