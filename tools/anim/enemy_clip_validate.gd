extends SceneTree
## Validate additive enemy hit/death AnimationLibraries against the source rigs.
## godot --headless --path . -s tools/anim/enemy_clip_validate.gd

const CASES := [
	["carapace", "res://assets/characters/enemies/carapace_generated/carapace_scavenger_generated.glb", "res://assets/animations/enemies/carapace_hit.tres", ["Hit"]],
	["larva", "res://assets/characters/enemies/larva/larva_corpse_lod.glb", "res://assets/animations/enemies/larva_hit.tres", ["Hit"]],
	["larva", "res://assets/characters/enemies/larva/larva_corpse_lod.glb", "res://assets/animations/enemies/larva_death.tres", ["Death"]],
]

var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for entry in CASES:
		var label: String = entry[0]
		var glb_path: String = entry[1]
		var lib_path: String = entry[2]
		var names: Array = entry[3]
		var lib := load(lib_path) as AnimationLibrary
		if lib == null:
			_fail("%s: cannot load %s" % [label, lib_path])
			continue
		for clip_name in names:
			var anim := lib.get_animation(clip_name)
			if anim == null:
				_fail("%s: missing clip %s" % [label, clip_name])
				continue
			if anim.get_track_count() == 0:
				_fail("%s: clip %s has no tracks" % [label, clip_name])
			print("ENEMY_CLIP ", label, " ", clip_name, " length=", anim.length, " tracks=", anim.get_track_count())
		var node := (load(glb_path) as PackedScene).instantiate()
		root.add_child(node)
		await process_frame
		var player := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player == null:
			_fail("%s: source player missing" % label)
			node.queue_free()
			continue
		player.add_animation_library(&"authored", lib)
		for clip_name in names:
			var full := StringName("authored/" + String(clip_name))
			if not player.has_animation(full):
				_fail("%s: player cannot resolve %s" % [label, full])
				continue
			player.play(full)
			await process_frame
			if player.current_animation != full:
				_fail("%s: play did not switch to %s" % [label, full])
		node.queue_free()
		await process_frame
	print("ENEMY_CLIP_VALIDATE failed=%d" % _failed)
	quit(1 if _failed > 0 else 0)


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
