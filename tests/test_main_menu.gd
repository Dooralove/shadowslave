extends GutTest
## Стартовое меню: две кнопки входа, страница настроек, вкладки и список
## управления из Input Map.

const MENU_SCENE_PATH := "res://scenes/ui/main_menu/main_menu.tscn"
const CAMPAIGN_SCENE := "res://scenes/campaign/campaign_entry.tscn"

var _menu
var _previous_mouse := Input.MOUSE_MODE_VISIBLE
var _previous_max_fps := 0
var _previous_scale := 1.0


func before_each() -> void:
	_previous_mouse = Input.mouse_mode
	_previous_max_fps = Engine.max_fps
	_previous_scale = get_tree().root.scaling_3d_scale
	_menu = (load(MENU_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(_menu)
	await get_tree().process_frame


func after_each() -> void:
	Engine.max_fps = _previous_max_fps
	get_tree().root.scaling_3d_scale = _previous_scale
	Input.mouse_mode = _previous_mouse
	var settings := GameSettings.new()
	settings.reset_all_bindings()


func _find(node_name: String) -> Node:
	return _menu.find_child(node_name, true, false)


func test_menu_starts_with_play_and_settings_buttons() -> void:
	var play := _find("PlayButton") as Button
	var settings := _find("SettingsButton") as Button
	assert_not_null(play, "кнопка «Играть» существует")
	assert_not_null(settings, "кнопка «Настройки» существует")
	assert_eq(play.text, "ИГРАТЬ")
	assert_eq(settings.text, "НАСТРОЙКИ")
	assert_true(play.visible, "кнопка «Играть» видна на старте")
	assert_true(settings.visible, "кнопка «Настройки» видна на старте")
	assert_eq(_find("MenuPage").visible, true, "стартовая страница показана")
	assert_false(_menu.is_settings_open(), "настройки на старте закрыты")


func test_play_launches_canonical_campaign_scene() -> void:
	assert_true(ResourceLoader.exists(CAMPAIGN_SCENE), "сцена кампании существует")
	var constants: Dictionary = _menu.get_script().get_script_constant_map()
	assert_eq(constants.get("CAMPAIGN_SCENE"), CAMPAIGN_SCENE, "меню ведёт в campaign_entry")


func test_settings_open_and_close() -> void:
	_menu.open_settings()
	assert_true(_menu.is_settings_open(), "настройки открываются")
	assert_eq(_find("SettingsPage").visible, true)
	assert_eq(_find("MenuPage").visible, false, "стартовая страница скрыта")
	assert_eq(_find("GraphicsPage").visible, true, "первая вкладка — графика")

	_menu.close_settings()
	assert_false(_menu.is_settings_open(), "настройки закрываются")
	assert_eq(_find("SettingsPage").visible, false)
	assert_eq(_find("MenuPage").visible, true, "стартовая страница возвращается")


func test_tabs_switch_settings_pages() -> void:
	var graphics := _find("GraphicsPage") as Control
	var sound := _find("SoundPage") as Control
	var controls := _find("ControlsPage") as Control
	assert_not_null(graphics)
	assert_not_null(sound)
	assert_not_null(controls)

	_menu.select_tab(1)
	assert_true(sound.visible, "вкладка звука показана")
	assert_false(graphics.visible, "графика скрыта")
	assert_false(controls.visible, "управление скрыто")
	assert_true((_find("SoundTab") as Button).button_pressed)

	_menu.select_tab(2)
	assert_true(controls.visible, "вкладка управления показана")
	assert_false(sound.visible, "звук скрыт")
	assert_true((_find("ControlsTab") as Button).button_pressed)


func test_graphics_and_sound_controls_are_populated() -> void:
	var window_mode := _find("WindowModeOption") as OptionButton
	var resolution := _find("ResolutionOption") as OptionButton
	var fps := _find("FpsOption") as OptionButton
	assert_eq(window_mode.item_count, 2, "два режима окна")
	assert_eq(resolution.item_count, GameSettings.RESOLUTIONS.size(), "список разрешений заполнен")
	assert_eq(fps.item_count, GameSettings.FPS_OPTIONS.size(), "список FPS заполнен")
	assert_eq((_find("MasterSlider") as HSlider).max_value, 100.0)
	assert_eq((_find("MusicSlider") as HSlider).max_value, 100.0)
	assert_eq((_find("SfxSlider") as HSlider).max_value, 100.0)


func test_controls_page_lists_input_map_actions() -> void:
	var list := _find("ControlsList") as VBoxContainer
	assert_not_null(list, "список управления существует")
	assert_gt(list.get_child_count(), 10, "строки управления построены из Input Map")
	assert_true(_find("GraphicsTab") is Button)
	assert_true(_find("BackButton") is Button, "кнопка возврата существует")
	assert_true(_find("ResetButton") is Button, "кнопка сброса существует")


func test_tech_demo_entry_exists_and_sets_mode() -> void:
	NightmareRunState.reset()
	var button := _find("TechDemoButton") as Button
	assert_not_null(button, "TechDemoButton exists")
	var constants: Dictionary = _menu.get_script().get_script_constant_map()
	assert_eq(
		constants.get("TECH_DEMO_SCENE"),
		"res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn",
		"tech demo entry points to the labyrinth"
	)
	assert_true(ResourceLoader.exists(constants.get("TECH_DEMO_SCENE")), "tech demo scene exists")

	_menu.transition_enabled = false
	await _menu.start_tech_demo()
	assert_true(NightmareRunState.has_flag(&"demo_mode_full"), "tech demo sets demo_mode_full")
	assert_true(NightmareRunState.has_flag(&"post_nightmare_started"), "tech demo sets post_nightmare_started")
	assert_eq(NightmareRunState.get_current_beat(), &"Z01", "tech demo starts at Z01")
	NightmareRunState.reset()


func test_post_nightmare_entry_exists_and_sets_state() -> void:
	NightmareRunState.reset()
	var button := _find("PostNightmareButton") as Button
	assert_not_null(button, "кнопка «После Кошмара» существует")
	var constants: Dictionary = _menu.get_script().get_script_constant_map()
	assert_eq(
		constants.get("POST_NIGHTMARE_SCENE"),
		"res://scenes/locations/post_nightmare/police_precinct.tscn",
		"меню ведёт в начало пост-Кошмарной цепочки"
	)
	assert_true(ResourceLoader.exists(constants.get("POST_NIGHTMARE_SCENE")), "сцена участка существует")

	_menu.transition_enabled = false
	await _menu.start_post_nightmare()
	assert_true(NightmareRunState.has_flag(&"post_nightmare_started"), "флаг старта выставлен")
	assert_true(NightmareRunState.has_flag(&"first_nightmare_completed"), "Кошмар считается завершённым")
	assert_true(NightmareRunState.has_item(&"puppeteer_shroud"), "награда оценки выдана")
	assert_eq(NightmareRunState.get_current_beat(), &"P05", "текущий бит — начало пост-Кошмара")
	NightmareRunState.reset()
