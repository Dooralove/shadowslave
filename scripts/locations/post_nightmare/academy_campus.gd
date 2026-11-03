class_name AcademyCampus
extends GreyboxLocation
## P03.5: внутренний кампус между воротами и спальным центром.
##
## Южный конец выходит к задним воротам Академии, северный — к тамбуру
## спального центра. Крытая галерея и боковые корпуса дают непрерывный
## маршрут вместо короткого затемнения между двумя интерьерами.

const GUIDE_SEQUENCE := preload("res://resources/dialogue/post_nightmare/p08_campus.tres")
const MANNEQUIN_SCENE := preload("res://scenes/slice/props/mannequin.tscn")
const WORLD_FRAME := preload("res://scripts/world/world_frame.gd")
const SNOW_SCENE := preload("res://scenes/environment/vfx/m1_snow_drift.tscn")


func build_layout() -> void:
	_build_ground()
	_build_south_gate()
	_build_gallery()
	_build_side_wings()
	_build_north_entrance()
	_build_backdrop()
	_build_details()
	_build_lights()
	_build_labels()
	_build_post_nightmare_content()


func _build_ground() -> void:
	structure(&"CampusPath", Vector3(0, -0.25, 0), Vector3(12, 0.5, 42), &"snow")
	structure(&"CampusWestWalk", Vector3(-9.0, -0.26, 0), Vector3(6, 0.5, 42), &"concrete")
	structure(&"CampusEastWalk", Vector3(9.0, -0.26, 0), Vector3(6, 0.5, 42), &"concrete")
	structure(&"CampusSouthPlaza", Vector3(0, -0.26, 17), Vector3(20, 0.5, 10), &"concrete")
	structure(&"CampusNorthPlaza", Vector3(0, -0.26, -17), Vector3(20, 0.5, 10), &"concrete")

	boundary(&"CampusWest", Vector3(-15.3, 3, 0), Vector3(0.5, 6, 44))
	boundary(&"CampusEast", Vector3(15.3, 3, 0), Vector3(0.5, 6, 44))
	boundary(&"CampusSouth", Vector3(0, 3, 22.4), Vector3(30, 6, 0.5))
	boundary(&"CampusNorth", Vector3(0, 3, -24.2), Vector3(30, 6, 0.5))

	# Расчищенные дорожки и снежные наносы.
	for z in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		prop_box(StringName("PathSnowWest%s" % str(z)), Vector3(-6.6, 0.1, z), Vector3(1.2, 0.2, 5.0), &"snow", 0.08)
		prop_box(StringName("PathSnowEast%s" % str(z)), Vector3(6.6, 0.1, z), Vector3(1.2, 0.2, 5.0), &"snow", -0.08)


func _build_south_gate() -> void:
	# Задние ворота: игрок выходит из сцены ворот через этот проём.
	structure(&"SouthGateWallWest", Vector3(-7.0, 3.2, 21.5), Vector3(10.0, 6.4, 1.0), &"concrete_dark")
	structure(&"SouthGateWallEast", Vector3(7.0, 3.2, 21.5), Vector3(10.0, 6.4, 1.0), &"concrete_dark")
	structure(&"SouthGateLintel", Vector3(0, 5.7, 21.5), Vector3(5.2, 1.2, 1.2), &"statue")
	structure(&"SouthGateDark", Vector3(0, 2.4, 22.15), Vector3(4.2, 4.8, 0.08), &"black", false)
	prop_box(&"SouthGateDoorWest", Vector3(-2.4, 1.8, 21.1), Vector3(0.1, 3.6, 0.08), &"metal_light")
	prop_box(&"SouthGateDoorEast", Vector3(2.4, 1.8, 21.1), Vector3(0.1, 3.6, 0.08), &"metal_light")
	label(&"SouthGateLabel", Vector3(0, 6.4, 21.5), "ВОРОТА · КАМПУС", Color(0.78, 0.88, 1.0, 0.9), 28)


func _build_gallery() -> void:
	# Крытая галерея по центру: крыша и колонны, но без глухих стен.
	structure(&"GalleryRoof", Vector3(0, 4.35, 0), Vector3(10.5, 0.3, 27), &"metal_dark")
	structure(&"GalleryBeamWest", Vector3(-4.7, 4.15, 0), Vector3(0.25, 0.4, 27), &"metal_light")
	structure(&"GalleryBeamEast", Vector3(4.7, 4.15, 0), Vector3(0.25, 0.4, 27), &"metal_light")
	for z in [-12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.0]:
		for x in [-4.4, 4.4]:
			prop_cylinder(StringName("GalleryColumn%s%s" % [str(x), str(z)]), Vector3(x, 2.0, z), 0.16, 4.0, &"metal_light", 10)
		prop_box(StringName("GalleryGlassWest%s" % str(z)), Vector3(-4.4, 3.4, z), Vector3(0.04, 1.1, 3.6), &"glass_blue")
		prop_box(StringName("GalleryGlassEast%s" % str(z)), Vector3(4.4, 3.4, z), Vector3(0.04, 1.1, 3.6), &"glass_blue")
		prop_box(StringName("GalleryLight%s" % str(z)), Vector3(0, 4.18, z), Vector3(1.6, 0.05, 0.2), &"screen_warm")
		omni(StringName("GalleryLamp%s" % str(z)), Vector3(0, 3.9, z), Color(1.0, 0.86, 0.64, 1), 1.2, 7.0)

	# Флаг Академии на южном краю.
	prop_cylinder(&"CampusFlagPole", Vector3(-7.0, 4.0, 17.0), 0.06, 8.0, &"metal_light", 10)
	prop_box(&"CampusFlag", Vector3(-5.9, 7.0, 17.0), Vector3(2.0, 1.1, 0.04), &"fabric_blue")


func _build_side_wings() -> void:
	for side in [-1.0, 1.0]:
		var x: float = 12.0 * side
		structure(
			StringName("Wing%s" % str(side)),
			Vector3(x, 5.0, 0),
			Vector3(8, 10, 32),
			&"concrete_dark"
		)
		structure(
			StringName("WingRoof%s" % str(side)),
			Vector3(x, 10.2, 0),
			Vector3(8.6, 0.4, 32.6),
			&"metal_dark",
			false
		)
		for index in 6:
			var z := -13.0 + 5.2 * float(index)
			prop_box(
				StringName("WingWindow%s%d" % [str(side), index]),
				Vector3(x - 4.02 * side, 5.2, z),
				Vector3(0.04, 2.2, 2.2),
				&"screen_warm"
			)
			prop_box(
				StringName("WingWindowLower%s%d" % [str(side), index]),
				Vector3(x - 4.02 * side, 2.2, z),
				Vector3(0.04, 1.2, 1.4),
				&"screen_cyan_dim"
			)
		# Входы в боковые корпуса; они визуальные, игровая зона — галерея.
		prop_box(StringName("WingDoor%s" % str(side)), Vector3(x - 4.02 * side, 1.3, -3.0), Vector3(0.05, 2.6, 1.4), &"metal_dark")

	# Скамьи и указатель в боковых карманах.
	bench(&"CampusBenchWest", Vector3(-7.4, 0, 7.0), 3.0, PI * 0.5)
	bench(&"CampusBenchEast", Vector3(7.4, 0, -7.0), 3.0, -PI * 0.5)
	prop_cylinder(&"CampusSignPost", Vector3(7.2, 2.0, 12.0), 0.06, 4.0, &"metal_dark", 8)
	prop_box(&"CampusSignBoard", Vector3(7.2, 3.6, 12.0), Vector3(2.0, 0.7, 0.08), &"metal_light")


func _build_north_entrance() -> void:
	# Фасад спального центра с тамбуром и спуском внутрь.
	structure(&"SleeperFacadeWest", Vector3(-7.0, 4.0, -22.0), Vector3(10.0, 8.0, 3.0), &"white")
	structure(&"SleeperFacadeEast", Vector3(7.0, 4.0, -22.0), Vector3(10.0, 8.0, 3.0), &"white")
	structure(&"SleeperLintel", Vector3(0, 5.8, -22.0), Vector3(5.0, 1.2, 3.2), &"metal_dark")
	structure(&"SleeperDoorDark", Vector3(0, 2.2, -22.6), Vector3(4.0, 4.4, 0.08), &"black", false)
	structure(&"SleeperCanopy", Vector3(0, 3.7, -19.9), Vector3(8.0, 0.2, 3.2), &"metal_dark")
	for x in [-3.4, 3.4]:
		prop_cylinder(StringName("SleeperCanopyPost%s" % str(x)), Vector3(x, 1.8, -19.9), 0.09, 3.6, &"metal_light", 8)
	prop_box(&"SleeperSign", Vector3(0, 3.1, -19.6), Vector3(4.2, 0.7, 0.08), &"screen_cyan_dim")
	label(&"SleeperSignLabel", Vector3(0, 3.15, -19.5), "СПАЛЬНЫЙ ЦЕНТР", Color(0.65, 0.88, 1.0, 0.95), 26)
	omni(&"SleeperCanopyLight", Vector3(0, 3.3, -19.6), Color(0.55, 0.82, 1.0, 1), 1.6, 7.0)


## The courtyard is enclosed by 10 m walls, but above them the world was empty.
## Distant campus wings, the Sleeper Center roof and a winter city skyline give
## the Academy the "city within a city" scale from canon.
func _build_backdrop() -> void:
	var backdrop := Node3D.new()
	backdrop.name = "Backdrop"
	_structure.add_child(backdrop)

	var ground := MeshInstance3D.new()
	ground.name = "CampusGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(900.0, 900.0)
	ground.mesh = plane
	ground.material_override = load("res://resources/locations/post_nightmare/materials/snow_night_ground.tres") as Material
	ground.position = Vector3(0.0, -0.08, 0.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.add_child(ground)

	var haze := Color(0.55, 0.60, 0.66)
	# The Sleeper Center is a large white block, not just a facade.
	WORLD_FRAME.mass_block(
		backdrop,
		Vector3(0.0, 7.0, -58.0),
		Vector3(64.0, 14.0, 46.0),
		Color(0.16, 0.17, 0.19),
		haze,
		0.38,
		"SleeperCenterMass"
	)
	WORLD_FRAME.mass_block(
		backdrop,
		Vector3(0.0, 15.0, -70.0),
		Vector3(34.0, 10.0, 22.0),
		Color(0.13, 0.14, 0.16),
		haze,
		0.42,
		"SleeperCenterUpper"
	)
	# Campus wings left and right, beyond the playable courtyard.
	for side in [-1.0, 1.0]:
		WORLD_FRAME.mass_block(
			backdrop,
			Vector3(46.0 * side, 8.0, -18.0),
			Vector3(28.0, 16.0, 42.0),
			Color(0.08, 0.09, 0.10),
			haze,
			0.36,
			"CampusWing%s" % str(side)
		)
		WORLD_FRAME.mass_block(
			backdrop,
			Vector3(58.0 * side, 13.0, 18.0),
			Vector3(18.0, 26.0, 24.0),
			Color(0.07, 0.08, 0.09),
			haze,
			0.40,
			"CampusTower%s" % str(side)
		)

	var palette := [
		Color(0.14, 0.15, 0.17),
		Color(0.18, 0.19, 0.22),
		Color(0.11, 0.12, 0.14),
	]
	WORLD_FRAME.city_skyline(
		backdrop,
		Vector3.ZERO,
		-0.35,
		95.0,
		300.0,
		30,
		16.0,
		64.0,
		palette,
		631,
		-PI * 0.5,
		0.50,
		"CampusSkyline",
		haze,
		130.0,
		820.0,
		Color(0.90, 0.75, 0.52),
		0.09,
		3.2,
		7.0,
		22.0,
		0.86,
		true
	)

	for i in 2:
		var snow := SNOW_SCENE.instantiate() as Node3D
		if snow == null:
			continue
		snow.name = "Snowfall%d" % i
		snow.position = Vector3(0.0, 2.0, -10.0 + float(i) * 22.0)
		backdrop.add_child(snow)
		for child in snow.get_children():
			var particles := child as GPUParticles3D
			if particles != null:
				particles.emitting = true
				particles.preprocess = 1.5


func _build_details() -> void:
	# Следы на снегу и фонари вдоль боковых дорожек.
	for z in [-13.0, -5.0, 5.0, 13.0]:
		prop_box(StringName("FootprintA%s" % str(z)), Vector3(-1.8, 0.015, z), Vector3(0.25, 0.01, 0.45), &"tile_wet", 0.3)
		prop_box(StringName("FootprintB%s" % str(z)), Vector3(1.2, 0.015, z + 0.8), Vector3(0.25, 0.01, 0.45), &"tile_wet", -0.3)
	for z in [-14.0, -6.0, 6.0, 14.0]:
		_campus_lamp(StringName("CampusLampWest%s" % str(z)), Vector3(-6.2, 0, z))
		_campus_lamp(StringName("CampusLampEast%s" % str(z)), Vector3(6.2, 0, z))


func _campus_lamp(light_id: StringName, position: Vector3) -> void:
	prop_cylinder(StringName("%sPole" % light_id), position + Vector3(0, 2.8, 0), 0.07, 5.6, &"metal_dark", 8)
	prop_box(StringName("%sHead" % light_id), position + Vector3(0, 5.55, 0), Vector3(0.45, 0.16, 0.3), &"metal_dark")
	prop_box(StringName("%sGlow" % light_id), position + Vector3(0, 5.45, 0), Vector3(0.34, 0.05, 0.2), &"screen_warm")
	omni(light_id, position + Vector3(0, 5.3, 0), Color(1.0, 0.86, 0.64, 1), 1.8, 10.0)


func _build_lights() -> void:
	omni(&"CampusAmbientA", Vector3(0, 4.0, 12.0), Color(0.72, 0.82, 1.0, 1), 1.0, 18.0)
	omni(&"CampusAmbientB", Vector3(0, 4.0, -12.0), Color(0.72, 0.82, 1.0, 1), 1.0, 18.0)
	omni(&"NorthEntranceGlow", Vector3(0, 2.4, -20.5), Color(0.55, 0.82, 1.0, 1), 1.8, 8.0)


func _build_labels() -> void:
	label(&"CampusLabel", Vector3(0, 3.6, 3.0), "КАМПУС АКАДЕМИИ", Color(0.78, 0.88, 1.0, 0.8), 30)
	label(&"GalleryLabel", Vector3(0, 3.9, 9.0), "КРЫТАЯ ГАЛЕРЕЯ", Color(1.0, 0.86, 0.64, 0.75), 24)
	label(&"WingWestLabel", Vector3(-11.8, 6.2, -3.0), "СТОЛОВАЯ", Color(0.92, 0.82, 0.64, 0.8), 22)
	label(&"WingEastLabel", Vector3(11.8, 6.2, -3.0), "ДОДЗЁ", Color(0.82, 0.78, 1.0, 0.8), 22)
	label(&"CampusDirectionsLabel", Vector3(7.2, 3.95, 12.0), "ВЫЖИВАНИЕ · SLEEPER CENTER", Color(0.7, 0.9, 1.0, 0.85), 16)


# ---------------------------------------------------------------------------
# M2: проводник по кампусу
# ---------------------------------------------------------------------------

func _build_post_nightmare_content() -> void:
	# P08: канонический терминал; проводник — optional placeholder, скрыт.
	_add_guide(&"CampusGuide", Vector3(3.0, 0.0, 6.0), PI, "mass_female")

	var terminal := Interactable.new()
	terminal.name = "CampusTerminal"
	terminal.interaction_id = &"campus_terminal"
	terminal.prompt = "Терминал: найти Sleeper Center"
	terminal.radius = 2.4
	terminal.enabled = not NightmareRunState.has_flag(&"dorm_assigned")
	terminal.position = Vector3(-2.5, 1.2, 4.0)
	add_child(terminal)
	terminal.interacted.connect(_on_campus_terminal_interacted)

	var guide := Interactable.new()
	guide.name = "CampusGuideInteract"
	guide.interaction_id = &"academy_campus_guide"
	guide.prompt = "Спросить дорогу"
	guide.radius = 2.4
	guide.enabled = false
	guide.position = Vector3(3.0, 1.2, 6.0)
	add_child(guide)
	guide.interacted.connect(_on_campus_guide_interacted)

	var portal := get_node_or_null(^"Portals/ToSleeper") as LevelPortal
	if portal != null:
		portal.required_flags = [&"dorm_assigned"]
		portal.set_flags_on_use = [&"p08_completed"]


func _add_guide(node_name: StringName, position: Vector3, rotation_y: float, archetype: String) -> void:
	var npc := MANNEQUIN_SCENE.instantiate() as Mannequin
	if npc == null:
		return
	npc.name = node_name
	npc.archetype = archetype
	npc.position = position
	npc.rotation.y = rotation_y
	npc.visible = false
	_props.add_child(npc)


func _on_campus_terminal_interacted(_id: StringName) -> void:
	if NightmareRunState.has_flag(&"dorm_assigned"):
		return
	NightmareRunState.set_flag(&"dorm_assigned")
	play_dialogue(GUIDE_SEQUENCE)
	set_scene_objective("Найти Sleeper Center.")
	var terminal := get_node_or_null(^"CampusTerminal") as Interactable
	if terminal != null:
		terminal.enabled = false


func _on_campus_guide_interacted(_id: StringName) -> void:
	if NightmareRunState.has_flag(&"dorm_assigned"):
		return
	NightmareRunState.set_flag(&"dorm_assigned")
