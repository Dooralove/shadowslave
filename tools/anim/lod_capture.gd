extends SceneTree
## Capture LOD0/1/2 switches for A06 character assets.
## godot --path . -s tools/anim/lod_capture.gd -- --out=<dir>

const CASES := [
	["sunny_v3", "res://assets/characters/generated/sunny_real_v3/sunny_real_v3.tscn", 1.0, [5.0, 12.0, 25.0]],
	["sunny_nightmare_v2", "res://assets/characters/generated/sunny_nightmare_v2/sunny_nightmare_v2.tscn", 1.0, [5.0, 12.0, 25.0]],
	["hero_v6", "res://assets/characters/generated/hero_auro_v6/hero_auro_v6.tscn", 1.0, [6.0, 14.0, 26.0]],
	["carapace", "res://scenes/enemies/carapace_enemy.tscn", 1.0, [8.0, 16.0, 28.0]],
	["mountain_king", "res://scenes/characters/mountain_king.tscn", 2.5, [15.0, 30.0, 55.0]],
]

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		push_error("lod_capture: missing --out=<dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(960, 720)
	for entry in CASES:
		await _capture(entry[0], entry[1], float(entry[2]), entry[3])
	quit(0)


func _capture(label: String, path: String, target_y: float, distances: Array) -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	_add_environment(stage)
	_add_floor(stage)
	_add_lights(stage, target_y)
	var node := (load(path) as PackedScene).instantiate() as Node3D
	stage.add_child(node)
	if node.has_method(&"set_physics_process"):
		node.set_physics_process(false)
	for child in node.find_children("*", "Node", true, false):
		if child.has_method(&"set_physics_process"):
			child.set_physics_process(false)
	await process_frame
	await process_frame
	var cam := Camera3D.new()
	cam.near = 0.05
	cam.far = 120.0
	stage.add_child(cam)
	cam.current = true
	for distance in distances:
		var d := float(distance)
		cam.position = Vector3(0, target_y + 0.4, -d)
		cam.look_at(Vector3(0, target_y, 0), Vector3.UP)
		cam.fov = clampf(rad_to_deg(2.0 * atan((target_y + 0.8) / d)), 4.0, 60.0)
		for f in 24:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out.path_join("%s_%02dm.png" % [label, int(d)]))
		var vis0 := 0
		var vis1 := 0
		var vis2 := 0
		for m in node.find_children("*", "MeshInstance3D", true, false):
			var mesh := m as MeshInstance3D
			if not mesh.is_visible_in_tree():
				continue
			var n := String(mesh.name).to_lower()
			if n.contains("_lod2") or n.contains("lod2_"):
				vis2 += 1
			elif n.contains("_lod1") or n.contains("lod1_"):
				vis1 += 1
			else:
				vis0 += 1
		print("LOD_SHOT ", label, " distance=", d, " visible lod0=", vis0, " lod1=", vis1, " lod2=", vis2)
	stage.queue_free()
	await process_frame


func _add_environment(stage: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.03, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.4, 0.5)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.4
	var node := WorldEnvironment.new()
	node.environment = env
	stage.add_child(node)


func _add_floor(stage: Node3D) -> void:
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.13, 0.15)
	mat.roughness = 0.82
	floor.material_override = mat
	stage.add_child(floor)


func _add_lights(stage: Node3D, target_y: float) -> void:
	_add_spot(stage, Vector3(-3.5, target_y + 3.0, 2.8), Vector3(0, target_y, 0), Color(1.0, 0.92, 0.82), 12.0, 20.0, 45.0, true)
	_add_spot(stage, Vector3(3.2, target_y + 2.2, 2.4), Vector3(0, target_y, 0), Color(0.48, 0.64, 1.0), 5.0, 16.0, 45.0, false)
	_add_spot(stage, Vector3(0.4, target_y + 2.8, -2.2), Vector3(0, target_y, 0), Color(0.62, 0.72, 1.0), 7.0, 16.0, 40.0, false)


func _add_spot(stage: Node3D, pos: Vector3, target: Vector3, color: Color, energy: float, range_m: float, angle: float, shadows: bool) -> void:
	var light := SpotLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.spot_range = range_m
	light.spot_angle = angle
	light.shadow_enabled = shadows
	stage.add_child(light)
	light.look_at(target, Vector3.UP)
