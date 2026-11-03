extends Node3D
## Standalone Academy Grounds art pass.
##
## The scene contains one GLB instance ("Art") built by
## assets/environments/academy/source/build_academy_grounds.py. This script
## applies the final PBR materials, winter sky/fog, practical lights, snow,
## collision and showcase cameras. No gameplay, portals or NPCs.

const SNOW_SCENE := preload("res://scenes/environment/vfx/m1_snow_drift.tscn")

var _built := false


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	_setup_environment()
	_setup_lights()
	_setup_snow()
	_setup_cameras()
	_setup_collision()
	_setup_labels()
	var art := get_node_or_null(^"Art")
	if art != null:
		AcademyMaterials.apply_to_scene(art)


func _setup_environment() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.16, 0.22, 0.30)
	sky_material.sky_horizon_color = Color(0.58, 0.66, 0.75)
	sky_material.sky_curve = 0.18
	sky_material.ground_horizon_color = Color(0.46, 0.51, 0.57)
	sky_material.ground_bottom_color = Color(0.20, 0.24, 0.28)
	sky_material.sun_angle_max = 12.0
	sky_material.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color(0.62, 0.72, 0.84)
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.02
	environment.ssao_enabled = true
	environment.ssao_intensity = 1.05
	environment.ssao_radius = 1.4
	environment.ssil_enabled = true
	environment.ssil_intensity = 0.65
	environment.glow_enabled = true
	environment.glow_intensity = 0.42
	environment.glow_bloom = 0.12
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.28, 0.34, 0.42)
	environment.fog_light_energy = 1.0
	environment.fog_density = 0.0045
	environment.fog_sky_affect = 0.42
	environment.fog_aerial_perspective = 0.55
	world_env.environment = environment
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "WinterSun"
	sun.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
	sun.light_color = Color(0.72, 0.82, 1.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)


func _setup_lights() -> void:
	var lights := Node3D.new()
	lights.name = "Lights"
	add_child(lights)
	# Gate: cold floods and a red warning wash.
	_omni(lights, "GateRedWash", Vector3(0, 9.0, 68.0), Color(0.85, 0.05, 0.03), 5.0, 28.0)
	_omni(lights, "GateColdFlood", Vector3(0, 14.0, 76.0), Color(0.55, 0.75, 1.0), 4.0, 32.0)
	for side in [-1.0, 1.0]:
		_omni(lights, "GateTowerGlow%s" % str(side), Vector3(side * 15.0, 24.0, 68.0), Color(0.55, 0.75, 1.0), 3.0, 16.0)
	# Gallery warm practicals.
	for i in 8:
		_omni(lights, "GalleryWarm%d" % i, Vector3(0, 3.9, 44.0 - i * 8.0), Color(1.0, 0.72, 0.44), 2.2, 10.0)
	# Building entrances and facades.
	_omni(lights, "SleeperEntrance", Vector3(0, 5.2, -46.0), Color(0.55, 0.82, 1.0), 5.0, 24.0)
	_omni(lights, "SleeperLobby", Vector3(0, 4.0, -54.0), Color(0.55, 0.82, 1.0), 6.0, 14.0)
	_omni(lights, "SleeperLobbyWarm", Vector3(0, 1.8, -56.0), Color(1.0, 0.78, 0.52), 2.0, 6.0)
	_omni(lights, "SleeperSign", Vector3(0, 12.8, -48.0), Color(0.45, 0.75, 1.0), 2.5, 10.0)
	_omni(lights, "DiningWarm", Vector3(-34.0, 5.0, 10.0), Color(1.0, 0.70, 0.42), 4.0, 20.0)
	_omni(lights, "DojoCold", Vector3(34.0, 6.0, 10.0), Color(0.55, 0.70, 1.0), 3.8, 18.0)
	_omni(lights, "DojoRed", Vector3(36.0, 11.0, 10.0), Color(0.85, 0.08, 0.05), 4.0, 12.0)
	_omni(lights, "DojoEmblemGlow", Vector3(35.0, 12.0, 10.0), Color(1.0, 0.22, 0.12), 3.0, 8.0)
	_omni(lights, "AcademicCool", Vector3(-37.0, 8.0, -35.0), Color(0.48, 0.72, 1.0), 3.2, 18.0)
	_omni(lights, "MedicalCold", Vector3(40.0, 5.0, -35.0), Color(0.55, 0.82, 1.0), 3.0, 15.0)
	# Axis lamp posts, alternating warm/cold.
	for side in [-1.0, 1.0]:
		for i in 5:
			var color := Color(1.0, 0.74, 0.46) if i % 2 == 0 else Color(0.55, 0.78, 1.0)
			_omni(lights, "AxisLamp%s%d" % [str(side), i], Vector3(side * 12.0, 6.2, 52.0 - i * 24.0), color, 2.4, 12.0)
	# Turret warning lights.
	for side in [-1.0, 1.0]:
		for i in 3:
			_omni(lights, "TurretWarn%s%d" % [str(side), i], Vector3(side * 80.0, 13.4, 55.0 - i * 40.0), Color(0.95, 0.03, 0.02), 1.8, 7.0)
	# Red gate emblem.
	_omni(lights, "EmblemGlow", Vector3(0, 17.0, 66.0), Color(1.0, 0.18, 0.10), 2.8, 10.0)


func _omni(parent: Node3D, light_name: String, position: Vector3, color: Color, energy: float, range_value: float) -> void:
	var light := OmniLight3D.new()
	light.name = light_name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	parent.add_child(light)


func _setup_snow() -> void:
	var snow_root := Node3D.new()
	snow_root.name = "Snowfall"
	add_child(snow_root)
	var positions := [
		Vector3(0, 2.0, 46.0),
		Vector3(0, 2.0, 12.0),
		Vector3(0, 2.0, -30.0),
		Vector3(-28.0, 2.0, 8.0),
		Vector3(28.0, 2.0, 8.0),
		Vector3(0, 2.0, 88.0),
	]
	for i in positions.size():
		var snow := SNOW_SCENE.instantiate() as Node3D
		if snow == null:
			continue
		snow.name = "Snow%d" % i
		snow.position = positions[i]
		snow_root.add_child(snow)
		for child in snow.get_children():
			if child is GPUParticles3D:
				(child as GPUParticles3D).emitting = true
				(child as GPUParticles3D).preprocess = 1.5


func _setup_cameras() -> void:
	var shots := Node3D.new()
	shots.name = "Shots"
	add_child(shots)
	_camera(shots, "Overview", Vector3(0, 58, 132), Vector3(0, 8, -20), 55.0, true)
	_camera(shots, "Gate", Vector3(0, 5.5, 122), Vector3(0, 10, 70), 52.0)
	_camera(shots, "Axis", Vector3(0, 4.0, 56), Vector3(0, 8, -38), 62.0)
	_camera(shots, "Sleeper", Vector3(0, 2.4, -34), Vector3(0, 5.0, -54), 58.0)
	_camera(shots, "SleeperWide", Vector3(0, 7.5, -24), Vector3(0, 8.5, -54), 60.0)
	_camera(shots, "SleeperSign", Vector3(0, 5.5, -28), Vector3(0, 12.8, -49.3), 38.0)
	_camera(shots, "Gallery", Vector3(0, 3.0, 32), Vector3(0, 3.0, -20), 68.0)
	_camera(shots, "Dining", Vector3(-24, 4.0, 20), Vector3(-55, 7, 10), 55.0)
	_camera(shots, "Dojo", Vector3(14, 7.5, 28), Vector3(50, 9, 8), 50.0)
	_camera(shots, "Skyline", Vector3(0, 30, 92), Vector3(0, 22, -120), 62.0)
	_camera(shots, "GateDetail", Vector3(0, 8.0, 82), Vector3(0, 12, 70), 48.0)


func _camera(parent: Node3D, camera_name: String, position: Vector3, target: Vector3, fov: float, current := false) -> void:
	var camera := Camera3D.new()
	camera.name = camera_name
	camera.fov = fov
	camera.near = 0.1
	camera.far = 700.0
	parent.add_child(camera)
	camera.position = position
	camera.look_at(target, Vector3.UP)
	if current:
		camera.current = true


func _setup_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	add_child(body)
	# Ground and the main volumes. Props are visual-only; the route is clear.
	_collider(body, "Ground", Vector3(0, -0.6, 0), Vector3(300, 1.2, 340))
	_collider(body, "GateWallWest", Vector3(-44.5, 6.0, 70), Vector3(71, 12, 2.4))
	_collider(body, "GateWallEast", Vector3(44.5, 6.0, 70), Vector3(71, 12, 2.4))
	_collider(body, "GateTowerWest", Vector3(-15, 13, 70), Vector3(12, 26, 12))
	_collider(body, "GateTowerEast", Vector3(15, 13, 70), Vector3(12, 26, 12))
	_collider(body, "Drawbridge", Vector3(0, 0.2, 78.5), Vector3(18, 0.4, 14))
	# The drawbridge is raised 0.4 m above the road. CharacterBody3D has no
	# automatic step-up, so both edges need short ramps or the main route to
	# the campus is blocked.
	_ramp(body, "DrawbridgeRampSouth", Vector3(0, 0.06, 86.4), Vector3(18, 0.3, 1.8), 12.0)
	_ramp(body, "DrawbridgeRampNorth", Vector3(0, 0.06, 70.6), Vector3(18, 0.3, 1.8), -12.0)
	_collider(body, "WallWest", Vector3(-80, 5, 0), Vector3(1.8, 10, 160))
	_collider(body, "WallEast", Vector3(80, 5, 0), Vector3(1.8, 10, 160))
	_collider(body, "WallNorth", Vector3(0, 5, -80), Vector3(160, 10, 1.8))
	_collider(body, "SleeperCenter", Vector3(0, 10.5, -70), Vector3(64, 21, 40))
	_collider(body, "DiningHall", Vector3(-55, 6.4, 10), Vector3(34, 12.8, 26))
	_collider(body, "Dojo", Vector3(55, 7.5, 10), Vector3(36, 15, 28))
	_collider(body, "AcademicWing", Vector3(-55, 9, -35), Vector3(34, 18, 26))
	_collider(body, "MedicalCenter", Vector3(55, 7, -35), Vector3(28, 14, 24))
	# The Sleeper Center stands on a 1.4 m plinth. A solid box would block the
	# only route to its portal, so the central stair is a sloped collider and
	# the sides stay solid.
	_collider(body, "SleeperPlinth", Vector3(0, 0.7, -73), Vector3(74, 1.4, 44))
	_collider(body, "SleeperPlinthWest", Vector3(-23, 0.7, -48), Vector3(28, 1.4, 6))
	_collider(body, "SleeperPlinthEast", Vector3(23, 0.7, -48), Vector3(28, 1.4, 6))
	_ramp(body, "SleeperSteps", Vector3(0, 0.51, -48), Vector3(18, 0.4, 6.2), 13.0)
	_collider(body, "Memorial", Vector3(22, 4, -32), Vector3(5, 8, 5))


func _collider(body: StaticBody3D, collider_name: String, position: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.name = collider_name
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = position
	body.add_child(shape)


func _ramp(body: StaticBody3D, ramp_name: String, position: Vector3, size: Vector3, pitch_degrees: float) -> void:
	var shape := CollisionShape3D.new()
	shape.name = ramp_name
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = position
	shape.rotation_degrees.x = pitch_degrees
	body.add_child(shape)


func _setup_labels() -> void:
	var labels := Node3D.new()
	labels.name = "Labels"
	add_child(labels)
	_label(labels, "ACADEMY", Vector3(0, 14.2, 71.6), 0.0, 58, 0.014)
	_label(labels, "SLEEPER CENTER", Vector3(0, 12.8, -49.2), 0.0, 58, 0.018)
	_label(labels, "DINING HALL", Vector3(-36.9, 9.0, 10.0), 90.0, 44, 0.016)
	_label(labels, "DOJO", Vector3(35.9, 10.5, 10.0), -90.0, 54, 0.018)
	_label(labels, "ACADEMIC WING", Vector3(-36.9, 13.0, -35.0), 90.0, 42, 0.016)
	_label(labels, "MEDICAL", Vector3(39.9, 5.0, -35.0), -90.0, 48, 0.017)


func _label(parent: Node3D, text_value: String, position: Vector3, rotation_y: float, font_size: int, pixel_size: float) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position
	label.rotation_degrees = Vector3(0, rotation_y, 0)
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.outline_size = 10
	label.modulate = Color(0.84, 0.92, 1.0, 1.0)
	label.outline_modulate = Color(0.015, 0.025, 0.035, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = false
	label.double_sided = false
	parent.add_child(label)
