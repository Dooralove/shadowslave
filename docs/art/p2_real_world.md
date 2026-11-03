# P2 — реальный мир: парк, лобби, изолятор

**Дата:** 2026-11-02  
**Статус:** P2-пас собран и интегрирован в prologue art-слои. Маршруты, коллизии, контроллер и игровая логика не менялись.  
**Единственное исключение по позе:** маркер `Spawns/Chair` в изоляторе сдвинут на +0,20 м, чтобы модель Санни садилась в кресло, а не перед ним. Это визуальная посадка, не изменение маршрута.

![P2 contact sheet](previews/p2_real_world/p2_contact_sheet.png)

## 1. Парк

- **Деревья:** `island_tree_01` (Poly Haven, CC0) упрощён в 3 LOD и импортирован:
  - LOD0 ≈ 63,9 тыс. треугольников;
  - LOD1 ≈ 19,0 тыс. (текстуры 512);
  - LOD2 ≈ 5,3 тыс. (текстуры 512);
  - `scripts/world/tree_lod.gd`, `scenes/environment/park/island_tree.tscn`; пороги 30/70 м.
  - проверка: 10 м → LOD0, 40 м → LOD1, 80 м → LOD2.
  - Старые low-poly `Tree0–Tree4` скрыты; их место занимают 5 островных деревьев + 2 фоновых. Низкополигональный LOD2 остаётся для дальнего плана.
- **Фасады:** новый процедурный кит `assets/environments/park/p2/`:
  - `facade_p2_balcony.glb` — бетонная рама, ленточные окна, балконы с остеклением/оградами, карнизы, vertical fins;
  - `facade_p2_glass.glb` — стеклянный curtain wall с металлическими импостами;
  - `facade_p2_stone.glb` — каменный фасад с punched windows и балконами;
  - `station_entrance_p2.glb` — новое освещённое лобби входа, козырёк, стеклянные двери, вывеска.
  - Старые `Facade0–7`, `StationMain`, `StationTower`, `StationPlinth` скрыты визуально; коллизии остались.
- **Земля:** новые PBR-плоскости `paving_park`, `asphalt`, `curb`; тротуары, дорога, бордюры, lane dashes, crosswalk; газон — собственная процедурная текстура `p2_grass_diff_1k.jpg` + `p2_grass.tres`.
- **Уличная мебель:** стеклянный автобусный павильон `bus_shelter_p2.glb`, дополнительные скамейки, существующие фонари/урны/болларды.
- **Дальний город:** `DistantCity` из упрощённых башен с `city_far_tower.tres` / `city_curtain_wall.tres`; растворяется в volumetric fog.
- **Свет:** HDRI `kloofendal_misty_morning_2k.hdr` (Poly Haven CC0), `morning_sky.tres`, `morning_environment.tres`; AgX, SSAO/SSIL/SSR, volumetric fog, отражения; тёплый утренний DirectionalLight.
- **Puddles:** Decals `p2_wet_stain.png` на тротуаре; ReflectionProbe в P2-сете.

Файлы:

- `scenes/slice/locations/park/park_street_art.tscn`
- `scenes/slice/locations/park/p2_park_set.tscn`
- `scenes/slice/locations/park/park_art.tscn`
- `assets/environments/park/p2/`
- `assets/environments/park/trees/`
- `assets/environments/park/sky/`

## 2. Лобби

- **Стойка:** `lobby_counter_p2.glb` — массивная консоль с каменной столешницей, панелями, сервисным люком и тёмным экраном; старый `Art/Counter` скрыт.
- **Плотность:** металлические шкафчики (6 шт.), стулья ожидания, потолочные короба-воздуховоды, вентиляционные решётки, кабельные лотки, вертикальный conduit, потолочные светильники, напольная разметка.
- **Свет/отражения:** `ReflectionProbe`, `CounterKey` SpotLight, `CounterFill`, переработанный `p2_lobby_environment.tres`; стойка стала сильнее и читается как рабочее место дежурного.
- **Alarm:** красные маяки `alarm_beacon_p2.glb` скрыты в штатном режиме; `scripts/world/alarm_beacons.gd` показывает их при энергии `AlarmLights > 0.12`. В `station_lobby.gd` добавлен `AlarmCenter` OmniLight, который пульсирует вместе с существующей тревогой. Red alarm state виден в `p1_scene_station_lobby_art_alarm.png`.

Файлы:

- `scenes/slice/locations/station_lobby_art.tscn`
- `scenes/slice/locations/lobby_p2_dressing.tscn`
- `assets/environments/prologue/p2/`
- `assets/environments/prologue/materials/p2_lobby_environment.tres`

## 3. Изолятор

- **Материалы:** существующие бетон/сталь `cell_*` + новый холодный `p2_cell_environment.tres` (AgX, SSAO/SSR/SSIL, volumetric fog).
- **Мокрый пол:** полупрозрачный `p2_wet_sheen.tres` + Puddles/Decals из `p2_wet_stain.png`; отражения от ReflectionProbe.
- **Стоки:** `cell_drain_p2.glb` — два сливных трапа с ламелями.
- **Трубы/потёки:** `cell_pipe_p2.glb` на восточной/западной стене, вертикальный wet streak decal.
- **Царапины:** `p2_scratch.png` Decals на полу и двери.
- **Жёсткий верхний свет:** `HardTop` SpotLight + усиленный `Overhead`, холодный цвет; `ViewingGlass` с прозрачным стеклом и `ObservationGlow` за ним.
- **Поза Санни:** маркер `Spawns/Chair` сдвинут на +0,20 м, чтобы `Sitting_Idle`/`restrained_idle` действительно попадал в кресло; ремни/подголовник/кресло остаются на месте.
- **Проверка:** `tools/audit/p2_containment_pose.gd` рендерит Санни в кресле и широкий кадр с полом/дренажом.

Файлы:

- `scenes/slice/locations/containment_room_art.tscn`
- `scenes/slice/locations/containment_p2_dressing.tscn`
- `assets/environments/prologue/p2/`
- `assets/environments/prologue/materials/textures/p2_wet_stain.png`, `p2_scratch.png`
- `assets/environments/prologue/materials/p2_cell_environment.tres`

## 4. Проверки

- `godot --headless --path . --import` — **exit 0**.
- GUT (выборочно, P2-релевантные):
  - `test_slice_locations` — 8/8;
  - `test_campaign_flow` — 10/10;
  - `test_sunny_waking` — 10/10;
  - `test_poison_flasks` — 7/7.
- Полный GUT после P2 не перезапускался; последний известный полный прогон до P2 — 528/529 (один fail в `test_labyrinth_first_fragment`, вне P2).
- Ручной playthrough, foot-sliding и 1080p/60 FPS — **NOT TESTED**.
- Превью: `docs/art/previews/p2_real_world/`.

## 5. Ограничения

- Фасады — процедурный P2-кит: геометрия и материалы читаются, но это не финальная архитектурная библиотека; нужны вариации этажей, вывесок, интерьеров за стеклом.
- Дальний город — упрощённые башни; для финала нужен более дешёвый skyline/импосты и, возможно, отдельный LOD.
- `island_tree_01` LOD0 ≈ 64k — дорого для десятков экземпляров; LOD1/2 уже есть, но для плотного парка нужен более лёгкий финальный tree kit.
- Мокрый пол/лужи — sheen + decals, не симуляция воды; отражения ограничены SSR/ReflectionProbe.
- Лобби: потолочные короба/лотки есть, но в кадре сверху они почти не читаются; при финальной постановке нужен отдельный верхний ракурс.
- Red alarm state проверен статическим кадром, не полным таймингом `code_black`.
- Стекло фасадов — dark reflective PBR, без настоящей прозрачности/интерьеров; это осознанно для 1080p.

**Итог:** P2 заменил low-poly парк на реалистичные деревья/фасады/мощение, собрал плотное лобби с сильной стойкой и red alarm, переработал изолятор (мокрый пол, стоки, потёки, верхний свет, окно, посадка Санни) без изменений маршрутов и коллизий.
