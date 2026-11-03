# Академия Пробуждённых — побочные квесты и награды (M2-full)

Дата: 2026-11-03  
Статус: **design-only. Код, сцены и ресурсы не изменялись. Runtime — NOT TESTED.**  
Область: 12 побочных квестов, 3 цепочки, локальные последствия и награды.  
Связанные документы:

- `docs/design/academy_chapter_roadmap.md` — сюжетный roadmap.
- `docs/design/academy_location_map.md` — карта.
- `docs/design/academy_main_quests.md` — основные квесты.
- `docs/demo_sprint/design/side_quests.md` — формат и правила побочных квестов.
- `scripts/quests/quest_definition.gd`, `quest_objective.gd`, `quest_reward.gd`, `quest_npc.gd`, `quest_pickup.gd`.

---

## 0. Принципы

1. **Необязательность.** Ни один SQ не блокирует MQ, капсулу или финал.
2. **Одна новая идея на квест.** Талисман, чужая форма, карта звёзд, мёртвое слово, ночная тренировка, рейтинг, пари, чай, пропавший кадет, ключ, письмо Hollow, прогулка по стене.
3. **Пространство рассказывает.** Игрок находит истории по следам, а не по восклицательным знакам.
4. **Всегда есть путь без боя.** В Академии нет боевых данжей; конфликты социальные.
5. **Последствия локальны.** Меняются реплики, доступ, предметы и финальная виньетка; не меняется канон.
6. **Награды не ломают баланс.** Никаких Памятей, кристаллов, +статов и уровней.
7. **Flaw важен.** Где возможно, выбор строится на невозможности соврать.
8. **Нет провала.** SQ остаётся `active`, пока не выполнены цели; «отказ» — это флаг, а не fail.
9. **Нет обязательного гринда.** Каждый SQ — один проход, без повторяемых действий.
10. **Всё можно пропустить.** Если игрок уходит в финал, SQ остаются незавершёнными, но не ломают игру.

---

## 1. Граф квестов

```text
ЦЕПОЧКА A «ДОДЗЁ»
SQ-05 Призрак в додзё
   └─ SQ-06 Второй с конца
        └─ SQ-07 Пари Каспера

ЦЕПОЧКА B «ПОДВАЛЫ»
SQ-10 Ключ от подвалов
   └─ SQ-09 Пропавший кадет
        └─ (эпилог) Тайник старой Академии

ЦЕПОЧКА C «ТИХИЕ ЛЮДИ»
SQ-08 Чай для слепой
   └─ SQ-11 Письмо из галереи

ОДИНОЧНЫЕ
SQ-01 Талисман
SQ-02 Чужая форма
SQ-03 Карта, которой нет
SQ-04 Слово из мёртвого языка
SQ-12 Прогулка по стене
```

---

## 2. Индекс

| ID | Название | Фаза | Giver | Локация | Цепочка | Время | Награда |
|---|---|---|---|---|---:|---:|---|
| `ac_sq_01_lucky_charm` | Талисман | induction/week_one | Мира | A3 дортуар, прачечная | — | 4–6 мин | `provisions`, репутация |
| `ac_sq_02_borrowed_uniform` | Чужая форма | week_one | Рен | A5 шкафчики, A3 прачечная | — | 5–7 мин | `academy_uniform`, credits |
| `ac_sq_03_star_chart` | Карта, которой нет | week_one | Джулиус | A6 библиотека | — | 6–8 мин | `compass`, `star_navigation` |
| `ac_sq_04_dead_word` | Слово из мёртвого языка | week_one | Джулиус | A6 библиотека/архив | — | 6–8 мин | `dead_languages`, lore |
| `ac_sq_05_dojo_ghost` | Призрак в додзё | week_two | Рен | A5 додзё, ночь | A | 5–7 мин | `parry_basics`, `dojo_token` |
| `ac_sq_06_second_from_last` | Второй с конца | week_two | Рок | A5 ринг | A | 8–12 мин | `academy_rank`, `training_blade` |
| `ac_sq_07_kasper_bet` | Пари Каспера | week_two | Каспер | A5/A4 | A | 5–8 мин | `kasper_favor`, credits |
| `ac_sq_08_tea_for_cassia` | Чай для слепой | week_one | Кассия | A4 кухня | C | 4–6 мин | `cassia_ribbon`, репутация |
| `ac_sq_09_missing_cadet` | Пропавший кадет | week_two | Рок/Мира | A8 подвалы | B | 8–10 мин | `field_medkit`, репутация |
| `ac_sq_10_maintenance_key` | Ключ от подвалов | week_one | Хольт | A3 прачечная/A8 | B | 5–7 мин | `maintenance_key`, `old_academy_map` |
| `ac_sq_11_hollow_letter` | Письмо из галереи | solstice | Кассия/Рок | A7 Hollow | C | 6–8 мин | `silver_locket`, финал |
| `ac_sq_12_wall_walk` | Прогулка по стене | week_one/week_two | Стражник | A1/A9 | — | 5–7 мин | `old_academy_map`, credits |

**Общая длительность:** 68–94 минуты при полном прохождении; 35–50 минут при выборочном.

---

## 3. SQ-01 — Талисман

### 3.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_sq_01_lucky_charm` |
| Название | Талисман |
| Тип | Исследование, маленькая история |
| Фаза | `induction` / `week_one` |
| Giver | Мира (`cadet_mira`) |
| Локация | A3 дортуар → прачечная → вентиляция |
| Prerequisites | `ac_mq_03_complete` |
| Completion flag | `ac_sq_01_complete` |
| Canon | ИНТЕРПРЕТАЦИЯ |

### 3.2. История

Мира потеряла латунный талисман — единственную вещь от старшего брата, который не вернулся из Царства Снов. Она боится сообщить: её уже записали в «обречённые». Талисман упал в вентиляцию прачечной. Санни может найти его, вернуть или оставить себе.

### 3.3. Цели

| # | Objective | Kind | Target | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `talk_mira` | TALK | `cadet_mira` | да | «Поговорить с Мирой» |
| 2 | `search_laundry` | INTERACT | `laundry_vent` | да | «Обыскать вентиляцию» |
| 3 | `return_charm` | INTERACT | `cadet_mira` | да | «Вернуть талисман» |

### 3.4. Ветки

| Выбор | Flag | Последствие |
|---|---|---|
| Вернуть | `ac_sq_01_returned` | `provisions` ×2, `ac_rep_outcast_1`, Мира помогает в SQ-09 |
| Оставить | `ac_sq_01_kept` | `credits` +15, `ac_rep_outcast_0`; Мира холодна в финале |
| Соврать | — | Невозможно: Flaw не позволяет. Вариант «Это не твоё» — правда, но жестоко |

### 3.5. Награды

| Тип | Значение | Где используется |
|---|---|---|
| Item | `provisions` ×2 (return) | Еда/отдых |
| Currency | `credits` +15 (keep) | Мелочи |
| Reputation | `ac_rep_outcast_1` (return) | Диалоги Кассии/Миры |
| Flag | `mira_owes_favor` | SQ-09, финал |

### 3.6. Реализация

- `QuestNpc` `CadetMira`, `npc_id=cadet_mira`, `start_quest_id=ac_sq_01_lucky_charm`.
- `QuestPickup` `LaundryVent` с `item_id=brass_charm`, `pickup_flag=ac_sq_01_charm_found`.
- `QuestNpc` возврата `CadetMiraReturn`, `required_flags=[ac_sq_01_charm_found]`.
- Диалог: `ac_sq01_mira.tres`.

### 3.7. Приёмка

- [ ] Талисман находится без пиксель-хантинга.
- [ ] Возврат/оставление — оба валидны.
- [ ] Мира не карикатурна.
- [ ] Нет квестового маркера до разговора.

---

## 4. SQ-02 — Чужая форма

### 4.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_sq_02_borrowed_uniform` |
| Название | Чужая форма |
| Тип | Социальный конфликт, улика |
| Фаза | `week_one` |
| Giver | Рен (`cadet_ren`) |
| Локация | A5 шкафчики → A3 прачечная |
| Prerequisites | `ac_mq_02_complete` |
| Completion flag | `ac_sq_02_complete` |
| Canon | ИНТЕРПРЕТАЦИЯ |

### 4.2. История

У Рена пропала форма. Он слишком напуган, чтобы сообщить: группа Legacy «одолжила» её для ритуала посвящения. Форма лежит в шкафчике додзё. Санни может вернуть её, сдать группу или оставить всё как есть.

### 4.3. Цели

| # | Objective | Kind | Target | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `talk_ren` | TALK | `cadet_ren` | да | «Поговорить с Реном» |
| 2 | `search_lockers` | INTERACT | `dojo_locker_03` | да | «Обыскать шкафчики» |
| 3 | `return_uniform` | INTERACT | `cadet_ren` | да | «Вернуть форму» |

### 4.4. Ветки

| Выбор | Flag | Последствие |
|---|---|---|
| Вернуть тихо | `ac_sq_02_quiet` | `academy_uniform`, `ac_rep_outcast_1`; Рен помогает в SQ-05 |
| Сдать группу | `ac_sq_02_report` | `ac_rep_faculty_1`, `ac_rep_legacy_-1`; Каспер холоден |
| Оставить | `ac_sq_02_dropped` | `credits` +10; Рен не появляется в финале |

### 4.5. Награды

| Тип | Значение |
|---|---|
| Item | `academy_uniform` |
| Currency | `credits` +10/+15 |
| Reputation | `ac_rep_outcast_1` или `ac_rep_faculty_1` |
| Flag | `ren_owes_favor` |

### 4.6. Реализация

- `QuestNpc` `CadetRen`.
- `QuestPickup` `DojoLocker03` с `item_id=ren_uniform`.
- `QuestNpc` возврата.
- Диалог: `ac_sq02_ren.tres`.

---

## 5. SQ-03 — Карта, которой нет

### 5.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_sq_03_star_chart` |
| Название | Карта, которой нет |
| Тип | Исследование, знания |
| Фаза | `week_one` |
| Giver | Джулиус |
| Локация | A6 библиотека, restricted section |
| Prerequisites | `ac_mq_05_complete`, `library_pass` |
| Completion flag | `ac_sq_03_complete` |
| Canon | Глава 28 (навигация по звёздам) |

### 5.2. История

Джулиус потерял карту звёзд, которую рисовал для Санни. Он думает, что оставил её в библиотеке, но карта попала в restricted section. Санни находит её среди старых экспедиционных карт.

### 5.3. Цели

| # | Objective | Kind | Target | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `talk_julius` | TALK | `julius` | да | «Спросить о карте» |
| 2 | `search_archive` | INTERACT | `restricted_archive` | да | «Найти карту в архиве» |
| 3 | `return_chart` | TALK | `julius` | да | «Вернуть карту» |

### 5.4. Ветки

| Выбор | Flag | Последствие |
|---|---|---|
| Вернуть | `ac_sq_03_returned` | `compass`, `star_navigation`, `ac_rep_faculty_2` |
| Оставить | `ac_sq_03_kept` | `compass`, но Джулиус холоден; `ac_rep_faculty_0` |
| Скопировать | `ac_sq_03_copied` | `compass`, `old_academy_map`, `ac_rep_faculty_1` |

### 5.5. Награды

| Тип | Значение |
|---|---|
| Item | `compass` |
| Flag | `star_navigation` (если ещё нет) |
| Flag | `old_academy_map` (copy) |
| Reputation | `ac_rep_faculty_2` |

### 5.6. Реализация

- `QuestNpc` `Julius`.
- `QuestPickup` `RestrictedArchive` с `item_id=star_chart`, `required_flags=[library_pass]`.
- Диалог: `ac_sq03_julius.tres`.

---

## 6. SQ-04 — Слово из мёртвого языка

### 6.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_sq_04_dead_word` |
| Название | Слово из мёртвого языка |
| Тип | Загадка, лор |
| Фаза | `week_one` |
| Giver | Джулиус / табличка в библиотеке |
| Локация | A6 библиотека |
| Prerequisites | `ac_mq_07_complete`, `dead_languages_selected` |
| Completion flag | `ac_sq_04_complete` |
| Canon | Глава 28 (мёртвые языки, True Name) |

### 6.2. История

На старой плите в библиотеке вырезано слово на мёртвом языке. Джулиус не уверен в переводе; он просит Санни помочь. Слово оказывается частью имени — возможно, «Star of Change». Это не ответ, а намёк.

### 6.3. Цели

| # | Objective | Kind | Target | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `find_plaque` | INTERACT | `library_plaque` | да | «Найти плиту» |
| 2 | `ask_julius` | TALK | `julius` | да | «Спросить Джулиуса» |
| 3 | `translate` | FLAG | `dead_languages` | да | «Перевести слово» |

### 6.4. Ветки

| Выбор | Flag | Последствие |
|---|---|---|
| Показать Джулиусу | `ac_sq_04_shown` | `dead_languages`, `ac_rep_faculty_1` |
| Скопировать себе | `ac_sq_04_copied` | `dead_languages`, `library_pass` upgrade, но Джулиус недоволен |
| Соврать о переводе | — | Невозможно: Flaw не позволяет |

### 6.5. Награды

| Тип | Значение |
|---|---|
| Flag | `dead_languages` |
| Flag | `library_restricted` |
| Lore | Запись «Changing Star» |
| Reputation | `ac_rep_faculty_1` |

### 6.6. Реализация

- `Interactable` `LibraryPlaque`.
- `QuestNpc` `Julius`.
- `QuestChoiceController` для перевода (3 варианта, все правдивые).
- Диалог: `ac_sq04_plaque.tres`.

---

## 7. SQ-05 — Призрак в додзё

### 7.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_sq_05_dojo_ghost` |
| Название | Призрак в додзё |
| Тип | Ночное исследование, социальный выбор |
| Фаза | `week_two` |
| Giver | Рен / ночной шум |
| Локация | A5 додзё, ночь |
| Prerequisites | `ac_mq_08_complete`, `dojo_token` |
| Completion flag | `ac_sq_05_complete` |
| Canon | ИНТЕРПРЕТАЦИЯ |

### 7.2. История

Ночью в додзё слышны удары. Это Рен: он тренируется тайком, чтобы не попасть в «обречённые». Если его найдут, его отправят на фронт раньше срока. Санни может помочь, сдать или уйти.

### 7.3. Цели

| # | Objective | Kind | Target | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `hear_noise` | REACH | `dojo_night` | да | «Проверить шум» |
| 2 | `find_ren` | TALK | `cadet_ren_night` | да | «Найти источник» |
| 3 | `decide` | FLAG | `ac_sq_05_resolved` | да | «Решить, что делать» |

### 7.4. Ветки

| Выбор | Flag | Последствие |
|---|---|---|
| Помочь | `ac_sq_05_helped` | `parry_basics`, `dojo_token`, `ac_rep_outcast_1` |
| Сдать | `ac_sq_05_reported` | `ac_rep_faculty_1`, `ac_rep_outcast_-1`; Рен исчезает |
| Уйти | `ac_sq_05_left` | Ничего; Рен остаётся, но холоден |
| Соврать | — | Невозможно |

### 7.5. Награды

| Тип | Значение |
|---|---|
| Flag | `parry_basics` |
| Flag | `dojo_token` (если ещё нет) |
| Reputation | `ac_rep_outcast_1` |
| Flag | `ren_friend` |

### 7.6. Реализация

- `QuestTriggerZone` `DojoNight`.
- `QuestNpc` `CadetRenNight`.
- Ночной свет, один прожектор, тени.
- Диалог: `ac_sq05_ren.tres`.

---

## 8. SQ-06 — Второй с конца

### 8.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_sq_06_second_from_last` |
| Название | Второй с конца |
| Тип | Тренировочная лестница, 3 боя |
| Фаза | `week_two` |
| Giver | Рок |
| Локация | A5 ринг |
| Prerequisites | `ac_mq_08_complete` |
| Completion flag | `ac_sq_06_complete` |
| Canon | Глава 26 (рейтинг), глава 35 (шутка «второй с конца») |

### 8.2. История

Рок предлагает Санни неофициальную лестницу: три тренировочных боя с кадетами他的 уровня. Победа не делает его героем, но меняет место в списке. Каждый бой — короткий, без смерти.

### 8.3. Цели

| # | Objective | Kind | Target | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `accept_ladder` | TALK | `rock_ladder` | да | «Принять вызов» |
| 2 | `duel_1` | FLAG | `ac_sq_06_duel_1` | да | «Победить первого» |
| 3 | `duel_2` | FLAG | `ac_sq_06_duel_2` | да | «Победить второго» |
| 4 | `duel_3` | FLAG | `ac_sq_06_duel_3` | да | «Победить третьего» |

### 8.4. Ветки

| Исход | Flag | Последствие |
|---|---|---|
| 3 победы | `ac_sq_06_three_wins` | `academy_rank` +2, `training_blade`, `ac_rep_legacy_1` |
| 2 победы | `ac_sq_06_two_wins` | `academy_rank` +1, `credits` +20 |
| 1 победа | `ac_sq_06_one_win` | `credits` +10, `ac_rep_outcast_1` |
| Отказ | `ac_sq_06_declined` | Ничего; Рок не осуждает |

### 8.5. Награды

| Тип | Значение |
|---|---|
| Flag | `academy_rank` |
| Item | `training_blade` |
| Currency | `credits` +10…30 |
| Reputation | `ac_rep_legacy_1` / `ac_rep_outcast_1` |

### 8.6. Реализация

- `QuestNpc` `RockLadder`.
- Три коротких тренировочных боя через существующий `CombatController` с `training=true` (без смерти, HP не опускается ниже 1).
- Диалог: `ac_sq06_ladder.tres`.

---

## 9. SQ-07 — Пари Каспера

### 9.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_sq_07_kasper_bet` |
| Название | Пари Каспера |
| Тип | Социальный выбор, ставка |
| Фаза | `week_two` |
| Giver | Каспер |
| Локация | A5 додзё / A4 столовая |
| Prerequisites | `ac_sq_06_complete` или `ac_mq_10_complete` |
| Completion flag | `ac_sq_07_complete` |
| Canon | ИНТЕРПРЕТАЦИЯ |

### 9.2. История

Каспер предлагает пари: Санни не сможет продержаться три удара против кадета из его группы. Ставка — credits или услуга. Каспер не злодей; он проверяет, не сломался ли Санни.

### 9.3. Цели

| # | Objective | Kind | Target | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `talk_kasper` | TALK | `kasper_bet` | да | «Выслушать пари» |
| 2 | `accept` | FLAG | `ac_sq_07_accepted` | да | «Принять или отказаться» |
| 3 | `fight` | FLAG | `ac_sq_07_result` | да | «Провести бой» |

### 9.4. Ветки

| Выбор | Flag | Последствие |
|---|---|---|
| Принять и выиграть | `ac_sq_07_won` | `credits` +30, `kasper_favor`, `ac_rep_legacy_2` |
| Принять и проиграть | `ac_sq_07_lost` | `credits` −10, `ac_rep_legacy_1`; Каспер не злорадствует |
| Отказаться | `ac_sq_07_declined` | `ac_rep_legacy_1`; Каспер уважает отказ |
| Соврать | — | Невозможно |

### 9.5. Награды

| Тип | Значение |
|---|---|
| Currency | `credits` +30 / −10 |
| Flag | `kasper_favor` |
| Reputation | `ac_rep_legacy_2` |

### 9.6. Реализация

- `QuestNpc` `KasperBet`.
- Бой — тренировочный, 3 удара, без смерти.
- Диалог: `ac_sq07_bet.tres`.

---

## 10. SQ-08 — Чай для слепой

### 10.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_sq_08_tea_for_cassia` |
| Название | Чай для слепой |
| Тип | Тихая история, помощь |
| Фаза | `week_one` |
| Giver | Кассия |
| Локация | A4 столовая / кухня |
| Prerequisites | `ac_mq_06_complete` |
| Completion flag | `ac_sq_08_complete` |
| Canon | Глава 29 (Кассия, кофе/чай) |

### 10.2. История

Кассия просит травяной чай, но автомат сломан. Санни идёт на кухню, находит чай и заваривает. Это не спасение мира, а маленький жест. Кассия запоминает.

### 10.3. Цели

| # | Objective | Kind | Target | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `talk_cassia` | TALK | `cassia_tea` | да | «Поговорить с Кассией» |
| 2 | `find_tea` | INTERACT | `kitchen_tea` | да | «Найти чай на кухне» |
| 3 | `brew` | INTERACT | `tea_station` | да | «Заварить чай» |
| 4 | `bring` | TALK | `cassia_tea` | да | «Принести чай» |

### 10.4. Ветки

| Выбор | Flag | Последствие |
|---|---|---|
| Принести чай | `ac_sq_08_served` | `cassia_ribbon`, `ac_rep_cassia_1`, тихая сцена |
| Выпить самому | `ac_sq_08_drank` | `credits` +5, Кассия не обижается, но сцена короче |
| Соврать | — | Невозможно |

### 10.5. Награды

| Тип | Значение |
|---|---|
| Item | `cassia_ribbon` |
| Reputation | `ac_rep_cassia_1` |
| Flag | `cassia_tea_shared` |
| Lore | Видение Кассии (намёк) |

### 10.6. Реализация

- `QuestNpc` `CassiaTea`.
- `QuestPickup` `KitchenTea`.
- `Interactable` `TeaStation`.
- Диалог: `ac_sq08_cassia.tres`.

---

## 11. SQ-09 — Пропавший кадет

### 11.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_sq_09_missing_cadet` |
| Название | Пропавший кадет |
| Тип | Поиск, тень, спасение |
| Фаза | `week_two` |
| Giver | Рок / Мира |
| Локация | A8 подвалы |
| Prerequisites | `ac_sq_10_complete` или `shadow_scout` |
| Completion flag | `ac_sq_09_complete` |
| Canon | ИНТЕРПРЕТАЦИЯ |

### 11.2. История

Мира говорит, что Рен пропал после отбоя. Санни идёт в подвалы, использует тень и находит его в старом фильтрационном блоке. Рен не ранен, но заперт. Он признаётся, что хотел сбежать из Академии.

### 11.3. Цели

| # | Objective | Kind | Target | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `talk_mira` | TALK | `cadet_mira` | да | «Поговорить с Мирой» |
| 2 | `search_underlevels` | REACH | `old_filtration` | да | «Обыскать подвалы» |
| 3 | `find_ren` | TALK | `cadet_ren_lost` | да | «Найти Рена» |
| 4 | `choose` | FLAG | `ac_sq_09_resolved` | да | «Решить, что делать» |

### 11.4. Ветки

| Выбор | Flag | Последствие |
|---|---|---|
| Вывести тихо | `ac_sq_09_saved` | `field_medkit`, `ac_rep_outcast_2`, Рен остаётся |
| Сдать Рока | `ac_sq_09_reported` | `ac_rep_faculty_2`, Рен исчезает |
| Помочь сбежать | `ac_sq_09_helped_escape` | `ac_rep_outcast_2`, `ac_rep_faculty_-1`; Рен появляется в финале |
| Соврать | — | Невозможно |

### 11.5. Награды

| Тип | Значение |
|---|---|
| Item | `field_medkit` |
| Reputation | `ac_rep_outcast_2` / `ac_rep_faculty_2` |
| Flag | `old_academy_map` (если ещё нет) |
| Lore | Тайник старой Академии (эпилог) |

### 11.6. Реализация

- `QuestNpc` `CadetMira`.
- `QuestTriggerZone` `OldFiltration`.
- `QuestNpc` `CadetRenLost`.
- Диалог: `ac_sq09_ren.tres`.

---

## 12. SQ-10 — Ключ от подвалов

### 12.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_sq_10_maintenance_key` |
| Название | Ключ от подвалов |
| Тип | Поиск, доступ |
| Фаза | `week_one` |
| Giver | Сержант Хольт |
| Локация | A3 прачечная / A8 |
| Prerequisites | `ac_mq_04_complete` |
| Completion flag | `ac_sq_10_complete` |
| Canon | ИНТЕРПРЕТАЦИЯ |

### 12.2. История

Хольт потерял ключ от сервисных тоннелей. Он не хочет сообщать: ему и так не платят за сверхурочные. Ключ упал в корзину с бельём. Санни может вернуть его, скопировать или оставить.

### 12.3. Цели

| # | Objective | Kind | Target | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `talk_holt` | TALK | `sergeant_holt` | да | «Поговорить с Хольтом» |
| 2 | `search_laundry` | INTERACT | `laundry_bin` | да | «Обыскать бельё» |
| 3 | `return_key` | INTERACT | `sergeant_holt` | да | «Вернуть ключ» |

### 12.4. Ветки

| Выбор | Flag | Последствие |
|---|---|---|
| Вернуть | `ac_sq_10_returned` | `maintenance_key`, `credits` +15, `ac_rep_faculty_1` |
| Скопировать | `ac_sq_10_copied` | `maintenance_key`, `old_academy_map`, `ac_rep_faculty_-1` |
| Оставить | `ac_sq_10_kept` | `maintenance_key`, Хольт ищет ключ; подвалы открыты |

### 12.5. Награды

| Тип | Значение |
|---|---|
| Flag | `maintenance_key` |
| Flag | `old_academy_map` (copy) |
| Currency | `credits` +15 |
| Reputation | `ac_rep_faculty_1` |

### 12.6. Реализация

- `QuestNpc` `SergeantHolt`.
- `QuestPickup` `LaundryBin` с `item_id=maintenance_key`.
- Диалог: `ac_sq10_holt.tres`.

---

## 13. SQ-11 — Письмо из галереи

### 13.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_sq_11_hollow_letter` |
| Название | Письмо из галереи |
| Тип | Тихая история, моральный выбор |
| Фаза | `solstice` |
| Giver | Кассия / Рок |
| Локация | A7 Hollow gallery |
| Prerequisites | `ac_sq_08_complete`, `hollow_seen` |
| Completion flag | `ac_sq_11_complete` |
| Canon | Глава 29 (Hollow) |

### 13.2. История

В галерее Hollow Санни замечает конверт, зажатый в руке одного из тел. Письмо адресовано матери. Кассия чувствует, что это важно. Санни может отдать письмо Року, оставить себе или прочитать.

### 13.3. Цели

| # | Objective | Kind | Target | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `find_letter` | INTERACT | `hollow_letter` | да | «Найти письмо» |
| 2 | `decide` | FLAG | `ac_sq_11_resolved` | да | «Решить, что с ним делать» |
| 3 | `talk_cassia` | TALK | `cassia_letter` | нет | «Поговорить с Кассией» |

### 13.4. Ветки

| Выбор | Flag | Последствие |
|---|---|---|
| Отдать Року | `ac_sq_11_rock` | `ac_rep_faculty_2`, Рок благодарит коротко |
| Оставить себе | `ac_sq_11_kept` | `silver_locket`, `ac_rep_cassia_1`; письмо в журнале |
| Прочитать и передать | `ac_sq_11_read` | `silver_locket`, `ac_rep_cassia_2`; Кассия плачет |
| Соврать | — | Невозможно |

### 13.5. Награды

| Тип | Значение |
|---|---|
| Item | `silver_locket` |
| Reputation | `ac_rep_cassia_2` или `ac_rep_faculty_2` |
| Flag | `hollow_letter_resolved` |
| Финал | Дополнительная виньетка в капсуле |

### 13.6. Реализация

- `Interactable` `HollowLetter`.
- `QuestNpc` `CassiaLetter`.
- `QuestChoiceController` для выбора.
- Диалог: `ac_sq11_letter.tres`.

---

## 14. SQ-12 — Прогулка по стене

### 14.1. Паспорт

| Поле | Значение |
|---|---|
| ID | `ac_sq_12_wall_walk` |
| Название | Прогулка по стене |
| Тип | Исследование, атмосфера |
| Фаза | `week_one` / `week_two` |
| Giver | Стражник (`wall_guard`) |
| Локация | A1 башня → A9 wall walk |
| Prerequisites | `ac_mq_01_complete` |
| Completion flag | `ac_sq_12_complete` |
| Canon | ИНТЕРПРЕТАЦИЯ |

### 14.2. История

Стражник спорит, что Санни не дойдёт до восточной турели до удара колокола. Это не насмешка, а скука. Санни идёт по стене, видит город, снег и купол. Наверху — тишина и мысль о Рейн.

### 14.3. Цели

| # | Objective | Kind | Target | Required | Текст |
|---|---|---|---|---:|---|
| 1 | `talk_guard` | TALK | `wall_guard` | да | «Принять спор» |
| 2 | `reach_east_turret` | REACH | `east_turret` | да | «Дойти до восточной турели» |
| 3 | `return_guard` | TALK | `wall_guard` | да | «Вернуться» |

### 14.4. Ветки

| Выбор | Flag | Последствие |
|---|---|---|
| Дойти | `ac_sq_12_won` | `old_academy_map`, `credits` +10, `ac_rep_faculty_1` |
| Не дойти | `ac_sq_12_lost` | `credits` −5, стражник смеётся без злобы |
| Отказаться | `ac_sq_12_declined` | Ничего |

### 14.5. Награды

| Тип | Значение |
|---|---|
| Flag | `old_academy_map` |
| Currency | `credits` +10 |
| Reputation | `ac_rep_faculty_1` |
| Lore | Вид на город, мысль о Рейн |

### 14.6. Реализация

- `QuestNpc` `WallGuard`.
- `QuestTriggerZone` `EastTurret`.
- Wall walk — подзона A1, без новой сцены.
- Диалог: `ac_sq12_wall.tres`.

---

## 15. Награды: сводная таблица

| Награда | Тип | Источник | Где используется |
|---|---|---|---|
| `provisions` ×2 | Item | SQ-01 | Еда/отдых |
| `brass_charm` | Key item | SQ-01 | Возврат Мире |
| `academy_uniform` | Item | SQ-02, MQ-02 | Косметика/форма |
| `compass` | Item | SQ-03 | Навигация |
| `star_chart` | Key item | SQ-03 | Библиотека/лор |
| `dead_languages` | Knowledge | SQ-04, MQ-07 | True Name, лор |
| `parry_basics` | Knowledge | SQ-05, MQ-08 | Тренировки |
| `dojo_token` | Access | SQ-05, MQ-08 | Ночное додзё |
| `academy_rank` | Flag | SQ-06 | Диалоги, финал |
| `training_blade` | Item | SQ-06, MQ-08 | Тренировка |
| `kasper_favor` | Flag | SQ-07 | Уникальная реплика/доступ |
| `cassia_ribbon` | Item | SQ-08 | Финал, виньетка |
| `field_medkit` | Item | SQ-09, MQ-11 | Лечение |
| `maintenance_key` | Access | SQ-10, MQ-09 | Подвалы |
| `old_academy_map` | Item | SQ-09/10/12 | Карта, лор |
| `silver_locket` | Item | SQ-11 | Финал, журнал |
| `credits` | Currency | SQ-01/02/06/07/10/12 | Кофе, мелочи |
| `ac_rep_cassia_*` | Reputation | SQ-08/11 | Диалоги, финал |
| `ac_rep_legacy_*` | Reputation | SQ-06/07 | Каспер |
| `ac_rep_outcast_*` | Reputation | SQ-01/02/05/09 | Кассия/Мира/Рен |
| `ac_rep_faculty_*` | Reputation | SQ-03/04/09/10/12 | Рок/Джулиус |

**Запрещено:** Memories, soul shards, +HP, +урон, новые Аспекты, уровни.

---

## 16. Доступность по фазам

| SQ | arrival | induction | week_one | week_two | solstice |
|---|---|---|---|---|---|
| SQ-01 | — | ✓ | ✓ | ✓ | ✓ |
| SQ-02 | — | — | ✓ | ✓ | ✓ |
| SQ-03 | — | — | ✓ | ✓ | ✓ |
| SQ-04 | — | — | ✓ | ✓ | ✓ |
| SQ-05 | — | — | — | ✓ | ✓ |
| SQ-06 | — | — | — | ✓ | ✓ |
| SQ-07 | — | — | — | ✓ | ✓ |
| SQ-08 | — | — | ✓ | ✓ | ✓ |
| SQ-09 | — | — | — | ✓ | ✓ |
| SQ-10 | — | — | ✓ | ✓ | ✓ |
| SQ-11 | — | — | — | — | ✓ |
| SQ-12 | — | — | ✓ | ✓ | ✓ |

**Правило:** ни один SQ не становится недоступным при переходе фазы, кроме SQ-11 (финал). Это сделано, чтобы игрок не терял контент из-за спешки. Если нужен тайм-менеджмент, можно закрыть SQ-01/02 после `week_two`, но это опционально.

---

## 17. Последствия и флаги

### 17.1. Кто появляется в финале

| Флаг | Кто | Что меняется |
|---|---|---|
| `mira_owes_favor` / `ac_sq_01_returned` | Мира | Стоит у стены, кивает |
| `ren_friend` / `ac_sq_02_quiet` | Рен | Сидит рядом с Мирой |
| `ac_sq_05_helped` | Рен | Тренируется в додзё, кивает |
| `ac_sq_09_saved` / `helped_escape` | Рен | Появляется/исчезает |
| `ac_sq_08_served` | Кассия | Лента на запястье Санни |
| `ac_sq_11_resolved` | Hollow | Дополнительная реплика Кассии |
| `kasper_favor` | Каспер | Уникальная реплика в капсуле |
| `academy_rank` | Рок | Упоминает место в списке |

### 17.2. Что не меняется

- Сюжет, смерть/выживание, доступ к капсуле, канонические события.
- Отношения не превращаются в романтику.
- Никакие SQ не дают Памятей или кристаллов.

---

## 18. Реализация

### 18.1. Данные

- `resources/quests/academy/ac_sq_01_lucky_charm.tres` … `ac_sq_12_wall_walk.tres`.
- `scope = &"academy"`, `category = SIDE`, `auto_start = false`, `show_available = false`.
- `prerequisites` — флаги MQ/фазы.
- `completion_flag` — `ac_sq_XX_complete`.

### 18.2. Сцены

| SQ | Сцена | Основные узлы |
|---|---|---|
| SQ-01 | A3 | `CadetMira`, `LaundryVent`, `CadetMiraReturn` |
| SQ-02 | A5/A3 | `CadetRen`, `DojoLocker03`, `CadetRenReturn` |
| SQ-03 | A6 | `Julius`, `RestrictedArchive`, `JuliusReturn` |
| SQ-04 | A6 | `LibraryPlaque`, `Julius`, `QuestChoiceController` |
| SQ-05 | A5 | `DojoNight` trigger, `CadetRenNight` |
| SQ-06 | A5 | `RockLadder`, 3 training fights |
| SQ-07 | A5/A4 | `KasperBet`, training fight |
| SQ-08 | A4 | `CassiaTea`, `KitchenTea`, `TeaStation` |
| SQ-09 | A8 | `CadetMira`, `OldFiltration`, `CadetRenLost` |
| SQ-10 | A3/A8 | `SergeantHolt`, `LaundryBin` |
| SQ-11 | A7 | `HollowLetter`, `CassiaLetter` |
| SQ-12 | A1/A9 | `WallGuard`, `EastTurret` |

### 18.3. Триггеры

- `QuestNpc.start_quest_id` — старт по первому разговору.
- `QuestPickup.start_quest_id` — старт по подбору.
- `QuestTriggerZone.start_quest_id` — старт по входу.
- `required_flags` — не показывать объект раньше времени.
- `one_shot = true` — не повторять диалог.

### 18.4. Журнал

- Каждый SQ имеет короткую запись: «Мира потеряла талисман», «Рен не вернулся», и т.д.
- Награда описывается текстом, а не только id.
- После завершения запись остаётся в журнале.

### 18.5. Сохранение

- Все SQ-флаги — в `NightmareRunState.flags`.
- `QuestSystem` snapshot уже включает квесты и флаги.
- При загрузке объекты восстанавливают состояние по флагам.
- Награды идемпотентны (`reward_claimed`).

---

## 19. Тесты

| Тест | Что проверяет |
|---|---|
| `test_academy_side_quest_data` | 12 SQ валидны; цели ссылаются на существующие id. |
| `test_academy_side_flow` | Каждый SQ завершается; ветки ставят флаги. |
| `test_academy_side_rewards` | Награды не дублируются; нет запрещённых типов. |
| `test_academy_side_softlock` | SQ не блокируют MQ; пропуск SQ не ломает финал. |
| `test_academy_side_save` | Флаги/награды переживают save/load. |

---

## 20. Приёмка

- [ ] 12 SQ имеют валидные `QuestDefinition`.
- [ ] Ни один SQ не обязателен для MQ/финала.
- [ ] Все SQ завершаемы без боя (кроме тренировочных SQ-06/07).
- [ ] Награды не дают Памятей/кристаллов/статов.
- [ ] Flaw используется минимум в 2 SQ (SQ-01, SQ-08).
- [ ] Ветки меняют реплики/флаги, но не канон.
- [ ] Журнал и карта не спойлерят скрытые SQ.
- [ ] Сохранение/загрузка восстанавливает прогресс.
- [ ] Нет soft-lock при пропуске SQ.
- [ ] Документация совпадает с картой и MQ.

---

## 21. Открытые вопросы

1. **12 SQ или 8?** Рекомендация: 8 обязательных к реализации, 4 — P1 (SQ-04, SQ-07, SQ-11, SQ-12).
2. **Тренировочные бои:** использовать существующий `CombatController` с `training=true` или сделать скриптовые? Рекомендация: существующий, с запретом смерти.
3. **Ночное додзё:** отдельная сцена или смена света в A5? Рекомендация: смена света, без новой сцены.
4. **Подвалы:** нужны ли SQ-09/10, если A8 не входит в первый проход? Рекомендация: да, но P1.
5. **Кассия:** сколько сцен ей давать? Рекомендация: 2 SQ + MQ-12; не превращать в романтику.
