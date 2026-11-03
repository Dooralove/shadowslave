extends SceneTree
## P0 style gate: реалистичный dark fantasy.
## Строит 4 тестовые сцены (парк, скала/тропа, персонажи, Горный Король)
## и рендерит варианты света/экспозиции/HDRI в PNG. Только чтение проекта:
## существующие сцены/материалы не сохраняются.
##
## Запуск:
##   godot --path . -s tools/audit/style_gate_capture.gd -- --out=<папка>
##
## Внешние ассеты (staging, не в проекте):
##   %USERPROFILE%\Tools\asset_staging\polyhaven_models\quiver_tree_01\...
##   %USERPROFILE%\Tools\asset_staging\polyhaven_hdri\...
## Если файлов нет, скрипт падает на процедурное небо/без дерева.

const PARK_BENCH := "res://assets/environments/park/props/bench.glb"
const PARK_BIN := "res://assets/environments/park/props/bin.glb"
const PARK_CUP := "res://assets/environments/park/props/cup.glb"
const PARK_BOLLARD := "res://assets/environments/park/props/bollard_a.glb"
const PARK_TREE_PLANTER := "res://assets/environments/park/props/tree_planter_a.glb"

const ROCK_WALL := "res://assets/environments/nightmare/mountain/rock_wall_a.glb"
const ROCK_OVERHANG := "res://assets/environments/nightmare/mountain/rock_overhang_b.glb"
const CLIFF_EDGE := "res://assets/environments/nightmare/mountain/cliff_edge_a1.glb"
const ROAD_OLD := "res://assets/environments/nightmare/mountain/road_old_01.glb"
const SNOW_DRIFT := "res://assets/environments/nightmare/mountain/snow_drift_wall_b.glb"
const BOULDER := "res://assets/environments/nightmare/mountain/boulder_angular_a.glb"
const BONES := "res://assets/environments/nightmare/remains/bones_scatter_a.glb"

const SUNNY := "res://assets/characters/sunny_realistic_poc/sunny_waking_poc.tscn"
const MANNEQUIN := "res://scenes/slice/props/mannequin.tscn"
const MOUNTAIN_KING := "res://scenes/characters/mountain_king.tscn"

const PARK_TEXTURE_DIR := "res://assets/environments/park/materials/textures/"

var _out_dir := ""
var _root: Node3D
var _env_node: WorldEnvironment
var _camera: Camera3D
var _stages: Dictionary = {}
var _reusable_tree: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	if _out_dir.is_empty():
		push_error("style_gate_capture: нужен --out=<папка>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	root.size = Vector2i(1280, 720)

	_root = Node3D.new()
	_root.name = "StyleGate"
	root.add_child(_root)

	_env_node = WorldEnvironment.new()
	_env_node.name = "WorldEnvironment"
	_root.add_child(_env_node)

	_camera = Camera3D.new()
	_camera.name = "GateCamera"
	_camera.fov = 55.0
	_camera.near = 0.05
	_camera.far = 300.0
	_root.add_child(_camera)
	_camera.current = true

	_build_park(_stage("Park", Vector3.ZERO))
	_build_rock(_stage("Rock", Vector3.ZERO))
	_build_characters(_stage("Characters", Vector3.ZERO))
	_build_king(_stage("King", Vector3.ZERO))

	await _render_park()
	await _render_rock()
	await _render_characters()
	await _render_king()

	print("style_gate_capture: done out=", _out_dir)
	quit(0)


# ---------------------------------------------------------------------------
# Stage helpers
# ---------------------------------------------------------------------------

func _stage(stage_name: String, position: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = stage_name
	node.position = position
	_root.add_child(node)
	_stages[stage_name] = node
	return node


func _show_only(stage_name: String) -> void:
	for key in _stages:
		(_stages[key] as Node3D).visible = key == stage_name


func _frame(position: Vector3, target: Vector3, fov := 55.0) -> void:
	_camera.global_position = position
	_camera.fov = fov
	_camera.look_at(target, Vector3.UP)
	_camera.current = true


func _save(file_name: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(_out_dir.path_join(file_name))


# ---------------------------------------------------------------------------
# Environment / light helpers
# ---------------------------------------------------------------------------

func _hdr_path(file_name: String) -> String:
	var base := OS.get_environment("POLYHAVEN_STAGING")
	if base.is_empty():
		base = OS.get_environment("USERPROFILE").path_join("Tools/asset_staging")
	return base.path_join("polyhaven_hdri").path_join(file_name)


func _tree_path() -> String:
	var base := OS.get_environment("POLYHAVEN_STAGING")
	if base.is_empty():
		base = OS.get_environment("USERPROFILE").path_join("Tools/asset_staging")
	var island := base.path_join("polyhaven_models/island_tree_01/island_tree_01_1k.gltf")
	if FileAccess.file_exists(island):
		return island
	return base.path_join("polyhaven_models/quiver_tree_01/quiver_tree_01_1k.gltf")


func _sky_from_hdr(file_name: String) -> Sky:
	var path := _hdr_path(file_name)
	if not FileAccess.file_exists(path):
		push_warning("style_gate: нет HDRI " + path)
		return null
	var image := Image.new()
	if image.load(path) != OK:
		push_warning("style_gate: не удалось загрузить HDRI " + path)
		return null
	var texture := ImageTexture.create_from_image(image)
	var material := PanoramaSkyMaterial.new()
	material.panorama = texture
	var sky := Sky.new()
	sky.sky_material = material
	return sky


func _procedural_sky(top: Color, horizon: Color, ground: Color, sun_angle := 8.0) -> Sky:
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = top
	material.sky_horizon_color = horizon
	material.sky_curve = 0.25
	material.ground_bottom_color = ground * 0.6
	material.ground_horizon_color = ground
	material.ground_curve = 0.15
	material.sun_angle_max = sun_angle
	material.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = material
	return sky


func _night_sky(moon_direction: Vector3) -> Sky:
	var shader := load("res://assets/environments/nightmare/materials/nm_night_sky.gdshader") as Shader
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("moon_direction", moon_direction.normalized())
	material.set_shader_parameter("day_mix", 0.0)
	material.set_shader_parameter("moon_energy", 3.2)
	material.set_shader_parameter("star_energy", 2.0)
	var sky := Sky.new()
	sky.sky_material = material
	return sky


func _environment(sky: Sky, exposure: float, fog_density: float, volumetric: float,
		ambient_energy: float, bg_color: Color = Color(0.01, 0.012, 0.02),
		fog_color: Color = Color(0.55, 0.62, 0.72),
		vol_color: Color = Color(0.78, 0.82, 0.9),
		sky_affect := 0.2) -> Environment:
	var env := Environment.new()
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = exposure
	env.ssao_enabled = true
	env.ssao_radius = 1.8
	env.ssao_intensity = 1.4
	env.ssil_enabled = true
	env.ssil_intensity = 0.7
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.2
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = fog_density > 0.0
	if env.fog_enabled:
		env.fog_light_color = fog_color
		env.fog_density = fog_density
		env.fog_aerial_perspective = 0.35
		env.fog_sky_affect = sky_affect
	env.volumetric_fog_enabled = volumetric > 0.0
	if env.volumetric_fog_enabled:
		env.volumetric_fog_density = volumetric
		env.volumetric_fog_albedo = vol_color
		env.volumetric_fog_length = 48.0
		env.volumetric_fog_anisotropy = 0.4
	if sky != null:
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = ambient_energy
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = bg_color
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.35, 0.4, 0.5)
		env.ambient_light_energy = ambient_energy
	return env


func _sun(parent: Node3D, rotation_degrees: Vector3, color: Color, energy: float) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = rotation_degrees
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 100.0
	parent.add_child(light)
	return light


func _omni(parent: Node3D, position: Vector3, color: Color, energy: float, range_m: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.shadow_enabled = false
	parent.add_child(light)
	return light


func _spot(parent: Node3D, position: Vector3, target: Vector3, color: Color, energy: float,
		range_m: float, angle_deg: float, shadows := false) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.spot_range = range_m
	light.spot_angle = angle_deg
	light.shadow_enabled = shadows
	parent.add_child(light)
	light.look_at(target, Vector3.UP)
	return light


# ---------------------------------------------------------------------------
# Mesh / material helpers
# ---------------------------------------------------------------------------

func _instance(path: String, parent: Node3D, position := Vector3.ZERO, rotation_y := 0.0) -> Node3D:
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("style_gate: нет сцены " + path)
		return null
	var node := scene.instantiate() as Node3D
	if node == null:
		return null
	parent.add_child(node)
	node.position = position
	node.rotation.y = rotation_y
	return node


func _orm_material(dir: String, base: String, uv_scale := 4.0) -> ORMMaterial3D:
	var material := ORMMaterial3D.new()
	var albedo := _texture_path(dir, base, "diff")
	var normal := _texture_path(dir, base, "nor_gl")
	var arm := _texture_path(dir, base, "arm")
	if not albedo.is_empty():
		material.albedo_texture = load(albedo)
	if not normal.is_empty():
		material.normal_texture = load(normal)
	if not arm.is_empty():
		material.orm_texture = load(arm)
	material.uv1_scale = Vector3(uv_scale, uv_scale, 1.0)
	material.roughness = 1.0
	return material


func _texture_path(dir: String, base: String, channel: String) -> String:
	for resolution in ["2k", "1k"]:
		var path := dir.path_join("%s_%s_%s.jpg" % [base, channel, resolution])
		if ResourceLoader.exists(path):
			return path
	return ""


func _plain_material(color: Color, roughness := 0.85) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _plane(parent: Node3D, position: Vector3, size: Vector2, material: Material) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = position
	parent.add_child(node)
	return node


func _box(parent: Node3D, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = position
	parent.add_child(node)
	return node


func _mannequin(parent: Node3D, archetype: String, position: Vector3, rotation_y := 0.0) -> Node3D:
	var scene := load(MANNEQUIN) as PackedScene
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	node.set("archetype", archetype)
	node.set("pose", "idle")
	parent.add_child(node)
	node.position = position
	node.rotation.y = rotation_y
	return node


func _load_tree(parent: Node3D, position: Vector3, height: float, rotation_y := 0.0) -> Node3D:
	if _reusable_tree == null:
		var path := _tree_path()
		if not FileAccess.file_exists(path):
			push_warning("style_gate: нет дерева " + path)
			return null
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) != OK:
			push_warning("style_gate: не удалось загрузить дерево")
			return null
		_reusable_tree = doc.generate_scene(state) as Node3D
	if _reusable_tree == null:
		return null
	var tree := _reusable_tree.duplicate() as Node3D
	parent.add_child(tree)
	tree.position = position
	tree.rotation.y = rotation_y
	_scale_to_height(tree, height)
	return tree


func _scale_to_height(node: Node3D, target_height: float) -> void:
	var aabb := _node_aabb(node)
	if aabb.size.y <= 0.01:
		return
	node.scale = Vector3.ONE * (target_height / aabb.size.y)


func _node_aabb(root_node: Node) -> AABB:
	var first := true
	var result := AABB()
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			var aabb := mesh_instance.get_aabb()
			var xf := mesh_instance.global_transform
			for xi in 2:
				for yi in 2:
					for zi in 2:
						var corner := Vector3(
							aabb.position.x if xi == 0 else aabb.end.x,
							aabb.position.y if yi == 0 else aabb.end.y,
							aabb.position.z if zi == 0 else aabb.end.z
						)
						var world := xf * corner
						if first:
							result = AABB(world, Vector3.ZERO)
							first = false
						else:
							result = result.expand(world)
		for child in node.get_children():
			stack.append(child)
	return result


# ---------------------------------------------------------------------------
# Park
# ---------------------------------------------------------------------------

func _build_park(stage: Node3D) -> void:
	var grass := _plain_material(Color(0.12, 0.16, 0.12), 0.95)
	var asphalt := _orm_material(PARK_TEXTURE_DIR, "clean_asphalt", 6.0)
	var concrete := _orm_material(PARK_TEXTURE_DIR, "concrete_slab_wall", 4.0)

	_plane(stage, Vector3(0, -0.02, -2), Vector2(28, 28), grass)
	_box(stage, Vector3(0, 0.03, 2.2), Vector3(28, 0.06, 5.2), concrete)
	_box(stage, Vector3(0, 0.01, 7.8), Vector3(28, 0.04, 6.2), asphalt)
	_box(stage, Vector3(0, 0.12, 4.9), Vector3(28, 0.22, 0.35), concrete)

	# Реалистичный фасад: бетонная рама, стеклянные окна, цоколь и козырёк.
	var glass := _plain_material(Color(0.025, 0.035, 0.05), 0.12)
	glass.metallic = 0.55
	var lit_glass := glass.duplicate() as StandardMaterial3D
	lit_glass.emission_enabled = true
	lit_glass.emission = Color(0.18, 0.26, 0.38)
	lit_glass.emission_energy_multiplier = 0.6
	_box(stage, Vector3(0, 6.0, -10.6), Vector3(26, 12, 0.6), concrete)
	for row in 3:
		for col in 6:
			var x := -10.0 + col * 4.0
			var y := 2.2 + row * 3.0
			var window_mat := lit_glass if (row + col) % 4 == 0 else glass
			_box(stage, Vector3(x, y, -10.22), Vector3(2.6, 2.1, 0.12), window_mat)
			_box(stage, Vector3(x, y, -10.18), Vector3(2.75, 0.09, 0.14), concrete)
	for col in 7:
		var x := -12.0 + col * 4.0
		_box(stage, Vector3(x, 6.0, -10.16), Vector3(0.22, 12.0, 0.16), concrete)
	# Глубина фасада: боковые крылья, карниз, цоколь, рамы окон.
	_box(stage, Vector3(-13.6, 5.2, -7.8), Vector3(5.0, 10.4, 5.4), concrete)
	_box(stage, Vector3(13.6, 5.2, -7.8), Vector3(5.0, 10.4, 5.4), concrete)
	_box(stage, Vector3(0, 12.25, -10.0), Vector3(30.0, 0.45, 1.4), concrete)
	_box(stage, Vector3(0, 0.6, -9.95), Vector3(27.0, 1.2, 1.1), _plain_material(Color(0.10, 0.11, 0.13), 0.9))
	for row in 3:
		for col in 6:
			var x := -10.0 + col * 4.0
			var y := 2.2 + row * 3.0
			_box(stage, Vector3(x - 1.42, y, -10.14), Vector3(0.14, 2.25, 0.2), concrete)
			_box(stage, Vector3(x + 1.42, y, -10.14), Vector3(0.14, 2.25, 0.2), concrete)
			_box(stage, Vector3(x, y - 1.13, -10.14), Vector3(2.95, 0.14, 0.2), concrete)
	# Вход и козырёк.
	var entrance_glass := StandardMaterial3D.new()
	entrance_glass.albedo_color = Color(0.18, 0.28, 0.4, 0.28)
	entrance_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	entrance_glass.metallic = 0.4
	entrance_glass.roughness = 0.08
	_box(stage, Vector3(0, 1.6, -10.1), Vector3(6.0, 3.2, 0.2), entrance_glass)
	_box(stage, Vector3(0, 1.55, -10.35), Vector3(5.4, 2.7, 0.1), _plain_material(Color(0.95, 0.72, 0.42), 0.45))
	_omni(stage, Vector3(0, 2.2, -10.1), Color(1.0, 0.7, 0.4), 1.6, 5.0)
	_box(stage, Vector3(0, 3.6, -9.3), Vector3(7.2, 0.3, 1.8), concrete)
	_box(stage, Vector3(0, 4.1, -10.0), Vector3(6.4, 0.15, 0.2), _plain_material(Color(0.85, 0.88, 0.92), 0.4))

	_load_tree(stage, Vector3(-4.2, 0.0, -1.0), 7.2, 0.4)
	_load_tree(stage, Vector3(4.6, 0.0, -2.5), 6.4, -0.6)

	_instance(PARK_BENCH, stage, Vector3(2.0, 0.05, 2.6), PI)
	_instance(PARK_BIN, stage, Vector3(3.4, 0.05, 2.0), 0.0)
	var cup := _instance(PARK_CUP, stage, Vector3(2.15, 0.55, 2.55), 0.0)
	if cup:
		cup.scale = Vector3.ONE * 0.9

	for x in [-7.0, -4.0, 4.0, 7.0]:
		_instance(PARK_BOLLARD, stage, Vector3(x, 0.05, 5.8), 0.0)
	_mannequin(stage, "townsman", Vector3(0.0, 0.05, 0.8), PI)
	_mannequin(stage, "police", Vector3(-1.2, 0.05, 2.2), PI * 0.8)

	_sun(stage, Vector3(-38, -52, 0), Color(1.0, 0.95, 0.88), 2.2)
	_omni(stage, Vector3(-5, 4.5, 3.0), Color(0.55, 0.7, 1.0), 0.7, 12.0)
	_spot(stage, Vector3(0, 3.3, -8.6), Vector3(0, 1.0, -2.0), Color(0.75, 0.85, 1.0), 4.0, 12.0, 32.0)


# ---------------------------------------------------------------------------
# Rock / trail
# ---------------------------------------------------------------------------

func _build_rock(stage: Node3D) -> void:
	var snow := _plain_material(Color(0.72, 0.76, 0.82), 0.9)
	var rock := load("res://assets/environments/nightmare/materials/nm_rock.tres") as Material
	if rock == null:
		rock = _plain_material(Color(0.22, 0.24, 0.28), 0.9)
	_plane(stage, Vector3(0, -0.05, 5), Vector2(12, 30), snow)
	_box(stage, Vector3(0, 0.0, 5), Vector3(4.4, 0.1, 26), rock)
	for z in [0, 4, 8, 12]:
		_instance(ROAD_OLD, stage, Vector3(0, 0.06, z), 0.0)
	for z in [0, 4, 8, 12]:
		_instance(ROCK_WALL, stage, Vector3(2.5, 0, z), 0.0)
		_instance(CLIFF_EDGE, stage, Vector3(0, 0, z), 0.0)
	_instance(ROCK_OVERHANG, stage, Vector3(2.5, 0, 6.0), 0.0)
	_instance(SNOW_DRIFT, stage, Vector3(1.4, 0.0, 3.0), 0.0)
	_instance(BOULDER, stage, Vector3(-0.6, 0.0, -1.0), 0.8)
	_instance(BONES, stage, Vector3(-0.3, 0.02, 2.2), 0.4)
	_mannequin(stage, "slave", Vector3(0.0, 0.06, 7.0), PI)

	_sun(stage, Vector3(-22, -115, 0), Color(0.55, 0.68, 1.0), 1.2)
	_omni(stage, Vector3(0.0, 3.0, -2.0), Color(0.45, 0.6, 1.0), 1.2, 12.0)
	_spot(stage, Vector3(-5.0, 5.0, -3.0), Vector3(0.0, 1.5, 7.0), Color(0.5, 0.65, 1.0), 5.0, 30.0, 45.0, true)


# ---------------------------------------------------------------------------
# Characters
# ---------------------------------------------------------------------------

var _char_lights: Array[Light3D] = []

func _build_characters(stage: Node3D) -> void:
	var floor_mat := _plain_material(Color(0.22, 0.22, 0.24), 0.8)
	var back_mat := _plain_material(Color(0.10, 0.11, 0.13), 0.9)
	_box(stage, Vector3(0, -0.05, 0), Vector3(10, 0.1, 8), floor_mat)
	_box(stage, Vector3(0, 3.0, -4.0), Vector3(10, 6, 0.2), back_mat)
	_box(stage, Vector3(-5.0, 3.0, 0), Vector3(0.2, 6, 8), back_mat)
	_box(stage, Vector3(5.0, 3.0, 0), Vector3(0.2, 6, 8), back_mat)

	_instance(SUNNY, stage, Vector3(0, 0, 0), PI)
	_mannequin(stage, "police", Vector3(-1.4, 0, 0.2), PI * 0.85)
	_mannequin(stage, "knight", Vector3(1.4, 0, -0.1), PI * 1.15)

	_char_lights.clear()
	_char_lights.append(_spot(stage, Vector3(-2.4, 2.5, 2.6), Vector3(0, 1.4, 0), Color(1.0, 0.94, 0.86), 5.0, 12.0, 38.0, true))
	_char_lights.append(_omni(stage, Vector3(2.6, 1.8, 2.2), Color(0.55, 0.7, 1.0), 1.5, 7.0))
	_char_lights.append(_spot(stage, Vector3(0.8, 2.8, -2.4), Vector3(0, 1.5, 0), Color(0.6, 0.75, 1.0), 3.5, 12.0, 32.0, false))


# ---------------------------------------------------------------------------
# Mountain King
# ---------------------------------------------------------------------------

var _king_node: Node3D

func _build_king(stage: Node3D) -> void:
	var snow := _plain_material(Color(0.65, 0.69, 0.76), 0.92)
	_plane(stage, Vector3(0, -0.05, 0), Vector2(16, 16), snow)
	_box(stage, Vector3(0, 0.0, 0), Vector3(16, 0.1, 16), snow)
	_instance(ROCK_WALL, stage, Vector3(6.5, 0, -2.0), PI)
	_mannequin(stage, "knight", Vector3(2.8, 0.05, 0.0), -PI * 0.6)

	var scene := load(MOUNTAIN_KING) as PackedScene
	if scene != null:
		_king_node = scene.instantiate() as Node3D
		stage.add_child(_king_node)
		_king_node.position = Vector3(0, 0.05, 0)
		_hide_node_names(_king_node, ["Telegraph", "SwingVisual", "Hurtbox", "AttackArea", "HealthBar"])
		_king_node.process_mode = Node.PROCESS_MODE_DISABLED

	_spot(stage, Vector3(0.0, 5.0, -5.0), Vector3(0, 2.0, 0), Color(0.55, 0.68, 1.0), 9.0, 24.0, 48.0, true)
	_omni(stage, Vector3(-3.0, 2.2, 3.2), Color(0.55, 0.65, 0.85), 1.2, 10.0)


func _hide_node_names(root_node: Node, needles: Array) -> void:
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for needle in needles:
			if String(node.name).to_lower().contains(String(needle).to_lower()):
				if node is Node3D:
					(node as Node3D).visible = false
				break
		for child in node.get_children():
			stack.append(child)


# ---------------------------------------------------------------------------
# Render variants
# ---------------------------------------------------------------------------

func _render_park() -> void:
	_show_only("Park")
	_frame(Vector3(0, 1.7, 9.0), Vector3(0, 1.4, -3.0), 52.0)
	var variants := [
		{
			"name": "park_a_procedural",
			"sky": _procedural_sky(Color(0.34, 0.42, 0.54), Color(0.68, 0.72, 0.78), Color(0.55, 0.58, 0.62)),
			"exposure": 0.95, "fog": 0.008, "vol": 0.008, "ambient": 0.6,
		},
		{
			"name": "park_b_hdri_misty",
			"sky": _sky_from_hdr("kloofendal_misty_morning_puresky_2k.hdr"),
			"exposure": 0.9, "fog": 0.009, "vol": 0.01, "ambient": 0.75,
		},
		{
			"name": "park_c_hdri_contrast",
			"sky": _sky_from_hdr("kloofendal_misty_morning_puresky_2k.hdr"),
			"exposure": 0.7, "fog": 0.012, "vol": 0.014, "ambient": 0.55,
		},
	]
	for variant in variants:
		_env_node.environment = _environment(variant.sky, variant.exposure, variant.fog, variant.vol, variant.ambient)
		await _save(variant.name + ".png")


func _render_rock() -> void:
	_show_only("Rock")
	_frame(Vector3(0.2, 1.7, 13.0), Vector3(0.2, 1.2, 2.0), 55.0)
	var sky := _night_sky(Vector3(-0.35, 0.45, -0.82))
	var variants := [
		{"name": "rock_a_moon", "exposure": 1.0, "fog": 0.004, "vol": 0.008, "ambient": 0.24},
		{"name": "rock_b_fog", "exposure": 1.2, "fog": 0.008, "vol": 0.018, "ambient": 0.35},
		{"name": "rock_c_cold", "exposure": 1.4, "fog": 0.012, "vol": 0.028, "ambient": 0.22},
	]
	for variant in variants:
		_env_node.environment = _environment(sky, variant.exposure, variant.fog, variant.vol, variant.ambient, Color(0.01, 0.015, 0.03), Color(0.025, 0.035, 0.06), Color(0.22, 0.3, 0.46), 0.0)
		await _save(variant.name + ".png")


func _render_characters() -> void:
	_show_only("Characters")
	var variants := [
		{"name": "char_a_soft", "exposure": 1.0, "key": 5.0, "fill": 1.5, "rim": 3.5, "key_color": Color(1.0, 0.94, 0.86), "rim_color": Color(0.6, 0.75, 1.0), "bg": Color(0.11, 0.12, 0.14)},
		{"name": "char_b_lowkey", "exposure": 1.15, "key": 9.0, "fill": 0.4, "rim": 5.0, "key_color": Color(1.0, 0.9, 0.8), "rim_color": Color(0.45, 0.65, 1.0), "bg": Color(0.03, 0.035, 0.05)},
		{"name": "char_c_warmcool", "exposure": 1.0, "key": 6.5, "fill": 0.8, "rim": 4.5, "key_color": Color(1.0, 0.78, 0.6), "rim_color": Color(0.4, 0.65, 1.0), "bg": Color(0.07, 0.075, 0.09)},
	]
	for variant in variants:
		_env_node.environment = _environment(null, variant.exposure, 0.0, 0.0, 0.22, variant.bg)
		var key := _char_lights[0] as SpotLight3D
		var fill := _char_lights[1] as OmniLight3D
		var rim := _char_lights[2] as SpotLight3D
		key.light_energy = variant.key
		key.light_color = variant.key_color
		fill.light_energy = variant.fill
		rim.light_energy = variant.rim
		rim.light_color = variant.rim_color
		_frame(Vector3(0, 1.55, 4.3), Vector3(0, 1.25, 0), 38.0)
		await _save(variant.name + "_group.png")
		_frame(Vector3(0.35, 1.52, 1.5), Vector3(0, 1.52, 0), 34.0)
		await _save(variant.name + "_face.png")


func _render_king() -> void:
	_show_only("King")
	var variants := [
		{"name": "king_a_silhouette", "exposure": 0.8, "fog": 0.02, "vol": 0.03, "ambient": 0.25, "fill": 0.6},
		{"name": "king_b_reveal", "exposure": 1.0, "fog": 0.012, "vol": 0.018, "ambient": 0.4, "fill": 1.8},
	]
	for variant in variants:
		_env_node.environment = _environment(null, variant.exposure, variant.fog, variant.vol, variant.ambient, Color(0.015, 0.02, 0.035), Color(0.03, 0.045, 0.08), Color(0.2, 0.28, 0.45), 0.0)
		_frame(Vector3(0, 2.2, 10.0), Vector3(0, 1.9, 0), 46.0)
		await _save(variant.name + ".png")
