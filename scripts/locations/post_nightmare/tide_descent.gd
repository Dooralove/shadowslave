class_name TideDescent
extends GreyboxLocation
## B02.5: открытый спуск по телу статуи к коралловому лабиринту.
##
## Канон: Санни спускается по самому рельефу огромного безголового рыцаря.
## Здесь нет тоннеля под наплечником, техногенного коридора или лебёдки.
## Верхняя площадка — обломок наплечника, ступени вырублены
## в его кромке, слева лежит огромная плита плеча, справа — рука статуи.
## Внизу открывается чёрная вода и коралловый порог.

const SEA_LEVEL := -40.0
const WORLD_FRAME := preload("res://scripts/world/world_frame.gd")
const WARNING_SEQUENCE := preload("res://resources/dialogue/post_nightmare/b02_descent.tres")


func build_layout() -> void:
	_build_top_landing()
	_build_stairs()
	_build_shoulder_slope()
	_build_arm_mass()
	_build_bottom_landing()
	_build_sea_and_coral()
	_build_horizon()
	_build_lights()
	_build_labels()
	_build_post_nightmare_content()


func _build_top_landing() -> void:
	structure(&"TopLanding", Vector3(0, -0.25, 19.8), Vector3(8, 0.5, 7.5), &"statue")
	structure(&"TopLandingTrim", Vector3(0, 0.02, 19.8), Vector3(8.4, 0.04, 7.9), &"concrete_dark", false)
	# Невысокие обломки кромки, а не стены тоннеля.
	for x in [-3.6, 3.6]:
		structure(
			StringName("TopEdge%s" % str(x)),
			Vector3(x, 0.45, 19.0),
			Vector3(0.6, 0.9, 6.4),
			&"concrete_dark",
			true
		)
	boundary(&"TopWest", Vector3(-4.2, 2.5, 19.8), Vector3(0.5, 5, 8.2))
	boundary(&"TopEast", Vector3(4.2, 2.5, 19.8), Vector3(0.5, 5, 8.2))
	boundary(&"TopBackstop", Vector3(0, 2.5, 24.4), Vector3(8, 5, 0.5))

	# Обломанный край наплечника на входе. Никакой тёмной арки: за игроком
	# остаётся открытое чёрное небо и кромка шеи.
	for i in 3:
		var plate := structure(
			StringName("TopBrokenPlate%d" % i),
			Vector3(-3.0 + 3.0 * float(i), 0.3, 22.8 - 0.35 * float(i)),
			Vector3(1.9, 0.6, 1.0),
			&"statue",
			false
		)
		plate.rotation.z = 0.12 * float(i - 1)


func _build_stairs() -> void:
	# 24 ступени, вырубленные в кромке плеча. Свет и вода остаются снаружи.
	var stairs_root := stairs(&"TideStairs", Vector3(0, -6.0, -18.0), 5.0, 0.25, 1.5, 24, &"statue", PI)
	# B2: визуальные ступени остаются, но пошаговая коллизия заменяется
	# непрерывной рампой — CharacterBody3D не поднимается по 0,25 м.
	for child in stairs_root.get_children():
		var step_collision := child.get_node_or_null(^"Collision")
		if step_collision != null:
			step_collision.free()
	_add_ramp_collision(&"TideStairsRampCollision", Vector3(0.0, -3.15, -1.0), 5.0, 34.0, 6.0)

	# Низкие обломки кромки вместо глухих стен. Они удерживают игрока
	# на ступенях, но не превращают спуск в коридор.
	for i in 12:
		var z := -18.0 + 3.0 * float(i)
		var y := -6.0 + (z + 18.0) / 6.0
		for x in [-2.85, 2.85]:
			var lip := structure(
				StringName("StairLip%s%s" % [str(x), str(i)]),
				Vector3(x, y + 0.32, z),
				Vector3(0.55, 0.64, 3.0),
				&"concrete_dark",
				true
			)
			lip.rotation.z = 0.03 * float((i % 3) - 1)


func _add_ramp_collision(id: StringName, center: Vector3, width: float, run: float, rise: float) -> void:
	var body := StaticBody3D.new()
	body.name = id
	body.position = center
	body.rotation.x = -atan2(rise, run)
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.3, sqrt(run * run + rise * rise))
	shape.shape = box
	body.add_child(shape)
	_structure.add_child(body)


func _build_shoulder_slope() -> void:
	# Огромная внешняя плита наплечника слева от ступеней. Она лежит
	# наклонно и уходит в темноту; это не стена тоннеля.
	var shoulder := _module_root(&"ShoulderSlopeWest", Vector3(-8.5, -1.0, 1.0))
	var outer := _plate(shoulder, &"OuterPlate", Vector3(-1.0, -3.0, 0), Vector3(9.0, 1.6, 38.0), &"statue")
	outer.rotation.z = -0.10
	outer.rotation.x = 0.03
	var upper := _plate(shoulder, &"UpperPlate", Vector3(0.8, 2.0, 2.0), Vector3(6.0, 1.2, 30.0), &"statue_pale")
	upper.rotation.z = -0.16
	var inner := _plate(shoulder, &"InnerRidge", Vector3(2.3, 4.2, 4.0), Vector3(4.0, 0.8, 24.0), &"concrete_dark")
	inner.rotation.z = -0.20
	for i in 4:
		var trim := _plate(
			shoulder,
			StringName("ShoulderTrim%d" % i),
			Vector3(-2.0, 0.6 - 1.1 * float(i), -14.0 + 9.0 * float(i)),
			Vector3(7.5, 0.16, 0.8),
			&"metal_light"
		)
		trim.rotation.z = -0.12


func _build_arm_mass() -> void:
	# Правая рука статуи: массив плеча и предплечья за краем спуска.
	var arm := _module_root(&"ArmMassEast", Vector3(10.8, -8.0, -2.0))
	_box_child(arm, &"UpperArm", Vector3.ZERO, Vector3(9.5, 22.0, 16.0), &"statue", false)
	_box_child(arm, &"BicepPlate", Vector3(-0.4, 2.0, -8.3), Vector3(8.0, 9.0, 0.8), &"concrete_dark", false)
	prop_sphere(&"ArmElbowEast", Vector3(11.5, -18.0, -3.0), 5.2, &"statue")
	_box_child(arm, &"Forearm", Vector3(0.8, -20.0, -8.5), Vector3(8.0, 20.0, 12.0), &"statue", false)
	_box_child(arm, &"ForearmBand", Vector3(0.8, -25.0, -8.5), Vector3(8.4, 1.2, 12.4), &"concrete_dark", false)


func _build_bottom_landing() -> void:
	structure(&"BottomLanding", Vector3(0, -6.25, -20.5), Vector3(8, 0.5, 7), &"mud")
	structure(&"BottomLandingTrim", Vector3(0, -5.98, -20.5), Vector3(8.4, 0.04, 7.4), &"tile_wet", false)
	boundary(&"BottomWest", Vector3(-4.2, -3.5, -20.5), Vector3(0.5, 5, 8))
	boundary(&"BottomEast", Vector3(4.2, -3.5, -20.5), Vector3(0.5, 5, 8))
	boundary(&"BottomBackstop", Vector3(0, -3.5, -24.2), Vector3(8, 5, 0.5))
	# Коралловая арка — естественный вход в лабиринт, не техногенный шлюз.
	structure(&"BottomGatePostWest", Vector3(-2.4, -3.8, -22.5), Vector3(0.8, 4.4, 0.8), &"coral_pale")
	structure(&"BottomGatePostEast", Vector3(2.4, -3.8, -22.5), Vector3(0.8, 4.4, 0.8), &"coral_pale")
	structure(&"BottomGateLintel", Vector3(0, -1.55, -22.5), Vector3(5.8, 0.45, 0.9), &"coral")
	prop_box(&"BottomGateGlow", Vector3(0, -3.8, -23.2), Vector3(4.2, 3.5, 0.06), &"screen_cyan_dim")
	prop_box(&"BottomGlow", Vector3(0, -5.94, -21.0), Vector3(4.4, 0.04, 0.3), &"screen_cyan_dim")
	coral_cluster(&"BottomCoralWest", Vector3(-3.1, -6.0, -20.0), 3.4, 81)
	coral_cluster(&"BottomCoralEast", Vector3(3.1, -6.0, -20.0), 3.0, 82)
	prop_box(&"BottomWater", Vector3(0, -5.97, -19.2), Vector3(3.8, 0.02, 1.0), &"tile_wet")


func _build_sea_and_coral() -> void:
	# Чёрная вода далеко внизу: она заполняет пустоту у подножия статуи
	# и показывает масштаб спуска. Это визуальный слой, не пол.
	prop_box(&"SeaBelow", Vector3(0, SEA_LEVEL, 0), Vector3(300, 0.2, 300), &"water")
	for i in 6:
		var angle := TAU * float(i) / 6.0
		coral_cluster(
			StringName("FarCoral%d" % i),
			Vector3(cos(angle) * 24.0, SEA_LEVEL + 0.2, sin(angle) * 24.0),
			4.0 + float(i % 3),
			120 + i
		)


## The descent faces the Black Sea. The sea and the far reef are the horizon
## here; without them the shoulder and stairs float in a black void.
func _build_horizon() -> void:
	var backdrop := Node3D.new()
	backdrop.name = "Backdrop"
	_structure.add_child(backdrop)

	var sea := WORLD_FRAME.far_sea(
		Vector3(0.0, SEA_LEVEL - 0.2, 0.0),
		5000.0,
		Color(0.008, 0.012, 0.020),
		Color(0.055, 0.070, 0.090),
		"FarBlackSea",
		220.0,
		1900.0
	)
	backdrop.add_child(sea)

	var near_rim := WORLD_FRAME.ridge_ring(
		Vector3.ZERO,
		680.0,
		120,
		SEA_LEVEL - 0.4,
		16.0,
		58.0,
		Color(0.055, 0.070, 0.090),
		Color(0.075, 0.095, 0.120),
		Color(0.055, 0.070, 0.090),
		Color(0.075, 0.095, 0.120),
		61,
		"NearBlackHorizon"
	)
	backdrop.add_child(near_rim)

	var far_rim := WORLD_FRAME.ridge_ring(
		Vector3.ZERO,
		1520.0,
		100,
		SEA_LEVEL - 0.4,
		34.0,
		108.0,
		Color(0.055, 0.070, 0.090),
		Color(0.105, 0.130, 0.160),
		Color(0.055, 0.070, 0.090),
		Color(0.105, 0.130, 0.160),
		73,
		"FarBlackHorizon"
	)
	backdrop.add_child(far_rim)

	# The reef that the stairs lead to, low and dark-crimson on the sea line.
	WORLD_FRAME.spire_cluster(
		backdrop,
		Vector3(210.0, SEA_LEVEL, -150.0),
		SEA_LEVEL,
		46.0,
		6,
		Color(0.12, 0.045, 0.055),
		Color(0.075, 0.085, 0.100),
		0.55,
		91,
		"FarCrimsonReef",
		58.0
	)
	WORLD_FRAME.spire_cluster(
		backdrop,
		Vector3(-190.0, SEA_LEVEL, -300.0),
		SEA_LEVEL,
		38.0,
		5,
		Color(0.10, 0.040, 0.050),
		Color(0.075, 0.085, 0.100),
		0.62,
		107,
		"FarCrimsonReefWest",
		44.0
	)

	# The chest and neck of the statue rise behind the descent. They frame the
	# stairs when the player looks back up, and explain what the shoulder is
	# attached to.
	WORLD_FRAME.mass_block(
		backdrop,
		Vector3(0.0, 6.0, 260.0),
		Vector3(300.0, 340.0, 180.0),
		Color(0.045, 0.050, 0.060),
		Color(0.12, 0.14, 0.17),
		0.18,
		"StatueChestMass"
	)


func _build_lights() -> void:
	omni(&"TopLandingLight", Vector3(0, 3.8, 18.8), Color(0.5, 0.8, 1.0, 1), 2.2, 16.0)
	omni(&"BottomLandingLight", Vector3(0, -2.8, -20.5), Color(0.35, 0.72, 1.0, 1), 2.0, 14.0)
	for i in 5:
		var z := -15.0 + 7.0 * float(i)
		var y := -6.0 + (z + 18.0) / 6.0
		omni(
			StringName("StairFill%d" % i),
			Vector3(0, y + 4.0, z),
			Color(0.35, 0.62, 0.92, 1),
			1.25,
			14.0
		)
	omni(&"SeaFill", Vector3(0, -18.0, -8.0), Color(0.18, 0.3, 0.5, 1), 0.9, 42.0)


func _build_labels() -> void:
	label(&"TopLabel", Vector3(0, 3.2, 20.5), "СПУСК ПО СТАТУЕ", Color(0.55, 0.82, 1.0, 0.9), 28)
	label(&"StairLabel", Vector3(0, 1.5, 3.0), "ВДОЛЬ ПЛЕЧА", Color(0.62, 0.78, 0.9, 0.7), 22)
	label(&"BottomLabel", Vector3(0, -1.0, -22.4), "КОРАЛЛОВЫЙ ЛАБИРИНТ", Color(0.62, 0.86, 1.0, 0.85), 26)


# ---------------------------------------------------------------------------
# Вспомогательные формы
# ---------------------------------------------------------------------------

func _module_root(module_id: StringName, position := Vector3.ZERO) -> Node3D:
	var root := Node3D.new()
	root.name = module_id
	root.position = position
	_structure.add_child(root)
	_register(module_id, root)
	return root


func _plate(
	parent: Node3D,
	child_name: StringName,
	local_position: Vector3,
	size: Vector3,
	material_key: StringName
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = child_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = local_position
	parent.add_child(mesh_instance)
	return mesh_instance


# ---------------------------------------------------------------------------
# M2: предупреждение о приливе
# ---------------------------------------------------------------------------

func _build_post_nightmare_content() -> void:
	var trigger := TriggerZone.new()
	trigger.name = "TideWarningTrigger"
	trigger.trigger_id = &"tide_descent_warning"
	trigger.enabled = not NightmareRunState.has_flag(&"tide_seen")
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 2.4, 1.2)
	shape.shape = box
	trigger.add_child(shape)
	trigger.position = Vector3(0.0, 1.2, 15.0)
	add_child(trigger)
	trigger.triggered.connect(_on_tide_warning_triggered)

	var portal := get_node_or_null(^"Portals/ToCoral") as LevelPortal
	if portal != null:
		portal.required_flags = [&"b01_completed"]
		portal.set_flags_on_use = [&"b02_completed"]


func _on_tide_warning_triggered(_id: StringName) -> void:
	if NightmareRunState.has_flag(&"tide_seen"):
		return
	play_dialogue(WARNING_SEQUENCE)
	NightmareRunState.set_flag(&"tide_seen")
	var trigger := get_node_or_null(^"TideWarningTrigger") as TriggerZone
	if trigger != null:
		trigger.enabled = false
