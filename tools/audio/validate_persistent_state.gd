extends SceneTree
## Simulates loading a save directly into B01 with shroud_summoned already set.
## Persistent flag events must restore the shroud sound and VFX.

const B01 := "res://scenes/locations/post_nightmare/black_sea_platform.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var state := root.get_node_or_null(^"NightmareRunState")
	var audio := root.get_node_or_null(^"AudioDirector")
	if state == null or audio == null:
		printerr("autoload missing")
		quit(1)
		return
	state.set_flag(&"shroud_summoned", true)
	var packed := load(B01) as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.8).timeout
	var vfx := scene.find_children("M1Vfx*", "", true, false).size()
	var sfx: Node = audio.get("sfx") as Node
	var last: Dictionary = sfx.get("_last_played")
	var played := last.has(&"b01_shroud_flare")
	print("loaded_shroud_vfx=", vfx, " cue=", played)
	state.set_flag(&"shroud_summoned", false)
	quit(0 if vfx >= 2 and played else 1)
