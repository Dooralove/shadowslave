# Character & Animation — Stage 6 deep completeness audit

**Domain:** A06 — Character & Animation  
**Branch:** `demo/characters`  
**Previous commits:** `6ac4aba` (implementation), `9620ac9` (Stage 5 handoff)  
**Stage 6 status:** deep audit complete; additional quality fixes applied; full GUT green.  
**Push:** none.

---

## 1. Что проверено

Сравнены:

- исходный baseline `ee97325` и `docs/demo_sprint/audits/characters_animation.md`;
- MASTER_AUDIT / MASTER_PLAN / FILE_OWNERSHIP / AGENT_TASKS;
- все A06-owned файлы после Stage 5;
- runtime-поведение через GUT, сцены, A06-валидаторы и Forward+ captures;
- чужие зоны только на предмет интеграционных разрывов (без редактирования).

Проверены runtime, парсинг, сцены, зависимости, ресурсы, сигналы, сохранения, визуальные ошибки, состояния и совместимость с Godot 4.7.2.

---

## 2. Исправлено в Stage 6

| Проблема | Исправление |
|---|---|
| v3/Nightmare guard выглядел как idle | `SunnyV3Model` создаёт `GuardPoseModifier` и отдаёт его через `get_guard_pose()`; offsets переведены на Mixamo-кости `RightArm`/`RightForeArm` |
| Дублирующий LOD-компонент у Hero в `Mannequin` | `Mannequin` теперь находит существующий `LodVisibility` и переиспользует его вместо второго компонента |
| Меч/аксессуары могли скрываться LOD-компонентом | `CharacterLodVisibility` пропускает meshes в группе `lod_ignore`; меч и placeholder-аксессуары добавлены в неё |
| Walk loop seam по старому аудиту 5–7 см | измерен заново: `WalkClean` 0.8–1.8 s даёт **0.66 см / 0.36 см**; текущий диапазон оставлен |
| Нет проверки guard pose | добавлен `tools/anim/sunny_guard_validate.gd` |
| Нет проверки LOD-дубликата Hero | `lod_validate.gd` проверяет `hero_mannequin components=1` |
| Нет измерения walk seam | добавлен `tools/anim/walk_seam_measure.gd` |

Визуально проверено: v3/Nightmare guard — руки подняты в защитную позицию; Nightmare armed idle — меч в правой руке; LOD0/1/2 — переключение без пропажи модели.

---

## 3. Оставшиеся проблемы

### 3.1. Требуют другого владельца

| Проблема | Владелец | Действие |
|---|---|---|
| P09 M1 содержит `Julius` и ставит `academy_julius_seen` | A03/A04 | убрать из M1 или закрыть M2-флагом |
| P09 Kasper и crowd отсутствуют | A03 | добавить `kasper.tscn` и `sleeper_crowd.tscn` по POI-P09-10/11 |
| `InductionMedic` стоит на подиуме Rock (POI-P09-09) | A03 | переименовать в `Rock`; A06 уберёт compatibility alias |
| P06 Jet yaw 0, игрок спавнится севернее | A03 | поставить yaw `PI`, чтобы Jett смотрела на игрока |
| A06-10 enemy clips не подключены | A05 | добавить `authored/Hit`/`authored/Death` в `CarapaceAnimator`/`LarvaAnimator` |
| A06-15 blade hitbox | A05 | перенести hitbox на клинок; A06 даёт socket |
| A06-11 `sleep`/`equip`/`shroud` не вызываются | A03/A04 | использовать `CinematicActor.play()` в капсуле/B01 |
| `scripts/characters/**` ownership | A00 | закрепить за A06 или перенести helpers |
| LOD0 budget v3/Nightmare/Hero | A00 | exception или decimation |
| Финал Jett/Nephis/Cassia/Julius/Theo | A00/внешняя генерация | Hyper3D/credits |

### 3.2. Осталось в A06

| Проблема | Статус |
|---|---|
| **A06-16 turn-in-place / foot IK** | не реализовано; контроллер резко поворачивает, foot lock отсутствует |
| **Sword combo/parry/riposte для v3/Nightmare** | у v3 только `HumanSpBoxing`; combo есть только у KayKit arena Sunny |
| **Directional hit reactions** | один `HumanSpHeadHit`; нет chest/heavy/left/right |
| **Special ability animation** | `Spell_Simple_Shoot`/`HumanSpBoxing` — заглушка; VFX за A09 |
| **Facial/finger/ragdoll** | P2/P3; не реализовано |
| **NPC gestures wave/argue** | `Mannequin` использует `Idle_Talking`/`Interact`; настоящих wave/argue клипов нет |
| **Nightmare armed attack** | меч виден, но клип остаётся `HumanSpBoxing` (punch); нужен sword clip или unarmed-only контракт |
| **v3 guard** | процедурная поза работает, но это не authored guard clip; для финала нужен клип |
| **Foot slide в реальном прохождении** | не измерен; seam чистый, но игровой slide — **NOT TESTED** |
| **1080p/60 FPS** | **NOT TESTED**; LOD0 всё ещё тяжёлый |
| **Manual playthrough** | **NOT TESTED** |

### 3.3. Граничные случаи

- `combo_window=1.2` рассчитан на armed cooldown 0.95; если A05 изменит cooldown, окно нужно синхронизировать.
- `dodge_hold_time=0.8` совпадает с `CombatSettings.dodge_duration`; при изменении настроек A05 должен обновить hold.
- `Mannequin` context profiles зависят от имён узлов/`npc_id`; A03 rename должен сохранять canonical names.
- `InductionMedic -> Rock` — временный alias; после rename его нужно удалить.
- `lod_ignore` — новая группа; A05/A03 не должны удалять её с меча/аксессуаров.
- `SunnyV3Model.get_guard_pose()` возвращает `Node`; `SunnyAnimator` проверяет метод, а не тип.
- `SunnyV3Model` weapon socket ищет `Skeleton3D`/`GeneralSkeleton`; при смене рига нужен новый путь.

---

## 4. Проверки

### 4.1. Full GUT

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Результат после Stage 6 изменений:

- **636/636 passed**
- 81 script
- 7,336 asserts
- 305.2 s
- 98 orphan nodes в UI-тесте — warnings, не failures.

### 4.2. A06 checks

| Check | Result |
|---|---|
| `tools/anim/sunny_guard_validate.gd` | failed=0; v3 + Nightmare guard active/inactive |
| `tools/anim/walk_seam_measure.gd` | 0.8–1.8 s: L 0.66 cm, R 0.36 cm |
| `tools/anim/lod_validate.gd` | failed=0; hero mannequin components=1 |
| `tools/anim/nightmare_validate.gd` | failed=0; clips/LOD/actions/weapon socket |
| `tools/anim/location_npc_validate.gd` | failed=0; P06/P07/P08/P09/Z08 profiles |
| `tools/anim/sunny_combo_validate.gd` | failed=0; combo chain + reset |
| `tools/anim/sunny_dodge_validate.gd` | failed=0; 0.4 s clip held to 0.8 s |
| `tools/anim/enemy_clip_validate.gd` | failed=0; 3 libraries |
| `tools/anim/npc_validate.gd` | failed=0; 6 prefabs + crowd |

### 4.3. Captures

- `%TEMP%\opencode\a06_char_capture_stage6e` — v3/Nightmare guard.
- `%TEMP%\opencode\a06_char_capture_stage4b` — Nightmare armed sword.
- `%TEMP%\opencode\a06_location_npc_shots2` — P06/P09/Z08 profiles.
- `%TEMP%\opencode\a06_lod_stage6` — LOD0/1/2.
- `%TEMP%\opencode\a06_combo_shots` — combo poses.

---

## 5. Итог для TD

- Stage 6 fixes are in the worktree; full suite is green.
- A06-owned gameplay now has: NPC context profiles, smooth NPC transitions, LODs, v3/Nightmare guard pose, Nightmare weapon socket, arena combo, dodge hold, enemy clip assets.
- The remaining M1 blockers are outside A06: A03 Kasper/crowd/Julius/P06 yaw, A05 enemy clip/hitbox integration, A00 LOD0/ownership/final-cast decisions.
- A06-16 (turn/foot IK), authored v3 sword/parry, facial/finger/ragdoll, NPC wave/argue, and special ability clips remain future work.
- No push and no foreign files edited.

Exact cross-agent changes: `docs/demo_sprint/implementation/a06_cross_agent_requests.md`.
