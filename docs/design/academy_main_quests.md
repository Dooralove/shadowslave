# Академия Пробуждённых — основные квесты (M2-full)

Дата: 2026-11-03  
Статус: **design-only. Код, сцены и ресурсы не изменялись. Runtime — NOT TESTED.**  
Область: 12 основных квестов главы, от ворот до капсулы.  
Связанные документы:

- `docs/design/academy_chapter_roadmap.md` — сюжетный roadmap.
- `docs/design/academy_location_map.md` — карта.
- `docs/design/academy_side_quests.md` — побочные квесты.
- `scripts/quests/quest_definition.gd`, `quest_objective.gd`, `quest_reward.gd`.
- `scripts/quests/quest_system.gd`, `quest_npc.gd`, `quest_pickup.gd`, `quest_trigger_zone.gd`.
- `docs/demo_sprint/design/side_quests.md` — формат описания квестов.

---

## 0. Как читать документ

### 0.1. Термины

| Термин | Значение |
|---|---|
| **MQ** | Main Quest, основной квест. |
| **SQ** | Side Quest, побочный квест. |
| **Phase** | Фаза главы: `arrival`, `induction`, `week_one`, `week_two`, `solstice`. |
| **Flaw-сцена** | Сцена, где Санни не может лгать и игрок выбирает форму правды. |
| **Reputation flag** | Флаг `ac_rep_*`, а не числовая шкала. |
| **Access flag** | Флаг доступа (`room_key`, `library_pass`, `dojo_token`, `maintenance_key`). |
| **Knowledge flag** | Флаг знания/способности (`shadow_scout`, `star_navigation`, `dead_languages`, `parry_basics`, `flaw_control`). |

### 0.2. Формат квеста

Каждый MQ описан по схеме:

1. Паспорт (ID, фаза, локация, канон, длительность).
2. История (2–4 предложения).
3. Цели (`QuestObjective`).
4. Последовательность.
5. Flaw/выбор.
6. Награды.
7. Провал/soft-lock.
8. Реализация.
9. Приёмка.

### 0.3. Общие правила

1. **Никакого провала.** Основные квесты не имеют состояния `FAILED`; `QuestSystem` знает только `active`/`completed`.
2. **Никакой лжи.** В Flaw-сценах вариант «соврать» отключён; игрок выбирает форму правды или молчание.
3. **Никаких Памятей и кристаллов.** Академия — реальный мир; награды — знания, доступ, мелкое снаряжение и credits.
4. **Никакого гринда.** Каждый MQ — один сюжетный бит; повторяемых задач нет.
5. **Совместимость с M1.** Существующие флаги `academy_gate_passed`, `dorm_assigned`, `induction_seen`, `capsule_entered` остаются; новые MQ их читают и пишут, но не переименовывают.
6. **Один активный трек.** `NightmareRunState.tracked_quest` показывает текущий MQ; журнал доступен.

---

## 1. Критический путь

```text
MQ-01 Красные ворота
  └─ MQ-02 Город в городе
       └─ MQ-03 Индукция
            └─ MQ-04 Первая ночь
                 └─ MQ-05 Расписание и интервью
                      ├─ MQ-06 Имя на табло
                      ├─ MQ-07 Уроки выживания
                      ├─ MQ-08 Мера силы
                      └─ MQ-09 Тень в коридорах
                           ├─ MQ-10 Спарринг
                           └─ MQ-11 Ночь шторма
                                └─ MQ-12 Семнадцать
                                     └─ капсула → B01
```

MQ-06, MQ-07, MQ-08 можно проходить в любом порядке после MQ-05. MQ-09 требует `shadow_sight_unlocked`. MQ-10 требует MQ-08. MQ-11 требует MQ-09 и MQ-10. MQ-12 требует MQ-11.

---

## 2. Индекс квестов

| ID | Название | Фаза | Где | Канон | Длительность | Ключевая награда |
|---|---|---|---|---|---:|---|
| `ac_mq_01_red_gate` | Красные ворота | arrival | A1 | гл. 19 | 3–4 мин | `academy_pass` |
| `ac_mq_02_city_within` | Город в городе | arrival | A2/A3 | гл. 19–20, 24 | 5–7 мин | `room_key`, форма |
| `ac_mq_03_induction` | Индукция | induction | A2b/A3 | гл. 20–23 | 6–8 мин | `academy_schedule` |
| `ac_mq_04_first_night` | Первая ночь | induction | A3 | гл. 18, 24 | 5–6 мин | `rest_unlocked` |
| `ac_mq_05_schedule` | Расписание и интервью | week_one | A6 | гл. 24 | 6–8 мин | `library_pass` |
| `ac_mq_06_true_name` | Имя на табло | week_one | A4 | гл. 25 | 5–6 мин | `nephis_true_name_seen` |
| `ac_mq_07_wilderness` | Уроки выживания | week_one | A6 | гл. 25, 28 | 8–10 мин | `star_navigation`, `firemaking`, `water_finding` |
| `ac_mq_08_measure` | Мера силы | week_one | A5 | гл. 26 | 6–8 мин | `training_blade`, `parry_basics` |
| `ac_mq_09_shadow` | Тень в коридорах | week_one | A3/A8 | гл. 26, 28 | 8–10 мин | `shadow_scout` |
| `ac_mq_10_sparring` | Спарринг | week_two | A5 | гл. 27 | 8–10 мин | `immortal_flame_known` |
| `ac_mq_11_storm` | Ночь шторма | week_two | A3/A8 | ИНТЕРПРЕТАЦИЯ | 8–10 мин | `field_medkit`, репутация |
| `ac_mq_12_last_day` | Семнадцать | solstice | A4/A6/A7/A3 | гл. 29 | 15–20 мин | `academy_complete`, финал |

---

## 3. MQ-01 — Красные ворота

### 3.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_mq_01_red_gate` |
| Название | Красные ворота |
| Фаза | `arrival` |
| Локация | A1 Gate Plaza |
| Giver | `gate_guard` |
| Канон | Глава 19 |
| Prerequisites | `p06_completed` или старт главы |
| Completion flag | `ac_mq_01_complete` |
| Длительность | 3–4 мин |

### 3.2. История

Санни выходит из машины Джет и идёт к Академии. Это не школа, а режимный объект: стена, ров, турели, красные ворота. Охрана проверяет имя и статус. Пока терминал гудит, у арки проходит девушка с серебряными волосами. Она не оглядывается.

### 3.3. Цели

| # | Objective ID | Kind | Target ID | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `reach_gate` | REACH | `academy_gate_plaza` | да | «Дойти до красных ворот» |
| 2 | `talk_guard` | TALK | `gate_guard` | да | «Пройти проверку» |
| 3 | `see_nephis` | FLAG | `nephis_seen_at_gate` | нет | «Заметить серебряные волосы» |
| 4 | `enter_campus` | REACH | `academy_campus_entry` | да | «Войти в кампус» |

### 3.4. Последовательность

1. Игрок идёт по мосту; камера показывает ров, турели и красные створки.
2. У КПП `QuestNpc` `gate_guard` с диалогом `ac_mq01_gate.tres`.
3. Охрана спрашивает имя и статус; Санни отвечает правду.
4. Триггер `nephis_gate_trigger` показывает силуэт Нефис; она уходит.
5. Ворота открываются; `REACH` `academy_campus_entry` завершает квест.
6. Цель меняется на «Найти Sleeper Center».

### 3.5. Flaw/выбор

Нет. Это бюрократическая сцена; правда Санни здесь безопасна.

### 3.6. Награды

| Тип | Значение | Где используется |
|---|---|---|
| Flag | `academy_pass` | Доступ в кампус |
| Currency | `credits` +10 | Мелкие покупки, кофе |
| Reputation | `ac_rep_faculty_1` | Диалоги охраны/Рока |
| Flag | `academy_gate_passed` | Совместимость с M1 |

### 3.7. Провал/soft-lock

Нет. Если игрок не подходит к охране, цель ведёт к КПП. Если пытается обойти, портал закрыт.

### 3.8. Реализация

- `QuestNpc` `GateGuard` с `npc_id=gate_guard`, `start_quest_id=ac_mq_01_red_gate`, `completion_flag=academy_gate_passed`.
- `QuestTriggerZone` `NephisGateTrigger` с `quest_event=flag`, `quest_subject=nephis_seen_at_gate`.
- `QuestTriggerZone` `CampusEntry` с `quest_event=reached`, `quest_subject=academy_campus_entry`, `required_flags=[academy_gate_passed]`.
- Диалог: `resources/dialogue/academy/ac_mq01_gate.tres`.

### 3.9. Приёмка

- [ ] Игрок понимает, что Академия — режимный объект.
- [ ] Нефис появляется молча и не взаимодействует.
- [ ] Ворота открываются только после проверки.
- [ ] M1-флаг `academy_gate_passed` сохранён.

---

## 4. MQ-02 — Город в городе

### 4.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_mq_02_city_within` |
| Название | Город в городе |
| Фаза | `arrival` |
| Локация | A2 Campus, A3 Sleeper Center |
| Giver | `campus_terminal`, `sleeper_receptionist` |
| Канон | Главы 19–20, 24 |
| Prerequisites | `ac_mq_01_complete` |
| Completion flag | `ac_mq_02_complete` |
| Длительность | 5–7 мин |

### 4.2. История

Кампус оказывается городом в городе: стена, галерея, стеклянные корпуса, толпа Sleepers. Санни получает направление в Sleeper Center, форму и комнату 07. Впервые за месяц у него есть койка, шкафчик и расписание.

### 4.3. Цели

| # | Objective ID | Kind | Target ID | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `use_terminal` | INTERACT | `campus_terminal` | да | «Получить направление» |
| 2 | `reach_sleeper` | REACH | `sleeper_center_entrance` | да | «Найти Sleeper Center» |
| 3 | `register` | TALK | `sleeper_receptionist` | да | «Зарегистрироваться» |
| 4 | `get_room` | FLAG | `room_key` | да | «Получить комнату» |
| 5 | `see_dining` | REACH | `dining_hall_door` | нет | «Заметить столовую» |
| 6 | `see_dojo` | REACH | `dojo_door` | нет | «Заметить додзё» |

### 4.4. Последовательность

1. Игрок входит в кампус; галерея ведёт на север.
2. Терминал у развилки выдаёт «Sleeper Center, сектор B».
3. По пути можно осмотреть столовую и додзё (двери закрыты).
4. У стойки регистрации — `QuestNpc` `sleeper_receptionist`.
5. Санни получает форму, комнату 07 и расписание.
6. Цель меняется на «Пройти индукцию».

### 4.5. Flaw/выбор

Нет. Регистрация — бюрократия, не конфликт.

### 4.6. Награды

| Тип | Значение | Где используется |
|---|---|---|
| Item | `academy_uniform` | Косметика, форма |
| Flag | `room_key` | Комната 07 |
| Currency | `credits` +15 | Кофе, мелочи |
| Reputation | `ac_rep_faculty_1` | Диалоги |
| Flag | `dorm_assigned` | Совместимость с M1 |

### 4.7. Провал/soft-lock

Нет. Если игрок не идёт к терминалу, цель ведёт к нему. Двери столовой/додзё не блокируют MQ.

### 4.8. Реализация

- `Interactable` `CampusTerminal`, `interaction_id=campus_terminal`.
- `QuestNpc` `SleeperReceptionist`, `npc_id=sleeper_receptionist`, `start_quest_id=ac_mq_02_city_within`, `completion_flag=dorm_assigned`.
- `QuestTriggerZone` `SleeperCenterEntrance`.
- Диалог: `ac_mq02_registration.tres`.

### 4.9. Приёмка

- [ ] Терминал выдаёт направление.
- [ ] Игрок получает форму и комнату.
- [ ] Двери столовой/додзё видны, но закрыты до регистрации.
- [ ] M1-флаг `dorm_assigned` сохранён.

---

## 5. MQ-03 — Индукция

### 5.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_mq_03_induction` |
| Название | Индукция |
| Фаза | `induction` |
| Локация | A2b Induction Gallery, A3 Dormitory |
| Giver | `rock` |
| Канон | Главы 20–23 |
| Prerequisites | `ac_mq_02_complete` |
| Completion flag | `ac_mq_03_complete` |
| Длительность | 6–8 мин |

### 5.2. История

Утром Sleepers собирают в галерее. Рок объясняет правила: Кошмары, Царство Снов, Врата, Цитадели, монстры с человеческими лицами. Каспер представляется и спрашивает, кто уже убивал. Санни отвечает правдой, которая звучит как бред. Толпа смеётся; Каспер защищает его и называет безумцем. В углу сидит слепая девушка.

### 5.3. Цели

| # | Objective ID | Kind | Target ID | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `attend_induction` | REACH | `induction_gallery` | да | «Прийти на индукцию» |
| 2 | `listen_rock` | TALK | `rock` | да | «Выслушать инструктора» |
| 3 | `answer_kasper` | FLAG | `flaw_choice_induction` | да | «Ответить Касперу» |
| 4 | `meet_kasper` | TALK | `kasper` | нет | «Запомнить Каспера» |
| 5 | `see_cassia` | FLAG | `cassia_seen` | нет | «Заметить слепую девушку» |
| 6 | `go_to_dorm` | REACH | `dormitory` | да | «Идти в дортуар» |

### 5.4. Последовательность

1. Игрок входит в галерею; 8–12 placeholder'ов, звук толпы.
2. Рок у трибуны; диалог `ac_mq03_induction.tres`.
3. Рок говорит о правилах; экран за ним показывает схему Врат.
4. Каспер представляется; запускается Flaw-сцена 1.
5. Игрок выбирает формулировку; толпа реагирует.
6. Кассия поворачивает голову; триггер ставит `cassia_seen`.
7. Рок заканчивает; игрок идёт в дортуар.

### 5.5. Flaw-сцена 1

| Вариант | Текст | Flag | Реакция |
|---|---|---|---|
| `induction_truth` | «Я. Тирана. Плевком.» | `flaw_choice_induction=truth` | Толпа смеётся; Каспер называет безумцем; `ac_rep_outcast_1` |
| `induction_misdirect` | «Только тех, кто первым пытался убить меня.» | `flaw_choice_induction=misdirect` | Каспер щурится; `ac_rep_legacy_1`, `ac_suspicion_1` |
| `induction_silence` | «…» | `flaw_choice_induction=silence` | Рок отмечает молчание; `ac_rep_outcast_1`, `ac_suspicion_1` |

**Ложь:** `enabled=false`, текст «Порок не позволяет». Это не выбор, а демонстрация правила.

### 5.6. Награды

| Тип | Значение | Где используется |
|---|---|---|
| Flag | `academy_schedule` | Доступ к расписанию |
| Currency | `credits` +20 | Мелкие покупки |
| Reputation | по выбору | Диалоги Каспера/Кассии |
| Flag | `induction_seen` | Совместимость с M1 |

### 5.7. Провал/soft-lock

Нет. Если игрок не отвечает, сцена ждёт; если уходит, цель ведёт назад. Каспер не блокирует.

### 5.8. Реализация

- `QuestNpc` `Rock`, `npc_id=rock`, `start_quest_id=ac_mq_03_induction`, `completion_flag=induction_seen`.
- `QuestNpc` `Kasper` для опционального разговора.
- `QuestTriggerZone` `InductionGallery`, `CassiaCorner`.
- `QuestChoiceController` + `QuestChoicePanel` для Flaw-сцены.
- Диалог: `ac_mq03_induction.tres`, `ac_mq03_kasper.tres`.

### 5.9. Приёмка

- [ ] Рок объясняет правила, а не читает лекцию.
- [ ] Каспер не злодей.
- [ ] Кассия не говорит.
- [ ] Ложь отключена.
- [ ] M1-флаг `induction_seen` сохранён.

---

## 6. MQ-04 — Первая ночь

### 6.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_mq_04_first_night` |
| Название | Первая ночь |
| Фаза | `induction` |
| Локация | A3 Dormitory, A3 Residential Room 07 |
| Giver | автоматически |
| Канон | Главы 18, 24 |
| Prerequisites | `ac_mq_03_complete` |
| Completion flag | `ac_mq_04_complete` |
| Длительность | 5–6 мин |

### 6.2. История

Санни получает койку в дортуаре, но его комната — 07, в жилом коридоре. Там есть форма, расписание и зеркало. Ночью тень на потолке поднимает руку. Санни не поднимал.

### 6.3. Цели

| # | Objective ID | Kind | Target ID | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `enter_dorm` | REACH | `dormitory` | да | «Войти в дортуар» |
| 2 | `find_room` | INTERACT | `room_07_door` | да | «Найти комнату 07» |
| 3 | `use_mirror` | INTERACT | `room_mirror` | нет | «Посмотреть в зеркало» |
| 4 | `sleep` | INTERACT | `room_bed` | да | «Лечь спать» |

### 6.4. Последовательность

1. Дортуар: 12 капсул, белый свет, шкафчики, доска статуса.
2. Игрок идёт в жилой коридор; комната 07 в конце.
3. В комнате: койка, стол, шкафчик, экран-окно, зеркало.
4. Если игрок смотрит в зеркало — тень отстаёт; флаг `shadow_sight_unlocked`, если ещё нет.
5. Игрок ложится; короткая сцена с тенью на потолке.
6. Утро; карточка «День 2».

### 6.5. Flaw/выбор

Нет. Это тихая сцена.

### 6.6. Награды

| Тип | Значение | Где используется |
|---|---|---|
| Flag | `rest_unlocked` | Восстановление в комнате |
| Flag | `ac_first_night` | Прогресс |
| Reputation | `ac_rep_outcast_1` | Диалоги |
| Currency | `credits` +5 | Мелочи |
| Flag | `shadow_sight_unlocked` | Если ещё не получен |

### 6.7. Провал/soft-lock

Нет. Если игрок не ложится, цель ведёт к койке.

### 6.8. Реализация

- `QuestTriggerZone` `Dormitory`.
- `Interactable` `Room07Door`, `RoomMirror`, `RoomBed`.
- Сцена `academy_residential.tscn` (future) или комната внутри `academy_sleeper_center`.
- Диалог/нарратив: `ac_mq04_first_night.tres`.

### 6.9. Приёмка

- [ ] Комната 07 читается как личное пространство.
- [ ] Тень ведёт себя независимо.
- [ ] Утро наступает после сна.
- [ ] M1-флаг `capsule_entered` не затрагивается.

---

## 7. MQ-05 — Расписание и интервью

### 7.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_mq_05_schedule` |
| Название | Расписание и интервью |
| Фаза | `week_one` |
| Локация | A6 Academic Wing, кабинет интервью |
| Giver | `administrator`, `rock` |
| Канон | Глава 24 |
| Prerequisites | `ac_mq_04_complete` |
| Completion flag | `ac_mq_05_complete` |
| Длительность | 6–8 мин |

### 7.2. История

На доске расписания три курса: Wilderness Survival, боевая подготовка, мёртвые языки. Санни выбирает выживание. Администратор вызывает его на интервью: Аспект, Памяти, Кошмар. Санни не может лгать; он выбирает, какую правду сказать.

### 7.3. Цели

| # | Objective ID | Kind | Target ID | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `read_schedule` | INTERACT | `schedule_board` | да | «Прочитать расписание» |
| 2 | `choose_wilderness` | FLAG | `wilderness_survival_selected` | да | «Выбрать Wilderness Survival» |
| 3 | `attend_interview` | TALK | `administrator` | да | «Пройти интервью» |
| 4 | `survive_interview` | FLAG | `interview_done` | да | «Не выдать Аспект» |
| 5 | `get_library` | FLAG | `library_pass` | да | «Получить допуск в библиотеку» |
| 6 | `choose_dead_languages` | FLAG | `dead_languages_selected` | нет | «Записаться на мёртвые языки» |

### 7.4. Последовательность

1. Доска расписания: три карточки, короткие описания.
2. Игрок выбирает Wilderness Survival (обязательно по совету Джет).
3. Администратор вызывает в кабинет; стеклянное окно, файлы, лампа.
4. Вопросы: «Опиши Аспект», «Что ты помнишь о Кошмаре?», «Сколько Памятей?».
5. Flaw-сцена 2: игрок выбирает формулировку; шкала подозрения.
6. Администратор записывает «вспомогательный, слабый»; выдаёт `library_pass`.
7. Если подозрение высоко — второй короткий вопрос, но без провала.

### 7.5. Flaw-сцена 2

| Вариант | Текст | Flag | Реакция |
|---|---|---|---|
| `interview_truth` | «[Temple Slave].» | `flaw_choice_interview=truth` | Администратор не понимает; suspicion +2; `ac_rep_faculty_0` |
| `interview_misdirect` | «Вспомогательный. Я не воин.» | `flaw_choice_interview=misdirect` | Записывает «слабый»; suspicion 0; `ac_rep_faculty_1` |
| `interview_silence` | «Предпочту не отвечать.» | `flaw_choice_interview=silence` | suspicion +1; `ac_rep_faculty_0` |

### 7.6. Награды

| Тип | Значение | Где используется |
|---|---|---|
| Flag | `interview_done` | Прогресс |
| Flag | `library_pass` | Библиотека, SQ-03/SQ-04 |
| Flag | `wilderness_survival_selected` | MQ-07 |
| Currency | `credits` +25 | Мелкие покупки |
| Reputation | `ac_rep_faculty_2` | Диалоги Джулиуса/Рока |

### 7.7. Провал/soft-lock

Нет. Любой выбор проходит интервью. Если игрок не выбрал курс, цель ведёт к доске.

### 7.8. Реализация

- `Interactable` `ScheduleBoard`, `interaction_id=schedule_board`.
- `QuestNpc` `Administrator`, `npc_id=administrator`, `start_quest_id=ac_mq_05_schedule`.
- `QuestChoiceController` для интервью.
- Диалог: `ac_mq05_interview.tres`.

### 7.9. Приёмка

- [ ] Три курса читаются.
- [ ] Wilderness Survival обязателен, но не единственный.
- [ ] Интервью не имеет провала.
- [ ] Игрок понимает, что Аспект лучше не раскрывать.

---

## 8. MQ-06 — Имя на табло

### 8.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_mq_06_true_name` |
| Название | Имя на табло |
| Фаза | `week_one` |
| Локация | A4 Dining Hall |
| Giver | автоматически (табло) |
| Канон | Глава 25 |
| Prerequisites | `ac_mq_05_complete` |
| Completion flag | `ac_mq_06_complete` |
| Длительность | 5–6 мин |

### 8.2. История

Утром на табло появляется True Name Нефис — **Changing Star**. Каспер смотрит на её имя, а не на True Name, и кланяется: «Lady». Кадеты шепчутся о клане Immortal Flame. Кассия сидит в углу одна.

### 8.3. Цели

| # | Objective ID | Kind | Target ID | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `enter_dining` | REACH | `dining_hall` | да | «Прийти в столовую» |
| 2 | `read_board` | INTERACT | `ranking_board` | да | «Прочитать табло» |
| 3 | `notice_nephis` | FLAG | `nephis_true_name_seen` | да | «Понять, кто такая Нефис» |
| 4 | `talk_kasper` | TALK | `kasper_dining` | нет | «Поговорить с Каспером» |
| 5 | `talk_cassia` | TALK | `cassia_dining` | нет | «Подойти к Кассии» |

### 8.4. Последовательность

1. Столовая: раздача, пар, столы групп.
2. Табло на восточной стене; True Name Нефис.
3. Каспер кланяется; короткая реплика «Lady».
4. Кадеты шепчутся; Кассия сидит одна.
5. Игрок может подойти к Касперу, Кассии или уйти.
6. Нефис смотрит на табло и уходит, не говоря ни слова.

### 8.5. Flaw/выбор

Опционально — Flaw-сцена 3, если игрок подходит к Касперу:

| Вариант | Текст | Flag | Реакция |
|---|---|---|---|
| `cafeteria_truth` | «Я слаб. Это правда.» | `flaw_choice_cafeteria=truth` | Каспер улыбается; `ac_rep_legacy_1` |
| `cafeteria_misdirect` | «Я то, чем кажусь. Вы видите не то.» | `flaw_choice_cafeteria=misdirect` | Интерес; `ac_rep_legacy_1`, suspicion +1 |
| `cafeteria_silence` | Уйти | `flaw_choice_cafeteria=silence` | Каспер запоминает; `ac_rep_legacy_0` |

### 8.6. Награды

| Тип | Значение | Где используется |
|---|---|---|
| Flag | `nephis_true_name_seen` | MQ-10, финал |
| Reputation | `ac_rep_legacy_1` | Каспер |
| Reputation | `ac_rep_outcast_1` | Кассия |
| Currency | `credits` +10 | Мелочи |

### 8.7. Провал/soft-lock

Нет. Если игрок не подходит к табло, цель ведёт к нему.

### 8.8. Реализация

- `Interactable` `RankingBoard`, `interaction_id=ranking_board`.
- `QuestNpc` `KasperDining`, `CassiaDining`.
- `QuestTriggerZone` `DiningHall`.
- Диалог: `ac_mq06_dining.tres`.

### 8.9. Приёмка

- [ ] True Name Нефис виден на табло.
- [ ] Каспер кланяется, но не объясняет всё.
- [ ] Кассия одна; игрок может подойти.
- [ ] Нефис не говорит.

---

## 9. MQ-07 — Уроки выживания

### 9.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_mq_07_wilderness` |
| Название | Уроки выживания |
| Фаза | `week_one` |
| Локация | A6 Wilderness Survival classroom |
| Giver | `julius` |
| Канон | Главы 25, 28 |
| Prerequisites | `ac_mq_05_complete`, `wilderness_survival_selected` |
| Completion flag | `ac_mq_07_complete` |
| Длительность | 8–10 мин |

### 9.2. История

Класс почти пуст: студенты не пришли. Джулиус один, с картой звёзд и очагом. Он спрашивает, почему Санни выбрал выживание; Санни называет Джет. Джулиус рассказывает о «Soul Reaper» и о том, что Джет не станет Saint. Потом — огонь, вода, звёзды.

### 9.3. Цели

| # | Objective ID | Kind | Target ID | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `meet_julius` | TALK | `julius` | да | «Поговорить с Джулиусом» |
| 2 | `study_stars` | INTERACT | `star_map` | да | «Изучить карту звёзд» |
| 3 | `make_fire` | INTERACT | `fire_pit` | да | «Развести огонь» |
| 4 | `find_water` | INTERACT | `water_station` | да | «Найти воду» |
| 5 | `take_notebook` | INTERACT | `julius_notebook` | нет | «Взять блокнот» |

### 9.4. Последовательность

1. Класс: карта звёзд, очаг, столы, образцы.
2. Джулиус говорит о Джет; короткая пауза.
3. Практика: звёзды → огонь → вода.
4. Джулиус даёт блокнот: «В Царстве Снов карта врёт, а звёзды — нет».
5. Если игрок спрашивает о True Name, Джулиус уходит от ответа.
6. Квест завершается; цель — «Вернуться к расписанию».

### 9.5. Flaw/выбор

Нет обязательной Flaw-сцены. Опциональный вопрос о Джет/True Name даёт лор, но не меняет исход.

### 9.6. Награды

| Тип | Значение | Где используется |
|---|---|---|
| Flag | `star_navigation` | Ориентирование в Царстве Снов |
| Flag | `firemaking` | Костры, факелы |
| Flag | `water_finding` | Вода |
| Item | `julius_notebook` | Журнал, лор |
| Reputation | `ac_rep_faculty_2` | Джулиус |

### 9.7. Провал/soft-lock

Нет. Если игрок не выполняет практику, цель ведёт к следующей точке. Все три знания обязательны для завершения, но подсказки явные.

### 9.8. Реализация

- `QuestNpc` `Julius`, `npc_id=julius`, `start_quest_id=ac_mq_07_wilderness`.
- `Interactable` `StarMap`, `FirePit`, `WaterStation`, `JuliusNotebook`.
- Диалог: `ac_mq07_julius.tres`.

### 9.9. Приёмка

- [ ] Джулиус — живой, а не энциклопедия.
- [ ] Три практики понятны.
- [ ] Игрок получает знания, а не «очки».
- [ ] Нет провала.

---

## 10. MQ-08 — Мера силы

### 10.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_mq_08_measure` |
| Название | Мера силы |
| Фаза | `week_one` |
| Локация | A5 Dojo |
| Giver | `rock` |
| Канон | Глава 26 |
| Prerequisites | `ac_mq_05_complete` |
| Completion flag | `ac_mq_08_complete` |
| Длительность | 6–8 мин |

### 10.2. История

Рок выстраивает кадетов у датчика удара. Нефис бьёт на 16, Каспер — на 21. Санни бьёт на 10–11. Толпа смеётся; Рок не комментирует. Он говорит: сила — не всё; выживание — это выбор.

### 10.3. Цели

| # | Objective ID | Kind | Target ID | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `enter_dojo` | REACH | `dojo_ring` | да | «Войти в додзё» |
| 2 | `strike_meter` | INTERACT | `strike_meter` | да | «Ударить по датчику» |
| 3 | `hear_rock` | TALK | `rock_dojo` | да | «Выслушать Рока» |
| 4 | `see_nephis` | TALK | `nephis_dojo` | нет | «Посмотреть на Нефис» |
| 5 | `see_kasper` | TALK | `kasper_dojo` | нет | «Посмотреть на Каспера» |

### 10.4. Последовательность

1. Додзё: ринг, маты, шкафчики, датчик.
2. Нефис бьёт 16; Каспер 21; кадеты шепчутся.
3. Санни бьёт 10–11; толпа смеётся.
4. Рок говорит коротко; не утешает.
5. Игрок может потренироваться; `dojo_token` открывает ночное додзё.
6. Нефис уходит первой.

### 10.5. Flaw/выбор

Нет. Это физическая сцена, не социальная.

### 10.6. Награды

| Тип | Значение | Где используется |
|---|---|---|
| Item | `training_blade` | Тренировочный меч |
| Flag | `dojo_token` | Ночное додзё, SQ-05/06 |
| Flag | `parry_basics` | Будущие тренировки |
| Reputation | `ac_rep_legacy_1` | Каспер |
| Currency | `credits` +20 | Мелочи |

### 10.7. Провал/soft-lock

Нет. Удар всегда проходит; сила удара фиксирована. Если игрок не подходит к датчику, цель ведёт к нему.

### 10.8. Реализация

- `QuestTriggerZone` `DojoRing`.
- `Interactable` `StrikeMeter`, `interaction_id=strike_meter`.
- `QuestNpc` `RockDojo`, `NephisDojo`, `KasperDojo`.
- Диалог: `ac_mq08_dojo.tres`.

### 10.9. Приёмка

- [ ] Тест удара читается.
- [ ] Санни слабее, но не унижен.
- [ ] Рок не утешает.
- [ ] Нет боевого урона.

---

## 11. MQ-09 — Тень в коридорах

### 11.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_mq_09_shadow` |
| Название | Тень в коридорах |
| Фаза | `week_one` |
| Локация | A3 Sleeper Center, A8 Underlevels |
| Giver | автоматически (тень) |
| Канон | Главы 26, 28 |
| Prerequisites | `ac_mq_04_complete`, `shadow_sight_unlocked` |
| Completion flag | `ac_mq_09_complete` |
| Длительность | 8–10 мин |

### 11.2. История

Ночью Санни не спит; тень тянется к вентиляции. Он отправляет её в разведку и находит открытую сервисную дверь. В подвалах нет монстров — только трубы, пар и старая табличка с именами. Тень задерживается на ней.

### 11.3. Цели

| # | Objective ID | Kind | Target ID | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `follow_shadow` | REACH | `service_corridor` | да | «Пойти за тенью» |
| 2 | `scout_1` | INTERACT | `shadow_point_1` | да | «Осмотреть коридор» |
| 3 | `scout_2` | INTERACT | `shadow_point_2` | да | «Осмотреть фильтры» |
| 4 | `scout_3` | INTERACT | `shadow_point_3` | да | «Осмотреть архив» |
| 5 | `read_plaque` | INTERACT | `old_plaque` | нет | «Прочитать табличку» |
| 6 | `return` | REACH | `dormitory` | да | «Вернуться в дортуар» |

### 11.4. Последовательность

1. Ночь; дортуар спит; тень на стене.
2. Игрок взаимодействует с `shadow_point` — тень показывает коридор.
3. Три точки: коридор, фильтры, архив.
4. Игрок спускается в подвалы; пар, аварийные лампы.
5. Табличка с именами; тень задерживается.
6. Возврат; Рок по радио объявляет отбой.

### 11.5. Flaw/выбор

Нет. Это исследование.

### 11.6. Награды

| Тип | Значение | Где используется |
|---|---|---|
| Flag | `shadow_scout` | Разведка тенью, SQ-09 |
| Flag | `maintenance_key` | Подвалы, SQ-10 |
| Reputation | `ac_rep_faculty_2` | Рок |
| Currency | `credits` +15 | Мелочи |

### 11.7. Провал/soft-lock

Нет. Если игрок не находит точку, тень подсвечивает её. Подвалы не блокируют финал.

### 11.8. Реализация

- `Interactable` `ShadowPoint1/2/3`, `OldPlaque`.
- `QuestTriggerZone` `ServiceCorridor`, `DormitoryReturn`.
- `AcademyShadowScout` — лёгкий контроллер подсветки, без free-roam.
- Диалог/нарратив: `ac_mq09_shadow.tres`.

### 11.9. Приёмка

- [ ] Тень — персонаж, а не гаджет.
- [ ] Подвалы не хоррор.
- [ ] Игрок получает `shadow_scout`.
- [ ] Нет боя.

---

## 12. MQ-10 — Спарринг

### 12.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_mq_10_sparring` |
| Название | Спарринг |
| Фаза | `week_two` |
| Локация | A5 Dojo |
| Giver | `rock` |
| Канон | Глава 27 |
| Prerequisites | `ac_mq_08_complete` |
| Completion flag | `ac_mq_10_complete` |
| Длительность | 8–10 мин |

### 12.2. История

Рок объявляет спарринг: Каспер против Нефис, Аспекты запрещены. Нефис почти побеждает, Каспер выигрывает на волоске. В раздевалке Каспер мрачнеет; Санни может подслушать или заговорить. Каспер раскрывает: Нефис — из клана Immortal Flame, последняя.

### 12.3. Цели

| # | Objective ID | Kind | Target ID | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `watch_sparring` | REACH | `dojo_ring_spectator` | да | «Посмотреть спарринг» |
| 2 | `see_result` | FLAG | `sparring_seen` | да | «Дождаться результата» |
| 3 | `enter_locker` | REACH | `dojo_locker_room` | да | «Зайти в раздевалку» |
| 4 | `talk_kasper` | TALK | `kasper_locker` | да | «Поговорить с Каспером» |
| 5 | `learn_clan` | FLAG | `immortal_flame_known` | да | «Узнать о клане» |

### 12.4. Последовательность

1. Ринг; Каспер и Нефис; Рок судит.
2. Бой: быстрые удары, Нефис почти побеждает.
3. Каспер ловит её падение; толпа аплодирует.
4. Раздевалка; Каспер мрачнеет.
5. Flaw-сцена 4: «Что ты видел в Кошмаре?»
6. Каспер рассказывает о клане Immortal Flame.
7. Нефис уходит; Санни остаётся с вопросом.

### 12.5. Flaw-сцена 4

| Вариант | Текст | Flag | Реакция |
|---|---|---|---|
| `locker_truth` | «Себя в цепи.» | `flaw_choice_locker=truth` | Каспер пауза; `ac_rep_legacy_2` |
| `locker_misdirect` | «Достаточно, чтобы не хотеть вернуться.» | `flaw_choice_locker=misdirect` | `ac_rep_legacy_1` |
| `locker_silence` | «Не твоё дело.» | `flaw_choice_locker=silence` | `ac_rep_legacy_0` |

### 12.6. Награды

| Тип | Значение | Где используется |
|---|---|---|
| Flag | `sparring_seen` | Прогресс |
| Flag | `immortal_flame_known` | MQ-12, лор |
| Reputation | `ac_rep_legacy_2` | Каспер |
| Reputation | `ac_rep_outcast_2` | Нефис/Кассия |
| Currency | `credits` +25 | Мелочи |

### 12.7. Провал/soft-lock

Нет. Спарринг — катсцена; игрок не участвует. Если игрок уходит, цель ведёт назад.

### 12.8. Реализация

- `QuestTriggerZone` `DojoRingSpectator`, `DojoLockerRoom`.
- `QuestNpc` `KasperLocker`.
- Катсцена спарринга — `CutsceneHost` или скриптовая анимация.
- Диалог: `ac_mq10_sparring.tres`, `ac_mq10_locker.tres`.

### 12.9. Приёмка

- [ ] Спарринг читается как бой, а не танец.
- [ ] Нефис почти побеждает без Аспекта.
- [ ] Каспер не злодей.
- [ ] Клан Immortal Flame раскрыт, но не перегружен.

---

## 13. MQ-11 — Ночь шторма

### 13.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_mq_11_storm` |
| Название | Ночь шторма |
| Фаза | `week_two` |
| Локация | A3 Sleeper Center, A8 Underlevels |
| Giver | автоматически (авария) |
| Канон | ИНТЕРПРЕТАЦИЯ |
| Prerequisites | `ac_mq_09_complete`, `ac_mq_10_complete` |
| Completion flag | `ac_mq_11_complete` |
| Длительность | 8–10 мин |

### 13.2. История

Ночью шторм валит внешнюю антенну. Sleeper Center переходит на аварийное питание; дверь в нижний блок блокируется. Там остаются Мира и Рен. Рок держит связь по радио. Санни использует тень и находит ручной release замка.

### 13.3. Цели

| # | Objective ID | Kind | Target ID | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `hear_alarm` | REACH | `sleeper_center_alarm` | да | «Понять, что произошло» |
| 2 | `talk_rock_radio` | TALK | `rock_radio` | да | «Связаться с Роком» |
| 3 | `reach_manual` | INTERACT | `manual_release` | да | «Открыть дверь вручную» |
| 4 | `rescue_cadets` | FLAG | `cadet_rescued` | да | «Вывести Миру и Рена» |
| 5 | `return_rock` | TALK | `rock_after_storm` | да | «Доложить Року» |

### 13.4. Последовательность

1. Сирена; свет мигает; дортуар просыпается.
2. Рок по радио: нижний блок заблокирован, там двое.
3. Санни спускается в подвалы; тень показывает путь.
4. Ручной release за ржавой панелью; игрок открывает.
5. Мира в панике; Рен молчит; Санни выводит их.
6. Рок: «Хорошо. Теперь иди спать».
7. Утром на доске — благодарность без имени.

### 13.5. Flaw/выбор

Нет. Это действие.

### 13.6. Награды

| Тип | Значение | Где используется |
|---|---|---|
| Item | `field_medkit` | Лечение |
| Reputation | `ac_rep_faculty_3` | Рок |
| Reputation | `ac_rep_outcast_2` | Мира/Рен |
| Currency | `credits` +30 | Мелочи |
| Flag | `storm_night_survived` | Финал |

### 13.7. Провал/soft-lock

Нет. Если игрок не идёт, Рок повторяет; дверь остаётся закрытой, но цель ведёт к release. Никто не умирает.

### 13.8. Реализация

- `TriggerZone` `SleeperCenterAlarm`.
- `QuestNpc` `RockRadio` (рация/голос), `RockAfterStorm`.
- `Interactable` `ManualRelease`.
- `QuestTriggerZone` `LowerBlockRescue`.
- Скриптовая сцена аварийного света, без монстров.

### 13.9. Приёмка

- [ ] Авария читается как бытовая, не боевая.
- [ ] Мира и Рен не карикатурны.
- [ ] Санни не произносит героическую речь.
- [ ] Нет смерти и монстров.

---

## 14. MQ-12 — Семнадцать

### 14.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_mq_12_last_day` |
| Название | Семнадцать |
| Фаза | `solstice` |
| Локация | A4 Dining, A6 Julius, A7 Hollow, A3 Dream Ward |
| Giver | автоматически |
| Канон | Глава 29 |
| Prerequisites | `ac_mq_11_complete` |
| Completion flag | `academy_complete` |
| Длительность | 15–20 мин |

### 14.2. История

Последний день. Санни пьёт кофе с сахаром и молоком. Кассия говорит: «Happy Birthday». Ему 17. Он прощается с Джулиусом, проходит галерею Hollow и ложится в капсулу. Впервые за месяц он не притворяется.

### 14.3. Цели

| # | Objective ID | Kind | Target ID | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `coffee` | INTERACT | `coffee_machine` | да | «Взять кофе» |
| 2 | `talk_cassia` | TALK | `cassia_birthday` | да | «Поговорить с Кассией» |
| 3 | `birthday` | FLAG | `birthday_17` | да | «Признать, что тебе 17» |
| 4 | `farewell_julius` | TALK | `julius_farewell` | да | «Попрощаться с Джулиусом» |
| 5 | `hollow` | REACH | `hollow_gallery` | да | «Пройти галерею Hollow» |
| 6 | `capsule` | INTERACT | `sleeper_capsule` | да | «Лечь в капсулу» |

### 14.4. Последовательность

1. Утро; столовая почти пуста; кофе.
2. Кассия садится рядом; «Happy Birthday».
3. Короткий разговор; игрок может спросить о доме, Нефис, страхе.
4. Джулиус в классе; прощание; предложение должности ассистента.
5. Медцентр: Рок ведёт группу; галерея Hollow; тишина.
6. Комната капсул: Кассия плачет, Каспер шепчет, Нефис светится.
7. Санни говорит с тенью; ложится; крышка закрывается.
8. Чёрный кадр; «Welcome to the Dream Realm, Sunless!».

### 14.5. Flaw-сцена 5

| Вариант | Текст | Flag | Реакция |
|---|---|---|---|
| `birthday_truth` | «Нет. Я перестал считать.» | `flaw_choice_birthday=truth` | Кассия тихо смеётся; `ac_rep_cassia_2` |
| `birthday_misdirect` | «Теперь знаю.» | `flaw_choice_birthday=misdirect` | `ac_rep_cassia_1` |
| `birthday_silence` | Взять кофе и молчать | `flaw_choice_birthday=silence` | `ac_rep_cassia_1`, тихая пауза |

### 14.6. Награды

| Тип | Значение | Где используется |
|---|---|---|
| Flag | `birthday_17` | Финал |
| Flag | `julius_farewell` | Эпилог |
| Flag | `hollow_seen` | Финал |
| Flag | `capsule_entered` | Совместимость с M1 |
| Flag | `academy_complete` | Карточка главы |
| Item | `cassia_ribbon` | Если `ac_rep_cassia_2`; финальная виньетка |
| Flag | `julius_letter` | Будущая должность ассистента |
| Currency | `credits` +0 | Не нужны |

### 14.7. Провал/soft-lock

Нет. Капсула требует `birthday_17`, `julius_farewell`, `hollow_seen`; если чего-то нет, цель ведёт к нужной точке. После капсулы — переход в B01.

### 14.8. Реализация

- `Interactable` `CoffeeMachine`, `SleeperCapsule`.
- `QuestNpc` `CassiaBirthday`, `JuliusFarewell`.
- `QuestTriggerZone` `HollowGallery`.
- `QuestChoiceController` для Flaw-сцены 5.
- Диалоги: `ac_mq12_birthday.tres`, `ac_mq12_farewell.tres`, `ac_mq12_capsule.tres`.

### 14.9. Приёмка

- [ ] День рождения тихий, без вечеринки.
- [ ] Hollow — эмоциональный низ, не хоррор.
- [ ] Капсула — единственный путь дальше.
- [ ] M1-флаг `capsule_entered` сохранён.
- [ ] Финал ведёт в B01.

---

## 15. Flaw-сцены: общая спецификация

### 15.1. Правила

1. **Ложь отключена.** В `QuestChoicePanel` вариант «соврать» имеет `enabled=false` и подпись «Порок не позволяет».
2. **Три валидных варианта.** Прямая правда, правда-как-ложь, молчание.
3. **Локальная шкала.** «Подозрение» 0…3, только внутри сцены.
4. **Нет провала.** Заполненная шкала даёт дополнительный вопрос/реакцию, но сцена продолжается.
5. **Последствия — флаги.** `flaw_choice_*` и `ac_rep_*`, не глобальные переменные.
6. **Никакой морали.** Игра не говорит, какой вариант «правильный».

### 15.2. Таблица сцен

| # | MQ | Вопрос | Truth | Misdirect | Silence |
|---|---|---|---|---|---|
| 1 | MQ-03 | «Кто уже убивал?» | «Я. Тирана. Плевком.» | «Только тех, кто первым пытался убить меня.» | Пауза |
| 2 | MQ-05 | «Опиши Аспект.» | «[Temple Slave].» | «Вспомогательный. Я не воин.» | «Предпочту не отвечать.» |
| 3 | MQ-06 | «Ты не то, чем кажешься?» | «Я слаб. Это правда.» | «Я то, чем кажусь. Вы видите не то.» | Уйти |
| 4 | MQ-10 | «Что ты видел в Кошмаре?» | «Себя в цепи.» | «Достаточно, чтобы не хотеть вернуться.» | «Не твоё дело.» |
| 5 | MQ-12 | «Ты знал, что сегодня твой день рождения?» | «Нет. Я перестал считать.» | «Теперь знаю.» | Взять кофе и молчать |

### 15.3. UI

- Панель выбора — существующий `QuestChoicePanel`.
- Шкала подозрения — три рунные насечки в углу субтитра, не полоса HP.
- Подсказка «Порок не позволяет» — на недоступном варианте.
- Никаких таймеров; игрок думает столько, сколько нужно.

---

## 16. Политика наград

### 16.1. Что можно давать

| Тип | Примеры | Почему |
|---|---|---|
| Знания | `star_navigation`, `firemaking`, `water_finding`, `dead_languages` | Канон: Джулиус учит выживанию |
| Доступ | `room_key`, `library_pass`, `dojo_token`, `maintenance_key` | Социальный прогресс |
| Снаряжение | `academy_uniform`, `training_blade`, `julius_notebook`, `compass`, `field_medkit` | Мелкие полезные вещи |
| Репутация | `ac_rep_legacy_*`, `ac_rep_outcast_*`, `ac_rep_faculty_*` | Диалоги и финал |
| Валюта | `credits` | Кофе, мелочи, подарки |
| Косметика | `cassia_ribbon` | Финальная виньетка |

### 16.2. Что нельзя давать

- **Памяти (Memories).** В реальном мире их не выдают; они приходят из Кошмаров.
- **Кристаллы душ.** Это валюта Царства Снов, не Академии.
- **Постоянные статы.** Никаких +HP/+урона; тренировки — знания и доступ.
- **Новые Аспекты.** Аспект уже есть; Академия его не меняет.
- **Уровни/XP.** Прогрессия — сюжетная и знаниевая.

### 16.3. Идемпотентность

- `QuestReward` выдаётся один раз; `reward_claimed` уже есть.
- Уникальные предметы (`cassia_ribbon`, `julius_notebook`) проверяются по флагу.
- `credits` можно давать повторно только за разные квесты.

---

## 17. Гейты и anti-soft-lock

| Ситуация | Поведение |
|---|---|
| Игрок пришёл к NPC раньше квеста | NPC имеет `required_flags`; interactable выключен; барк «Ещё рано». |
| Игрок пропустил опциональную цель | Квест завершается по required; опциональная остаётся в журнале. |
| Игрок ушёл из сцены | Квест остаётся `active`; цель ведёт обратно. |
| Игрок не выбрал курс | `ScheduleBoard` остаётся доступен; MQ-07 ждёт `wilderness_survival_selected`. |
| Игрок не открыл подвалы | MQ-09 остаётся активным; тень подсвечивает дверь. |
| Игрок не прошёл спарринг | MQ-10 ждёт `sparring_seen`; дверь в раздевалку закрыта до сцены. |
| Игрок не пережил шторм | MQ-11 не имеет смерти; сцена ждёт release. |
| Игрок пытается лечь в капсулу раньше | `SleeperCapsule` требует `birthday_17`, `julius_farewell`, `hollow_seen`. |
| Сохранение/загрузка | Все флаги и квесты в `NightmareRunState`; `academy_day`/`academy_phase` добавить в snapshot. |

---

## 18. Интеграция с QuestSystem

### 18.1. Каталог

Новый файл: `resources/quests/academy/quest_catalog_academy.tres`.

```text
QuestCatalog
  scope = &"academy"
  quests = [12 MQ + 12 SQ]
```

### 18.2. Scope

Текущий `QuestSystem` загружает один каталог и требует `catalog.scope == active_scope`. Минимальное изменение:

1. `QuestSystem` получает `CATALOG_PATHS = { &"forgotten_shore": ..., &"academy": ... }`.
2. `_load_catalog()` строит словарь каталогов; `activate_scope(scope)` выбирает нужный.
3. `AcademyQuestDirector` вызывает `activate_scope(&"academy")` при входе в академию; `deactivate_scope()` при переходе в B01.
4. `CampaignGuide.set_external_objective` показывает текущую цель MQ.

### 18.3. Директор

`AcademyQuestDirector` — Node в каждой академической сцене (или один в `academy_campus` + чтение состояния):

- читает `academy_phase` и `academy_day`;
- активирует scope;
- проверяет завершение обязательных MQ фазы;
- ставит следующий `academy_phase`;
- обновляет `CampaignGuide`;
- проигрывает временную карточку при смене фазы.

### 18.4. Флаги

| Флаг | Тип | Где ставится |
|---|---|---|
| `academy_gate_passed` | bool | MQ-01 |
| `dorm_assigned` | bool | MQ-02 |
| `induction_seen` | bool | MQ-03 |
| `ac_first_night` | bool | MQ-04 |
| `interview_done` | bool | MQ-05 |
| `nephis_true_name_seen` | bool | MQ-06 |
| `star_navigation` | bool | MQ-07 |
| `strike_rating` | bool | MQ-08 |
| `shadow_scout` | bool | MQ-09 |
| `immortal_flame_known` | bool | MQ-10 |
| `storm_night_survived` | bool | MQ-11 |
| `birthday_17` | bool | MQ-12 |
| `academy_complete` | bool | MQ-12 |
| `ac_mq_XX_complete` | bool | каждый MQ |
| `ac_rep_*` | bool | Flaw/выборы |

### 18.5. Диалоги

- `resources/dialogue/academy/ac_mq01_gate.tres`
- `ac_mq02_registration.tres`
- `ac_mq03_induction.tres`
- `ac_mq03_kasper.tres`
- `ac_mq04_first_night.tres`
- `ac_mq05_interview.tres`
- `ac_mq06_dining.tres`
- `ac_mq07_julius.tres`
- `ac_mq08_dojo.tres`
- `ac_mq09_shadow.tres`
- `ac_mq10_sparring.tres`
- `ac_mq10_locker.tres`
- `ac_mq11_storm.tres`
- `ac_mq12_birthday.tres`
- `ac_mq12_farewell.tres`
- `ac_mq12_capsule.tres`

### 18.6. Тесты

| Тест | Что проверяет |
|---|---|
| `test_academy_quest_data` | 24 квеста валидны; цели ссылаются на существующие id; награды не пустые. |
| `test_academy_main_flow` | MQ-01…MQ-12 завершаются; капсула открывается. |
| `test_academy_flaw` | 5 Flaw-сцен: ложь отключена; выборы ставят флаги. |
| `test_academy_anti_softlock` | Все обязательные цели доступны; нет тупика. |
| `test_academy_save_load` | Флаги, день, фаза, квесты переживают save/load. |

---

## 19. Приёмка главы (квестовая часть)

- [ ] 12 MQ имеют валидные `QuestDefinition`.
- [ ] Каждый MQ завершается по required-целям.
- [ ] MQ-06/07/08 можно проходить в любом порядке.
- [ ] Flaw-сцены не имеют варианта лжи.
- [ ] Награды не дают Памятей/кристаллов/статов.
- [ ] Капсула не открывается до финальных целей.
- [ ] Нет soft-lock при пропуске опциональных целей.
- [ ] M1-флаги совместимы.
- [ ] Журнал показывает понятные цели.
- [ ] Руководство по квестам совпадает с картой.

---

## 20. Открытые вопросы

1. **MQ-11 «Ночь шторма»:** оставляем или заменяем короткой сценой? Рекомендация: оставить, если хватает времени; иначе — 3-минутная версия.
2. **MQ-09 подвалы:** делаем в M2-full или откладываем? Рекомендация: отложить, если нет ресурсов; тень можно обучить в дортуаре.
3. **Flaw-сцены:** 5 или 3? Рекомендация: 5, но MQ-06 и MQ-10 можно сократить.
4. **Репутация:** флаги или числовая шкала? Рекомендация: флаги.
5. **Интервью:** добавлять ли второй вопрос при высоком подозрении? Рекомендация: да, но без провала.
