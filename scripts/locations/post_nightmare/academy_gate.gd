class_name AcademyGate
extends GreyboxLocation
## P03: ворота Академии.
##
## Открытая площадь перед стеной, две сторожевые башни и дорога внутрь.
## Прототип задаёт масштаб и маршрут; финальные фасады и толпа заменяются
## позже, не затрагивая Spawns/Shots.

const CHECKPOINT_SEQUENCE := preload("res://resources/dialogue/post_nightmare/p07_gate.tres")
const MANNEQUIN_SCENE := preload("res://scenes/slice/props/mannequin.tscn")
const WORLD_FRAME := preload("res://scripts/world/world_frame.gd")
const SNOW_SCENE := preload("res://scenes/environment/vfx/m1_snow_drift.tscn")


func build_layout() -> void:
	_build_ground()
	_build_wall_and_towers()
	_build_backdrop()
	_build_inner_road()
	_build_plaza_props()
	_build_transition_gates()
	_build_lights()
	_build_labels()
	_build_post_nightmare_content()


# ---------------------------------------------------------------------------
# Земля и стены
# ---------------------------------------------------------------------------

func _build_ground() -> void:
	structure(&"GatePlaza", Vector3(0, -0.25, 12), Vector3(40, 0.5, 24), &"asphalt")
	structure(&"PlazaInlay", Vector3(0, 0.01, 10), Vector3(10, 0.02, 18), &"concrete")
	structure(&"WestWalk", Vector3(-14, 0.01, 12), Vector3(6, 0.02, 22), &"concrete")
	structure(&"EastWalk", Vector3(14, 0.01, 12), Vector3(6, 0.02, 22), &"concrete")

	boundary(&"BoundarySouth", Vector3(0, 3, 25), Vector3(44, 6, 0.5))
	boundary(&"BoundaryWest", Vector3(-21, 3, 12), Vector3(0.5, 6, 28))
	boundary(&"BoundaryEast", Vector3(21, 3, 12), Vector3(0.5, 6, 28))
	boundary(&"BoundaryInnerWest", Vector3(-7.5, 3, -13), Vector3(0.5, 6, 27))
	boundary(&"BoundaryInnerEast", Vector3(7.5, 3, -13), Vector3(0.5, 6, 27))
	# Северная стена разорвана центральным проходом к кампусу.
	boundary(&"BoundaryNorthWest", Vector3(-10, 3, -26.5), Vector3(12, 6, 0.5))
	boundary(&"BoundaryNorthEast", Vector3(10, 3, -26.5), Vector3(12, 6, 0.5))
	boundary(&"BoundaryNorthBack", Vector3(0, 3, -28.0), Vector3(9, 6, 0.5))


func _build_wall_and_towers() -> void:
	# Стена разорвана башнями: проход идёт между ними, а не сквозь стену.
	structure(&"WallWest", Vector3(-14, 3.5, 0), Vector3(10, 7, 1.3), &"concrete_dark")
	structure(&"WallEast", Vector3(14, 3.5, 0), Vector3(10, 7, 1.3), &"concrete_dark")
	structure(&"WallCapWest", Vector3(-14, 7.15, 0), Vector3(10.4, 0.3, 1.7), &"statue")
	structure(&"WallCapEast", Vector3(14, 7.15, 0), Vector3(10.4, 0.3, 1.7), &"statue")

	room(
		&"GateTowerWest",
		Vector3(-5.5, 0, 0),
		Vector3(7, 6, 8),
		&"concrete_dark",
		[
			{"side": &"south", "width": 2.4, "height": 2.8},
			{"side": &"north", "width": 2.4, "height": 2.8},
			{"side": &"east", "width": 2.4, "height": 2.8},
		],
		{"floor_material": &"tile", "wall_material": &"concrete_dark", "ceiling_material": &"concrete_dark"}
	)
	room(
		&"GateTowerEast",
		Vector3(5.5, 0, 0),
		Vector3(7, 6, 8),
		&"concrete_dark",
		[
			{"side": &"south", "width": 2.4, "height": 2.8},
			{"side": &"north", "width": 2.4, "height": 2.8},
			{"side": &"west", "width": 2.4, "height": 2.8},
		],
		{"floor_material": &"tile", "wall_material": &"concrete_dark", "ceiling_material": &"concrete_dark"}
	)

	# Арка над проёмом и звезда Академии.
	structure(&"GateArch", Vector3(0, 6.1, 0), Vector3(4.8, 1.2, 1.5), &"statue")
	prop_box(&"GateArchTrim", Vector3(0, 5.45, 0), Vector3(5.2, 0.18, 1.7), &"metal_light")
	statue_star(&"AcademyStar", Vector3(0, 7.4, 0), 1.4)

	# Створки ворот открыты внутрь и стоят у башен.
	prop_box(&"GateLeafWest", Vector3(-2.55, 1.8, -1.2), Vector3(1.0, 3.6, 0.12), &"metal_dark", -0.9)
	prop_box(&"GateLeafEast", Vector3(2.55, 1.8, -1.2), Vector3(1.0, 3.6, 0.12), &"metal_dark", 0.9)
	prop_box(&"GateBraceWest", Vector3(-2.55, 1.8, -1.15), Vector3(0.9, 0.12, 0.08), &"metal_light", -0.9)
	prop_box(&"GateBraceEast", Vector3(2.55, 1.8, -1.15), Vector3(0.9, 0.12, 0.08), &"metal_light", 0.9)


## The gate wall is only 38 m wide in the greybox. A longer wall, side towers
## and a winter city skyline make the Academy read as a "city within a city"
## instead of a facade standing alone on a plaza.
func _build_backdrop() -> void:
	var backdrop := Node3D.new()
	backdrop.name = "Backdrop"
	_structure.add_child(backdrop)

	var ground := MeshInstance3D.new()
	ground.name = "GateGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(900.0, 900.0)
	ground.mesh = plane
	ground.material_override = load("res://resources/locations/post_nightmare/materials/snow_night_ground.tres") as Material
	ground.position = Vector3(0.0, -0.08, 0.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.add_child(ground)

	var haze := Color(0.55, 0.60, 0.66)
	# Wall continuation left and right, with towers at the far ends.
	WORLD_FRAME.mass_block(
		backdrop,
		Vector3(-52.0, 3.5, 0.0),
		Vector3(76.0, 7.0, 1.3),
		Color(0.045, 0.050, 0.060),
		haze,
		0.34,
		"WallFarWest"
	)
	WORLD_FRAME.mass_block(
		backdrop,
		Vector3(52.0, 3.5, 0.0),
		Vector3(76.0, 7.0, 1.3),
		Color(0.045, 0.050, 0.060),
		haze,
		0.34,
		"WallFarEast"
	)
	for i in 3:
		var x := 30.0 + float(i) * 22.0
		for side in [-1.0, 1.0]:
			WORLD_FRAME.mass_block(
				backdrop,
				Vector3(x * side, 6.0, 0.0),
				Vector3(8.0, 12.0, 8.0),
				Color(0.040, 0.045, 0.055),
				haze,
				0.32,
				"WallTower%s%d" % [str(side), i]
			)

	var palette := [
		Color(0.14, 0.15, 0.17),
		Color(0.18, 0.19, 0.22),
		Color(0.11, 0.12, 0.14),
	]
	# City blocks behind and beside the player. The northern gap keeps the
	# gate and the inner road readable.
	WORLD_FRAME.city_skyline(
		backdrop,
		Vector3.ZERO,
		-0.35,
		70.0,
		260.0,
		32,
		14.0,
		58.0,
		palette,
		523,
		-PI * 0.5,
		0.46,
		"GateSkyline",
		haze,
		110.0,
		760.0,
		Color(0.90, 0.75, 0.52),
		0.10,
		3.0,
		6.0,
		20.0,
		0.86,
		true
	)

	# A few lit windows on the far wall towers. The mass blocks are unshaded,
	# so these are simple emissive quads rather than a second shader.
	for i in 3:
		var x := 30.0 + float(i) * 22.0
		for side in [-1.0, 1.0]:
			for row in 3:
				prop_box(
					StringName("FarTowerWindow%s%d%d" % [str(side), i, row]),
					Vector3(x * side, 4.0 + float(row) * 3.0, -4.05),
					Vector3(1.0, 0.7, 0.04),
					&"screen_warm"
				)

	for i in 2:
		var snow := SNOW_SCENE.instantiate() as Node3D
		if snow == null:
			continue
		snow.name = "Snowfall%d" % i
		snow.position = Vector3(0.0, 2.0, 4.0 + float(i) * 16.0)
		backdrop.add_child(snow)
		for child in snow.get_children():
			var particles := child as GPUParticles3D
			if particles != null:
				particles.emitting = true
				particles.preprocess = 1.5


func _build_inner_road() -> void:
	structure(&"InnerRoad", Vector3(0, -0.25, -13), Vector3(14, 0.5, 26), &"snow")
	structure(&"InnerRoadEdgeWest", Vector3(-7.2, 0.01, -13), Vector3(0.4, 0.06, 26), &"concrete_dark")
	structure(&"InnerRoadEdgeEast", Vector3(7.2, 0.01, -13), Vector3(0.4, 0.06, 26), &"concrete_dark")

	# Дальний корпус Академии — силуэт за туманом, не игровая зона.
	structure(&"AcademyFacade", Vector3(0, 9, -36), Vector3(36, 18, 8), &"concrete_dark")
	structure(&"AcademyWingWest", Vector3(-16, 6, -31), Vector3(10, 12, 14), &"concrete_dark")
	structure(&"AcademyWingEast", Vector3(16, 6, -31), Vector3(10, 12, 14), &"concrete_dark")
	structure(&"AcademyRoof", Vector3(0, 18.4, -36), Vector3(38, 0.8, 10), &"metal_dark")

	for i in 7:
		var x := -12.0 + 4.0 * float(i)
		prop_box(
			StringName("FacadeWindow%d" % i),
			Vector3(x, 7.5, -31.92),
			Vector3(1.6, 3.0, 0.05),
			&"screen_warm"
		)
		prop_box(
			StringName("FacadeWindowUpper%d" % i),
			Vector3(x, 13.0, -31.92),
			Vector3(1.4, 2.2, 0.05),
			&"screen_warm"
		)

	# Фонари вдоль внутренней дороги.
	for i in 3:
		var z := -5.0 - 8.0 * float(i)
		_lamp(StringName("RoadLampWest%d" % i), Vector3(-6.2, 0, z))
		_lamp(StringName("RoadLampEast%d" % i), Vector3(6.2, 0, z))


# ---------------------------------------------------------------------------
# Площадь и переходы
# ---------------------------------------------------------------------------

## Южные ворота ведут на подъездную улицу, северный проход — на кампус.
## Обе точки оформлены как реальные проёмы, а не как невидимые телепорты.
func _build_transition_gates() -> void:
	# Южный выездной пост на краю площади.
	prop_box(&"SouthPostWest", Vector3(-4.5, 2.2, 24.4), Vector3(1.0, 4.4, 1.0), &"concrete_dark", 0.0, true)
	prop_box(&"SouthPostEast", Vector3(4.5, 2.2, 24.4), Vector3(1.0, 4.4, 1.0), &"concrete_dark", 0.0, true)
	prop_box(&"SouthLintel", Vector3(0, 4.55, 24.4), Vector3(10.0, 0.5, 1.2), &"statue")
	prop_box(&"SouthLamp", Vector3(0, 4.05, 23.75), Vector3(4.0, 0.08, 0.2), &"screen_warm")
	label(&"SouthGateLabel", Vector3(0, 5.35, 24.4), "ВЫЕЗД · ГОРОД", Color(1.0, 0.86, 0.64, 0.9), 28)

	# Северный служебный проход за внутренней дорогой.
	prop_box(&"CampusPostWest", Vector3(-3.1, 2.6, -26.4), Vector3(1.1, 5.2, 1.2), &"concrete_dark", 0.0, true)
	prop_box(&"CampusPostEast", Vector3(3.1, 2.6, -26.4), Vector3(1.1, 5.2, 1.2), &"concrete_dark", 0.0, true)
	prop_box(&"CampusLintel", Vector3(0, 5.35, -26.4), Vector3(7.0, 0.6, 1.4), &"statue")
	prop_box(&"CampusDark", Vector3(0, 2.4, -28.02), Vector3(7.4, 4.8, 0.08), &"black")
	label(&"CampusGateLabel", Vector3(0, 6.0, -26.4), "КАМПУС · СПАЛЬНЫЙ ЦЕНТР", Color(0.72, 0.88, 1.0, 0.9), 24)


func _build_plaza_props() -> void:
	# Пост проверки в восточной башне.
	counter(&"CheckpointCounter", Vector3(5.5, 0, 1.8), Vector2(3.2, 0.8))
	terminal(&"CheckpointTerminal", Vector3(4.2, 0, 1.8))
	chair(&"CheckpointChair", Vector3(6.8, 0, 1.8), PI)
	locker(&"CheckpointLocker", Vector3(8.2, 0, -2.6), PI * 0.5, 0.9)
	locker(&"CheckpointLockerB", Vector3(8.2, 0, -1.6), PI * 0.5, 0.9)

	# Очередь перед воротами: барьеры и скамьи.
	for i in 4:
		var x := -8.0 + 2.4 * float(i)
		prop_box(
			StringName("QueuePost%d" % i),
			Vector3(x, 0.55, 6.0),
			Vector3(0.12, 1.1, 0.12),
			&"metal_light"
		)
		prop_box(
			StringName("QueueRope%d" % i),
			Vector3(x + 1.2, 0.9, 6.0),
			Vector3(2.3, 0.05, 0.05),
			&"metal_dark"
		)
	bench(&"PlazaBenchWest", Vector3(-10.0, 0, 14.0), 3.0, 0.0)
	bench(&"PlazaBenchEast", Vector3(10.0, 0, 14.0), 3.0, PI)
	# Южная скамья сдвинута с оси появления: иначе она перекрывает
	# нижнюю часть кадра от третьего лица.
	bench(&"PlazaBenchSouth", Vector3(7.5, 0, 21.5), 4.0, PI)

	# Доска объявлений и ящики для вещей.
	prop_box(&"NoticeFrame", Vector3(-12.5, 1.7, 19.5), Vector3(2.6, 2.2, 0.12), &"wood_dark", 0.1)
	prop_box(&"NoticeSurface", Vector3(-12.5, 1.7, 19.42), Vector3(2.3, 1.9, 0.02), &"white", 0.1)
	prop_box(&"CrateA", Vector3(13.5, 0.55, 18.0), Vector3(1.1, 1.1, 1.1), &"wood_dark", 0.2, true)
	prop_box(&"CrateB", Vector3(13.8, 1.45, 18.1), Vector3(0.8, 0.8, 0.8), &"wood_dark", -0.3, true)
	prop_box(&"CrateC", Vector3(-14.5, 0.45, 8.0), Vector3(0.9, 0.9, 0.9), &"wood_dark", 0.4, true)

	# Путевой указатель и флаг Академии.
	prop_cylinder(&"SignPost", Vector3(13.0, 2.0, 7.0), 0.06, 4.0, &"metal_dark", 8)
	prop_box(&"SignBoard", Vector3(13.0, 3.6, 7.0), Vector3(2.2, 0.8, 0.08), &"metal_light")
	prop_cylinder(&"AcademyFlagPole", Vector3(-4.0, 4.0, 20.0), 0.06, 8.0, &"metal_light", 10)
	prop_box(&"AcademyFlag", Vector3(-2.9, 7.2, 20.0), Vector3(2.0, 1.2, 0.04), &"fabric_blue")


func _lamp(light_id: StringName, position: Vector3) -> void:
	prop_cylinder(StringName("%sPole" % light_id), position + Vector3(0, 2.8, 0), 0.06, 5.6, &"metal_dark", 8)
	prop_box(StringName("%sHead" % light_id), position + Vector3(0, 5.6, 0), Vector3(0.45, 0.16, 0.3), &"metal_dark")
	prop_box(StringName("%sGlow" % light_id), position + Vector3(0, 5.5, 0), Vector3(0.34, 0.05, 0.2), &"screen_warm")
	omni(light_id, position + Vector3(0, 5.3, 0), Color(1.0, 0.88, 0.68, 1), 1.8, 11.0)


# ---------------------------------------------------------------------------
# Свет и подписи
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	_lamp(&"PlazaLampWest", Vector3(-8.5, 0, 9.0))
	_lamp(&"PlazaLampEast", Vector3(8.5, 0, 9.0))
	# Фонарь у стартовой площадки вынесен с центральной оси.
	_lamp(&"PlazaLampSouth", Vector3(-8.0, 0, 19.0))
	omni(&"GateTowerWestLight", Vector3(-5.5, 4.8, 0), Color(1.0, 0.9, 0.72, 1), 1.6, 8.0)
	omni(&"GateTowerEastLight", Vector3(5.5, 4.8, 0), Color(1.0, 0.9, 0.72, 1), 1.6, 8.0)
	spot(&"GateFloodWest", Vector3(-8.0, 8.0, 7.0), Vector3(0, 2.0, 0), Color(1.0, 0.92, 0.8, 1), 5.0, 24.0, 30.0)
	spot(&"GateFloodEast", Vector3(8.0, 8.0, 7.0), Vector3(0, 2.0, 0), Color(1.0, 0.92, 0.8, 1), 5.0, 24.0, 30.0)
	omni(&"ArchGlow", Vector3(0, 7.4, 0), Color(0.55, 0.75, 1.0, 1), 2.0, 8.0)


func _build_labels() -> void:
	label(&"GateLabel", Vector3(0, 8.9, 1.0), "ВОРОТА АКАДЕМИИ", Color(0.78, 0.88, 1.0, 0.95), 44)
	label(&"CheckpointLabel", Vector3(5.5, 3.0, 4.2), "ПОСТ ПРОВЕРКИ", Color(1.0, 0.86, 0.64, 0.9), 26)
	label(&"InnerRoadLabel", Vector3(0, 3.2, -8.0), "ВНУТРЕННЯЯ ДОРОГА", Color(0.8, 0.88, 1.0, 0.8), 28)


# ---------------------------------------------------------------------------
# M2: проверка на воротах
# ---------------------------------------------------------------------------

func _build_post_nightmare_content() -> void:
	_add_guard(&"GateGuard", Vector3(5.5, 0.0, 3.0), PI, "police_guard")
	# P07: первый силуэт Нефис за аркой; не интерактивен, не блокирует.
	_add_guard(&"NephisSilhouette", Vector3(6.0, 0.0, -5.0), 0.0, "mass_female")

	var gate := Interactable.new()
	gate.name = "GateCheckpointInteract"
	gate.interaction_id = &"academy_gate_checkpoint"
	gate.prompt = "Пройти проверку"
	gate.radius = 2.5
	gate.enabled = true
	gate.position = Vector3(5.5, 1.2, 3.0)
	add_child(gate)
	gate.interacted.connect(_on_gate_checkpoint_interacted)

	var nephis_trigger := TriggerZone.new()
	nephis_trigger.name = "NephisGateTrigger"
	nephis_trigger.trigger_id = &"nephis_at_gate"
	nephis_trigger.enabled = not NightmareRunState.has_flag(&"nephis_seen_at_gate")
	nephis_trigger.collision_layer = 0
	nephis_trigger.collision_mask = 2
	var nephis_shape := CollisionShape3D.new()
	var nephis_box := BoxShape3D.new()
	nephis_box.size = Vector3(10.0, 2.4, 3.0)
	nephis_shape.shape = nephis_box
	nephis_trigger.add_child(nephis_shape)
	nephis_trigger.position = Vector3(0.0, 1.2, 5.0)
	add_child(nephis_trigger)
	nephis_trigger.triggered.connect(_on_nephis_gate_triggered)

	var portal := get_node_or_null(^"Portals/ToCampus") as LevelPortal
	if portal != null:
		portal.enabled = NightmareRunState.has_flag(&"academy_gate_passed")
		portal.required_flags = [&"academy_gate_passed"]
		portal.set_flags_on_use = [&"p07_completed"]


func _add_guard(node_name: StringName, position: Vector3, rotation_y: float, archetype: String) -> void:
	var guard := MANNEQUIN_SCENE.instantiate() as Mannequin
	if guard == null:
		return
	guard.name = node_name
	guard.archetype = archetype
	guard.position = position
	guard.rotation.y = rotation_y
	_props.add_child(guard)


func _on_gate_checkpoint_interacted(_id: StringName) -> void:
	play_dialogue(CHECKPOINT_SEQUENCE)
	NightmareRunState.set_flag(&"academy_gate_passed")
	set_scene_objective("Войти в кампус академии.")
	var portal := get_node_or_null(^"Portals/ToCampus") as LevelPortal
	if portal != null:
		portal.enabled = true


func _on_nephis_gate_triggered(_id: StringName) -> void:
	if NightmareRunState.has_flag(&"nephis_seen_at_gate"):
		return
	NightmareRunState.set_flag(&"nephis_seen_at_gate")
	var trigger := get_node_or_null(^"NephisGateTrigger") as TriggerZone
	if trigger != null:
		trigger.enabled = false
