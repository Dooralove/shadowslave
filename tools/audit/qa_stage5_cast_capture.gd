extends Node3D
## Stage 5 QA: close-up captures of the named cast in real scenes.
##   godot --path . res://tools/audit/qa_stage5_cast_capture.tscn -- --out=<dir>

const SHOTS := [
	["P05_jett", "res://scenes/locations/post_nightmare/police_precinct.tscn", ^"Generated/Props/JettAtBed"],
	["P06_jet", "res://scenes/locations/post_nightmare/academy_approach.tscn", ^"Generated/Props/Jet"],
	["P07_nephis", "res://scenes/locations/post_nightmare/academy_gate.tscn", ^"Generated/Props/NephisSilhouette"],
	["P09_cassia", "res://scenes/locations/post_nightmare/academy_sleeper_center.tscn", ^"Generated/Props/Cassia"],
	["P09_kasper", "res://scenes/locations/post_nightmare/academy_sleeper_center.tscn", ^"Generated/Props/Kasper"],
	["P09_rock", "res://scenes/locations/post_nightmare/academy_sleeper_center.tscn", ^"Generated/Props/Rock"],
	["LAB_nephis", "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn", ^"Gameplay/Runtime/NPC_Nephis"],
	["LAB_cassia", "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn", ^"Gameplay/Runtime/NPC_Cassia"],
]

var _out := ""
var _passes := 0
var _fails := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		push_error("qa_stage5_cast_capture: need --out=<dir>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().root.size = Vector2i(1000, 1000)
	await get_tree().process_frame
	_run()


func _run() -> void:
	for shot in SHOTS:
		var scene := (load(shot[1]) as PackedScene).instantiate()
		get_tree().root.add_child(scene)
		await get_tree().process_frame
		await get_tree().physics_frame
		await get_tree().physics_frame
		var npc := scene.get_node_or_null(shot[2]) as Node3D
		if npc == null:
			_fail("missing %s at %s" % [shot[0], shot[2]])
			scene.queue_free()
			await get_tree().process_frame
			continue
		var camera := Camera3D.new()
		camera.name = "CastShot"
		camera.fov = 35.0
		camera.near = 0.05
		camera.far = 80.0
		scene.add_child(camera)
		var target := npc.global_position + Vector3(0, 1.1, 0)
		camera.global_position = target + Vector3(2.3, 0.7, 2.7)
		camera.look_at(target, Vector3.UP)
		camera.make_current()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := _out.path_join(shot[0] + ".png")
		var error := get_tree().root.get_texture().get_image().save_png(path)
		if error == OK:
			_passes += 1
			print("QA_STAGE5_CAST_CAPTURE ", path)
		else:
			_fail("capture %s error %d" % [shot[0], error])
		scene.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	print("QA_STAGE5_CAST_RESULT pass=", _passes, " fail=", _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _fail(message: String) -> void:
	_fails += 1
	print("QA_STAGE5_CAST_FAIL ", message)
