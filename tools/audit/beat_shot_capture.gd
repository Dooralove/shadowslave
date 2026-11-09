extends SceneTree
## Шесть кадров ключевых beat-ов через реальные камеры BeatStage.
## Запуск:
##   godot --path . -s tools/audit/beat_shot_capture.gd -- --out=<dir>

const CAMP_WRAPPER := "res://scenes/campaign/caravan_site_arrival.tscn"
const PILGRIM_WRAPPER := "res://scenes/campaign/pilgrim_path_arrival.tscn"
const SHOT_WAIT := 0.9

var _out := ""


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		_out = OS.get_environment("TEMP").path_join("opencode/beats")
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(1600, 900)
	await _capture_camp()
	await _capture_pilgrim()
	quit(0)


func _capture_camp() -> void:
	var wrapper := await _spawn(CAMP_WRAPPER)
	var site := wrapper.get_node("CaravanSite") as Node3D
	site.call(&"show_tyrant")
	site.call(&"grow_tyrant", 0.0, true)
	site.call(&"stage_attack_beat")
	await _wait(SHOT_WAIT)
	_hide_ui(wrapper)
	await process_frame
	await _save("01_attack")

	site.call(&"show_aftermath")
	site.call(&"stage_veteran_found")
	await _wait(1.8)
	_hide_ui(wrapper)
	await process_frame
	await _save("02_veteran_found")

	site.call(&"stage_veteran_death")
	await _wait(0.6)
	_hide_ui(wrapper)
	await process_frame
	await _save("03_veteran_death")
	await _free(wrapper)


func _capture_pilgrim() -> void:
	var wrapper := await _spawn(PILGRIM_WRAPPER)
	var site := wrapper.get_node("PilgrimPath") as Node3D
	site.call(&"place_party_at_alcove")
	site.call(&"stage_shifty_fall")
	await _wait(0.55)
	_hide_ui(wrapper)
	await process_frame
	await _save("04_shifty_fall")

	site.call(&"stage_cave_wound")
	await _wait(SHOT_WAIT)
	_hide_ui(wrapper)
	await process_frame
	await _save("05_cave_wound")

	site.call(&"stage_hero_confrontation")
	await _wait(SHOT_WAIT)
	_hide_ui(wrapper)
	await process_frame
	await _save("06_hero_confront")

	site.call(&"stage_hero_capture")
	await _wait(0.55)
	_hide_ui(wrapper)
	await process_frame
	await _save("07_hero_capture")
	await _free(wrapper)


func _spawn(path: String) -> Node:
	var packed := load(path) as PackedScene
	var scene := packed.instantiate()
	scene.set(&"fade_in", false)
	scene.set(&"transition_enabled", false)
	scene.set(&"fast_mode", false)
	scene.set(&"debug_direct_scene", true)
	root.add_child(scene)
	await process_frame
	await process_frame
	_hide_ui(scene)
	return scene


func _hide_ui(scene: Node) -> void:
	var ui := scene.get_node_or_null(^"UI")
	if ui != null:
		ui.process_mode = Node.PROCESS_MODE_DISABLED
		_hide_canvas_items(ui)
	var timing := scene.get_node_or_null(^"TimingChallenge")
	if timing != null:
		timing.process_mode = Node.PROCESS_MODE_DISABLED
		_hide_canvas_items(timing)


func _hide_canvas_items(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		_hide_canvas_items(child)


func _free(scene: Node) -> void:
	if scene != null and is_instance_valid(scene):
		scene.queue_free()
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	image.save_png(path)
	print("BEAT_SHOT ", path)
