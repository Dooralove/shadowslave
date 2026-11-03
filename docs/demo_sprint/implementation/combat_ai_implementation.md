# Combat & Enemy AI — Stage 2 implementation specification

**Домен:** A05 — Combat & Enemy AI  
**Дата:** 2026-11-03  
**Статус:** Stage 2 implementation spec. **Не является разрешением на правку игровых файлов.** Ждёт утверждения `MASTER_PLAN.md`, `FILE_OWNERSHIP.md`, `INTEGRATION_CONTRACTS.md`.  
**Базовая точка:** commit `0335a5c346901af2146413b5a159b442d326d8de`, branch `s3-park-art`, dirty tree.  
**Рабочая ветка:** `feat/a05-combat-ai` — создаёт и мержит Technical Director. A05 не коммитит и не пушит.  
**Проверки этого документа:** статическое чтение кода, сцен, `.tres` и отчётов. Новые прогоны в рамках Stage 2 не выполнялись; всё, что не перепроверено, помечено **NOT TESTED**.

> Этот документ — не второй боевой дизайн и не второй AI. Он описывает, как довести уже существующие `CombatController`, `MeleeAttack`, `Hurtbox`, `HealthComponent`, `CarapaceEnemy`, `CombatHud` и `QuestKillCredit` до приёмки демо, не создавая параллельных систем.
>
> **Stage 5 note:** A05-01b реализован через `CarapaceEnemy.spawn_profile` + `spawn_profile_tag`, который читает существующий `QuestKillCredit.enemy_tag`; правка A03 больше не требуется. A03 mapping остаётся опциональной альтернативой.

---

## 0. Executive summary

| Область | Фактическое состояние | Что требуется по спецификации |
|---|---|---|
| E01, Z03 | Спавн есть: 1 раненый карапакс, 65 HP; урон 18 идёт стандартной клешнёй; в прошлом runtime-прогоне убит за 6 ударов P1, игрок 100 → 46 HP, смерть игрока вернула на чекпоинт | Подтвердить P0-приёмку; отдельным P1-профилем сделать `0.95` замах и `carapace_wounded_e01` data |
| E02, Z13 | Спавн 3 карапаксов есть; группового боя и токенов нет; ручной бой **NOT TESTED** | Дать 1–2 одновременных атакующих, остальным — давление; принять бой 45–75 с |
| E03, Z14 | Спавн 2 карапаксов есть; мост не проверен вручную | Проверить проход по мосту, отсутствие блока трупами, 30–50 с |
| Смерть игрока | Игрок возвращается на чекпоинт с 100 HP; живые враги сохраняют полученный урон | Сбросить живых врагов в полный HP и на spawn; мёртвых не воскрешать |
| Weak spot | Только `Inspectable`; урона не множит | Отдельный hurtbox с множителем, без второго Inspectable |
| HUD | `CombatHud` сам ищет ближайшего врага; цель может залипнуть, имя не сбрасывается | API смены цели в `CombatController` + потребление в `CombatHud` (A08) |
| Клипы | Hit/death — процедурный flinch + `Death`; authored hit-клипов нет | Интегрировать 2–3 клипа A06 или оставить явно помеченный fallback |
| Azure Blade | Есть как предмет/Память, но не включает armed-режим; в `sunny_waking_poc.tscn` и `armed_attack`, и `unarmed_attack` указывают на P1-кулак | Одного `set_unarmed(false)` недостаточно: нужен armed `AttackData` + клип, который есть у P1-модели; A05 не делает квестовый хук |
| Тесты | Целевой боевой набор 111/111, 496 assert (прошлый прогон); полный GUT **NOT TESTED** | Повторить после freeze; тесты пишет A10, A05 даёт сценарии |

**Реальная оценка A05:** 5,5–7,5 person-days на код, данные и проверки, плюс 0,5 day A08 на HUD, 0,5 day A06 на blade-клип (если A05-09 нужен) и 1–1,5 day A10 на тесты/ручной прогон.  
**Главный риск:** не код, а владение общими файлами и порядок смерти/респавна. Поэтому A05-04, A05-05 и A05-08 разбиты так, чтобы не требовать постоянных правок A03/A06/A08.

---

## 1. Что конкретно предстоит реализовать

### 1.1. Два гейта, два объёма

| Гейт | Обязательные встречи | Что можно не делать | Условие старта |
|---|---|---|---|
| **M1** | **Только E01** в Z03 | E02, E03, SQ-FS, Z11–Z18 | `A00-07` M1 gate |
| **Tech demo** | **E01–E03** | E04/E05, Mountain King как сюжетный бой | `A00-08` после M1 PASS |

`MASTER_PLAN.md` §7: E01 обязателен для M1; E02/E03 — tech demo; weak spot, групповой AI и hit/death clips — P1.  
`AGENT_TASKS.md` A05-01…A05-08 сохраняются как канонические ID. Под-ID `A05-00`, `A05-01b`, `A05-08a/b` вводятся только для разделения владения и не создают новых агентов; TD может свернуть их в A05-01/A05-08 при утверждении. `A05-09` — новый условный ID для Azure Blade; он не входит в `AGENT_TASKS` до решения TD.

### 1.2. Состав встреч

| ID | Зона | Состав | HP | Урон | Гейт | Что проверяет игрок |
|---|---|---|---:|---:|---|---|
| **E01** | Z03, `Gameplay/Encounters/WoundedScavenger` | 1 раненый карапакс | 65 | 18 | M1 | Читает замах, уклоняется, бьёт в ответ |
| **E02** | Z13, `Gameplay/Encounters/PacksZ13` | 3 стандартных карапакса | 95 каждый | 18 | Tech demo | Разделяет группу, не даёт окружить |
| **E03** | Z14, `Gameplay/Encounters/TwoCarapaces` | 2 стандартных карапакса | 95 каждый | 18 | Tech demo | Держит узкий мост, не падает, завершает пару |

**Никаких новых врагов, «толпы» или дополнительных спавнов не добавляется.** E01 = 1, E02 = 3, E03 = 2 — это фиксированное количество из `combat_encounters.md` и `MASTER_PLAN.md`.

### 1.3. Что входит в работу A05

1. **E01 P0:** подтвердить и, если нужно, стабилизировать текущий бой 65 HP / 18 урона; смерть врага не блокирует выходы; квестовый кредит `wounded_scavenger_slain` ставится один раз.
2. **E01 P1:** отдельный профиль `carapace_wounded_e01` с замахом `0.95`, скоростью `1.6`, дистанцией `2.0`, уроном `18`; он подключается A05-адаптером `spawn_profile` по `QuestKillCredit.enemy_tag`, A03 mapping остаётся опциональным. Sandbox-профиль `carapace_wounded` с 14 урона не меняется.
3. **E02 P1:** три карапакса, групповой токен, давление ожидающих, отсутствие трёх одновременных атак, 45–75 с.
4. **E03 P1:** два карапакса на мосту, проход после боя, отсутствие падения/блока, 30–50 с.
5. **A05-04 P0:** сброс живых врагов после смерти игрока; мёртвые остаются мёртвыми; повторный кредит не выдаётся.
6. **A05-05 P1:** weak spot hurtbox с множителем; `Inspectable` не участвует в расчёте урона.
7. **A05-06 P1:** групповой токен на локальном сканировании, без нового autoload/manager.
8. **A05-07 P1:** интеграция authored hit/death клипов, если A06 их поставит; procedural fallback сохраняется.
9. **A05-08 P1:** API цели боя в `CombatController`; HUD-часть делает A08.
10. **A05-09 P1, условно:** боевой API для Azure Blade; квестовый хук остаётся за A04/A06.

### 1.4. Чего в этой работе нет

- Второго `CombatController`, `MeleeAttack`, `HealthComponent`, `CombatHud`, `QuestSystem`, `CombatEncounter` или AI-директора.
- Новых autoload, input actions, save-полей, квестовых флагов и resource-каталогов.
- Правки `scenes/locations/**`, `scripts/locations/**`, `scripts/player/**`, `assets/characters/**`, `scenes/ui/**` без claim и владельца.
- Балансного переписывания Mountain King, ranged/controller-врагов, poise/stagger/knockdown, lock-on, combo/parry.
- Финальных моделей, LOD, Blender-генераций и внешних ассетов.

---

## 2. Какие существующие элементы требуется исправить

| ID / backlog | Сейчас | Целевое состояние | Причина |
|---|---|---|---|
| **SS-012 / A05-01** | E01 спавнится с 65 HP, но использует стандартный `carapace_scavenger.tres`: замах `0.85`, скорость `2.1`, урон `18` | P0: 65 HP / 18 урона / 6 ударов P1 / выходы свободны. P1: отдельный `carapace_wounded_e01` с `0.95 / 1.6 / 18`; sandbox `carapace_wounded` 14 не трогать | Учебный бой должен читаться медленнее стандартного, не ломая sandbox |
| **SS-011 / A05-04** | После смерти игрока живые враги остаются с полученным уроном; мёртвые уже не блокируют | Живые — полный HP, spawn, IDLE, attack enabled; мёртвые — остаются мёртвыми; кредит не дублируется | Игрок не должен возвращаться к «полуживому» паку |
| **SS-059 / A05-06** | Три карапакса Z13 атакуют независимо; возможен «конг» из трёх атак | Не более 1–2 в `TELEGRAPH/ATTACK`; остальные давят/обходят; после смерти одного токен освобождается | Групповой бой должен быть честным |
| **SS-058 / A05-05** | `WeakSpot` — `CSGSphere3D` + `Inspectable`, урон обычный | Отдельный `Hurtbox` с `damage_multiplier`; удар в сустав > обычного; `Inspectable` не меняет урон | Слабое место должно быть механикой, а не только осмотром |
| **SS-118 / A05-08** | `CombatHud` сам сканирует ближайшего врага; при смене цели имя/полоса могут залипать; явная цель блокируется `_enemy_locked` | A05 отдаёт `combat_target_changed`/`get_combat_target()`; A08 переключает полосу, сбрасывает имя и скрывает её после боя | Один HUD, но цель должна быть управляемой |
| **SS-121 / A05-07** | Hit-реакция — процедурный flinch; death-клип есть | Если A06 даёт клипы: hit/death проигрываются в разрешённых состояниях; flinch не ломает `TELEGRAPH/ATTACK/DEATH` | Финальный бой не должен выглядеть процедурным |
| **SS-116 / A05-09** | Azure Blade — Память/квест, но `CombatController` остаётся unarmed. В демо-модели `armed_attack` и `unarmed_attack` — один и тот же `sunny_light_unarmed_p1.tres`, клип `HumanSpBoxing`; `1H_Melee_Attack_Slice_Diagonal` в P1-модели не найден | После подбора клинка — armed-профиль 20 урона; клип должен быть подтверждён A06. Если клипа нет, armed-режим невозможен без нового клипа/модели | 24 удара в E02 — плохой бой; нельзя обещать 20 dmg без данных и клипа |
| **E03 / A05-03** | Спавн 2 карапаксов на мосту есть; ручной проход не проверен | Мост проходим; трупы не блокируют; враги не сталкивают в пропасть без шанса | E03 — обязательная tech demo-встреча |
| **E01/E02/E03** | `CombatEncounter` существует, но `LabyrinthQuestDirector` спавнит врагов напрямую | Не внедрять `CombatEncounter` в Лабиринт без необходимости; локальные токены и сброс живут в `CarapaceEnemy` | Не создавать второй слой encounter-логики |
| **Документы** | `docs/design/11_combat_system.md` говорит о 80 HP / 10–16 урона и dodge `0.42/0.22`; факт — 95 HP / 18 и `0.8/0.3` | TD фиксирует актуальные значения в дизайн-документе | Не менять код под устаревший документ |

---

## 3. Какие новые элементы требуется создать

Новые элементы — только расширения существующих классов и данных. Новых систем нет.

| Элемент | Тип | Где | Зачем | Задача |
|---|---|---|---|---|
| `damage_multiplier` | `@export` в `Hurtbox` | `scripts/combat/hurtbox.gd` | Множитель > 1 для weak spot; `damage_scale` остаётся блоком | A05-05 |
| `hit_cue_override` | `@export` в `Hurtbox` | `scripts/combat/hurtbox.gd` | Weak spot не должен озвучиваться как «flesh» | A05-05 |
| `select_hit_targets()` | метод `MeleeAttack` | `scripts/combat/melee_attack.gd` | Один удар не должен попасть в body и weak spot дважды | A05-05 |
| `combat_target_changed` | сигнал `CombatController` | `scripts/combat/combat_controller.gd` | HUD получает цель без второго сканера | A05-08a |
| `get_combat_target()` | метод `CombatController` | `scripts/combat/combat_controller.gd` | Публичный read-only API для HUD/тестов | A05-08a |
| `equip_armed(data, clip)` | метод `CombatController` | `scripts/combat/combat_controller.gd` | Честный armed-режим без правки P1-сцены | A05-09 |
| `reset_on_player_death` | `@export` в `CarapaceEnemy` | `scripts/combat/carapace_enemy.gd` | Локальный сброс живого врага | A05-04 |
| `max_simultaneous_attackers` | `@export` в `CarapaceEnemy` | `scripts/combat/carapace_enemy.gd` | 1–2 атакующих в группе | A05-06 |
| `attack_group_radius` | `@export` в `CarapaceEnemy` | `scripts/combat/carapace_enemy.gd` | Локальный радиус группы без encounter ID | A05-06 |
| `can_start_attack()` | метод `CarapaceEnemy` | `scripts/combat/carapace_enemy.gd` | Тестируемая проверка токена | A05-06 |
| `carapace_wounded_e01` profile | новый `.tres` | `resources/combat/enemies/carapace_wounded_e01.tres` | Медленный учебный карапакс; sandbox `carapace_wounded` 14 не меняется | A05-01b |
| Weak spot hurtbox | новый дочерний `Area3D` в сцене | `scenes/enemies/carapace_enemy.tscn` | Реальный урон в сустав | A05-05 |
| Authored hit/death клипы | ассеты A06 | `assets/characters/enemies/...` | Убрать процедурный flinch из финального боя | A05-07 |

**Явно не создаём:** `EnemyManager`, `CombatDirector`, `WeakSpotSystem`, `CombatTargetingSystem`, второй `CombatHud`, второй `CombatEncounter`, новый autoload, новую сцену врага-дубликата.

---

## 4. Какие файлы предстоит изменить

### 4.1. Файлы A05

| Файл | Действие | Задачи | Комментарий |
|---|---|---|---|
| `scripts/combat/carapace_enemy.gd` | изменить | A05-04, A05-06 | Снимок spawn, сброс после смерти игрока, токен, pressure-страйф |
| `scripts/combat/carapace_animator.gd` | изменить | A05-07 | `hit_clip`, `death_clip`, fallback |
| `scripts/combat/combat_controller.gd` | изменить | A05-08a, A05-09 | Сигнал цели, `get_combat_target()`, при необходимости — явный armed API |
| `scripts/combat/hurtbox.gd` | изменить | A05-05 | `damage_multiplier`, `hit_cue_override`, безопасный clamp |
| `scripts/combat/melee_attack.gd` | изменить | A05-05 | Выбор одного hurtbox на владельца, приоритет weak spot |
| `scenes/enemies/carapace_enemy.tscn` | изменить | A05-05, A05-07 | Weak spot Area3D, при наличии — clip refs |
| `resources/combat/enemies/carapace_wounded_e01.tres` | создать | A05-01b | 65 HP, 18 урона, `0.95` замах, `1.6` скорость; attack = `carapace_claw.tres` |
| `resources/combat/enemies/carapace_wounded.tres` | **не менять** | — | Sandbox-профиль 14 урона остаётся для `combat_course` |
| `docs/demo_sprint/design/combat_encounters.md` | обновить после проверок | A05-01…A05-09 | Только фактические результаты, без обещаний |
| `docs/demo_sprint/implementation/combat_ai_implementation.md` | этот документ | — | Stage 2 spec |

`health_component.gd`, `combat_encounter.gd`, `mountain_king.gd`, `mountain_king_config.gd`, `scenes/characters/mountain_king.tscn` **не входят в обязательный объём**. Их не трогаем, если TD не расширит A05-04 на босса.

### 4.2. Файлы других специалистов — только через владельца / claim

| Файл | Владелец | Что нужно | Задача |
|---|---|---|---|
| `scripts/locations/forgotten_shore_labyrinth/labyrinth_quest_director.gd` | A03 | **Не требуется:** A05 `spawn_profile` уже применяет `carapace_wounded_e01` по `QuestKillCredit.enemy_tag`; явный mapping — опциональная альтернатива | A05-01b |
| `scripts/ui/combat_hud.gd`, `scenes/ui/combat_hud.tscn` | A08 | Подписка на `combat_target_changed`, смена/скрытие цели, сброс имени | A05-08b |
| `scripts/player/fall_recovery.gd` | A06 | **Не менять.** Использовать существующий `health.died` и `recover()` | A05-04 |
| `scripts/player/sunny_controller.gd` | A06 | **Не менять.** Использовать существующий `set_unarmed(false)` только как mode-toggle; armed data/clip задаёт A05 API + A06/A04 | A05-09 |
| `assets/characters/enemies/**`, `assets/animations/**` | A06 | Hit/death клипы, если будут | A05-07 |
| `tests/**`, `tools/audit/**` | A10 | Новые regression-тесты и probes | A10 |
| `resources/quests/azure_blade.tres`, `scripts/quests/quest_pickup.gd` | A04 | Решение о хуке Azure Blade | A05-09 |
| `project.godot`, `.mcp.json`, `opencode.json` | A00 | Не менять | — |
| `scenes/locations/**`, `scripts/locations/**` (кроме одной строки A03) | A03 | Не менять | — |
| `scenes/ui/**`, `scripts/ui/**` (кроме HUD-задачи A08) | A08 | Не менять | — |

### 4.3. Чего A05 не касается

- `LabyrinthQuestDirector` не переписывается; меняется только mapping профиля через A03.
- `FallRecovery` не переписывается; смерть игрока уже возвращает HP/позицию.
- `QuestKillCredit` не дублируется; используется существующий адаптер.
- `GameplayHud` не получает второй боевой HUD.
- Геометрия Z13/Z14, ширина моста и маркеры — A03.

---

## 5. Какие ресурсы потребуются

### 5.1. Существующие данные

| Ресурс | Текущие значения | Решение |
|---|---|---|
| `resources/combat/enemies/carapace_scavenger.tres` | 95 HP, 18 урона, `0.85` замах, `1.05` recovery, `2.1` скорость, `2.1` дистанция | Оставить; это E02/E03 |
| `resources/combat/attacks/carapace_claw.tres` | 18 урона, cooldown `1.45`, active `0.25`, reach `1.35`, radius `1.0`, contact `0.40`, guard `32` | Оставить |
| `resources/combat/enemies/carapace_wounded.tres` | 65 HP, **14 урона**, `0.95` замах, `1.20` recovery, `1.6` скорость, `2.0` дистанция | **Не менять:** sandbox `combat_course`; для E01 — новый `_e01` |
| `resources/combat/attacks/carapace_wounded_claw.tres` | **14 урона**, cooldown `1.65`, active `0.25`, contact `0.40`, guard `24` | **Не менять:** sandbox |
| `resources/combat/combat_settings.tres` | dodge `0.8`, i-frames `0.3`, cost `16`, post-hit i-frames `0.25`, block `0.3` | Не менять без отдельного решения |
| `resources/combat/attacks/sunny_light_armed.tres` | 20 урона, cooldown `0.95`, windup `0.3`, active `0.2`, contact `0.4`, stamina `10` | Не менять; **не подключён** к демо-модели |
| `resources/combat/attacks/sunny_light_unarmed_p1.tres` | 12 урона, cooldown `0.9`, windup `0.3`, active `0.2`, contact `0.33`, stamina `6` | Не менять; текущий armed/unarmed в `sunny_waking_poc.tscn` |
| `assets/characters/sunny_realistic_poc/sunny_waking_poc.tscn` | `start_unarmed=true`; `armed_attack` и `unarmed_attack` = `sunny_light_unarmed_p1.tres`; клип `HumanSpBoxing` | A06: подтвердить наличие blade-клипа или дать его; A04/A05: armed loadout API |
| `resources/combat/attacks/sunny_light_unarmed.tres` | 12 урона, contact `0.18` | Оставить для KayKit-арены |
| `resources/inspect/carapace_weak_spot.tres` | `Inspectable` | **Не менять:** владелец A04; урон не должен идти через него |

### 5.2. Новые/изменённые данные

| Данные | Значение | Где | Примечание |
|---|---|---|---|
| `carapace_wounded_e01` | 65 HP, 18 урона, `0.95` telegraph, `1.2` recovery, `1.6` speed, `2.0` distance; attack = `carapace_claw.tres` | `resources/combat/enemies/carapace_wounded_e01.tres` | Новый профиль только для E01; sandbox `carapace_wounded` 14 не трогать |
| Weak spot `damage_multiplier` | `1.5` (TD может выбрать `2.0`) | `Hurtbox` node в `carapace_enemy.tscn` | Отдельный `Area3D`, radius `0.18`, layer `16`, mask `0` |
| Weak spot hit cue | `combat_hit_carapace` | `Hurtbox.hit_cue_override` | Иначе `hit_cue()` даст `flesh` |
| `max_simultaneous_attackers` | `2` | `CarapaceEnemy` export | 1–2 по дизайну |
| `attack_group_radius` | `24.0` | `CarapaceEnemy` export | E02 max dist ~20.9; E03 — 16; группы далеко друг от друга |
| `reset_on_player_death` | `true` | `CarapaceEnemy` export | Только живые |
| `combat_target` radius | `settings.combat_radius = 8.0` | `CombatController` | Не показывать врага за 30 м |
| Hit/death clips | имена от A06 | `CarapaceAnimator` exports | Если клипов нет — fallback |

**Формат данных:** все новые числовые значения — в типизированных `.tres` (`EnemyData`, `AttackData`); JSON не добавляется.  
**Внешние ассеты и лицензии:** не требуются. Blender, Krita, Materialize, glTF-Transform и генерации моделей в этой задаче не используются. Новых MCP-серверов нет.

---

## 6. Какие инструменты использовать

| Инструмент | Назначение | Ограничение |
|---|---|---|
| Godot 4.7.2 headless | `--import`, GUT, probes | Class cache в грязном дереве нестабилен; перед прогоном остановить лишние Godot-процессы |
| GUT | Целевые боевые тесты | Тесты принадлежат A10; A05 не правит их «под зелёный» |
| `tools/audit/combat_labyrinth_probe.gd` | Read-only проверка 6 врагов, HP, позиций | Не менять сцену ради probe |
| `tools/audit/combat_timing_probe.gd` | Измерение контакта клипа по кости | Только чтение; результаты — в отчёт |
| Godot MCP | Runtime-проверка E01, HUD, death/respawn | Read-only для игровых ресурсов; не менять сцены через MCP |
| Скриншоты | E01/E02/E03, weak spot, HUD | Сохранять в `docs/demo_sprint/qa/`, не выдавать за финальный арт |

**Не использовать:** Blender/Modly для боевых данных, новые MCP-серверы, второй test runner, внешние библиотеки.

---

## 7. Какие зависимости существуют

### 7.1. Жёсткие зависимости

| ID | Зависимость | Почему блокирует | Кто |
|---|---|---|---|
| **A00-01** | Freeze + чистый baseline + полный GUT | Нельзя отличить старый fail от нового | A00 |
| **A00-03** | Утверждение `MASTER_PLAN`, `FILE_OWNERSHIP`, `INTEGRATION_CONTRACTS` | Без этого запрещены правки игровых файлов | A00 |
| **A00-05** | `ACTIVE_CLAIMS` для shared files | HUD/A03 mapping иначе конфликтуют | A00 |
| **A00-08** | Разрешение tech demo Z11–Z18 | E02/E03 нельзя принимать раньше M1 | A00 |
| **A03-08** | Z03/Z10 route, G1–G5, финальная зона | E01 должен быть достижим и не блокировать выходы | A03 |
| **A03-10** | Z11–Z18, Z13/Z14 | E02/E03 физически существуют | A03 |
| **A04-08** | Save/load, checkpoint | Смерть/респавн должны совпадать с чекпоинтом | A04 |
| **A04-10** | M1 final logic | Не влияет на бой, но задаёт порядок сцены | A04 |
| **A06-06** | Стабильный `SunnyAnimator`/Mannequin | Без него P1-удар и death-анимация ломаются | A06 |
| **A06-10** | Carapace/Larva hit/death clips | A05-07 без клипов не закрывается | A06 |
| **A08-01** | Combat HUD | A05-08b требует HUD-владельца | A08 |
| **A10** | Regression-тесты и ручной прогон | A05 не владеет `tests/**` | A10 |

### 7.2. Критический путь

```text
A00 freeze / approve
  → A05-00 preflight
  → A05-01 E01 baseline
  → A05-04 respawn
  → A05-06 group token
  → A05-02 E02
  → A05-03 E03
  → A05-05 weak spot
  → A05-07 clips (если A06 готов)
  → A05-08 HUD (A05 API + A08 UI)
  → A10 tests / manual
```

`A05-01b` (wounded profile) может идти параллельно A05-04, но требует одной строки A03.  
`A05-09` (Azure Blade) не блокирует M1 и не должен задерживать E01.

---

## 8. С какими специалистами необходимо интегрироваться

### 8.0. Существующий конвейер, который не переписывается

```text
input → CombatController.try_light_attack()
      → MeleeAttack.try_attack() → ACTIVE window
      → Hurtbox.receive_hit() → HealthComponent.take_damage()
      → HitFlash / HitSpark / hit_received

CarapaceEnemy.update_ai()
      → State.TELEGRAPH → MeleeAttack.try_attack()
      → State.ATTACK ждёт MeleeAttack.Phase.RECOVERY/READY
      → State.RECOVERY → State.CHASE

HealthComponent.died → CarapaceEnemy._on_died()
      → collision off, attack disabled
      → QuestKillCredit → NightmareRunState flag + QuestSystem event

CombatController._refresh_combat_state()
      → combat_target_changed → CombatHud (A08)
```

A05 меняет только ветки, помеченные задачами A05; `QuestKillCredit`, `QuestSystem`, `NightmareRunState`, `MeleeAttack`-фазы и `HealthComponent` остаются единственными.

### 8.1. A03 — World & Level

**Нужно:**
1. Подтвердить маркеры `Gameplay/Encounters/WoundedScavenger`, `PacksZ13`, `TwoCarapaces` и то, что E01 не перекрывает выходы Z03.
2. Для A05-01b **правка A03 не требуется:** `CarapaceEnemy.spawn_profile` + `spawn_profile_tag` читают существующий `QuestKillCredit.enemy_tag`; E01 уже получает `carapace_wounded_e01`. Если A03 хочет владеть mapping явно, можно добавить одну строку `apply_data` — двойное применение идемпотентно.
3. Для E03 — подтвердить, что мост Z14 (`POI-Z14-02`, 100×6) проходим, враги стоят на полу, а не на рампе/краю.
4. **A05 не правит** `labyrinth_first_fragment.tscn`, `labyrinth_quest_director.gd` (кроме согласованной строки) и `scenes/locations/**`.

**Если A03 не даёт mapping:** E01 остаётся на стандартном `0.85` замахе; `A05-01b` не закрывается, но M1 P0 может быть принят по `MASTER_PLAN` (там обязателен только 65 HP).

### 8.2. A04 — Gameplay & Quest Systems

**Нужно:**
- Сохранить `QuestKillCredit` и флаги `wounded_scavenger_slain`, `pack_carapace_*`, `bridge_carapace_*`, `hunt_pack`, `bridge_stand`.
- Подтвердить, что респавн живых врагов не сбрасывает kill-флаги и не дублирует награды.
- Для Azure Blade — решить, кто вызывает armed loadout после `azure_blade_picked`; одного `player.set_unarmed(false)` недостаточно, потому что в демо-сцене armed data/clip тоже кулак.

**A05 не делает:** второй QuestSystem, второй kill credit, новые флаги, правку `resources/quests/**`.

### 8.3. A06 — Character & Animation

**Нужно:**
- Стабильный `SunnyAnimator` с P1-клипом `HumanSpBoxing`, contact `0.33`.
- `FallRecovery.recover()` уже вызывает `CombatController.reset_after_recovery()`; менять не нужно.
- Для A05-07 — 2–3 authored клипа: hit (вне committed attack), death, при возможности — flinch/idle variant.
- Для A05-09 — подтвердить, есть ли у P1-модели blade-клип и weapon socket/визуал клинка. `1H_Melee_Attack_Slice_Diagonal` в `sunny_realistic_poc` не найден; у `sunny_real_v3` не найден `get_weapon_socket`. Если клипа/сокета нет, A06 должен их дать или A05-09 переносится.
- Не менять `assets/characters/**` из A05; A05 только интегрирует имена клипов.

**Риск:** если A06 меняет клип атаки, contact `0.4` нужно перемерить `combat_timing_probe`.

### 8.4. A08 — UI/UX

**Нужно:**
- `CombatController` (A05) отдаёт:
  ```gdscript
  signal combat_target_changed(target: Node3D)
  func get_combat_target() -> Node3D
  ```
- `CombatHud` (A08) подписывается, переключает `_enemy_health`, сбрасывает `enemy_label`, скрывает `EnemyPanel` после смерти последнего врага/истечения `combat_grace`.
- `CombatHud` не создаёт второй сканер и не вводит `lock-on`.

**Владение:** A05-08a — только API; A05-08b — A08. Если TD хочет один ID, A05 получает shared-file claim на `combat_hud.gd`; это хуже, потому что нарушает матрицу владения.

### 8.5. A09 — Audio & VFX

**Нужно:** использовать существующие cue ID:
- `combat_swing_armed`, `combat_swing_unarmed`;
- `combat_hit_carapace`, `combat_hit_flesh`, `combat_hit_armor`;
- `creature_carapace_attack`, `creature_carapace_chitter`, `creature_carapace_click`, `creature_carapace_death`;
- `combat_block_metal`, `combat_block_leather`, `combat_guard_break`.

Weak spot должен играть `combat_hit_carapace`, а не `combat_hit_flesh`. Новых звуков не требуется; если A09 меняет cue, A05-05/07 перепроверяются.

### 8.6. A10 — QA & Release

**Нужно:**
- Владеть `tests/**` и `tools/audit/**`.
- Добавить regression-тесты: respawn, weak spot dedup, group token, HUD target switch, E01 profile.
- Провести ручной E01 (M1) и E02/E03 (tech demo).
- Полный GUT — только после freeze; 633/634 не считается PASS.

**A05 не правит тесты.** Если TD даёт исключение, A05 может добавить только точечные тесты в существующие боевые файлы, но это должно быть записано в claim.

### 8.7. A00 — Technical Director

- Создаёт ветку/worktree, подтверждает shared files, мержит.
- Решает спорные пункты §13.
- Не разрешает A05 трогать `project.godot`, `scenes/locations/**`, UI и assets.

---

## 9. Какие ошибки или конфликты могут возникнуть

| Риск | Вероятность | Влияние | Смягчение | Владелец |
|---|---|---|---|---|
| Класс-кеш и параллельные чаты ломают headless | Высокая | Ложные fail, потеря времени | Freeze, остановить лишние Godot, `--import`, чистый targeted run | A00/A10 |
| HUD-владелец и A05-08 конфликтуют | Высокая | Два HUD или залипшая цель | Разделить A05-08a (API) и A05-08b (A08 UI); claim | TD |
| Weak spot даёт двойной удар (body + spot) | Высокая | Ваншот/нечестный урон | `select_hit_targets()` по `health`, один удар на владельца | A05 |
| Респавн воскрешает уникального врага и дублирует кредит | Высокая | Сброс квеста/награды | Живых сбрасывать, мёртвых не воскрешать; не трогать `QuestKillCredit` | A05/A04 |
| Снимок spawn сделан до `global_position` спавнера | Высокая | Враг респавнится в (0,0,0) | `call_deferred` снимок после `add_child`/установки позиции | A05 |
| E01 variant требует A03 | Низкая | E01 остаётся стандартным | A05 `spawn_profile` уже применяет профиль по `QuestKillCredit.enemy_tag`; A03 mapping опционален | A05 |
| E03 мост/край: враг или труп блокирует | Средняя | Soft-lock на маршруте | Проверить collision off, ширину 6 м, spawn на полу | A03/A05 |
| Токен «морит голодом» третьего врага | Средняя | Бой затягивается | Радиус 24 м, 2 слота, после смерти слота — атака; pressure-страйф | A05 |
| Azure Blade не подключён | Средняя | E02 слишком долгий | Решить хук A04/A06; A05 даёт только armed-профиль | TD |
| Нет authored hit/death клипов | Средняя | Процедурный flinch в tech demo | Fallback явно помечен; A05-07 не блокирует E01 | A06 |
| Балансные документы противоречат коду (80/10–16 vs 95/18) | Средняя | Спор о «правильных» числах | TD фиксирует 95/18 для демо; документ обновляется | TD |
| Полный GUT нестабилен | Высокая | Нельзя объявить релиз | Не считать targeted run полным PASS; A10 запускает после freeze | A10 |
| Смерть игрока и `health.died` порядок сигналов | Средняя | Враг не сбрасывается/сбрасывается дважды | `call_deferred`, проверка `state == DEAD`, идемпотентный reset | A05 |
| Смена клипа атаки ломает contact | Средняя | Удар не совпадает с замахом | `combat_timing_probe` после каждого изменения A06 | A05/A06 |

**Протокол конфликта:** остановить правки в затронутой зоне, записать инцидент в `ACTIVE_CLAIMS.md` (`INCIDENTS`), уведомить A00, не «чинить» чужую зону.

---

## 10. Как проверить готовность каждого элемента

### 10.1. Базовые команды

```powershell
# 1. Импорт и проверка проекта
godot --headless --path . --import

# 2. Целевой боевой GUT (14 скриптов, прошлый результат 111/111, 496 assert)
godot --headless --path . -s addons/gut/gut_cmdln.gd `
  -gtest=res://tests/test_melee_attack.gd,res://tests/test_sunny_combat.gd,res://tests/test_combat_controller.gd,res://tests/test_test_enemy.gd,res://tests/test_enemy_animation.gd,res://tests/test_larva_enemy.gd,res://tests/test_carapace_enemy.gd,res://tests/test_combat_arena.gd,res://tests/test_combat_hud.gd,res://tests/test_sunny_animation.gd,res://tests/test_fall_recovery.gd,res://tests/test_mountain_king.gd,res://tests/test_combat_timing.gd,res://tests/test_combat_course.gd -gexit

# 3. Read-only проверка спавнов Лабиринта
godot --headless --path . -s tools/audit/combat_labyrinth_probe.gd
```

**Ожидаемо для probe:** `PLAYER combat_enabled=true`, `ENEMIES count=6`, `WoundedScavenger hp=65`, `PackCarapace1..3 hp=95`, `BridgeCarapace1..2 hp=95`.  
**Не считать это доказательством E02/E03:** probe не запускает бой.

### 10.2. Матрица приёмки по задачам

| Задача | Автоматическая проверка | Ручная/визуальная проверка | Доказательство |
|---|---|---|---|
| A05-01 | probe: 65 HP; 6 ударов P1; `wounded_scavenger_slain` один раз | E01: замах читается, выходы Z03 свободны, труп не блокирует | Лог GUT/probe + скриншот |
| A05-01b | `carapace_wounded_e01.tres` 65/18/0.95/1.6; `apply_data` в runtime | E01: замах заметно медленнее стандартного | Лог + скриншот/видео |
| A05-02 | 3 врага, 3 кредита; `can_start_attack` не даёт 3 одновременно | E02: 45–75 с, нет трёх атак, можно обойти | Лог + запись |
| A05-03 | 2 врага, 2 кредита; трупы collision off | E03: мост проходим, нет падения/блока | Лог + запись |
| A05-04 | Синтетический тест: живой враг 50% → смерть игрока → 100% на spawn; мёртвый остаётся мёртвым | Runtime: смерть в E01, возврат на чекпоинт, нет «полуживых» | Лог + запись |
| A05-05 | `damage_multiplier=1.5`; body 1.0; один удар не бьёт дважды; `Inspectable` не влияет | Удар в сустав визуально/числом сильнее | Лог + скриншот |
| A05-06 | 3 врага: максимум 2 в `TELEGRAPH/ATTACK`; третий в `CHASE`/страйф | E02: нет «конга», бой читается | Лог + запись |
| A05-07 | `hit_clip`/`death_clip` играют в разрешённых состояниях; fallback | E01/E02: flinch не ломает замах | Лог + запись |
| A05-08a | Сигнал эмитится при смене/смерти/null; `get_combat_target()` | — | Лог GUT |
| A05-08b | HUD: цель меняется, имя сбрасывается, панель скрывается | E02: после смерти цели полоса переключается | Лог + скриншот |
| A05-09 | `equip_armed(data, clip)` даёт 20 урона и валидный клип; тест | После клинка E02 идёт быстрее | Лог + запись |

### 10.3. Ручной проход

**E01 (M1, обязательный):**
1. Войти в Z03, получить агро.
2. Убедиться, что замах читается, кольцо/поза совпадают с окном урона.
3. Убить за 6 ударов P1; проверить, что игрок может пережить 3 удара (100 → 46).
4. Умереть, проверить возврат на `CP-SHORE-START`, 100 HP, рабочий удар.
5. Проверить `wounded_scavenger_slain`, отсутствие блока выхода, труп с collision off.

**E02 (tech demo):**
1. Войти в Z13, собрать всех трёх.
2. Проверить: не более двух атакующих, третий давит/обходит.
3. Убить всех, проверить 3 кредита `carapace`, `hunt_pack`, 6 осколков.
4. Проверить, что маршрут можно обойти без убийства всех.
5. Замерить 45–75 с при нормальной игре.

**E03 (tech demo):**
1. Войти на мост Z14, получить агро двух.
2. Проверить, что можно пройти/убить, трупы не блокируют, нет падения из-за врага.
3. Проверить 2 кредита `bridge_carapace`, `bridge_stand`, 4 осколка.
4. Замерить 30–50 с.

**HUD/weak spot:**
- После смерти текущей цели HUD переключается на следующую, имя и HP обновляются; после боя панель скрывается.
- Удар в сустав даёт больше урона, чем в тело; `Inspectable` на суставе не меняет урон.

### 10.4. NOT TESTED

Следующее **не считается проверенным** до фактического прогона:

- Полный GUT и полный ручной проход M1.
- Ручной E02/E03.
- Визуальное совпадение замахов/клешни/меча в живом кадре.
- 1080p / 60 FPS в E01–E03.
- Слуховой тест и VFX на слух/в кадре.
- Поведение после двух смертей подряд и после save/load в бою.
- Weak spot, group tokens, respawn, HUD target switch — **не реализованы в рамках Stage 2**.

---

## 11. Список задач

### 11.1. Сводная таблица

| Task ID | Description | Files | Dependencies | Priority | Effort | Risk | Acceptance Criteria |
|---|---|---|---|---|---|---|---|
| **A05-00** | Preflight: ветка/worktree, baseline, claims, запрет правок до утверждения | — | A00-01, A00-03, A00-05 | P0 | 0,25 d | L | Ветка от frozen baseline; `git status` записан; claims на A03/A08/A10; игровые файлы не изменены |
| **A05-01** | E01 baseline: 65 HP, 18 урона, 6 ударов, выходы свободны, кредит один раз | `scripts/combat/carapace_enemy.gd` (только если фикс), `docs/.../combat_encounters.md` | A03-08, A06-06 | P0 | 0,25 d | L | Probe: 65 HP; 65 − 6×12 → 0; `wounded_scavenger_slain` один раз; труп collision off; E01 manual |
| **A05-01b** | E01 wounded profile: `0.95` замах, `1.6` скорость, 18 урона; A05 spawn_profile | `resources/combat/enemies/carapace_wounded_e01.tres` (new); `scripts/combat/carapace_enemy.gd`, `scenes/enemies/carapace_enemy.tscn` | A05-01 | P1 | 0,5 d | M | Runtime data id `carapace_wounded_e01`; 65 HP; 18 dmg; contact 0,40; E01 заметно медленнее; sandbox 14 не изменён |
| **A05-02** | E02: 3 карапакса, 3 кредита, 45–75 с, побочный обход | `scripts/combat/carapace_enemy.gd` (только баланс/стабильность), `docs/.../combat_encounters.md` | A00-08, A03-10, A05-01, A05-06 | P1 | 0,5 d | M | 3/3 убиты; 3 кредита; ≤2 атакующих; нет stuck; 45–75 с; маршрут обходим |
| **A05-03** | E03: 2 карапакса на мосту, проход, без падения/блока | `scripts/combat/carapace_enemy.gd` (только edge/stuck), `docs/.../combat_encounters.md` | A00-08, A03-10, A05-01, A05-06 | P1 | 0,5 d | M/H | 2/2 убиты; 2 кредита; мост проходим; трупы не блокируют; 30–50 с |
| **A05-04** | Respawn живых врагов после смерти игрока; мёртвые остаются мёртвыми | `scripts/combat/carapace_enemy.gd` | A04-08, A03-08, A05-01 | P0 | 1,0 d | H | Живой враг: 100% HP на spawn, IDLE, attack enabled; мёртвый — DEAD; кредит не дублируется; две смерти подряд |
| **A05-05** | Weak spot hurtbox-множитель; `Inspectable` не влияет на урон | `scripts/combat/hurtbox.gd`, `scripts/combat/melee_attack.gd`, `scenes/enemies/carapace_enemy.tscn` | A05-01, A10 tests | P1 | 1,0 d | H | Удар в сустав ×1,5; тело ×1,0; один удар не бьёт дважды; cue `combat_hit_carapace` |
| **A05-06** | Group attack token: 1–2 атакующих, остальные давят | `scripts/combat/carapace_enemy.gd` | A05-01 | P1 | 1,0 d | M | 3 врага: max 2 в `TELEGRAPH/ATTACK`; третий в `CHASE`/страйф; после смерти слота — атака; нет deadlock |
| **A05-07** | Интеграция hit/death клипов A06; fallback | `scripts/combat/carapace_animator.gd`, `scenes/enemies/carapace_enemy.tscn` | A06-10, A05-01 | P1 | 0,5 d | M | 2–3 клипа играют в разрешённых состояниях; flinch не ломает замах; fallback помечен |
| **A05-08a** | API цели боя в `CombatController` | `scripts/combat/combat_controller.gd` | A05-01 | P1 | 0,25 d | M | `combat_target_changed`/`get_combat_target()`; цель в радиусе 8 м; null после смерти |
| **A05-08b** | HUD: смена цели, сброс имени, скрытие после боя | `scripts/ui/combat_hud.gd`, `scenes/ui/combat_hud.tscn` (A08) | A05-08a, A08-01 | P1 | 0,5 d (A08) | M | Цель меняется; имя/HP обновляются; панель скрывается после смерти последнего |
| **A05-09** | Azure Blade armed loadout API и интеграция (условно) | `scripts/combat/combat_controller.gd`; A04/A06 hook; A06 blade clip + weapon socket | A05-01, A04/A06 decision, A06 clip/socket | P1 (conditional) | 0,5 d | M | `equip_armed(data, clip)` даёт 20 dmg и валидный клип; после клинка E02 быстрее; квестовый хук не в A05; без клипа/сокета — deferred |

**Итого:** A05 ~5,5–6,5 d; A08 ~0,5 d; A10 ~1–1,5 d. Оценки не включают ожидание ассетов A06 и freeze.

### 11.2. Карточки задач

#### A05-00 — Preflight

- **Цель:** исключить правки в грязном дереве и зафиксировать baseline.
- **Шаги:** получить от A00 подтверждение DP-1.0; создать `feat/a05-combat-ai` от frozen commit; записать `git status --short`; открыть claims на A03 (опциональный mapping), A08 HUD, A10 tests.
- **Не делать:** не менять `project.godot`, не запускать массовый reformat, не коммитить.
- **Acceptance:** ветка существует; baseline-лог сохранён; claims подтверждены; A05 не изменил ни одного игрового файла до A00-03.

#### A05-01 — E01 baseline

- **Цель:** подтвердить, что текущий E01 уже играбелен, и не переписывать его без причины.
- **Факты:** `_spawn_enemy` создаёт `WoundedScavenger` с `health_override 65`; data — `carapace_scavenger` (95 HP статов, 18 dmg), поэтому замах `0.85`, скорость `2.1`.
- **Шаги:** прогнать probe; проверить 6 ударов P1 по 12; проверить `wounded_scavenger_slain`; проверить death collision; проверить, что маркер не перекрывает выходы.
- **Если проходит:** код не менять; записать результат; закрыть P0.
- **Acceptance:** 65 HP; 6 ударов; игрок выживает 3 удара (46 HP); труп не блокирует; кредит один раз; E01 manual.

#### A05-01b — E01 wounded profile

- **Цель:** сделать учебный бой медленнее стандартного, не создавая новую сцену.
- **Шаги:** создать `carapace_wounded_e01.tres` (65 HP, 18 dmg, 0.95 telegraph, 1.2 recovery, 1.6 speed, 2.0 distance; attack = `carapace_claw.tres`); **не трогать** sandbox `carapace_wounded.tres` с 14 урона; A03 добавляет mapping в `_spawn_enemy`.
- **Почему не новая сцена:** интерфейс `apply_data` уже есть; новый `.tscn` только удвоит сопровождение.
- **Acceptance:** runtime `data.id == carapace_wounded_e01`; 65 HP; 18 dmg; E01 заметно медленнее; contact 0.40; death/credit не меняются; `combat_course` с 14 dmg не затронут.

#### A05-02 — E02

- **Цель:** три карапакса — групповой бой, а не три независимых дуэли.
- **Шаги:** проверить 3 спавна/3 кредита; включить A05-06; проверить, что маршрут можно обойти; проверить stuck/avoid на равнине Z13; замерить 45–75 с.
- **Не делать:** не добавлять четвёртого врага, не менять награду, не трогать `hunt_pack`.
- **Acceptance:** 3/3; 3 кредита; ≤2 атакующих; нет трёх одновременных; нет stuck; 45–75 с; обход возможен.

#### A05-03 — E03

- **Цель:** пара на мосту не превращает узкий проход в soft-lock.
- **Шаги:** проверить 2 спавна на полу; проверить, что смерть отключает collision; проверить, что труп не перекрывает 6-метровый мост; проверить, что враг не сталкивает игрока в пропасть без телеграфа; замерить 30–50 с.
- **Если мост/спавн плохие:** задача A05-03 не «чинит» геометрию; пишется A03-задача, A05 фиксирует блок.
- **Acceptance:** 2/2; 2 кредита; мост проходим; трупы не блокируют; 30–50 с; нет падения из-за врага.

#### A05-04 — Respawn после смерти игрока

- **Цель:** убрать «полуживых» врагов после возврата на чекпоинт.
- **Технические детали:**
  - снимок `global_transform` делать **deferred**: `_spawn_enemy` добавляет врага в дерево и только потом ставит `global_position`;
  - слушать `HealthComponent.died` игрока; сброс делать `call_deferred`, чтобы `FallRecovery` успел вернуть игрока;
  - подключение к target повторять в `alert_to()`/при появлении игрока: в тестах target назначается после `add_child`, в сцене — до первого кадра;
  - сбрасывать только `state != DEAD`; `health.revive(true)`, `attack.disable()` + `enabled = true`, `state = IDLE`, cooldown/stuck/blocked = 0;
  - `collision_layer/mask` восстановить из сохранённых значений; если враг `_dormant`, оставить layer `0`/physics off и сбросить только HP/позицию;
  - мёртвого не воскрешать: `QuestKillCredit` уже поставил флаг, повторный кредит запрещён.
- **Acceptance:** живой враг после смерти игрока — 100% HP на spawn, IDLE, attack enabled; мёртвый — DEAD; флаг не дублируется; две смерти подряд стабильны; E01 manual.

#### A05-05 — Weak spot

- **Цель:** сустав карапакса реально увеличивает урон, но `Inspectable` остаётся отдельным.
- **Технические детали:**
  - `Hurtbox.damage_multiplier` (не путать с `damage_scale` блока);
  - `MeleeAttack.select_hit_targets(areas)` группирует по `Hurtbox.health` и выбирает hurtbox с большим множителем;
  - `tick()` применяет только выбранные цели; `_hit_this_swing` защищает от повторного удара;
  - weak spot `Area3D` radius `0.18`, layer `16`, mask `0`, `hit_cue_override = combat_hit_carapace`;
  - `Inspectable` остаётся дочерним узлом и не влияет на урон.
- **Acceptance:** weak spot ×1,5; body ×1,0; один удар не бьёт дважды; `Inspectable` не меняет урон; cue правильный; тест A10.

#### A05-06 — Group attack token

- **Цель:** 1–2 атакующих, остальные давят, без нового менеджера.
- **Технические детали:**
  - `max_simultaneous_attackers = 2`;
  - `attack_group_radius = 24.0` (E02 max ~20.9, E03 16; группы далеко);
  - считать соседей в `TELEGRAPH/ATTACK`, живых, не dormant;
  - `can_start_attack()` — публичная проверка для теста;
  - если слот занят, враг остаётся в `CHASE` и делает pressure-страйф, не стоит столбом;
  - при смерти одного слота третий может войти в атаку.
- **Acceptance:** 3 врага — max 2 атакующих; третий в `CHASE`/страйф; после смерти слота атака; нет deadlock; E02 manual.

#### A05-07 — Hit/death clips

- **Цель:** заменить процедурный flinch authored-клипами, не ломая замах.
- **Технические детали:**
  - `CarapaceAnimator` получает `hit_clip`/`death_clip` (имена от A06);
  - hit-клип играет только вне `TELEGRAPH/ATTACK/DEATH`;
  - death-клип играет в `DEAD`, attack disabled, collision off;
  - если клипа нет — текущий procedural flinch, явно помеченный fallback.
- **Acceptance:** 2–3 клипа; flinch не прерывает committed attack; death clip; fallback; E01/E02 visual.

#### A05-08a / A05-08b — HUD target switching

- **A05-08a:** добавить `combat_target_changed(target)` и `get_combat_target()`; цель — ближайший живой враг в `settings.combat_radius`; сигнал только при изменении; null при смерти/выходе из радиуса.
- **A05-08b (A08):** `CombatHud` подписывается; при смене — новый `HealthComponent`, сброс `enemy_label`, обновление бара; при смерти последнего/истечении `combat_grace` — скрыть `EnemyPanel`; старый `_find_nearest_enemy_health` остаётся только fallback для сцен без `CombatController`.
- **Acceptance:** цель меняется; имя/HP обновляются; панель скрывается; нет второго сканера; E02 visual.

#### A05-09 — Azure Blade (условно)

- **Цель:** не оставлять E02 на 24 ударах, если клинок уже получен, но не обещать armed-режим, которого нет в демо-модели.
- **Факт:** `sunny_waking_poc.tscn` содержит `start_unarmed=true`, `armed_attack = sunny_light_unarmed_p1.tres`, `unarmed_attack = sunny_light_unarmed_p1.tres`, оба клипа `HumanSpBoxing`. Вызов `set_unarmed(false)` переключит на тот же кулак, а не на 20 урона. `1H_Melee_Attack_Slice_Diagonal` в P1-ассетах не найден; `get_weapon_socket` у `sunny_real_v3` не найден.
- **Техническая сторона A05:** добавить узкий API `equip_armed(data: AttackData, clip: StringName)`, который назначает `armed_attack`, `armed_attack_clip` и вызывает `set_unarmed(false)`; опционально `is_armed()`. Это не второй боевой контроллер.
- **Интеграция:** A04/A06 вызывают `equip_armed(sunny_light_armed.tres, blade_clip)` после `azure_blade_picked`/получения Памяти; A06 подтверждает blade_clip и weapon socket/визуал. A05 не правит quest data.
- **Если клипа/сокета нет:** A05-09 не закрывается; E02 остаётся на 24 ударах P1, и это фиксируется в отчёте, а не маскируется.
- **Acceptance:** `equip_armed` даёт 20 dmg и валидный клип; E02 быстрее; квестовый флаг не дублируется; при отсутствии клипа — deferred, не PASS.

---

## 12. Ветка, порядок работ и правила изоляции

### 12.1. Preconditions

1. A00 подтвердил `MASTER_PLAN.md`, `FILE_OWNERSHIP.md`, `INTEGRATION_CONTRACTS.md`.
2. A00 создал `feat/a05-combat-ai` от frozen baseline.
3. A05 записал claims:
   - A03: one-line `carapace_wounded_e01` mapping;
   - A08: `combat_target_changed` consumption;
   - A10: test cases for A05-04/05/06/08.
4. A05 не меняет игровые файлы до этого шага.

### 12.2. Порядок

```text
A05-00
  → A05-01 (E01 baseline)
  → A05-04 (respawn)
  → A05-06 (tokens)
  → A05-02 (E02)
  → A05-03 (E03)
  → A05-05 (weak spot)
  → A05-07 (clips, если A06 готов)
  → A05-08a (API) → A05-08b (A08)
  → A05-09 (если TD разрешит)
```

### 12.3. Правила

- Один файл — один владелец. A05 не переписывает `scripts/locations/**`, `scripts/ui/**`, `scripts/player/**`, `assets/**`.
- Каждая задача заканчивается отчётом: файлы, тест, результат, **NOT TESTED**.
- A05 не коммитит и не пушит; TD мержит.
- Если A03/A08/A10 не дают зависимость — задача остаётся открытой, A05 не делает чужую работу.
- Не запускать полный GUT в шумном дереве и не объявлять 633/634 PASS.

---

## 13. Спорные моменты для Technical Director

| ID | Вопрос | Варианты | Рекомендация | Почему |
|---|---|---|---|---|
| **Q-A05-01** | Weak spot: P0 или P1? | (a) P0 в E01; (b) P1, как в `MASTER_PLAN` | **(b)** P1; в E01 P0 достаточно визуального сустава + `Inspectable` | `MASTER_PLAN` §7 прямо говорит: weak spot не блокирует M1; `AGENT_TASKS` A05-01 упоминает сустав, но A05-05 выделен отдельно |
| **Q-A05-02** | Как подключить `carapace_wounded_e01` к E01? | (a) A05 `spawn_profile` по `QuestKillCredit.enemy_tag`; (b) одна строка A03 `apply_data`; (c) оставить стандартный `0.85` | **(a)** — реализовано; (b) опционально | A05-адаптер уже работает в runtime и не требует правки A03; sandbox `carapace_wounded` 14 не меняется |
| **Q-A05-03** | Что значит «respawn врагов»? | (a) живые — полный HP на spawn, мёртвые остаются; (b) весь encounter сбрасывается, включая мёртвых; (c) только HP, без позиции | **(a)** | Не ломает `QuestKillCredit`/флаги и не даёт фарм; соответствует «нет полуживых» |
| **Q-A05-04** | Множитель weak spot | `1.5` или `2.0` | **1.5** для демо | 1.5 — нижняя граница дизайна: 18 за weak-удар, 4–6 ударов по E01; 2.0 даёт 24 и сокращает бой до 3–4 |
| **Q-A05-05** | Групповой токен | (a) локальный радиус 24 м; (b) явный `encounter_id`/группа (нужна правка A03) | **(a)** на демо | E02/E03 далеко друг от друга; радиус 24 покрывает обе группы; нет нового manager |
| **Q-A05-06** | HUD: кто делает A05-08? | (a) A05 API + A08 UI; (b) A05 получает shared-file claim на `combat_hud.gd` | **(a)** | Не нарушает `FILE_OWNERSHIP`; HUD остаётся у A08 |
| **Q-A05-07** | Тесты: кто пишет? | (a) A10; (b) A05 пишет боевые тесты | **(a)** | `tests/**` принадлежит A10; A05 даёт сценарии и test seams |
| **Q-A05-08** | Hit/death clips обязательны? | (a) да, tech demo; (b) fallback допустим | **(b)** для M1, **(a)** для tech demo, если A06 успевает | Не блокировать E01 отсутствием ассетов |
| **Q-A05-09** | Azure Blade | (a) A04/A06 вызывает `set_unarmed(false)`; (b) A05 добавляет `equip_armed(data, clip)`, A04/A06 вызывают; (c) оставить кулак | **(b)**; A05 даёт API, A06 даёт blade-клип и weapon socket, A04 делает хук | В демо-сцене `armed_attack` — тот же кулак; `1H_Melee_Attack_Slice_Diagonal` и `get_weapon_socket` не найдены; одного `set_unarmed(false)` недостаточно |
| **Q-A05-10** | Баланс и длительность E02/E03 | (a) дизайн: E02 45–75 с, E03 30–50 с, 95 HP / 18 dmg; (b) backlog: 3–5 мин; (c) снизить HP или дать Azure Blade | **(a) + (c)**; 3–5 мин считать общим временем с подходом, а не таймером боя | В `combat_encounters.md` — 45–75/30–50 с; в `BACKLOG` SS-116 — 3–5 мин. Нужно зафиксировать, что 3–5 мин включает маршрут, иначе цифры противоречат друг другу |
| **Q-A05-11** | E03 мост | (a) 6 м, трупы collision off; (b) расширить/добавить перила (A03) | **(a)**, если проход подтверждён; иначе A03 | A05 не меняет геометрию |
| **Q-A05-12** | Mountain King | (a) не трогать; (b) добавить respawn/weak spot | **(a)** | Не входит в M1/tech demo E01–E03; sandbox |
| **Q-A05-13** | Ветка/коммиты | (a) TD создаёт ветку и мержит; A05 не коммитит; (b) A05 делает локальные коммиты | **(a)** | Соответствует `FILE_OWNERSHIP`; если TD хочет атомарные коммиты — A05 stage + report |
| **Q-A05-14** | Канонический баланс | (a) обновить `docs/design/11_combat_system.md` под 95 HP/18 и dodge `0.8/0.3`; (b) вернуть код к 80 HP/10–16 и `0.42/0.22` | **(a)** | Текущее демо уже проверено на 95/18 и `0.8/0.3`; A05 не меняет формулы без TD |

---

## 14. Передача Technical Director

### 14.1. Что передаётся

1. Эта спецификация с 14 разделами, матрицей приёмки и оценками.
2. Task ID: `A05-00`, `A05-01`, `A05-01b`, `A05-02`…`A05-09`.
3. Точные файлы A05 и список shared-file зависимостей.
4. 14 вопросов §13, из которых 6 блокируют старт:
   - Q-A05-01 (weak spot P0/P1);
   - Q-A05-02 (E01 mapping);
   - Q-A05-03 (respawn semantics);
   - Q-A05-06 (HUD ownership);
   - Q-A05-07 (tests ownership);
   - Q-A05-13 (branch/commit).
5. Список **NOT TESTED**: полный GUT, ручной E02/E03, визуальный бой, 60 FPS, аудио/VFX.

### 14.2. Definition of Ready

- DP-1.0 утверждён; ветка создана; claims подтверждены.
- A03 подтвердил одну строку mapping и маркеры E01–E03.
- A08 подтвердил потребление `combat_target_changed`.
- A10 подтвердил тестовые сценарии.
- A06 подтвердил наличие/отсутствие клипов и стабильность animator.

### 14.3. Definition of Done

- A05-01 P0 закрыт: E01 играбелен, 65 HP/18, выходы свободны, кредит один раз.
- A05-04 P0 закрыт: нет полуживых врагов после смерти.
- A05-06/A05-02/A05-03 P1 закрыты для tech demo.
- A05-05/A05-07/A05-08 закрыты или явно отложены решением TD.
- A10: targeted GUT зелёный, ручной E01 (M1), ручной E02/E03 (tech demo), логи/скриншоты.
- Нет новых autoload, второго HUD, второго QuestSystem и изменений чужих зон.

### 14.4. Граница текущего шага

**В рамках Stage 2 игровые файлы не изменялись.** Создан только этот документ. Любая реализация начинается после подтверждения `MASTER_PLAN.md` и `FILE_OWNERSHIP.md` и создания отдельной ветки Technical Director.
