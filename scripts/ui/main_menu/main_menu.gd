extends Control
## Стартовое меню игры.
##
## Минимальный вход в игру: «Играть» запускает канонический маршрут Первого
## Кошмара, «Настройки» открывают шаблон с разделами «Графика», «Звук» и
## «Управление». Настройки применяются сразу и сохраняются в user://settings.cfg.

const CAMPAIGN_SCENE := "res://scenes/campaign/campaign_entry.tscn"
const POST_NIGHTMARE_SCENE := "res://scenes/locations/post_nightmare/police_precinct.tscn"
const TECH_DEMO_SCENE := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"
const ACADEMY_SCENE := "res://scenes/locations/academy_playable/academy_grounds_playable.tscn"
const CREDITS_PATH := "res://resources/ui/credits.tres"
const FADE_TIME := 0.25
const STATUS_HOLD := 1.6
const STATUS_IDLE := "Изменения применяются сразу"

@onready var _menu_page: Control = %MenuPage
@onready var _settings_page: Control = %SettingsPage
@onready var _play_button: Button = %PlayButton
@onready var _settings_button: Button = %SettingsButton
@onready var _back_button: Button = %BackButton
@onready var _reset_button: Button = %ResetButton
@onready var _status_label: Label = %StatusLabel
@onready var _fade: ColorRect = %Fade

@onready var _graphics_tab: Button = %GraphicsTab
@onready var _sound_tab: Button = %SoundTab
@onready var _controls_tab: Button = %ControlsTab
@onready var _graphics_page: Control = %GraphicsPage
@onready var _sound_page: Control = %SoundPage
@onready var _controls_page: Control = %ControlsPage

@onready var _window_mode_option: OptionButton = %WindowModeOption
@onready var _resolution_option: OptionButton = %ResolutionOption
@onready var _vsync_check: CheckButton = %VsyncCheck
@onready var _fps_option: OptionButton = %FpsOption
@onready var _render_scale_slider: HSlider = %RenderScaleSlider
@onready var _render_scale_value: Label = %RenderScaleValue
@onready var _master_slider: HSlider = %MasterSlider
@onready var _master_value: Label = %MasterValue
@onready var _music_slider: HSlider = %MusicSlider
@onready var _music_value: Label = %MusicValue
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _sfx_value: Label = %SfxValue
@onready var _ambience_slider: HSlider = %AmbienceSlider
@onready var _ambience_value: Label = %AmbienceValue
@onready var _voice_slider: HSlider = %VoiceSlider
@onready var _voice_value: Label = %VoiceValue
@onready var _ui_slider: HSlider = %UiSlider
@onready var _ui_value: Label = %UiValue
@onready var _captions_check: CheckButton = %CaptionsCheck
@onready var _mono_check: CheckButton = %MonoCheck
@onready var _dynamic_range_option: OptionButton = %DynamicRangeOption
@onready var _controls_list: VBoxContainer = %ControlsList

## В тестах можно отключить смену сцены, чтобы проверить состояние входа.
@export var transition_enabled := true

var _settings := GameSettings.new()
var _updating_ui := false
var _launching := false
var _status_generation := 0
var _credits_button: Button
var _post_nightmare_button: Button
var _tech_demo_button: Button
var _academy_button: Button
var _credits_dialog: CreditsDialog
var _demo_label: Label


func _ready() -> void:
	RpgMenuTheme.apply_to(self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_settings.load_settings()
	_settings.apply_input()
	_populate_options()
	_build_controls_list()
	_build_demo_label()
	_build_post_nightmare_ui()
	_build_tech_demo_ui()
	_build_academy_ui()
	_build_credits_ui()
	_connect_signals()
	_sync_ui_from_settings()
	_settings.apply()
	_start_menu_audio()

	_show_settings_page(false)
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and is_settings_open():
		close_settings()
		get_viewport().set_input_as_handled()


func get_settings() -> GameSettings:
	return _settings


func is_settings_open() -> bool:
	return _settings_page.visible


func open_settings() -> void:
	_show_settings_page(true)
	select_tab(0)
	_back_button.grab_focus()


func close_settings() -> void:
	if not is_settings_open():
		return
	_show_settings_page(false)
	_settings_button.grab_focus()


func select_tab(index: int) -> void:
	if index < 0 or index >= 3:
		return
	var tabs: Array[Button] = [_graphics_tab, _sound_tab, _controls_tab]
	var pages: Array[Control] = [_graphics_page, _sound_page, _controls_page]
	for i in tabs.size():
		tabs[i].button_pressed = i == index
	for i in pages.size():
		pages[i].visible = i == index
	_status_label.text = STATUS_IDLE


## Запускает канонический маршрут. Перед сменой сцены экран затемняется.
func start_campaign() -> void:
	if _launching:
		return
	_launching = true
	_play_button.disabled = true
	_settings_button.disabled = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	await tween.finished

	var error := get_tree().change_scene_to_file(CAMPAIGN_SCENE)
	if error != OK:
		push_error("MainMenu: не удалось открыть %s (код %d)" % [CAMPAIGN_SCENE, error])
		_launching = false
		_play_button.disabled = false
		_settings_button.disabled = false
		_fade.modulate.a = 0.0
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Демо-вход в пост-Кошмарную главу. Это не продолжение сохранения:
## состояние выставляется как завершённый Первый Кошмар, чтобы игрок мог
## проверить следующую цепочку без 45-минутного прохождения.
func start_post_nightmare() -> void:
	if _launching:
		return
	_launching = true
	_play_button.disabled = true
	_settings_button.disabled = true
	if _post_nightmare_button != null:
		_post_nightmare_button.disabled = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	await tween.finished

	NightmareRunState.reset()
	for flag in [
		&"prologue_completed", &"campaign_started", &"temple_reached",
		&"trial_completed", &"appraisal_completed", &"awakening_completed",
		&"first_nightmare_finished", &"first_nightmare_completed",
		&"aspect_abilities_unlocked", &"memory_abilities_unlocked",
		&"shadow_core_awakened", &"shadow_control_unlocked",
		&"post_nightmare_started",
	]:
		NightmareRunState.set_flag(flag)
	NightmareRunState.set_item(&"puppeteer_shroud", 1)
	NightmareRunState.set_item(&"shadow_blessing", 1)
	NightmareRunState.set_item(&"silver_bell", 1)
	NightmareRunState.set_current_beat(&"P05")
	LevelPortal.clear_pending_spawn()
	LevelPortal.clear_active_transition()

	if not transition_enabled:
		_launching = false
		return

	var error := get_tree().change_scene_to_file(POST_NIGHTMARE_SCENE)
	if error != OK:
		push_error("MainMenu: не удалось открыть %s (код %d)" % [POST_NIGHTMARE_SCENE, error])
		_launching = false
		_play_button.disabled = false
		_settings_button.disabled = false
		if _post_nightmare_button != null:
			_post_nightmare_button.disabled = false
		_fade.modulate.a = 0.0
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Tech-demo entry: Z01-Z18 without the M1 gate. The flag must be set before
## the labyrinth scene loads so DemoEndZone is disabled and FinalZone is live.
func start_tech_demo() -> void:
	if _launching:
		return
	_launching = true
	_play_button.disabled = true
	_settings_button.disabled = true
	if _post_nightmare_button != null:
		_post_nightmare_button.disabled = true
	if _tech_demo_button != null:
		_tech_demo_button.disabled = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	await tween.finished

	NightmareRunState.reset()
	NightmareRunState.set_flag(&"first_nightmare_completed")
	NightmareRunState.set_flag(&"post_nightmare_started")
	NightmareRunState.set_flag(&"demo_mode_full")
	NightmareRunState.set_current_beat(&"Z01")
	LevelPortal.clear_pending_spawn()
	LevelPortal.clear_active_transition()

	if not transition_enabled:
		_launching = false
		return

	var error := get_tree().change_scene_to_file(TECH_DEMO_SCENE)
	if error != OK:
		push_error("MainMenu: не удалось открыть %s (код %d)" % [TECH_DEMO_SCENE, error])
		_launching = false
		_play_button.disabled = false
		_settings_button.disabled = false
		if _post_nightmare_button != null:
			_post_nightmare_button.disabled = false
		if _tech_demo_button != null:
			_tech_demo_button.disabled = false
		_fade.modulate.a = 0.0
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_demo_label() -> void:
	var title_column := $MenuPage/Frame/Column/Hero/TitleColumn as VBoxContainer
	if title_column == null:
		return
	_demo_label = Label.new()
	_demo_label.name = "DemoLabel"
	_demo_label.theme_type_variation = &"OverlineLabel"
	_demo_label.text = "ДЕМО-ФРАГМЕНТ · M1"
	_demo_label.add_theme_color_override("font_color", RpgMenuTheme.BRONZE_BRIGHT)
	title_column.add_child(_demo_label)
	var kicker := title_column.get_node_or_null(^"Kicker")
	if kicker != null:
		title_column.move_child(_demo_label, kicker.get_index() + 1)


func _build_post_nightmare_ui() -> void:
	var actions := $MenuPage/Frame/Column/Hero/ActionsFrame/ActionsMargin/Actions as VBoxContainer
	_post_nightmare_button = Button.new()
	_post_nightmare_button.name = "PostNightmareButton"
	_post_nightmare_button.custom_minimum_size = Vector2(376, 44)
	_post_nightmare_button.theme_type_variation = &"SecondaryButton"
	_post_nightmare_button.text = "После Кошмара · ДЕМО"
	_post_nightmare_button.tooltip_text = "Демо-глава: участок, академия, Чёрное море и Забытый берег"
	actions.add_child(_post_nightmare_button)
	actions.move_child(_post_nightmare_button, _settings_button.get_index() + 1)


func _build_tech_demo_ui() -> void:
	var actions := $MenuPage/Frame/Column/Hero/ActionsFrame/ActionsMargin/Actions as VBoxContainer
	_tech_demo_button = Button.new()
	_tech_demo_button.name = "TechDemoButton"
	_tech_demo_button.custom_minimum_size = Vector2(376, 44)
	_tech_demo_button.theme_type_variation = &"SecondaryButton"
	_tech_demo_button.text = "Технический фрагмент · Z01–Z18"
	_tech_demo_button.tooltip_text = "Полный Лабиринт: прилив, костяной мост, шторм и утёсы"
	actions.add_child(_tech_demo_button)
	actions.move_child(_tech_demo_button, _post_nightmare_button.get_index() + 1)


## Отдельный playable-сегмент Академии. Он не меняет M1-маршрут: это
## самостоятельный вход в Academy Grounds/Sleeper Center с 24 заданиями.
func start_academy() -> void:
	if _launching:
		return
	_launching = true
	_play_button.disabled = true
	_settings_button.disabled = true
	for button in [_post_nightmare_button, _tech_demo_button, _academy_button]:
		if button != null:
			button.disabled = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	await tween.finished

	NightmareRunState.reset()
	NightmareRunState.set_flag(&"first_nightmare_completed")
	NightmareRunState.set_flag(&"post_nightmare_started")
	NightmareRunState.set_flag(&"academy_chapter_started")
	NightmareRunState.set_current_beat(&"AC01")
	LevelPortal.clear_pending_spawn()
	LevelPortal.clear_active_transition()

	if not transition_enabled:
		_launching = false
		return

	var error := get_tree().change_scene_to_file(ACADEMY_SCENE)
	if error != OK:
		push_error("MainMenu: не удалось открыть %s (код %d)" % [ACADEMY_SCENE, error])
		_launching = false
		_play_button.disabled = false
		_settings_button.disabled = false
		for button in [_post_nightmare_button, _tech_demo_button, _academy_button]:
			if button != null:
				button.disabled = false
		_fade.modulate.a = 0.0
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_academy_ui() -> void:
	var actions := $MenuPage/Frame/Column/Hero/ActionsFrame/ActionsMargin/Actions as VBoxContainer
	_academy_button = Button.new()
	_academy_button.name = "AcademyButton"
	_academy_button.custom_minimum_size = Vector2(376, 44)
	_academy_button.theme_type_variation = &"SecondaryButton"
	_academy_button.text = "Академия · ALPHA"
	_academy_button.tooltip_text = "Кампус, красные ворота, Sleeper Center и 24 задания"
	actions.add_child(_academy_button)
	actions.move_child(_academy_button, _tech_demo_button.get_index() + 1)


func _build_credits_ui() -> void:
	var actions := $MenuPage/Frame/Column/Hero/ActionsFrame/ActionsMargin/Actions as VBoxContainer
	_credits_button = Button.new()
	_credits_button.name = "CreditsButton"
	_credits_button.custom_minimum_size = Vector2(376, 44)
	_credits_button.theme_type_variation = &"SecondaryButton"
	_credits_button.text = "Кредиты и лицензии"
	actions.add_child(_credits_button)
	actions.move_child(_credits_button, _settings_button.get_index() + 1)

	_credits_dialog = CreditsDialog.new()
	_credits_dialog.name = "CreditsDialog"
	add_child(_credits_dialog)
	_credits_button.pressed.connect(open_credits)


func _load_credits_text() -> String:
	var data: Resource = load(CREDITS_PATH)
	if data != null:
		var text := String(data.get(&"text")).strip_edges()
		if not text.is_empty():
			return text
	return "Полный список лицензий: docs/ASSET_LICENSES.md."


func open_credits() -> void:
	if _credits_dialog == null:
		return
	_credits_dialog.present("Кредиты и лицензии", _load_credits_text())


func _show_settings_page(visible_now: bool) -> void:
	_settings_page.visible = visible_now
	_menu_page.visible = not visible_now
	if visible_now:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _connect_signals() -> void:
	_play_button.pressed.connect(start_campaign)
	if _post_nightmare_button != null:
		_post_nightmare_button.pressed.connect(start_post_nightmare)
	if _tech_demo_button != null:
		_tech_demo_button.pressed.connect(start_tech_demo)
	if _academy_button != null:
		_academy_button.pressed.connect(start_academy)
	_settings_button.pressed.connect(open_settings)
	_back_button.pressed.connect(close_settings)
	_reset_button.pressed.connect(_on_reset_pressed)

	_graphics_tab.pressed.connect(select_tab.bind(0))
	_sound_tab.pressed.connect(select_tab.bind(1))
	_controls_tab.pressed.connect(select_tab.bind(2))

	_window_mode_option.item_selected.connect(_on_window_mode_selected)
	_resolution_option.item_selected.connect(_on_resolution_selected)
	_vsync_check.toggled.connect(_on_vsync_toggled)
	_fps_option.item_selected.connect(_on_fps_selected)
	_render_scale_slider.value_changed.connect(_on_render_scale_changed)
	_master_slider.value_changed.connect(_on_master_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_ambience_slider.value_changed.connect(_on_ambience_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_voice_slider.value_changed.connect(_on_voice_changed)
	_ui_slider.value_changed.connect(_on_ui_changed)
	_captions_check.toggled.connect(_on_captions_toggled)
	_mono_check.toggled.connect(_on_mono_toggled)
	_dynamic_range_option.item_selected.connect(_on_dynamic_range_selected)

	for button in find_children("*", "BaseButton", true, false):
		button.pressed.connect(_on_any_button_pressed)
		button.mouse_entered.connect(_on_button_hovered)
		button.focus_entered.connect(_on_button_hovered)


func _populate_options() -> void:
	_window_mode_option.clear()
	_window_mode_option.add_item("Оконный")
	_window_mode_option.add_item("Полноэкранный")

	_resolution_option.clear()
	for resolution in GameSettings.RESOLUTIONS:
		_resolution_option.add_item("%d × %d" % [resolution.x, resolution.y])

	_fps_option.clear()
	for fps in GameSettings.FPS_OPTIONS:
		_fps_option.add_item("Без ограничения" if fps == 0 else str(fps))


func _sync_ui_from_settings() -> void:
	_updating_ui = true

	_window_mode_option.select(1 if _settings.fullscreen else 0)
	_resolution_option.disabled = _settings.fullscreen
	_resolution_option.select(maxi(GameSettings.RESOLUTIONS.find(_settings.resolution), 0))
	_vsync_check.button_pressed = _settings.vsync_enabled
	_sync_vsync_text()
	_fps_option.select(maxi(GameSettings.FPS_OPTIONS.find(_settings.max_fps), 0))

	_render_scale_slider.value = roundi(_settings.render_scale * 100.0)
	_render_scale_value.text = "%d%%" % roundi(_settings.render_scale * 100.0)
	_master_slider.value = roundi(_settings.master_volume * 100.0)
	_music_slider.value = roundi(_settings.music_volume * 100.0)
	_ambience_slider.value = roundi(_settings.ambience_volume * 100.0)
	_sfx_slider.value = roundi(_settings.sfx_volume * 100.0)
	_voice_slider.value = roundi(_settings.voice_volume * 100.0)
	_ui_slider.value = roundi(_settings.ui_volume * 100.0)
	_sync_volume_labels()
	_captions_check.button_pressed = _settings.captions_enabled
	_mono_check.button_pressed = _settings.mono_downmix
	_sync_accessibility_text()
	if _dynamic_range_option.item_count == 0:
		_dynamic_range_option.add_item("Полный")
		_dynamic_range_option.add_item("Сниженный")
	_dynamic_range_option.select(clampi(_settings.dynamic_range, 0, 1))

	_updating_ui = false


func _sync_vsync_text() -> void:
	_vsync_check.text = "Включена" if _settings.vsync_enabled else "Выключена"


func _sync_accessibility_text() -> void:
	_captions_check.text = "Включены" if _settings.captions_enabled else "Выключены"
	_mono_check.text = "Включено" if _settings.mono_downmix else "Выключено"


func _sync_volume_labels() -> void:
	_master_value.text = "%d%%" % roundi(_settings.master_volume * 100.0)
	_music_value.text = "%d%%" % roundi(_settings.music_volume * 100.0)
	_ambience_value.text = "%d%%" % roundi(_settings.ambience_volume * 100.0)
	_sfx_value.text = "%d%%" % roundi(_settings.sfx_volume * 100.0)
	_voice_value.text = "%d%%" % roundi(_settings.voice_volume * 100.0)
	_ui_value.text = "%d%%" % roundi(_settings.ui_volume * 100.0)


func _on_window_mode_selected(index: int) -> void:
	if _updating_ui:
		return
	_settings.fullscreen = index == 1
	_resolution_option.disabled = _settings.fullscreen
	_commit_settings()


func _on_resolution_selected(index: int) -> void:
	if _updating_ui or index < 0 or index >= GameSettings.RESOLUTIONS.size():
		return
	_settings.resolution = GameSettings.RESOLUTIONS[index]
	_commit_settings()


func _on_vsync_toggled(enabled: bool) -> void:
	if _updating_ui:
		return
	_settings.vsync_enabled = enabled
	_sync_vsync_text()
	_commit_settings()


func _on_fps_selected(index: int) -> void:
	if _updating_ui or index < 0 or index >= GameSettings.FPS_OPTIONS.size():
		return
	_settings.max_fps = GameSettings.FPS_OPTIONS[index]
	_commit_settings()


func _on_render_scale_changed(value: float) -> void:
	if _updating_ui:
		return
	_settings.render_scale = clampf(value / 100.0, 0.5, 1.0)
	_render_scale_value.text = "%d%%" % roundi(value)
	_commit_settings()


func _on_master_changed(value: float) -> void:
	if _updating_ui:
		return
	_settings.master_volume = clampf(value / 100.0, 0.0, 1.0)
	_sync_volume_labels()
	_play_ui("slider")
	_commit_settings(true)


func _on_music_changed(value: float) -> void:
	if _updating_ui:
		return
	_settings.music_volume = clampf(value / 100.0, 0.0, 1.0)
	_sync_volume_labels()
	_play_ui("slider")
	_commit_settings(true)


func _on_sfx_changed(value: float) -> void:
	if _updating_ui:
		return
	_settings.sfx_volume = clampf(value / 100.0, 0.0, 1.0)
	_sync_volume_labels()
	_play_ui("slider")
	_commit_settings(true)


func _on_ambience_changed(value: float) -> void:
	if _updating_ui:
		return
	_settings.ambience_volume = clampf(value / 100.0, 0.0, 1.0)
	_sync_volume_labels()
	_play_ui("slider")
	_commit_settings(true)


func _on_voice_changed(value: float) -> void:
	if _updating_ui:
		return
	_settings.voice_volume = clampf(value / 100.0, 0.0, 1.0)
	_sync_volume_labels()
	_play_ui("slider")
	_commit_settings(true)


func _on_ui_changed(value: float) -> void:
	if _updating_ui:
		return
	_settings.ui_volume = clampf(value / 100.0, 0.0, 1.0)
	_sync_volume_labels()
	_play_ui("slider")
	_commit_settings(true)


func _on_captions_toggled(enabled: bool) -> void:
	if _updating_ui:
		return
	_settings.captions_enabled = enabled
	_sync_accessibility_text()
	_commit_settings(true)


func _on_mono_toggled(enabled: bool) -> void:
	if _updating_ui:
		return
	_settings.mono_downmix = enabled
	_sync_accessibility_text()
	_commit_settings(true)


func _on_dynamic_range_selected(index: int) -> void:
	if _updating_ui:
		return
	_settings.dynamic_range = clampi(index, 0, 1)
	_commit_settings(true)


func _on_reset_pressed() -> void:
	_settings.reset_defaults()
	_settings.reset_all_bindings()
	_sync_ui_from_settings()
	_settings.apply()
	_settings.save_settings()
	_refresh_binding_rows()
	_flash_status("Настройки сброшены")


func _start_menu_audio() -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director == null:
		return
	director.call(&"play_music", &"menu", 1.5)
	director.call(&"play_ambience", &"menu", 1.5)
	if director.has_method(&"set_reverb_profile"):
		director.call(&"set_reverb_profile", &"outdoor")


func _play_ui(id: String) -> void:
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.is_node_ready() and director.has_method(&"play_ui"):
		director.call(&"play_ui", StringName("ui_" + id))


func _on_any_button_pressed() -> void:
	_play_ui("click")


func _on_button_hovered() -> void:
	_play_ui("hover")


func _commit_settings(audio_only := false) -> void:
	if audio_only:
		_settings.apply_audio()
	else:
		_settings.apply_graphics()
	_settings.save_settings()
	_flash_status("Сохранено")


func _flash_status(message: String) -> void:
	_status_generation += 1
	var generation := _status_generation
	_status_label.text = message
	await get_tree().create_timer(STATUS_HOLD).timeout
	if generation == _status_generation and is_instance_valid(_status_label):
		_status_label.text = STATUS_IDLE


func _build_controls_list() -> void:
	for child in _controls_list.get_children():
		_controls_list.remove_child(child)
		child.queue_free()

	var reset_bindings := Button.new()
	reset_bindings.text = "СБРОСИТЬ УПРАВЛЕНИЕ"
	reset_bindings.tooltip_text = "Вернуть все клавиши из project.godot"
	reset_bindings.theme_type_variation = &"SecondaryButton"
	reset_bindings.custom_minimum_size = Vector2(260, 34)
	reset_bindings.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset_bindings.pressed.connect(_on_reset_bindings_pressed)
	_controls_list.add_child(reset_bindings)

	for section in InputBindings.SECTIONS:
		var header := Label.new()
		header.theme_type_variation = &"SectionLabel"
		header.text = str(section["title"])
		header.custom_minimum_size.y = 18.0
		_controls_list.add_child(header)

		for action in section["actions"]:
			if not InputMap.has_action(action):
				continue
			var row := InputBindingRow.new()
			row.setup(_settings, action)
			row.binding_changed.connect(_on_binding_changed)
			_controls_list.add_child(row)


func _refresh_binding_rows() -> void:
	for child in _controls_list.get_children():
		if child is InputBindingRow:
			(child as InputBindingRow).refresh()


func _on_binding_changed(_action: StringName, message: String) -> void:
	_flash_status(message)


func _on_reset_bindings_pressed() -> void:
	_settings.reset_all_bindings()
	_settings.save_settings()
	_refresh_binding_rows()
	_flash_status("Управление сброшено")
