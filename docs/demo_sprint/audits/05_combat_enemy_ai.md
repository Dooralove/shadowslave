# Combat & Enemy AI — аудит

**Дата:** 2026-11-02  
**Автор:** Chat 05 — Lead Combat & Enemy AI Engineer  
**Ветка / HEAD:** `s3-park-art` / `0335a5c`  
**Статус:** аудит + точечная реализация в зоне `scripts/combat/**`, `resources/combat/**`, `tests/test_*combat*`, `tests/test_*enemy*`.  
**Связанные документы:** `docs/design/11_combat_system.md`, `docs/art/character_animation_pipeline_audit.md`, `docs/art/enemy_model_upgrade_followup_2026-11-02.md`, `docs/demo_sprint/design/00_DEMO_SCOPE_AND_CONTRACT.md`, `docs/demo_sprint/audits/03_world_level_design.md`.

---

## 0. Сводка

1. **Базовая боевая система работает:** `MeleeAttack` (WINDUP → ACTIVE → RECOVERY), `Hurtbox`, `HealthComponent`, `CombatController` (удар / уклонение с i-frames / блок), HUD и смерть проверены 111/111 целевыми тестами.
2. **Критический разрыв демо закрыт не нами, а уровнем:** в `labyrinth_first_fragment.gd` игрок включается через `enable_demo_gameplay`; в чистом runtime-прогоне `combat_enabled = true`, HUD показывает HP/выносливость, удар реально снимает 12 HP с раненого карапакса.
3. **Главный дефект синхронизации:** `CarapaceAnimator.attack_contact_time` был `0.34`, а фактический пик клешни `LeftPincer` — `0.40`. Исправлено; удар теперь попадает в середину окна `0.85–1.10`, а не на его край.
4. **Главный дефект Mountain King:** окно урона открывалось сразу после телеграфа (`0–0.30`), а видимый замах приходил на `0.433`. Добавлены `windup_time = 0.35` и `active_time = 0.20`; AI ждёт фактического закрытия окна `MeleeAttack`, а не своего таймера.
5. **P1-модель Санни** (используется в демо-Лабиринте) имеет клип `HumanSpBoxing`, а не `Punch_Jab`; контакт измерен по `LeftHand` — `0.33`. Создан отдельный `sunny_light_unarmed_p1.tres`; старый `sunny_light_unarmed.tres` с `0.18` оставлен для KayKit-арены.
6. **AI больше не переходит в RECOVERY по копии `active_time`:** `TestEnemy`, `CarapaceEnemy` и `MountainKing` ждут `MeleeAttack.Phase.RECOVERY/READY`. Это исключает рассинхрон при изменении `windup_time/active_time` в `.tres`.
7. **Добавлены:** post-hit i-frames (`0.25 с`), реакция на удар по блоку/пробой блока (через состояния `GUARD_HIT/GUARD_BREAK` Chat 06), процедурная реакция карапакса и личинки на урон, stuck/avoid поведение карапакса, `CombatEncounter` и песочница `combat_course`.
8. **Боевые встречи демо:** `LabyrinthQuestDirector` спавнит 1 раненого карапакса в Z03, 3 карапаксов в Z13 и 2 на костяном мосту Z14. Runtime-проверка раненого: 65 → 0 HP за 6 ударов, игрок 100 → 46 HP, смерть игрока возвращает на старт с 100 HP, труп не блокирует.
9. **Не проверено вручную:** полный проход 1.5 км, бой с тремя карапаксами Z13 и парой на Z14, визуальное соответствие каждого замаха в кадре, 60 FPS и субъективное ощущение. Это **NOT TESTED**.
10. **Полный GUT не запускался целиком:** целевые боевые 111/111, `test_labyrinth_first_fragment` 13/13 (332 assert), `test_labyrinth_quest_content` 4/4 (41 assert). Ручной проход E01–E03 и полный GUT — **NOT TESTED**.

---

## 1. Метод и границы

**Прочитано:**

- `docs/design/11_combat_system.md` — роли, тайминги, i-frames, блок, групповые правила.
- `docs/art/character_animation_pipeline_audit.md` — клипы, длины, проблема обрезки атаки, `Enemy Chop 0.717`.
- `docs/art/enemy_model_upgrade_followup_2026-11-02.md` — Carapace AI, 95 HP / 18 урона, 5 клипов.
- `docs/demo_sprint/**` — контракт M1, ownership, отчёты 03/04.
- `docs/design/level_brief_labyrinth_first_fragment.md` — Z03 первый бой, Z13 стая, Z14 два карапакса.
- Код: `scripts/combat/**`, `scripts/player/sunny_animator.gd`, `scripts/player/sunny_controller.gd`, `scripts/locations/forgotten_shore_labyrinth/labyrinth_quest_director.gd`, `scripts/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.gd`, сцены врагов/арен.

**Запущено:**

- `tools/audit/combat_timing_probe.gd` — покадровая выборка кости/клешни на 60 Гц.
- GUT: 14 боевых скриптов, 111 тестов, 496 assert — **111/111 passed**, exit 0.
- Godot MCP runtime: `labyrinth_first_fragment.tscn` — игрок, удар, урон, смерть врага, смерть игрока и возврат на чекпоинт.
- Визуальный кадр: `docs/demo_sprint/qa/combat_labyrinth_start.png`.

**Границы:**

- Полный GUT и полный ручной проход не выполнялись; в дереве параллельно меняются `QuestSystem`, `NightmareRunState`, `CampaignGuide`, `SunnyAnimator` и классы Лабиринта. Это вызывает периодические parse errors и устаревший `global_script_class_cache.cfg`.
- Боевые значения не переписывались вслепую: при расхождении документов с фактическим клипом приоритет у измеренного клипа и текущего решения демо-спринта.
- Мы не меняли геометрию, маршруты, спавны и квестовые ресурсы Лабиринта.

---

## 2. Фактическое состояние

### 2.1. Карта боевых файлов

| Элемент | Файл | Что реально есть |
|---|---|---|
| Фазы атаки | `scripts/combat/melee_attack.gd` | `READY → WINDUP → ACTIVE → RECOVERY`, один хит на цель за удар, фиксация направления |
| Данные атаки | `scripts/combat/attack_stats.gd`, `attack_data.gd` | damage, cooldown, windup, active, reach, radius, contact_time, stamina, guard, hitstop |
| Здоровье | `scripts/combat/health_component.gd` | max/current, `damaged`, `died`, `revive` |
| Хёртбокс | `scripts/combat/hurtbox.gd` | слой, `invulnerable`, `damage_scale`, звук/частицы попадания |
| Игрок | `scripts/combat/combat_controller.gd` | удар, уклонение с i-frames, блок, stamina, guard break, post-hit i-frames |
| Аниматор игрока | `scripts/player/sunny_animator.gd` | состояние, скорость клипа по contact_time, guard/hit/dodge/death, AnimationTree-путь |
| Тестовый враг | `scripts/combat/test_enemy.gd`, `enemy_animator.gd` | Idle → Chase → Telegraph → Attack → Recovery → Dead; Hit_A, Death_B |
| Карапакс | `scripts/combat/carapace_enemy.gd`, `carapace_animator.gd` | scuttle, lunge, claw, stuck/avoid, dormant, flinch, death |
| Личинка | `scripts/combat/test_enemy.gd`, `larva_animator.gd` | процедурный замах/выпад/смерть + реакция на урон |
| Горный Король | `scripts/combat/mountain_king.gd`, `mountain_king_config.gd` | Dormant/Chase/Telegraph/Attack/Recovery/Blocked/Retreat/Dead |
| HUD | `scripts/ui/combat_hud.gd` | HP/выносливость, первое появление, поиск ближайшего врага |
| Арены | `scenes/levels/combat_arena.tscn`, `larva_arena.tscn`, `combat_course.tscn` | одиночный карапакс, личинка, песочница 1+2+2 |
| Демо-встречи | `labyrinth_quest_director.gd` + маркеры | Wounded Z03, 3 Pack Z13, 2 Bridge Z14 |

### 2.2. Конвейер атаки

```
input → CombatController.try_light_attack()
      → MeleeAttack.try_attack()
      → SunyAnimator.play attack clip (speed = contact_time / contact_at)
      → ACTIVE window: get_overlapping_areas() → Hurtbox.receive_hit()
      → HealthComponent.take_damage() → HitFlash / HitSpark / hit_received
      → Hurtbox signal → CombatController (block stamina, i-frames)
```

Ключевое правило сохранено: **урон наносит только `MeleeAttack`**, анимация и звук — визуальный слой. `MeleeAttack.disable()` закрывает окно и сбрасывает направление при смерти/отключении.

### 2.3. Слои и зоны

| Слой | Значение | Использование |
|---:|---|---|
| 1 | world | пол, стены, рампы |
| 2 | player | капсула Санни |
| 4 | enemy | тело врага, не блокирует удар |
| 8 | player_hurtbox | хёртбокс игрока; маска атак врагов |
| 16 | enemy_hurtbox | хёртбокс врага; маска атаки игрока |
| 32 | boundary | невидимые границы |

Хёртбоксы: Санни — капсула `0.4 × 1.9`, враги — капсулы `0.5–1.25`; атаки — сферы. Слабая точка карапакса — `CSGSphere3D` + `Inspectable`, **не отдельный hurtbox и не множитель урона**.

### 2.4. Урон, блок, i-frames

| Механика | Реализация | Проверка |
|---|---|---|
| Лёгкий удар | 20 (KayKit armed, 10 stamina) / 12 (P1 unarmed, 6 stamina) | GUT + runtime |
| Блок | 30% урона, 32 guard damage у карапакса, полный блок-стан при нуле | `test_combat_controller` |
| Уклонение | 0.8 с, i-frames 0.30 с, 16 stamina | `test_combat_controller` |
| Post-hit i-frames | 0.25 с после фактического попадания | новый тест |
| Повторный урон | `_hit_this_swing` — одна цель один раз за удар | `test_melee_attack`, runtime |
| Смерть врага | `attack.disable()`, layer/mask = 0, клип Death, труп не блокирует | `test_*enemy`, runtime |

### 2.5. Противники

| Противник | HP | Урон | Замах | Окно | Recovery | Роль |
|---|---:|---:|---:|---:|---:|---|
| Раненый карапакс | 65 | 18 | 0.95 | 0.25 | 1.20 | учебный, Z03 |
| Карапакс-падальщик | 95 | 18 | 0.85 | 0.25 | 1.05 | pressure/flanker, Z13/Z14 |
| Личинка | 55 | 14 | 0.65 | 0.20 | 0.95 | быстрый скирмишер |
| Тестовый гуманоид | 60 | 15 | 0.60 | 0.20 | 1.00 | legacy/арена, не в демо |
| Горный Король | 600 (сцена) | 25 | 1.10 + 0.35 windup | 0.20 | 1.40 | босс/засада, cinematic |

`carapace_wounded.tres` (65 HP / 14 урона) используется только в песочнице `combat_course`; в демо-Лабиринте `LabyrinthQuestDirector` переопределяет только HP, поэтому E01 бьёт стандартной клешнёй на 18.

### 2.6. Встречи на карте

| ID | Зона | Маркер | Состав | Статус |
|---|---|---|---|---|
| E01 | Z03 Первая развилка | `Gameplay/Encounters/WoundedScavenger` | 1 раненый карапакс | runtime проверен |
| E02 | Z13 Охотничьи угодья | `Gameplay/Encounters/PacksZ13` | 3 карапакса | спавн есть, бой вручную NOT TESTED |
| E03 | Z14 Костяной мост | `Gameplay/Encounters/TwoCarapaces` | 2 карапакса | спавн есть, бой вручную NOT TESTED |
| — | Z02 Туша | статические placeholder-крабы | 3 декоративных | без AI |
| — | Z09/Z16 | — | врагов нет | только маркеры |

### 2.7. Измеренные контакты

Метод: `godot --headless --path . -s tools/audit/combat_timing_probe.gd -- --scene=... --clip=... --bone=...`; выборка 60 Гц, пик скорости кости.

| Атака | Клип | Клип, с | Контакт, с | Окно, с | Совпадение |
|---|---:|---:|---:|---:|---|
| Sunny armed | `1H_Melee_Attack_Slice_Diagonal` | 1.000 | 0.383–0.40 (`handslot.r`) | 0.30–0.50 | да |
| Sunny unarmed KayKit | `Punch_Jab` | 0.867 | 0.18 (`handslot.r`) | 0.14–0.26 | да |
| Sunny P1 | `HumanSpBoxing` | 1.708 | 0.33 (`LeftHand`) | 0.30–0.50 | да |
| TestEnemy chop | `2H_Melee_Attack_Chop` | 1.633 | 0.717 (`handslot.r`) | 0.60–0.80 | да |
| Carapace claw | `Attack` | 0.833 | 0.40 (`LeftPincer`) | 0.85–1.10 | да |
| Mountain King | `Attack` | 0.833 | 0.433 (`LongHandR`) | 0.35–0.55 | да |

---

## 3. Расхождения «документ ↔ реализация»

| Документ | Утверждение | Факт до правки | Риск / действие |
|---|---|---|---|
| `character_animation_pipeline_audit.md` | Sunny armed contact 0.25 (Slice_Horizontal) | Старый клип давал 0.25; новое решение — `Slice_Diagonal` с контактом 0.383–0.40 | **обновлено**: `CombatController.armed_attack_clip` → Diagonal, data 0.4; старые 0.25 не навязываются |
| `character_animation_pipeline_audit.md` / `DECISIONS.md` | Enemy Chop contact 0.717 | Подтверждено (правый `handslot.r` 0.700–0.717) | нет |
| `enemy_model_upgrade_followup_2026-11-02.md` | Carapace claw contact 0.34, 95 HP, 18 урона | Фактический пик `LeftPincer` — 0.40 | **исправлено** на 0.40; HP/урон оставлены как в актуальном follow-up |
| `docs/design/11_combat_system.md` | Уклонение: 0.42 с, i-frames 0.22 | `combat_settings.tres`: 0.8 с, i-frames 0.30 | Новое решение под `Roll`; документ устарел, TD обновить |
| `docs/design/11_combat_system.md` | Лёгкая атака: windup 0.17, active 0.10, total 0.50 | Фактические `sunny_light_armed.tres`: 0.30 / 0.20 / 0.95 | Новое решение ради целостности клипа `Slice_Diagonal`; документ нужно обновить TD; P1 |
| `docs/design/11_combat_system.md` | Карапакс 80 HP, 10–16 урона | 95 HP, 18 урона | расхождение документов; не меняли без решения TD, отмечено в P1 |
| `docs/design/11_combat_system.md` | Слабая точка — множитель 1.5–2.0 | Слабая точка только Inspectable | P2: нет множителя/зоны |
| `docs/design/11_combat_system.md` | Poise/stagger/knockdown | Нет poise; только Hit/GuardBreak | P2 |
| `docs/design/11_combat_system.md` | Unblockable/grab | `AttackData.kind` есть, но боевой проверки нет | P2 |
| `docs/design/11_combat_system.md` | 1–2 атакующих одновременно | Нет групповых токенов; 3 карапакса атакуют независимо | P1 для Z13 |
| `docs/design/11_combat_system.md` | Полный клип атаки не обрезать | KayKit armed `Slice_Diagonal` играет ~95% (cooldown 0.95, speed 1.0); P1 boxing ~43% | осознанный компромисс; P2 |
| `docs/art/character_animation_pipeline_audit.md` | Пер-attack contact time | Реализовано в `AttackStats.contact_time` | нет |

---

## 4. Готовность к демо

| Область | Готовность | Что нужно для P0 |
|---|---:|---|
| Санни: удар/блок/уклонение | 90% | ручной бой в Лабиринте, читаемость замаха |
| i-frames и повторный урон | 95% | — |
| Карапакс: AI/анимация/смерть | 85% | визуальная проверка замаха и клешни в кадре |
| Личинка | 80% | визуальная проверка процедурного выпада |
| Горный Король | 75% | ручной прогон засады; тайминг замаха |
| Встречи Z03/Z13/Z14 | 60% | бой с 3 и 2 карапаксами, групповой pressure |
| HUD/фидбек | 85% | проверить читаемость полос и первого появления |
| Звук/VFX | 60% | проверить cue `combat_swing_*`, `combat_hit_*`, `creature_carapace_*` |
| Тесты | 90% | полный GUT после стабилизации class cache |

---

## 5. P0 / P1 / P2

### P0 — без этого демо не проходится

- [x] Удар игрока реально наносит урон в демо-Лабиринте (runtime: 12 HP за удар).
- [x] Один удар не наносит урон дважды.
- [x] Смерть врага закрывает окно атаки, отключает коллизию и не блокирует маршрут.
- [x] Смерть игрока возвращает на чекпоинт с полным HP и рабочим ударом.
- [x] Окно урона карапакса и Mountain King совпадает с видимым замахом (по измерению).
- [x] **P0 внешний:** в чистом прогоне после `rescan_filesystem` и остановки лишних Godot-процессов class cache стабилен; `test_labyrinth_first_fragment` 13/13, `test_labyrinth_quest_content` 4/4. Перед релизом нужен freeze и один `--import`.
- [ ] **P0 проверка:** ручной бой с E02/E03, а не только E01.

### P1 — заметно улучшает демо

- Групповой токен атак для 3 карапаксов Z13 (1–2 атакующих, остальные давят/обходят).
- Баланс E02/E03: 95 HP × 3 при 12 уроне — 24 удара; проверить или дать Azure Blade реальный боевой режим.
- Реальный weak spot карапакса: отдельный hurtbox/множитель, а не только Inspectable.
- Ограничить/сгладить обрезку клипа атаки (follow-through tail или отдельный recovery-клип).
- Уклонение: тело двигается 0.8 с, клип `HumanRoll`/`Roll` длиннее; визуальный хвост и root motion не выверены (06).
- Проверить HUD: полоса врага, смена цели, скрытие после боя.
- Проверить звуковые cue и VFX попадания/смерти в живом кадре.
- Респавн живых врагов после смерти игрока: сейчас они сохраняют полученный урон (документ `11_combat_system` §9.6 говорит о полном HP `PRELIM`); нужно решение 03/04.

### P2 — после демо

- Poise, stagger, knockdown, directional hit reactions.
- Hitstop (`AttackData.hitstop` хранится, но не применяется) и камера-импульс.
- Unblockable/grab и честный красный телеграф.
- Центурион, центурипеда, ranged-угроза, controller-роль.
- Групповая мораль/бегство карапаксов.
- Lock-on и камера боя.

---

## 6. Владение файлами

**Наши файлы (05):**

- `scripts/combat/attack_stats.gd`, `attack_data.gd`, `combat_settings.gd`, `combat_controller.gd`, `carapace_enemy.gd`, `carapace_animator.gd`, `enemy_animator.gd`, `test_enemy.gd`, `mountain_king.gd`, `larva_animator.gd`, `combat_encounter.gd`, `combat_course.gd`.
- `resources/combat/attacks/sunny_light_unarmed_p1.tres`, `carapace_wounded_claw.tres`; `resources/combat/enemies/carapace_wounded.tres`.
- `scenes/enemies/carapace_enemy.tscn`, `larva_enemy.tscn` (model/health wiring для flinch).
- `tests/test_combat_timing.gd`, `test_combat_course.gd`; правки `test_combat_controller.gd`, `test_combat_hud.gd`, `test_carapace_enemy.gd`, `test_mountain_king.gd`, `test_sunny_animation.gd`.
- `scenes/levels/combat_course.tscn` (новая песочница).
- `tools/audit/combat_timing_probe.gd`, `tools/audit/combat_labyrinth_probe.gd` (read-only probes).

**Кросс-владельческие правки, требуют ревью TD:**

- `scripts/player/sunny_animator.gd` (06) — защита `has_animation` в `_prepare_loop_modes` и null-guard в `attack_clip_speed`. Без этого P1-модель писала ошибки `Animation not found: Hit_Head`.
- `assets/characters/sunny_realistic_poc/sunny_waking_poc.tscn` (06) — P1 unarmed data `sunny_light_unarmed_p1.tres` и существующие guard-клипы `HumanSpHeadHit`. Без этого контакт P1-удара не совпадает с клипом.
- `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn` (03/04/07) — **не меняли**: combat включается `enable_demo_gameplay` в `labyrinth_first_fragment.gd`.

**Чужие зоны, которые мы не трогали:** `LabyrinthQuestDirector`, `QuestSystem`, `NightmareRunState`, `CampaignGuide`, геометрия и арт Лабиринта.

---

## 7. Риски интеграции

1. **Класс-кеш и параллельные чаты.** В одном дереве одновременно меняются `QuestSystem`, `SunnyAnimator`, `LabyrinthAtmosphere`, материалы. Headless-прогоны периодически получают `Could not find type` / `Could not find script for class`. Перед релизным прогоном нужен freeze и один `--import`.
2. **P1-модель — общая.** Наш `sunny_light_unarmed_p1.tres` привязан к клипу `HumanSpBoxing`; если Chat 06 заменит клип/модель, contact 0.33 нужно перемерить.
3. **Групповой бой.** Три карапакса Z13 не имеют токенов; возможен нечестный «конг» из трёх атак. Это следующий P1.
4. **Azure Blade.** Предмет и квест есть, но он не переключает `CombatController` в armed-режим; награда пока не влияет на бой.
5. **HUD.** Первое появление HUD (4 с) — решение 08; боевые тесты обновлены под него, но визуальная читаемость не проверена.
6. **Runtime MCP.** В шумном дереве несколько Godot-процессов одновременно подключаются к `MCPRuntime`; запросы могут попасть в чужой тестовый процесс. Чистый runtime-прогон выполнен после остановки лишних процессов; это нужно повторять.
7. **Параллельная правка атаки.** `sunny_light_armed.tres` был изменён другим чатом на `windup 0.3 / active 0.2 / cooldown 0.95 / contact 0.4`. Мы не откатывали это решение, а перевели `armed_attack_clip` на `1H_Melee_Attack_Slice_Diagonal` (фактический контакт 0.383). Если клип снова заменят, contact нужно перемерить.

---

## 8. Проверки

### 8.1. GUT

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd `
  -gtest=res://tests/test_melee_attack.gd,res://tests/test_sunny_combat.gd,res://tests/test_combat_controller.gd,res://tests/test_test_enemy.gd,res://tests/test_enemy_animation.gd,res://tests/test_larva_enemy.gd,res://tests/test_carapace_enemy.gd,res://tests/test_combat_arena.gd,res://tests/test_combat_hud.gd,res://tests/test_sunny_animation.gd,res://tests/test_fall_recovery.gd,res://tests/test_mountain_king.gd,res://tests/test_combat_timing.gd,res://tests/test_combat_course.gd -gexit
```

**Фактический результат:** 14 scripts, **111/111 passed**, 496 asserts, exit 0.  
До правок тот же боевой набор: 12 scripts, 95/95, 430 asserts.

### 8.2. Headless-проба Лабиринта

```powershell
godot --headless --path . -s tools/audit/combat_labyrinth_probe.gd
```

Фактический вывод:

```text
PLAYER combat_enabled=true controls=true pos=(38.0, 6.000941, 0.0) attack_damage=12.0
ENEMIES count=6
  WoundedScavenger hp=65.0
  PackCarapace1..3 hp=95.0
  BridgeCarapace1..2 hp=95.0
```

Это доказывает, что `enable_demo_gameplay` включает бой без правки сцены, а `LabyrinthQuestDirector` действительно спавнит 1+3+2 противников.

### 8.3. Runtime

Сцена `res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`:

- `Player.combat_enabled = true`;
- `WoundedScavenger` 65 HP: 65 → 53 → 41 → 29 → 17 → 5 → 0 за 6 ударов по 12;
- игрок 100 → 46 HP за бой (три удара карапакса по 18);
- смерть игрока: возврат на `CP-SHORE-START`, 100 HP, `attack.enabled = true`;
- труп: `collision_layer = 0`, `collision_mask = 0`, state = DEAD;
- HUD-кадр: `docs/demo_sprint/qa/combat_labyrinth_start.png`.

### 8.4. Структурные тесты Лабиринта

Чистый прогон после стабилизации class cache:

- `test_labyrinth_first_fragment` — **13/13 passed, 332 asserts**.
- `test_labyrinth_quest_content` — **4/4 passed, 41 assert** (включая `first_blood` → появление Azure Blade).

Ранее в шумном дереве эти же тесты падали на transient engine errors (`Could not find script for class "LabyrinthAtmosphere"`, `QuestDefinition` lookup), не на боевых assert'ах. После пересканирования и остановки лишних Godot-процессов — зелёные.

### 8.5. NOT TESTED

- Полный ручной проход 1.5 км и все 18 зон.
- Бой с E02 (3 карапакса) и E03 (2 карапакса) вручную.
- Визуальное совпадение замаха/клешни/меча в живом кадре (только числовые измерения).
- Mountain King ambush вручную после изменения windup.
- Звук и VFX на слух/в кадре.
- 1080p / 60 FPS.
- Полный GUT без внешних parse errors.

---

## 9. Ссылки

- `scripts/combat/melee_attack.gd`, `combat_controller.gd`, `carapace_enemy.gd`, `carapace_animator.gd`, `mountain_king.gd`
- `resources/combat/attacks/*.tres`, `resources/combat/enemies/*.tres`
- `tools/audit/combat_timing_probe.gd`
- `docs/design/11_combat_system.md`
- `docs/art/character_animation_pipeline_audit.md`
- `docs/art/enemy_model_upgrade_followup_2026-11-02.md`
- `docs/demo_sprint/design/00_DEMO_SCOPE_AND_CONTRACT.md`
- `docs/demo_sprint/audits/03_world_level_design.md`

---

## 10. Stage 3 — реализация A05 (2026-11-03)

**Ветка:** `demo/combat-ai`, база `ee97325`, worktree `shadowslave-demo-05`.
**Границы:** изменены только `scripts/combat/**`, `scenes/enemies/carapace_enemy.tscn`, `resources/combat/enemies/carapace_wounded_e01.tres`, `docs/demo_sprint/design/combat_encounters.md` и этот отчёт. Чужие сцены, HUD, квестовые и player-файлы не менялись.

### 10.1. Что реализовано

- **A05-04, respawn:** `CarapaceEnemy` запоминает spawn deferred-снимком (спавнер ставит позицию после `add_child`), слушает `HealthComponent.died` и `FallRecovery.recovered` игрока и сбрасывает только живого врага: полный HP, spawn, IDLE, attack enabled, cooldown/stuck сброшены. Мёртвые остаются DEAD, kill-credit не дублируется.
- **A05-05, weak spot:** в `Hurtbox` добавлены `damage_multiplier` и `hit_cue_override`; `MeleeAttack.select_hit_targets()` оставляет один hurtbox на `HealthComponent` и предпочитает weak spot; в `carapace_enemy.tscn` добавлен `WeakSpotHurtbox` (radius `0.18`, multiplier `1.5`, cue `combat_hit_carapace`). `Inspectable` не участвует в уроне.
- **A05-06, group token:** `CarapaceEnemy` считает соседей в `TELEGRAPH/ATTACK` в радиусе `24 м`; `max_simultaneous_attackers = 2`; ожидающий враг делает pressure-страйф, а не стоит столбом. Локально, без autoload/manager.
- **A05-08a, HUD API:** `CombatController` получил `combat_target_changed(target)` и `get_combat_target()`; цель — ближайший живой враг в `combat_radius`, null после смерти/выхода.
- **A05-07, hit clips:** `CarapaceAnimator` поддерживает `hit_clip` (`Hit`) с fallback на процедурный flinch; authored-клипов в ассетах пока нет.
- **A05-09, armed API:** `CombatController.equip_armed(data, clip)` проверяет наличие клипа у модели и переключает armed-профиль; квестовый хук Azure Blade остаётся A04/A06.
- **A05-01b, data:** создан `carapace_wounded_e01.tres` (65 HP, 18 dmg, `0.95` telegraph, `1.6` speed). Подключён A05-адаптером: `CarapaceEnemy.spawn_profile` + `spawn_profile_tag = "wounded_scavenger"` читают существующий `QuestKillCredit.enemy_tag`; A03-файл не менялся. Runtime подтверждает `WoundedScavenger` с `carapace_wounded_e01`, E02/E03 остаются на `carapace_scavenger`.

### 10.2. Проверки

- Полный GUT: **82 скрипта, 646/646 passed, 7374 asserts, exit 0** (`-ghide_orphans`; orphan cleanup не является падением тестов).
- Целевой боевой GUT: **111/111 passed, 496 asserts**.
- `test_combat_ai_integration`: **10/10 passed, 41 assert**.
- `test_labyrinth_first_fragment` + `test_labyrinth_quest_content`: **17/17 passed, 373 asserts**.
- `combat_labyrinth_probe`: 6 врагов, Wounded 65, Pack 3×95, Bridge 2×95.
- Локальный integration probe: смерть игрока в реальном Лабиринте → WoundedScavenger 65 HP, IDLE, на spawn; игрок 100 HP. Отдельный вызов `FallRecovery.recover()` также сбрасывает живого врага — закрыт путь «упал с моста, вернулся, враг остался раненым».
- Локальный E02 probe: максимум **1** атакующий в `TELEGRAPH/ATTACK` при лимите 2 и групповом интервале `1.0 с`; три одновременные атаки невозможны.
- Локальный HUD probe: цель переключается с первого врага на второго, после смерти обоих панель скрыта.
- Weak spot probe: body `10`, weak `15`, двойного удара по одному `HealthComponent` нет; фланговый удар P1-кулаком снимает `18` вместо `12`.
- E01 front-hit probe: P1-кулак, 65 HP → 0 за **6** ударов; weak spot вынесен на боковой сустав, чтобы фронтальный удар не давал бонус. В реальном спавне профиль применяется A05 `spawn_profile` по `QuestKillCredit.enemy_tag`; A03 mapping не требуется.
- E03 probe: оба `BridgeCarapace` на высоте моста, труп после смерти имеет `collision_layer/mask = 0`; ручной проход по мосту — **NOT TESTED**.

### 10.3. NOT TESTED

- Ручной E01/E02/E03 в живом кадре.
- Проход по мосту Z14 и отсутствие сталкивания в пропасть.
- Визуальное совпадение замаха/клешни/меча, звук и VFX на слух/в кадре.
- Authored hit/death клипы A06 (в ассетах отсутствуют; используется fallback).
- Azure Blade в живом прохождении: у P1-модели не найден blade-клип/`get_weapon_socket`.
- Ручной проход E01–E03, 1080p / 60 FPS, экспортная сборка.
- Визуальный кадр weak spot и живые transitions.

### 10.4. Блокеры

1. **A03 (опционально):** E01-профиль уже работает через A05-адаптер `spawn_profile`/`spawn_profile_tag` + существующий `QuestKillCredit.enemy_tag`; A03-файл не менялся. Если A03 хочет владеть mapping явно, можно продублировать одной строкой в `LabyrinthQuestDirector._spawn_enemy`; двойное применение идемпотентно, но не обязательно.
2. **A06:** hit/death клипы карапакса и blade-клип/сокет для Azure Blade. `CarapaceAnimator.hit_clip` уже читает клип `Hit`, fallback — процедурный flinch; для клинка нужен клип, который принимает `CombatController.equip_armed()`, и `get_weapon_socket()` у P1-модели.
3. **A08:** при желании использовать `combat_target_changed`/`get_combat_target()` вместо второго сканера (`player.get_node("CombatController")`); текущий `CombatHud` уже переключает цель и скрывает панель, но API пока не потребляет.
4. **A10:** перенести локальные probes в `tests/**` и провести ручной проход.
5. **P2 не начат:** poise/stagger/knockdown/hitstop, ranged/controller-враги, execute, lock-on не входят в A05-01…A05-08 и не должны расширять scope до M1.

---

## 11. Stage 4 — дополнительный аудит A05

### 11.1. Полностью закрыто в рамках A05

- **A05-04:** смерть и падение игрока сбрасывают только живых карапаксов; мёртвые не воскрешаются; проверено на реальном Лабиринте и через `FallRecovery.recover()`.
- **A05-05:** weak spot имеет отдельный hurtbox, множитель `1.5`, cue `combat_hit_carapace`; двойной удар body+weak исключён; фланговый удар проверен.
- **A05-06:** групповой лимит `2` атакующих, gap `1.0 с`, pressure-страйф; E02 headless-прогон дал максимум `1` при лимите 2.
- **A05-08a/b:** `CombatController.combat_target_changed` + `get_combat_target()`; цель очищается после смерти. `CombatHud` уже переключает полосу на следующего врага и скрывает панель после боя; headless HUD probe прошёл. API пока не потребляется HUD — это опциональная интеграция A08.
- **A05-07 (код):** `CarapaceAnimator` готов принять authored `Hit`; без клипа работает procedural fallback.
- **A05-09 (код):** `CombatController.equip_armed(data, clip)` проверяет наличие клипа; проверено на существующем клипе.
- **A05-01b:** E01 использует `carapace_wounded_e01` (65 HP, 18 урона, `0.95` замах, `1.6` скорость) через A05 `spawn_profile`; E02/E03 остаются стандартными.
- **A05-01 (P0 baseline):** E01 65 HP, 18 урона, 6 фронтальных ударов P1, труп не блокирует; проверено.

### 11.2. Частично закрыто

- **A05-07:** authored-клипов нет; A06 должен дать `Hit`/`Death`; fallback уже работает.
- **A05-09:** API готов, но blade-клип, weapon socket и квестовый хук отсутствуют (A06/A04).
- **A05-02/E02:** спавн, токен и 3 кредита проверены headless; ручной бой — **NOT TESTED**.
- **A05-03/E03:** спавн, высота, 2 кредита и collision-off трупа проверены headless; проход по мосту — **NOT TESTED**.

### 11.3. Новые проблемы, найденные аудитом

- Смерть от падения не вызывает `HealthComponent.died`; без `FallRecovery.recovered` живые враги оставались бы ранеными. **Исправлено:** подключён `recovered`.
- Weak spot в исходной точке `(0, 1.05, 1.2)` попадал под фронтальный удар, и E01 умирал за 4 удара. **Исправлено:** сустав вынесен на бок; фронт снова 6 ударов.
- `carapace_wounded.tres` (14 урона) используется sandbox `combat_course`; менять его под E01 нельзя. **Исправлено:** отдельный `carapace_wounded_e01.tres`.
- `sunny_waking_poc.tscn` имеет `armed_attack = unarmed_attack = P1-кулак`; `set_unarmed(false)` сам по себе не даёт 20 урона. **Задокументировано:** нужен `equip_armed`, blade-клип и сокет.
- В `BACKLOG` SS-116 указано 3–5 мин, в `combat_encounters.md` — 45–75/30–50 с. **Не решено:** TD должен зафиксировать, что 3–5 мин включает подход/обход.

### 11.4. Оставшаяся работа

1. A03: mapping `carapace_wounded_e01` больше не блокирует E01 — A05-адаптер использует существующий `QuestKillCredit.enemy_tag`; явный A03 mapping опционален.
2. A06: `Hit`/`Death` клипы и blade-клип + `get_weapon_socket`.
3. A04/A06: вызвать `equip_armed` после `azure_blade_picked`.
4. A08: опционально потреблять `combat_target_changed` и показывать имя цели; текущий HUD уже выполняет acceptance A05-08, но label «Противник» выглядит обезличенно. Предложение: при смене цели вызывать `target.get_display_name()` и сбрасывать подпись при `null`.
5. A10: принять/ревьюнуть `tests/test_combat_ai_integration.gd`; ручной E01/E02/E03, мост Z14, 60 FPS; полный GUT уже 646/646.
6. P2: не начинать до M1/tech demo; задачи не назначены.

---

## 12. Stage 6 — глубокий аудит и финальная полировка

### 12.1. Найдено и исправлено

- **E01-профиль реально применён в игре.** A05-адаптер `spawn_profile` читает `QuestKillCredit.enemy_tag`; `WoundedScavenger` в реальном Лабиринте имеет `carapace_wounded_e01`, `0.95` замах, `1.6` скорость, 65 HP. E02/E03 остаются на `carapace_scavenger`.
- **Групповой интервал.** Добавлен `group_attack_gap = 1.0 с`: после начала атаки сосед ждёт, а не входит в `TELEGRAPH` одновременно. E02 headless показывает максимум **1** атакующего при лимите 2; три одновременные атаки невозможны.
- **Смерть от падения.** `FallRecovery.recovered` подключён к сбросу живых врагов; проверено прямым `recover()`.
- **Weak spot.** Вынесен на бок, фронтальный удар снова даёт 6 ударов по E01, фланговый — 18 вместо 12. Визуал уменьшен и утоплен в сустав, добавлен слабый красный glow; VFX слабой точки опущен к суставу через `impact_offset`; после смерти weak spot скрывается, чтобы труп не светился.
- **Telegraph ring.** Плоский красный диск заменён на `TorusMesh` с emissive-материалом и сохранением плоского масштаба при пульсации. В живом кадре кольцо читается как кольцо, а не как залитая красная площадка.
- **HUD API.** `get_combat_target()` не отдаёт мёртвую цель; `CombatController` не выбирает dormant-врагов. Сигнал проверен на приобретение и очистку цели.
- **Spawn adapter.** Ожидание `QuestKillCredit` ограничено 3 кадрами, чтобы сцены без credit не сканировали дерево каждый физический кадр.

### 12.2. Осталось

- **A05-07:** authored `Hit`/`Death` клипы отсутствуют; A06. Fallback работает.
- **A05-09:** `equip_armed` готов, но нет blade-клипа, `get_weapon_socket` и хукa A04.
- **A05-02/E02:** ручной бой не проведён; headless token/3 кредита.
- **A05-03/E03:** ручной проход по мосту не проведён; headless spawn/collision.
- **A05-08:** текущий `CombatHud` проходит поведение; API не потребляется, это опционально A08. Видимый остаток: подпись цели остаётся «Противник», а не `get_display_name()`; A08 может подключить `combat_target_changed` и сбросить label — это заметно игроку.
- **A10:** `tests/test_combat_ai_integration.gd` добавлен, нужен review/принятие; полный GUT проходит.
- **P2:** poise/stagger/hitstop/ranged/execute/lock-on не начаты.

### 12.3. Финальные проверки

- Полный GUT: **82 скрипта, 646/646 passed, 7374 asserts, exit 0**.
- `test_combat_ai_integration`: **10/10 passed, 41 assert**.
- `combat_e01_labyrinth` probe: реальный WoundedScavenger — **6 ударов**, 0 HP, `wounded_scavenger_slain = true`.
- E02 token probe: максимум **1** атакующий, лимит 2.
- E03 probe: оба врага на мосту, труп collision-off.
- Respawn probe: смерть + падение, игрок 100 HP, враг 65 HP на spawn.
- HUD probe: смена цели и скрытие панели.
- `godot --headless --path . --import`: exit 0.
- Визуальный capture E01: weak spot читается как боковой сустав, telegraph — красное кольцо; труп не светится.
- NOT TESTED: ручной E01–E03 в живом кадре, мост Z14 вручную, 60 FPS, экспортная сборка.

---

## 13. Stage 7 — финальная визуальная проверка

Проверено реальным capture из `labyrinth_first_fragment` (камера у E01):
- **Telegraph:** плоский красный диск выглядел как залитая площадка; заменён на `TorusMesh` с emissive-материалом. В кадре читается именно кольцо, пульсация сохраняет плоский масштаб.
- **Weak spot:** красный шар `radius 0.12` висел на краю панциря. Уменьшен до `0.07`, утоплен в боковой сустав, получил слабый `OmniLight3D`; после смерти weak spot скрывается, труп не светится.
- **Weak spot VFX:** `impact_offset` опускает частицы к суставу, а не на 0.9 м выше.
- **HUD:** полоса и переключение цели работают, но подпись остаётся «Противник». Это видимый остаток A08: нужно использовать `get_combat_target().get_display_name()`.
- **Кольцо/weak spot** проверены в трёх ракурсах; скриншоты локальные, в репозиторий не добавлены.

Финальные проверки после визуальных правок:
- Полный GUT: **646/646, 7374 asserts, exit 0**.
- `--import`: exit 0.
- E01 actual: 6 ударов, флаг `wounded_scavenger_slain`.
- E02: max 1 атакующий; E03: spawn/collision; respawn: death+fall; HUD: switch/hide.
- NOT TESTED: ручной E01–E03 в живом кадре, мост Z14 вручную, 60 FPS, экспортная сборка.
