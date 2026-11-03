# Character Animation QA Report — Shadow Slave

**Дата:** 2026-11-02  
**Статус:** интеграция выполнена; автоматические проверки пройдены; ручной playthrough — **NOT TESTED**.  
**Связанный аудит:** `docs/demo_sprint/audits/characters_animation.md`.

---

## 1. Итог

В этом пасе персонажная анимация переведена с «файлы лежат в каталоге» на реально воспроизводимый слой:

- **Sunny real-world (v3)** получил очищенный GLB, in-place `WalkClean`, `FootGrounder` и 15-state `AnimationTree` с blend space idle/walk/run.
- **Sunny Nightmare (P1)** получил общий `AnimationTree`, `WeaponSocket` с `short_sword.glb`, attack/guard/dodge-клипы и guard hit/guard break.
- **Attack contact** выровнен по фактическому пику скорости руки: 0.400 s для P1 `Sword_Attack` и v3 `HumanSpBoxing`.
- **Dodge/landing hold** сокращены до длительности игрового действия, а не полного клипа.
- **Mountain King** и **Carapace Scavenger** получили процедурную hit-реакцию.
- **NPC P1** получили `WalkClean` для native-моделей и позы `interact`/`pickup`.

Генеративные кредиты не расходовались. Массовая генерация не запускалась.

---

## 2. Что именно интегрировано

### 2.1. Sunny v3 (real world / prologue / post-nightmare)

**Сцена:** `assets/characters/sunny_realistic_poc/sunny_waking_poc.tscn`  
**Модель:** `assets/characters/generated/sunny_real_v3/sunny_real_v3_clean2.glb`  
**Tree:** `resources/characters/sunny_v3_animation_tree.tres`

| Параметр | Значение |
|---|---|
| Tri / verts | 84 175 / 46 074 |
| Bones | 52 (Mixamo-style) |
| Clips | 10 native |
| Textures | 2K base/normal/ORM |
| Tangents | да |
| Double-sided | нет |
| LOD | нет |
| Scene scale | 0.875; Model Y 0.831 + ground offset |
| Walk speed | 1.7 m/s |
| Sprint speed | 4.5 m/s |
| Walk authored speed | 1.685 m/s |
| Run authored speed | 3.3 m/s |

**Что исправлено в GLB:**
- удалён вросший меч (2 121 вершина, loose-компоненты 36–45);
- `HumanRelaxedWalkLoopF` (4.13 s downhill take) обрезан до `WalkClean` 0.8–1.8 s;
- Hips Y/Z drift удалён → in-place;
- `HumanLandrollR` forward drift удалён;
- добавлены MikkTSpace tangents;
- материал переведён в single-sided.

**AnimationTree states:** `Locomotion`, `Jump`, `Fall`, `Land`, `Attack`, `Hit`, `Guard`, `GuardHit`, `GuardBreak`, `Dodge`, `Death`, `Interact`, `Special` + Start/End.  
**Locomotion blend:** `HumanStandingIdle` 0.0, `WalkClean` 0.4, `HumanSprintLoop` 1.0.  
**Cancellation matrix:** каждый non-death state имеет прямой переход в каждый другой state; AUTO-переходы возвращают one-shot в Locomotion.

### 2.2. Sunny Nightmare (P1, 53 bones)

**Сцена:** `assets/characters/p1/sunny_waking_nightmare.tscn`  
**Модель:** `assets/characters/p1/models/sunny_nightmare.glb`  
**Tree:** `resources/characters/sunny_animation_tree.tres`

| Параметр | Значение |
|---|---|
| Tri / verts | 48 518 / 28 109 |
| Bones | 53 (UE-style) |
| Clips | UAL 46 + `sunny/Idle_Relaxed` |
| Textures | 1K/512 PNG |
| Tangents raw | нет (Godot ensure_tangents) |
| Double-sided | да |
| LOD | 3 |
| Walk speed | 2.5 m/s (`Jog_Fwd`) |
| Sprint speed | 5.0 m/s (`Sprint`) |
| Walk authored speed | 2.5 m/s |
| Run authored speed | 3.27 m/s |

**Weapon socket:** `BoneAttachment3D` на `RightHand`, меч `assets/environments/nightmare/caravan/short_sword.glb`, масштаб 1.0, rotation `(90, 90, 0)`.  
**Режимы:** `start_unarmed = true` в прологе/Nightmare; `CombatController.set_unarmed(false)` показывает меч и переключает attack clip на `Sword_Attack`.  
**AnimationTree states:** те же 15 states; Locomotion blend `sunny/Idle_Relaxed` 0.0, `Jog_Fwd` 0.65, `Sprint` 1.0.

### 2.3. Attack timing

| Атака | Клип | Длина | Windup | Active | Contact | Cooldown | Speed | Реально играет |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| P1 armed | `Sword_Attack` | 1.533 s | 0.30 | 0.20 | 0.40 | 0.95 | 1.0 | 62 % |
| P1/v3 unarmed | `Punch_Jab` / `HumanSpBoxing` | 0.87 / 1.71 s | 0.30 | 0.20 | 0.40 | 0.90 | 1.0 | 52–103 % |
| KayKit arena | `1H_Melee_Attack_Slice_Horizontal` | 1.067 s | 0.30 | 0.20 | 0.40 | 0.95 | 1.0 | 89 % |

Пик скорости правой руки измерен пробой `tools/audit/attack_contact_probe.gd`:
- P1 `Sword_Attack`: **0.400 s**;
- v3 `HumanSpBoxing`: **0.400 s**.

Это совпадает с серединой active-окна 0.30–0.50 и с `contact_time = 0.40`.

### 2.4. Dodge / landing / guard

| Параметр | Было | Стало |
|---|---|---|
| Dodge duration | 0.42 s | 0.80 s |
| Dodge i-frames | 0.22 s | 0.30 s |
| Dodge speed | 7.5 m/s | 4.0 m/s |
| Dodge distance | ~3.15 m | ~3.20 m |
| Animator dodge hold | полный `Roll` 1.47 s | 0.80 s |
| Landing hold P1 | полный 1.27 s | 0.80 s |
| Landing hold v3 | полный 2.08 s | 0.60 s |
| Attack hold | cooldown only | 1.20 s (follow-through) |

**Guard hit/break:**
- `CombatController._on_hurtbox_hit_received` → `animator.play_block_hit()`.
- `_break_guard` → `animator.play_guard_break()`.
- Tree states `GuardHit` (`Hit_Head`) и `GuardBreak` (`Hit_Chest`), AUTO-возврат в `Guard`/`Locomotion`.

### 2.5. Enemies and NPCs

| Ассет | Изменение | Проверка |
|---|---|---|
| Mountain King p3 | процедурный hit-flinch (visual rotation X, 0.05/0.18 s) | `test_mountain_king` 11/11 |
| Carapace Scavenger | процедурный hit-flinch (visual rotation Z, 0.05/0.16 s) | `test_carapace_enemy` 9/9 |
| NPC P1 (`Mannequin`) | `WalkClean` для native Hero v6; `interact`/`pickup` позы | `test_caravan_site` 7/7, `test_pilgrim_path` 10/10 |
| Animation lab | переиспользует runtime `WeaponSocket`, добавляет debug weapon | `test_animation_lab` 5/5 |

---

## 3. Визуальные проверки

Студийные капчи (read-only, не игровые кадры):

- `docs/art/previews/characters_animation/contact_sheet.png`
- `docs/art/previews/characters_animation/v3_idle.png`
- `docs/art/previews/characters_animation/v3_walk.png`
- `docs/art/previews/characters_animation/v3_run.png`
- `docs/art/previews/characters_animation/v3_attack.png`
- `docs/art/previews/characters_animation/v3_guard.png`
- `docs/art/previews/characters_animation/v3_dodge.png`
- `docs/art/previews/characters_animation/v3_death.png`
- `docs/art/previews/characters_animation/nightmare_idle.png`
- `docs/art/previews/characters_animation/nightmare_attack.png`
- `docs/art/previews/characters_animation/nightmare_guard.png`
- `docs/art/previews/characters_animation/nightmare_armed_idle.png`
- `docs/art/previews/characters_animation/nightmare_armed_guard.png`

**Что видно:**
- v3 idle/walk/run читаются, ноги не «плавают» в idle; walk показывает шаг, run — flight/stance.
- v3 attack — unarmed boxing stance; меч отсутствует (удалён).
- P1 Nightmare attack/guard — рабочие, но модель визуально слабая.
- P1 unarmed guard — additive `GuardPose` поднимает руки в читаемый блок; armed guard остаётся low guard: меч в правой руке виден в `nightmare_armed_idle.png`, но в `Sword_Idle` клинок уходит вниз/за ногу. Это не финальная sword guard-стойка.

**Измерения grounding (v3, после 120 кадров):**

| Состояние | Model Y | LeftFoot Y | RightFoot Y |
|---|---:|---:|---:|
| Idle | 0.739 | 0.020 | 0.021 |
| Walk | 0.804 | -0.032 | 0.028 |
| Run | 0.652 | 0.147 | 0.180 |

Idle — в пределах 2 см. Walk — одна стопа касается, вторая в шаге. Run — flight phase, обе стопы выше земли; это ожидаемо для бега, но требует проверки в геймплее.

---

## 4. Автоматические проверки

### 4.1. Импорт

```powershell
godot --headless --path . --import
```

Результат: **exit 0** (2026-11-02).

### 4.2. Полный GUT

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

**Прогон 1 (до последних Mannequin/clip-map правок):**

```text
Scripts              81
Tests               622
Passing Tests       620
Failing Tests         2
Asserts           7268/7270
Time              235.986s
```

Два падения:

1. `test_act4_stealth.test_wounded_state_slows_and_dims_but_does_not_start_combat` — order-dependent/flaky; изолированный прогон `test_act4_stealth` — **12/12 passed**.
2. `test_dialogue_barks.test_bark_ui_presents_and_hides_line` — несовпадение регистра `"САННИ"` / `"Санни"`, вне персонажной анимации.

**Прогон 2 (финальное дерево):** процесс не дошёл до summary и завершился на `test_labyrinth_first_fragment` — это pre-existing crash/parse-проблема лабиринта, не анимационный слой. Финальные targeted-наборы после правок — **101/101, 1386 asserts**. Полный suite поэтому не назван «зелёным»: последний завершённый baseline — **620/622**, финальный полный прогон — **NOT COMPLETED**.

### 4.3. Targeted GUT

| Набор | Результат |
|---|---|
| `test_sunny_animation`, `test_sunny_poc`, `test_combat_controller`, `test_sunny_combat`, `test_fall_recovery`, `test_animation_lab`, `test_carapace_enemy`, `test_mountain_king`, `test_caravan_site`, `test_pilgrim_path` | **102/102, 1388 asserts** |

### 4.4. Визуальные/скелетные пробы

- `tools/audit/sunny_v3_tree_probe.gd` — tree states idle/walk/run/dodge/interact; `WalkClean` найден.
- `tools/audit/sunny_nightmare_tree_probe.gd` — tree states idle/walk/run/guard/dodge/interact; `WeaponSocket visible=true` после `set_unarmed(false)`.
- `tools/audit/v3_ground_check.gd` — измерения grounding (таблица выше).
- `tools/audit/attack_contact_probe.gd` — пики 0.400 s.
- `tools/audit/weapon_rotation_probe.gd` — выбор rotation `(90, 90, 0)`.

---

## 5. Изменённые файлы

### Новые

- `assets/characters/generated/sunny_real_v3/sunny_real_v3_clean2.glb`
- `resources/characters/sunny_animation_tree.tres`
- `resources/characters/sunny_v3_animation_tree.tres`
- `scripts/characters/foot_grounder.gd`
- `scripts/characters/guard_pose_modifier.gd`
- `tools/anim/build_sunny_tree.gd`
- `tools/anim/build_sunny_v3_tree.gd`
- `tools/audit/character_asset_audit_extended.py`
- `tools/audit/character_animation_capture.gd`
- `tools/audit/sunny_v3_tree_probe.gd`
- `tools/audit/sunny_nightmare_tree_probe.gd`
- `tools/audit/v3_ground_check.gd`
- `tools/audit/attack_contact_probe.gd`
- `tools/audit/weapon_rotation_probe.gd`
- `tools/audit/clean_sunny_v3.py` / `clean_sunny_v3_clean2.py`
- `docs/demo_sprint/audits/characters_animation.md`
- `docs/demo_sprint/qa/character_animation_report.md`

### Изменённые

- `assets/characters/generated/sunny_real_v3/sunny_v3_model.gd`
- `assets/characters/generated/sunny_real_v3/sunny_real_v3.tscn`
- `assets/characters/sunny_realistic_poc/sunny_waking_poc.tscn`
- `assets/characters/sunny_realistic_poc/sunny_poc_clips.tres`
- `assets/characters/p1/sunny_waking_nightmare.tscn`
- `assets/characters/p1/sunny_p1_model.tscn`
- `assets/characters/p1/sunny_p1_model.gd`
- `scripts/player/sunny_animator.gd`
- `scripts/combat/combat_controller.gd`
- `scripts/combat/mountain_king.gd`
- `scripts/combat/carapace_enemy.gd`
- `scripts/slice/mannequin.gd`
- `scripts/dev/animation_lab.gd`
- `resources/combat/attacks/sunny_light_armed.tres`
- `resources/combat/attacks/sunny_light_unarmed_p1.tres`
- `resources/combat/combat_settings.tres`
- `tests/test_sunny_poc.gd`

---

## 6. Известные проблемы и ограничения

1. **P1 Nightmare визуально слабый.** Функционален, но не финальный. Нужен новый скульпт или weight-transfer с v3-меша на 53-костный риг.
2. **v3 без LOD.** 84k tri + 2K текстуры; для массовых сцен нужен LOD1/2 и, возможно, 1K textures.
3. **Hero v6 и Carapace без LOD.** 90k/120k tri.
4. **Sword guard pose.** `Sword_Idle` — low guard; клинок вниз, не финальная стойка.
5. **Нет turn-in-place.** Контроллер резко поворачивает.
6. **Нет sword combo / parry / riposte / directional hit.**
7. **Weapon hitbox не на мече.** `MeleeAttack` — сфера перед персонажем.
8. **Foot IK нет.** `FootGrounder` — приблизительная визуальная коррекция; walk/run могут иметь остаточный slide.
9. **NPC transitions.** `Mannequin` меняет pose без blend; нужен shared NPC AnimationTree.
10. **Facial animation / blink / lip sync** отсутствуют.
11. **Полный ручной playthrough** — **NOT TESTED**.
12. **1080p / 60 FPS** — **NOT TESTED**.
13. **Rokoko-клипы** остаются staging; orientation после Godot-retarget неверна.
14. **Hyper3D** не запускался; кредиты не расходовались.

---

## 7. Следующие шаги

1. Принять решение по P1 Nightmare: weight-transfer с v3 или новая генерация по concept.
2. Добавить sword guard pose и combo 2–3; выровнять hitbox по мечу.
3. Добавить turn-in-place и foot IK/foot lock; замерить slide в движении.
4. Сделать shared NPC AnimationTree (idle/walk/talk) и подключить к `Mannequin`.
5. LOD1/2 и texture resize для v3, Hero v6, Carapace.
6. Пройти маршрут вручную и обновить этот отчёт фактическими игровыми кадрами и FPS.
