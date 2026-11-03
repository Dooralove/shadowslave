class_name AcademyApproach
extends GreyboxLocation
## P02.5: подъездная улица между городом и воротами Академии.
##
## Короткий связующий отрезок: машина у южного края, КПП и стена Академии
## у северного. Игрок проходит его пешком, поэтому переход из участка в
## ворота не выглядит как мгновенный перенос в другую локацию.

const JET_SEQUENCE := preload("res://resources/dialogue/post_nightmare/p06_jett_advice.tres")
const CHECKPOINT_SEQUENCE := preload("res://resources/dialogue/post_nightmare/p06_checkpoint.tres")
const MANNEQUIN_SCENE := preload("res://scenes/slice/props/mannequin.tscn")
const WORLD_FRAME := preload("res://scripts/world/world_frame.gd")
const SNOW_SCENE := preload("res://scenes/environment/vfx/m1_snow_drift.tscn")


func build_layout() -> void:
	_build_ground()
	_build_checkpoint()
	_build_city_edge()
	_build_backdrop()
	_build_car()
	_build_lights()
	_build_labels()
	_build_post_nightmare_content()


func _build_ground() -> void:
	structure(&"ApproachRoad", Vector3(0, -0.25, 0), Vector3(14, 0.5, 44), &"asphalt")
	structure(&"ApproachWalkWest", Vector3(-8.5, -0.25, 0), Vector3(3, 0.5, 44), &"snow")
	structure(&"ApproachWalkEast", Vector3(8.5, -0.25, 0), Vector3(3, 0.5, 44), &"snow")
	structure(&"DropOffPlaza", Vector3(0, -0.26, 18), Vector3(20, 0.5, 8), &"asphalt")
	structure(&"CheckpointPlaza", Vector3(0, -0.26, -19), Vector3(20, 0.5, 7), &"concrete")

	boundary(&"ApproachWest", Vector3(-10.3, 3, 0), Vector3(0.5, 6, 45))
	boundary(&"ApproachEast", Vector3(10.3, 3, 0), Vector3(0.5, 6, 45))
	boundary(&"ApproachSouth", Vector3(0, 3, 22.3), Vector3(21, 6, 0.5))
	boundary(&"CheckpointBackstop", Vector3(0, 3, -24.0), Vector3(8, 6, 0.5))

	# Следы машин и бордюр: простые тёмные полосы без коллизии.
	for x in [-4.0, -1.2, 1.2, 4.0]:
		prop_box(StringName("LaneStripe%s" % str(x)), Vector3(x, 0.01, 0), Vector3(0.12, 0.02, 36), &"concrete")
	for z in [-15.0, -7.0, 7.0, 15.0]:
		prop_box(StringName("CurbWest%s" % str(z)), Vector3(-7.0, 0.08, z), Vector3(0.3, 0.16, 6.0), &"concrete_dark")
		prop_box(StringName("CurbEast%s" % str(z)), Vector3(7.0, 0.08, z), Vector3(0.3, 0.16, 6.0), &"concrete_dark")

	# Снежные валы у тротуаров.
	for z in [-16.0, -4.0, 8.0, 17.0]:
		prop_box(StringName("SnowBankWest%s" % str(z)), Vector3(-9.4, 0.18, z), Vector3(1.1, 0.36, 4.0), &"snow", 0.05)
		prop_box(StringName("SnowBankEast%s" % str(z)), Vector3(9.4, 0.18, z), Vector3(1.1, 0.36, 4.0), &"snow", -0.05)


func _build_checkpoint() -> void:
	# Стена Академии с центральным проёмом; за проёмом начинается сцена ворот.
	structure(&"CheckpointWallWest", Vector3(-6.4, 3.0, -22.5), Vector3(8.8, 6.0, 1.0), &"concrete_dark")
	structure(&"CheckpointWallEast", Vector3(6.4, 3.0, -22.5), Vector3(8.8, 6.0, 1.0), &"concrete_dark")
	structure(&"CheckpointLintel", Vector3(0, 5.55, -22.5), Vector3(5.0, 1.1, 1.2), &"statue")
	structure(&"CheckpointDark", Vector3(0, 2.3, -23.15), Vector3(4.2, 4.6, 0.08), &"black", false)
	structure(&"CheckpointPostWest", Vector3(-2.5, 2.2, -21.2), Vector3(0.7, 4.4, 0.9), &"concrete_dark")
	structure(&"CheckpointPostEast", Vector3(2.5, 2.2, -21.2), Vector3(0.7, 4.4, 0.9), &"concrete_dark")
	statue_star(&"ApproachStar", Vector3(0, 7.1, -22.5), 1.0)

	# Будка КПП с подсвеченным окном.
	structure(&"GuardBooth", Vector3(6.8, 1.6, -18.8), Vector3(4.0, 3.2, 4.0), &"concrete_dark")
	structure(&"GuardRoof", Vector3(6.8, 3.35, -18.8), Vector3(4.6, 0.3, 4.6), &"metal_dark")
	prop_box(&"GuardWindow", Vector3(4.78, 1.9, -18.8), Vector3(0.06, 1.1, 2.4), &"screen_warm")
	prop_box(&"GuardDoor", Vector3(6.8, 1.2, -16.78), Vector3(1.0, 2.2, 0.08), &"metal_dark")
	prop_box(&"GuardBarrierArm", Vector3(4.2, 1.1, -17.2), Vector3(5.2, 0.12, 0.12), &"metal_light", 0.0)
	prop_box(&"GuardBarrierFoot", Vector3(1.7, 0.35, -17.2), Vector3(0.5, 0.7, 0.5), &"metal_dark")
	label(&"CheckpointLabel", Vector3(0, 6.4, -22.5), "КПП АКАДЕМИИ", Color(0.78, 0.88, 1.0, 0.9), 30)
	label(&"GuardLabel", Vector3(6.8, 3.0, -16.7), "ПОСТ ПРОВЕРКИ", Color(1.0, 0.86, 0.64, 0.85), 22)


func _build_city_edge() -> void:
	# Силуэты городских коробок за оградой; в игру не входят.
	for side in [-1.0, 1.0]:
		var x: float = 15.0 * side
		for index in 2:
			var z := -8.0 + 16.0 * float(index)
			var height := 8.0 + 3.0 * float(index)
			structure(
				StringName("CityBlock%s%d" % [str(side), index]),
				Vector3(x, height * 0.5 - 0.2, z),
				Vector3(8.0, height, 12.0),
				&"concrete_dark",
				false
			)
			for window in 3:
				prop_box(
					StringName("CityWindow%s%d%d" % [str(side), index, window]),
					Vector3(x - 4.02 * side, 2.0 + 1.6 * float(window), z - 3.0),
					Vector3(0.03, 0.8, 1.0),
					&"screen_warm"
				)

	# Ограда вдоль тротуаров: столбы и две перекладины.
	for z in range(-18, 20, 4):
		for side in [-1.0, 1.0]:
			var x: float = 10.1 * side
			prop_cylinder(StringName("FencePost%s%s" % [str(side), str(z)]), Vector3(x, 1.2, z), 0.06, 2.4, &"metal_dark", 8)
	for side in [-1.0, 1.0]:
		var x: float = 10.1 * side
		prop_box(StringName("FenceRailTop%s" % str(side)), Vector3(x, 2.1, 0), Vector3(0.05, 0.05, 36), &"metal_dark")
		prop_box(StringName("FenceRailMid%s" % str(side)), Vector3(x, 1.2, 0), Vector3(0.05, 0.05, 36), &"metal_dark")

	# Автобусная остановка на южном краю: визуальная причина, почему здесь
	# останавливается машина.
	structure(&"BusShelterBack", Vector3(-7.8, 1.5, 18.0), Vector3(0.15, 3.0, 4.6), &"metal_dark")
	structure(&"BusShelterRoof", Vector3(-7.1, 3.0, 18.0), Vector3(1.8, 0.15, 4.8), &"metal_dark")
	bench(&"BusBench", Vector3(-8.0, 0, 18.0), 3.2, PI * 0.5)
	prop_box(&"BusSign", Vector3(-8.0, 2.4, 15.4), Vector3(0.08, 1.2, 0.7), &"screen_warm")


## The approach is a short street slice. A winter ground plane, two rings of
## city blocks and the distant Academy wall turn it into a street inside a
## city instead of a road slab floating in grey fog.
func _build_backdrop() -> void:
	var backdrop := Node3D.new()
	backdrop.name = "Backdrop"
	_structure.add_child(backdrop)

	var ground := MeshInstance3D.new()
	ground.name = "CityGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(900.0, 900.0)
	ground.mesh = plane
	ground.material_override = load("res://resources/locations/post_nightmare/materials/snow_night_ground.tres") as Material
	ground.position = Vector3(0.0, -0.20, 0.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.add_child(ground)

	var palette := [
		Color(0.14, 0.15, 0.17),
		Color(0.18, 0.19, 0.22),
		Color(0.11, 0.12, 0.14),
	]
	var haze := Color(0.55, 0.60, 0.66)
	# Side blocks: the road corridor stays open to the north.
	WORLD_FRAME.city_skyline(
		backdrop,
		Vector3.ZERO,
		-0.20,
		62.0,
		220.0,
		30,
		12.0,
		52.0,
		palette,
		307,
		-PI * 0.5,
		0.48,
		"ApproachSkyline",
		haze,
		90.0,
		700.0,
		Color(0.90, 0.75, 0.52),
		0.10,
		3.0,
		6.0,
		18.0,
		0.86,
		true
	)
	# Far skyline beyond the checkpoint: the Academy wall and the city behind.
	WORLD_FRAME.city_skyline(
		backdrop,
		Vector3(0.0, 0.0, -150.0),
		-0.20,
		70.0,
		240.0,
		18,
		18.0,
		64.0,
		palette,
		419,
		0.0,
		0.0,
		"AcademyOuterSkyline",
		haze,
		160.0,
		760.0,
		Color(0.88, 0.73, 0.50),
		0.09,
		3.4,
		8.0,
		22.0
	)

	# The Academy wall is visible above the checkpoint. Its central red gate
	# is the visual promise of the next scene.
	WORLD_FRAME.mass_block(
		backdrop,
		Vector3(-44.0, 4.3, -96.0),
		Vector3(88.0, 9.0, 4.0),
		Color(0.045, 0.050, 0.060),
		haze,
		0.42,
		"AcademyWallWest"
	)
	WORLD_FRAME.mass_block(
		backdrop,
		Vector3(44.0, 4.3, -96.0),
		Vector3(88.0, 9.0, 4.0),
		Color(0.045, 0.050, 0.060),
		haze,
		0.42,
		"AcademyWallEast"
	)
	WORLD_FRAME.mass_block(
		backdrop,
		Vector3(0.0, 7.3, -96.0),
		Vector3(16.0, 15.0, 6.0),
		Color(0.30, 0.055, 0.045),
		haze,
		0.48,
		"AcademyRedGate"
	)
	WORLD_FRAME.mass_block(
		backdrop,
		Vector3(-11.0, 10.8, -96.0),
		Vector3(7.0, 22.0, 7.0),
		Color(0.040, 0.045, 0.055),
		haze,
		0.46,
		"AcademyGateTowerWest"
	)
	WORLD_FRAME.mass_block(
		backdrop,
		Vector3(11.0, 10.8, -96.0),
		Vector3(7.0, 22.0, 7.0),
		Color(0.040, 0.045, 0.055),
		haze,
		0.46,
		"AcademyGateTowerEast"
	)

	# A few lamps continue beyond the playable road, so the street reads as a
	# route into the city rather than a stage that ends at z = -24.
	for z in [-38.0, -54.0, -70.0]:
		for side in [-1.0, 1.0]:
			var x: float = 9.2 * float(side)
			prop_cylinder(StringName("DistantLampPole%s%s" % [str(side), str(z)]), Vector3(x, 3.0, z), 0.07, 6.0, &"metal_dark", 8)
			prop_box(StringName("DistantLampGlow%s%s" % [str(side), str(z)]), Vector3(x, 5.8, z), Vector3(0.42, 0.05, 0.22), &"screen_warm")

	# Light snowfall around the playable street.
	for i in 3:
		var snow := SNOW_SCENE.instantiate() as Node3D
		if snow == null:
			continue
		snow.name = "Snowfall%d" % i
		snow.position = Vector3(0.0, 2.0, -14.0 + float(i) * 14.0)
		backdrop.add_child(snow)
		for child in snow.get_children():
			var particles := child as GPUParticles3D
			if particles != null:
				particles.emitting = true
				particles.preprocess = 1.5


func _build_car() -> void:
	# Тёмная машина Джетта у южного края. Не интерактивна: она обозначает
	# начало и конец поездки, а не транспортную механику.
	var car := _prop_root(&"JettCar", Vector3(-3.4, 0, 18.6), 0.0)
	_prop_box(car, &"Body", Vector3(0, 0.55, 0), Vector3(4.4, 0.7, 1.9), &"black")
	_prop_box(car, &"Cabin", Vector3(0.25, 1.08, 0), Vector3(2.0, 0.58, 1.7), &"glass_blue")
	_prop_box(car, &"Hood", Vector3(-1.9, 0.82, 0), Vector3(0.7, 0.12, 1.8), &"black")
	_prop_box(car, &"Trunk", Vector3(1.9, 0.82, 0), Vector3(0.6, 0.12, 1.8), &"black")
	_prop_box(car, &"HeadlightL", Vector3(-2.2, 0.6, -0.62), Vector3(0.08, 0.2, 0.38), &"screen_warm")
	_prop_box(car, &"HeadlightR", Vector3(-2.2, 0.6, 0.62), Vector3(0.08, 0.2, 0.38), &"screen_warm")
	_prop_box(car, &"TailL", Vector3(2.2, 0.6, -0.62), Vector3(0.06, 0.18, 0.34), &"red_glow")
	_prop_box(car, &"TailR", Vector3(2.2, 0.6, 0.62), Vector3(0.06, 0.18, 0.34), &"red_glow")
	for x in [-1.35, 1.35]:
		for z in [-0.98, 0.98]:
			_prop_cylinder(
				car,
				StringName("Wheel%s%s" % [str(x), str(z)]),
				Vector3(x, 0.34, z),
				0.34,
				0.22,
				&"black",
				14,
				Vector3(0.0, 0.0, PI * 0.5)
			)
	omni(&"CarHeadlightGlow", Vector3(-5.8, 0.9, 18.6), Color(1.0, 0.88, 0.68, 1), 1.4, 6.0)
	prop_box(&"CarPuddle", Vector3(-4.6, 0.015, 19.6), Vector3(3.8, 0.02, 1.2), &"tile_wet")


func _build_lights() -> void:
	for z in [-14.0, -6.0, 4.0, 14.0]:
		_street_lamp(StringName("StreetLampWest%s" % str(z)), Vector3(-9.2, 0, z))
		_street_lamp(StringName("StreetLampEast%s" % str(z)), Vector3(9.2, 0, z))
	omni(&"CheckpointFlood", Vector3(0, 5.6, -21.0), Color(0.72, 0.85, 1.0, 1), 2.4, 14.0)
	omni(&"GuardBoothLight", Vector3(5.8, 2.2, -18.8), Color(1.0, 0.86, 0.64, 1), 1.4, 6.0)


func _street_lamp(light_id: StringName, position: Vector3) -> void:
	prop_cylinder(StringName("%sPole" % light_id), position + Vector3(0, 3.0, 0), 0.07, 6.0, &"metal_dark", 8)
	prop_box(StringName("%sHead" % light_id), position + Vector3(0, 5.9, 0), Vector3(0.55, 0.18, 0.32), &"metal_dark")
	prop_box(StringName("%sGlow" % light_id), position + Vector3(0, 5.8, 0), Vector3(0.42, 0.05, 0.22), &"screen_warm")
	omni(light_id, position + Vector3(0, 5.6, 0), Color(1.0, 0.86, 0.64, 1), 2.0, 12.0)


func _build_labels() -> void:
	label(&"CityLabel", Vector3(0, 2.6, 21.0), "ГОРОД · ВЫЕЗД", Color(0.82, 0.86, 0.92, 0.8), 26)
	label(&"ApproachLabel", Vector3(0, 3.2, 4.0), "ПОДЪЕЗД К АКАДЕМИИ", Color(0.75, 0.85, 1.0, 0.75), 28)


# ---------------------------------------------------------------------------
# M2: Джет и КПП
# ---------------------------------------------------------------------------

func _build_post_nightmare_content() -> void:
	_add_npc(&"Jet", Vector3(-2.0, 0.0, 16.8), -PI * 0.5, "mass_female")
	_add_npc(&"CheckpointGuard", Vector3(6.8, 0.0, -18.8), PI, "police_guard")

	var gate := Interactable.new()
	gate.name = "CheckpointInteract"
	gate.interaction_id = &"academy_checkpoint"
	gate.prompt = "Пройти проверку"
	gate.radius = 2.6
	gate.enabled = true
	gate.position = Vector3(4.8, 1.2, -18.8)
	add_child(gate)
	gate.interacted.connect(_on_checkpoint_interacted)

	var jet_trigger := TriggerZone.new()
	jet_trigger.name = "JetTrigger"
	jet_trigger.trigger_id = &"academy_jet"
	jet_trigger.enabled = not NightmareRunState.has_flag(&"jett_advice_heard")
	jet_trigger.collision_layer = 0
	jet_trigger.collision_mask = 2
	var jet_shape := CollisionShape3D.new()
	var jet_box := BoxShape3D.new()
	jet_box.size = Vector3(4.0, 2.4, 4.0)
	jet_shape.shape = jet_box
	jet_trigger.add_child(jet_shape)
	jet_trigger.position = Vector3(-3.0, 1.2, 16.8)
	add_child(jet_trigger)
	jet_trigger.triggered.connect(_on_jet_triggered)

	var portal := get_node_or_null(^"Portals/ToAcademyGate") as LevelPortal
	if portal != null:
		portal.required_flags = [&"jett_advice_heard"]
		portal.set_flags_on_use = [&"p06_completed"]


func _add_npc(node_name: StringName, position: Vector3, rotation_y: float, archetype: String) -> void:
	var npc := MANNEQUIN_SCENE.instantiate() as Mannequin
	if npc == null:
		return
	npc.name = node_name
	npc.archetype = archetype
	npc.position = position
	npc.rotation.y = rotation_y
	_props.add_child(npc)


func _on_jet_triggered(_id: StringName) -> void:
	if NightmareRunState.has_flag(&"jett_advice_heard"):
		return
	play_dialogue(JET_SEQUENCE)
	NightmareRunState.set_flag(&"jett_advice_heard")
	set_scene_objective("Добраться до КПП академии.")
	var trigger := get_node_or_null(^"JetTrigger") as TriggerZone
	if trigger != null:
		trigger.enabled = false


func _on_checkpoint_interacted(_id: StringName) -> void:
	play_dialogue(CHECKPOINT_SEQUENCE)
	NightmareRunState.set_flag(&"p06_checkpoint_passed")
