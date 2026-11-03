class_name PolicePrecinct
extends GreyboxLocation
## P01–P02: полицейский участок после Первого Кошмара.
##
## Серобокс-прототип, а не финальная локация. Двор, приёмная, коридор,
## камеры и допросная собраны из модулей GreyboxLocation. Внешний вид
## (материалы, свет, реквизит) можно менять, не трогая Spawns и Shots.

const WAKE_SEQUENCE := preload("res://resources/dialogue/post_nightmare/p05_jett_awakening.tres")
const MIRROR_SEQUENCE := preload("res://resources/dialogue/post_nightmare/p05_mirror.tres")
const EXIT_SEQUENCE := preload("res://resources/dialogue/post_nightmare/p05_exit.tres")
const MANNEQUIN_SCENE := preload("res://scenes/slice/props/mannequin.tscn")

var _jett_interact: Interactable
var _mirror_interact: Interactable


func build_layout() -> void:
	_build_ground()
	_build_intake_hall()
	_build_cell_block()
	_build_interrogation()
	_build_yard()
	_build_lights()
	_build_labels()
	_build_post_nightmare_content()


# ---------------------------------------------------------------------------
# Земля и границы
# ---------------------------------------------------------------------------

func _build_ground() -> void:
	# Передний двор перед входом. Верх плиты совпадает с уровнем пола (y = 0).
	structure(&"Forecourt", Vector3(0, -0.25, 11), Vector3(34, 0.5, 10), &"asphalt")
	structure(&"WestApron", Vector3(-14, -0.25, 0), Vector3(6, 0.5, 20), &"asphalt")
	structure(&"EastApron", Vector3(14, -0.25, 0), Vector3(6, 0.5, 20), &"asphalt")
	structure(&"RearYard", Vector3(0, -0.25, -23), Vector3(34, 0.5, 6), &"concrete_dark")

	# Низкая бетонная ограда вместо финального забора. Проходы оставлены
	# там, где игрок должен видеть продолжение улицы.
	structure(&"FenceWest", Vector3(-17.2, 1.4, 7), Vector3(0.3, 2.8, 18), &"concrete_dark")
	structure(&"FenceEast", Vector3(17.2, 1.4, 7), Vector3(0.3, 2.8, 18), &"concrete_dark")
	structure(&"FenceRear", Vector3(0, 1.4, -25.8), Vector3(34.4, 2.8, 0.3), &"concrete_dark")
	structure(&"FenceFrontWest", Vector3(-12, 1.4, 16), Vector3(10, 2.8, 0.3), &"concrete_dark")
	structure(&"FenceFrontEast", Vector3(12, 1.4, 16), Vector3(10, 2.8, 0.3), &"concrete_dark")

	boundary(&"BoundaryWest", Vector3(-18, 3, 4), Vector3(0.5, 6, 28))
	boundary(&"BoundaryEast", Vector3(18, 3, 4), Vector3(0.5, 6, 28))
	boundary(&"BoundarySouth", Vector3(0, 3, 17), Vector3(36, 6, 0.5))
	boundary(&"BoundaryNorth", Vector3(0, 3, -26.2), Vector3(36, 6, 0.5))


# ---------------------------------------------------------------------------
# Приёмная и камеры
# ---------------------------------------------------------------------------

func _build_intake_hall() -> void:
	room(
		&"IntakeHall",
		Vector3(0, 0, 0),
		Vector3(20, 4.4, 12),
		&"concrete",
		[
			{"side": &"south", "width": 4.2, "height": 3.2},
			{"side": &"north", "width": 3.0, "height": 3.2},
			{"side": &"west", "width": 2.2, "height": 2.6, "offset": -2.0},
		],
		{"floor_material": &"tile", "wall_material": &"concrete", "ceiling_material": &"concrete_dark"}
	)

	# Стойка дежурного разворачивает поток к допросной и камерам.
	counter(&"ReceptionCounter", Vector3(1, 0, -3.2), Vector2(6.0, 0.9))
	chair(&"ReceptionChair", Vector3(1, 0, -4.4), PI)
	terminal(&"ReceptionTerminal", Vector3(-0.9, 0, -2.75))
	terminal(&"ReceptionTerminalB", Vector3(3.0, 0, -2.75))

	bench(&"WaitingBenchA", Vector3(7.6, 0, 0.5), 3.2, PI * 0.5)
	bench(&"WaitingBenchB", Vector3(7.6, 0, 3.2), 3.2, PI * 0.5)
	vending(&"Vending", Vector3(7.7, 0, 5.0), PI)
	locker(&"CaseLockers", Vector3(-8.4, 0, 3.4), PI * 0.5, 0.9)
	locker(&"CaseLockersB", Vector3(-8.4, 0, 4.4), PI * 0.5, 0.9)

	# Доска розыска и часы — простые пятна цвета на стене.
	prop_box(&"NoticeBoard", Vector3(-5.5, 2.2, -5.62), Vector3(2.8, 1.5, 0.08), &"wood_dark")
	prop_box(&"NoticePaper", Vector3(-5.5, 2.2, -5.55), Vector3(2.4, 1.15, 0.02), &"white")
	prop_box(&"WallClock", Vector3(5.5, 3.1, -5.62), Vector3(0.8, 0.8, 0.08), &"metal_dark")
	prop_box(&"ClockFace", Vector3(5.5, 3.1, -5.55), Vector3(0.64, 0.64, 0.02), &"white")


func _build_cell_block() -> void:
	room(
		&"NorthConnector",
		Vector3(0, 0, -8),
		Vector3(4, 3.2, 4),
		&"concrete_dark",
		[
			{"side": &"south", "width": 4.0, "height": 3.2},
			{"side": &"north", "width": 4.0, "height": 3.2},
		],
		{"floor_material": &"tile", "wall_material": &"concrete_dark"}
	)

	room(
		&"CellBlock",
		Vector3(0, 0, -15),
		Vector3(14, 3.4, 10),
		&"concrete_dark",
		[{"side": &"south", "width": 4.0, "height": 3.2}],
		{"floor_material": &"concrete_dark", "wall_material": &"concrete_dark", "ceiling_material": &"concrete_dark"}
	)

	# Решётки камер: вертикальные прутья и две перекладины. Это реквизит,
	# а не коллизия — проход в камеры остаётся свободным для прототипа.
	for side in [-1.0, 1.0]:
		var x: float = 2.2 * side
		var prefix := "West" if side < 0.0 else "East"
		for i in 17:
			var z := -19.0 + 0.5 * float(i)
			# Оставляем проём двери в середине ряда.
			if absf(z + 15.0) < 0.9:
				continue
			prop_cylinder(
				StringName("Bars%s%d" % [prefix, i]),
				Vector3(x, 1.45, z),
				0.035,
				2.9,
				&"metal_light",
				8
			)
		prop_box(
			StringName("Bars%sTop" % prefix),
			Vector3(x, 2.75, -15.0),
			Vector3(0.06, 0.07, 8.0),
			&"metal_light"
		)
		prop_box(
			StringName("Bars%sMid" % prefix),
			Vector3(x, 1.45, -15.0),
			Vector3(0.06, 0.06, 8.0),
			&"metal_light"
		)

	var bed_id := 1
	for z in [-18.2, -15.7, -13.2]:
		for side in [-1.0, 1.0]:
			# East beds sit closer to the wall so the canonical spawn (5.0, 0.2,
			# -18.2) is beside the bunk, not inside its mattress.
			var bed_x: float = 6.1 if side > 0.0 else -5.0
			bed(
				StringName("CellBed%d" % bed_id),
				Vector3(bed_x, 0, z),
				PI * 0.5,
				false
			)
			bed_id += 1

	bench(&"CellBench", Vector3(0, 0, -19.2), 2.4, 0.0)
	sink(&"CellSink", Vector3(6.3, 0, -11.2), PI)
	terminal(&"CellLog", Vector3(-6.3, 0, -10.8), 0.0)

	label(
		&"CellBlockLabel",
		Vector3(0, 3.0, -10.2),
		"КАМЕРЫ",
		Color(0.75, 0.82, 0.9, 0.85),
		36
	)


func _build_interrogation() -> void:
	room(
		&"WestConnector",
		Vector3(-11, 0, -2),
		Vector3(4, 3.0, 3),
		&"concrete",
		[
			{"side": &"east", "width": 3.0, "height": 3.0},
			{"side": &"west", "width": 3.0, "height": 3.0},
		],
		{"floor_material": &"tile", "wall_material": &"concrete"}
	)

	room(
		&"Interrogation",
		Vector3(-16, 0, -2),
		Vector3(6, 3.2, 7),
		&"concrete",
		[{"side": &"east", "width": 2.2, "height": 2.6}],
		{"floor_material": &"concrete_dark", "wall_material": &"concrete", "ceiling_material": &"concrete_dark"}
	)

	table(&"InterrogationTable", Vector3(-16, 0, -2), Vector2(2.0, 1.0))
	chair(&"SuspectChair", Vector3(-16, 0, -3.4), 0.0)
	chair(&"OfficerChair", Vector3(-16, 0, -0.6), PI)

	# Одностороннее зеркало и лампа над столом.
	prop_box(&"MirrorFrame", Vector3(-19.62, 1.8, -2), Vector3(0.08, 2.2, 3.2), &"metal_dark")
	prop_box(&"MirrorGlass", Vector3(-19.55, 1.8, -2), Vector3(0.02, 2.0, 3.0), &"mirror")
	prop_box(&"LampShade", Vector3(-16, 2.85, -2), Vector3(0.9, 0.12, 0.9), &"metal_dark")
	prop_box(&"CaseFile", Vector3(-15.6, 0.79, -2.2), Vector3(0.5, 0.05, 0.7), &"white")

	label(
		&"InterrogationLabel",
		Vector3(-13.2, 2.6, -2),
		"ДОПРОС",
		Color(0.95, 0.8, 0.65, 0.9),
		34
	)


# ---------------------------------------------------------------------------
# Двор
# ---------------------------------------------------------------------------

func _build_yard() -> void:
	_police_car(&"Cruiser", Vector3(10.5, 0, 11.5), PI * 0.5)

	# Ограждения у входа и служебный контейнер.
	prop_box(&"BarrierA", Vector3(-3.2, 0.55, 14.4), Vector3(2.6, 1.1, 0.18), &"metal_light", 0.0, true)
	prop_box(&"BarrierB", Vector3(3.2, 0.55, 14.4), Vector3(2.6, 1.1, 0.18), &"metal_light", 0.0, true)
	prop_box(&"BarrierFootA", Vector3(-4.4, 0.18, 14.4), Vector3(0.3, 0.36, 0.7), &"metal_dark")
	prop_box(&"BarrierFootB", Vector3(-2.0, 0.18, 14.4), Vector3(0.3, 0.36, 0.7), &"metal_dark")
	prop_box(&"BarrierFootC", Vector3(2.0, 0.18, 14.4), Vector3(0.3, 0.36, 0.7), &"metal_dark")
	prop_box(&"BarrierFootD", Vector3(4.4, 0.18, 14.4), Vector3(0.3, 0.36, 0.7), &"metal_dark")

	prop_box(&"UtilityContainer", Vector3(-14.5, 1.25, 10.5), Vector3(3.2, 2.5, 2.2), &"metal_red", 0.15, true)
	prop_box(&"ContainerDoor", Vector3(-14.5, 1.2, 11.62), Vector3(1.0, 2.1, 0.06), &"metal_dark", 0.15)
	prop_box(&"UtilityCrateA", Vector3(14.0, 0.5, 8.0), Vector3(1.1, 1.0, 1.1), &"wood_dark", 0.4, true)
	prop_box(&"UtilityCrateB", Vector3(14.3, 1.4, 8.1), Vector3(0.8, 0.8, 0.8), &"wood_dark", -0.2, true)

	# Флагшток и флаг участка.
	prop_cylinder(&"FlagPole", Vector3(-8.5, 4.0, 12.0), 0.06, 8.0, &"metal_light", 10)
	prop_box(&"Flag", Vector3(-7.4, 7.2, 12.0), Vector3(2.0, 1.2, 0.04), &"fabric_blue")
	prop_sphere(&"FlagTop", Vector3(-8.5, 8.05, 12.0), 0.14, &"metal_light", 10)


func _police_car(prop_id: StringName, position: Vector3, rotation_y: float) -> Node3D:
	var root := _prop_root(prop_id, position, rotation_y)
	_prop_box(root, &"Body", Vector3(0, 0.62, 0), Vector3(4.5, 0.72, 1.9), &"paint_white")
	_prop_box(root, &"Cabin", Vector3(0.25, 1.18, 0), Vector3(2.1, 0.62, 1.72), &"glass_blue")
	_prop_box(root, &"Hood", Vector3(-1.85, 0.9, 0), Vector3(0.8, 0.12, 1.78), &"paint_white")
	_prop_box(root, &"Trunk", Vector3(1.85, 0.9, 0), Vector3(0.7, 0.12, 1.78), &"paint_white")
	_prop_box(root, &"LightBar", Vector3(0.25, 1.55, 0), Vector3(1.0, 0.14, 0.28), &"metal_dark")
	_prop_box(root, &"LightBlue", Vector3(0.0, 1.58, 0), Vector3(0.28, 0.1, 0.24), &"glass_blue")
	_prop_box(root, &"LightRed", Vector3(0.5, 1.58, 0), Vector3(0.28, 0.1, 0.24), &"red_glow")
	_prop_box(root, &"BumperFront", Vector3(-2.28, 0.45, 0), Vector3(0.12, 0.24, 1.95), &"metal_dark")
	_prop_box(root, &"BumperRear", Vector3(2.28, 0.45, 0), Vector3(0.12, 0.24, 1.95), &"metal_dark")
	for x in [-1.45, 1.45]:
		for z in [-0.98, 0.98]:
			_prop_cylinder(
				root,
				StringName("Wheel_%s_%s" % [str(x), str(z)]),
				Vector3(x, 0.36, z),
				0.36,
				0.22,
				&"black",
				14,
				Vector3(0.0, 0.0, PI * 0.5)
			)
	omni(StringName("%sBeacon" % prop_id), position + Vector3(0.3, 2.1, 0), Color(0.3, 0.55, 1.0, 1), 1.2, 4.0)
	return root


# ---------------------------------------------------------------------------
# Свет и подписи
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	omni(&"HallLightA", Vector3(-5, 3.9, 0), Color(0.9, 0.95, 1.0, 1), 2.2, 12.0)
	omni(&"HallLightB", Vector3(5, 3.9, 0), Color(0.9, 0.95, 1.0, 1), 2.2, 12.0)
	omni(&"HallLightSouth", Vector3(0, 3.9, 4), Color(0.9, 0.95, 1.0, 1), 1.6, 9.0)
	omni(&"CellLight", Vector3(0, 2.9, -15), Color(0.75, 0.85, 1.0, 1), 2.4, 12.0)
	omni(&"CellLightBack", Vector3(0, 2.9, -19), Color(0.7, 0.8, 0.95, 1), 1.4, 7.0)
	omni(&"ConnectorLight", Vector3(0, 2.8, -8), Color(0.85, 0.9, 1.0, 1), 1.2, 5.0)
	spot(&"InterrogationLight", Vector3(-16, 2.75, -2), Vector3(-16, 0, -2), Color(1.0, 0.88, 0.7, 1), 5.0, 8.0, 32.0)
	omni(&"InterrogationFill", Vector3(-18.5, 2.4, 1.0), Color(1.0, 0.82, 0.62, 1), 0.8, 6.0)

	_pole_light(&"YardLampWest", Vector3(-10.5, 0, 9.5))
	_pole_light(&"YardLampEast", Vector3(9.5, 0, 9.0))
	_pole_light(&"YardLampGate", Vector3(-7.0, 0, 15.2))


func _pole_light(light_id: StringName, position: Vector3) -> void:
	prop_cylinder(StringName("%sPole" % light_id), position + Vector3(0, 3.0, 0), 0.07, 6.0, &"metal_dark", 10)
	prop_box(StringName("%sHead" % light_id), position + Vector3(0, 6.0, 0), Vector3(0.55, 0.18, 0.35), &"metal_dark")
	prop_box(StringName("%sGlow" % light_id), position + Vector3(0, 5.88, 0), Vector3(0.42, 0.06, 0.24), &"screen_warm")
	omni(light_id, position + Vector3(0, 5.7, 0), Color(1.0, 0.86, 0.62, 1), 2.4, 14.0)


func _build_labels() -> void:
	label(&"SiteLabel", Vector3(0, 3.7, 6.4), "ПОЛИЦЕЙСКИЙ УЧАСТОК", Color(1, 0.86, 0.66, 0.95), 46)
	label(&"EntranceLabel", Vector3(0, 2.9, 6.15), "ВХОД", Color(0.78, 0.88, 1.0, 0.9), 30)
	label(&"YardLabel", Vector3(10.5, 2.2, 11.5), "ДЕЖУРНАЯ МАШИНА", Color(0.7, 0.82, 1.0, 0.8), 24)
	label(&"ServiceLabel", Vector3(-14.5, 3.0, 10.5), "СЛУЖЕБНЫЙ ВЫХОД", Color(0.85, 0.7, 0.6, 0.8), 24)


# ---------------------------------------------------------------------------
# M2: живой слой участка
# ---------------------------------------------------------------------------

func _build_post_nightmare_content() -> void:
	_add_officer(&"DeskOfficer", Vector3(1.0, 0.0, -2.15), 0.0, "police_desk")
	_add_officer(&"InterrogationOfficer", Vector3(-16.0, 0.0, -0.6), PI, "police_guard")
	# P05: Джет у койки. Один персонаж, одна сцена; ID canonical `jett`.
	_add_officer(&"JettAtBed", Vector3(3.6, 0.0, -16.7), -PI * 0.25, "mass_female")

	var jett := Interactable.new()
	jett.name = "JettInteract"
	jett.interaction_id = &"precinct_jett"
	jett.prompt = "Поговорить с Джет"
	jett.radius = 2.2
	jett.enabled = not NightmareRunState.has_flag(&"p05_jett_talked")
	jett.position = Vector3(4.0, 1.0, -16.7)
	add_child(jett)
	jett.interacted.connect(_on_jett_interacted)
	_jett_interact = jett

	var mirror := Interactable.new()
	mirror.name = "MirrorInteract"
	mirror.interaction_id = &"interrogation_mirror"
	mirror.prompt = "Посмотреть в зеркало"
	mirror.radius = 2.2
	mirror.enabled = NightmareRunState.has_flag(&"p05_jett_talked") and not NightmareRunState.has_flag(&"p05_mirror_seen")
	mirror.position = Vector3(-18.2, 1.0, -2.0)
	add_child(mirror)
	mirror.interacted.connect(_on_mirror_interacted)
	_mirror_interact = mirror

	# POI-маркер для сверки manifest, не игровой объект.
	var mirror_poi := Marker3D.new()
	mirror_poi.name = "InterrogationMirror"
	mirror_poi.position = Vector3(-18.2, 0.2, -2.0)
	add_child(mirror_poi)

	var exit_trigger := TriggerZone.new()
	exit_trigger.name = "ExitTrigger"
	exit_trigger.trigger_id = &"precinct_exit"
	exit_trigger.enabled = true
	exit_trigger.collision_layer = 0
	exit_trigger.collision_mask = 2
	var exit_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 2.4, 1.0)
	exit_shape.shape = box
	exit_trigger.add_child(exit_shape)
	exit_trigger.position = Vector3(0.0, 1.2, 15.4)
	add_child(exit_trigger)
	exit_trigger.triggered.connect(_on_exit_triggered)

	var portal := get_node_or_null(^"Portals/ToAcademyApproach") as LevelPortal
	if portal != null:
		portal.required_flags = [&"p05_jett_talked", &"p05_mirror_seen"]
		portal.set_flags_on_use = [&"p05_completed"]


func _add_officer(node_name: StringName, position: Vector3, rotation_y: float, archetype: String) -> void:
	var officer := MANNEQUIN_SCENE.instantiate() as Mannequin
	if officer == null:
		return
	officer.name = node_name
	officer.archetype = archetype
	officer.position = position
	officer.rotation.y = rotation_y
	_props.add_child(officer)


func _play_wake_once() -> void:
	if NightmareRunState.has_flag(&"p05_jett_talked"):
		return
	if not play_cutscene(&"P05Wake"):
		play_dialogue(WAKE_SEQUENCE)
	NightmareRunState.set_flag(&"p05_jett_talked")
	NightmareRunState.set_flag(&"flaw_revealed")
	NightmareRunState.set_flag(&"flaw_clear_conscience")
	if _jett_interact != null:
		_jett_interact.enabled = false
	if _mirror_interact != null:
		_mirror_interact.enabled = true
	set_scene_objective("Посмотреть в зеркало в допросной.")


func _on_jett_interacted(_id: StringName) -> void:
	_play_wake_once()


func _on_mirror_interacted(_id: StringName) -> void:
	if NightmareRunState.has_flag(&"p05_mirror_seen"):
		return
	if not play_cutscene(&"P05Mirror"):
		play_dialogue(MIRROR_SEQUENCE)
	NightmareRunState.set_flag(&"p05_mirror_seen")
	NightmareRunState.set_flag(&"shadow_sight_unlocked")
	if _mirror_interact != null:
		_mirror_interact.enabled = false
	set_scene_objective("Выйти во двор и покинуть участок.")


func _on_exit_triggered(_id: StringName) -> void:
	if NightmareRunState.has_flag(&"p05_completed"):
		return
	play_dialogue(EXIT_SEQUENCE)
	NightmareRunState.set_flag(&"p05_completed")
	var trigger := get_node_or_null(^"ExitTrigger") as TriggerZone
	if trigger != null:
		trigger.enabled = false
