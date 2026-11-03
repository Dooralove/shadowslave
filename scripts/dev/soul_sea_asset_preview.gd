extends Node3D
## Read-only витрина кита Моря Души. Собирает GLB из
## `assets/environments/soul_sea/kit/` в одну сцену, чтобы проверить
## масштаб, материалы и силуэты в Godot. Не является игровой сценой.

const KIT := "res://assets/environments/soul_sea/kit/"
const LAYER := 2

var _world: Node3D


func _ready() -> void:
	_build_environment()
	_build_lights()
	_build_camera()
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	_build_ground()
	_build_hero()
	_build_periphery()
	_build_shade_ranks()
	_set_layers(self)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.014, 0.028)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.10, 0.15, 0.24)
	env.ambient_light_energy = 1.7
	env.tonemap_mode = 4
	env.tonemap_exposure = 1.25
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.05, 0.08)
	env.fog_density = 0.008
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)


func _build_lights() -> void:
	var key := DirectionalLight3D.new()
	key.name = "ColdKey"
	key.rotation_degrees = Vector3(-28, -42, 0)
	key.light_color = Color(0.55, 0.68, 0.95)
	key.light_energy = 2.0
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 80.0
	key.light_cull_mask = LAYER
	add_child(key)

	var warm := OmniLight3D.new()
	warm.name = "MemoryLight"
	warm.position = Vector3(0, 2.5, -0.9)
	warm.light_color = Color(1.0, 0.58, 0.26)
	warm.light_energy = 4.6
	warm.omni_range = 15.0
	warm.omni_attenuation = 1.2
	warm.light_cull_mask = LAYER
	add_child(warm)

	var rim := OmniLight3D.new()
	rim.name = "ColdRim"
	rim.position = Vector3(-5, 4, 4)
	rim.light_color = Color(0.35, 0.5, 0.9)
	rim.light_energy = 2.2
	rim.omni_range = 20.0
	rim.light_cull_mask = LAYER
	add_child(rim)


func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "PreviewCamera"
	cam.position = Vector3(9.5, 5.5, 13.0)
	cam.fov = 50.0
	cam.far = 160.0
	cam.cull_mask = LAYER
	add_child(cam)
	cam.look_at(Vector3(0, 1.3, 0.0), Vector3.UP)
	cam.make_current()


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(42, 42)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.025, 0.04, 0.06)
	mat.metallic = 0.25
	mat.roughness = 0.32
	var ground := MeshInstance3D.new()
	ground.name = "WaterPlane"
	ground.mesh = plane
	ground.material_override = mat
	ground.position.y = -0.02
	ground.layers = LAYER
	_world.add_child(ground)


func _build_hero() -> void:
	_add("ss_dais_hero", Vector3(0, 0, 0), Vector3.ZERO, 1.0)
	_add("ss_memory_sphere_hero", Vector3(0, 1.28, -0.9), Vector3.ZERO, 1.0)
	_add("ss_memory_orbit_sigil_a", Vector3(0, 0.67, -0.9), Vector3.ZERO, 1.0)
	_add("ss_memory_orbit_ring_a", Vector3(0, 1.28, -0.9), Vector3(18, 25, 0), 1.0)
	_add("ss_memory_orbit_ring_b", Vector3(0, 1.28, -0.9), Vector3(-35, -10, 0), 1.0)
	_add("ss_shade_slave_a", Vector3(4.6, 0, 3.4), Vector3(0, -28, 0), 1.0)
	_add("ss_shade_slaver_a", Vector3(5.4, 0, 1.6), Vector3(0, -55, 0), 1.0)
	_add("ss_shade_carapace_scavenger_a", Vector3(-4.8, 0, -2.5), Vector3(0, 40, 0), 1.0)
	_add("ss_obelisk_hero", Vector3(-8.5, 0, -6.0), Vector3(0, 18, 0), 0.60)
	_add("ss_shade_mountain_king", Vector3(-10.0, 0, 8.0), Vector3(0, 35, 0), 0.75)


func _build_periphery() -> void:
	_add("ss_shoal_rock_a", Vector3(-3.4, 0, 1.2), Vector3(0, 30, 0), 0.7)
	_add("ss_shoal_rock_b", Vector3(3.6, 0, -3.0), Vector3(0, -20, 0), 0.7)
	_add("ss_shoal_rock_c", Vector3(-2.0, 0, -3.8), Vector3(0, 65, 0), 0.55)
	_add("ss_obelisk_a", Vector3(7.2, 0, 5.2), Vector3(0, -15, 0), 0.55)
	_add("ss_obelisk_b", Vector3(-5.5, 0, 4.2), Vector3(0, 50, 0), 0.55)
	_add("ss_plinth_a", Vector3(2.0, 0, -3.4), Vector3.ZERO, 0.8)
	_add("ss_step_a", Vector3(2.6, 0, 0.8), Vector3(0, 20, 0), 0.8)
	for i in 3:
		_add("ss_memory_sphere_%s" % "abc"[i], Vector3(-1.8 + i * 1.8, 2.1 + i * 0.25, -4.2), Vector3.ZERO, 0.9)
	for i in 3:
		_add("ss_memory_thread_%s" % "abc"[i], Vector3(-2.8 + i * 2.8, 1.8, -3.0), Vector3(0, i * 35, 0), 0.9)


func _build_shade_ranks() -> void:
	for i in 5:
		var a := TAU * i / 5.0
		var pos := Vector3(cos(a) * 8.0, 0, sin(a) * 8.0 - 2.0)
		_add("ss_shade_rank_far_%s" % "abc"[i % 3], pos, Vector3(0, -rad_to_deg(a), 0), 1.0)


func _add(asset: String, pos: Vector3, rot_deg: Vector3, scale: float) -> void:
	var path := KIT + asset + ".glb"
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("soul_sea preview: missing %s" % path)
		return
	var inst := packed.instantiate()
	inst.name = asset
	inst.position = pos
	inst.rotation_degrees = rot_deg
	inst.scale = Vector3.ONE * scale
	_world.add_child(inst)


func _set_layers(node: Node) -> void:
	for child in node.find_children("*", "VisualInstance3D", true, false):
		(child as VisualInstance3D).layers = LAYER
