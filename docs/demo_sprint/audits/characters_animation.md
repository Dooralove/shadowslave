# Character & Animation Audit — Shadow Slave

**Дата:** 2026-11-02  
**Статус:** аудит завершён, первый интеграционный пас выполнен.  
**Область:** все персонажи, монстры, NPC, временные модели, сгенерированные ассеты, KayKit, Quaternius, MPFB и доступный animation/rigging-стек.  
**Метод:** разбор GLB JSON/accessor, Godot-пробы скелетов и клипов, Blender-инспекция мешей и действий, GUT, визуальные студийные рендеры.  
**Не является:** финальным арт-ревью всего маршрута и ручным playthrough.

---

## 1. Короткий вердикт

1. **Проблема каста — не «нет ассетов», а качество и интеграция.** Все ключевые персонажи существуют, но большинство P1-моделей — MPFB-тела с простой одеждой, без тангентов, с двусторонними материалами и слабым силуэтом.
2. **Лучший визуальный герой сейчас — сгенерированный Sunny v3** (`sunny_real_v3_clean2.glb`): 84 175 tri, 52 кости, 2K PBR, лицо/волосы/одежда заметно лучше P1. После чистки у него удалён вросший меч, walk-take превращён в in-place `WalkClean`, добавлены тангенты и single-sided материал.
3. **P1 Nightmare Sunny остаётся самым слабым геройским ассетом.** 48 518 tri, 53 кости, UAL-клипы, 3 LOD; визуально это тонкое «манекенное» тело с грубой одеждой. Он функционален, но не финальный.
4. **Покрытие анимаций неравномерно.** Locomotion, базовый удар, смерть, hit и dodge есть почти у всех. Нет turn-in-place, полноценной sword guard-стойки, sword combo, directional hit reactions, special-анимаций, NPC-переходов и части сюжетных действий.
5. **В этом пасе сделано:** v3 Sunny с AnimationTree; P1 Nightmare с общим AnimationTree и weapon socket; выравнивание attack contact по замеренному пику руки; guard hit/guard break; dodge/landing hold; процедурные hit-реакции Mountain King и Carapace; NPC-позы `interact`/`pickup`.
6. **Генеративные кредиты не расходовались.** Hyper3D не запускался; использован уже лежащий в проекте v3-ассет. Массовая генерация не выполнялась.

---

## 2. Инвентарь персонажей и существ

| Ассет | Tri | Verts | Bones | Prims/Mats | UV0 | Tangents | Double-sided | Textures | Clips | Где используется |
|---|---:|---:|---:|---:|---:|---:|---:|---|---:|---|
| `sunny_real_v3_clean2.glb` | 84 175 | 46 074 | 52 | 1/1 | да | да | нет | 2K base/normal/ORM | 10 native | `sunny_waking_poc.tscn` |
| `sunny_nightmare.glb` (P1) | 48 518 | 28 109 | 53 | 17/7 | да | нет | да | 1K/512 PNG | 0 + UAL 46 | `sunny_waking_nightmare.tscn` |
| `sunny_real.glb` (P1) | 46 425 | 27 320 | 53 | 20/8 | да | нет | да | 1K/512 PNG | 0 + UAL 46 | fallback, preview, lab |
| `sunny_poc.glb` | 30 400 | 16 927 | 53 | 20/8 | да | нет | да | 1K/2K PNG | 0 + UAL 46 | POC/tests |
| `Rogue_Hooded.glb` (KayKit) | 6 035 | 5 586 | 41 | 12/1 | да | нет | да | 1K | 76 | `sunny.tscn`, arena/prologue |
| `hero_auro_v6.glb` | 90 000 | 49 139 | 52 | 1/1 | да | нет | да | 2K PBR | 7 native | `Mannequin` hero/auro |
| `hero_auro.glb` (P1) | 54 116 | 33 289 | 53 | 23/9 | да | нет | да | 1K | 0 + UAL 46 | fallback |
| `veteran.glb` (P1) | 57 735 | 34 161 | 53 | 23/9 | да | нет | да | 1K | 0 + UAL 46 | caravan/pilgrim |
| `scholar.glb` (P1) | 65 133 | 38 422 | 53 | 20/8 | да | нет | да | 1K | 0 + UAL 46 | caravan/pilgrim |
| `shifty.glb` (P1) | 47 787 | 28 184 | 53 | 20/8 | да | нет | да | 1K/512 | 0 + UAL 46 | caravan/pilgrim |
| `police_desk.glb` / `police_guard.glb` | 47 209 / 50 215 | 27 084 / 31 338 | 53 | 25/11 | да | нет | да | 1K | 0 + UAL 46 | prologue |
| `mass_*` (5 моделей) | 8 865–14 257 | 5 345–9 256 | 53 | 4–5/4–5 | да | нет | часть | 512 | 0 + UAL 46 | crowd/NPC |
| `mountain_king_p3.glb` | 75 643 | 57 816 | 25 | 18/6 | **нет** | нет | да | **нет** | 5 | ambush/caravan |
| `carapace_scavenger_generated.glb` | 120 000 | 103 280 | 38 | 1/1 | да | нет | да | 2K PBR | 5 | carapace arena |
| `carapace_scavenger.glb` (procedural) | 9 700 | 6 667 | 31 | 15/5 | часть | нет | да | нет | 5 | fallback |
| `larva_corpse.glb` | 28 785 | 32 175 | 25 | 1/1 | да | нет | да | 2K/1K | 1 + Tween | caravan/arena |
| `horse.glb` | 690 | 1 398 | 39 | 2/2 | нет | нет | да | нет | 6 | background prop |
| `sunny_real_v2_rigged_core10.glb` | 94 487 | 54 989 | 52 | 1/1 | да | нет | да | 2K PBR | 10 native | **не интегрирован**, кандидат отклонён |
| `sunny_nightmare_v2_raw.glb` | 93 472 | 51 981 | 0 | 1/1 | да | нет | да | 2K PBR | 0 | **не интегрирован**, нужен риг |
| `sunny_real_v3.glb` (raw) | 87 624 | 48 189 | 52 | 1/1 | да | нет | да | 2K PBR | 10 native | исходник для clean2 |
| `stone_knight_colossus.glb` | — | — | 0 | — | — | — | — | — | 0 | environment statue |
| Soul Sea shades | — | — | 0 | — | — | — | — | — | 0 | static kit |

**Примечания:**
- «Tangents» — наличие `TANGENT` в сыром GLB. Godot-импорт с `meshes/ensure_tangents=true` генерирует их для моделей с normal map; для v3 clean2 тангенты уже записаны в GLB.
- «Double-sided» — материалы с `doubleSided=true`. Для P1 это маскирует перевёрнутые нормали и увеличивает overdraw.
- LOD: P1-модели имеют LOD0/1/2 внутри одного GLB (`_LOD1`, `_LOD2`); v3, Hero v6, Carapace и Mountain King — без LOD.
- `mountain_king_p3` не имеет UV и текстур: это процедурный P1-ассет, а не финальный скульпт.
- P1-модели — 53-костный UE-style риг; v3/Hero v6 — 52-костный Mixamo-style; KayKit — 41-костный chibi-риг. Это три разных скелета, не «один персонаж с разными скинами».

---

## 3. Что проверено по геометрии, ригу и материалам

### 3.1. Сильные стороны

- **v3 Sunny:** лучший силуэт и лицо; одежда и обувь читаются; 52-костный риг с пальцами; 10 клипов; после чистки — single-sided, с тангентами, без вросшего меча.
- **P1-каст:** стабильный 53-костный риг, чистые веса, 3 LOD, UAL-совместимость. Это рабочая база для NPC и fallback.
- **Hero v6:** высокое визуальное качество, 7 native-клипов, корректно деформируется в idle/walk/attack/death по превью.
- **Carapace generated:** читаемый crab-centaur силуэт, 5 клипов, 2K PBR, 38-костный риг.
- **Larva:** здоровый монстр-ассет, 2K albedo, idle-клип + процедурная анимация.
- **Mountain King p3:** читаемый четырёхрукий силуэт, 5 клипов, 3 LOD.

### 3.2. Слабые стороны

- **P1-тела:** тонкие/вытянутые пропорции, крупные кисти, простая одежда, «манекенные» лица. Это не финальный каст.
- **P1-материалы:** почти все двусторонние; тангентов в сыром GLB нет; у части моделей 20–86 примитивов и 8–12 материалов — высокий draw-call.
- **P1 Nightmare:** самый слабый геройский ассет; визуально не соответствует v3 и канону «измождённого подростка».
- **Mountain King p3:** нет UV/текстур, шерсть — геометрия; не финальный скульпт.
- **Carapace generated:** 120k tri без LOD; для арены допустимо, для массовых сцен — тяжело.
- **Hero v6:** 90k tri без LOD; walk-клип — root-motion take, который в `Mannequin` проигрывался на месте (исправлено обработкой `WalkClean`).
- **v3:** 84k tri без LOD; 2K текстуры; нет facial rig; меч был вросшим в меш (удалён).
- **KayKit:** chibi-стиль, 41 кость, нет пальцев; не совместим с реалистичным кастом.
- **MPFB/P1:** нет weapon socket в GLB (создаётся в `sunny_p1_model.gd`), нет IK-контролов, нет foot IK.

### 3.3. Совместимость с Godot

- P1 53-костный риг и UAL 46 клипов импортируются и проигрываются; `SkeletonProfileHumanoid` + BoneMap работают.
- v3/Hero v6 52-костный Mixamo-style риг: native-клипы работают; UAL-клипы **не** переносятся чисто (см. §4.3).
- KayKit 41-костный риг не участвует в общем retarget-пайплайне.
- Weapon socket: `BoneAttachment3D` на `RightHand`; меч `short_sword.glb` (project-owned) виден в armed-режиме, скрыт в unarmed.
- `MeleeAttack` по-прежнему сфера перед персонажем; hitbox не перенесён на оружие.

---

## 4. Animation Coverage Matrix

Легенда качества: **A** — production-ready; **B** — хорошая основа, нужна полировка; **C** — prototype/placeholder; **—** — отсутствует.  
«Retargeted» — клип перенесён на риг персонажа; «Integrated» — реально проигрывается в игре/сцене, а не только лежит в каталоге.

### 4.1. Sunny v3 (real world / prologue / post-nightmare)

| Animation | Existing Asset | Retargeted | Integrated | Quality | Missing Work |
|---|---|---|---|---|---|
| Idle | `HumanStandingIdle` (6.0 s) | native | AnimationTree `Locomotion` | **B+** | лёгкая полировка дыхания; лицо статично |
| Walk | `WalkClean` (1.0 s loop) | native, trimmed 0.8–1.8 s | `Locomotion` blend 0.4 | **B** | loop seam ~5–7 см; нужен foot IK/полировка |
| Run | `HumanSprintLoop` (0.62 s) | native | `Locomotion` blend 1.0 | **B+** | flight phase без grounder; проверить в геймплее |
| Sprint | `HumanSprintLoop` | native | `Locomotion` | **B+** | нет отдельного sprint-клипа |
| Jump | `HumanInplaceJumpL` | native | `Jump` | **B** | нет отдельного fall |
| Fall | `HumanInplaceJumpL` | native | `Fall` | **B−** | падение и прыжок — один клип |
| Landing | `HumanLandrollR` | native, forward drift removed | `Land`, hold 0.6 s | **B** | 2.08 s clip обрезается; нет мягкого land |
| Turn | — | — | controller rotates | **—** | turn-in-place клип |
| Dodge | `HumanRoll` | native | `Dodge`, hold 0.8 s | **B** | 1.46 s clip обрезается |
| Roll | `HumanRoll` | native | `Dodge` | **B** | нет отдельного roll-направления |
| Blocking | `HumanStandingIdle` | native | `Guard` | **C** | нет guard-позы/меча |
| Hit Reaction | `HumanSpHeadHit` | native | `Hit` | **B** | одно направление; нет chest/heavy |
| Death | `HumanDeath` | native | `Death` | **B** | нет death pose/ragdoll |
| Melee Attacks | `HumanSpBoxing` | native | `Attack` | **B** | только unarmed punch; нет sword/combo |
| Special Attacks | `HumanSpBoxing` | native | `Special` | **C** | заглушка; нет spell/shadow |
| NPC Idle | — | — | — | **—** | это игрок, не NPC |
| NPC Gestures | — | — | — | **—** | это игрок, не NPC |
| Interaction | `HumanSit` | native | `Interact` | **C** | sit вместо interact/pickup |
| Transitions | AnimationTree 15 states | — | да | **B** | полная cancellation-матрица; нет turn/guard pose |

### 4.2. Sunny Nightmare (P1, 53 bones, UAL)

| Animation | Existing Asset | Retargeted | Integrated | Quality | Missing Work |
|---|---|---|---|---|---|
| Idle | `sunny/Idle_Relaxed` | UAL | `Locomotion` | **B** | P1-модель визуально слабая |
| Walk | `Jog_Fwd` (2.51 m/s) | UAL | `Locomotion` blend 0.65 | **B** | foot slide подавлен speed_scale; проверить |
| Run | `Sprint` (3.27 m/s) | UAL | `Locomotion` blend 1.0 | **B** | проверить в геймплее |
| Sprint | `Sprint` | UAL | `Locomotion` | **B** | — |
| Jump | `Jump_Start` | UAL | `Jump` | **B−** | нет root motion |
| Fall | `Jump` | UAL | `Fall` | **B−** | — |
| Landing | `Jump_Land` | UAL | `Land`, hold 0.8 s | **B−** | — |
| Turn | — | — | controller rotates | **—** | turn-in-place |
| Dodge | `Roll` | UAL | `Dodge`, hold 0.8 s | **B** | клип 1.47 s обрезается |
| Roll | `Roll` | UAL | `Dodge` | **B** | — |
| Blocking | `Sword_Idle` | UAL | `Guard` + `GuardPose` additive | **C+** | unarmed guard поднят additive-модификатором; armed — low guard, меч вниз; нет guard-walk |
| Hit Reaction | `Hit_Chest` / `Hit_Head` | UAL | `Hit`, `GuardHit` | **B−** | нет directional/heavy |
| Death | `Death01` | UAL | `Death` | **B** | — |
| Melee Attacks | `Sword_Attack` (1.53 s) | UAL | `Attack` | **B** | contact 0.40 s; клип играет ~62 % |
| Special Attacks | `Spell_Simple_Shoot` | UAL | `Special` | **C+** | заглушка без VFX |
| NPC Idle | — | — | — | **—** | это игрок |
| NPC Gestures | — | — | — | **—** | это игрок |
| Interaction | `Interact` | UAL | `Interact` | **B−** | нет pickup-специфики |
| Transitions | AnimationTree 15 states | — | да | **B** | полная cancellation-матрица |

### 4.3. Sunny arena (KayKit Rogue, 41 bones)

| Animation | Existing Asset | Retargeted | Integrated | Quality | Missing Work |
|---|---|---|---|---|---|
| Idle | `Unarmed_Idle` | native | `SunnyAnimator` | **C+** | chibi-стиль |
| Walk | `Walking_A` | native | `SunnyAnimator` | **C+** | foot slide 4× |
| Run | `Running_A` | native | `SunnyAnimator` | **C+** | foot slide |
| Sprint | `Running_A` | native | `SunnyAnimator` | **C+** | — |
| Jump | `Jump_Start` | native | `SunnyAnimator` | **B−** | chibi |
| Fall | `Jump_Idle` | native | `SunnyAnimator` | **B−** | — |
| Landing | `Jump_Land` | native | `SunnyAnimator` | **B−** | — |
| Turn | — | — | controller | **—** | — |
| Dodge | `Dodge_Backward` | native | `SunnyAnimator` | **B−** | root motion игнорируется |
| Roll | — | — | — | **—** | нет |
| Blocking | `Blocking` | native | `SunnyAnimator` | **B−** | full-body |
| Hit Reaction | `Hit_A` | native | `SunnyAnimator` | **B−** | — |
| Death | `Death_A` | native | `SunnyAnimator` | **B−** | — |
| Melee Attacks | `1H_Melee_Attack_Slice_Horizontal` | native | `SunnyAnimator` | **B−** | chibi, обрезается |
| Special Attacks | `Spellcast_*` | native | не подключено | **C** | нет state |
| NPC Idle | — | — | — | **—** | — |
| NPC Gestures | — | — | — | **—** | — |
| Interaction | `Interact` | native | `CinematicActor` | **B−** | — |
| Transitions | нет AnimationTree | — | код | **C** | заменить на tree или оставить арену тестовой |

### 4.4. NPC P1-каст (`Mannequin`, 53 bones, UAL)

| Animation | Existing Asset | Retargeted | Integrated | Quality | Missing Work |
|---|---|---|---|---|---|
| Idle | `Idle_Relaxed` | UAL | `pose=idle` | **B** | нет transitions |
| Walk | `Walk` | UAL | `pose=walk` | **B** | NPC не двигаются, клип статичен |
| Run | `Sprint` | UAL | `pose=run` | **B** | — |
| Sprint | `Sprint` | UAL | `pose=run` | **B** | — |
| Jump | — | — | — | **—** | NPC не прыгают |
| Fall | — | — | — | **—** | — |
| Landing | — | — | — | **—** | — |
| Turn | — | — | — | **—** | — |
| Dodge | — | — | — | **—** | — |
| Roll | — | — | — | **—** | — |
| Blocking | `Sword_Idle` | UAL | `pose=guard` | **C** | — |
| Hit Reaction | — | — | — | **—** | NPC не получают hit |
| Death | `Death01` | UAL | `pose=dead` | **B** | — |
| Melee Attacks | — | — | — | **—** | Hero NPC не дерётся |
| Special Attacks | — | — | — | **—** | — |
| NPC Idle | `Idle_Relaxed` | UAL | да | **B** | случайная фаза/темп |
| NPC Gestures | `Idle_Talking`, `Idle_Torch`, `Fixing_Kneeling`, `Sitting_*`, `Interact`, `PickUp_Table` | UAL | `talk/torch/kneel/sit/interact/pickup` | **B−** | нет wave/point/argue |
| Interaction | `Interact`, `PickUp_Table` | UAL | да | **B−** | — |
| Transitions | нет tree | — | смена pose | **C** | shared NPC AnimationTree |

### 4.5. Hero/Auro v6 (52 bones, native)

| Animation | Existing Asset | Retargeted | Integrated | Quality | Missing Work |
|---|---|---|---|---|---|
| Idle | `HumanStandingIdle` | native | `Mannequin` idle/talk/torch/guard | **B** | лицо статично |
| Walk | `WalkClean` (processed) | native | `Mannequin` walk | **B** | NPC не двигается |
| Run | `HumanSprintLoop` | native | `Mannequin` run | **B** | — |
| Sprint | `HumanSprintLoop` | native | `Mannequin` run | **B** | — |
| Jump | — | — | — | **—** | — |
| Fall | — | — | — | **—** | — |
| Landing | — | — | — | **—** | — |
| Turn | — | — | — | **—** | — |
| Dodge | `HumanRoll` | native | не подключено в Mannequin | **C** | — |
| Roll | `HumanRoll` | native | не подключено | **C** | — |
| Blocking | `HumanStandingIdle` | native | `pose=guard` | **C** | нет guard-клипа |
| Hit Reaction | — | — | — | **—** | — |
| Death | `HumanDeath` | native | `pose=dead` | **B** | — |
| Melee Attacks | `HumanCounterAttack` | native | не подключено | **C** | Hero NPC не дерётся |
| Special Attacks | — | — | — | **—** | — |
| NPC Idle | `HumanStandingIdle` | native | да | **B** | — |
| NPC Gestures | `HumanSit` | native | `sit/ride/kneel` | **C** | нет talk-жестов |
| Interaction | `HumanSit` | native | `pose=sit` | **C** | — |
| Transitions | нет tree | — | смена pose | **C** | — |

### 4.6. Mountain King p3 (25 bones)

| Animation | Existing Asset | Retargeted | Integrated | Quality | Missing Work |
|---|---|---|---|---|---|
| Idle | `Idle` | native | `MountainKing` | **B−** | нет UV/текстур |
| Walk | `Walk` | native | `CHASE` | **B−** | нет run/sprint |
| Run | `Walk` | native | `CHASE` | **C** | — |
| Sprint | — | — | — | **—** | — |
| Jump | — | — | — | **—** | — |
| Fall | — | — | — | **—** | — |
| Landing | — | — | — | **—** | — |
| Turn | — | — | AI rotate | **C** | — |
| Dodge | — | — | — | **—** | — |
| Roll | — | — | — | **—** | — |
| Blocking | — | — | — | **—** | — |
| Hit Reaction | procedural flinch | — | `_on_damaged` | **B−** | нет hit-клипа |
| Death | `Death` | native | `DEAD` | **B−** | — |
| Melee Attacks | `Attack` + `Telegraph` | native | `ATTACK` | **B−** | нет four-arm-specific |
| Special Attacks | `Telegraph` | native | `TELEGRAPH` | **B−** | нет roar/grab/slam |
| NPC Idle | — | — | — | **—** | это монстр |
| NPC Gestures | — | — | — | **—** | — |
| Interaction | — | — | — | **—** | — |
| Transitions | AnimationPlayer state switch | — | да | **B−** | — |

### 4.7. Carapace Scavenger (generated, 38 bones)

| Animation | Existing Asset | Retargeted | Integrated | Quality | Missing Work |
|---|---|---|---|---|---|
| Idle | `Idle` | native | `CarapaceAnimator` | **B−** | 120k tri без LOD |
| Walk | `Walk` | native | `CHASE` | **B−** | нет run |
| Run | `Walk` | native | `CHASE` | **C** | — |
| Sprint | — | — | — | **—** | — |
| Jump | — | — | — | **—** | — |
| Fall | — | — | — | **—** | — |
| Landing | — | — | — | **—** | — |
| Turn | — | — | AI rotate | **C** | — |
| Dodge | — | — | — | **—** | — |
| Roll | — | — | — | **—** | — |
| Blocking | — | — | — | **—** | — |
| Hit Reaction | procedural flinch | — | `_on_damaged` | **B−** | нет hit-клипа |
| Death | `Death` | native | `DEAD` | **B−** | — |
| Melee Attacks | `Attack` + `Telegraph` | native | `ATTACK` | **B−** | нет pincer-specific |
| Special Attacks | `Telegraph` | native | `TELEGRAPH` | **B−** | нет burrow/summon |
| NPC Idle | — | — | — | **—** | это монстр |
| NPC Gestures | — | — | — | **—** | — |
| Interaction | — | — | — | **—** | — |
| Transitions | AnimationPlayer state switch | — | да | **B−** | — |

### 4.8. Larva (25 bones + Tween)

| Animation | Existing Asset | Retargeted | Integrated | Quality | Missing Work |
|---|---|---|---|---|---|
| Idle | `Idle` + procedural writhe | native | `LarvaAnimator` | **B−** | — |
| Walk | procedural bob | — | `CHASE` | **C** | нет skeleton walk |
| Run | procedural bob | — | `CHASE` | **C** | — |
| Sprint | — | — | — | **—** | — |
| Jump | — | — | — | **—** | — |
| Fall | — | — | — | **—** | — |
| Landing | — | — | — | **—** | — |
| Turn | rotation | — | AI | **C** | — |
| Dodge | — | — | — | **—** | — |
| Roll | — | — | — | **—** | — |
| Blocking | — | — | — | **—** | — |
| Hit Reaction | procedural flinch | — | `_on_damaged` | **B−** | — |
| Death | procedural collapse | — | `DEAD` | **B−** | — |
| Melee Attacks | procedural lunge | — | `ATTACK` | **B−** | — |
| Special Attacks | telegraph | — | `TELEGRAPH` | **B−** | — |
| NPC Idle | — | — | — | **—** | — |
| NPC Gestures | — | — | — | **—** | — |
| Interaction | — | — | — | **—** | — |
| Transitions | Tween | — | да | **B−** | — |

### 4.9. Horse (39 bones)

| Animation | Existing Asset | Retargeted | Integrated | Quality | Missing Work |
|---|---|---|---|---|---|
| Idle | `Idle` | native | `horse.tscn` | **B−** | background |
| Walk | `Walk`/`WalkSlow` | native | да | **B−** | — |
| Run | `Run` | native | да | **B−** | — |
| Sprint | `Run` | native | да | **C** | — |
| Jump | `Jump` | native | да | **B−** | — |
| Fall | — | — | — | **—** | — |
| Landing | — | — | — | **—** | — |
| Turn | — | — | — | **—** | — |
| Dodge/Roll | — | — | — | **—** | — |
| Blocking | — | — | — | **—** | — |
| Hit Reaction | — | — | — | **—** | — |
| Death | `Death` | native | да | **B−** | — |
| Melee/Special | — | — | — | **—** | — |
| NPC Idle/Gestures | — | — | — | **—** | — |
| Interaction | — | — | — | **—** | — |
| Transitions | AnimationPlayer | — | да | **C** | — |

### 4.10. Статичные персонажи

- **Stone Knight Colossus** — статичная статуя, рига и клипов нет; анимация не требуется.
- **Soul Sea shades** — статичные kit-меши; анимация не требуется, но для «живого» Моря Души нужны отдельные idle/float-клипы (missing).

---

## 5. Уникальные сюжетные и побочные анимации

| Персонаж/сцена | Требуемое действие | Есть | Статус |
|---|---|---|---|
| Sunny, караван | chained walk, hands bound | `WalkClean`/`Walk` | **частично**: нет bound-hands позы |
| Sunny, клетка | restrained idle, kneel | `Sitting_Idle`/`Fixing_Kneeling` | **частично** |
| Sunny, побег | pick up key, unlock shackles | `PickUp_Table`, `Interact` | **частично** |
| Sunny, алтарь | offer item, kneel, receive blessing | `Interact`/`Sitting_Idle` | **частично** |
| Sunny, оценка/пробуждение | stand, look at hand, collapse/wake | `HumanStandingIdle`/`HumanDeath` | **C**: нет уникальных поз |
| Sunny, бой | sword combo, guard hit, parry, riposte | `Sword_Attack`, `Hit_Head/Chest` | **C**: нет combo/parry/riposte |
| Sunny, способности | shadow step, shadow summon, aspect | `Spell_Simple_Shoot` | **C**: заглушка |
| NPC каравана | march, whip, argue, cower | `Walk`, `Idle_Talking`, `Fixing_Kneeling` | **C**: нет whip/cower |
| Scholar | read, point, reveal | `Idle_Talking`, `Interact` | **C** |
| Shifty | cower, beg, die | `Death01`, `Fixing_Kneeling` | **C** |
| Hero/Auro | fight, last stand, die | `HumanCounterAttack` (не подключён), `HumanDeath` | **C** |
| Veteran | die, bless | `Death01` | **C** |
| Police | aim, arrest, patrol | `Pistol_Aim_*`, `Pistol_Shoot` (UAL, не подключены) | **C** |
| Mountain King | roar, four-arm slam, grab, collapse | `Telegraph`, `Attack`, `Death` | **C**: нет four-arm-specific |
| Carapace | skitter, pincer snap, burrow, death curl | `Walk`, `Attack`, `Death` | **C** |
| Larva | writhe, lunge, corpse burst | procedural + `Idle` | **B−** |
| Horse | idle, walk, run, death | 6 clips | **B−** |

---

## 6. Инструменты, лицензии и ограничения

### 6.1. Что реально доступно и проверено

| Инструмент | Статус | Что можно делать | Ограничения |
|---|---|---|---|
| **Blender 5.1.1** | работает | mesh cleanup, удаление вросших частей, decimate, UV, weights, GLB export, actions | нет встроенного retarget «из коробки»; slotted actions API; нет физики/Cascadeur |
| **Blender MCP 2.2.6 / addon 1.8** | connected, SAFE_MODE | read-only scene info, background scripts, previews | внешние библиотеки/генераторы off; production — только background-скрипты |
| **Godot MCP 0.6.1** | editor connected, runtime helper connected | scene inspection, screenshots, GUT, headless import | runtime helper зависит от autoload/parse errors; полный playthrough не заменяет |
| **Godot 4.7.2** | работает | AnimationTree, BoneAttachment3D, SkeletonModifier3D, GUT | нет встроенного IK-retarget; foot IK нужно писать |
| **Hyper3D CLI** | доступен, но кредиты/подписка | генерация и rigging | в этом пасе **не запускался**; предыдущие проверки: `API_INSUFFICIENT_FUNDS` / `API_NO_ACTIVE_SUBSCRIPTION` |
| **glTF-Transform 4.5.1** | работает | inspect, tangents, optimize, dedup, resize | не заменяет DCC-скульпт |
| **Krita 5.3.4.1 / Materialize 1.78** | установлены | 2D-покраска, PBR-карты | не использовались в этом пасе |
| **UAL 46 clips** | локально | locomotion, jump, sit, punch, sword, pistol, death | combat неполный; stylized |
| **KayKit 76 clips** | локально | 1H/2H, block, dodge, death, spells | chibi, 41 кость, нет пальцев |
| **Rokoko 7 clips** | локально | walk/run/knife/grenade | staging; ориентация после Godot-retarget сломана; лицензия commercial/no AI training |
| **Blender Retarget 5.2.0** | установлен | retarget Mixamo/UE/Rigify | не использован в этом пасе; требует проверки пресетов |
| **Mixamo / MoCap Central / MoCap Online / ActorCore / CMU** | не скачаны | потенциальные библиотеки | лицензии различаются; MoCap Online запрещает AI retargeting без permit; ActorCore запрещает AI training; Mixamo — Adobe terms |

### 6.2. Лицензионные выводы

- **UAL / KayKit / MakeHuman / MPFB / Poly Haven** — CC0; коммерческое использование разрешено.
- **Rokoko free packs** — commercial use, но нельзя использовать для обучения AI без письменного согласия; в проекте лежат как staging, не production.
- **Mixamo** — Adobe FAQ разрешает commercial games, но нельзя раздавать raw FBX; условия AI-обучения не раскрыты — **NOT VERIFIED**.
- **MoCap Online** — commercial до 1M users, но **AI usage запрещён без AI Permit**, включая AI retargeting.
- **ActorCore** — commercial, но **AI training / AI-generated output запрещены**.
- **MoCap Central** — commercial, team ≤3, нельзя standalone redistribution; AI training запрещён, AI-assisted posing разрешён с условиями.
- **Hyper3D** — сгенерированные ассеты project-owned по условиям аккаунта; перед релизом проверить текущие terms.
- **CMU** — free for research/commercial, нельзя resell data.

### 6.3. Кредиты и генерация

- Массовая генерация **не запускалась**.
- v3 Sunny — уже существующий ассет; в этом пасе выполнены только cleanup/trim/export.
- Hyper3D CLI не вызывался; кредиты не расходовались.
- Для следующих генераций: сначала один тестовый ассет, визуальная приёмка, потом batch. Не генерировать массовку до фикса главного героя.

---

## 7. Ключевые находки по приоритетам

### P0 — до следующей демонстрации

1. **v3 Sunny:** удалён вросший меч (2 121 вершина), walk-take превращён в `WalkClean` (0.8–1.8 s, Hips Y/Z drift удалён), добавлены тангенты и single-sided материал.  
2. **P1 Nightmare:** добавлен `WeaponSocket` на `RightHand` с `short_sword.glb`; armed-режим скрыт в прологе, включается `set_unarmed(false)`.  
3. **Attack contact:** замерен пик скорости правой руки; P1 `Sword_Attack` — 0.400 s, v3 `HumanSpBoxing` — 0.400 s. Окно атаки выровнено: windup 0.30, active 0.20, contact 0.40; cooldown 0.95/0.9.  
4. **Dodge:** duration 0.8 s, i-frames 0.3 s, speed 4.0; animator hold 0.8 s вместо полного 1.47 s клипа.  
5. **AnimationTree:** v3 и P1 Nightmare получили 15-state tree с Locomotion blend space и полной cancellation-матрицей.

### P1 — качество и покрытие

1. **P1 Nightmare визуально слабый** — нужен новый скульпт/генерация или weight-transfer с v3-меша на 53-костный риг.
2. **Sword guard/block pose** — `Sword_Idle` низкая, меч вниз; нужна полноценная guard-стойка и guard-walk.
3. **Sword combo / parry / riposte / directional hit** — отсутствуют; UAL `Sword_Attack` — один клип.
4. **Turn-in-place** — нет; контроллер резко поворачивает.
5. **Weapon hitbox** — `MeleeAttack` остаётся сферой перед персонажем, не на мече.
6. **NPC transitions** — `Mannequin` меняет позы без blend; нужен shared NPC AnimationTree.
7. **Enemy hit clips** — Mountain King/Carapace используют процедурный flinch; нужны authored hit/death варианты.
8. **v3/Hero/Carapace LOD** — 84k/90k/120k tri без LOD; нужен LOD1/2 и texture resize.

### P2 — полировка

1. Facial animation / blink / lip sync — отсутствуют.
2. Finger animation — есть в риге, но не используется в клипах.
3. Foot IK / foot lock — нет; grounder приблизительный.
4. Ragdoll / death physics — нет.
5. NPC gestures wave/point/argue — нет.
6. Special ability VFX sync — нет.
7. Full manual playthrough and 1080p/60 FPS — **NOT TESTED**.

---

## 8. Что сделано в этом пасе (файлы)

| Файл | Изменение |
|---|---|
| `assets/characters/generated/sunny_real_v3/sunny_real_v3_clean2.glb` | очищенный v3: меч удалён, walk/landroll drift удалён, tangents, single-sided |
| `assets/characters/generated/sunny_real_v3/sunny_v3_model.gd` | native clip prep: `WalkClean`, loop modes, landroll flatten, ground offset |
| `assets/characters/generated/sunny_real_v3/sunny_real_v3.tscn` | clean2 + `FootGrounder` |
| `resources/characters/sunny_v3_animation_tree.tres` | 15-state native AnimationTree |
| `resources/characters/sunny_animation_tree.tres` | 15-state P1/UAL AnimationTree |
| `assets/characters/sunny_realistic_poc/sunny_waking_poc.tscn` | v3 tree, `WalkClean`, speeds, hold times |
| `assets/characters/p1/sunny_waking_nightmare.tscn` | P1 tree, sword, `Jog_Fwd`/`Sprint`, attack/guard/dodge |
| `assets/characters/p1/sunny_p1_model.tscn` | `FootGrounder` |
| `assets/characters/p1/sunny_p1_model.gd` | runtime `WeaponSocket` + `short_sword.glb` |
| `scripts/player/sunny_animator.gd` | tree support, blend space, authored speeds, hold times, guard hit/break, action API, grounding |
| `scripts/combat/combat_controller.gd` | `start_unarmed`, block hit/guard break hooks, weapon socket auto-find |
| `scripts/characters/foot_grounder.gd` | generalized mesh/skeleton grounder |
| `scripts/characters/guard_pose_modifier.gd` | additive unarmed guard pose; armed low guard remains |
| `scripts/combat/mountain_king.gd` | procedural hit flinch |
| `scripts/combat/carapace_enemy.gd` | procedural hit flinch |
| `scripts/slice/mannequin.gd` | `WalkClean` for native NPCs, `interact`/`pickup` poses |
| `resources/combat/attacks/sunny_light_armed.tres` | cooldown 0.95, windup 0.30, active 0.20, contact 0.40 |
| `resources/combat/attacks/sunny_light_unarmed_p1.tres` | cooldown 0.90, windup 0.30, active 0.20, contact 0.40 |
| `resources/combat/combat_settings.tres` | dodge 0.8 s / i-frames 0.3 / speed 4.0 |
| `assets/characters/sunny_realistic_poc/sunny_poc_clips.tres` | chained/walk → `WalkClean` |
| `scripts/dev/animation_lab.gd` | reuses runtime weapon socket, adds debug weapon |
| `tests/test_sunny_poc.gd` | current v3 player path |

---

## 9. Метрики приёмки

| Метрика | Цель | Факт |
|---|---|---|
| T-pose в игре | 0 кадров | idle/walk/run/attack/hit/guard/dodge/death проигрываются; T-pose не наблюдался в пробах |
| Foot contact (idle) | < 2 см | v3 idle: 0.020 m (FootGrounder) |
| Foot contact (walk) | < 5 % шага | v3 walk: 0.03–0.09 m; P1: 0.02–0.10 m (приблизительно) |
| Loop seam (WalkClean) | < 2 см / 2° | ~5–7 см по стопе; **не идеально** |
| Attack contact | внутри active window | P1 contact 0.400 s при окне 0.30–0.50; v3 0.400 s |
| Dodge clip coverage | > 50 % | 0.8 s из 1.46 s = 55 % |
| Attack clip coverage | > 60 % | P1 0.95 s из 1.53 s = 62 % |
| Transition coverage | 100 % состояний | 15 states, полная cancellation-матрица |
| Weapon socket | следует за `RightHand` | да; меч виден в armed, скрыт в unarmed |
| Full GUT | зелёный | **620/622** baseline; финальный полный прогон **NOT COMPLETED** (crash в `test_labyrinth_first_fragment`) |

---

## 10. Ограничения и NOT TESTED

- **Ручной playthrough** всего маршрута — **NOT TESTED**.
- **1080p / 60 FPS** — **NOT TESTED**; LOD у v3/Hero/Carapace отсутствует.
- **Foot sliding в реальном геймплее** — **NOT TESTED**; замеры сделаны в студийных пробах, не в движении по локациям.
- **Weapon hitbox** — не перенесён на меч; `MeleeAttack` остаётся сферой.
- **Facial animation / blink / lip sync** — отсутствуют.
- **NPC transitions** — `Mannequin` меняет позы без blend.
- **Turn-in-place** — отсутствует.
- **Sword combo / parry / riposte / directional hit** — отсутствуют.
- **P1 Nightmare** — визуально не финальный; нужен новый ассет или weight-transfer.
- **v3/Hero/Carapace** — без LOD; 2K текстуры; оптимизация не завершена.
- **Hyper3D** — не запускался; кредиты не расходовались.
- **Rokoko** — staging, не production; ориентация после Godot-retarget неверна.

---

## 11. Следующий разумный шаг

1. **P1 Nightmare:** weight-transfer с v3-меша на 53-костный P1-риг или новая генерация с утверждённым concept; проверить деформацию в 3 ракурсах.
2. **Sword combat:** добавить guard pose, combo 2–3, parry/riposte, directional hit; выровнять hitbox по мечу.
3. **Turn-in-place + foot IK:** добавить turn-клипы и foot lock; замерить slide в реальном движении.
4. **NPC AnimationTree:** shared idle/walk/talk tree для `Mannequin`.
5. **LOD/оптимизация:** v3, Hero v6, Carapace — LOD1/2, 1K textures, draw-call budget.
6. **Ручной playthrough** и 1080p/60 FPS; обновить QA report фактическими кадрами.
