extends Node3D
## Standalone Sleeper Center interior art pass.
##
## The scene contains one GLB instance ("Art") built by
## assets/environments/academy/source/build_academy_sleeper_center.py. This
## script applies the final PBR materials, interior lighting, collision and
## showcase cameras. No gameplay, NPCs or quests.

var _built := false


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	_setup_environment()
	_setup_lights()
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
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.024, 0.032)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.50, 0.60, 0.74)
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.00
	environment.ssao_enabled = true
	environment.ssao_intensity = 1.15
	environment.ssao_radius = 1.2
	environment.ssil_enabled = true
	environment.ssil_intensity = 0.85
	environment.glow_enabled = true
	environment.glow_intensity = 0.24
	environment.glow_bloom = 0.03
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.045, 0.065, 0.095)
	environment.fog_light_energy = 0.55
	environment.fog_density = 0.008
	environment.fog_sky_affect = 0.0
	world_env.environment = environment
	add_child(world_env)

	# A very low directional fill keeps hard-surface bevels readable without
	# adding a second shadow-casting sun inside the building.
	var fill := DirectionalLight3D.new()
	fill.name = "InteriorFill"
	fill.rotation_degrees = Vector3(-24.0, -18.0, 0.0)
	fill.light_color = Color(0.60, 0.70, 0.88)
	fill.light_energy = 0.26
	fill.shadow_enabled = false
	add_child(fill)


func _setup_lights() -> void:
	var lights := Node3D.new()
	lights.name = "Lights"
	add_child(lights)
	_omni(lights, "EntryWarm", Vector3(0, 3.15, 10.0), Color(1.0, 0.78, 0.52), 4.2, 11.0)
	# Dormitory: cold strips over the capsule rows.
	for i in 5:
		_omni(lights, "DormCold%d" % i, Vector3(-10.0 + i * 5.0, 3.80, 0.0), Color(0.70, 0.82, 0.98), 2.2, 15.0)
	_omni(lights, "DormBoardGlow", Vector3(-8.0, 2.5, -6.0), Color(0.55, 0.76, 1.0), 1.6, 5.0)
	# Common room: warm and lived-in.
	_omni(lights, "CommonWarm", Vector3(-20.0, 3.15, 0.0), Color(1.0, 0.72, 0.42), 3.4, 13.0)
	_omni(lights, "CommonKitchen", Vector3(-20.0, 2.5, -5.0), Color(1.0, 0.80, 0.55), 1.6, 6.0)
	# Showers: cool, slightly green-blue.
	_omni(lights, "ShowersCool", Vector3(20.0, 3.15, 0.0), Color(0.70, 0.86, 1.0), 3.0, 13.0)
	for i in 2:
		_omni(lights, "ShowerStall%d" % i, Vector3(20.0, 2.6, -3.0 + i * 6.0), Color(0.76, 0.88, 1.0), 1.6, 6.0)
	# Observation: cold monitor glow.
	_omni(lights, "ObsCold", Vector3(0.0, 3.0, -10.0), Color(0.62, 0.80, 1.0), 2.6, 11.0)
	_omni(lights, "ObsScreen", Vector3(0.0, 2.2, -12.3), Color(0.35, 0.65, 0.90), 1.2, 5.0)
	# Medical corridor: clinical white.
	_omni(lights, "MedicalWhite", Vector3(0.0, 2.9, -16.0), Color(0.84, 0.92, 1.0), 2.8, 9.0)
	# Hollow gallery: cold, almost no warmth.
	_omni(lights, "HollowColdA", Vector3(5.0, 3.2, -21.5), Color(0.64, 0.82, 1.0), 2.0, 9.0)
	_omni(lights, "HollowColdB", Vector3(11.0, 3.2, -18.5), Color(0.64, 0.82, 1.0), 2.0, 9.0)
	_omni(lights, "HollowColdC", Vector3(8.0, 3.2, -20.0), Color(0.70, 0.86, 1.0), 1.4, 7.0)
	# Dream ward: deep blue with a soft practical over the central capsule.
	_omni(lights, "DreamBlueA", Vector3(0.0, 3.3, -21.0), Color(0.48, 0.70, 1.0), 3.2, 12.0)
	_omni(lights, "DreamBlueB", Vector3(0.0, 3.3, -27.0), Color(0.48, 0.70, 1.0), 3.0, 11.0)
	_omni(lights, "DreamFill", Vector3(-4.0, 3.2, -24.0), Color(0.62, 0.78, 1.0), 1.6, 8.0)
	_spot(lights, "DreamCapsuleKey", Vector3(0.0, 3.55, -25.5), Vector3(0.2, 0.0, -25.5), Color(0.42, 0.70, 1.0), 4.0, 10.0, 34.0)
	# Residential corridor and room 07.
	_omni(lights, "ResWarmA", Vector3(-30.0, 3.0, -8.0), Color(1.0, 0.76, 0.48), 2.6, 10.0)
	_omni(lights, "ResWarmB", Vector3(-30.0, 3.0, 8.0), Color(1.0, 0.76, 0.48), 2.6, 10.0)
	_omni(lights, "Room07Warm", Vector3(-35.0, 2.8, -8.6), Color(1.0, 0.74, 0.44), 2.8, 8.0)
	_omni(lights, "LaundryCold", Vector3(-25.0, 2.8, 9.0), Color(0.76, 0.88, 1.0), 2.0, 8.0)
	# Emergency red pools.
	_omni(lights, "EmergencyA", Vector3(-14.0, 2.4, 6.6), Color(0.95, 0.03, 0.02), 1.1, 3.5)
	_omni(lights, "EmergencyB", Vector3(14.0, 2.4, -6.6), Color(0.95, 0.03, 0.02), 1.1, 3.5)


func _omni(parent: Node3D, light_name: String, position: Vector3, color: Color, energy: float, range_value: float) -> void:
	var light := OmniLight3D.new()
	light.name = light_name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	parent.add_child(light)


func _spot(parent: Node3D, light_name: String, position: Vector3, target: Vector3, color: Color, energy: float, range_value: float, angle: float) -> void:
	var light := SpotLight3D.new()
	light.name = light_name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.spot_range = range_value
	light.spot_angle = angle
	light.spot_angle_attenuation = 0.8
	light.shadow_enabled = true
	parent.add_child(light)
	light.look_at(target, Vector3.UP)


func _setup_cameras() -> void:
	var shots := Node3D.new()
	shots.name = "Shots"
	add_child(shots)
	_camera(shots, "Entry", Vector3(0, 1.65, 13.4), Vector3(0, 1.4, 7.5), 62.0, true)
	_camera(shots, "Dorm", Vector3(0, 1.65, 6.2), Vector3(0, 1.4, -5.0), 64.0)
	_camera(shots, "DormWide", Vector3(0, 2.8, 6.0), Vector3(0, 0.8, -3.5), 64.0)
	_camera(shots, "Capsules", Vector3(-5.6, 1.55, 5.4), Vector3(-7.8, 0.9, -3.0), 58.0)
	_camera(shots, "Common", Vector3(-15.2, 1.65, 0), Vector3(-22.0, 1.3, 0), 64.0)
	_camera(shots, "Showers", Vector3(20.0, 1.70, 5.6), Vector3(20.0, 1.1, -4.0), 66.0)
	_camera(shots, "Observation", Vector3(-3.8, 1.70, -8.6), Vector3(0.0, 1.4, -12.2), 62.0)
	_camera(shots, "Medical", Vector3(0, 1.65, -13.3), Vector3(0, 1.4, -18.6), 60.0)
	_camera(shots, "Hollow", Vector3(7.2, 2.20, -16.9), Vector3(10.2, 0.8, -21.0), 62.0)
	_camera(shots, "Dream", Vector3(-3.2, 1.55, -20.6), Vector3(0, 1.2, -25.5), 60.0)
	_camera(shots, "Room07", Vector3(-37.4, 1.65, -6.3), Vector3(-34.0, 1.2, -9.8), 66.0)
	_camera(shots, "Laundry", Vector3(-22.4, 1.65, 9.0), Vector3(-26.0, 1.2, 10.0), 60.0)


func _camera(parent: Node3D, camera_name: String, position: Vector3, target: Vector3, fov: float, current := false) -> void:
	var camera := Camera3D.new()
	camera.name = camera_name
	camera.fov = fov
	camera.near = 0.05
	camera.far = 120.0
	parent.add_child(camera)
	camera.position = position
	camera.look_at(target, Vector3.UP)
	if current:
		camera.current = true


func _setup_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	add_child(body)
	# One continuous floor slab; the rooms are visually distinct, not separate
	# physical islands.
	_collider(body, "Floor", Vector3(-5.0, -0.1, -5.0), Vector3(72, 0.2, 50))
	# Entry vestibule (south and north doors).
	_wall_x(body, "EntryWest", -4.0, 10.0, 6.0, 3.6)
	_wall_x(body, "EntryEast", 4.0, 10.0, 6.0, 3.6)
	_wall_z(body, "EntrySouth", 13.0, 0.0, 8.0, 3.6, 0.0, 3.2)
	_wall_z(body, "EntryNorth", 7.0, 0.0, 8.0, 3.6, 0.0, 3.2)
	# Dormitory (doors on all four sides).
	_wall_z(body, "DormSouth", 7.0, 0.0, 26.0, 4.2, 0.0, 3.2)
	_wall_z(body, "DormNorth", -7.0, 0.0, 26.0, 4.2, 0.0, 3.0)
	_wall_x(body, "DormWest", -13.0, 0.0, 14.0, 4.2, 0.0, 3.0)
	_wall_x(body, "DormEast", 13.0, 0.0, 14.0, 4.2, 0.0, 3.0)
	# Short connectors between the dormitory and the common room / showers.
	_wall_z(body, "DormWestConnectorNorth", -2.0, -14.0, 2.0, 3.2)
	_wall_z(body, "DormWestConnectorSouth", 2.0, -14.0, 2.0, 3.2)
	_wall_z(body, "DormEastConnectorNorth", -2.0, 14.0, 2.0, 3.2)
	_wall_z(body, "DormEastConnectorSouth", 2.0, 14.0, 2.0, 3.2)
	# Common room (east/west doors).
	_wall_z(body, "CommonNorth", -6.0, -20.0, 10.0, 3.6)
	_wall_z(body, "CommonSouth", 6.0, -20.0, 10.0, 3.6)
	_wall_x(body, "CommonWest", -25.0, 0.0, 12.0, 3.6, 0.0, 2.6)
	_wall_x(body, "CommonEast", -15.0, 0.0, 12.0, 3.6, 0.0, 2.6)
	# Showers (west door).
	_wall_z(body, "ShowersNorth", -6.0, 20.0, 10.0, 3.6)
	_wall_z(body, "ShowersSouth", 6.0, 20.0, 10.0, 3.6)
	_wall_x(body, "ShowersEast", 25.0, 0.0, 12.0, 3.6)
	_wall_x(body, "ShowersWest", 15.0, 0.0, 12.0, 3.6, 0.0, 2.6)
	# Observation (south/north doors).
	_wall_x(body, "ObsWest", -6.0, -10.0, 6.0, 3.4)
	_wall_x(body, "ObsEast", 6.0, -10.0, 6.0, 3.4)
	_wall_z(body, "ObsSouth", -7.0, 0.0, 12.0, 3.4, 0.0, 3.0)
	_wall_z(body, "ObsNorth", -13.0, 0.0, 12.0, 3.4, 0.0, 2.6)
	# Medical corridor (south/north/east doors).
	_wall_x(body, "MedicalWest", -2.0, -16.0, 6.0, 3.2)
	_wall_z(body, "MedicalSouth", -13.0, 0.0, 4.0, 3.2, 0.0, 2.6)
	_wall_z(body, "MedicalNorth", -19.0, 0.0, 4.0, 3.2, 0.0, 2.6)
	_wall_x(body, "MedicalEast", 2.0, -16.0, 6.0, 3.2, -2.0, 2.0)
	# Hollow gallery (west door).
	_wall_z(body, "HollowNorth", -24.0, 8.0, 12.0, 3.6)
	_wall_z(body, "HollowSouth", -16.0, 8.0, 12.0, 3.6)
	_wall_x(body, "HollowEast", 14.0, -20.0, 8.0, 3.6)
	_wall_x(body, "HollowWest", 2.0, -20.0, 8.0, 3.6, 2.0, 2.0)
	# Dream ward (south door).
	_wall_x(body, "DreamWest", -6.0, -24.0, 10.0, 3.8)
	_wall_x(body, "DreamEast", 6.0, -24.0, 10.0, 3.8)
	_wall_z(body, "DreamNorth", -29.0, 0.0, 12.0, 3.8)
	_wall_z(body, "DreamSouth", -19.0, 0.0, 12.0, 3.8, 0.0, 2.6)
	# Residential corridor (east/west doors).
	_wall_z(body, "ResNorth", -14.0, -30.0, 4.0, 3.2)
	_wall_z(body, "ResSouth", 14.0, -30.0, 4.0, 3.2)
	_wall_x(body, "ResWest", -32.0, 0.0, 28.0, 3.2, -8.6, 2.0)
	# East wall of the corridor: door to the common-room connector at z=0,
	# laundry door at z=9. Segment it instead of one wall with a single gap.
	_collider(body, "ResEast_A", Vector3(-28.0, 1.6, -7.65), Vector3(0.3, 3.2, 12.7))
	_collider(body, "ResEast_B", Vector3(-28.0, 1.6, 4.85), Vector3(0.3, 3.2, 7.1))
	_collider(body, "ResEast_C", Vector3(-28.0, 1.6, 11.8), Vector3(0.3, 3.2, 4.4))
	# Connector vestibule north/south walls.
	_wall_z(body, "ResConnectorNorth", -2.0, -26.5, 3.0, 3.2)
	_wall_z(body, "ResConnectorSouth", 2.0, -26.5, 3.0, 3.2)
	# Room 07 (east door).
	_wall_x(body, "Room07West", -38.0, -8.6, 6.0, 3.2)
	_wall_z(body, "Room07North", -11.6, -35.0, 6.0, 3.2)
	_wall_z(body, "Room07South", -5.6, -35.0, 6.0, 3.2)
	_wall_x(body, "Room07East", -32.0, -8.6, 6.0, 3.2, 0.0, 2.0)
	# Laundry: the west wall is ResEast; its doorway is the gap at z=9.
	_wall_x(body, "LaundryEast", -22.0, 9.0, 6.0, 3.2)
	_wall_z(body, "LaundryNorth", 12.0, -25.0, 6.0, 3.2)
	_wall_z(body, "LaundrySouth", 6.0, -25.0, 6.0, 3.2)
	# Capsule bodies.
	for row_x in [-7.8, -3.7, 3.7, 7.8]:
		for col_z in [-4.6, 0.0, 4.6]:
			_collider(body, "Capsule_%s_%s" % [str(row_x), str(col_z)], Vector3(row_x, 0.75, col_z), Vector3(1.35, 1.5, 2.55))
	# Lockers and large furniture.
	_collider(body, "DormLockers", Vector3(-8.0, 0.95, 6.1), Vector3(5.4, 1.9, 0.55))
	_collider(body, "CommonTable", Vector3(-20.0, 0.75, 0.0), Vector3(3.2, 1.5, 1.5))
	_collider(body, "EntryDesk", Vector3(-2.2, 1.0, 9.6), Vector3(3.2, 2.0, 0.9))
	_collider(body, "DreamBedCenter", Vector3(0.0, 0.6, -25.5), Vector3(2.1, 1.2, 3.5))
	_collider(body, "Room07Bed", Vector3(-35.0, 0.6, -9.4), Vector3(2.1, 1.2, 3.5))


func _wall_x(body: StaticBody3D, wall_name: String, x: float, z_center: float, length: float, height: float, gap_center := 0.0, gap_width := 0.0) -> void:
	var start := z_center - length * 0.5
	var end := z_center + length * 0.5
	if gap_width <= 0.01:
		_collider(body, wall_name, Vector3(x, height * 0.5, z_center), Vector3(0.3, height, length))
		return
	var gap_start := z_center + gap_center - gap_width * 0.5
	var gap_end := z_center + gap_center + gap_width * 0.5
	if gap_start > start + 0.01:
		_collider(body, wall_name + "_A", Vector3(x, height * 0.5, (start + gap_start) * 0.5), Vector3(0.3, height, gap_start - start))
	if gap_end < end - 0.01:
		_collider(body, wall_name + "_B", Vector3(x, height * 0.5, (gap_end + end) * 0.5), Vector3(0.3, height, end - gap_end))


func _wall_z(body: StaticBody3D, wall_name: String, z: float, x_center: float, length: float, height: float, gap_center := 0.0, gap_width := 0.0) -> void:
	var start := x_center - length * 0.5
	var end := x_center + length * 0.5
	if gap_width <= 0.01:
		_collider(body, wall_name, Vector3(x_center, height * 0.5, z), Vector3(length, height, 0.3))
		return
	var gap_start := x_center + gap_center - gap_width * 0.5
	var gap_end := x_center + gap_center + gap_width * 0.5
	if gap_start > start + 0.01:
		_collider(body, wall_name + "_A", Vector3((start + gap_start) * 0.5, height * 0.5, z), Vector3(gap_start - start, height, 0.3))
	if gap_end < end - 0.01:
		_collider(body, wall_name + "_B", Vector3((gap_end + end) * 0.5, height * 0.5, z), Vector3(end - gap_end, height, 0.3))


func _collider(body: StaticBody3D, collider_name: String, position: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.name = collider_name
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = position
	body.add_child(shape)


func _setup_labels() -> void:
	var labels := Node3D.new()
	labels.name = "Labels"
	add_child(labels)
	_label(labels, "SLEEPER CENTER", Vector3(0, 3.0, 13.3), 0.0, 52, 0.016)
	_label(labels, "DORMITORY", Vector3(0, 3.75, 6.8), 0.0, 40, 0.015)
	_label(labels, "COMMON ROOM", Vector3(-15.1, 2.6, 0), 90.0, 34, 0.013)
	_label(labels, "SHOWERS", Vector3(15.1, 2.6, 0), -90.0, 34, 0.013)
	_label(labels, "OBSERVATION", Vector3(0, 2.85, -7.2), 0.0, 34, 0.013)
	_label(labels, "MEDICAL", Vector3(0, 2.8, -13.2), 0.0, 34, 0.013)
	_label(labels, "HOLLOW", Vector3(2.2, 2.85, -18.0), -90.0, 38, 0.014)
	_label(labels, "DREAM WARD", Vector3(0, 3.1, -19.2), 0.0, 38, 0.014)
	_label(labels, "ROOM 07", Vector3(-32.1, 2.4, -8.6), 90.0, 30, 0.012)
	_label(labels, "LAUNDRY", Vector3(-27.8, 2.4, 9.0), -90.0, 28, 0.012)


func _label(parent: Node3D, text_value: String, position: Vector3, rotation_y: float, font_size: int, pixel_size: float) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position
	label.rotation_degrees = Vector3(0, rotation_y, 0)
	label.font_size = int(font_size * 0.82)
	label.pixel_size = pixel_size * 0.52
	label.outline_size = 5
	label.modulate = Color(0.82, 0.92, 1.0, 1.0)
	label.outline_modulate = Color(0.010, 0.018, 0.026, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = false
	label.double_sided = false
	parent.add_child(label)
