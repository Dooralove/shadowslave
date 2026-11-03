extends Node
## P4 review capture: key moments with the unified campaign UI.
## The captures use the real shot cameras (and their shared cutscene DOF), not
## a free-fly audit camera, so framing and depth of field match play.

var _out := ""


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		push_error("p4_capture: нужен --out=<каталог>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().root.size = Vector2i(1280, 720)

	await _capture_park()
	await _capture_lobby()
	await _capture_cell()
	await _capture_spell_void()
	await _capture_camp()
	await _capture_trail()
	await _capture_sanctuary()
	await _capture_ui_language()

	print("p4_capture: done out=", _out)
	get_tree().quit(0)


func _instantiate(path: String) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("p4_capture: cannot load " + path)
		return null
	var scene := packed.instantiate() as Node3D
	get_tree().root.add_child(scene)
	for i in 10:
		await get_tree().process_frame
	return scene


func _add_ui(scene: Node3D, objective := "", hint := "", speaker := "", line := "") -> PrologueUI:
	var ui := (load("res://scenes/ui/prologue_ui.tscn") as PackedScene).instantiate() as PrologueUI
	scene.add_child(ui)
	await get_tree().process_frame
	ui.fade.visible = false
	ui.drowsiness.visible = false
	ui.hint.visible = false
	ui.subtitles.hide_line()
	ui.combat_hud.visible = false
	if not objective.is_empty():
		ui.objective_line.show_objective(objective, 0, true)
	if not hint.is_empty():
		ui.show_hint(hint)
	if not line.is_empty():
		ui.subtitles.show_line(speaker, line, true)
	await get_tree().process_frame
	return ui


func _ui_for_campaign(scene: Node3D) -> PrologueUI:
	var ui := scene.get_node_or_null(^"UI") as PrologueUI
	if ui == null:
		return null
	ui.fade.visible = false
	ui.drowsiness.visible = false
	ui.subtitles.hide_line()
	ui.combat_hud.visible = false
	# The campaign wrapper has its own Transition/NightTint layers; hide only those,
	# keep the actual PrologueUI visible for the review shot.
	for canvas in scene.find_children("*", "CanvasLayer", true, false):
		if canvas != ui:
			(canvas as CanvasLayer).visible = false
	return ui


func _capture_park() -> void:
	var scene := await _instantiate("res://scenes/slice/locations/park/park_street_art.tscn")
	await _add_ui(
		scene,
		"Найти тихое место",
		"Утро перед сменой. Не привлекай внимания.",
		"Санни",
		"Здесь можно выдохнуть. Ненадолго."
	)
	var camera := scene.get_node_or_null(^"Shots/DozeShot") as Camera3D
	if camera != null:
		camera.make_current()
	await _save("park_ui.png")
	await _free(scene)


func _capture_lobby() -> void:
	var scene := await _instantiate("res://scenes/slice/locations/station_lobby_art.tscn")
	scene.call(&"_start_alarm", true)
	await _add_ui(
		scene,
		"Не привлекать внимания",
		"Code Black. Оставайся на месте.",
		"",
		""
	)
	var camera := scene.get_node_or_null(^"Shots/AlarmShot") as Camera3D
	if camera != null:
		camera.make_current()
	await _save("lobby_alarm_ui.png")
	await _free(scene)


func _capture_cell() -> void:
	var scene := await _instantiate("res://scenes/slice/locations/containment_room_art.tscn")
	await _add_ui(
		scene,
		"Ждать",
		"Разговор закончился. Тебя ведут в Первый Кошмар.",
		"Санни",
		"Я не помню, как оказался здесь."
	)
	var camera := scene.get_node_or_null(^"Shots/RoomShot") as Camera3D
	if camera != null:
		camera.make_current()
	await _save("containment_ui.png")
	await _free(scene)


func _capture_spell_void() -> void:
	var scene := await _instantiate("res://scenes/slice/locations/spell_void.tscn")
	scene.call(&"play_cutscene", &"spell", true)
	var ui := await _add_ui(scene, "", "", "")
	ui.spell_message.show_text("Аспирант! Добро пожаловать в Кошмарное Заклинание.", 30.0)
	var camera := scene.get_node_or_null(^"Shots/SpellShot") as Camera3D
	if camera != null:
		camera.make_current()
	await _save("spell_void_ui.png")
	await _free(scene)


func _capture_camp() -> void:
	var scene := await _instantiate("res://scenes/campaign/caravan_site_arrival.tscn")
	var ui := _ui_for_campaign(scene)
	if ui != null:
		ui.show_hint("Привал. Найди взгляд на лагерь.")
		ui.objective_line.show_objective("Осмотреться у костра", 0, true)
		ui.subtitles.show_line("Санни", "Дым, цепи и чужие голоса.", true)
	scene.call(&"_stage_wagon_camera")
	await _save("wagon_camera_ui.png")
	scene.call(&"_stage_night_camera")
	await _save("night_montage_ui.png")
	await _free(scene)


func _capture_trail() -> void:
	var scene := await _instantiate("res://scenes/locations/pilgrim_path/pilgrim_path_art.tscn")
	await _add_ui(
		scene,
		"Подняться к храму",
		"Тропа уходит вверх. Не смотри вниз.",
		"Санни",
		"Каждый шаг отдаётся в костях."
	)
	var camera := Camera3D.new()
	camera.fov = 58.0
	camera.far = 1200.0
	camera.attributes = load("res://resources/cameras/p4_cutscene_dof.tres")
	scene.add_child(camera)
	camera.global_position = Vector3(0.0, 1.8, 8.5)
	camera.look_at(Vector3(0.0, 2.4, -20.0), Vector3.UP)
	camera.make_current()
	await _save("pilgrim_trail_ui.png")
	camera.queue_free()
	await _free(scene)


func _capture_sanctuary() -> void:
	var scene := await _instantiate("res://scenes/locations/shadow_sanctuary/shadow_sanctuary_art.tscn")
	await _add_ui(
		scene,
		"Войти в храм",
		"Святилище Тени. Здесь заканчивается Первый Кошмар.",
		"",
		""
	)
	var camera := Camera3D.new()
	camera.fov = 56.0
	camera.far = 1200.0
	camera.attributes = load("res://resources/cameras/p4_cutscene_dof.tres")
	scene.add_child(camera)
	camera.global_position = Vector3(0.0, 2.2, 4.8)
	camera.look_at(Vector3(0.0, 2.2, -5.0), Vector3.UP)
	camera.make_current()
	await _save("sanctuary_ui.png")
	camera.queue_free()
	await _free(scene)


func _capture_ui_language() -> void:
	var scene := await _instantiate("res://scenes/slice/locations/station_lobby_art.tscn")
	var ui := await _add_ui(
		scene,
		"Не привлекать внимания",
		"Code Black. Оставайся на месте.",
		"Санни",
		"Главное — не выделяться."
	)
	var camera := scene.get_node_or_null(^"Shots/DeskShot") as Camera3D
	if camera != null:
		camera.make_current()
	await _save("ui_language.png")
	if ui != null:
		ui.queue_free()
	await _free(scene)


func _save(file_name: String) -> void:
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(_out.path_join(file_name))


func _free(scene: Node) -> void:
	if scene != null:
		scene.queue_free()
	for i in 4:
		await get_tree().process_frame
