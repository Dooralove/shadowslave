class_name CoralLabyrinth
extends GreyboxLocation
## B03–B05: коралловый лабиринт на дне Чёрного моря.
##
## Лабиринт собран из коротких комнат и коридоров с открытым верхом.
## Коралловые стены, кости и ритуальная площадка задают тон; сетку легко
## продолжить новыми ветками, не меняя остальные локации.

const WORLD_FRAME := preload("res://scripts/world/world_frame.gd")


func build_layout() -> void:
	_build_foundation()
	_build_backdrop()
	_build_tide_landing()
	_build_maze()
	_build_shrine()
	_build_coral_and_bones()
	_build_lights()
	_build_labels()


# ---------------------------------------------------------------------------
# Основание и сетка лабиринта
# ---------------------------------------------------------------------------

func _build_foundation() -> void:
	# Верх основания намеренно ниже полов комнат, чтобы не было z-fighting.
	structure(&"SeaFloor", Vector3(0, -0.35, -5), Vector3(60, 0.6, 70), &"mud")

	# Тёмная вода по краям — визуальная граница, без коллизии.
	prop_box(&"DeepWater", Vector3(0, -1.2, 0), Vector3(120, 0.1, 120), &"water")

	for i in 8:
		var angle := TAU * float(i) / 8.0
		var edge_center := Vector3(cos(angle) * 23.0, 3.0, sin(angle) * 23.0 - 6.0)
		var edge_size := Vector3(18.0, 6.0, 0.6)
		var edge_rotation := -angle - PI * 0.5
		if i == 2:
			# Южная стена лабиринта разорвана лестницей с платформы.
			edge_size.x = 4.6
			boundary(&"MazeBoundary2West", edge_center + Vector3(-6.7, 0, 0), edge_size, edge_rotation)
			boundary(&"MazeBoundary2East", edge_center + Vector3(6.7, 0, 0), edge_size, edge_rotation)
			continue
		boundary(
			StringName("MazeBoundary%d" % i),
			edge_center,
			edge_size,
			edge_rotation
		)


## The sandbox is not the final art target, but it is the entry point from
## tide_descent. A cheap reef horizon keeps the first impression from being a
## 60 m slab in a black void.
func _build_backdrop() -> void:
	var backdrop := Node3D.new()
	backdrop.name = "Backdrop"
	_structure.add_child(backdrop)
	var sea := WORLD_FRAME.far_sea(
		Vector3(0.0, -1.3, 0.0),
		3200.0,
		Color(0.010, 0.016, 0.026),
		Color(0.20, 0.23, 0.26),
		"FarBlackSea",
		160.0,
		1300.0
	)
	backdrop.add_child(sea)
	var near_rim := WORLD_FRAME.ridge_ring(
		Vector3.ZERO,
		300.0,
		96,
		-1.4,
		10.0,
		38.0,
		Color(0.30, 0.32, 0.34),
		Color(0.16, 0.10, 0.11),
		Color(0.30, 0.32, 0.34),
		Color(0.16, 0.10, 0.11),
		211,
		"NearReefHorizon"
	)
	backdrop.add_child(near_rim)
	var far_rim := WORLD_FRAME.ridge_ring(
		Vector3.ZERO,
		760.0,
		80,
		-1.4,
		26.0,
		86.0,
		Color(0.30, 0.32, 0.34),
		Color(0.22, 0.16, 0.17),
		Color(0.30, 0.32, 0.34),
		Color(0.22, 0.16, 0.17),
		223,
		"FarReefHorizon"
	)
	backdrop.add_child(far_rim)
	WORLD_FRAME.reef_band(
		backdrop,
		Vector3.ZERO,
		-1.3,
		120.0,
		300.0,
		42,
		8.0,
		32.0,
		Color(0.18, 0.075, 0.085),
		Color(0.30, 0.32, 0.34),
		0.50,
		241,
		"ReefBandNorth"
	)
	WORLD_FRAME.reef_band(
		backdrop,
		Vector3.ZERO,
		-1.3,
		130.0,
		320.0,
		38,
		7.0,
		28.0,
		Color(0.16, 0.070, 0.080),
		Color(0.30, 0.32, 0.34),
		0.56,
		257,
		"ReefBandSouth"
	)


func _build_maze() -> void:
	var wall_options := {
		"floor_material": &"mud",
		"wall_material": &"coral_pale",
		"ceiling_material": &"coral_pale",
		"open_ceiling": true,
	}

	room(
		&"Entrance",
		Vector3(0, 0, 12),
		Vector3(8, 4.5, 10),
		&"coral_pale",
		[
			{"side": &"north", "width": 4.0, "height": 4.5},
			{"side": &"south", "width": 4.0, "height": 4.5},
		],
		wall_options
	)
	room(
		&"EntranceCorridor",
		Vector3(0, 0, 3),
		Vector3(4, 4.5, 10),
		&"coral_pale",
		[
			{"side": &"north", "width": 4.0, "height": 4.5},
			{"side": &"south", "width": 4.0, "height": 4.5},
		],
		wall_options
	)
	room(
		&"Hub",
		Vector3(0, 0, -5),
		Vector3(10, 4.5, 10),
		&"coral_pale",
		[
			{"side": &"south", "width": 4.0, "height": 4.5},
			{"side": &"north", "width": 4.0, "height": 4.5},
			{"side": &"east", "width": 3.0, "height": 4.5},
			{"side": &"west", "width": 3.0, "height": 4.5},
		],
		wall_options
	)

	# Северная ветка к святилищу.
	room(
		&"NorthCorridor",
		Vector3(0, 0, -13),
		Vector3(4, 4.5, 8),
		&"coral_pale",
		[
			{"side": &"north", "width": 4.0, "height": 4.5},
			{"side": &"south", "width": 4.0, "height": 4.5},
		],
		wall_options
	)

	# Восточная ветка: коридор и камера с пустыми креслами.
	room(
		&"EastCorridor",
		Vector3(7, 0, -5),
		Vector3(6, 4.5, 4),
		&"coral_pale",
		[
			{"side": &"east", "width": 3.0, "height": 4.5},
			{"side": &"west", "width": 3.0, "height": 4.5},
		],
		wall_options
	)
	room(
		&"EastChamber",
		Vector3(14, 0, -5),
		Vector3(8, 4.5, 8),
		&"coral_pale",
		[{"side": &"west", "width": 3.0, "height": 4.5}],
		wall_options
	)

	# Западная ветка: узкий проход и камера с костями.
	room(
		&"WestCorridor",
		Vector3(-7, 0, -5),
		Vector3(6, 4.5, 4),
		&"coral_pale",
		[
			{"side": &"east", "width": 3.0, "height": 4.5},
			{"side": &"west", "width": 3.0, "height": 4.5},
		],
		wall_options
	)
	room(
		&"WestChamber",
		Vector3(-14, 0, -5),
		Vector3(8, 4.5, 8),
		&"coral_pale",
		[{"side": &"east", "width": 3.0, "height": 4.5}],
		wall_options
	)

	# Потайная камера за святилищем.
	room(
		&"SecretCorridor",
		Vector3(8, 0, -23),
		Vector3(6, 4.5, 4),
		&"coral",
		[
			{"side": &"east", "width": 3.0, "height": 4.5},
			{"side": &"west", "width": 3.0, "height": 4.5},
		],
		wall_options
	)
	room(
		&"SecretChamber",
		Vector3(14, 0, -23),
		Vector3(6, 4.5, 6),
		&"coral",
		[{"side": &"west", "width": 3.0, "height": 4.5}],
		wall_options
	)


func _build_shrine() -> void:
	room(
		&"Shrine",
		Vector3(0, 0, -23),
		Vector3(14, 5.0, 12),
		&"coral_pale",
		[{"side": &"south", "width": 4.0, "height": 5.0}],
		{
			"floor_material": &"mud",
			"wall_material": &"coral",
			"ceiling_material": &"coral",
			"open_ceiling": true,
		}
	)

	platform(&"ShrineDais", Vector3(0, 0.25, -23), 4.0, 0.6, &"coral_pale", true)
	prop_box(&"ShrineAltar", Vector3(0, 0.9, -23), Vector3(2.2, 0.8, 1.2), &"statue")
	prop_box(&"ShrineAltarTop", Vector3(0, 1.32, -23), Vector3(2.5, 0.12, 1.5), &"bone")
	statue_star(&"ShrineStar", Vector3(0, 2.8, -23), 1.3)
	prop_cylinder(&"ShrineGlow", Vector3(0, 1.7, -23), 0.55, 0.12, &"red_glow", 16)

	# Ритуальные чаши вокруг площадки.
	for i in 3:
		var angle := -PI * 0.5 + TAU * float(i) / 3.0
		prop_cylinder(
			StringName("RitualBowl%d" % i),
			Vector3(cos(angle) * 5.2, 0.35, -23 + sin(angle) * 5.2),
			0.35,
			0.6,
			&"statue",
			12
		)
		prop_cylinder(
			StringName("RitualGlow%d" % i),
			Vector3(cos(angle) * 5.2, 0.68, -23 + sin(angle) * 5.2),
			0.24,
			0.08,
			&"red_glow",
			12
		)


# ---------------------------------------------------------------------------
# Спуск с платформы
# ---------------------------------------------------------------------------

## Нижняя площадка под южным краем лабиринта. Игрок приходит сюда из
## tide_descent, поднимается по каменной лестнице и только затем попадает
## в Entrance. Так спуск не выглядит как перенос в середину комнаты.
func _build_tide_landing() -> void:
	# Пол площадки ниже уровня лабиринта; верх плиты совпадает с y = -6.
	structure(&"TideLandingFloor", Vector3(0, -6.25, 26), Vector3(8, 0.5, 7), &"mud")
	structure(&"TideLandingStep", Vector3(0, -6.1, 22.5), Vector3(6, 0.2, 1.6), &"statue")
	stairs(&"TideStairs", Vector3(0, -6.0, 24.0), 4.0, 0.25, 0.3, 24, &"statue")

	# Боковые стены и внешний тамбур: игрок не сваливается в воду.
	for x in [-4.4, 4.4]:
		structure(StringName("TideWall%s" % str(x)), Vector3(x, -4.0, 26), Vector3(0.8, 4.0, 7), &"coral_pale")
	boundary(&"TideBackstop", Vector3(0, -4.5, 29.7), Vector3(8, 3, 0.5))
	boundary(&"TideSideWest", Vector3(-4.7, -4.0, 25), Vector3(0.4, 4.0, 9), 0.0)
	boundary(&"TideSideEast", Vector3(4.7, -4.0, 25), Vector3(0.4, 4.0, 9), 0.0)

	# Влажный камень, коралловые стойки и фонарь у входа.
	coral_cluster(&"TideCoralWest", Vector3(-3.4, -6.0, 27.8), 3.6, 71)
	coral_cluster(&"TideCoralEast", Vector3(3.4, -6.0, 27.8), 3.2, 72)
	prop_box(&"TideArchWest", Vector3(-2.5, -3.2, 28.4), Vector3(0.7, 5.6, 0.7), &"coral")
	prop_box(&"TideArchEast", Vector3(2.5, -3.2, 28.4), Vector3(0.7, 5.6, 0.7), &"coral")
	prop_box(&"TideArchLintel", Vector3(0, -0.65, 28.4), Vector3(5.6, 0.5, 0.8), &"coral_pale")
	omni(&"TideLandingLight", Vector3(0, -3.8, 26.5), Color(0.35, 0.72, 1.0, 1), 2.0, 12.0)
	label(&"TideLandingLabel", Vector3(0, -1.5, 28.3), "СПУСК С ПЛАТФОРМЫ", Color(0.55, 0.82, 1.0, 0.85), 24)


# ---------------------------------------------------------------------------
# Коралл, кости и следы
# ---------------------------------------------------------------------------

func _build_coral_and_bones() -> void:
	var clusters := [
		[-3.2, 16.0, 4.6, 11],
		[3.2, 16.0, 4.2, 12],
		[-3.2, 9.0, 3.6, 13],
		[3.2, 9.0, 3.9, 14],
		[-4.2, -1.2, 4.8, 21],
		[4.2, -1.2, 5.2, 22],
		[-4.2, -8.8, 4.4, 23],
		[4.2, -8.8, 4.8, 24],
		[-7.8, -8.0, 3.8, 31],
		[-7.8, -2.0, 4.4, 32],
		[-16.8, -8.0, 4.6, 33],
		[-16.8, -2.0, 3.8, 34],
		[7.8, -8.0, 3.6, 41],
		[7.8, -2.0, 4.6, 42],
		[16.8, -8.0, 4.2, 43],
		[16.8, -2.0, 4.8, 44],
		[-6.2, -28.0, 5.2, 51],
		[6.2, -28.0, 5.0, 52],
		[-6.2, -18.0, 4.2, 53],
		[6.2, -18.0, 4.5, 54],
		[16.5, -25.5, 3.8, 61],
		[16.5, -20.5, 4.0, 62],
	]

	var index := 0
	for entry in clusters:
		coral_cluster(
			StringName("Coral%d" % index),
			Vector3(float(entry[0]), 0, float(entry[1])),
			float(entry[2]),
			int(entry[3])
		)
		index += 1

	# Кости: рёбра обрамляют святилище по бокам, а не перекрывают алтарь.
	bone(&"RibA", Vector3(-4.6, 0.5, -19.6), 3.6, Vector3(0, 0.35, 1.45))
	bone(&"RibB", Vector3(4.6, 0.5, -19.6), 3.6, Vector3(0, -0.35, 1.45))
	bone(&"RibC", Vector3(0, 4.1, -19.0), 6.0, Vector3(0, 0, PI * 0.5))
	bone(&"BoneEast", Vector3(13.0, 0.15, -2.0), 2.2, Vector3(0.25, 0.5, 0.0))
	bone(&"BoneWest", Vector3(-14.0, 0.15, -6.5), 2.6, Vector3(0.1, -0.6, 0.0))
	bone(&"BoneHub", Vector3(-2.0, 0.12, -7.5), 1.8, Vector3(0, 1.2, 0.0))
	bone(&"BoneSecret", Vector3(14.0, 0.2, -24.0), 2.4, Vector3(0.3, 0.2, 0.0))

	# Пустые кресла — следы тех, кто не выбрался.
	hollow_chair(&"HollowEastA", Vector3(12.5, 0, -3.0), 0.4)
	hollow_chair(&"HollowEastB", Vector3(14.0, 0, -3.2), -0.2)
	hollow_chair(&"HollowEastC", Vector3(15.5, 0, -3.0), 0.8)
	hollow_chair(&"HollowWest", Vector3(-15.0, 0, -6.0), PI)
	hollow_chair(&"HollowSecretA", Vector3(13.0, 0, -21.8), 0.3)
	hollow_chair(&"HollowSecretB", Vector3(15.0, 0, -21.8), -0.3)

	# Тёмные лужи на полу — тонкие плоскости без коллизии.
	for i in 5:
		var angle := TAU * float(i) / 5.0
		prop_box(
			StringName("Puddle%d" % i),
			Vector3(cos(angle) * 14.0, 0.015, -5.0 + sin(angle) * 7.0),
			Vector3(2.2, 0.02, 1.4),
			&"water",
			angle
		)
	prop_box(&"ShrinePuddle", Vector3(0, 0.015, -18.5), Vector3(5.0, 0.02, 2.0), &"water")


# ---------------------------------------------------------------------------
# Свет и подписи
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	omni(&"EntranceGlow", Vector3(0, 3.4, 13), Color(0.35, 0.65, 0.95, 1), 2.4, 12.0)
	omni(&"CorridorGlow", Vector3(0, 3.4, 3), Color(0.3, 0.55, 0.85, 1), 1.6, 8.0)
	omni(&"HubGlow", Vector3(0, 3.6, -5), Color(0.4, 0.7, 0.95, 1), 2.2, 14.0)
	omni(&"EastGlow", Vector3(14, 3.4, -5), Color(0.55, 0.4, 0.9, 1), 2.0, 10.0)
	omni(&"WestGlow", Vector3(-14, 3.4, -5), Color(0.3, 0.6, 0.8, 1), 1.8, 10.0)
	omni(&"NorthGlow", Vector3(0, 3.6, -13), Color(0.3, 0.58, 0.86, 1), 1.6, 9.0)
	omni(&"ShrineGlowLight", Vector3(0, 4.2, -23), Color(1.0, 0.28, 0.22, 1), 3.2, 16.0)
	omni(&"ShrineFill", Vector3(0, 2.0, -19), Color(0.7, 0.2, 0.25, 1), 1.2, 8.0)
	omni(&"SecretGlow", Vector3(14, 3.2, -23), Color(0.8, 0.3, 0.55, 1), 1.8, 8.0)


func _build_labels() -> void:
	label(&"LabyrinthLabel", Vector3(0, 4.0, 14.0), "КОРАЛЛОВЫЙ ЛАБИРИНТ", Color(0.7, 0.86, 1.0, 0.95), 40)
	label(&"HubLabel", Vector3(0, 3.4, -4.0), "РАЗВИЛКА", Color(0.62, 0.8, 1.0, 0.85), 26)
	label(&"ShrineLabel", Vector3(0, 4.4, -18.0), "СВЯТИЛИЩЕ", Color(1.0, 0.6, 0.55, 0.95), 34)
	label(&"EastLabel", Vector3(11.0, 2.8, -5.0), "ВОСТОЧНЫЙ ГРОТ", Color(0.8, 0.68, 1.0, 0.85), 24)
	label(&"WestLabel", Vector3(-11.0, 2.8, -5.0), "ЗАПАДНЫЙ ГРОТ", Color(0.6, 0.8, 1.0, 0.85), 24)
	label(&"SecretLabel", Vector3(11.0, 2.6, -23.0), "ПОТАЙНАЯ КАМЕРА", Color(1.0, 0.55, 0.7, 0.85), 22)
