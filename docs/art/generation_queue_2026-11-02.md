# Generation queue — missing / replacement characters and monsters

**Дата:** 2026-11-02  
**Назначение:** список моделей, которые нужно сгенерировать в Hyper3D web UI, с готовыми промптами и именами файлов.  
**Куда складывать:** `incoming_models/` (папка исключена из импорта Godot через `.gdignore`).  
**Статус API:** Hyper3D API на тарифе Creator возвращает `API_NO_ACTIVE_SUBSCRIPTION`; web UI использовать можно.  \
**Canon update 2026-11-02:** старые промпты для Carapace Scavenger/Centurion/Blood Flower/Mountain King/Hero исправлены в `docs/art/canon_asset_bible_2026-11-02.md`. Использовать в первую очередь её, а не начальные блоки ниже.

---

## 0. Как генерировать

- Один объект = один `.glb`, без сцены, пола, базы, фона и второго персонажа.
- Формат: **GLB**, PBR-текстуры встроены.
- Гуманоиды: **A-pose**, полный рост, руки примерно на 35° от корпуса, ноги на ширине плеч, нейтральное лицо.
- Монстры: нейтральная стойка, все конечности видны, без подставки.
- Оружие — только закреплённое на теле (за спиной/на поясе), **не в руке**, иначе сложно риггить.
- Если получился T-pose — тоже годится, но A-pose лучше.
- Имя файла — ровно из заголовка. Варианты: `_alt1`, `_alt2`.
- Плохие генерации — в `incoming_models/_rejected/`, не удаляй.
- Не генерируй модели из раздела «уже есть»: они не пропали, их нужно оптимизировать/интегрировать, а не дублировать.

**Стиль (для всех):** реалистичное тёмное фэнтези, grounded anatomy, PBR, приглушённые цвета, без мультяшности, без базы и фона. Для персонажей — лицо и кисти с нормальной анатомией, одежда сидит по телу, без парящих деталей.

---

## 1. Аудит локаций: чего не хватает

| Локация | Персонажи / монстры сейчас | Чего не хватает | Приоритет |
|---|---|---|---|
| L01 Парк | Sunny real, mass_male/female | Замена Sunny real; массовка — опционально | P0/P2 |
| L02 Лобби | police_desk, police_guard, mass_police | Замена ключевой полиции — опционально | P1 |
| L03 Изолятор | police_desk, police_guard | То же | P1 |
| L05 Видение горы | Hero, white horse placeholder, caravan, Mountain King p3 | Hero, horse, Mountain King — заменить | P0 |
| L06 Дорога каравана | Hero, Veteran, Shifty, Scholar, BroadSlave, солдаты, кони | Замена Hero/Veteran/Shifty/Scholar/BroadSlave/horse | P0 |
| L07 Стоянка | То же + Larva (есть), Mountain King | Замена ключевых NPC; Larva не генерировать | P0 |
| L08–L13 Тропа | Hero, Shifty, Scholar, Veteran, Mountain King | Те же замены; новых типов нет | P0 |
| L14 Святилище | Mountain King (сцена), без новых NPC | Новых персонажей нет | — |
| Forgotten Shore, Z01–Z18 | Sunny, carapace placeholders, коралловый кит (60 GLB) | Carapace Scavenger/Centurion, Centipede, Worm Knot, Blood Flower; hero-туша и скелет | P1 |
| Black Sea / tide_descent | статуя Stone Knight (найдена), коралл | Статуя есть; нужна адаптация/оптимизация, не генерация | — |
| Soul Sea | 63 GLB кита, статичные тени | Новых персонажей нет; rigged-тени для спарринга — позже | — |
| Пролог | Sunny, полиция, массовка | Полиция/массовка — опционально | P2 |

**Что уже есть и не требует генерации:**

- `Larva` — `larva_corpse_lod.glb`, 3 LOD, PBR; не генерировать заново.
- `Mountain King p3` — процедурный fallback; заменить сгенерированной моделью, но не удалять до приёмки.
- `Carapace Scavenger` — процедурный fallback; заменить.
- `statue_knight` — найденный Stone Knight; нужна оптимизация, не новая генерация.
- Коралловый кит Лабиринта — 60 GLB; нужна интеграция, не генерация.
- Soul Sea kit — 63 GLB; нужна интеграция/оптимизация, не генерация.
- Парк, лобби, изолятор, горный кит — пропсы уже собраны.
- `Nephis`, `Cassia` — в сцене только маркеры, текущего геймплея нет; **не генерировать сейчас**.
- `Echo` (Z14) — не определён как персонаж/эхо; **не генерировать до дизайн-решения**.

---

## 2. P0 — главный каст и Горный Король

### 2.1. `sunny_real_v2.glb` — Санни, реальный мир

**Роль:** главный герой, пролог/реальный мир. Заменяет `sunny_real.glb`.

```text
Sunny, a 16-year-old extremely thin pale boy, 1.66 m tall, gaunt face with dark circles under tired dark eyes, messy short black hair, small nose, wary neutral expression, skinny shoulders and arms. Wearing a faded off-white knitted sweater, dark worn trousers and scuffed sneakers. Full body, relaxed A-pose, arms about 35 degrees from the torso, palms facing inward, feet shoulder-width apart. Realistic contemporary dark fantasy, grounded anatomy, detailed face and hands, PBR materials, muted desaturated colors, single isolated character, no base, no background, no extra objects, no text.
```

### 2.2. `sunny_nightmare_v2.glb` — Санни, Кошмар

**Роль:** главный герой в Первом Кошмаре. Заменяет `sunny_nightmare.glb`.

```text
Sunny, the same 16-year-old extremely thin pale boy, 1.66 m tall, gaunt face with dark circles under tired dark eyes, messy short black hair, wary exhausted expression. Wearing a ragged ancient slave tunic of coarse brown cloth, rough wool trousers, bare dirty feet, faint red marks from shackles on wrists and ankles, no armor, no weapons. Full body, relaxed A-pose, arms about 35 degrees from torso, feet shoulder-width apart. Realistic dark fantasy, grounded anatomy, detailed face and hands, PBR materials, muted desaturated colors, single isolated character, no base, no background, no extra objects, no text.
```

### 2.3. `hero_auro_v3.glb` — Герой Ауро

**Роль:** главный NPC/антагонист каравана. Заменяет `hero_auro` и отклонённый `hero_auro_v2`.

```text
Hero Auro, a handsome young male soldier about 22 years old, 1.82 m tall, soft noble features, clean-shaven, short dark brown hair, calm dignified expression, upright noble posture. Wearing a simple ancient leather cuirass fitted to the torso over a dark wool tunic, leather bracers and sturdy leather boots, a short sword sheathed at his hip, a spear strapped diagonally across his back, no helmet, no weapon in his hands. Full body, relaxed A-pose, arms about 35 degrees from torso, feet shoulder-width apart. Realistic dark fantasy, grounded anatomy, detailed face and hands, PBR materials, muted leather and dark cloth colors, clothing fitted to the body with no floating armor pieces, single isolated character, no base, no background, no extra objects, no text.
```

### 2.4. `shifty_v3.glb` — Шифти

**Роль:** ключевой NPC каравана. Заменяет `shifty` и отклонённый `shifty_v2`.

```text
Shifty, a thin wiry male slave about 35 years old, 1.75 m tall, sharp suspicious eyes, unshaven stubble, messy dark hair, nervous guarded expression. Wearing a ragged brown slave tunic with a rough rope belt, patched wool trousers and worn leather boots, no armor, no weapons. Full body, relaxed A-pose, arms about 35 degrees from torso, feet shoulder-width apart. Realistic dark fantasy, grounded anatomy, detailed face and hands, PBR materials, dirty muted earth tones, single isolated character, no base, no background, no extra objects, no text.
```

### 2.5. `scholar_v2.glb` — Учёный

**Роль:** ключевой NPC каравана. Заменяет `scholar.glb`.

```text
The Scholar, a tall gaunt man about 40 years old, 1.86 m tall, strangely handsome tired face, short graying dark hair, rectangular glasses, calm intelligent expression. Wearing a worn dark scholar's coat and trousers, simple leather shoes, no armor, no weapons, no cloak. Full body, relaxed A-pose, arms about 35 degrees from torso, feet shoulder-width apart. Realistic dark fantasy, grounded anatomy, detailed face and hands, PBR materials, desaturated charcoal and brown palette, clothing fitted to the body, single isolated character, no base, no background, no extra objects, no text.
```

### 2.6. `veteran_v3.glb` — Старый ветеран

**Роль:** офицер каравана. Заменяет `veteran` и отклонённый `veteran_v2`.

```text
The Old Veteran, a heavy weathered male officer about 55 years old, 1.80 m tall, short gray hair, deep-set angry eyes, strong jaw with short stubble, broad build. Wearing a simple ancient leather cuirass with a dark fur mantle over the shoulders, thick leather boots, a coiled whip hanging at his right hip, a sheathed sword at his left hip, no helmet, no weapon in his hands. Full body, relaxed A-pose, arms about 35 degrees from torso, feet shoulder-width apart. Realistic dark fantasy, grounded anatomy, detailed face and hands, PBR materials, dark leather and gray fur, clothing fitted to the body with no floating armor pieces, single isolated character, no base, no background, no extra objects, no text.
```

### 2.7. `broad_slave_v1.glb` — Широкоплечий раб

**Роль:** канонический BroadSlave (отдельный NPC; сейчас mass_slave). Не путать с Hero.

```text
A broad-shouldered male slave about 35 years old, 1.85 m tall, strong heavy build, shaved head with short dark stubble, weathered blunt face, tired resentful expression. Wearing a coarse ragged brown slave tunic, simple rope belt, patched wool trousers, bare dirty feet, no armor, no weapons. Full body, relaxed A-pose, arms about 35 degrees from torso, feet shoulder-width apart. Realistic dark fantasy, grounded anatomy, detailed face and hands, PBR materials, dirty muted earth tones, single isolated character, no base, no background, no extra objects, no text.
```

### 2.8. `white_horse_v1.glb` — Белый конь Героя

**Роль:** конь Ауро; сейчас low-poly placeholder `horse.glb`. Тёмный конь Ветерана делается перекраской этого же ассета, отдельная генерация не нужна.

```text
A beautiful elegant white horse, 1.65 m at the withers, long clean white mane and tail, calm proud expression, realistic horse anatomy. Wearing a simple dark brown leather saddle and bridle, no armor, no rider, no banners. Standing in a neutral side-three-quarter pose, all four legs visible, head slightly raised. Realistic dark fantasy, detailed coat and leather, PBR materials, single isolated animal, no base, no background, no extra objects, no text.
```

### 2.9. `mountain_king_gen_v1.glb` — Горный Король

**Роль:** главный монстр Первого Кошмара. Заменяет процедурный `mountain_king_p3.glb` (p3 остаётся fallback).

```text
The Mountain King, a colossal blind nightmare tyrant at least 4.5 m tall, emaciated hunched torso, two short stumpy legs, four arms: two disproportionately long multi-jointed arms ending in sword-length bone claws, and two shorter arms ending in almost human fingers. Yellowish-gray matted ragged fur thick enough to stop arrows, five milky-white blind eyes in a row, a wide half-open maw crowded with razor-sharp teeth, viscous drool on the chin, bone horns and jagged bone growths, strange worm-like shapes moving under the skin. No armor, no weapons, no base. Full body, neutral hunched standing pose, all four arms visible and slightly spread for rigging, terrifying but anatomically grounded. Realistic dark fantasy horror, PBR fur and bone, muted yellow-gray and dark flesh, single isolated creature, no background, no extra objects, no text.
```

---

## 3. P1 — монстры Forgotten Shore

**Как использовать варианты:** `WoundedScavenger`, `TwoCarapaces` и `Packs` — это не отдельные виды, а те же carapace-модели с раной/масштабом/покраской. Сначала один базовый `carapace_scavenger_gen_a`; вариант B — только если нужен другой силуэт. Centipede/Worm/Blood Flower также можно размножать масштабом и палитрой.

### 3.1. `carapace_scavenger_gen_a.glb` — Карапакс-падальщик

**Роль:** базовый враг Лабиринта/Арены. Заменяет процедурный `carapace_scavenger.glb`.

```text
A giant crab-like nightmare scavenger, about 3 m wide and 1.2 m tall, dark crimson chitin carapace with overlapping segmented plates, bone spikes along the shell rim, six segmented legs, two large pincers with serrated jaws, an eyeless armored head with mandibles. Low aggressive stance, all six legs and both pincers visible, no base, no human face, no eyes. Realistic dark fantasy creature, wet layered chitin, bone and dark red palette, PBR materials, single isolated creature, no background, no extra objects, no text.
```

### 3.2. `carapace_scavenger_gen_b.glb` — вариант B (опционально)

```text
A variant of the giant crab-like carapace scavenger, same species but broader and older, asymmetric cracked shell with one chipped pincer, additional barnacle-like growths and old battle scars, dark crimson and charcoal chitin, six segmented legs, two pincers, eyeless armored head. Low aggressive stance, all limbs visible, no base. Realistic dark fantasy creature, PBR wet chitin and bone, single isolated creature, no background, no extra objects, no text.
```

### 3.3. `carapace_centurion_gen.glb` — Карапакс-центурион

**Роль:** элитный враг/hero-силуэт Лабиринта.

```text
A massive carapace centurion, an elite crab-like nightmare creature about 4.5 m tall, broader and taller than a scavenger, thick layered dark-red chitin armor, a crown of jagged bone horns, two enormous pincers, six heavy segmented legs, an eyeless armored head with mandibles, old battle scars, no human face. Imposing neutral hero stance, all limbs visible, no base. Realistic dark fantasy, PBR wet chitin and bone, dark crimson and charcoal palette, single isolated creature, no background, no extra objects, no text.
```

### 3.4. `centipede_gen_a.glb` — Сколопендра

```text
A giant armored centipede nightmare creature, 6 m long, segmented black-red chitin plates, many sharp legs, powerful mandibles, no eyes, low crawling pose. Full body visible from head to tail, no base. Realistic dark fantasy, wet chitin, bone details, muted dark red and black palette, PBR materials, single isolated creature, no background, no extra objects, no text.
```

### 3.5. `worm_knot_gen_a.glb` — Клубок червей

```text
A coiled knot of blind segmented nightmare worms, about 2.5 m across, wet pale gray and dark red flesh, circular mouth parts, no eyes, tangled body forming a low knot. Neutral coiled pose, all body mass visible, no base. Realistic dark fantasy, wet organic surfaces, PBR materials, single isolated creature, no background, no extra objects, no text.
```

### 3.6. `blood_flower_gen_a.glb` — Кровавый цветок

```text
A carnivorous blood-red nightmare flower, about 3 m tall, fleshy layered petals forming a circular maw, thorned dark stem and roots, wet organic surface, no eyes. Neutral open pose, full plant visible, no base. Realistic dark fantasy, PBR wet flesh and thorns, deep crimson and dark green-black palette, single isolated creature, no background, no extra objects, no text.
```

### 3.7. `police_desk_v2.glb` — дежурный офицер

**Роль:** пролог, лобби/изолятор. Заменяет `police_desk.glb` (опционально).

```text
A senior police desk officer, male about 55 years old, heavy build, short gray hair, tired stern face, modern blue short-sleeve police uniform shirt with badge and duty belt, dark trousers and boots, no weapon in hands. Full body, relaxed A-pose, arms about 35 degrees from torso, feet shoulder-width apart. Realistic contemporary game character, grounded anatomy, detailed face and hands, PBR materials, single isolated character, no base, no background, no extra objects, no text.
```

### 3.8. `police_guard_v2.glb` — молодой офицер

```text
A young police patrol officer, male about 30 years old, fit medium build, short dark hair, alert neutral expression, modern blue police uniform, dark tactical vest, duty belt with holstered sidearm, dark trousers and boots, no weapon in hands. Full body, relaxed A-pose, arms about 35 degrees from torso, feet shoulder-width apart. Realistic contemporary game character, grounded anatomy, detailed face and hands, PBR materials, single isolated character, no base, no background, no extra objects, no text.
```

---

## 4. P2 — массовка и будущие персонажи

Генерировать **после** P0/P1 и только если качество принято. Для толпы достаточно 2–3 базовых моделей с разными текстурами.

### 4.1. `mass_slave_v3.glb` — раб (базовый)

```text
A generic emaciated male slave about 30 years old, average height, gaunt tired face, short messy dark hair, ragged brown slave tunic, rope belt, patched wool trousers, bare dirty feet, no armor, no weapons. Full body, relaxed A-pose, arms about 35 degrees from torso, feet shoulder-width apart. Realistic dark fantasy, grounded anatomy, PBR materials, single isolated character, no base, no background, no extra objects, no text.
```

### 4.2. `mass_soldier_v3.glb` — солдат каравана

```text
A generic ancient caravan soldier, male about 30 years old, average build, short dark hair, stern face, simple leather cuirass over a dark tunic, leather bracers and boots, short sword sheathed at the hip, spear strapped on the back, no helmet, no weapon in hands. Full body, relaxed A-pose, arms about 35 degrees from torso, feet shoulder-width apart. Realistic dark fantasy, grounded anatomy, PBR materials, muted leather and dark cloth, single isolated character, no base, no background, no extra objects, no text.
```

### 4.3. `mass_male_v2.glb` — современный прохожий

```text
A generic adult man about 35 years old, average build, short dark hair, neutral expression, modern casual jacket, plain t-shirt, jeans and sneakers, no weapons. Full body, relaxed A-pose, arms about 35 degrees from torso, feet shoulder-width apart. Realistic contemporary game character, grounded anatomy, PBR materials, single isolated character, no base, no background, no extra objects, no text.
```

### 4.4. `mass_female_v2.glb` — современная прохожая

```text
A generic adult woman about 30 years old, average build, dark blonde hair tied back, neutral expression, modern casual coat, plain top, trousers and shoes, no weapons. Full body, relaxed A-pose, arms about 35 degrees from torso, feet shoulder-width apart. Realistic contemporary game character, grounded anatomy, PBR materials, single isolated character, no base, no background, no extra objects, no text.
```

### 4.5. `mass_police_v2.glb` — патрульный

```text
A generic police patrol officer, male about 35 years old, average build, short dark hair, neutral expression, modern blue police uniform, dark tactical vest, duty belt with holstered sidearm, dark trousers and boots, no weapon in hands. Full body, relaxed A-pose, arms about 35 degrees from torso, feet shoulder-width apart. Realistic contemporary game character, grounded anatomy, PBR materials, single isolated character, no base, no background, no extra objects, no text.
```

### 4.6. Nephis / Cassia / Echo — **не генерировать сейчас**

В сцене Лабиринта есть только маркеры `Nephis`, `Cassia`, `EchoPath` и `Echo`, без утверждённого геймплея и модельного брифа. Генерация сейчас создаст неканоничные лица и лишние ассеты. Вернуться после решения по сцене; для Nephis/Cassia нужен отдельный канон-чеклист.

---

## 5. Опциональные hero-ассеты окружения

Это не персонажи, но их сложно делать процедурно; генерировать только если есть свободные кредиты после P0/P1.

### 5.1. `carcass_shark_gen.glb` — туша акулы (Z02)

```text
A giant half-eaten shark carcass, 14 m long, lying on its side, torn open belly with exposed ribs and spine, damaged jaw with teeth, dark wet weathered skin, no living pose, no rig, no base. Realistic dark fantasy environment prop, PBR organic surfaces, single isolated object, no background, no extra objects, no text.
```

### 5.2. `giant_skeleton_gen.glb` — гигантский скелет (Z13)

```text
A colossal half-buried humanoid skeleton, 25 m long, massive weathered skull, long spine and rib cage, one arm and hand visible above the ground, ancient bone, no flesh, no base, no rig. Realistic dark fantasy environment hero prop, PBR aged bone, single isolated object, no background, no extra objects, no text.
```

### 5.3. `statue_knight_gen.glb` — статуя рыцаря (опционально)

**Сейчас есть найденный Stone Knight; сначала оптимизировать его, не генерировать дубль.** Если нужен канонический вариант:

```text
A colossal ancient headless knight statue, 200 m tall, black marble with weathered edges, seven star reliefs on the chest plate, massive sword pointing down, broken neck stump, no head, no base beyond a simple stone plinth. Realistic dark fantasy environment hero prop, PBR black marble and pale stone, single isolated statue, no background, no extra objects, no text.
```

---

## 6. План по кредитам

| Этап | Модели | Зачем |
|---|---|---|
| **P0** | 9 | Закрывает главный каст Первого Кошмара и Горного Короля |
| **P1** | 6–8 | Закрывает монстров Лабиринта; полиция опционально |
| **P2** | 5 | Массовка; только после приёмки P0/P1 |
| **Environment** | 2–3 | Туша/скелет/статуя; опционально |

При 45 кредитах: P0 + P1 = 15–17 моделей; если каждая 1–2 кредита, запас остаётся. **Не генерируй P2 и environment, пока P0/P1 не приняты** — иначе потратим кредиты на модели, которые придётся переделывать.

---

## 7. Что я сделаю после получения папки

1. Разберу файлы по именам и проверю GLB (tri, UV, текстуры, PBR, масштаб, ориентация).
2. Отбракую брак; лучшие варианты оставлю.
3. Для гуманоидов — риг на 53-костный humanoid, UAL, проверка коленей/стоп.
4. Для монстров — свой риг/AI или привязка к существующему AI.
5. Оптимизация: LOD, single-sided, tangents, texture resize/ORM, draw calls.
6. Интеграция в сцены, тесты, превью, `docs/ASSET_LICENSES.md`.

**Не удаляй старые fallback-модели** — они нужны до приёмки новых.
