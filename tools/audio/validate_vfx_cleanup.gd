extends SceneTree
## Checks that one-shot M1 VFX are freed and only loop VFX remain.

const P09 := "res://scenes/locations/post_nightmare/academy_sleeper_center.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var state := root.get_node_or_null(^"NightmareRunState")
	if state == null:
		printerr("NightmareRunState missing")
		quit(1)
		return
	var scene := (load(P09) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.8).timeout
	var before := scene.find_children("M1Vfx*", "", true, false).size()
	state.set_flag(&"induction_seen", true)
	await create_timer(0.2).timeout
	var during := scene.find_children("M1Vfx*", "", true, false).size()
	await create_timer(3.4).timeout
	var after := scene.find_children("M1Vfx*", "", true, false).size()
	print("vfx_p09 before=", before, " during=", during, " after=", after)
	state.set_flag(&"induction_seen", false)
	quit(0 if during == before + 1 and after == before else 1)
