extends SceneTree
## Build authored enemy hit/death AnimationLibrary resources from the existing rigs.
## These are additive assets: A05 can add the library to the enemy AnimationPlayer
## and play "Hit"/"Death" without changing the base GLB or its LODs.
##
## godot --headless --path . -s tools/anim/build_enemy_hit_clips.gd

const CARAPACE := "res://assets/characters/enemies/carapace_generated/carapace_scavenger_generated.glb"
const LARVA := "res://assets/characters/enemies/larva/larva_corpse_lod.glb"
const OUT_DIR := "res://assets/animations/enemies"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await _carapace()
	await _larva()
	quit(0)


func _carapace() -> void:
	var player := await _player_for(CARAPACE)
	var idle := player.get_animation(&"Idle")
	if idle == null:
		push_error("carapace: Idle missing")
		return
	var hit := idle.duplicate() as Animation
	hit.resource_name = "Hit"
	hit.length = 0.42
	hit.loop_mode = Animation.LOOP_NONE
	var rot_track := _find_track(hit, &"Shell", Animation.TYPE_ROTATION_3D)
	if rot_track >= 0:
		var base: Quaternion = hit.track_get_key_value(rot_track, 0)
		var back := base * Quaternion(Vector3.RIGHT, deg_to_rad(9.0))
		var settle := base * Quaternion(Vector3.RIGHT, deg_to_rad(-3.0))
		hit.track_insert_key(rot_track, 0.0, base)
		hit.track_insert_key(rot_track, 0.08, back)
		hit.track_insert_key(rot_track, 0.20, settle)
		hit.track_insert_key(rot_track, 0.42, base)
	else:
		push_error("carapace: Shell rotation track missing")
	var lib := AnimationLibrary.new()
	lib.add_animation(&"Hit", hit)
	var path := OUT_DIR.path_join("carapace_hit.tres")
	_save(lib, path, "carapace Hit", hit)
	player.get_parent().queue_free()


func _larva() -> void:
	var player := await _player_for(LARVA)
	var idle := player.get_animation(&"Idle")
	if idle == null:
		push_error("larva: Idle missing")
		return
	var hit := idle.duplicate() as Animation
	hit.resource_name = "Hit"
	hit.length = 0.38
	hit.loop_mode = Animation.LOOP_NONE
	var scale_track := _find_track(hit, &"Hips_23", Animation.TYPE_SCALE_3D)
	if scale_track >= 0:
		var base: Vector3 = hit.track_get_key_value(scale_track, 0)
		hit.track_insert_key(scale_track, 0.0, base)
		hit.track_insert_key(scale_track, 0.07, base * Vector3(0.92, 0.92, 0.92))
		hit.track_insert_key(scale_track, 0.18, base * Vector3(1.03, 1.03, 1.03))
		hit.track_insert_key(scale_track, 0.38, base)
	else:
		push_error("larva: Hips scale track missing")
	var hit_lib := AnimationLibrary.new()
	hit_lib.add_animation(&"Hit", hit)
	_save(hit_lib, OUT_DIR.path_join("larva_hit.tres"), "larva Hit", hit)

	var death := idle.duplicate() as Animation
	death.resource_name = "Death"
	death.length = 0.8
	death.loop_mode = Animation.LOOP_NONE
	var hips_rot := _find_track(death, &"Hips_23", Animation.TYPE_ROTATION_3D)
	if hips_rot >= 0:
		var base_rot: Quaternion = death.track_get_key_value(hips_rot, 0)
		var dead_rot := base_rot * Quaternion(Vector3(0, 0, 1), deg_to_rad(72.0))
		death.track_insert_key(hips_rot, 0.0, base_rot)
		death.track_insert_key(hips_rot, 0.35, dead_rot)
		death.track_insert_key(hips_rot, 0.8, dead_rot)
	if scale_track >= 0:
		var base_scale: Vector3 = death.track_get_key_value(scale_track, 0)
		death.track_insert_key(scale_track, 0.0, base_scale)
		death.track_insert_key(scale_track, 0.35, base_scale * Vector3(1.0, 0.22, 1.0))
		death.track_insert_key(scale_track, 0.8, base_scale * Vector3(1.0, 0.22, 1.0))
	# Freeze all other bones at their starting pose so the collapse reads clearly.
	for track in death.get_track_count():
		if track == hips_rot or track == scale_track:
			continue
		if death.track_get_key_count(track) == 0:
			continue
		var rest: Variant = death.track_get_key_value(track, 0)
		death.track_insert_key(track, 0.8, rest)
	var death_lib := AnimationLibrary.new()
	death_lib.add_animation(&"Death", death)
	_save(death_lib, OUT_DIR.path_join("larva_death.tres"), "larva Death", death)
	player.get_parent().queue_free()


func _player_for(path: String) -> AnimationPlayer:
	var packed := load(path) as PackedScene
	var node := packed.instantiate()
	root.add_child(node)
	await process_frame
	var player := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		push_error(path + ": no AnimationPlayer")
	return player


func _find_track(anim: Animation, bone: StringName, type: int) -> int:
	for i in anim.get_track_count():
		if anim.track_get_type(i) != type:
			continue
		var path := String(anim.track_get_path(i))
		if path.ends_with(":" + String(bone)):
			return i
	return -1


func _save(lib: AnimationLibrary, path: String, label: String, anim: Animation) -> void:
	var err := ResourceSaver.save(lib, path)
	if err != OK:
		push_error("%s: save failed %s" % [label, err])
		return
	print("ENEMY_CLIP ", label, " path=", path, " length=", anim.length, " tracks=", anim.get_track_count())
