# P1 — основные персонажи и Горный Король

**Дата:** 2026-11-02  
**Статус:** P1-пас сделан и интегрирован в сцены. Маршруты, коллизии, контроллер и логика боя не менялись.  
**Scope:** L01–L16, до `finale_arrival`; post-nightmare не входит.  
**Цель P1:** заменить заглушки основных персонажей на реалистичные PBR-модели с UAL-анимациями, LOD и читаемыми силуэтами; Горного Короля — на отдельный hero-ассет.

![Main cast](previews/p1_characters/main_cast.png)

## 1. Что сделано

- **Санни:** два варианта — реальный мир (`sunny_real.glb`) и Кошмар (`sunny_nightmare.glb`):
  - худой подросток ~1,66 м, бледная кожа, тёмные неопрятные волосы, тёмные круги вокруг глаз;
  - реальный мир: выцветший светлый свитер, тёмные штаны, изношенные кроссовки;
  - Кошмар: ветхая туника, шерстяные штаны, босые ноги;
  - 3 LOD в одном GLB.
- **Полиция:** 2 ключевых варианта:
  - `police_desk` — старший офицер, седые волосы, тяжёлое телосложение;
  - `police_guard` — молодой офицер, тёмные волосы, другой силуэт;
  - остальная полиция — `mass_police`, без уникального лица.
- **Герой / Ауро:** `hero_auro.glb` — молодой солдат, кожаная кираса, длинные волосы. В каноне Герой и Ауро — один персонаж; отдельного актёра `Auro` нет, но `auro` оставлен алиасом в `Mannequin`.
- **Учёный:** `scholar.glb` — высокий худой мужчина, тёмный костюм, очки, седеющие волосы.
- **Шифти:** `shifty.glb` — тонкий раб в грубой одежде, отдельный силуэт.
- **Ветеран:** `veteran.glb` — старый офицер, кожаная кираса, седые волосы, тяжёлое телосложение.
- **Массовка:** `mass_male`, `mass_female`, `mass_slave`, `mass_soldier`, `mass_police` — упрощённые модели без уникальных лиц; палитры по типам, разные силуэты.
- **Горный Король:** `mountain_king_p1.glb` — оригинальная процедурная модель: 4+ м, сутулый торс, две короткие ноги, четыре руки (две длинные с костяными когтями, две короткие с пальцами), пять млечных глаз, пасть с зубами, жёлто-серая клочковатая шерсть, роговые выступы (по брифу пользователя). 3 LOD, 5 клипов.

Все исходники воспроизводимы:

- `assets/characters/p1/source/build_main_cast.py`
- `assets/characters/p1/source/build_mountain_king.py`

## 2. Полигонаж и LOD

| Ассет | LOD0 | LOD1 | LOD2 | Примечание |
|---|---:|---:|---:|---|
| `sunny_real` | 26 626 | 13 547 | 6 252 | 3 LOD |
| `sunny_nightmare` | 27 814 | 14 166 | 6 538 | 3 LOD |
| `police_desk` | 27 108 | 13 755 | 6 346 | 3 LOD |
| `police_guard` | 28 816 | 14 644 | 6 755 | 3 LOD |
| `hero_auro` | 30 998 | 15 820 | 7 298 | 3 LOD |
| `scholar` | 37 374 | 18 994 | 8 765 | 3 LOD |
| `shifty` | 27 400 | 13 950 | 6 437 | 3 LOD |
| `veteran` | 33 054 | 16 889 | 7 792 | 3 LOD |
| `mountain_king_p1` | 32 656 | 14 130 | 3 366 | 3 LOD, 5 клипов |
| `mass_*` | 8 865–14 257 | — | — | один уровень, без уникальных лиц |

LOD0/1/2 лежат **в одном GLB** и используют общую арматуру; переключаются скриптом
`scripts/characters/character_lod_visibility.gd` (дистанции по умолчанию 10/22 м; у Короля 20/45 м).
Проверка переключения на `hero`:

```text
LOD_DIST 2.0  visible_lod0=9 lod1=0 lod2=0
LOD_DIST 12.0 visible_lod0=0 lod1=7 lod2=0
LOD_DIST 30.0 visible_lod0=0 lod1=0 lod2=7
```

Король: `KING_LOD 5.0 lod0`, `KING_LOD 25.0 lod1`, `KING_LOD 60.0 lod2`.

## 3. Анимации

- **Гуманоиды** используют существующую библиотеку Quaternius UAL (CC0) и `sunny_idle_relaxed.glb`.
  `Mannequin` поддерживает позы: `idle`, `talk`, `walk`, `run`, `sit`, `guard`, `dead` (+ `kneel`, `torch`, `ride`);
  добавлен `run` (`Sprint`).
- **Санни** — `SunnyAnimator`/`CinematicActor`: idle, walk, sprint, jump/fall/land, punch, guard, roll, hit, death.
- **Горный Король** — клипы `Idle`, `Walk`, `Telegraph`, `Attack`, `Death`; `mountain_king.gd` переключает их по состоянию AI
  (это визуальный хук, логика состояний не менялась).
- **Без T-pose:** все runtime-инстансы проигрывают позу; голый GLB в редакторе остаётся в rest/T-pose, это нормально для исходника.
- **Проверка поз** на `Mannequin`:

```text
POSE idle clip=Idle_Relaxed playing=true
POSE talk clip=Idle_Talking playing=true
POSE walk clip=Walk playing=true
POSE run clip=Sprint playing=true
POSE sit clip=Sitting_Idle playing=true
POSE guard clip=Sword_Idle playing=true
POSE dead: Death01, финальный кадр 2.39/2.40 с, paused
```

Скольжение стоп и тайминг шага вручную **NOT TESTED**; клипы UAL in-place, но для финального вердикта нужен прогон в реальном flow.

## 4. Интеграция в сцены

- `scripts/slice/mannequin.gd`: новые архетипы `police_desk`, `police_guard`, `hero`, `auro`, `scholar`, `shifty`, `veteran`,
  `mass_*`; LOD-дистанции; переименование скелета `Skeleton3D` → `GeneralSkeleton`.
- `scenes/locations/caravan_site/caravan_site.tscn`: `ShiftySlave` → `shifty`, `Scholar` → `scholar`, `Hero` → `hero`,
  `Veteran` → `veteran`; масштабы подогнаны (1.66–1.85 м).
- `scenes/locations/pilgrim_path/pilgrim_path.tscn`: Hero/Shifty/Scholar переведены на новые архетипы.
- `scenes/slice/locations/station_lobby.tscn`: `DeskOfficer` → `police_desk`, `OfficerA/B` → `police_guard`.
- `scenes/slice/locations/containment_room.tscn`: `Policeman` → `police_desk`, `GuardA/B` → `police_guard`.
- `scenes/slice/locations/park_street.tscn`: массовка переведена на `mass_male`/`mass_female` и подогнана по росту.
- `scenes/campaign/caravan_site_arrival.tscn`, `first_nightmare_pass.tscn`, `pilgrim_path_arrival.tscn`,
  `scenes/locations/shadow_sanctuary/shadow_sanctuary.tscn`, `scenes/levels/ambush_site_demo.tscn`:
  Санни переключён на `sunny_waking_nightmare.tscn` (ветхая туника, босые ноги).
- `assets/characters/sunny_realistic_poc/sunny_waking_poc.tscn`: реальный мир — на `sunny_p1_model.tscn`.
- `scenes/characters/mountain_king.tscn`: добавлен `Visual/Model` с `mountain_king_p1.glb`; старые примитивы скрыты,
  `Visual/MeleeAttack`, `TelegraphVisual`, `Hurtbox`, `Health`, коллизия сохранены.

## 5. Горный Король

![Mountain King](previews/p1_characters/mountain_king_p1.png)

- Высота тела ~4,3 м; силуэт: сутулый торс, короткие ноги, четыре руки, когти, пять глаз, пасть.
- Материалы: тёмная кожа, два оттенка жёлто-серой шерсти, кость, млечные глаза; шерсть — геометрия из тысяч конусов, не alpha-карты.
- 5 клипов; LOD2 3,4 тыс. треугольников.
- **Ограничение:** это процедурный P1-пас, не финальный скульпт. Для финала нужны:
  - ретопология/скульпт головы и торса, нормал-карты шерсти;
  - нормальные fur cards/шелл вместо «игл»;
  - более читаемая пасть и рога;
  - проверка анимаций в бою и на дистанции.

**Обновление 2026-11-02:** `mountain_king.tscn` переведён на `mountain_king_p3.glb` — производную p1/p2 с переработанной шерстью, выведенными из шерсти короткими руками и усиленной мордой (надбровья, скулы, губы, подбородок, грива). Риг (25 костей) и пять клипов сохранены; p1/p2 оставлены fallback. Детали — `docs/art/enemy_model_upgrade_followup_2026-11-02.md`; p3: LOD0 46 148 / LOD1 21 228 / LOD2 8 267 tri.

## 5а. P1.5: проход по экипировке главных героев и NPC (2026-11-02)

Проверены все P1-модели, POC-Санни, старые placeholders и лошадь. Обновлены пять моделей, у которых silhouette/gear расходились с каноном:

| Модель | LOD0 tri / meshes | Что изменено |
|---|---:|---|
| `hero_auro_v2.glb` | 31 902 / 12 | короткая мужская стрижка, кожаная кираса с заклёпками, наплечники, наручи, ремень, копьё за спиной, короткий меч |
| `veteran_v2.glb` | 36 958 / 12 | седина, тёмный меховой воротник, кираса, хлыст и меч |
| `shifty_v2.glb` | 27 672 / 10 | грубая туника, юбка-туника, верёвочный пояс, стоптанные сапоги |
| `mass_slave_v2.glb` | 9 137 / 6 | грубая туника, юбка-туника, верёвочный пояс, босые ноги |
| `mass_soldier_v2.glb` | 17 525 / 9 | кожаная кираса, наплечники, наручи, ремень, копьё и меч |

Сохранены 53-костный rig, рост и UAL-совместимость; LOD1/LOD2 пересобраны. `Mannequin` переведён на v2 для `hero`/`auro`, `veteran`, `shifty`, `slave`/`mass_slave`, `knight`/`mass_soldier`. Оригинальные GLB оставлены fallback. Санни, Учёный, полиция и массовка парка оставлены без изменений — их P1-модели уже читаются, а экспериментальные hood/плащ не прошли приёмку.

Превью: `docs/art/previews/p1_characters/cast_gear_pass_*.jpg`. Профильные тесты: 65/65, 1260 asserts (включая `test_full_route`). Полный аудит, канон-чеклист и ограничения — `docs/art/character_model_audit_2026-11-02.md`.

**2026-11-02, реакция пользователя:** v2-пас признан неприемлемым — плавающие наплечники/наручи, жёсткая юбка, «суженные» силуэты. `mannequin.gd` возвращён на исходные P1-модели; убраны экстремальные `width_scale` 0.9/1.4. Это **не финальное решение**, а откат сломанного слоя. Генерация Hyper3D перепроверена: free-trial ключ — `API_INSUFFICIENT_FUNDS`, приватный ключ — `API_NO_ACTIVE_SUBSCRIPTION`, FAL_AI — требуется авторизация. Пока генератор не активирован, новые модели не производились. Статус и варианты — `docs/art/character_rework_status_2026-11-02.md`.

## 6. Проверка

- `godot --headless --path . --import` — **exit 0**.
- Сцены `caravan_site`, `pilgrim_path`, `station_lobby`, `containment_room`, `park_street` загружаются; ключевые NPC имеют
  `archetype` и `GeneralSkeleton`; Король в `caravan_site` имеет `Model`, `AnimationPlayer` и клип `Idle`.
- GUT (выборочно, 9 скриптов): **90/90 passed**:
  - `test_sunny_poc` 10/10
  - `test_sunny_waking` 10/10
  - `test_mountain_king` 11/11
  - `test_pilgrim_path` 10/10
  - `test_caravan_site` 7/7
  - `test_poison_flasks` 7/7
  - `test_shadow_sanctuary` 11/11
  - `test_ambush_site` 16/16
  - `test_slice_locations` 8/8
- Полный GUT-прогон: **528/529 passed**; единственный fail — `test_labyrinth_first_fragment::test_walk_down_entry_stairs_into_fork`
  (ошибка `Parameter "t" is null`, вне P1-скоупа, labyrinth). Это не P1-регрессия, но полный suite не зелёный.
- Ручной playthrough — **NOT TESTED**.
- 1080p/60 FPS — **NOT TESTED**; есть LOD и бюджеты, но замер FPS в этом пасе не выполнялся.
- Скольжение стоп / отсутствие T-pose в каждом кадре — T-pose проверен косвенно (все инстансы играют позу),
  foot sliding — **NOT TESTED**.

## 7. Ограничения P1

- Лица — MakeHuman-база с разными фенотипами, но без скульпта/текстурной живописи; это не финальные уникальные лица.
- Одежда — доступные CC0-ассеты MPFB с перекраской; Герой/Ветеран используют кожаную кирасу-производную, а не полный
  авторский armor kit.
- У Санни нет полноценного hoodie: свитер + силуэт; hood/капюшон вынесен в P1.5.
- Массовка — 9–14 тыс. треугольников, не «ультра-low-poly»; лица без уникальных черт, палитры по типам.
- Горный Король — процедурный, силуэт читается, но финальная шерсть/морда требуют скульпта.
- В сценовых кадрах `containment_room` и `caravan_site` освещение/камера не финальные: это проверка интеграции, не арт-постановка.

## 8. Следующий шаг

1. P1.5: уникальные лица/волосы Санни и ключевых NPC, hoodie, нормальные cloth/leather kits.
2. P1.5: финальный скульпт/ретопология Горного Короля, fur cards, боевые анимации.
3. P2: парк (фасадный кит, деревья, мощение), лобби/изолятор (свет, отражения, композиция).
4. QA: реальный flow, экспозиция, foot sliding, 1080p 60 FPS.

**Итог:** P1 заменил заглушки на реальные модели и интегрировал их без изменений геймплея; главный оставшийся разрыв — уникальные лица/волосы и финальная шерсть Короля, а не отсутствие ассетов.
