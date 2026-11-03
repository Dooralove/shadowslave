# P4 — UI и постановка: чистый HUD, камеры, DOF, LUT

**Дата:** 2026-11-02  
**Область:** P4 — визуальная/UI-доводка пролога и Первого Кошмара.  
**Статус:** реализовано; маршруты, коллизии, контроллер и боевые системы не менялись.

![P4 contact sheet](previews/p4_staging/p4_contact_sheet.png)

Контактный лист: `docs/art/previews/p4_staging/p4_contact_sheet.png`  
Кадры: `park_ui`, `lobby_alarm_ui`, `containment_ui`, `spell_void_ui`, `wagon_camera_ui`, `night_montage_ui`, `pilgrim_trail_ui`, `sanctuary_ui`, `ui_language`.

## 1. Debug-текст

Удалены из play-path:

- `PrototypeNote` вместе с дочерними `Root/Note` в `caravan_site_arrival.tscn`, `first_nightmare_pass.tscn`, `pilgrim_path_arrival.tscn`;
- ссылки `_note` и весь текст заметок из `caravan_site_arrival.gd`, `first_nightmare_pass.gd`, `pilgrim_path_arrival.gd`;
- `Prototype`-подпись в `finale_arrival.tscn`;
- `PROTOTYPE BUILD` из `main_menu.tscn`;
- debug-path/footer из `rpg_menu_prototype.tscn`;
- `show_debug_labels` в восьми post-nightmare greybox-сценах переключён на `false`.

Логические ветки `debug_direct_scene` сохранены: они по-прежнему выставляют флаги для прямого запуска, но больше не показывают текст. Тесты, которые раньше проверяли `PrototypeNote`, переписаны на проверку его отсутствия.

## 2. Камеры и Shots

**AlarmShot** (`scenes/slice/locations/station_lobby.tscn`) пересобран в фронтальный кадр стойки:

- позиция `(0, 2.15, 4.2)`, FOV `54`;
- цель — `(0, 1.3, -3.2)`, то есть стол и офицер, а не стена/угол;
- кадр проверен в `test_p4_presentation.gd` по положению `LookAt`.

**WagonCamera / NightMontageCamera:** позиции P3 сохранены и повторно проверены через реальные методы `_stage_wagon_camera()` / `_stage_night_camera()`; обе камеры получили общий cutscene-DOF. Регрессии кадра нет.

Проверены все камеры `Shots/*` в P2/P2.5/P3-сценах:

- park: `BenchShot`, `DozeShot`;
- lobby: `DeskShot`, `AlarmShot`;
- containment: `RoomShot`, `DoorShot`;
- mountain vision: `Orbit`, `RoadShot`;
- spell void: `SpellShot`, `CloseShot`.

## 3. Единый UI

Единый источник — существующая палитра `RpgMenuTheme` (тёмный графит, бронза/золото, тёплый костяной текст). Она применена к:

- `SubtitleUI` (субтитры в прологе и барах);
- `ObjectiveLine`;
- `RuneStatusUI`;
- `CombatHud/Root`;
- `PrologueUI` (`Hint`, `Prompt`, `SpellMessage`, `EndCard`).

Стили `PrologueUI`, `BarkUI`, `CombatHud` приведены к той же палитре; `SpellMessage` оставлен холодным синим как семантическое исключение для голоса Кошмарного Заклинания. Кампанейские карточки (`campaign_entry`, `sanctuary_arrival`, `appraisal_arrival`, `finale_arrival`) переведены с холодного синего на бронзовый акцент, чтобы не было двух UI-языков.

## 4. DOF только в катсценах

Ресурс: `resources/cameras/p4_cutscene_dof.tres` (`CameraAttributesPractical`).

- `SliceLocation` назначает его каждой камере из `Shots/*`, если у неё ещё нет атрибутов;
- `WagonCamera` и `NightMontageCamera` получают тот же ресурс явно в сцене;
- камера игрока (`sunny.tscn/CameraRig/SpringArm3D/Camera3D`) не имеет `attributes`;
- параметры: дальний DOF от `14` с переходом `18`, амплитуда `0.08` — фон мягкий, субъект и гейплейная камера остаются резкими.

## 5. LUT / цветокоррекция

Ресурс: `resources/environment/p4_grade_lut.tres` — 1D LUT (`GradientTexture1D`), мягкий split-tone: холодные/приподнятые тени, нейтральные средние, тёплые костяные света.

Назначен на ключевые окружения:

- `p2_lobby_environment.tres`, `p2_cell_environment.tres`, `morning_environment.tres`;
- `caravan_road_art`, `caravan_site_art`, `pilgrim_path_art`, `shadow_sanctuary_art`, `mountain_vision_art` (оба environment);
- `spell_void`.

Это не меняет геометрию и материалы, только постобработку `Environment.adjustment_color_correction`.

## 6. Проверки

| Проверка | Результат |
|---|---|
| `godot --headless --path . --import` | exit 0 |
| `p3_validate.gd` | 20/20 сцен, failed=0 |
| `test_p4_presentation` | 9/9, 65 assert |
| `test_campaign_flow` | 11/11, 82 assert |
| `test_caravan_march` | 7/7, 31 assert |
| `test_prologue_art` | 10/10, 86 assert |
| Полный GUT | 72 скрипта, 567 тестов, 567 pass, 6825 assert, exit 0 |
| P4-рендер | 9 кадров 1280×720; контактный лист выше |

??????: `godot --path . res://tools/audit/p4_capture.tscn -- --out=<temp>/p4_final_shots`.

**NOT TESTED:** ручной playthrough с мышью/геймпадом, 1080p/60 FPS на целевом железе, субъективная оценка DOF/LOOK в полном прохождении. Это не заявляется как проверенное.

## 7. Файлы

**Изменены/добавлены:**

- `resources/cameras/p4_cutscene_dof.tres`
- `resources/environment/p4_grade_lut.tres`
- `scripts/slice/slice_location.gd`
- `scenes/campaign/caravan_site_arrival.tscn`
- `scenes/campaign/first_nightmare_pass.tscn`
- `scenes/campaign/pilgrim_path_arrival.tscn`
- `scenes/campaign/{campaign_entry,sanctuary_arrival,appraisal_arrival,finale_arrival}.tscn`
- `scenes/slice/locations/station_lobby.tscn`
- `scenes/slice/locations/{spell_void,caravan_road_art,mountain_vision_art}.tscn`
- `scenes/locations/caravan_site/caravan_site_art.tscn`
- `scenes/locations/pilgrim_path/pilgrim_path_art.tscn`
- `scenes/locations/shadow_sanctuary/shadow_sanctuary_art.tscn`
- `assets/environments/prologue/materials/{p2_lobby_environment,p2_cell_environment}.tres`
- `assets/environments/park/sky/morning_environment.tres`
- `scenes/ui/{prologue_ui,bark_ui,combat_hud,objective_line}.tscn`
- `scenes/ui/main_menu/main_menu.tscn`, `scenes/ui/rpg_menu_prototype.tscn`
- `scripts/ui/{prologue_ui,subtitle_ui,objective_line,rune_status_ui,combat_hud}.gd`
- `scripts/campaign/{caravan_site_arrival,first_nightmare_pass,pilgrim_path_arrival}.gd`
- `tests/{test_campaign_flow,test_caravan_march}.gd`
- `tests/test_p4_presentation.gd`
- `tools/audit/p4_capture.tscn`, `tools/audit/p4_capture_runner.gd`
- `docs/art/previews/p4_staging/`

Коммиты не создавались.
