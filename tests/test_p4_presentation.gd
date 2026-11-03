extends GutTest
## P4: unified presentation, camera DOF and debug UI removal.

const CAMPAIGN_DEBUG_SCENES := [
	"res://scenes/campaign/first_nightmare_pass.tscn",
	"res://scenes/campaign/caravan_site_arrival.tscn",
	"res://scenes/campaign/pilgrim_path_arrival.tscn",
]

const SHOT_SCENES := [
	"res://scenes/slice/locations/park/park_street_art.tscn",
	"res://scenes/slice/locations/station_lobby_art.tscn",
	"res://scenes/slice/locations/containment_room_art.tscn",
	"res://scenes/slice/locations/mountain_vision_art.tscn",
	"res://scenes/slice/locations/spell_void.tscn",
]


func _spawn(path: String) -> Node3D:
	var scene := (load(path) as PackedScene).instantiate() as Node3D
	for property in [&"autostart", &"transition_enabled", &"fade_in"]:
		for entry in scene.get_property_list():
			if StringName(entry.get("name", "")) == property:
				scene.set(property, false)
	add_child_autofree(scene)
	return scene


func test_debug_prototype_notes_are_removed() -> void:
	for path in CAMPAIGN_DEBUG_SCENES:
		var scene := _spawn(path)
		assert_null(scene.get_node_or_null("PrototypeNote"), "%s: PrototypeNote удалён" % path)


func test_finale_has_no_prototype_label() -> void:
	var finale := (load("res://scenes/campaign/finale_arrival.tscn") as PackedScene).instantiate() as Node
	finale.set("redirect_without_gate", false)
	finale.set("transition_enabled", false)
	finale.set("fade_in", false)
	finale.set("fast_mode", true)
	add_child_autofree(finale)
	assert_null(finale.get_node_or_null("Center/Column/Prototype"), "finale debug label removed")


func test_all_cutscene_shots_have_dof() -> void:
	for path in SHOT_SCENES:
		var scene := _spawn(path)
		var shots := scene.get_node_or_null(^"Shots")
		assert_not_null(shots, "%s: Shots" % path)
		if shots == null:
			continue
		for child in shots.get_children():
			var camera := child as Camera3D
			if camera == null:
				continue
			assert_true(camera.attributes is CameraAttributesPractical, "%s/%s: CameraAttributesPractical" % [path, camera.name])
			if camera.attributes is CameraAttributesPractical:
				assert_true(camera.attributes.dof_blur_far_enabled, "%s/%s: far DOF" % [path, camera.name])


func test_player_camera_has_no_dof() -> void:
	var sunny := (load("res://scenes/characters/sunny_waking.tscn") as PackedScene).instantiate() as Node3D
	add_child_autofree(sunny)
	await wait_process_frames(1)
	var camera := sunny.get_node_or_null(^"CameraRig/SpringArm3D/Camera3D") as Camera3D
	assert_not_null(camera, "player camera")
	if camera != null:
		assert_null(camera.attributes, "DOF не назначается камере игрока")


func test_campaign_cutscene_cameras_have_dof() -> void:
	var camp := _spawn("res://scenes/campaign/caravan_site_arrival.tscn")
	for name in [&"WagonCamera", &"NightMontageCamera"]:
		var camera := camp.get_node_or_null(NodePath(name)) as Camera3D
		assert_not_null(camera, String(name))
		if camera != null:
			assert_true(camera.attributes is CameraAttributesPractical, "%s: CameraAttributesPractical" % name)
			assert_true(camera.attributes.dof_blur_far_enabled, "%s: far DOF" % name)


func test_alarm_shot_frames_the_desk_not_a_wall() -> void:
	var scene := _spawn("res://scenes/slice/locations/station_lobby_art.tscn")
	var camera := scene.get_node_or_null(^"Shots/AlarmShot") as Camera3D
	assert_not_null(camera, "AlarmShot")
	if camera == null:
		return
	var target := camera.get_node_or_null(^"LookAt") as Node3D
	assert_not_null(target, "AlarmShot/LookAt")
	if target == null:
		return
	assert_lt(camera.global_position.distance_to(target.global_position), 10.0, "AlarmShot смотрит на стол с разумной дистанции")
	assert_almost_eq(target.global_position.x, 0.0, 0.05, "AlarmShot центрирован на столе")
	assert_almost_eq(target.global_position.y, 1.3, 0.05, "AlarmShot смотрит на уровень стола")
	assert_almost_eq(target.global_position.z, -3.2, 0.05, "AlarmShot смотрит вглубь стойки")


func test_shared_campaign_ui_theme_is_applied() -> void:
	var ui := (load("res://scenes/ui/prologue_ui.tscn") as PackedScene).instantiate() as Node
	add_child_autofree(ui)
	await wait_process_frames(1)
	for path in [^"Subtitles", ^"RuneStatus", ^"ObjectiveLine"]:
		var control := ui.get_node_or_null(path) as Control
		assert_not_null(control, String(path))
		if control != null:
			assert_not_null(control.theme, "%s: Theme" % path)
	var root := ui.get_node_or_null(^"CombatHud/Root") as Control
	assert_not_null(root, "CombatHud/Root")
	if root != null:
		assert_not_null(root.theme, "CombatHud использует общий Theme")


func test_p2_and_p3_environments_have_lut() -> void:
	for path in [
		"res://assets/environments/prologue/materials/p2_lobby_environment.tres",
		"res://assets/environments/prologue/materials/p2_cell_environment.tres",
		"res://assets/environments/park/sky/morning_environment.tres",
	]:
		var environment := load(path) as Environment
		assert_not_null(environment, path)
		if environment != null:
			assert_not_null(environment.adjustment_color_correction, "%s: LUT" % path)
	var camp := _spawn("res://scenes/locations/caravan_site/caravan_site_art.tscn")
	var world := camp.get_node_or_null(^"Environment/WorldEnvironment") as WorldEnvironment
	assert_not_null(world, "caravan site WorldEnvironment")
	if world != null and world.environment != null:
		assert_not_null(world.environment.adjustment_color_correction, "caravan site LUT")


func test_debug_ui_text_removed_from_menus() -> void:
	for path in ["res://scenes/ui/main_menu/main_menu.tscn", "res://scenes/ui/rpg_menu_prototype.tscn"]:
		var file := FileAccess.open(path, FileAccess.READ)
		assert_not_null(file, path)
		if file != null:
			var text := file.get_as_text()
			file.close()
			assert_false(text.contains("PROTOTYPE BUILD"), "%s: PROTOTYPE BUILD удалён" % path)
			assert_false(text.contains("PrototypeNote"), "%s: PrototypeNote удалён" % path)
