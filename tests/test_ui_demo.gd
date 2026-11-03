extends GutTest
## Проверки демонстрационного UI: живая цель, журнал, карта Лабиринта,
## меню паузы и условные маркеры.

const LABYRINTH_MAP := "res://resources/map/locations/labyrinth_first_fragment.tres"
const PAUSE_SCENE := "res://scenes/ui/pause_menu/pause_menu.tscn"
const QUEST_SCREEN := "res://scenes/ui/rpg_menu/quest_screen.tscn"
const OBJECTIVE_SCENE := "res://scenes/ui/objective_line.tscn"


func before_each() -> void:
	NightmareRunState.reset()
	CampaignGuide.reset_campaign()
	QuestSystem.deactivate_scope()


func after_each() -> void:
	QuestSystem.deactivate_scope()
	CampaignGuide.reset_campaign()
	NightmareRunState.reset()
	var settings := GameSettings.new()
	settings.reset_all_bindings()


func test_labyrinth_map_matches_scene_bounds_and_markers() -> void:
	var map := load(LABYRINTH_MAP) as MapDefinition
	assert_not_null(map, "карта Лабиринта загружается")
	if map == null:
		return
	assert_eq(map.id, &"labyrinth_first_fragment")
	assert_true(map.scene_paths.has("res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"))
	assert_eq(map.world_bounds, Rect2(-1470, -160, 1520, 320), "границы совпадают с полем сцены")
	var fork := map.marker_by_id(&"first_fork")
	var camp := map.marker_by_id(&"camp")
	var cliffs := map.marker_by_id(&"cliffs")
	assert_not_null(fork, "первая развилка отмечена")
	assert_not_null(camp, "лагерь отмечен")
	assert_not_null(cliffs, "утёсы отмечены")
	if fork != null:
		assert_eq(fork.world_position, Vector2(0, 0))
	if camp != null:
		assert_eq(camp.world_position, Vector2(-100, -5))
	if cliffs != null:
		assert_eq(cliffs.world_position, Vector2(-1400, 0))
	assert_gt(map.markers.size(), 10, "на карте есть места и опасности")


func test_map_system_resolves_labyrinth_by_map_id() -> void:
	var fake := Node3D.new()
	fake.name = "LabyrinthProbe"
	fake.set_meta(&"map_id", &"labyrinth_first_fragment")
	add_child_autofree(fake)
	var resolved := MapSystem.resolve_location_for(fake)
	assert_eq(resolved.id, &"labyrinth_first_fragment", "атлас находит карту Лабиринта")
	assert_eq(resolved.title, "ЛАБИРИНТ ЗАБЫТОГО БЕРЕГА")


func test_labyrinth_region_is_playable_and_composes_map() -> void:
	var atlas := load("res://resources/map/map_atlas.tres") as MapAtlas
	assert_not_null(atlas)
	if atlas == null:
		return
	var location := atlas.get_location(&"labyrinth_first_fragment")
	var region := atlas.get_region(&"region_forgotten_shore")
	assert_not_null(location, "локация Лабиринта в атласе")
	assert_not_null(region, "регион Забытого берега в атласе")
	if location == null or region == null:
		return
	assert_true(region.is_playable(), "регион доступен для демо")
	var composed := atlas.compose_region_map(region)
	assert_not_null(composed, "карта региона собирается")
	if composed != null:
		assert_gt(composed.markers.size(), 10, "маркеры локации перенесены")
		assert_true(composed.marker_by_id(&"labyrinth_first_fragment/camp") != null)


func test_map_screen_opens_labyrinth_region_and_shows_tracked_objective() -> void:
	QuestSystem.activate_scope(&"forgotten_shore")
	QuestSystem.refresh_auto_start()
	var atlas := load("res://resources/map/map_atlas.tres") as MapAtlas
	var region := atlas.get_region(&"region_forgotten_shore")
	var screen := (load("res://scenes/ui/rpg_menu/map_screen.tscn") as PackedScene).instantiate() as RpgMapScreen
	add_child_autofree(screen)
	await wait_process_frames(1)
	screen.setup(atlas)
	assert_true(screen.show_region(region), "карта региона открывается")
	assert_eq(screen.get_mode(), "region")
	assert_eq(screen.get_displayed_region_id(), &"region_forgotten_shore")
	var objective_line := screen.get("_objective_line") as Label
	assert_not_null(objective_line)
	if objective_line != null:
		assert_string_contains(objective_line.text, "Первый день", "строка цели видна на карте")
	var list := screen.get("_list") as VBoxContainer
	assert_not_null(list)
	if list != null:
		assert_gt(list.get_child_count(), 0, "маркеры Лабиринта попали в список")


func test_map_screen_opens_local_m1_scene_geometry() -> void:
	var atlas := load("res://resources/map/map_atlas.tres") as MapAtlas
	var location := atlas.get_location(&"police_precinct")
	var screen := (load("res://scenes/ui/rpg_menu/map_screen.tscn") as PackedScene).instantiate() as RpgMapScreen
	add_child_autofree(screen)
	await wait_process_frames(1)
	screen.setup(atlas)
	assert_true(screen.show_local(location), "локальная карта участка открывается")
	assert_eq(screen.get_mode(), "local")
	assert_eq(screen.displayed_map.id, &"police_precinct")
	var list := screen.get("_list") as VBoxContainer
	assert_not_null(list)
	if list != null:
		assert_gt(list.get_child_count(), 0, "места участка попали в список")


func test_marker_hide_flag_removes_collected_pickup() -> void:
	var marker := MapMarker.new()
	marker.id = &"shard"
	marker.hide_when_flag = &"shard_taken"
	assert_true(marker.is_visible_with({}), "до подбора маркер виден")
	assert_false(marker.is_visible_with({&"shard_taken": true}), "после подбора маркер скрыт")


func test_objective_line_reads_live_quest_and_updates_progress() -> void:
	QuestSystem.activate_scope(&"forgotten_shore")
	QuestSystem.refresh_auto_start()
	var line := (load(OBJECTIVE_SCENE) as PackedScene).instantiate() as ObjectiveLine
	add_child_autofree(line)
	await wait_process_frames(1)
	assert_true(line.is_showing(), "строка читает задание QuestSystem")
	assert_string_contains(line.get_objective_text(), "первой развилки")

	QuestSystem.notify_event(&"reached", &"first_fork")
	await wait_process_frames(1)
	assert_string_contains(line.get_objective_text(), "Нефис", "цель обновилась после события")


func test_quest_journal_uses_live_definitions_and_tracking() -> void:
	QuestSystem.activate_scope(&"forgotten_shore")
	QuestSystem.refresh_auto_start()
	var screen := (load(QUEST_SCREEN) as PackedScene).instantiate() as RpgQuestScreen
	add_child_autofree(screen)
	await wait_process_frames(1)
	assert_true(screen.quests.size() >= 1, "журнал загружает живые задания")
	var objective := screen.get_node("%CurrentObjective") as Label
	assert_string_contains(objective.text, "Первый день", "текущая цель — из QuestSystem")
	var track := screen.get_node_or_null("Columns/LeftPanel/LeftColumn/TrackButton") as Button
	assert_not_null(track, "кнопка отслеживания создана")
	if track != null:
		assert_true(track.visible, "активное задание можно отслеживать")


func test_post_nightmare_scene_gets_hud_and_objective() -> void:
	var packed := load("res://scenes/locations/post_nightmare/police_precinct.tscn") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var scene := packed.instantiate() as GreyboxLocation
	add_child_autofree(scene)
	await wait_process_frames(2)
	var hud := scene.get_node_or_null(^"GameplayHud") as GameplayHud
	assert_not_null(hud, "пост-Кошмарная сцена получает GameplayHud")
	if hud == null:
		return
	var line := hud.get_node_or_null(^"ObjectiveLine") as ObjectiveLine
	assert_not_null(line, "строка цели подключена")
	if line != null:
		# Guide-only contract: the scene is instantiated as a child in tests, so
		# _setup_post_nightmare_demo() intentionally does not run. Feed the same
		# external objective through the public scene API and verify HUD wiring.
		scene.set_scene_objective("Очнуться в участке. Найти выход к академии.")
		await wait_process_frames(1)
		assert_string_contains(line.get_objective_text(), "участке", "цель сцены берётся из M1-каталога")
	assert_not_null(hud.get_node_or_null(^"DialogueRunner"), "диалоги получают runner")


func test_pause_menu_has_navigation_settings_and_controls() -> void:
	var pause := (load(PAUSE_SCENE) as PackedScene).instantiate() as PauseMenu
	add_child_autofree(pause)
	await wait_process_frames(1)
	pause.open()
	assert_true(pause.is_open(), "меню паузы открывается")
	var nav := pause.get_node("%Nav") as VBoxContainer
	assert_gte(nav.get_child_count(), 4, "разделы паузы созданы")
	var content := pause.get_node("%Content") as VBoxContainer
	assert_gt(content.get_child_count(), 1)
	pause.call(&"_show_section", &"settings")
	assert_gt(content.get_child_count(), 5, "в настройках есть громкость и режим экрана")
	pause.call(&"_show_section", &"controls")
	assert_gt(content.get_child_count(), 8, "экран управления строится из InputMap")
	pause.call(&"_show_section", &"quests")
	assert_gt(content.get_child_count(), 2, "экран текущей цели открывается")
	pause.close()
	assert_false(pause.is_open())


func test_pause_menu_audio_settings_cover_all_buses() -> void:
	var pause := (load(PAUSE_SCENE) as PackedScene).instantiate() as PauseMenu
	add_child_autofree(pause)
	await wait_process_frames(1)
	pause.open()
	pause.call(&"_show_section", &"settings")
	var content := pause.get_node("%Content") as VBoxContainer
	for slider_name in [
		"MasterSlider", "MusicSlider", "SfxSlider", "AmbienceSlider", "VoiceSlider", "UiSlider"
	]:
		var slider := content.find_child(slider_name, true, false) as HSlider
		assert_not_null(slider, "слайдер %s существует" % slider_name)
		if slider != null:
			assert_eq(slider.max_value, 100.0, "%s работает в процентах" % slider_name)
	assert_not_null(content.find_child("CaptionsCheck", true, false), "субтитры звуков доступны из паузы")
	assert_not_null(content.find_child("MonoCheck", true, false), "моно-сведение доступно из паузы")
	assert_not_null(content.find_child("DynamicRangeOption", true, false), "динамический диапазон доступен из паузы")


func test_pause_menu_controls_are_rebindable() -> void:
	var pause := (load(PAUSE_SCENE) as PackedScene).instantiate() as PauseMenu
	add_child_autofree(pause)
	await wait_process_frames(1)
	pause.open()
	pause.call(&"_show_section", &"controls")
	var content := pause.get_node("%Content") as VBoxContainer
	var rows := 0
	for child in content.get_children():
		if child is InputBindingRow:
			rows += 1
	assert_gt(rows, 10, "все основные действия доступны для переназначения")
	assert_not_null(content.find_child("BindButton", true, false), "у строки есть кнопка привязки")
	assert_not_null(content.find_child("ResetButton", true, false), "у строки есть сброс")
