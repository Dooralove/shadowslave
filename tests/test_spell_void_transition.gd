extends GutTest
## P2.5: Spell Void — сцена-переход B13, не геймплейная локация.

const SPELL_VOID_SCENE := "res://scenes/slice/locations/spell_void.tscn"


func _spawn() -> SliceLocation:
	var scene := (load(SPELL_VOID_SCENE) as PackedScene).instantiate() as SliceLocation
	add_child_autofree(scene)
	return scene


func test_spell_void_has_center_spawn_and_shot_cameras() -> void:
	var scene := _spawn()
	assert_not_null(scene.get_spawn(&"Center"), "void должен иметь Spawns/Center")
	assert_not_null(scene.shot(&"SpellShot"), "SpellShot должен существовать")
	assert_not_null(scene.shot(&"CloseShot"), "CloseShot должен существовать")
	for camera_name in [&"SpellShot", &"CloseShot"]:
		var camera := scene.shot(camera_name)
		var target := camera.get_node_or_null(^"LookAt") as Node3D
		assert_not_null(target, "%s: LookAt" % camera_name)
		if target == null:
			continue
		var forward := -camera.global_basis.z
		var to_target := (target.global_position - camera.global_position).normalized()
		assert_almost_eq(forward.dot(to_target), 1.0, 0.001, "%s смотрит в LookAt" % camera_name)


func test_spell_void_fast_cutscene_reaches_final_state() -> void:
	var scene := _spawn()
	await scene.play_cutscene(&"spell", true)
	var rune := scene.get_node(^"RuneCircle") as Node3D
	var halo := scene.get_node(^"Halo") as Node3D
	assert_not_null(rune, "RuneCircle")
	assert_not_null(halo, "Halo")
	if rune != null:
		assert_almost_eq(rune.scale.x, 1.0, 0.001, "rune circle раскрыт в fast_mode")
	if halo != null:
		assert_almost_eq(halo.scale.x, 0.6, 0.001, "halo раскрыт в fast_mode")


func test_spell_void_has_visual_layers() -> void:
	var scene := _spawn()
	assert_not_null(scene.get_node_or_null(^"WorldEnvironment"), "WorldEnvironment")
	assert_not_null(scene.get_node_or_null(^"VoidFloor"), "VoidFloor")
	assert_not_null(scene.get_node_or_null(^"VoidMotes"), "VoidMotes")
	assert_not_null(scene.get_node_or_null(^"SunnyVoid"), "SunnyVoid")
