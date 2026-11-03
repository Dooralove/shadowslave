extends SceneTree
## Verifies text-dialogue ducking for M1 scenes without a VO file.

const P05 := "res://scenes/locations/post_nightmare/police_precinct.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var audio := root.get_node_or_null(^"AudioDirector")
	if audio == null:
		printerr("AudioDirector missing")
		quit(1)
		return
	var packed := load(P05) as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.8).timeout
	var runner := get_first_node_in_group(&"dialogue_runner") as DialogueRunner
	if runner == null:
		printerr("DialogueRunner missing")
		quit(1)
		return
	var sequence := DialogueSequence.new()
	var line := DialogueLine.new()
	line.speaker = &"sunny"
	line.text = "duck test"
	line.duration = 0.35
	sequence.lines = [line]
	var music: Node = audio.get("music") as Node
	var ambience: Node = audio.get("ambience") as Node
	var scene_audio: Node = audio.get("scene_audio") as Node
	var loops: Array = scene_audio.get("_local_loops")
	var loop: AudioStreamPlayer3D = loops[0] as AudioStreamPlayer3D if not loops.is_empty() else null
	var loop_base := float(loop.get_meta(&"base_db", loop.volume_db)) if loop != null else 0.0
	runner.run(sequence)
	await create_timer(0.15).timeout
	var loop_ducked: bool = loop != null and loop.volume_db <= loop_base - 3.9
	var ducked: bool = music.get("_duck_db") <= -7.9 and ambience.get("_duck_db") <= -3.9 and loop_ducked
	print("ducked=", ducked, " music=", music.get("_duck_db"), " ambience=", ambience.get("_duck_db"), " loop=", loop.volume_db if loop != null else "null")
	await create_timer(0.55).timeout
	var loop_released: bool = loop != null and absf(loop.volume_db - loop_base) < 0.2
	var released: bool = is_zero_approx(float(music.get("_duck_db"))) and is_zero_approx(float(ambience.get("_duck_db"))) and loop_released
	print("released=", released, " loop=", loop.volume_db if loop != null else "null")
	quit(0 if ducked and released else 1)
