extends SceneTree
## Capture the integrated Mountain King v2 in a neutral stage.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "C:/Users/user/Desktop/shadowslave/docs/art/previews/generated/mountain_king_v2"
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(900, 900)
	var stage := Node3D.new(); root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.03, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.4, 0.5)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.3
	var we := WorldEnvironment.new(); we.environment = env; stage.add_child(we)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new(); plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.05, 0.055, 0.065); fm.roughness = 0.9
	floor_mesh.material_override = fm
	stage.add_child(floor_mesh)
	var key := DirectionalLight3D.new(); key.light_energy = 1.4; key.rotation_degrees = Vector3(-35, 25, 0); stage.add_child(key)
	var fill := OmniLight3D.new(); fill.light_energy = 2.0; fill.position = Vector3(-3, 3, 3); stage.add_child(fill)
	var mk := (load("res://scenes/characters/mountain_king.tscn") as PackedScene).instantiate()
	stage.add_child(mk)
	for i in 8: await process_frame
	var cam := Camera3D.new(); cam.fov = 38; cam.near = 0.05; cam.far = 60
	stage.add_child(cam); cam.current = true
	for entry in [["front", Vector3(0, 2.3, -8.5)], ["side", Vector3(8.0, 2.3, 2.0)]]:
		cam.position = entry[1]
		cam.look_at(Vector3(0, 2.1, 0), Vector3.UP)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("%s.png" % entry[0]))
		print("SHOT ", entry[0])
	quit(0)
