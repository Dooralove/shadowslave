extends SceneTree
## Verifies that the AudioDirector hook applies a profile through current_scene,
## not only through the direct validation call.

const SCENE := "res://scenes/locations/post_nightmare/police_precinct.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var audio := root.get_node_or_null(^"AudioDirector")
	print("audio_director=", audio != null)
	if audio == null:
		quit(1)
		return
	var scene_audio: Node = audio.get("scene_audio") as Node
	print("scene_audio=", scene_audio != null)
	if scene_audio == null:
		quit(1)
		return
	var packed := load(SCENE) as PackedScene
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.8).timeout
	var profile: SceneAudioProfile = scene_audio.get("_active_profile")
	print("profile=", profile.id if profile != null else "null")
	var music: Node = audio.get("music") as Node
	var ambience: Node = audio.get("ambience") as Node
	print("music=", music.current_cue_id() if music != null else "null")
	print("ambience=", ambience.current_zone_id() if ambience != null else "null")
	var mirror := scene.get_node_or_null(^"MirrorInteract") as Interactable
	print("mirror_cue=", mirror.interact_cue if mirror != null else "null")
	print("loops=", scene_audio.get("_local_loops").size())
	print("vfx=", scene.find_children("M1Vfx*", "", true, false).size())
	quit(0 if profile != null and music != null and music.current_cue_id() == &"m1_precinct" else 1)
