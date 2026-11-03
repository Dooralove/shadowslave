extends SceneTree
## Read-only validation for the M1 scene-audio/VFX layer.
##
## This is a tool, not a GUT suite. It loads typed profiles, checks every cue
## reference, instantiates each post-Nightmare scene and applies the profile
## without requiring a player or a real audio device.
##
## Run:
##   godot --headless --path . --script res://tools/audio/validate_m1_audio.gd

const AUDIO_PROFILES := [
	"res://resources/audio/scene_profiles/p05_police_precinct.tres",
	"res://resources/audio/scene_profiles/p06_academy_approach.tres",
	"res://resources/audio/scene_profiles/p07_academy_gate.tres",
	"res://resources/audio/scene_profiles/p08_academy_campus.tres",
	"res://resources/audio/scene_profiles/p09_sleeper_center.tres",
	"res://resources/audio/scene_profiles/b01_black_sea.tres",
	"res://resources/audio/scene_profiles/b02_tide_descent.tres",
]

const VFX_PROFILES := [
	"res://resources/audio/scene_vfx_profiles/p05_police_precinct_vfx.tres",
	"res://resources/audio/scene_vfx_profiles/p06_academy_approach_vfx.tres",
	"res://resources/audio/scene_vfx_profiles/p07_academy_gate_vfx.tres",
	"res://resources/audio/scene_vfx_profiles/p08_academy_campus_vfx.tres",
	"res://resources/audio/scene_vfx_profiles/p09_sleeper_center_vfx.tres",
	"res://resources/audio/scene_vfx_profiles/b01_black_sea_vfx.tres",
	"res://resources/audio/scene_vfx_profiles/b02_tide_descent_vfx.tres",
]

const SCENES := [
	"res://scenes/locations/post_nightmare/police_precinct.tscn",
	"res://scenes/locations/post_nightmare/academy_approach.tscn",
	"res://scenes/locations/post_nightmare/academy_gate.tscn",
	"res://scenes/locations/post_nightmare/academy_campus.tscn",
	"res://scenes/locations/post_nightmare/academy_sleeper_center.tscn",
	"res://scenes/locations/post_nightmare/black_sea_platform.tscn",
	"res://scenes/locations/post_nightmare/tide_descent.tscn",
]

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var music := AudioLibrary.music_cues()
	var sfx := AudioLibrary.sfx_cues()
	var zones := AudioLibrary.ambience_zones()
	print("library music=%d sfx=%d zones=%d" % [music.size(), sfx.size(), zones.size()])

	for path in AUDIO_PROFILES:
		var profile := load(path) as SceneAudioProfile
		if profile == null:
			_fail(path, "profile load")
			continue
		print("audio_profile=", profile.id, " location=", profile.location_id)
		_check_music(profile, music)
		_check_zone(profile, zones)
		_check_events(profile.loops, sfx, "loops")
		_check_events(profile.enter_events, sfx, "enter")
		_check_events(profile.flag_events, sfx, "flags")
		_check_events(profile.trigger_events, sfx, "triggers")
		for key in profile.interactions:
			var cue := StringName(profile.interactions[key])
			if not sfx.has(cue):
				_fail(path, "interaction cue %s" % cue)

	for path in VFX_PROFILES:
		var profile := load(path) as SceneVfxProfile
		if profile == null:
			_fail(path, "vfx profile load")
			continue
		print("vfx_profile=", profile.id, " location=", profile.location_id)
		var vfx_particles := 0
		for event in profile.loops + profile.enter_effects + profile.flag_effects + profile.trigger_effects:
			if event == null or event.scene == null:
				_fail(path, "vfx event without scene")
				continue
			var inst := event.scene.instantiate()
			if inst == null:
				_fail(path, "vfx instantiate")
				continue
			var particles := inst.find_children("*", "GPUParticles3D", true, false)
			if particles.is_empty():
				_fail(path, "vfx has no particles")
			for particle in particles:
				vfx_particles += (particle as GPUParticles3D).amount
			inst.free()
		print("  vfx_particles=", vfx_particles)
		if vfx_particles > 900:
			_fail(path, "vfx particle budget %d > 900" % vfx_particles)

	for scene_path in SCENES:
		var packed := load(scene_path) as PackedScene
		if packed == null:
			_fail(scene_path, "scene load")
			continue
		var scene := packed.instantiate() as Node3D
		root.add_child(scene)
		await process_frame
		var director := SceneAudioDirector.new()
		director.name = "ValidationSceneAudio"
		root.add_child(director)
		director.call(&"_apply_scene", scene)
		await process_frame
		print("scene=", scene_path.get_file(), " loops=", _count_children(director, "SceneLoop"), " vfx=", _count_vfx(scene))
		var mapped := 0
		for node in get_nodes_in_group(&"interactable"):
			if node is Interactable and (node == scene or scene.is_ancestor_of(node)):
				var interactable := node as Interactable
				if interactable.interact_cue != &"world_pickup":
					mapped += 1
				print("  interact=", interactable.interaction_id, " cue=", interactable.interact_cue)
		if mapped == 0:
			print("  interact=no mapped cues")
		director.queue_free()
		scene.queue_free()
		await process_frame

	if _failures.is_empty():
		print("VALIDATION PASS")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: ", failure)
		print("VALIDATION FAIL count=", _failures.size())
		quit(1)


func _check_music(profile: SceneAudioProfile, music: Dictionary) -> void:
	if not profile.music_id.is_empty() and not music.has(profile.music_id):
		_fail(String(profile.id), "missing music %s" % profile.music_id)


func _check_zone(profile: SceneAudioProfile, zones: Dictionary) -> void:
	if not profile.ambience_id.is_empty() and not zones.has(profile.ambience_id):
		_fail(String(profile.id), "missing ambience %s" % profile.ambience_id)


func _check_events(events: Array[SceneAudioEvent], sfx: Dictionary, label: String) -> void:
	for event in events:
		if event == null:
			continue
		if not sfx.has(event.cue_id):
			_fail(label, "missing cue %s" % event.cue_id)


func _count_children(node: Node, prefix: String) -> int:
	var count := 0
	for child in node.get_children():
		if String(child.name).begins_with(prefix):
			count += 1
	return count


func _count_vfx(scene: Node) -> int:
	return scene.find_children("M1Vfx*", "", true, false).size()


func _fail(subject: String, message: String) -> void:
	_failures.append("%s: %s" % [subject, message])
	printerr("FAIL: ", subject, ": ", message)
