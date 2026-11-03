extends SceneTree
## Smoke test for the Z10 camp-night transition without loading the full
## labyrinth. The real scene uses the same LabyrinthAudio node.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var state := root.get_node_or_null(^"NightmareRunState")
	var audio := root.get_node_or_null(^"AudioDirector")
	if state == null or audio == null:
		printerr("autoload missing")
		quit(1)
		return
	state.set_flag(&"camp_night_seen", false)
	var lab := LabyrinthAudio.new()
	lab.name = "CampNightValidation"
	root.add_child(lab)
	await process_frame
	state.set_flag(&"camp_night_seen", true)
	await create_timer(0.2).timeout
	var music: Node = audio.get("music") as Node
	var ambience: Node = audio.get("ambience") as Node
	print("music=", music.current_cue_id() if music != null else "null")
	print("ambience=", ambience.current_zone_id() if ambience != null else "null")
	var ok: bool = music != null and music.current_cue_id() == &"camp" and ambience != null and ambience.current_zone_id() == &"m1_camp_night"
	# Simulate a save loaded directly into B03 with the flag already present.
	state.set_flag(&"camp_night_seen", true)
	var lab_loaded := LabyrinthAudio.new()
	lab_loaded.name = "CampNightLoadedValidation"
	root.add_child(lab_loaded)
	await create_timer(0.2).timeout
	var loaded_ok: bool = music != null and music.current_cue_id() == &"camp" and ambience != null and ambience.current_zone_id() == &"m1_camp_night"
	state.set_flag(&"camp_night_seen", false)
	lab.queue_free()
	lab_loaded.queue_free()
	await process_frame
	print("CAMP NIGHT ", "PASS" if ok and loaded_ok else "FAIL")
	quit(0 if ok and loaded_ok else 1)
