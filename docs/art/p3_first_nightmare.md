# P3 — Первый Кошмар: видение, дорога, стоянка, тропа, святилище

**Дата:** 2026-11-02  
**Статус:** art-overlay проход завершён, игровые ресурсы и коллизии не менялись.  
**Область:** L01–L16 / `finale_arrival`; post-nightmare вне области.  
**Prerequisite:** P2.5 Spell Void (B13) — `docs/art/p2_5_spell_void.md`.

![P3 contact sheet](previews/p3_first_nightmare/p3_contact_sheet.png)

## 1. Подход

P3 сделан как **визуальный art-overlay поверх существующих сцен**. Базовые маршруты, коллизии, контроллеры, интерактивные объекты и общие системы не переписывались. Новые элементы — только `Node3D`, `GPUParticles3D`, `MeshInstance3D`, `Decal`/плоские следы, свет и окружение.

Проверенные ранее P0–P2 решения сохранены: реалистичные GLB-киты, AgX, SSAO/SSIL/SSR, туман, PBR-материалы и low-poly только для фона.

## 2. Дорога каравана

**Сцена:** `scenes/slice/locations/caravan_road_art.tscn`  
**Dressing:** `scenes/environment/p3_road_dressing.tscn`

- усилен лунный rim: `Sun` 1,25, `RimLight` 0,8, `directional_shadow_max_distance` 160;
- снег: дополнительный `p3_snow_gust` (1500 частиц) поверх существующего `nm_snowfall`;
- дыхание: четыре `p3_breath_puff` у цепи и всадника;
- следы: `DecalTrail` создаёт 28 отпечатков и 11 царапин цепи; следы привязаны к наклону `Road` (0,08 рад), а не висят в мировых координатах;
- окружение: AgX (`tonemap_mode = 4`), SSAO, SSIL, SSR, объёмный туман, усиленный `glow`;
- существующие цепь, рабы, всадники, кости и snow drifts сохранены.

## 3. Стоянка

**Сцена:** `scenes/locations/caravan_site/caravan_site_art.tscn`  
**Dressing:** `scenes/environment/p3_site_dressing.tscn`

- огонь: существующий `nm_fire_flame` (пламя + искры) и новый `p3_camp_smoke` (дым);
- тёплый/холодный контраст: `WarmFill` OmniLight у костра, холодный `Moon` 1,2 и `RimLight` 0,75;
- дыхание: четыре `p3_breath_puff` у NPC;
- снег: `p3_snow_gust`; кровь: три `Decal` + `BloodSpots` (5 плоских следов), цепные потёртости и 22 отпечатка;
- обломки: 2 `boulder_shard_a` и 1 `scree_pile_a` добавлены как визуальный слой без коллизий;
- окружение: AgX, SSAO/SSIL/SSR, объёмный туман, `glow`.

### Исправление камер

`NightMontageCamera` больше не смотрит в скалу и не стоит в геометрии.

- сцена: `scenes/campaign/caravan_site_arrival.tscn`;
- скрипт: `scripts/campaign/caravan_site_arrival.gd`;
- новая позиция `Vector3(4.6, 3.4, 4.6)`, `look_at` на огонь (в скрипте — `get_fire_position() + Vector3(0, 0.9, 0)`);
- `WagonCamera` переставлена в `Vector3(4.5, 3.0, 1.2)` с `look_at` на повозку `Vector3(-4.5, 0.9, -2.6)`;
- проверка: `site_night_script.png` и `site_wagon_script.png` сняты через реальные методы `_stage_night_camera()`/`_stage_wagon_camera()`.

## 4. Горная тропа

**Сцена:** `scenes/locations/pilgrim_path/pilgrim_path_art.tscn`  
**Dressing:** `scenes/environment/p3_trail_dressing.tscn`

- экспозиция поднята: AgX, `tonemap_exposure = 1.45`, ambient 0,9, moon 1,35, rim 0,85;
- световые щели: три `SpotLight3D` (`MoonShaftAlcove/Cave/Temple`) с объёмным туманом и `TempleKey`/`TempleFill`;
- снег/лёд: `p3_snow_gust`, существующие ice flow, снежные дрифты и icicles;
- дыхание: у костра, пещеры и уступа;
- кровь: `BloodAtAlcove`, `BloodAtCave`, `BloodOnStairs`, `BloodOnPath`, `BloodOnLedge` + 4 плоских следа `BloodSpots`;
- следы: 16 у алькова, 20 на тропе, 18 на лестнице;
- дым: `p3_camp_smoke` у костра в алькове;
- силуэты: существующие `MountainKing`, `TyrantSighting`, `TempleGlow`, `Summit`;
- храм дополнительно подсвечен `TempleFill` и `TempleKey`, чтобы читались колонны/фасад.

## 5. Видение

**Сцена:** `scenes/slice/locations/mountain_vision_art.tscn`  
**Dressing:** `scenes/environment/p3_vision_dressing.tscn`

- добавлены два дополнительных слоя `nm_cloud_sea` (mid/near) к существующему морю облаков;
- `Sun`/moon сцены и `Env_art`/`Env_orbit` переведены на AgX, SSAO/SSIL/SSR, усиленный glow;
- `p3_snow_gust`, `p3_dust_motes`, снежные и пылевые слои;
- лучи: `MoonShaftA/B/Road/Caravan` SpotLight3D с объёмным туманом;
- отпечатки каравана и царапины цепи привязаны к наклону дороги (`GroundDetails` копирует transform `Road`);
- караван и кости включаются в проверочном кадре (в игре их видимость по-прежнему управляется cutscene `MountainVision._vision`);
- кости/караван/цепь читаются в `vision_caravan.png`; общий силуэт Чёрной горы — `vision_orbit.png`.

## 6. Святилище Тени

**Сцена:** `scenes/locations/shadow_sanctuary/shadow_sanctuary_art.tscn`  
**Dressing:** `scenes/environment/p3_sanctuary_dressing.tscn`

- чёрный мрамор: полированная центральная полоса `PolishedNave` с материалом `p3_marble_polished.tres` (roughness 0,42, metallic 0,08), поверх снега; SSR + `ReflectionProbe`;
- рельефы, колонны, алтарь, обломки и снег/лёд — существующие art-ассеты, усилены светом;
- объёмные лучи: `P3BeamMain/East/North`, `AltarShaft`, плюс базовые `Beam_*`;
- пыль: `p3_dust_motes` + `BreachSnow` (снег через пролом);
- тёплый/холодный баланс: холодный moon/rim, `AltarGlow`, `ReflectionFill`;
- окружение: AgX, exposure 1,32, SSAO/SSIL/SSR, усиленный объёмный туман.

## 7. VFX-кит

- `scenes/environment/p3_snow_gust.tscn` — ветровой снег/крупные хлопья;
- `p3_breath_puff.tscn` — пар дыхания (низкая яркость, чтобы не читался как шар);
- `p3_camp_smoke.tscn` — дым костра;
- `p3_dust_motes.tscn` — пыль/мотыльки;
- `scripts/world/decal_trail.gd` — плоские следы/кровь/потёртости, привязанные к поверхности;
- `assets/environments/nightmare/materials/textures/p3_footprint.png`, `p3_blood.png`, `p3_chain_scrape.png` — сгенерированы `source/make_p3_decals.py`.

## 8. Файлы

**Новые:**

- `scenes/environment/p3_snow_gust.tscn`
- `scenes/environment/p3_breath_puff.tscn`
- `scenes/environment/p3_camp_smoke.tscn`
- `scenes/environment/p3_dust_motes.tscn`
- `scenes/environment/p3_road_dressing.tscn`
- `scenes/environment/p3_site_dressing.tscn`
- `scenes/environment/p3_trail_dressing.tscn`
- `scenes/environment/p3_vision_dressing.tscn`
- `scenes/environment/p3_sanctuary_dressing.tscn`
- `scripts/world/decal_trail.gd`
- `assets/environments/nightmare/materials/textures/p3_{footprint,blood,chain_scrape}.png`
- `assets/environments/nightmare/materials/p3_marble_polished.tres`
- `assets/environments/nightmare/source/make_p3_decals.py`
- `tools/audit/p3_capture.gd` (рендер P3-ракурсов)
- `tools/audit/p3_validate.gd` (headless-проверка загрузки сцен)

**Изменены:**

- `scenes/slice/locations/caravan_road_art.tscn`
- `scenes/locations/caravan_site/caravan_site_art.tscn`
- `scenes/locations/pilgrim_path/pilgrim_path_art.tscn`
- `scenes/slice/locations/mountain_vision_art.tscn`
- `scenes/locations/shadow_sanctuary/shadow_sanctuary_art.tscn`
- `scenes/campaign/caravan_site_arrival.tscn`
- `scripts/campaign/caravan_site_arrival.gd` (только позиции/`look_at` камер)

## 9. Проверки

| Проверка | Результат |
|---|---|
| `godot --headless --path . --import` | exit 0 |
| `p3_validate.gd` (P3 + P2.5) | 20/20 сцен, failed=0 |
| `test_location_art_decor` | 3/3, 112 assert, exit 0 |
| `test_caravan_march` | 7/7, 31 assert, exit 0 |
| `test_caravan_site` | 7/7, 533 assert, exit 0 |
| `test_pilgrim_path` | 10/10, 259 assert, exit 0 |
| `test_sanctuary_approach_presentation` | 10/10, 443 assert, exit 0 |
| `test_shadow_sanctuary` | 11/11, 34 assert, exit 0 |
| `test_slice_locations` | 8/8, 48 assert, exit 0 |
| `test_campaign_flow` | 10/10, 83 assert, exit 0 |
| Полный GUT (`-gdir=res://tests -gexit`) | 71 скриптов, 557 теста, 557 pass, 6761 assert, exit 0 |
| P3-рендеры | 1280×720, `p3_capture.gd`; контактный лист в `docs/art/previews/p3_first_nightmare/` |

**NOT TESTED:** полный ручной playthrough, foot-sliding, 1080p/60 FPS, визуальная проверка на всех разрешениях/GPU. Это не заявляется как пройденное.

## 10. Ограничения

- P3 не меняет геймплей, маршруты и коллизии; арт-слой можно отключать.
- `caravan_site` использует существующую low-poly лошадь; замена лошади на новую модель не входила в этот проход.
- Часть базовых low-poly ассетов остаётся в кадре (манекены/повозка/крупные камни); это осознанно, чтобы не менять игровые сцены и не создавать новые коллизии.
- Производительность и ручной playthrough требуют отдельного прогона; результаты не подменяются.
