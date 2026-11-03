class_name BlackSeaPlatform
extends GreyboxLocation
## B01–B02: шея гигантской статуи рыцаря в Чёрном море.
##
## Канон (гл. 30–32): круглая каменная площадка около 12 м в диаметре —
## это срез шеи статуи. У статуи нет головы, на нагруднике семь звёзд,
## меч опущен к земле. Вокруг — чёрная вода без луны и звёзд.
##
## Площадка остаётся игровой зоной. Гигантское тело, плечи, нагрудник,
## меч и дальний риф — визуальный масштаб и ориентиры, а не проходимая
## геометрия. Спуск к лабиринту начинается с разлома на восточном краю
## шеи и продолжается в отдельной сцене tide_descent.

const NECK_RADIUS := 6.0
const WATER_LEVEL := -72.0
# Оставлено для старых primitive-функций, которые больше не вызываются.
const STATUE_STAR_MATERIAL := preload(
	"res://resources/locations/post_nightmare/materials/statue_star.tres"
)
const STATUE_LOD_SCENE := preload(
	"res://assets/environments/nightmare/statue/statue_knight_colossus_lod.tscn"
)
const WORLD_FRAME := preload("res://scripts/world/world_frame.gd")


const STARS_SEQUENCE := preload("res://resources/dialogue/post_nightmare/b01_statue.tres")
const SWORD_SEQUENCE := preload("res://resources/dialogue/post_nightmare/black_sea_sword.tres")
const SHROUD_SEQUENCE := preload("res://resources/dialogue/post_nightmare/b01_shroud.tres")
const DESCENT_SEQUENCE := preload("res://resources/dialogue/post_nightmare/black_sea_descent.tres")


func _ready() -> void:
	super._ready()
	# Direct scene launch has no LevelPortal pending spawn; face the neck
	# breastplate instead of looking away from the only interactable.
	if not LevelPortal.peek_pending_spawn(scene_file_path).is_empty():
		return
	var player := get_tree().get_first_node_in_group(&"player") as SunnyController
	var start := get_spawn(&"Start")
	if player != null and start != null:
		player.apply_spawn_orientation(start.global_rotation.y)


func build_layout() -> void:
	NightmareRunState.set_flag(&"b01_arrived")
	# Визуальная статуя — новый hero-ассет; primitive-функции ниже оставлены
	# как fallback/историческая разметка, но больше не строятся в сцене.
	_build_statue_asset()
	_build_platform_collision()
	_build_neck_boundary()
	_build_sea_and_reef()
	_build_horizon()
	_build_descent()
	_build_lights()
	_build_labels()
	_build_post_nightmare_content()


func _build_statue_asset() -> void:
	var statue := STATUE_LOD_SCENE.instantiate()
	statue.name = "StatueKnightColossus"
	statue.position = Vector3.ZERO
	_structure.add_child(statue)


func _build_platform_collision() -> void:
	# Только коллизия: верх 12-м площадки ровно y = 0, как у GLB.
	var body := StaticBody3D.new()
	body.name = "NeckPlatformCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = NECK_RADIUS
	cylinder.height = 2.4
	shape.shape = cylinder
	shape.position = Vector3(0, -1.2, 0)
	body.add_child(shape)
	_structure.add_child(body)


func _build_neck_boundary() -> void:
	# Невидимый барьер по кромке; восточный сектор открыт для спуска.
	for i in 12:
		if i == 0:
			continue
		var angle := TAU * float(i) / 12.0
		boundary(
			StringName("NeckBoundary%d" % i),
			Vector3(cos(angle) * 6.15, 1.4, sin(angle) * 6.15),
			Vector3(3.4, 3.0, 0.35),
			-angle - PI * 0.5
		)


# ---------------------------------------------------------------------------
# Шея и площадка
# ---------------------------------------------------------------------------

func _build_neck() -> void:
	# Верхняя поверхность — ровно y = 0. Диаметр 12 м, как в тексте главы 30.
	platform(&"NeckPlatform", Vector3.ZERO, NECK_RADIUS, 2.4, &"statue", true)
	structure(&"PlatformShoulder", Vector3(0, -1.2, 0), Vector3(9.2, 0.25, 9.2), &"concrete_dark", false)
	platform(&"NeckBase", Vector3(0, -6.0, 0), 8.8, 7.2, &"statue_pale", false)

	# Обломанная кромка: низкие плиты по кругу. На востоке оставлен разлом
	# под спуск, на севере — выщербина, через которую читается нагрудник.
	var rim := _module_root(&"NeckRim")
	for i in 12:
		var angle := TAU * float(i) / 12.0
		if i == 0:
			continue
		var height := 0.18 + 0.10 * float(i % 3)
		if i == 10 or i == 11:
			height = 0.12
		_box_child(
			rim,
			StringName("Rim%d" % i),
			Vector3(cos(angle) * 5.75, height * 0.5, sin(angle) * 5.75),
			Vector3(2.55, height, 0.55),
			&"statue",
			false
		).rotation.y = -angle - PI * 0.5

	# Борозды на площадке: три кольца и радиальные канавки.
	for i in 7:
		var angle := TAU * float(i) / 7.0
		var groove := _statue_block(
			StringName("RadialGroove%d" % i),
			Vector3(cos(angle) * 3.1, 0.015, sin(angle) * 3.1),
			Vector3(3.6, 0.025, 0.10),
			&"concrete_dark",
			Vector3(0, -angle - PI * 0.5, 0),
			false
		)
		groove.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Невидимый барьер по кромке. Восточный сектор открыт для спуска.
	for i in 12:
		if i == 0:
			continue
		var angle := TAU * float(i) / 12.0
		boundary(
			StringName("NeckBoundary%d" % i),
			Vector3(cos(angle) * 6.15, 1.4, sin(angle) * 6.15),
			Vector3(3.4, 3.0, 0.35),
			-angle - PI * 0.5
		)


func _build_broken_collar() -> void:
	var collar := _module_root(&"BrokenCollar")
	for i in 12:
		var angle := TAU * float(i) / 12.0
		if i == 0 or i == 9:
			continue
		var radius := 7.15 + 0.18 * float(i % 2)
		var height := 1.6 + 0.55 * float(i % 4)
		var plate := _box_child(
			collar,
			StringName("Plate%d" % i),
			Vector3(cos(angle) * radius, height * 0.5 - 1.0, sin(angle) * radius),
			Vector3(3.35, height, 1.15),
			&"statue",
			false
		)
		plate.rotation.y = -angle - PI * 0.5
		plate.rotation.z = 0.06 * float((i % 3) - 1)
		if i % 3 == 0:
			_box_child(
				collar,
				StringName("Trim%d" % i),
				Vector3(cos(angle) * (radius + 0.05), -0.5, sin(angle) * (radius + 0.05)),
				Vector3(3.0, 0.16, 1.25),
				&"metal_light",
				false
			).rotation.y = plate.rotation.y

	# Упавшие обломки у северного края — намёк на отломанную голову.
	for i in 3:
		var angle := -PI * 0.5 + (float(i) - 1.0) * 0.22
		var fallen := _box_child(
			collar,
			StringName("Fallen%d" % i),
			Vector3(cos(angle) * 8.8, -1.25, sin(angle) * 8.8),
			Vector3(2.2, 0.55, 1.2),
			&"statue",
			false
		)
		fallen.rotation = Vector3(0.28 * float(i), -angle - PI * 0.5, 0.32)


func _build_shoulders_and_arms() -> void:
	for side in [-1.0, 1.0]:
		var shoulder_id := StringName("ShoulderWest" if side < 0.0 else "ShoulderEast")
		var shoulder := _module_root(shoulder_id, Vector3(25.0 * side, -2.0, 0.0))
		var dome := _statue_sphere(
			shoulder,
			&"PauldronDome",
			Vector3.ZERO,
			12.5,
			&"statue",
			Vector3(1.18, 0.88, 1.15)
		)
		dome.rotation.z = -0.06 * side
		_box_child(
			shoulder,
			&"TopPlate",
			Vector3(0, 4.0, 0),
			Vector3(23.0, 2.4, 25.0),
			&"statue_pale",
			false
		).rotation.z = -0.08 * side
		_box_child(
			shoulder,
			&"PlateEdge",
			Vector3(0, 5.25, 0),
			Vector3(20.0, 0.18, 21.0),
			&"metal_light",
			false
		).rotation.z = -0.08 * side
		for j in 3:
			var plate := _box_child(
				shoulder,
				StringName("Layer%d" % j),
				Vector3(-1.6 * side, 1.4 - 1.35 * float(j), -8.0 + 8.0 * float(j)),
				Vector3(19.0 - 2.1 * float(j), 0.8, 7.4),
				&"statue",
				false
			)
			plate.rotation.x = 0.10 - 0.05 * float(j)
			plate.rotation.z = -0.10 * side

		# Верхняя часть руки уходит вниз, к нагруднику и мечу.
		var arm := _module_root(
			StringName("ArmWest" if side < 0.0 else "ArmEast"),
			Vector3(29.0 * side, -17.0, 1.5)
		)
		_box_child(arm, &"UpperArm", Vector3.ZERO, Vector3(13.0, 28.0, 13.0), &"statue", false)
		_box_child(arm, &"UpperPlate", Vector3(-0.6 * side, 1.0, -6.9), Vector3(10.0, 8.0, 0.9), &"concrete_dark", false)
		_statue_sphere(arm, &"Elbow", Vector3(0, -15.0, 0), 7.0, &"statue", Vector3(1.0, 0.85, 1.0))
		_box_child(arm, &"Forearm", Vector3(1.4 * side, -26.0, -1.5), Vector3(10.5, 23.0, 10.5), &"statue", false)
		_box_child(arm, &"Cuff", Vector3(1.4 * side, -37.0, -2.0), Vector3(12.0, 3.0, 12.0), &"concrete_dark", false)


func _build_chest() -> void:
	var chest := _module_root(&"Chest", Vector3(0, -27.0, -14.0))
	_box_child(chest, &"Core", Vector3.ZERO, Vector3(52.0, 48.0, 30.0), &"statue", false)
	_box_child(chest, &"TopBevel", Vector3(0, 22.5, -2.0), Vector3(46.0, 3.0, 24.0), &"concrete_dark", false)
	_box_child(chest, &"Breastplate", Vector3(0, 2.0, -15.15), Vector3(45.0, 37.0, 2.2), &"statue_pale", false)
	_box_child(chest, &"BreastplateRim", Vector3(0, 21.0, -16.3), Vector3(43.0, 0.4, 0.8), &"metal_light", false)
	_box_child(chest, &"BreastplateLowerBand", Vector3(0, -17.0, -16.2), Vector3(41.0, 0.45, 0.7), &"concrete_dark", false)
	_box_child(chest, &"Abdomen", Vector3(0, -22.0, -14.5), Vector3(30.0, 20.0, 26.0), &"statue", false)
	_box_child(chest, &"Belt", Vector3(0, -34.0, -14.0), Vector3(42.0, 5.0, 28.0), &"concrete_dark", false)
	_box_child(chest, &"BeltEdge", Vector3(0, -31.4, -14.6), Vector3(39.0, 0.18, 27.0), &"metal_light", false)

	# Семь звёзд на нагруднике. Одна центральная и шесть вокруг неё.
	var stars := _module_root(&"ChestStars", Vector3(0, -21.0, -30.65))
	_add_star(stars, &"StarCenter", Vector3.ZERO, 3.4)
	for i in 6:
		var angle := -PI * 0.5 + TAU * float(i) / 6.0
		_add_star(
			stars,
			StringName("Star%d" % i),
			Vector3(cos(angle) * 11.8, sin(angle) * 11.8, 0),
			2.0
		)


func _build_lower_body() -> void:
	var lower := _module_root(&"LowerBody", Vector3(0, -55.0, -10.0))
	_box_child(lower, &"Waist", Vector3(0, 0, 0), Vector3(36.0, 13.0, 26.0), &"statue", false)
	_box_child(lower, &"Pelvis", Vector3(0, -15.0, 0), Vector3(31.0, 18.0, 24.0), &"concrete_dark", false)
	_box_child(lower, &"TassetWest", Vector3(-12.0, -27.0, -3.0), Vector3(10.0, 22.0, 12.0), &"statue", false)
	_box_child(lower, &"TassetEast", Vector3(12.0, -27.0, -3.0), Vector3(10.0, 22.0, 12.0), &"statue", false)
	_box_child(lower, &"LegWest", Vector3(-10.0, -46.0, 0), Vector3(12.0, 30.0, 14.0), &"statue", false)
	_box_child(lower, &"LegEast", Vector3(10.0, -46.0, 0), Vector3(12.0, 30.0, 14.0), &"statue", false)


func _build_sword() -> void:
	var sword := _module_root(&"Sword", Vector3(-30.0, -15.0, -36.0))
	_statue_sphere(sword, &"Pommel", Vector3(0, 8.5, 0), 3.0, &"statue", Vector3(1.0, 0.9, 1.0))
	_statue_cylinder(sword, &"Grip", Vector3(0, 0, 0), 1.9, 1.9, 16.0, &"metal_dark", Vector3.ZERO, 12)
	_box_child(sword, &"Guard", Vector3(0, -8.2, 0), Vector3(28.0, 2.5, 4.0), &"statue", false)
	_box_child(sword, &"GuardEdge", Vector3(0, -6.8, -0.2), Vector3(25.0, 0.18, 4.1), &"metal_light", false)
	_box_child(sword, &"Blade", Vector3(0, -38.0, 0), Vector3(6.0, 60.0, 2.5), &"statue_pale", false)
	_box_child(sword, &"BladeEdgeWest", Vector3(-3.05, -38.0, -0.1), Vector3(0.22, 59.0, 2.6), &"metal_light", false)
	_box_child(sword, &"BladeEdgeEast", Vector3(3.05, -38.0, -0.1), Vector3(0.22, 59.0, 2.6), &"metal_light", false)
	_statue_cylinder(sword, &"BladeTip", Vector3(0, -73.0, 0), 0.2, 3.2, 10.0, &"statue", Vector3(0, 0, PI), 6)
	_add_sword_hand(sword)

	# Предплечье, ведущее к рукояти. Оно не проходимо, но объясняет позу.
	_box_child(_module_root(&"SwordArm", Vector3(-29.0, -22.0, -20.0)), &"Forearm", Vector3.ZERO, Vector3(11.0, 10.0, 34.0), &"statue", false)


func _add_sword_hand(sword: Node3D) -> void:
	_statue_sphere(sword, &"Hand", Vector3(0, -0.5, -1.0), 4.7, &"statue", Vector3(1.0, 1.2, 0.9))
	for i in 4:
		var finger := _box_child(
			sword,
			StringName("Finger%d" % i),
			Vector3(-4.0 + 2.65 * float(i), -0.5, -5.0),
			Vector3(1.7, 2.5, 4.2),
			&"statue",
			false
		)
		finger.rotation.x = 0.28
	_box_child(sword, &"Thumb", Vector3(4.7, -1.0, -1.6), Vector3(2.2, 3.4, 5.0), &"statue", false)


# ---------------------------------------------------------------------------
# Море, дальний риф и спуск
# ---------------------------------------------------------------------------

func _build_sea_and_reef() -> void:
	# Вода — визуальная плоскость без коллизии. Игрок не может сойти с шеи.
	prop_box(&"BlackWater", Vector3(0, WATER_LEVEL, -60.0), Vector3(520.0, 0.2, 520.0), &"water")

	# Дальние коралловые силуэты: лабиринт лежит далеко внизу, за границей
	# сцены. Они дают масштаб и направление спуска, но не являются проходимыми.
	var reef := _module_root(&"DistantReef")
	for i in 9:
		var angle := TAU * float(i) / 9.0 + 0.18
		var radius := 92.0 + 14.0 * float(i % 3)
		var height := 14.0 + 6.0 * float(i % 4)
		var cluster := Node3D.new()
		cluster.name = "Reef%d" % i
		cluster.position = Vector3(cos(angle) * radius, WATER_LEVEL, sin(angle) * radius - 45.0)
		reef.add_child(cluster)
		for j in 4:
			var branch_height := height * (0.55 + 0.18 * float(j % 3))
			var branch := _box_child(
				cluster,
				StringName("Branch%d" % j),
				Vector3(
					cos(float(j) * 1.7) * height * 0.18,
					branch_height * 0.5,
					sin(float(j) * 1.7) * height * 0.18
				),
				Vector3(1.6 + 0.4 * float(j % 2), branch_height, 1.4),
				&"coral" if j % 2 == 0 else &"coral_pale",
				false
			)
			branch.rotation.y = float(j) * 0.8
			branch.rotation.z = 0.14 * float((j % 3) - 1)


## The Black Sea is canonically endless black water under a starless sky.
## That is not the same as an empty void: a faint horizon band, distant reef
## silhouettes and two giant backs in the water give the platform scale and a
## direction to the coral descent.
func _build_horizon() -> void:
	var backdrop := Node3D.new()
	backdrop.name = "Backdrop"
	_structure.add_child(backdrop)

	var sea := WORLD_FRAME.far_sea(
		Vector3(0.0, WATER_LEVEL - 0.2, 0.0),
		5000.0,
		Color(0.008, 0.012, 0.020),
		Color(0.055, 0.070, 0.090),
		"FarBlackSea",
		260.0,
		2100.0
	)
	backdrop.add_child(sea)

	var near_rim := WORLD_FRAME.ridge_ring(
		Vector3.ZERO,
		720.0,
		140,
		WATER_LEVEL - 0.4,
		10.0,
		38.0,
		Color(0.055, 0.070, 0.090),
		Color(0.075, 0.095, 0.120),
		Color(0.055, 0.070, 0.090),
		Color(0.075, 0.095, 0.120),
		37,
		"NearBlackHorizon"
	)
	backdrop.add_child(near_rim)

	var far_rim := WORLD_FRAME.ridge_ring(
		Vector3.ZERO,
		1560.0,
		120,
		WATER_LEVEL - 0.4,
		18.0,
		55.0,
		Color(0.055, 0.070, 0.090),
		Color(0.105, 0.130, 0.160),
		Color(0.055, 0.070, 0.090),
		Color(0.105, 0.130, 0.160),
		53,
		"FarBlackHorizon"
	)
	backdrop.add_child(far_rim)

	# The reef that the descent leads to: a low, dark-crimson band east of the
	# statue. It is the only warm colour on the horizon, so the eye reads it as
	# "the way down".
	WORLD_FRAME.spire_cluster(
		backdrop,
		Vector3(430.0, WATER_LEVEL, 20.0),
		WATER_LEVEL,
		92.0,
		8,
		Color(0.13, 0.045, 0.055),
		Color(0.075, 0.085, 0.100),
		0.48,
		71,
		"FarCrimsonReef",
		92.0
	)
	WORLD_FRAME.spire_cluster(
		backdrop,
		Vector3(350.0, WATER_LEVEL, -210.0),
		WATER_LEVEL,
		66.0,
		6,
		Color(0.11, 0.040, 0.050),
		Color(0.075, 0.085, 0.100),
		0.55,
		83,
		"FarCrimsonReefSouth",
		70.0
	)

	# Two giant backs break the surface far from the platform. Canon mentions
	# giant creatures in the Black Sea; silhouettes are enough at this scale.
	WORLD_FRAME.water_fin(
		backdrop,
		Vector3(-260.0, WATER_LEVEL, 330.0),
		110.0,
		70.0,
		16.0,
		Color(0.015, 0.020, 0.030),
		Color(0.055, 0.070, 0.090),
		0.35,
		"GiantBackWest"
	)
	WORLD_FRAME.water_fin(
		backdrop,
		Vector3(300.0, WATER_LEVEL, -360.0),
		80.0,
		55.0,
		12.0,
		Color(0.015, 0.020, 0.030),
		Color(0.055, 0.070, 0.090),
		0.42,
		"GiantBackEast"
	)


func _build_descent() -> void:
	# Разлом на восточном краю шеи. Четыре ступени уходят вниз, дальше
	# начинается отдельная сцена спуска по телу статуи.
	var descent := _module_root(&"DescentLedge", Vector3(7.4, -0.35, 0))
	_box_child(descent, &"Ledge", Vector3.ZERO, Vector3(4.2, 0.7, 4.2), &"concrete_dark", true)
	_box_child(descent, &"LedgeTrim", Vector3(0, 0.38, 0), Vector3(3.7, 0.12, 3.4), &"concrete_dark", false)
	for i in 4:
		_box_child(
			descent,
			StringName("Step%d" % i),
			Vector3(2.35 + 1.25 * float(i), -0.55 - 0.55 * float(i), 0),
			Vector3(1.15, 0.55, 3.6 - 0.4 * float(i)),
			&"concrete_dark",
			true
		)
	# Сломанные боковые пластины вместо перил.
	for z in [-2.15, 2.15]:
		var plate := _box_child(
			descent,
			StringName("SidePlate%s" % str(z)),
			Vector3(1.0, 1.15, z),
			Vector3(3.4, 2.6, 0.5),
			&"concrete_dark",
			false
		)
		plate.rotation.x = 0.22 * signf(z)
		plate.rotation.y = 0.12
	boundary(&"DescentSideNorth", Vector3(8.2, 1.0, -2.45), Vector3(5.0, 3.0, 0.4))
	boundary(&"DescentSideSouth", Vector3(8.2, 1.0, 2.45), Vector3(5.0, 3.0, 0.4))
	boundary(&"DescentEnd", Vector3(11.1, -0.7, 0), Vector3(0.4, 3.0, 4.4))


# ---------------------------------------------------------------------------
# Свет и подписи
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	# Не «луна»: в каноне неба без звёзд и луны. Это холодный заполняющий
	# свет, без которого серобокс нечитаем; он не изображает небесное тело.
	omni(&"NeckFill", Vector3(0, 3.4, 0), Color(0.56, 0.68, 0.9, 1), 3.2, 26.0)
	# The statue is far beyond the neck fill. A soft authored spot keeps the
	# colossus readable from the spawn without turning the Black Sea into day.
	var statue_fill := SpotLight3D.new()
	statue_fill.name = "StatueReadFill"
	statue_fill.position = Vector3(0.0, 12.0, 6.0)
	statue_fill.light_color = Color(0.55, 0.68, 0.9, 1.0)
	statue_fill.light_energy = 4.5
	statue_fill.spot_range = 240.0
	statue_fill.spot_angle = 34.0
	statue_fill.shadow_enabled = false
	_lights.add_child(statue_fill)
	statue_fill.look_at(Vector3(0.0, -12.0, -120.0), Vector3.UP)
	omni(&"CollarFillWest", Vector3(-10.0, 2.0, 0), Color(0.48, 0.6, 0.82, 1), 1.2, 20.0)
	omni(&"CollarFillEast", Vector3(10.0, 2.0, 0), Color(0.48, 0.6, 0.82, 1), 1.2, 20.0)
	omni(&"ChestGlow", Vector3(0, -18.0, -42.0), Color(0.48, 0.66, 0.94, 1), 7.0, 78.0)
	omni(&"SwordGlow", Vector3(0.0, -34.0, -40.0), Color(0.45, 0.6, 0.88, 1), 3.6, 62.0)
	omni(&"BodyFill", Vector3(0, -44.0, -55.0), Color(0.3, 0.44, 0.68, 1), 4.5, 120.0)
	omni(&"DescentGlow", Vector3(8.0, 2.0, 0), Color(0.42, 0.5, 0.58, 1), 1.2, 12.0)
	omni(&"WaterGlow", Vector3(0, -58.0, -64.0), Color(0.12, 0.2, 0.34, 1), 1.0, 90.0)


func _build_labels() -> void:
	label(&"NeckLabel", Vector3(0, 3.6, 2.0), "ШЕЯ СТАТУИ", Color(0.72, 0.82, 1.0, 0.95), 34)
	label(&"StarsLabel", Vector3(0, -8.0, -38.0), "СЕМЬ ЗВЁЗД", Color(0.55, 0.72, 1.0, 0.8), 30)
	label(&"SwordLabel", Vector3(0.0, -48.0, -32.0), "МЕЧ", Color(0.64, 0.72, 0.88, 0.75), 28)
	label(&"DescentLabel", Vector3(8.5, 3.0, 0), "СПУСК ПО СТАТУЕ", Color(0.55, 0.82, 1.0, 0.9), 26)


# ---------------------------------------------------------------------------
# Мелкие строители гигантских форм
# ---------------------------------------------------------------------------

func _module_root(module_id: StringName, position := Vector3.ZERO, rotation_y := 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = module_id
	root.position = position
	root.rotation.y = rotation_y
	_structure.add_child(root)
	_register(module_id, root)
	return root


func _statue_block(
	module_id: StringName,
	position: Vector3,
	size: Vector3,
	material_key: StringName = &"statue",
	rotation := Vector3.ZERO,
	collision := false
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = module_id
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = position
	mesh_instance.rotation = rotation
	_structure.add_child(mesh_instance)
	_register(module_id, mesh_instance)
	if collision:
		_add_box_collision(mesh_instance, size)
	return mesh_instance


func _statue_cylinder(
	parent: Node3D,
	child_name: StringName,
	local_position: Vector3,
	top_radius: float,
	bottom_radius: float,
	height: float,
	material_key: StringName,
	rotation := Vector3.ZERO,
	segments := 24
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = child_name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top_radius
	cylinder.bottom_radius = bottom_radius
	cylinder.height = height
	cylinder.radial_segments = segments
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = local_position
	mesh_instance.rotation = rotation
	parent.add_child(mesh_instance)
	return mesh_instance


func _statue_sphere(
	parent: Node3D,
	child_name: StringName,
	local_position: Vector3,
	radius: float,
	material_key: StringName,
	scale_factor := Vector3.ONE
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = child_name
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 20
	sphere.rings = 10
	mesh_instance.mesh = sphere
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = local_position
	mesh_instance.scale = scale_factor
	parent.add_child(mesh_instance)
	return mesh_instance


## Плоская пятиконечная звезда в локальной плоскости XY, нормалью к +Z.
## Корень ChestStars поворачивается на 180°, чтобы звёзды смотрели вперёд.
func _add_star(parent: Node3D, star_id: StringName, local_position: Vector3, radius: float) -> void:
	var star := MeshInstance3D.new()
	star.name = star_id
	star.mesh = _star_mesh(radius)
	star.material_override = STATUE_STAR_MATERIAL
	star.position = local_position
	star.rotation.y = PI
	parent.add_child(star)


func _star_mesh(radius: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)
	normals.append(Vector3(0, 0, 1))
	for i in 10:
		var angle := -PI * 0.5 + TAU * float(i) / 10.0
		var r := radius if i % 2 == 0 else radius * 0.43
		vertices.append(Vector3(cos(angle) * r, sin(angle) * r, 0))
		normals.append(Vector3(0, 0, 1))
	for i in 10:
		indices.append(0)
		indices.append(i + 1)
		indices.append((i + 1) % 10 + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# ---------------------------------------------------------------------------
# M2: осмотр статуи и спуск
# ---------------------------------------------------------------------------

func _build_post_nightmare_content() -> void:
	var stars := Interactable.new()
	stars.name = "StarsInteract"
	stars.interaction_id = &"black_sea_stars"
	stars.prompt = "Посмотреть на нагрудник"
	stars.radius = 2.8
	stars.enabled = true
	stars.position = Vector3(0.0, 1.0, 5.2)
	add_child(stars)
	stars.interacted.connect(_on_stars_interacted)

	var sword := Interactable.new()
	sword.name = "SwordInteract"
	sword.interaction_id = &"black_sea_sword"
	sword.prompt = "Посмотреть на меч"
	sword.radius = 2.8
	sword.enabled = true
	sword.position = Vector3(-4.8, 1.0, 1.2)
	add_child(sword)
	sword.interacted.connect(_on_sword_interacted)

	# B01: Плащ призывается после осмотра статуи; без повторной награды.
	var shroud := Interactable.new()
	shroud.name = "ShroudInteract"
	shroud.interaction_id = &"black_sea_shroud"
	shroud.prompt = "Призвать Плащ"
	shroud.radius = 2.4
	shroud.enabled = NightmareRunState.has_flag(&"statue_seen") and not NightmareRunState.has_flag(&"shroud_summoned")
	shroud.position = Vector3(2.8, 1.0, 4.2)
	add_child(shroud)
	shroud.interacted.connect(_on_shroud_interacted)

	var portal := get_node_or_null(^"Portals/ToCoral") as LevelPortal
	if portal != null:
		portal.enabled = NightmareRunState.has_flag(&"statue_seen") and NightmareRunState.has_flag(&"shroud_summoned")
		portal.required_flags = [&"statue_seen", &"shroud_summoned"]
		portal.set_flags_on_use = [&"b01_completed"]

	var descent := Interactable.new()
	descent.name = "DescentInteract"
	descent.interaction_id = &"black_sea_descent"
	descent.prompt = "Спуститься к кораллам"
	descent.radius = 2.4
	descent.enabled = not NightmareRunState.has_flag(&"b01_completed")
	descent.position = Vector3(8.0, 1.0, 0.0)
	add_child(descent)
	descent.interacted.connect(_on_descent_interacted)


func _on_stars_interacted(_id: StringName) -> void:
	play_dialogue(STARS_SEQUENCE)
	NightmareRunState.set_flag(&"statue_seen")
	_enable_shroud_if_ready()


func _on_sword_interacted(_id: StringName) -> void:
	play_dialogue(SWORD_SEQUENCE)
	NightmareRunState.set_flag(&"statue_seen")
	_enable_shroud_if_ready()


func _enable_shroud_if_ready() -> void:
	var shroud := get_node_or_null(^"ShroudInteract") as Interactable
	if shroud != null:
		shroud.enabled = not NightmareRunState.has_flag(&"shroud_summoned")


func _on_shroud_interacted(_id: StringName) -> void:
	if NightmareRunState.has_flag(&"shroud_summoned"):
		return
	if not play_cutscene(&"B01Shroud"):
		play_dialogue(SHROUD_SEQUENCE)
	NightmareRunState.set_flag(&"shroud_summoned")
	var shroud := get_node_or_null(^"ShroudInteract") as Interactable
	if shroud != null:
		shroud.enabled = false
	var portal := get_node_or_null(^"Portals/ToCoral") as LevelPortal
	if portal != null:
		portal.enabled = true
	set_scene_objective("Спуститься по статуе к кораллам.")


func _on_descent_interacted(_id: StringName) -> void:
	if NightmareRunState.has_flag(&"b01_completed"):
		return
	play_dialogue(DESCENT_SEQUENCE)
	NightmareRunState.set_flag(&"b01_completed")
	var descent := get_node_or_null(^"DescentInteract") as Interactable
	if descent != null:
		descent.enabled = false
	var portal := get_node_or_null(^"Portals/ToCoral") as LevelPortal
	if portal != null:
		portal.enabled = true
		portal.activate()
