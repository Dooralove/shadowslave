class_name AcademySleeperCenter
extends GreyboxLocation
## P04–P06: спальный центр Академии.
##
## Общая спальня с капсулами, бытовая комната, душевые и наблюдательный
## пункт. Планировка намеренно регулярная: её легко расширять рядами капсул
## и новыми ответвлениями.

const CAPSULE_SEQUENCE := preload("res://resources/dialogue/post_nightmare/p09_capsule.tres")
const INDUCTION_SEQUENCE := preload("res://resources/dialogue/post_nightmare/p09_induction.tres")
const MANNEQUIN_SCENE := preload("res://scenes/slice/props/mannequin.tscn")

var _capsule: Interactable


func build_layout() -> void:
	_build_dormitory()
	_build_entry_vestibule()
	_build_common_room()
	_build_showers()
	_build_observation()
	_build_dream_ward()
	_build_details()
	_build_labels()
	_build_post_nightmare_content()


# ---------------------------------------------------------------------------
# Помещения
# ---------------------------------------------------------------------------

func _build_dormitory() -> void:
	room(
		&"Dormitory",
		Vector3(0, 0, 0),
		Vector3(26, 4.2, 14),
		&"white",
		[
			{"side": &"west", "width": 3.0, "height": 3.2},
			{"side": &"east", "width": 3.0, "height": 3.2},
			{"side": &"north", "width": 4.0, "height": 3.2},
			{"side": &"south", "width": 4.0, "height": 3.2},
		],
		{"floor_material": &"tile", "wall_material": &"white", "ceiling_material": &"white"}
	)
	room(
		&"DormWestConnector",
		Vector3(-14, 0, 0),
		Vector3(2, 3.2, 4),
		&"white",
		[
			{"side": &"east", "width": 3.0, "height": 3.2},
			{"side": &"west", "width": 3.0, "height": 3.2},
		],
		{"floor_material": &"tile", "wall_material": &"white"}
	)
	room(
		&"DormEastConnector",
		Vector3(14, 0, 0),
		Vector3(2, 3.2, 4),
		&"white",
		[
			{"side": &"east", "width": 3.0, "height": 3.2},
			{"side": &"west", "width": 3.0, "height": 3.2},
		],
		{"floor_material": &"tile", "wall_material": &"white"}
	)

	# Двенадцать капсул в четыре ряда. Центральный проход между внутренними
	# рядами остаётся свободным, внешние ряды читаются как отдельные отсеки.
	var capsule_id := 1
	for row_x in [-7.8, -3.7, 3.7, 7.8]:
		for column_z in [-4.6, 0.0, 4.6]:
			capsule(
				StringName("SleepCapsule%d" % capsule_id),
				Vector3(row_x, 0, column_z),
				0.0
			)
			capsule_id += 1

	# Скамьи и шкафчики у южной стены.
	bench(&"DormBenchA", Vector3(-4.0, 0, 5.9), 3.0, PI)
	bench(&"DormBenchB", Vector3(4.0, 0, 5.9), 3.0, PI)
	for i in 5:
		locker(
			StringName("DormLocker%d" % i),
			Vector3(-10.0 + 1.0 * float(i), 0, 6.1),
			PI,
			0.9
		)

	prop_box(&"DormStatusBoard", Vector3(0, 2.35, -6.62), Vector3(5.0, 1.5, 0.08), &"metal_dark")
	prop_box(&"DormStatusScreen", Vector3(0, 2.35, -6.55), Vector3(4.6, 1.2, 0.02), &"screen_cyan_dim")


## Короткий тамбур между кампусом и спальней. Это не отдельная сцена:
## игрок проходит через реальный дверной проём, а не появляется в спальне
## из пустоты. Портал стоит в южном проёме и ведёт на кампус.
func _build_entry_vestibule() -> void:
	room(
		&"EntryVestibule",
		Vector3(0, 0, 10),
		Vector3(8, 3.6, 6),
		&"white",
		[
			{"side": &"north", "width": 4.0, "height": 3.2},
			{"side": &"south", "width": 4.0, "height": 3.2},
		],
		{"floor_material": &"tile_wet", "wall_material": &"white", "ceiling_material": &"white"}
	)

	# Дверная рама и козырёк на внешней стороне.
	prop_box(&"EntryFrameWest", Vector3(-2.3, 1.6, 13.0), Vector3(0.22, 3.2, 0.3), &"metal_dark")
	prop_box(&"EntryFrameEast", Vector3(2.3, 1.6, 13.0), Vector3(0.22, 3.2, 0.3), &"metal_dark")
	prop_box(&"EntryLintel", Vector3(0, 3.25, 13.0), Vector3(4.8, 0.24, 0.36), &"metal_dark")
	prop_box(&"EntryCanopy", Vector3(0, 3.55, 14.0), Vector3(7.0, 0.16, 2.0), &"metal_dark")
	prop_box(&"EntrySign", Vector3(0, 2.7, 13.18), Vector3(2.6, 0.5, 0.05), &"screen_warm")
	label(&"EntryLabel", Vector3(0, 2.75, 13.25), "СПАЛЬНЫЙ ЦЕНТР", Color(1.0, 0.86, 0.64, 0.9), 22)

	# Шкафчики и скамья не перекрывают центральный проход.
	locker(&"EntryLockerA", Vector3(-3.3, 0, 9.0), PI * 0.5, 0.85)
	locker(&"EntryLockerB", Vector3(-3.3, 0, 10.0), PI * 0.5, 0.85)
	bench(&"EntryBench", Vector3(3.2, 0, 10.5), 2.4, -PI * 0.5)
	omni(&"EntryLight", Vector3(0, 3.2, 10.0), Color(1.0, 0.88, 0.68, 1), 1.6, 7.0)
	boundary(&"EntryBackstop", Vector3(0, 1.8, 13.85), Vector3(6, 3.6, 0.3))


func _build_common_room() -> void:
	room(
		&"CommonRoom",
		Vector3(-20, 0, 0),
		Vector3(10, 3.6, 12),
		&"white",
		[{"side": &"east", "width": 3.0, "height": 3.2}],
		{"floor_material": &"wood_light", "wall_material": &"white", "ceiling_material": &"white"}
	)

	table(&"CommonTable", Vector3(-20, 0, 0), Vector2(3.0, 1.4))
	for i in 4:
		var x := -21.2 + 0.8 * float(i)
		chair(StringName("CommonChairN%d" % i), Vector3(x, 0, -1.2), 0.0)
		chair(StringName("CommonChairS%d" % i), Vector3(x, 0, 1.2), PI)

	counter(&"Kitchenette", Vector3(-20, 0, -4.8), Vector2(4.6, 0.8))
	prop_box(&"KitchenShelf", Vector3(-20, 2.4, -5.72), Vector3(4.2, 0.12, 0.35), &"wood_dark")
	for i in 4:
		prop_cylinder(
			StringName("Cup%d" % i),
			Vector3(-21.6 + 0.9 * float(i), 1.28, -4.8),
			0.07,
			0.14,
			&"white",
			8
		)
	vending(&"CommonVending", Vector3(-23.6, 0, 3.8), PI * 0.5)
	bench(&"CommonBench", Vector3(-18.0, 0, 5.2), 2.6, PI)
	terminal(&"CommonTerminal", Vector3(-15.9, 0, -4.4), PI * 0.5)


func _build_showers() -> void:
	room(
		&"ShowerHall",
		Vector3(20, 0, 0),
		Vector3(10, 3.6, 12),
		&"tile",
		[{"side": &"west", "width": 3.0, "height": 3.2}],
		{"floor_material": &"tile", "wall_material": &"tile", "ceiling_material": &"tile"}
	)

	for i in 4:
		var z := -4.2 + 2.8 * float(i)
		shower_stall(StringName("ShowerWest%d" % i), Vector3(17.0, 0, z), PI * 0.5)
		shower_stall(StringName("ShowerEast%d" % i), Vector3(22.8, 0, z), -PI * 0.5)
	sink(&"ShowerSinkA", Vector3(20.0, 0, 5.4), PI)
	sink(&"ShowerSinkB", Vector3(21.2, 0, 5.4), PI)
	bench(&"ShowerBench", Vector3(20.0, 0, -5.4), 3.0, 0.0)
	locker(&"TowelLockerA", Vector3(16.6, 0, 5.4), PI * 0.5, 0.9)
	locker(&"TowelLockerB", Vector3(16.6, 0, 4.4), PI * 0.5, 0.9)
	omni(&"ShowerLight", Vector3(20, 3.2, 0), Color(0.78, 0.9, 1.0, 1), 2.4, 9.0)


func _build_observation() -> void:
	room(
		&"Observation",
		Vector3(0, 0, -10),
		Vector3(12, 3.4, 6),
		&"white",
		[
			{"side": &"south", "width": 4.0, "height": 3.2},
			{"side": &"north", "width": 3.0, "height": 3.0},
		],
		{"floor_material": &"concrete_dark", "wall_material": &"white", "ceiling_material": &"concrete_dark"}
	)

	counter(&"ObservationDesk", Vector3(0, 0, -10.4), Vector2(7.0, 0.9))
	chair(&"ObserverChairA", Vector3(-2.2, 0, -9.1), 0.0)
	chair(&"ObserverChairB", Vector3(2.2, 0, -9.1), 0.0)

	# Мониторы стоят на столешнице и развёрнуты к наблюдателям.
	for i in 2:
		var x := -2.2 + 4.4 * float(i)
		prop_box(StringName("ObservationMonitorFrame%d" % i), Vector3(x, 1.5, -10.5), Vector3(1.0, 0.55, 0.08), &"metal_dark")
		prop_box(StringName("ObservationMonitorGlow%d" % i), Vector3(x, 1.5, -10.455), Vector3(0.86, 0.43, 0.01), &"screen_cyan_dim")

	prop_box(&"ObservationScreen", Vector3(0, 2.3, -12.55), Vector3(7.2, 1.5, 0.06), &"metal_dark")
	prop_box(&"ObservationScreenGlow", Vector3(0, 2.3, -12.49), Vector3(6.8, 1.25, 0.02), &"screen_cyan_dim")

	# Четыре тёмных окна поверх свечения читаются как стена мониторов.
	for i in 4:
		var x := -2.55 + 1.7 * float(i)
		prop_box(StringName("ObservationFeed%d" % i), Vector3(x, 2.33, -12.46), Vector3(1.45, 0.9, 0.02), &"metal_dark")

	locker(&"ObservationLocker", Vector3(5.3, 0, -12.5), 0.0, 0.9)


# ---------------------------------------------------------------------------
# Медицинское крыло и погружение
# ---------------------------------------------------------------------------

## Между наблюдательным пунктом и Чёрным морем стоит короткий медцентр.
## Капсула погружения — граница сна: длинное затемнение здесь объясняет
## перенос в Царство Снов, а не имитирует обычную дверь.
func _build_dream_ward() -> void:
	room(
		&"MedicalCorridor",
		Vector3(0, 0, -16),
		Vector3(4, 3.2, 6),
		&"tile",
		[
			{"side": &"south", "width": 3.0, "height": 3.0},
			{"side": &"north", "width": 3.0, "height": 3.0},
		],
		{"floor_material": &"tile_wet", "wall_material": &"tile", "ceiling_material": &"white"}
	)
	room(
		&"DreamWard",
		Vector3(0, 0, -24),
		Vector3(12, 3.8, 10),
		&"white",
		[{"side": &"south", "width": 3.0, "height": 3.0}],
		{"floor_material": &"tile_wet", "wall_material": &"white", "ceiling_material": &"concrete_dark"}
	)

	# Три койки; центральная — точка погружения. Боковые остаются
	# декоративной поддержкой протокола и не мешают проходу.
	bed(&"DreamBedWest", Vector3(-3.7, 0, -25.5), 0.0)
	bed(&"DreamBedEast", Vector3(3.7, 0, -25.5), 0.0)
	bed(&"DreamBedCenter", Vector3(0, 0, -25.5), 0.0)

	# Светящийся контур капсулы вокруг центральной койки.
	prop_cylinder(&"DreamRing", Vector3(0, 0.03, -25.5), 1.6, 0.04, &"screen_cyan_dim", 32)
	prop_box(&"DreamCanopy", Vector3(0, 3.0, -25.5), Vector3(4.4, 0.18, 3.6), &"metal_dark")
	for x in [-1.9, 1.9]:
		prop_box(StringName("DreamCanopyPost%s" % str(x)), Vector3(x, 1.6, -25.5), Vector3(0.1, 3.2, 0.1), &"metal_light")
	prop_box(&"DreamHeader", Vector3(0, 2.9, -28.85), Vector3(6.0, 0.5, 0.08), &"metal_dark")
	prop_box(&"DreamHeaderGlow", Vector3(0, 2.9, -28.79), Vector3(5.6, 0.34, 0.02), &"screen_cyan_dim")
	prop_box(&"DreamMonitor", Vector3(5.0, 1.4, -20.3), Vector3(0.06, 1.0, 1.8), &"metal_dark")
	prop_box(&"DreamMonitorGlow", Vector3(4.96, 1.4, -20.3), Vector3(0.02, 0.84, 1.56), &"screen_cyan_dim")
	terminal(&"DreamTerminal", Vector3(4.2, 0, -20.3), -PI * 0.5)
	bench(&"DreamBench", Vector3(-4.2, 0, -20.3), 2.2, PI)

	omni(&"DreamWardLight", Vector3(0, 3.2, -24.0), Color(0.55, 0.82, 1.0, 1), 1.4, 10.0)
	omni(&"DreamBedLight", Vector3(0, 2.3, -25.5), Color(0.45, 0.8, 1.0, 1), 1.1, 5.0)
	omni(&"MedicalCorridorLight", Vector3(0, 2.8, -16.0), Color(0.75, 0.9, 1.0, 1), 1.2, 6.0)


# ---------------------------------------------------------------------------
# Детали и свет
# ---------------------------------------------------------------------------

func _build_details() -> void:
	# Тёмная дорожка по центральному проходу: визуальный ориентир, без коллизии.
	prop_box(&"DormAisle", Vector3(0, 0.01, 0), Vector3(2.6, 0.02, 12.6), &"tile_wet")

	# Полосы света под потолком спальни.
	for i in 5:
		var x := -10.0 + 5.0 * float(i)
		prop_box(
			StringName("CeilingStrip%d" % i),
			Vector3(x, 4.05, 0),
			Vector3(2.6, 0.05, 0.18),
			&"strip"
		)
		prop_box(
			StringName("CeilingStripWest%d" % i),
			Vector3(x, 4.05, -4.8),
			Vector3(2.2, 0.05, 0.12),
			&"strip"
		)

	# Условные таблички на стенах.
	prop_box(&"DormSignPlate", Vector3(-4.0, 2.6, -6.6), Vector3(2.0, 0.6, 0.04), &"metal_dark")
	prop_box(&"DormSignFace", Vector3(-4.0, 2.6, -6.56), Vector3(1.8, 0.45, 0.02), &"screen_warm")

	for i in 3:
		prop_box(
			StringName("HallPipe%d" % i),
			Vector3(0, 4.05, 6.3 + 0.22 * float(i)),
			Vector3(24.0, 0.12, 0.12),
			&"metal_light"
		)

	omni(&"DormLightA", Vector3(-7, 3.8, -3.0), Color(0.72, 0.88, 1.0, 1), 1.8, 12.0)
	omni(&"DormLightB", Vector3(0, 3.8, -3.0), Color(0.72, 0.88, 1.0, 1), 1.8, 12.0)
	omni(&"DormLightC", Vector3(7, 3.8, -3.0), Color(0.72, 0.88, 1.0, 1), 1.8, 12.0)
	omni(&"DormLightD", Vector3(-7, 3.8, 3.0), Color(0.72, 0.88, 1.0, 1), 1.8, 12.0)
	omni(&"DormLightE", Vector3(7, 3.8, 3.0), Color(0.72, 0.88, 1.0, 1), 1.8, 12.0)
	omni(&"CommonLight", Vector3(-20, 3.1, 0), Color(1.0, 0.85, 0.65, 1), 2.2, 12.0)
	omni(&"ObservationLight", Vector3(0, 3.0, -10), Color(0.68, 0.9, 1.0, 1), 1.8, 10.0)
	spot(&"ObservationGlow", Vector3(0, 2.9, -12.4), Vector3(0, 1.0, -8.0), Color(0.45, 0.8, 1.0, 1), 2.2, 14.0, 40.0)


func _build_labels() -> void:
	label(&"DormLabel", Vector3(0, 3.2, 7.0), "СПАЛЬНЫЙ ЦЕНТР", Color(0.72, 0.88, 1.0, 0.95), 44)
	label(&"CommonLabel", Vector3(-15.8, 2.6, 0), "ОБЩАЯ КОМНАТА", Color(1.0, 0.86, 0.68, 0.9), 30)
	label(&"ShowerLabel", Vector3(15.8, 2.6, 0), "ДУШЕВЫЕ", Color(0.78, 0.9, 1.0, 0.9), 30)
	label(&"ObservationLabel", Vector3(0, 2.8, -7.2), "НАБЛЮДЕНИЕ", Color(0.72, 0.88, 1.0, 0.9), 30)
	label(&"DreamWardLabel", Vector3(0, 2.55, -19.3), "ПРОТОКОЛ ПОГРУЖЕНИЯ", Color(0.55, 0.82, 1.0, 0.9), 28)
	label(&"DreamWardHint", Vector3(0, 1.9, -25.5), "СОН · ЧЁРНОЕ МОРЕ", Color(0.45, 0.8, 1.0, 0.75), 24)
	label(&"InductionLabel", Vector3(0, 2.8, -23.4), "ИНДУКЦИЯ", Color(1.0, 0.82, 0.58, 0.85), 24)


# ---------------------------------------------------------------------------
# M2: индукция и капсула
# ---------------------------------------------------------------------------

func _build_post_nightmare_content() -> void:
	# P09: Джулиус в M1 отсутствует. Индукция — Рок, Каспер, Кассия, медик.
	_add_medic(&"InductionMedic", Vector3(4.2, 0.0, -20.3), PI, "mass_male")
	_add_medic(&"Rock", Vector3(0.0, 0.0, -23.4), PI, "mass_male")
	_add_medic(&"Kasper", Vector3(2.5, 0.0, -21.5), PI, "mass_male")
	_add_medic(&"Cassia", Vector3(-3.0, 0.0, -22.5), 0.0, "mass_female")

	var rock := Interactable.new()
	rock.name = "RockInteract"
	rock.interaction_id = &"induction_rock"
	rock.prompt = "Слушать инструктора"
	rock.radius = 2.2
	rock.enabled = not NightmareRunState.has_flag(&"induction_seen")
	rock.position = Vector3(0.0, 1.2, -23.4)
	add_child(rock)
	rock.interacted.connect(_on_rock_interacted)

	var kasper := Interactable.new()
	kasper.name = "KasperInteract"
	kasper.interaction_id = &"induction_kasper"
	kasper.prompt = "Заговорить с Каспером"
	kasper.radius = 2.2
	kasper.enabled = true
	kasper.position = Vector3(2.5, 1.2, -21.5)
	add_child(kasper)
	kasper.interacted.connect(_on_kasper_interacted)

	var cassia_trigger := TriggerZone.new()
	cassia_trigger.name = "CassiaTrigger"
	cassia_trigger.trigger_id = &"cassia_at_induction"
	cassia_trigger.enabled = true
	cassia_trigger.collision_layer = 0
	cassia_trigger.collision_mask = 2
	var cassia_shape := CollisionShape3D.new()
	var cassia_box := BoxShape3D.new()
	cassia_box.size = Vector3(4.0, 2.4, 4.0)
	cassia_shape.shape = cassia_box
	cassia_trigger.add_child(cassia_shape)
	cassia_trigger.position = Vector3(-3.0, 1.2, -22.5)
	add_child(cassia_trigger)
	cassia_trigger.triggered.connect(_on_cassia_triggered)

	var portal := get_node_or_null(^"Portals/ToBlackSea") as LevelPortal
	if portal != null:
		portal.enabled = NightmareRunState.has_flag(&"capsule_entered")
		portal.required_flags = [&"induction_seen", &"capsule_entered"]
		portal.set_flags_on_use = [&"p09_completed"]

	_capsule = Interactable.new()
	_capsule.name = "CapsuleInteract"
	_capsule.interaction_id = &"sleeper_capsule"
	_capsule.prompt = "Лечь в капсулу"
	_capsule.radius = 2.2
	_capsule.enabled = NightmareRunState.has_flag(&"induction_seen") and not NightmareRunState.has_flag(&"capsule_entered")
	_capsule.position = Vector3(0.0, 1.0, -25.5)
	add_child(_capsule)
	_capsule.interacted.connect(_on_capsule_interacted)


func _add_medic(node_name: StringName, position: Vector3, rotation_y: float, archetype: String) -> void:
	var medic := MANNEQUIN_SCENE.instantiate() as Mannequin
	if medic == null:
		return
	medic.name = node_name
	medic.archetype = archetype
	medic.position = position
	medic.rotation.y = rotation_y
	_props.add_child(medic)


func _on_rock_interacted(_id: StringName) -> void:
	if NightmareRunState.has_flag(&"induction_seen"):
		return
	if not play_cutscene(&"P09Induction"):
		play_dialogue(INDUCTION_SEQUENCE)
	NightmareRunState.set_flag(&"induction_seen")
	NightmareRunState.set_flag(&"kasper_met")
	set_scene_objective("Лечь в капсулу в DreamWard.")
	if _capsule != null:
		_capsule.enabled = true
	var rock := get_node_or_null(^"RockInteract") as Interactable
	if rock != null:
		rock.enabled = false


func _on_kasper_interacted(_id: StringName) -> void:
	NightmareRunState.set_flag(&"kasper_met")


func _on_cassia_triggered(_id: StringName) -> void:
	NightmareRunState.set_flag(&"cassia_seen")


func _on_capsule_interacted(_id: StringName) -> void:
	if NightmareRunState.has_flag(&"capsule_entered"):
		return
	if not NightmareRunState.has_flag(&"induction_seen"):
		return
	if not play_cutscene(&"P09Capsule"):
		play_dialogue(CAPSULE_SEQUENCE)
	NightmareRunState.set_flag(&"capsule_entered")
	NightmareRunState.set_flag(&"academy_month_passed")
	if _capsule != null:
		_capsule.enabled = false
	var portal := get_node_or_null(^"Portals/ToBlackSea") as LevelPortal
	if portal != null:
		portal.enabled = true
		portal.activate()
