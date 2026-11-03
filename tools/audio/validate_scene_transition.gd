extends SceneTree
## Verifies that SceneAudioDirector cleans up one M1 scene before applying the
## next profile, and that current_scene detection works across a transition.

const P05 := "res://scenes/locations/post_nightmare/police_precinct.tscn"
const P06 := "res://scenes/locations/post_nightmare/academy_approach.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var audio := root.get_node_or_null(^"AudioDirector")
	var scene_audio: Node = audio.get("scene_audio") as Node if audio != null else null
	if scene_audio == null:
		printerr("SceneAudioDirector missing")
		quit(1)
		return

	await _open(P05)
	var music: Node = audio.get("music") as Node
	var ambience: Node = audio.get("ambience") as Node
	var p05_ok: bool = music != null and music.current_cue_id() == &"m1_precinct" and ambience != null and ambience.current_zone_id() == &"m1_precinct"
	print("p05=", p05_ok, " loops=", scene_audio.get("_local_loops").size())

	await _open(P06)
	var p06_ok: bool = music != null and music.current_cue_id() == &"m1_academy" and ambience != null and ambience.current_zone_id() == &"m1_academy"
	print("p06=", p06_ok, " loops=", scene_audio.get("_local_loops").size())
	var car := current_scene.find_children("JettCar", "", true, false)
	print("car=", not car.is_empty())
	quit(0 if p05_ok and p06_ok else 1)


func _open(path: String) -> void:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await create_timer(0.25).timeout
	var packed := load(path) as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.8).timeout
