# Character Animation Pipeline Audit — Shadow Slave

**Дата:** 2026-11-02  
**Статус:** research-only. Код, сцены, тайминги, ассеты и настройки не изменялись.  
**Целевая версия проекта:** Godot 4.7.2, Blender 5.1.1, MPFB 2.0.18, GUT 9.7.1.  
**Главный вопрос:** как получить максимальное качество персонажной анимации при разумных времени и деньгах, не ломая уже работающую игру.

---

## 0. Краткий вывод

1. **Сейчас в проекте две параллельные персонажные системы.** Тестовая арена и старый пролог используют KayKit Rogue/Barbarian (41 кость, 76 клипов, chibi-стиль). Кампания и новые локации используют MPFB/POC Sunny (53 кости, UAL 46 клипов + собственный Idle). P1-модели (13 персонажей, 53 кости) уже собраны; NPC-часть P1 используется через `Mannequin`, но `sunny_p1_model` ещё не подключён к кампании. Это не «один персонаж с разными скинами», а два разных скелета и два разных набора анимаций.
2. **Текущий анимационный слой — код, а не AnimationTree.** `SunnyAnimator` — enum из 11 состояний, `TestEnemy` — 6 состояний, `MountainKing` — 8 состояний, `LarvaAnimator` — Tween-анимация. `AnimationTree`, BlendSpace, StateMachine-ресурсов и AnimationLibrary-ресурсов в проекте нет.
3. **Ключевые технические дефекты видны без новых ассетов:**
   - сильный foot sliding: авторская скорость UAL Walk ≈ 1,0 м/с, а тело идёт 4,0 м/с; клип играет на 1,0×, а не на 4,0×;
   - клип атаки обрезается: при `cooldown = 0,5 с` и клипе 1,067 с (0,909×) проигрывается только ≈ 42,6 % клипа; follow-through и recovery теряются;
   - `Dodge_Backward` имеет root motion ≈ 0,65 м, но `root_motion_track` пуст, а контроллер двигает тело на 3,15 м; клип и перемещение расходятся;
   - блок — full-body поза, включённая по удержанию `sprint`; при движении персонаж «скользит» в стойке блока, block hit / guard break анимаций нет;
   - у POC/P1 нет weapon socket; `MeleeAttack` — статическая сфера, не привязанная к оружию;
   - после смерти и возврата на чекпоинт `FallRecovery` выставляет `animator.state = IDLE`, но не перезапускает Idle-клип; поза смерти может сохраниться (код-анализ; runtime не проверен из-за parse errors в других скриптах).
4. **Бесплатные ресурсы закрывают большую часть locomotion, NPC и взаимодействий, но не дают полноценного A-уровня боя.** Лучшая бесплатная база: UAL 2 Standard (42 клипа), MoCap Central Sample (120+), MoCap Online T.C. Sword, Rokoko 263, Mixamo, Anderson Rohr 134. Для A-уровня sword combat нужен либо один платный mocap-пак (Kubold / MoCap Central), либо ручная анимация.
5. **Рекомендация:** не перестраивать риг и не покупать «всё сразу». Сначала исправить пять инфраструктурных вещей (retarget-тест, AnimationTree, foot IK, weapon socket, attack profile), затем собрать M1 из бесплатных клипов. Если бой M1 действительно приоритетен — добавить **один** платный one-handed sword pack и, при необходимости, Cascadeur Indie для чистки. Ориентир: 6–10 недель на M1, 3–5 месяцев на полный набор 60–80 клипов силами одного человека.

---

## 1. Метод и границы аудита

**Изучено:**
- `docs/DECISIONS.md`, `docs/design/11_combat_system.md`, `docs/design/13_systems_architecture_audit.md`, `docs/production/s2_character_pipeline_plan.md`, `docs/art/art_direction.md`, `docs/art/asset_production_standards.md`, `docs/art/style_gate_p0.md`, `docs/AI_HANDOFF_AFTER_S3_2.md`;
- все персонажные сцены, `.import`-файлы, `AnimationPlayer`, скрипты `SunnyAnimator`, `EnemyAnimator`, `LarvaAnimator`, `CombatController`, `MeleeAttack`, `TestEnemy`, `MountainKing`, `FallRecovery`, `Mannequin`;
- GLB-файлы: `sunny_poc.glb`, `sunny_real.glb`, `sunny_nightmare.glb`, `ual_standard.glb`, `sunny_idle_relaxed.glb`, `Rogue_Hooded.glb`, `Barbarian.glb`, `horse.glb`, P1/NPC-модели;
- живые MCP-статусы Godot и Blender; `get_errors`, `get_console_log`, `classdb_query`;
- целевые GUT-тесты анимации.

**Проверки:**
- `test_sunny_animation.gd`, `test_enemy_animation.gd`, `test_sunny_poc.gd`, `test_sunny_combat.gd` — **38/38 passed, 386 asserts** (фактический запуск 2026-11-02):

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd `
  -gtest=res://tests/test_sunny_animation.gd,res://tests/test_enemy_animation.gd,res://tests/test_sunny_poc.gd,res://tests/test_sunny_combat.gd -gexit
```
- Полный GUT и полноценный runtime-прогон **NOT TESTED**: в текущем рабочем дереве есть parse errors в unrelated-скриптах (`EnemyData`, `StaminaComponent`, `CampaignGuide`), из-за чего `combat_arena.tscn` не инициализируется полностью. Это не ошибка анимационной системы, но ограничивает проверку.
- Визуальная проверка поз: студийные рендеры POC и KayKit в `%TEMP%\opencode\anim_audit\` (не коммитились). Это не игровые кадры; свет и ракурс искусственные.

**Границы:**
- Внешние библиотеки не скачивались в проект. Оценки качества внешних паков — **предварительные**; перед покупкой нужен тест 3 клипов на Sunny.
- Цены и тарифы — на дату аудита, могут зависеть от региона и акций. Это не юридическая консультация.
- Тайминги боя не менялись. Все предложения по синхронизации — только рекомендации.

---

## 2. Текущее состояние проекта

### 2.1. Стек

| Компонент | Фактически |
|---|---|
| Godot | 4.7.2-stable, Forward+, GDScript |
| Blender | 5.1.1; MPFB 2.0.18; glTF/FBX export доступен |
| GUT | 9.7.1 |
| Godot MCP | 0.6.1, editor connected, runtime helper connected |
| Blender MCP | addon 1.8, protocol 15, SAFE_MODE; внешние библиотеки/генераторы off |
| Git LFS | бинарные форматы; текстовые — обычный Git |

### 2.2. Персонажные модели и скелеты

| Файл / сцена | Скелет | Кости | Анимации в GLB | Где используется | Состояние |
|---|---|---:|---:|---|---|
| `assets/characters/sunny_placeholder/Rogue_Hooded.glb` | KayKit Rig | 41 | 76 | `scenes/characters/sunny.tscn`, арена, старый пролог | Временная chibi-модель; есть `handslot_l/r`, ножей; нет пальцев |
| `assets/characters/enemy_placeholder/Barbarian.glb` | KayKit Rig | 41 | 76 | `test_enemy.tscn`, арена | Временный противник; 2H-топор; нет пальцев |
| `assets/characters/sunny_realistic_poc/sunny_poc.glb` | MPFB `game_engine` | 53 | 0 | POC-модель кампании | Реалистичный инди-уровень; A-поза; пальцы есть; weapon socket нет |
| `assets/characters/sunny_realistic_poc/animations/ual_standard.glb` | UAL/Rigify | 53 | 46 | POC, NPC, P1 | CC0; T-поза; пальцы есть; root/hips; combat coverage неполное |
| `assets/characters/sunny_realistic_poc/animations/sunny_idle_relaxed.glb` | UAL/Rigify | 53 | 1 | POC | Собственный `Idle_Relaxed_Loop`, 3 с |
| `assets/characters/p1/models/sunny_real.glb` | MPFB `GeneralSkeleton` | 53 | 0 | P1; `sunny_p1_model` пока не подключён к кампании | Новый Sunny; LOD0/1/2; без анимаций |
| `assets/characters/p1/models/sunny_nightmare.glb` | MPFB | 53 | 0 | P1; `sunny_nightmare_p1_model` | Кошмарный Sunny; без анимаций |
| `assets/characters/p1/models/mass_*.glb`, `hero_auro`, `veteran`, `scholar`, `shifty` | MPFB | 53 | 0 | `Mannequin` / P1 | 13 персонажей; без анимаций |
| `assets/characters/placeholders/humans/*.glb` | MPFB | 53 | 0 | старые placeholder-сцены | 5 моделей; без анимаций |
| `assets/characters/placeholders/horse/horse.glb` | Quaternius Armature | 39 | 6 | `scenes/slice/props/horse.tscn` | Idle/WalkSlow/Walk/Run и др.; фоновый уровень |
| `scenes/enemies/larva_enemy.tscn` | нет скелета | — | — | караван, арена | Процедурный Tween; C |
| `scenes/characters/mountain_king.tscn` | нет скелета | — | — | засада | CSG-примитивы; Tween-смерть; C |

**Вывод:** фактический стандарт для людей — **MPFB/UE-style 53-bone rig** (`Root`, `pelvis`, `spine_01..03`, `clavicle_l/r`, `upperarm_l/r` и т.д.). POC, P1 и NPC уже используют его. KayKit — legacy-исключение с 41 костью и chibi-пропорциями.

### 2.3. Анимационные файлы и библиотеки

| Набор | Клипов | Формат | Скелет | Где подключён |
|---|---:|---|---|---|
| KayKit Rogue | 76 | GLB | KayKit 41 | `Rogue_Hooded.glb` → `AnimationPlayer` |
| KayKit Barbarian | 76 | GLB | KayKit 41 | `Barbarian.glb` → `AnimationPlayer` |
| Quaternius UAL Standard | 46 | GLB | UAL/Rigify 53 | `sunny_poc_model.tscn`, `Mannequin`, P1 |
| `sunny_idle_relaxed` | 1 | GLB | UAL 53 | `sunny_poc_model.tscn` |
| Horse | 6 | GLB | Quaternius 39 | `horse.tscn` |
| P1 / NPC | 0 | GLB | MPFB 53 | анимации берутся из UAL |
| Larva | 0 | Tween | — | `LarvaAnimator` |
| Mountain King | 0 | Tween | — | `MountainKing._on_died()` |

**AnimationLibrary:** UAL и Idle подключены как внешние библиотеки (`libraries = { "": UAL, "sunny": Idle }`). Отдельных `.tres` AnimationLibrary для персонажей нет. KayKit-клипы лежат внутри GLB. Общей библиотеки, разделяемой между персонажами, нет.

### 2.4. AnimationPlayer, AnimationTree, state machines

| Компонент | Факт |
|---|---|
| `AnimationTree` | **нет ни одного** |
| `AnimationNodeStateMachine` | **нет** |
| `AnimationNodeBlendSpace1D/2D` | **нет** |
| `AnimationNodeOneShot` | **нет** |
| `AnimationPlayer` | есть у KayKit, POC, Barbarian, horse, runtime `Mannequin`; UI `spell_overlay`; preview-сцены |
| `SunnyAnimator` | enum `IDLE, WALK, RUN, JUMP, FALL, LAND, ATTACK, HIT, GUARD, DODGE, DEAD`; переходы в `update()` |
| `EnemyAnimator` | следует за `TestEnemy.State`; один attack clip на TELEGRAPH → ATTACK → RECOVERY |
| `LarvaAnimator` | Tween: idle writhe, telegraph, lunge, death |
| `MountainKing` | AI-состояния есть, скелетной анимации нет; смерть — Tween |
| `Mannequin` | 10 поз (`idle/talk/walk/run/guard/torch/kneel/sit/ride/dead`), без переходов; случайная фаза/темп |
| `CinematicActor` | ставит клипы из `ActionClipMap`; `SunnyAnimator.cinematic` отключает конфликт |

### 2.5. IK, оружие, root motion, события

- **IK:** нет. `PostureOffset` — `SkeletonModifier3D`, но это статическая поправка осанки, не IK.
- **Weapon attachment:** у KayKit есть `handslot_l/r` и дочерние Knife/Knife_Offhand; у POC/P1 только `hand_l/r`. `BoneAttachment3D` в проекте нет. `CombatController.weapon_root` объявлен, но нигде не назначен.
- **Root motion:** `root_motion_track` пуст в тестах и сценах. UAL-клипы в основном in-place; `Dodge_Backward` KayKit содержит root translation ≈0,65 м, но он игнорируется. `SunnyController` двигает тело независимо.
- **Animation events:** method tracks в импортированных клипах отсутствуют. Удары, шаги, VFX и звук синхронизируются таймерами/сигналами в коде, не анимацией.

### 2.6. Импорт и ретаргетинг

**UAL:**
- importer `animation_library`;
- `bone_map_ual.tres` → `SkeletonProfileHumanoid`;
- `rename_bones = true`, unique `GeneralSkeleton`;
- `rest_fixer/retarget_method = 1` (Overwrite Axis), `fix_silhouette = true`;
- `remove_immutable_tracks = false`;
- post-import `keep_rotation_tracks.gd`: оставляет вращения всех костей и позиции только `Root`/`Hips`, удаляет scale.

**POC:**
- `sunny_poc.glb` импортируется как scene;
- `bone_map_mpfb_game_engine.tres` → `SkeletonProfileHumanoid`;
- rename bones, unique `GeneralSkeleton`;
- Rest Fixer Overwrite Axis + Fix Silhouette;
- `PostureOffset` добавляет поправку после анимации.

**P1:**
- GLB уже с humanoid-именами (`Root`, `pelvis`, ...); импорт без BoneMap;
- UAL-библиотека подключается к P1 `AnimationPlayer`; track paths совпадают по `GeneralSkeleton`.

**KayKit:**
- собственный скелет и клипы; ретаргетинг не используется.

**Риски:**
- POC — A-поза, UAL — T-поза; Godot Fix Silhouette лечит, но требует `PostureOffset` и может давать плохие стопы/пятки.
- `remove_tracks/unimportant_positions` в Godot 4.7.2 сбоит; используется собственный post-import.
- Нет автоматической проверки, что новый клип не ломает rest pose, foot contact и weapon grip.

### 2.7. Текущее покрытие

**Sunny (POC):** 11 состояний, 11 клипов: Idle, Walk, Sprint, Jump_Start, Jump, Jump_Land, Punch_Jab (attack placeholder), Sword_Idle (guard placeholder), Roll, Hit_Chest, Death01.  
**Нет:** strafe, turn, crouch/sneak, climb, swim, combat idle, block hit, guard break, parry, riposte, directional hit, heavy stagger, knockdown/getup, execution, item use, throw, aim, shadow abilities.  
**NPC:** 10 статичных поз, без переходов и locomotion blend.  
**Barbarian:** idle/chase/attack/hit/death, без block/parry/stagger/knockdown.  
**Larva:** 4 процедурных состояния.  
**Mountain King:** 8 AI-состояний, но 0 скелетных клипов.

### 2.8. Что подтверждено тестами

- Модель KayKit загружается, скелет на месте, все используемые клипы существуют, loop modes корректны.
- POC: скелет ретаргетирован в `SkeletonProfileHumanoid`, в клипах >40 дорожек, позиции только `Root`/`Hips`, высота 1,63–1,72 м, `PostureOffset` активен, пролог проходится.
- Бой: `MeleeAttack` фазы, одно попадание за удар, направление фиксируется, смерть финальна.
- **Не проверено:** визуальное качество в живом runtime, foot sliding, weapon contact, переходы AnimationTree, respawn после смерти.

---

## 3. Целевой уровень качества: A / B / C

### A — Production Ready

Анимацию можно ставить в игру после обычной технической интеграции (retarget, loop, hitbox, экспорт), без художественной переделки.

Критерии:
- анатомически правдоподобная работа тела, перенос веса, таз/корпус/плечи/голова;
- нет foot sliding на целевой скорости; стопа не «плывёт» и не проваливается;
- контакт оружия и хитбокса совпадает; нет проникновения рук в тело/оружие;
- anticipation, contact, follow-through, recovery читаются;
- переходы без скачков поз; loop seam незаметен;
- пальцы и кисть работают; оружие удерживается правильно;
- клип сохраняет качество после retarget на Sunny;
- тайминг совместим с `AttackData`/`MeleeAttack`;
- характеры NPC различимы по пластике, а не только по цвету/модели;
- hit reactions выразительны и направлены, есть разнообразие поз;
- смерти, падения, уклонения и взаимодействия не выглядят как один и тот же клип;
- проверено в 3 ракурсах и в геймплее.

### B — Requires Polish

Хорошая основа, но нужна правка: 0,5–2 дня на клип.

Причины:
- небольшой foot slide или неверный контакт;
- hand/weapon alignment;
- тайминг/восстановление;
- loop seam;
- retarget-артефакты (плечо, локоть, запястье, стопа);
- не хватает пальцев/выразительности;
- root offset/scale.

### C — Prototype Only

Blockout, тест, временное заполнение. Нельзя ship.

Причины:
- неверные пропорции/стиль;
- нет пальцев/оружия/контакта;
- сильный slide;
- процедурная «резиновая» анимация;
- клип не соответствует персонажу или камере.

### Метрики приёмки

| Метрика | Цель |
|---|---|
| Foot slide за stance | < 5 % длины шага; в идеале < 2 см дрейфа |
| Скорость стопы в контакте | < 0,1 м/с |
| Loop seam | < 2 см / 2° |
| Скачок позы на переходе | < 5° на ключевых костях |
| Совпадение weapon tip ↔ hitbox | 100 % active frames |
| Проникновение рука/оружие | < 1 см |
| T-поза в игре | 0 кадров |
| Root motion vs controller | < 2 см расхождения |
| Покрытие состояний | 100 % состояний имеют клип, без fallback |

---

## 4. Оценка текущих ассетов

| Ассет | Текущая оценка | Обоснование |
|---|---|---|
| POC Sunny: Idle | **B−** | Поза читаемая, но руки/плечи stiff; лицо/одежда generic; годится для vertical slice |
| POC Sunny: Walk/Run | **C+** | Foot sliding 4–5×; скорость клипа не связана с длиной шага |
| POC Sunny: Jump/Fall/Land | **C+** | Клипы есть, root/contact не выверены; приземление короткое |
| POC Sunny: Attack | **C** | `Punch_Jab` вместо оружия; клип обрезается на 60 %; hitbox не на оружии |
| POC Sunny: Guard | **C** | `Sword_Idle` как guard; full-body; движение скользит; block hit/guard break нет |
| POC Sunny: Dodge | **C** | `Roll` без root motion; контроллер едет 3,15 м; направление не совпадает |
| POC Sunny: Hit | **C+** | `Hit_Chest` читается, но без направления/тяжести |
| POC Sunny: Death | **B−** | `Death01` читается; после respawn возможна застывшая поза |
| POC Sunny: Sit/PickUp | **B−** | UAL-клипы работают, но без IK и контакта с мебелью |
| KayKit Rogue/Barbarian | **C production / B− prototype** | Chibi, 41 кость, нет пальцев; боевой набор читаемый, но стиль несовместим; 76 клипов |
| UAL Standard | **C+ production / B− prototype** | Хорошая база locomotion; combat неполный; T-поза/A-поза; stylized |
| P1 static models | **C по анимации / B+ по ригу** | 53 кости, LOD, но 0 клипов; UAL применяется |
| NPC Mannequin | **C** | 10 поз, без переходов; одинаков для всех |
| Barbarian enemy | **C production / B− prototype** | 5 состояний, нет directional reactions/block |
| Larva | **C+** | Процедурно читается; нет скелета и полноценных реакций |
| Mountain King | **C** | CSG-блоб, Tween; не соответствует канону |
| Horse | **C+ / B− background** | 6 клипов; для фона достаточно, для героя нет |

**Общая оценка текущей анимации:** **C+ / B−**. Это нормальный blockout/vertical-slice уровень, но не A.

---

## 5. Глобальный обзор бесплатных ресурсов

> **Важно:** «бесплатно скачать» ≠ «можно использовать в игре». Ниже проверены оригинальные страницы и лицензии, где это возможно. Для внешних паков оценка качества предварительная: они не скачивались и не проверялись на Sunny.

### 5.1. Сводная таблица

| Источник | Бесплатно | Категории | Форматы | Скелет | Retarget | Оценка | Лицензия / коммерция | Ограничения | Сложность в Godot |
|---|---:|---|---|---|---|---|---|---|---|
| **Quaternius UAL 1 Standard** (локально) | 46 | locomotion, jump, sit, swim, punch, sword, pistol, death | GLB, FBX, Blend | UAL/Rigify 53 | да | **B−/C+** | CC0; коммерция да | нет атрибуции; набор stylized; combat неполный | низкая |
| **Quaternius UAL 2 Standard** | 42 из 130+ | melee/armed combos, parkour, farming, fishing, zombie, knockback | GLB, FBX, Blend | Universal Humanoid | да | **B− (provisional)** | CC0; коммерция да; Source $14.99 | free — только 42; sword combo есть, blocks/parries мало | низкая |
| **Mixamo** | ~2 400 записей каталога (не офиц. счёт) | locomotion, combat, dance, idle, interactions | FBX | `mixamorig` ~65 | да | **B+ locomotion / C+ combat** | Adobe FAQ: royalty-free, commercial, games; attribution не заявлена (FAQ/community) | Adobe ID; не Enterprise/Federated; не Китай; нельзя раздавать raw FBX; нет пропсов | средняя |
| **KayKit Adventurers** (локально) | 76 на модель | 1H/2H, block, dodge, death, spells, sit, lie, throw | GLB | KayKit 41 | ограниченно (нет пальцев) | **C production / B− prototype** | CC0; коммерция да | chibi; 41 кость; нет пальцев; оружие в handslot | низкая |
| **Rokoko Free 263** | 263 | 16 walk/run, 10 idle, 13 fight, 10 weapon, 6 martial arts, 12 zombie, 15 superhero, 11 gun, 12 sports | FBX | Mixamo / UE4 / UE5 / HIK | да | **B+/A−** | commercial use; 30 FPS | регистрация/опрос; finger data зависит от пака | средняя |
| **Rokoko Motion Library 10 free weapon** | 10 | fight/weapon handling | FBX | HIK | да | **B+** | commercial use | только 10; без контекста | средняя |
| **MoCap Online Free Sampler + T.C. Sword** | 2 пака; точное число клипов не опубликовано | locomotion, idle, combat, sword attacks/blocks/combos | FBX, UE, Unity, Blender, BIP, iClone | MotusMan | да | **A−/B+** | Standard: commercial до 1M users / $1M revenue; royalty-free | **AI usage запрещён без AI Permit**, включая AI retargeting; raw redistribution нельзя | средняя |
| **MoCap Central Free Sample** | 120+ | fantasy/combat, dance, interactions, locomotion, fingers | FBX, UE5, Unity | UE5 Manny | да | **A−/B+** | EULA: royalty-free commercial; team ≤3; no standalone redistribution | 30 FPS; пропсы отдельно; не полный sword system | низкая/средняя |
| **ActorCore Free** | 32 при регистрации; 33 текущих | daily life, communication, gun, stealth, magic, idle/run | FBX, BVH | ActorCore/UE/HIK | да | **B** | EULA: commercial, royalty-free; no AI training/generated output | 10 downloads/day; free set меняется; sword combat почти нет | средняя |
| **CMU MoCap** | 2 605 последовательностей | locomotion, sports, dance, interactions, test | BVH, ASF/AMC, C3D | CMU/BVH, не humanoid | через Blender | **C+/B− после чистки** | free for research/commercial; нельзя resell data | старый захват, нет пропсов/пальцев; чистка | высокая |
| **Anderson Rohr Free Packs** | 134 | everyday actions, cleaning, talking, crowd, soccer, fitness | FBX, 60 FPS | UE5 Manny / Rokoko Newton / iClone | да | **B+ NPC** | commercial, no attribution (CG Channel/Gumroad) | не бой; в основном бытовые действия | низкая/средняя |
| **Ultimate Animation Library (Godot)** | 20 из 102 | sword slash, parry, fireball, dash, rifle, sports | GLB, Godot 4.7 project | mannequin | да | **C+/B−** | custom: commercial finished games; no standalone resale; AI-assisted | stylized, без пропсов; качество не проверено | низкая |
| **Kubold Sword Animset Pro** (платно) | — | 178 клипов: one-handed sword, right hand, no shield | FBX, HIK | HIK/Mecanim | да | **B+/A− (provisional)** | commercial compiled games; no source redistribution | старый пак; нет shield; root motion | средняя |
| **MoCap Central Longsword Vol.1/2** (платно) | — | 180 / 423 клипа: longsword attacks, parries, hit reacts, deaths, dodges, finishers | FBX, UE5, Unity | UE5 Manny | да | **A− (provisional)** | EULA commercial; team ≤3; no standalone redistribution | two-handed; Sunny использует short sword; цена $89.99/$139.99 | средняя |
| **ActorCore Sword & Shield Moves** (платно) | — | sword & shield attack/block/combo; точное число клипов не проверено (в каталоге 148 паков) | FBX, BVH | ActorCore | да | **B+ (provisional)** | commercial EULA; no AI | shield не канон для Sunny; цена ~$69 | средняя |

### 5.2. Что реально даёт бесплатный набор

**Locomotion / NPC / interactions — да, почти полностью.**
- UAL + Mixamo + Rokoko + Anderson Rohr + MoCap Central sample закрывают idle, walk, run, jump, sit, talk, pick up, crowd, everyday actions.
- Для NPC это позволяет уйти от 10 статичных поз к полноценному shared AnimationTree.

**Sword combat — частично.**
- UAL 2 free: 42 клипа, включая `SWORD_REGULAR_A`, combo A/B, `SWORD_DASH`, `KNOCKBACK`; но нет полноценных block/parry/hit-direction/death набора.
- MoCap Online T.C. Sword: атаки, блоки, комбо, возможно parry/riposte; точное число клипов не опубликовано.
- MoCap Central sample: 120+ клипов, включая fight, but not a complete longsword system.
- Mixamo: много атак/блоков/уклонений, но generic, старая база, требует чистки.
- **Ни один бесплатный пак не даёт одновременно 3-hit combo + directional hit reactions + block hit + guard break + parry + riposte + deaths + weapon contact для одного оружия.**

**Вывод:** бесплатный набор достаточен для **B-прототипа** боя и для **A-уровня locomotion/NPC**. Для **A-уровня боевой системы** нужен либо один paid combat pack, либо 3–6 недель ручной анимации/Cascadeur.

### 5.3. Лицензионные ловушки

1. **MoCap Online:** Standard License разрешает commercial до 1M end users / $1M revenue, но **запрещает AI usage** без отдельного AI Permit. Это включает «AI-powered retargeting», AI cleanup, AI synthesis. Если используем MoCap Online и AI-инструменты — нужен permit или классический retarget.
2. **ActorCore:** EULA разрешает commercial games, но **запрещает AI training / AI-generated output** и redistribution. Нельзя использовать как обучающий датасет.
3. **Rokoko:** Terms 5.4 запрещают использовать Rokoko Assets для обучения AI без письменного согласия. Сгенерированные Rokoko Create данные — commercial, по FAQ.
4. **Mixamo:** официальный FAQ разрешает personal/commercial/non-profit, включая video games; attribution явно не заявлена (по FAQ/community — не требуется, но это стоит проверить перед релизом). Нельзя раздавать raw FBX как standalone; Adobe ID обязателен; Enterprise/Federated IDs и Китай недоступны. Условия AI-обучения на клипах в FAQ не раскрыты — **NOT VERIFIED**, не использовать как датасет без отдельной проверки.
5. **CMU:** free for research and commercial; **нельзя resell data** даже в конвертированном виде. Attribution желательна.
6. **MoCap Central:** EULA royalty-free commercial, single user/entity, team ≤3; нельзя standalone redistribution; **нельзя AI training/fine-tune**, но AI-assisted auto-posing/in-betweening разрешены при условиях (не обучение модели). Для команды >3 — дополнительная лицензия.
7. **CC0 (UAL, KayKit):** ограничений нет; attribution не обязательна.
8. **Ultimate Animation Library:** commercial finished games, но не standalone resale; **AI-assisted** — при релизе проверить раскрытие AI (Steam и т.п.).
9. **Plask:** условия противоречивы; free tier выглядит personal/evaluation, commercial — только paid, но страница тарифов не называет «Commercial plan». **NOT VERIFIED.**
10. **DeepMotion:** free tier — non-commercial; paid — commercial. Free tier 25 кредитов/мес (pricing page) vs 60 секунд (FAQ) — **расхождение, проверить в аккаунте**.

---

## 6. AI-генерация движения

| Инструмент | Тип | Бесплатно | Платно | Форматы | Лицензия | Качество | Ограничения | Вердикт |
|---|---|---|---|---|---|---|---|---|
| **Rokoko Vision 3.0 / Create** | video-to-motion + text-to-motion | 30 с/мес; text clips unlimited, 5 imports/month; FBX | Basic $10/мес annual, 600 с; Plus $20/3000 с; Pro $50/15000 с | FBX, BVH | commercial use; generated data — commercial | **B− после cleanup** | нет finger tracking; occlusion; один performer; cloud | Лучший бесплатный AI-вариант для base motion |
| **DeepMotion Animate 3D** | video-to-motion | 25 кредитов/мес, 20 с clips, non-commercial | Starter $9/мес annual, 180 credits; paid commercial | FBX, BVH, GLB, MP4 | free non-commercial; paid commercial | **C+/B−** | foot sliding, jitter; face/hand extra credits; cloud | Только paid, только base |
| **Plask** | video-to-motion | 15 с/день; FBX/GLB/BVH | Standard $18/мес annual, 10 мин; Pro $50/мес, 1 ч | FBX, GLB, BVH | commercial terms **NOT VERIFIED** | **C+/B−** | twitching, sliding; commercial plan unclear | Не использовать без письменного подтверждения |
| **NVIDIA Kimodo** | text-to-motion + constraints | open code/weights | free (local GPU) | NPZ, AMASS; retarget через Blender | code Apache-2.0; SOMA checkpoints NVIDIA Open Model (commercial); SMPL-X variant R&D only | **B− base** | 17 GB VRAM full; <3 GB с CPU text encoder; foot skate; limited actions; SOMA 77 | Экспериментально; хорош для уникальных base motions |
| **GVHMR** | video-to-motion | open | free | SMPL/SMPL-X | **non-commercial/research; SMPL license** | **C+** | research only; no commercial | Не использовать |
| **Move AI** | video-to-motion | trial/limited | from ~$15/мес; commercial paid | FBX/BVH | commercial paid | **B−** | paid; single/multi-cam; cloud | Резерв, если Rokoko Vision не хватает |
| **Cascadeur AI (AutoPosing / Root Motion Tool)** | не генерация, а физика/поза | free non-commercial | Indie €8–19/мес; Pro €33–49/мес | CASC, FBX, DAE, USD, GLTF | commercial paid; free — no | **A− для polish** | retargeting только Pro | Лучший инструмент для чистки/физики |

**Вывод по AI:** AI-генерация в 2026 году полезна для **base motion / blockout / уникальных движений**, но не для финального A-уровня. Типичные проблемы: foot skating, jitter, потеря пальцев/кистей, окклюзия, нет пропсов и контакта оружия, слабое следование сложному бою. Бюджет на cleanup — 0,5–2 дня на клип; для 60 клипов это сопоставимо с покупкой mocap-пака.

---

## 7. Совместимость с Sunny

### 7.1. Факты по скелету Sunny (POC/P1)

| Параметр | Значение |
|---|---|
| Костей | 53 |
| Корень | `Root` (в POC/P1), `root` (UAL) |
| Таз | `pelvis` (POC/P1), `DEF-hips` (UAL) |
| Позвоночник | `spine_01..03` / `DEF-spine.001..003` |
| Шея/голова | `neck_01`, `head` |
| Руки | `clavicle_l/r`, `upperarm_l/r`, `lowerarm_l/r`, `hand_l/r` |
| Пальцы | по 15 костей на руку (thumb 3, index/middle/ring/pinky 3) |
| Ноги | `thigh_l/r`, `calf_l/r`, `foot_l/r`, `ball_l/r` |
| Rest pose | **A-поза**: плечо→кисть ≈ 0,43 м по X и −0,33 м по Y (≈37° вниз) |
| Рост | 1,63–1,72 м; капсула 1,8 м |
| Skin weights | 0 unweighted; max 4 influences; сумма 1,0 |
| Weapon socket | **нет**; только `hand_r`/`hand_l` |

### 7.2. Сравнение с другими скелетами

| Скелет | Костей | Rest pose | Пальцы | Weapon socket | Масштаб | Совместимость |
|---|---:|---|---|---|---|---|
| Sunny/P1 MPFB | 53 | A-pose | да | нет | 1,65–1,70 м | база |
| UAL/Rigify | 53 | T-pose | да | нет | ~1,70 м | отличная по BoneMap; A/T fix |
| KayKit | 41 | T-pose | **нет** | `handslot_l/r` | 2,25 м raw; 0,8× = 1,8 м | ограниченная; пальцы не переносятся |
| Mixamo | ~65 | T-pose | да | нет | ~1,8 м | хорошая через BoneMap; weapon grip вручную |
| UE5 Manny | ~60+ | T-pose | да | нет | ~1,8 м | хорошая; POC уже UE-style |
| Rokoko Newton | HIK | T-pose | зависит от gloves | нет | ~1,8 м | хорошая через HIK/Mixamo preset |
| MoCap Central | UE5 Manny | T-pose | да | нет | ~1,8 м | хорошая; 30 FPS |

### 7.3. Ретаргетинг: что уже работает

- UAL → POC прошёл: `SkeletonProfileHumanoid`, BoneMap, rename, unique `GeneralSkeleton`, Rest Fixer Overwrite Axis + Fix Silhouette.
- POC tests: >40 дорожек, позиции только `Root`/`Hips`, все клипы задают полную позу, высота в допуске, после сидения Idle поднимает таз.
- P1 модели уже используют humanoid-имена и UAL-библиотеку; отдельный BoneMap не нужен.
- KayKit не участвует в этом ретаргетинге; его 41 кость и отсутствие пальцев — тупиковая ветка для общего pipeline.

### 7.4. Проблемные места

1. **A-pose vs T-pose.** Sunny — A-поза, UAL/Mixamo/UE — T-поза. Godot Fix Silhouette лечит, но может испортить пятки/стопы; `PostureOffset` — временная заплатка, а не решение.
2. **Bone naming.** POC/P1 — UE-style; UAL — Rigify; KayKit — собственный; Mixamo — `mixamorig`. Нужен единый `SkeletonProfileHumanoid` + проверка mapping.
3. **Fingers.** POC/UAL/Mixamo/MoCap Central имеют пальцы; KayKit — нет. Нельзя смешивать finger-клипы с KayKit.
4. **Weapon socket.** У POC/P1 нет `handslot`/`weapon_r`; нужно добавить `BoneAttachment3D` на `hand_r` или отдельную кость `weapon_r`.
5. **Root motion.** UAL loco — in-place; KayKit dodge — root motion; POC Roll — hips motion. Нужна политика «один владелец движения».
6. **Scale.** UAL 1,7 м, Sunny 1,65–1,70 м, KayKit 1,8 м. `normalize_position_tracks` и `motion_scale` обязательны; иначе foot slide.
7. **Rest pose / bone roll.** Mixamo/UE могут дать twist плеча/локтя; нужен визуальный тест в 3 ракурсах, а не только `has_animation`.
8. **Weapon contact.** Даже при идеальном retarget кисть не гарантирует правильный хват; нужен IK/attachment и калибровка.

### 7.5. Рекомендация по ригу

- **Не перестраивать POC/P1 скелет.** Он уже стандартный, веса чистые, UAL работает.
- Добавить в Blender animation rig (не в игру) контрольные IK/FK-кости, weapon socket, pole targets; bake на deform-скелет.
- В игре добавить `BoneAttachment3D` на `hand_r` (и `hand_l` при необходимости), `weapon_r` socket, `TwoBoneIK3D` для ног и, при необходимости, левой руки под двуручное оружие.
- Для новых персонажей использовать тот же 53-bone MPFB/UE-style rig; не заводить KayKit-подобные исключения.
- Для Mixamo/UE-клипов делать retarget в Blender (Retarget extension), а не массовый импорт в Godot без проверки.

---

## 8. Инструменты создания и редактирования

### 8.1. Blender 5.1.1

**Что есть:**
- Animation Editor, Dope Sheet, Action Editor, Graph Editor, NLA Editor;
- Rigify (bundled, включается в Preferences; GPL; генерирует FK/IK контролы, но не skinning);
- constraints, IK/FK, drivers, Python API, batch operations;
- glTF 2.0 и FBX export;
- новые slotted actions (Blender 4.4+): slots/layers в API; в UI layers пока не выставлены, NLA остаётся основным слоем;
- высокая скорость playback в 5.1.

**Чего нет:**
- встроенной физики/autoposing как в Cascadeur;
- Maya-подобного UI animation layers (есть NLA; платный add-on Animation Layers $28 — опция);
- автоматического retargeting «из коробки» (нужен Retarget extension / ARP / Rokoko);
- продвинутого motion matching.

**Вывод:** Blender 5.1.1 достаточно для keyframe, cleanup, NLA, rigging и batch Python. Для физически правдоподобной чистки mocap и быстрого pose-to-pose — Cascadeur; для массового retarget — Retarget extension.

### 8.2. Retargeting

| Инструмент | Цена | Blender 5.1 | Поддержка | Ограничения | Вердикт |
|---|---|---|---|---|---|
| **Blender Retarget (KBS-DEV)** | free, GPLv3 | **да, 5.0+; 5.2.0** | Mixamo, UE, VRoid, MMD, Daz, Auto-Rig Pro presets; batch | интерфейс/пресеты требуют проверки; rest pose должен совпадать | **Рекомендуется** |
| **Rokoko Studio Live plugin** | free (retarget), LGPL | **официально 4.4; 5.1 issues, PR #141 open** | Mixamo/HIK/custom | на 5.1.1 не production-ready; beta может работать | **Не основной**; использовать только после теста |
| **Auto-Rig Pro Remap** | $50 full / $25 lite | да, 2.93–5.2 | любые armatures, BVH/FBX, IK | платно; нужен ARP rig/Remap | Хорош, если покупать ARP |
| **Expy Kit** | free/paid | старые версии; для 5.x — fork Retarget | Mixamo/Rigify/UE | обновления/поддержка нестабильны | Резерв |
| **Rig Bridge** | free, GPL | 5.1+ | auto-detect humanoid, batch, root/in-place | новый инструмент, меньше проверен | Экспериментально |
| **Godot import retarget** | free | 4.7.2 | SkeletonProfileHumanoid | Rest Fixer/A-pose issues; нет batch UI | Обязательная финальная проверка, не замена Blender |

### 8.3. Rigging

| Инструмент | Цена | Плюсы | Минусы | Вердикт |
|---|---|---|---|---|
| **MPFB game_engine** (текущий) | free, CC0 assets | уже работает; UE-style 53 кости; пальцы; веса | нет weapon socket/IK controls; generic | **Оставить** |
| **Rigify** | free, bundled | мощные FK/IK контролы, лицо, пальцы | не auto-skinning; T-pose; экспорт требует cleanup | Для новых rigs/анимационного рига |
| **Auto-Rig Pro** | $50 full / $25 lite | auto-rig, Remap, Godot/UE export presets, face | платно; GPL add-on; нужен навык | Купить, если делать новых персонажей/много rigs |
| **AccuRIG** | free | быстрый auto-rig, FBX/USD, fingers | нет animation retarget; Reallusion account; EULA | Резерв, не основной |
| **Reallusion CC5** | paid | высокое качество персонажей | дорого, тяжёлый pipeline, лицензии | Не сейчас |

### 8.4. Специализированная анимация

| Инструмент | Бесплатно | Платно | Форматы | Retarget | Физика/AI | Ограничения | Железо/диск | Вердикт |
|---|---|---|---|---|---|---|---|---|
| **Cascadeur** | free: полный toolset, **CASC only, non-commercial** | Indie €19/мес или €8/мес annual, revenue <$100k, FBX/DAE/USD/GLTF; Pro €49/€33, retargeting + environment | CASC, FBX, DAE, USD, GLTF | **только Pro** | AutoPhysics, AutoPosing, Inbetweening, AI Root Motion Tool | Indie без retargeting; free нельзя commercial | Win/mac/Linux; ~503 MB download; 4 GB RAM min | **Лучший polish-инструмент**; брать Indie, если нужен экспорт |
| **Rokoko Studio** | Starter $0: FBX export, cleanup filters, Motion Library; 30s Vision | Basic $10/мес annual: custom retarget, BVH; Plus $20; Pro $50 | FBX, BVH, CSV | Basic+ | cleanup filters, smoothing, loop, foot lock | custom retarget только Basic+; cloud | Win/mac; cloud | Хорош для mocap cleanup; free для FBX |
| **Rokoko Create** | 30s video; unlimited text, 5 imports/month | Basic 600s/100 imports; Pro 15000s | FBX/BVH via Studio | через Studio | text-to-motion, video-to-motion | нет finger tracking; occlusion | browser/cloud | Для base motion |
| **Rokoko Blender plugin** | free | live stream Plus+ | — | free retarget | — | **Blender 5.1 not officially supported** | local | Не основной |
| **Animation Layers add-on** | — | $28 | Blender | — | NLA UI | не нужен для базового NLA | local | Опция, не необходимость |
| **MetaHuman/UE** | free-ish | Epic account, UE install | FBX | UE | facial/body | тяжёлый, не для Godot; лицензия | десятки ГБ | Не сейчас |
| **Reallusion CC5/ActorCore** | free motions | CC5 paid | FBX/BVH | iClone | high-quality | дорого; EULA no AI | Windows | Не сейчас |

### 8.5. Что действительно необходимо, а что избыточно

**Необходимо:**
1. Batch retarget source → Sunny + проверка rest pose/scale.
2. Cleanup: foot contact, hips/root, hand/weapon, loop seams, timing.
3. NLA/layers для комбинирования (guard + walk, hit + locomotion).
4. AnimationTree: state machine + blend space + one-shot.
5. Foot IK и weapon attachment/IK.
6. Animation events/profile для hit windows, footsteps, VFX.
7. QA-метрики и тесты на slide/contact/transition.

**Полезно, но не обязательно сейчас:**
- Cascadeur для физики/чистки;
- Auto-Rig Pro для новых персонажей;
- платный combat pack;
- Motion Library подписка;
- face/finger capture.

**Избыточно / рискованно:**
- MetaHuman/UE pipeline;
- Reallusion CC5;
- motion matching для 1v1;
- mocap suit;
- AI text-to-motion как финальный источник;
- runtime retargeting;
- полный facial rig до утверждения лица Sunny.

### 8.6. Бюджет

| Вариант | Состав | Ориентир |
|---|---|---:|
| Free-first | UAL 2 free + MoCap Central sample + MoCap Online free + Rokoko 263 + Mixamo + Anderson Rohr + Blender Retarget | **$0** |
| Minimal paid | UAL 2 Source $14.99 + Kubold Sword ~$65 + Cascadeur Indie $96/год + Auto-Rig Pro опционально $50 | **$100–250** |
| Combat pack | MoCap Central Longsword Vol.1 $89.99 или Vol.2 $139.99 | **$90–140** |
| Pro | Cascadeur Pro $396/год + ARP $50 + 2 packs | **$500+** |
| Custom mocap | студия + каскадёр + cleanup, один weapon archetype | **$20k–50k** (оценка MoCap Online; не проверялась для нашего масштаба) |

**Время:** 60–80 клипов × 0,5–2 дня cleanup = 6–10 недель чистого времени; с rig/architecture/QA — 3–5 месяцев при одном человеке. M1 25–30 клипов — 6–10 недель.

---

## 9. Боевая анимация Shadow Slave

### 9.1. Что есть в коде

- `MeleeAttack`: `READY → WINDUP → ACTIVE → RECOVERY`; урон только в ACTIVE; один хит на цель за удар; направление фиксируется при старте.
- `AttackStats` / `AttackData`: damage, cooldown, windup, active, reach, radius, stamina, guard damage, hitstop.
- `CombatController`: light attack, dodge с i-frames, block по удержанию `sprint`, stamina, guard break.
- `SunnyAnimator`: attack/hit/guard/dodge/death — визуальный слой; урон не наносит.
- `TestEnemy`: Idle → Chase → Telegraph → Attack → Recovery → Dead; `EnemyAnimator` один attack clip.
- `MountainKing`: AI + Tween; скелетной анимации нет.
- **Cancel windows:** в коде их нет. Атаку нельзя отменить в recovery, кроме смерти/`disable()`; таблица отмен из `docs/design/11_combat_system.md` §3.6 остаётся документом, не реализацией. Парирование описано в дизайне, но в коде отсутствует; блок есть.

### 9.2. Текущие тайминги и клипы

| Действие | Windup | Active | Recovery | Total | Клип | Длина | Speed | Реально проигрывается | Проблема |
|---|---:|---:|---:|---:|---|---:|---:|---:|---|
| Sunny armed light | 0,20 | 0,15 | 0,15 | 0,50 | `1H_Melee_Attack_Slice_Horizontal` | 1,067 | 0,909 | **0,50 / 1,174 = 42,6 %** | follow-through/recovery обрезаны |
| Sunny unarmed light | 0,14 | 0,12 | 0,16 | 0,42 | `Punch_Jab` | 0,867 | 1,25 | **0,42 / 0,694 = 60,5 %** | клип обрезан; contact time не пересчитан |
| Larva bite | 0 | 0,20 | 0,95 | 1,15 | процедура | — | — | — | нет скелета |
| Mountain King | 1,10 telegraph | 0,30 | 1,40 | 4,50 между атаками | Tween | — | — | — | нет скелета |
| Barbarian | 0,60 telegraph | 0,20 | 1,00 | ~1,80 | `2H_Melee_Attack_Chop` | 1,633 | ~1,02 | 1,60 | клип заканчивается раньше recovery; idle fallback |

**Формула:** `played_fraction = min(1, total / (clip_length / speed_scale))`.

### 9.3. Найденные несоответствия

1. **Клип атаки обрезается.** `SunnyAnimator` выходит из ATTACK, как только `attack.is_attacking()` стал false; клип не доигрывается. Это объясняет «рваный» удар и отсутствие follow-through.
2. **Один `attack_contact_time` на все атаки.** `SunnyAnimator.attack_contact_time = 0,25`; при смене клипа (`Punch_Jab`, другой удар) contact не пересчитывается. `CombatController` меняет clip, но не contact time.
3. **Hitbox не на оружии.** `MeleeAttack` — сфера radius 0,8, reach 1,0, позиция (0,1,0) на `Visual`; не следует за `hand_r`/`handslot_r`; нет sweep; нет line-of-sight.
4. **Dodge не совпадает.** `dodge_speed = 7,5`, `duration = 0,42` → 3,15 м; `Dodge_Backward` root ≈0,65 м; root motion ignored; один клип на все направления.
5. **Guard — full-body.** `_guard` возвращает управление до locomotion; при движении персонаж скользит в блоке; `block_move_multiplier = 0,45`; block hit/guard break анимаций нет.
6. **Hit reaction без направления.** `HealthComponent.damaged` передаёт только amount; `SunnyAnimator` играет один `Hit_A`/`Hit_Chest`; нет front/back/left/right, heavy stagger, knockdown.
7. **Ввод блока/уклонения.** Блок — удержание `sprint`; уклонение — `jump` в бою. Нет отдельных `block`/`dodge` actions; это затрудняет AnimationTree и тесты.
8. **Смерть/respawn.** `FallRecovery.recover()` ставит `animator.state = IDLE`, но не вызывает `_play(idle_clip)`; `update()` не перезапустит клип, если state уже IDLE. Поза смерти может остаться. **Требует runtime-проверки после исправления parse errors.**
9. **POC combat — заглушка.** `attack_clip = Punch_Jab`, `guard_clip = Sword_Idle`, `dodge_clip = Roll`; оружия нет; это не боевой набор Санни.
10. **Combat ↔ locomotion без переходного слоя.** После атаки `SunnyAnimator` сразу выбирает WALK/RUN/IDLE; combat idle, draw/sheathe и transition-клипов нет. Это даёт резкий переход и «обычную» стойку в бою.
11. **Канон.** В Первом Кошмаре Санни большую часть времени без меча; он использует цепь, короткий меч, колокол. Полноценная sword-система — это арена/будущие арки, а не канонический вертикальный срез. Нельзя строить 100 клипов меча раньше, чем закрыты цепь, взаимодействия и постановки.

### 9.4. Перечень анимаций для Санни

**P0 — канон/вертикальный срез (без боя):**
- Idle relaxed, tired, cold, wounded;
- Walk, chained walk, exhausted walk, run, sprint;
- Jump start/loop/land, fall, roll;
- Crouch/sneak, crawl/wounded crawl;
- Sit, stand, lie, get up;
- Pick up, inspect, use, drink, eat, bandage, shackles, bell ring;
- Climb ledge, squeeze, swim (если нужно);
- Carry, throw, pull lever, light fire;
- Death/collapse, wake up.

**P1 — бой M1 (один враг, один набор):**
- Unarmed: combat idle, jab, cross, hook, kick, knee, grab/throw;
- Knife/short sword: combat idle, draw/sheathe, light 1/2/3, heavy, thrust, overhead, horizontal, diagonal, backhand;
- Defense: guard loop, block hit, guard break, parry, riposte, dodge forward/back/left/right;
- Reactions: hit front/back/left/right, heavy stagger, knockdown, getup;
- Death A/B, execution;
- Chain: chain idle, swing, wrap, pull, choke, release (уникальные, keyframe/procedural).

**P2 — расширение:**
- Sword combo 4, running attack, jump attack, dodge attack, finisher;
- Shadow: manifest, arms, step, scout, shield, bind, drain;
- Item/Memory activation, throw, aim;
- Boss finishers, cinematic interactions.

### 9.5. Перечень для противников

| Противник | Клипы | Приоритет | Метод |
|---|---|---|---|
| Humanoid soldier (Barbarian placeholder) | idle, walk, run, alert, telegraph, attack 1/2, block, parry, hit front/back, stagger, death | P1 | mocap/retarget + cleanup |
| Larva | idle/writhe, telegraph, lunge, hit, death | P1 | procedural + 3–5 клипов |
| Mountain King | dormant, wake/roar, chase, telegraph swipe, sweep, stomp, grab, throw, hit, stagger, phase, death | P1/P2 | unique rig + keyframe/Cascadeur |
| Carapace scavenger (future) | idle, walk, claw, lunge, hit, death | P2 | unique rig/mocap |
| Archer (future) | idle, aim, draw, release, reload, hit, death | P2 | mocap |
| Horse | idle, walk, trot, run, hit, death | P2 | existing + 2 custom |

### 9.6. Где mocap, где keyframe, где procedural/IK

| Задача | Метод | Почему |
|---|---|---|
| Locomotion, NPC, interactions | mocap/retarget | быстро, правдоподобно, легко покрыть объём |
| Sword/knife attacks | mocap + cleanup | вес, инерция, contact; проще купить пак |
| Chain (garrote, swing, pull) | keyframe/procedural + constraints | нет готового mocap с цепью; нужен контроль контакта |
| Shadow arms/tendrils | procedural + VFX | не humanoid; IK/шейдеры |
| Mountain King | unique rig + keyframe/Cascadeur | анатомия не humanoid; mocap не подходит |
| Larva | procedural + 3–5 клипов | blob; Tween читается |
| Weapon grip / two-handed | IK + BoneAttachment3D | mocap не гарантирует хват |
| Foot contact | TwoBoneIK3D + foot lock | неровности, уклоны, лестницы |
| Hit reactions | mocap + direction data | сложно выдумать; нужна направленность |
| Cinematics | keyframe | контроль камеры/тайминга |

### 9.7. Синхронизация Animation ↔ Hitbox ↔ Damage

Рекомендуемая схема (без изменения текущих таймингов):

1. `AttackData` остаётся источником фаз: `windup_time`, `active_time`, `cooldown`.
2. `ActionRunner`/`CombatController` открывает/закрывает `MeleeAttack`; `MeleeAttack` остаётся единственным источником урона.
3. `AnimationProfile` (новый `.tres`) хранит для клипа: `contact_normalized`, `active_start_normalized`, `active_end_normalized`, `root_motion_mode`, `footsteps`.
4. `SunnyAnimator` играет клип со скоростью, при которой `contact_normalized * clip_length / speed = windup + active*0.5`; но **не обрезает клип** ради cooldown — вместо этого либо удлиняет recovery, либо добавляет tail-анимацию, либо ускоряет клип целиком (решение пользователя).
5. `MeleeAttack` использует `ShapeCast3D`/swept capsule от основания до кончика оружия; `BoneAttachment3D` на `hand_r`; проверка `weapon_tip` в active frames.
6. Method tracks/Animation events — только для звука, VFX, trail, footsteps; урон не через них.
7. Тесты: contact в окне; нет двойного попадания; hitbox не активен вне окна; weapon tip пересекает hurtbox; нет удара за спиной/через стену (line-of-sight).

---

## 10. Архитектура Animation Pipeline в Godot 4.7.2

### 10.1. Текущие ограничения

- `SunnyAnimator` ждёт один `AnimationPlayer` и имена клипов через export; это удобно и уже тестируется.
- `AnimationTree` нет; переходы в коде; нет blend space, слоёв, one-shot.
- Нет общей библиотеки; KayKit/POC/UAL разделены.
- Нет IK/weapon socket.
- Нет метода синхронизации attack clip ↔ hitbox, кроме `attack_contact_time`.

### 10.2. Целевая схема

```
Character (CharacterBody3D)
  Visual
    Model (GLB)
      Skeleton3D (GeneralSkeleton)
        BoneAttachment3D (hand_r) → WeaponRoot
        TwoBoneIK3D (legs) / LookAtModifier3D
    AnimationPlayer (one per model)
      libraries: core, combat, reactions, character, ...
    AnimationTree
      root: AnimationNodeStateMachine
        Locomotion (BlendSpace2D)
        CombatIdle
        Attack (OneShot)
        Guard (Blend2, upper-body filter)
        Hit (OneShot)
        Dodge (OneShot)
        Death
        Interaction (OneShot)
        Cinematic (external)
  Animator facade (SunnyAnimator API preserved)
  CombatController / ActionRunner
  MeleeAttack (authority for damage)
```

### 10.3. AnimationLibrary

| Библиотека | Содержимое | Кто использует |
|---|---|---|
| `humanoid_core` | idle, walk, run, sprint, strafe, turn, jump, fall, land, crouch | все humanoid |
| `humanoid_combat_unarmed` | jab, cross, hook, kick, grab, guard, dodge, hit | Sunny, NPC |
| `humanoid_combat_blade` | 1H/2H attacks, block, parry, riposte, finisher | Sunny/enemies |
| `humanoid_reactions` | hit front/back/left/right, stagger, knockdown, getup, death | все humanoid |
| `humanoid_interactions` | pick up, use, drink, eat, sit, lie, open, climb, carry, throw | все humanoid |
| `npc_civilian` | idle variants, talk, listen, gesture, work, fear | массовка |
| `npc_key` | unique overrides | ветеран, Шифти, Учёный, Герой, Ауро |
| `sunny` | `Idle_Relaxed`, уникальные | Sunny |
| `enemy_humanoid` | attack/reactions | солдаты |
| `enemy_larva` | procedural/3–5 | личинка |
| `enemy_tyrant` | unique | Горный Король |
| `horse` | 6 клипов | лошадь |

**Правила:**
- Один `AnimationPlayer` на модель; `AnimationTree` только ссылается на него.
- Общие библиотеки не копируют клипы; один `.glb`/`AnimationLibrary` на источник.
- Track paths должны указывать на unique `GeneralSkeleton`; иначе библиотека не разделяется.
- Не смешивать KayKit (41) и MPFB (53) в одной библиотеке.

### 10.4. State machine и переходы

- **Locomotion:** `AnimationNodeBlendSpace2D` по локальной скорости (x = strafe, y = forward/back) или `BlendSpace1D` + strafe layer. `sync_mode = Cyclic Mutable`, чтобы фазы шага совпадали.
- **Combat:** `AnimationNodeStateMachine`; `Attack` — `AnimationNodeOneShot` с `request`; `Guard` — `Blend2` с `BoneFilter` (upper body) поверх locomotion; `Hit` — OneShot; `Death` — At End.
- **Transitions:** xfade 0,1–0,2 с; attack entry 0,05–0,1; hit 0,05; death 0,1; использовать `Sync` для walk↔run, `At End` для death, `Immediate` только для hit/death.
- **Phase matching:** `AnimationNodeTimeSeek`/`TimeScale` для walk↔run; не сбрасывать фазу при смене скорости.
- **Interrupts:** attack cancel windows — данные, не хардкод; hit не прерывает active attack (как сейчас), но может прерывать recovery.
- **Публичный API:** `SunnyAnimator` сохраняет `update`, `set_guard`, `play_dodge`, `set_*_clip`, `state`; внутри переключается на `AnimationTree`. Тесты остаются.

### 10.5. Root motion policy

- **In-place — по умолчанию** для locomotion, dodge, attack: движение ведёт `CharacterBody3D`.
- **Root motion — только** для cinematic/finisher/особых действий; `root_motion_track` задаётся per-action; `AnimationMixer.get_root_motion_position/rotation` передаётся в контроллер.
- **Один владелец движения.** Нельзя одновременно двигать body и skeleton root.
- Для dodge: либо in-place + controller (предпочтительно для геймплея), либо root motion + controller выключает движение; не смешивать.
- Тест: суммарное смещение root + body не должно давать рывок/двойное перемещение.

### 10.6. IK и оружие

- **Foot IK:** `TwoBoneIK3D` (Godot 4.4+; в 4.7 есть) на цепочку thigh→calf→foot; target — `RayCast3D`/Marker под стопой; pole — колено вперёд; influence 0,7–1,0; отключать в прыжке/ролле.
- **LookAt:** `LookAtModifier3D` на neck/head; ограничить углы; использовать в диалогах/прицеливании.
- **Weapon:** `BoneAttachment3D` на `hand_r`; child `WeaponRoot`; для POC/P1 добавить `weapon_r` socket; калибровать offset/rotation по мешу. Для двуручного — левая рука через `TwoBoneIK3D` на grip.
- **Не использовать `SkeletonIK3D`** (deprecated); `TwoBoneIK3D`/`ChainIK3D` — актуальные классы 4.7 (проверено ClassDB).
- **Тест:** weapon tip в active frames; нет проникновения; хват не «плывёт» при повороте кисти.

### 10.7. События анимации

- glTF не несёт method tracks; после импорта их нет.
- Вариант A: `ClipEventMap` `.tres` с нормализованными временами (footstep, contact, trail, audio); `SunnyAnimator` читает и эмитит.
- Вариант B: post-import script добавляет `Animation.TYPE_METHOD` tracks в Godot; но reimport их теряет — нужно хранить в отдельном ресурсе и применять после импорта.
- **Правило:** урон/хитбокс — только `MeleeAttack`/`ActionRunner`; события — звук/VFX/трейл/шаги.

### 10.8. Миграция без переписывания

1. Оставить `SunnyAnimator` facade и его тесты.
2. Добавить `AnimationTree` как внутреннюю реализацию; старые методы делегируют.
3. Сначала Locomotion (BlendSpace + transitions), затем Combat (OneShot/Guard), затем Reactions.
4. Не менять `MeleeAttack`/`AttackData` тайминги; добавить `AnimationProfile` и использовать его для скорости/contact.
5. Добавить `BoneAttachment3D`/IK отдельными сценами; не менять коллизии/капсулу.
6. Каждый шаг — тест + визуальный кадр.

### 10.9. Производительность

- Один `AnimationTree` на персонажа; 20 NPC — 20 trees; LOD/VisibilityEnabler.
- Не использовать runtime retargeting; только import-time.
- Ограничить IK: foot IK только для игрока и ближних NPC; дальние — без IK.
- Бюджет: <1 мс на персонажа в `_physics_process`; общий animation budget <5 мс для 20 NPC (ориентир, требует Profiler).
- `AnimationTree` `active` только для видимых; `VisibilityEnabler3D`.

---

## 11. Animation Coverage Matrix

### 11.1. Матрица по категориям

| Категория | Обязательный набор | Кол-во | Сейчас | Лучший источник | Метод | Приоритет | Целевой grade |
|---|---|---:|---|---|---|---|---|
| Locomotion | idle, walk, run, sprint, strafe, turn, jump, fall, land, crouch | 18 | частично (6) | UAL 2 / Mixamo / MoCap Central | retarget | P0 | A/B |
| Combat unarmed | idle, jab, cross, hook, kick, knee, grab, guard, dodge, hit | 16 | 1 placeholder | UAL 2 / Mixamo / MoCap Central | retarget+cleanup | P1 | B/A |
| Combat blade | idle, draw, 3-hit, heavy, thrust, overhead, guard, block hit, parry, riposte, finisher | 22 | 1 placeholder | MoCap Online / Kubold / MoCap Central | retarget+cleanup | P1/P2 | A |
| Reactions | hit 4 directions, stagger, knockdown, getup, death A/B | 12 | 1 | MoCap Central / Mixamo / MoCap Online | retarget+cleanup | P1 | A |
| Chain | idle, swing, wrap, pull, choke, release | 6 | 0 | custom | keyframe/procedural | P1 | B |
| Shadow | manifest, arms, step, scout, shield, bind, drain | 10 | 0 | custom | procedural/VFX | P2 | B |
| Enemy humanoid | idle, walk, run, alert, telegraph, attack, block, hit, death | 12 | 5 | UAL/Mixamo/MoCap Central | retarget | P1 | B/A |
| Larva | idle, telegraph, lunge, hit, death | 5 | 4 procedural | custom | procedural+clips | P1 | B |
| Mountain King | dormant, roar, chase, swipe, sweep, stomp, grab, hit, phase, death | 12 | 0 skeletal | custom | keyframe/Cascadeur | P1/P2 | B |
| NPC civilian | idle x3, talk, listen, gesture, walk, run, sit, work, fear, death | 12 | 10 poses | Anderson Rohr / Rokoko / Mixamo | retarget | P1 | B |
| Key NPC | veteran, Shifty, Scholar, Hero, Auro | 10 | 0 unique | Mixamo/Anderson + custom | retarget+keyframe | P1 | B |
| Interactions | pick up, inspect, use, drink, eat, open, climb, sit, lie, carry, throw, lever, fire, bandage, shackles, bell | 16 | 3 | UAL/Anderson/Mixamo | retarget | P0 | B/A |
| Stealth | crouch, sneak, cover, peek, takedown, distraction, search, detect | 8 | 0 | Mixamo/UAL | retarget | P2 | B |
| Cinematic | restrained, collapse, crawl, wounded, carried, altar, wake, look, bell, death | 10 | 2 | Mixamo/UAL/custom | retarget/keyframe | P0/P1 | B |
| Horse | idle, walk, trot, run, hit, death | 6 | 4 | existing | existing+custom | P2 | B |

**Итого:** ~175 клипов в полной матрице; для M1 реально 25–30, для полной части 60–80. Остальное — переиспользование, процедурные и P2.

### 11.2. P0/P1 точный список для Санни

**P0 (вертикальный срез, без боя):**
1. Idle_Relaxed
2. Idle_Tired
3. Idle_Cold
4. Walk
5. Chained_Walk
6. Exhausted_Walk
7. Run
8. Sprint
9. Jump_Start
10. Jump_Loop
11. Jump_Land
12. Fall
13. Roll
14. Crouch_Idle
15. Crouch_Walk
16. Wounded_Crawl
17. Sit_Down
18. Sit_Idle
19. Stand_Up
20. Lie_Down
21. Lie_Idle
22. Get_Up
23. PickUp
24. Inspect
25. Use_Item
26. Drink
27. Eat
28. Bandage
29. Shackles_Open
30. Bell_Ring
31. Climb_Ledge
32. Squeeze
33. Swim (если нужен)
34. Carry_Idle
35. Carry_Walk
36. Throw
37. Pull_Lever
38. Light_Fire
39. Collapse
40. Wake_Up
41. Death_Cinematic
42. Look_At_Hand

**P1 (бой): полный список; MVP M1 — 25–30 клипов из него.**  
Core MVP: combat idle, 3 light, 1 heavy, 2 dodge, guard, block hit, 2 hit reactions, death, 3 chain — остальное добирается в M2.

43. Combat_Idle_Unarmed
44. Combat_Idle_Knife
45. Draw_Knife
46. Sheathe_Knife
47. Light_1
48. Light_2
49. Light_3
50. Heavy
51. Thrust
52. Overhead
53. Horizontal
54. Diagonal
55. Backhand
56. Guard_Loop
57. Block_Hit
58. Guard_Break
59. Parry
60. Riposte
61. Dodge_Fwd
62. Dodge_Back
63. Dodge_Left
64. Dodge_Right
65. Hit_Front
66. Hit_Back
67. Hit_Left
68. Hit_Right
69. Heavy_Stagger
70. Knockdown
71. Get_Up_Combat
72. Death_A
73. Death_B
74. Execution
75. Chain_Idle
76. Chain_Swing
77. Chain_Wrap
78. Chain_Pull
79. Chain_Choke
80. Chain_Release

**P2:** sword combo 4, running/jump/dodge attacks, shadow 10, item/Memory, boss finishers.

### 11.3. Фазирование

| Фаза | Клипы | Срок | Результат |
|---|---|---:|---|
| M1 | 25–30 | 6–10 недель | один враг, один набор, бой читается |
| M2 | +20–25 | +6–8 недель | цепь, shadow, key NPC |
| Full part | 60–80 | 3–5 месяцев | полный набор |

---

## 12. Рекомендация

### 12.1. Основной путь

**Free-first hybrid, без перестройки рига.**

1. **Стандартизировать персонажа:** оставить MPFB/P1 53-bone rig; KayKit оставить только как тестовый placeholder, не смешивать с POC. Добавить weapon socket и IK в Blender animation rig, а в Godot — `BoneAttachment3D`/`TwoBoneIK3D`.
2. **Сначала починить инфраструктуру, потом покупать контент:**
   - retarget-тест 3 клипов (walk, attack, hit) на Sunny;
   - `AnimationTree` с locomotion blend space и one-shot;
   - foot IK + калибровка скорости клипа по длине шага;
   - `AnimationProfile` с contact time для каждого клипа;
   - weapon attachment + swept hitbox.
3. **Бесплатные источники:**
   - UAL 2 Standard (42) — locomotion, jump, sword combos, knockback;
   - MoCap Central Sample (120+) — качественный mocap с пальцами и UE5 Manny;
   - MoCap Online T.C. Sword + Sampler — sword attacks/blocks;
   - Rokoko 263 — idle/walk/fight/weapon;
   - Mixamo — закрыть пробелы (но не sole source);
   - Anderson Rohr 134 — NPC/быт;
   - CMU — только для экспериментов/NPC, не для героя.
4. **Retarget:** Blender 5.1.1 + **Blender Retarget extension 5.2.0** (free, GPL, 5.0+). Rokoko plugin на 5.1 официально не готов; не строить на нём.
5. **Cleanup:** Blender NLA/Graph Editor; Cascadeur Indie — если физика/чистка становится бутылочным горлом. Free Cascadeur не использовать для commercial (CASC only, non-commercial).
6. **Godot:** один `AnimationPlayer` + `AnimationTree`; общие библиотеки; in-place locomotion; root motion только для cinematic; IK для стоп/оружия; события — `ClipEventMap`.
7. **Бой:** M1 — один враг, один набор; не 60–80 клипов. Сначала unarmed/knife/chain, потому что это канон Санни; sword combo — P2.
8. **Покупка только при подтверждённом M1:** один one-handed sword pack (Kubold ~$65) или MoCap Central Longsword (если двуручный враг); не покупать оба.

### 12.2. Что покупать в каком порядке

| Приоритет | Покупка | Зачем | Цена |
|---|---|---|---:|
| 1 | UAL 2 Source | 130+ клипов, root motion, sword combos, CC0 | $14.99 |
| 2 | Cascadeur Indie (год) | физика, AutoPosing, cleanup; retarget не нужен | $96/год |
| 3 | Kubold Sword Animset Pro | one-handed sword, 178 клипов, HIK; под Санни | ~$65 |
| 4 | Auto-Rig Pro Full | новые персонажи, Remap, Godot export | $50 |
| 5 | MoCap Central Longsword | если двуручный враг/босс | $89.99–139.99 |
| — | Custom mocap | только после M1 и плейтеста | $20k–50k |

**Не покупать сейчас:** MetaHuman/UE, Reallusion CC5, mocap suit, Motion Library подписку, Synty stylized packs, полный facial rig.

### 12.3. Последовательность внедрения

| Шаг | Действие | Срок | Критерий |
|---|---|---:|---|
| 0 | Этот аудит; зафиксировать текущие тайминги | — | документ принят |
| 1 | Retarget spike: 3 клипа на Sunny; замер foot slide/contact | 3–5 дней | slide <5 %, нет T-позы |
| 2 | AnimationTree facade: locomotion + one-shot; API сохранён | 1–2 недели | 38/38 тестов + новые |
| 3 | Foot IK + speed calibration; dodge/guard fixes | 1–2 недели | slide <5 %, dodge совпадает |
| 4 | Weapon socket + swept hitbox + AttackProfile | 1–2 недели | contact в окне, нет двойных попаданий |
| 5 | M1 combat: 1 enemy, 1 набор, 25–30 клипов | 2–4 недели | бой читается, hit reacts направленные |
| 6 | NPC/cinematic: shared libraries, Anderson/Rokoko | 2–3 недели | 10–20 NPC без T-позы |
| 7 | Chain/shadow/Mountain King | 3–6 недель | уникальные анимации, не placeholder |
| 8 | Polish/QA: 60–80 клипов, LOD, performance | ongoing | A/B grades, 1080p 60 |

### 12.4. Decision gates

- **G1:** retarget spike passes on Sunny (walk/attack/hit) without per-clip fixes.
- **G2:** AnimationTree + IK prototype passes 3 camera angles and existing tests.
- **G3:** attack timeline ↔ hitbox ↔ damage test passes without changing gameplay timings.
- **G4:** combat pack test (3 clips) passes before purchase.
- **G5:** license audit complete; every asset registered in `docs/ASSET_LICENSES.md`.

### 12.5. Открытые вопросы к пользователю

1. Какая модель считается основной для анимации: POC (`sunny_poc`) или P1 (`sunny_real`)? Сейчас кампания на POC, P1 не используется.
2. Бой M1 — приоритет до вертикального среза или арена остаётся тестовой?
3. Бюджет: $0, $100–250 или $500+?
4. Целевое оружие Санни: короткий меч + цепь (канон) или полноценный sword/shield?
5. Допустим ли переход на T-pose reference / пересборка P1, или POC A-pose фиксирован?
6. Есть ли доступ к Adobe ID (Mixamo), Rokoko, MoCap Online/MoCap Central для скачивания?
7. Нужна ли лицевая анимация/липсинк в этом этапе?
8. Кто делает cleanup: вы, аниматор или AI + вы?

### 12.6. Чего не делать

- Не массово ретаргетить 100 клипов без теста на Sunny.
- Не смешивать KayKit 41 и MPFB 53 в одном AnimationTree.
- Не использовать free Cascadeur для commercial (CASC only).
- Не использовать MoCap Online/ActorCore с AI-инструментами без permit/письменного согласия.
- Не строить 100-клиповый sword system, пока не закрыты цепь, взаимодействия и постановки.
- Не добавлять AnimationTree «везде» сразу; сначала facade + 8 состояний.
- Не менять тайминги `MeleeAttack` ради визуала; синхронизировать контент, а не ломать логику.
- Не покупать MetaHuman/UE/CC5 до подтверждения M1.

---

## 13. Источники

**Проект:**
- `docs/DECISIONS.md`, `docs/design/11_combat_system.md`, `docs/design/13_systems_architecture_audit.md`, `docs/production/s2_character_pipeline_plan.md`, `docs/art/art_direction.md`, `docs/art/style_gate_p0.md`, `docs/AI_HANDOFF_AFTER_S3_2.md`.
- Файлы: `scripts/player/sunny_animator.gd`, `scripts/combat/*.gd`, `scripts/player/sunny_controller.gd`, `scripts/player/fall_recovery.gd`, `scripts/slice/mannequin.gd`, `scenes/characters/*.tscn`, `assets/characters/**/*.glb.import`.

**Godot:**
- Retargeting 3D skeletons: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html
- Using AnimationTree: https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html
- AnimationMixer/root motion: https://docs.godotengine.org/en/stable/classes/class_animationmixer.html
- SkeletonIK3D (deprecated): https://docs.godotengine.org/en/stable/classes/class_skeletonik3d.html
- `TwoBoneIK3D` проверен через ClassDB 4.7.2.

**Blender:**
- Blender 5.1 release: https://www.blender.org/download/releases/5-1/
- Actions/slotted actions: https://docs.blender.org/manual/en/5.1/animation/actions.html
- NLA: https://docs.blender.org/manual/en/5.1/editors/nla/introduction.html
- Rigify: https://docs.blender.org/manual/en/5.1/addons/rigging/rigify/introduction.html

**Free libraries:**
- Quaternius UAL: https://quaternius.com/packs/universalanimationlibrary.html
- Quaternius UAL 2: https://quaternius.com/packs/universalanimationlibrary2.html ; https://quaternius.itch.io/universal-animation-library-2
- Mixamo: https://www.mixamo.com ; FAQ: https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html
- Rokoko free resources: https://www.rokoko.com/free-resources ; 263: https://www.rokoko.com/resources/download-263-rokoko-motion-capture-assets ; 10 weapon: https://www.rokoko.com/resources/motion-library-10-free-fight-and-weapon-animations
- MoCap Online free: https://mocaponline.com/pages/free-animations ; T.C. Sword: https://mocaponline.com/products/tc-sword ; license: https://mocaponline.com/pages/licensing
- MoCap Central free sample: https://mocapcentral.com/products/mocap-studio-series-sample-pack-free ; EULA: https://mocapcentral.com/pages/licensing
- ActorCore free: https://actorcore.reallusion.com/3d-motion/free ; EULA: https://actorcore.reallusion.com/eula
- CMU: https://mocap.cs.cmu.edu ; cgspeed BVH: https://sites.google.com/a/cgspeed.com/cgspeed/motion-capture/the-motionbuilder-friendly-bvh-conversion-release-of-cmus-motion-capture-database
- Anderson Rohr: https://andersonrohr.gumroad.com/ ; CG Channel: https://www.cgchannel.com/2026/09/download-130-free-fbx-mocap-moves-from-anderson-rohr
- Ultimate Animation Library: https://store.godotengine.org/asset/fabbio-mendoza/ultimate-animation-library
- KayKit: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0
- Kubold: https://www.kubold.com/store ; Fab listing: https://www.fab.com/listings/12783d2f-2bcf-4f3e-9a4a-d554cc3c579a

**Tools/prices:**
- Cascadeur: https://cascadeur.com/plans ; FAQ: https://cascadeur.com/help/faq
- Rokoko pricing: https://www.rokoko.com/pricing ; Vision: https://www.rokoko.com/products/vision ; Create: https://rokoko.com/products/studio/rokoko-create
- Rokoko Blender plugin: https://github.com/Rokoko/rokoko-studio-live-blender ; PR #141: https://github.com/Rokoko/rokoko-studio-live-blender/pull/141
- Blender Retarget: https://extensions.blender.org/add-ons/retarget/
- Auto-Rig Pro: https://superhivemarket.com/products/auto-rig-pro ; docs: https://www.lucky3d.fr/auto-rig-pro/doc/faq.html
- AccuRIG: https://actorcore.reallusion.com/auto-rig
- Kimodo: https://github.com/nv-tlabs/kimodo
- DeepMotion: https://www.deepmotion.com/pricing-animate3d ; terms: https://www.deepmotion.com/terms-of-use
- Plask: https://plask.ai/pricing ; terms: https://plask.ai/en-US/docs/100002 (commercial terms — NOT VERIFIED)
- Move AI: https://move.ai ; pricing docs: https://docs.move.ai/knowledge/move-one-pricing
- GVHMR: https://github.com/zju3dv/GVHMR

---

## Appendix A. Как измерялся foot slide

1. GLB распарсен напрямую; иерархия костей и rest transforms извлечены.
2. Для клипов UAL (`Walk_Loop`, `Jog_Fwd_Loop`, `Sprint_Loop`, `Roll`) и KayKit (`Walking_A`, `Running_A`, `Dodge_Backward`) сэмплированы мировые позиции стоп/пальцев ног на 60 Гц.
3. Stance определялся как кадры, где Y стопы/пальца в пределах 2,5–3 см от минимума; брался горизонтальный ход за контактный интервал.
4. `implied_speed = horizontal_travel / contact_time`.
5. Это приблизительная оценка (±20 %); она не заменяет замер в движке. Но порядок величины устойчив: UAL Walk ≈1,0 м/с, KayKit Walk ≈0,8 м/с, KayKit Run ≈3,5–4,6 м/с, UAL Sprint ≈8,8 м/с.
6. Текущий `speed_scale` в `SunnyAnimator` считается как `body_speed / walk_speed` или `body_speed / sprint_speed`, а не как `body_speed / authored_clip_speed`; поэтому на walk он равен 1,0 при скорости тела 4,0 м/с.

**Результат:** walk slide ≈4–5×; run slide ≈1,6–2×; sprint ≈0,85× (приемлемо); dodge mismatch ≈2,5 м по дистанции.

---

## Appendix B. Быстрый чек-лист перед покупкой/интеграцией анимационного пака

- [ ] Лицензия проверена на оригинальной странице, не у агрегатора.
- [ ] Commercial use разрешён для игр; нет revenue/user cap, который мы превысим.
- [ ] Нет запрета на AI retargeting/cleanup, если мы используем AI.
- [ ] Формат: FBX/GLB; скелет: UE5 Manny / Mixamo / HIK / UAL.
- [ ] Есть fingers; есть root motion/in-place вариант.
- [ ] 3 клипа протестированы на Sunny: walk, attack, hit.
- [ ] Нет foot slide >5 %, нет T-позы, нет twist плеча/локтя.
- [ ] Weapon grip проверен; при необходимости — IK.
- [ ] Клип не обрезается под наш cooldown; contact time пересчитан.
- [ ] Ассет зарегистрирован в `docs/ASSET_LICENSES.md` до импорта в `assets/`.
- [ ] После импорта: `godot --headless --path . --import` без ошибок; targeted GUT; визуальный кадр.

---

**Итог:** проект уже имеет жизнеспособный 53-bone pipeline и хорошую базу UAL, но текущий анимационный слой не готов к production: нет AnimationTree, IK, weapon socket, калибровки скорости и синхронизации клипа с хитбоксом. Бесплатные библиотеки позволяют собрать B-прототип и A-уровень NPC/locomotion; для A-уровня боя нужен один платный mocap-пак или ручная работа. Начинать надо не с покупки 100 клипов, а с retarget-теста, AnimationTree, foot IK и weapon socket — иначе любой новый контент будет выглядеть хуже, чем есть.

---

## Статус реализации (2026-11-02)

См. `docs/art/animation_pipeline_status_2026-11-02.md`: установлен Blender Retarget 5.2.0,
импортированы 7 Rokoko-клипов, созданы `rokoko_library.tres`, `scenes/dev/animation_lab.tscn`,
weapon socket, per-attack `contact_time` и исправлен respawn в idle. Targeted GUT: 37/37 passed,
167 asserts. Полный GUT: первый прогон 510/536, 26 failing; после фикса parse-регресса
повторный прогон упал signal 11 в pre-existing campaign flow и не завершился. Runtime —
NOT TESTED. **Rokoko-клипы остаются staging:** визуальная проверка выявила неверную
ориентацию/высоту после Godot-ретargета, нужен Blender-бейк на P1.
