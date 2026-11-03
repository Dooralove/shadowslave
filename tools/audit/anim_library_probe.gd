extends SceneTree
## Одноразовая диагностика: какие AnimationLibrary/клипы реально есть у врагов.


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	for path in ["res://scenes/enemies/carapace_enemy.tscn", "res://scenes/enemies/larva_enemy.tscn"]:
		var scene := (load(path) as PackedScene).instantiate()
		root.add_child(scene)
		await process_frame
		var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player == null:
			print("PROBE ", path, " NO_ANIMATION_PLAYER")
		else:
			print("PROBE ", path, " libs=", player.get_animation_library_list(), " clips=", player.get_animation_list())
		scene.queue_free()
		await process_frame
	quit()
