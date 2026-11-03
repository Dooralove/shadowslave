# Enemy follow-up: Mountain King p3, larva LOD, carapace scavenger

**Дата:** 2026-11-02  
**Статус:** follow-up к `docs/art/enemy_model_audit_2026-11-02.md`. Три задачи выполнены: усилены короткие руки и морда Горного Короля, сделаны LOD для личинки, тестовый Barbarian в арене заменён на канонического карапакса с отдельным AI.  
**Проверки:** импорт Godot exit 0; профильные тесты **92/92, 1381 assert**. Полный GUT и ручной playthrough — **NOT TESTED**.

---

## 1. Горный Король p3

**Файл:** `assets/characters/p1/models/mountain_king_p3.glb`  
**Сцена:** `scenes/characters/mountain_king.tscn` (p3; p1/p2 остаются fallback).  
**Скрипт:** `assets/characters/p1/source/upgrade_mountain_king_v3.py`.

Что изменено поверх p2:

- **Короткие руки** выведены из шерсти: верхние/предплечья/кисти смещены вперёд и наружу с плавным falloff по весам, чтобы не разорвать плечевой стык. Теперь четыре руки читаются в силуэте.
- **Морда:** добавлены надбровные валики, скулы, мостик морды, верхняя/нижняя губа, подбородок, углы челюсти и пара коротких костяных клыков; глаза/пасть/зубы p2 сохранены.
- **Грива:** 180 тёмных кустиков вокруг затылка и боков головы, фронт лица оставлен открытым.
- **Риг/клипы:** 25 костей и 5 клипов (`Idle`, `Walk`, `Telegraph`, `Attack`, `Death`) без изменений.
- **LOD:** LOD0 46 148 tri, LOD1 21 228, LOD2 8 267; 3 меша, 6 материалов.

**Канон:** 4+ м, сутулый торс, две короткие ноги, четыре руки (две длинные с когтями, две короткие), пять млечных глаз, пасть с зубами, жёлто-серая шерсть. Короткие руки и морда теперь читаются заметно лучше; грива усиливает «зверя», не добавляя брони или оружия.

**Ограничение:** морда всё ещё процедурная, не финальный скульпт; грива — геометрические кустики, не fur cards. Для финала нужен отдельный fur/face-пас.

**Превью:** `docs/art/previews/enemies/mountain_king_p3_front.png`, `..._head.png`, `..._ambush.png`.

---

## 2. LOD для личинки

**Файл:** `assets/characters/enemies/larva/larva_corpse_lod.glb`  
**Сцена:** `scenes/locations/caravan_site/larva.tscn` (LOD-версия + `CharacterLodVisibility`).  
**Скрипт:** `assets/characters/enemies/larva/source/make_larva_lods.py`.

- LOD0 **28 785 tri**, LOD1 **14 391**, LOD2 **6 332**.
- Тот же 25-костный риг, тот же клип `Idle`; все три меша используют общий скелет.
- `LodVisibility`: LOD1 с 8 м, LOD2 с 16 м.
- `larva_corpse.glb` (без LOD) оставлен fallback; `larva.gd` по-прежнему запускает `Idle`.
- Текстуры альбедо/normal/roughness общие для всех LOD.

**Проверка:** `inspect_asset` видит три меша `LarvaBody`, `LarvaBody_LOD1`, `LarvaBody_LOD2`, 25 костей, `Idle`; `test_larva_enemy` 5/5. Runtime-проверка LOD: вблизи виден `LarvaBody`, на 20 м — `LarvaBody_LOD2`, промежуточные LOD1/2 скрываются корректно.

---

## 3. Карапакс-падальщик вместо Barbarian

**Модель:** `assets/characters/enemies/carapace/carapace_scavenger.glb`  
**Сборщик:** `assets/characters/enemies/carapace/source/build_carapace_scavenger.py`  
**Сцена:** `scenes/enemies/carapace_enemy.tscn`  
**AI:** `scripts/combat/carapace_enemy.gd`  
**Аниматор:** `scripts/combat/carapace_animator.gd`  
**Данные:** `resources/combat/enemies/carapace_scavenger.tres`, `resources/combat/attacks/carapace_claw.tres`.

### Модель

- Крабовидный панцирь 3,1 × 2,4 м, высота ~1,1 м; 6 сегментных ног, 2 большие клешни, костяные шипы по панцирю и краю, усики/мандибулы, без глаз.
- Тёмно-красный хитин, более светлые пластины, кость, тёмная пасть.
- 31 кость: Root, Body, Head, две мандибулы, две цепи клешней (upper/fore/claw/tip), 6 ног (upper/lower/foot).
- 5 клипов: `Idle`, `Walk`, `Telegraph`, `Attack`, `Death`.
- LOD0 **5 940 tri**, LOD1 **2 726**, LOD2 **1 034**.
- Клешни имеют раздельные верхнюю/нижнюю «челюсти»; `ClawTip` открывает нижнюю.

### Отдельный AI

`CarapaceEnemy` — не наследник `TestEnemy`. Свои решения и движение:

- **Scuttle:** в CHASE к прямому направлению добавляется боковая синусоида (`scuttle_strength`/`scuttle_frequency`), поэтому карапакс идёт «крабьим» зигзагом, а не по прямой.
- **Slow turn:** `turn_speed = 4.2` вместо 8 у тестового врага.
- **Claw snap:** TELEGRAPH 0.85 с, ATTACK 0.25 с с коротким рывком вперёд (`lunge_speed`, `lunge_time`), RECOVERY 1.05 с.
- **Stats:** 95 HP, 18 урона, 32 guard damage, cooldown 1.45 с.
- **Слабая точка:** красное сочленение на спине, отдельный `InspectableData` `carapace_weak_spot.tres` (без larva-флагов).
- **Смерть:** отключает атаку, collision_layer = 0, играет `Death`, остаётся телом.

### Интеграция

- `scenes/levels/combat_arena.tscn` теперь инстансит `carapace_enemy.tscn` вместо `test_enemy.tscn`; узел называется `TestEnemy` для совместимости с HUD/тестами.
- `scripts/world/combat_arena.gd` больше не типизирован как `TestEnemy`: работает с общим контрактом `health`/HUD, поэтому арена принимает и `LarvaEnemy`, и `CarapaceEnemy`.
- `tests/test_combat_arena.gd` обновлён на `CarapaceEnemy`.
- `test_test_enemy.tscn`/`Barbarian.glb` сохранены для старых тестов и как fallback; в боевой арене больше не используются.

### Канон

Карапакс-падальщик: крабовидный панцирь, клешни, сегментные ноги, 2,5–3,5 м. Модель не добавляет лицо, глаза, человеческие черты, броню или оружие. Это не «краб-воин» из Sketchfab, а именно зверь-падальщик.

### Ограничения

- Модель процедурная и стилизованная; это не финальный скульпт. При близком кадре нужны нормал-карты хитина и более сложные пластины.
- Анимации процедурные (покачивание, скелетный scuttle, щелчок клешнёй); foot contact/IK не выверены.
- Слабые точки/хитбоксы — игровая адаптация, не точный канон.

**Превью:** `docs/art/previews/enemies/carapace_scavenger_front.png`, `carapace_attack.png`, `carapace_arena_godot.png`.

---

## 4. Проверки

| Проверка | Результат |
|---|---|
| `godot --headless --path . --import` | exit 0; p3, larva LOD и carapace импортированы |
| `test_mountain_king` | 11/11 |
| `test_ambush_site` | 16/16 |
| `test_caravan_site` | 7/7 |
| `test_larva_enemy` | 5/5 |
| `test_carapace_enemy` | 5/5, 24 assert |
| `test_combat_arena` | 6/6 |
| `test_slice_locations` | 8/8 |
| `test_pilgrim_path` | 10/10 |
| `test_caravan_march` | 7/7 |
| `test_shifty_symptoms` | 5/5 |
| `test_act1_rework` | 9/9 |
| `test_full_route` | 3/3 |
| **Суммарно** | **92/92, 1381 assert** |
| Полный GUT | **NOT TESTED** |
| Ручной бой / scuttle / клешня | **NOT TESTED** |
| 1080p/60 FPS | **NOT TESTED** |

---

## 5. Файлы

**Новые:**
- `assets/characters/p1/models/mountain_king_p3.glb`
- `assets/characters/p1/source/upgrade_mountain_king_v3.py`
- `assets/characters/enemies/larva/larva_corpse_lod.glb`
- `assets/characters/enemies/larva/source/make_larva_lods.py`
- `assets/characters/enemies/carapace/carapace_scavenger.glb`
- `assets/characters/enemies/carapace/source/build_carapace_scavenger.py`
- `scenes/enemies/carapace_enemy.tscn`
- `scripts/combat/carapace_enemy.gd`
- `scripts/combat/carapace_animator.gd`
- `resources/combat/enemies/carapace_scavenger.tres`
- `resources/combat/attacks/carapace_claw.tres`
- `resources/inspect/carapace_weak_spot.tres`
- `tests/test_carapace_enemy.gd`
- `docs/art/previews/enemies/mountain_king_p3_*.png`
- `docs/art/previews/enemies/carapace_*.png`

**Изменены:**
- `scenes/characters/mountain_king.tscn` — p3.
- `scenes/locations/caravan_site/larva.tscn` — LOD-версия + `LodVisibility`.
- `scenes/levels/combat_arena.tscn` — carapace вместо Barbarian.
- `scripts/world/combat_arena.gd` — общий контракт `health`.
- `tests/test_combat_arena.gd` — `CarapaceEnemy`.
- `docs/art/p1_characters.md`, `docs/DECISIONS.md`, `docs/ASSET_LICENSES.md`.

**Не удалено:** `mountain_king_p1/p2`, `larva_corpse.glb`, `Barbarian.glb`, `test_enemy.tscn`, старые тесты.

---

## 6. Лицензии

Все три ассета — собственные/производные проекта:

- Mountain King p3 — производная p1/p2, проект;
- larva LOD — производная CC BY 4.0 модели Purple.Point; атрибуция уже в `docs/ASSET_LICENSES.md`;
- carapace — собственная процедурная геометрия и риг, без внешних моделей/текстур.

Новых строк лицензий не требуется.
