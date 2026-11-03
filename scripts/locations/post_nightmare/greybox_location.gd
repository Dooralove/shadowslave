class_name GreyboxLocation
extends Node3D
## Базовый шаблон серобокс-локации после Первого Кошмара.
##
## Локация не хранит сотни ручных CSG-узлов. Она собирается из повторяемых
## модулей (комната, коридор, площадка, лестница, реквизит) в момент _ready().
## Геометрия живёт в группе Generated, поэтому её легко заменить, расширить
## или отключить, не трогая сцену, свет и игровые точки.
##
## Расширение локации:
##   1. Добавить вызов room()/corridor()/prop_*() в build_layout().
##   2. При необходимости добавить новый композитный реквизит ниже.
##   3. Перегенерировать карту и прогнать tests/test_post_nightmare_locations.gd.
##
## Это прототип: материалы, пропорции и декор намеренно простые. Замена
## Generated-узлов на финальные модели не затрагивает Spawns, Shots и Markers.

signal layout_built

const MATERIAL_DIR := "res://resources/locations/post_nightmare/materials/"
const MATERIALS := {
	&"concrete": preload("res://resources/locations/post_nightmare/materials/concrete_cold.tres"),
	&"concrete_dark": preload("res://resources/locations/post_nightmare/materials/concrete_dark.tres"),
	&"tile": preload("res://resources/locations/post_nightmare/materials/tile_wet.tres"),
	&"tile_wet": preload("res://resources/locations/post_nightmare/materials/tile_wet.tres"),
	&"paint_white": preload("res://resources/locations/post_nightmare/materials/paint_white.tres"),
	&"white": preload("res://resources/locations/post_nightmare/materials/paint_white.tres"),
	&"metal_dark": preload("res://resources/locations/post_nightmare/materials/metal_dark.tres"),
	&"metal_red": preload("res://resources/locations/post_nightmare/materials/metal_red.tres"),
	&"metal_light": preload("res://resources/locations/post_nightmare/materials/metal_light.tres"),
	&"glass_blue": preload("res://resources/locations/post_nightmare/materials/glass_blue.tres"),
	&"screen_cyan": preload("res://resources/locations/post_nightmare/materials/screen_cyan.tres"),
	&"screen_cyan_dim": preload("res://resources/locations/post_nightmare/materials/screen_cyan_dim.tres"),
	&"screen_warm": preload("res://resources/locations/post_nightmare/materials/screen_warm.tres"),
	&"snow": preload("res://resources/locations/post_nightmare/materials/snow.tres"),
	&"asphalt": preload("res://resources/locations/post_nightmare/materials/asphalt.tres"),
	&"water": preload("res://resources/locations/post_nightmare/materials/water_black.tres"),
	&"mud": preload("res://resources/locations/post_nightmare/materials/mud.tres"),
	&"coral": preload("res://resources/locations/post_nightmare/materials/coral_red.tres"),
	&"coral_pale": preload("res://resources/locations/post_nightmare/materials/coral_pale.tres"),
	&"bone": preload("res://resources/locations/post_nightmare/materials/bone.tres"),
	&"wood_dark": preload("res://resources/locations/post_nightmare/materials/wood_dark.tres"),
	&"wood_light": preload("res://resources/locations/post_nightmare/materials/wood_light.tres"),
	&"fabric_blue": preload("res://resources/locations/post_nightmare/materials/fabric_blue.tres"),
	&"fabric_grey": preload("res://resources/locations/post_nightmare/materials/fabric_grey.tres"),
	&"hollow": preload("res://resources/locations/post_nightmare/materials/hollow_skin.tres"),
	&"orange": preload("res://resources/locations/post_nightmare/materials/emissive_orange.tres"),
	&"red_glow": preload("res://resources/locations/post_nightmare/materials/emissive_red.tres"),
	&"statue": preload("res://resources/locations/post_nightmare/materials/statue_stone.tres"),
	&"statue_pale": preload("res://resources/locations/post_nightmare/materials/statue_pale.tres"),
	&"black": preload("res://resources/locations/post_nightmare/materials/black.tres"),
	&"fin": preload("res://resources/locations/post_nightmare/materials/fin_dark.tres"),
	&"mirror": preload("res://resources/locations/post_nightmare/materials/mirror.tres"),
	&"strip": preload("res://resources/locations/post_nightmare/materials/light_strip.tres"),
	&"fire": preload("res://resources/locations/post_nightmare/materials/fire_glow.tres"),
}

const WALL_THICKNESS := 0.3
const DOOR_WIDTH := 1.8
const DOOR_HEIGHT := 2.4

@export var location_id: StringName = &""
@export var display_name := ""
@export var map_id: StringName = &""
@export var build_on_ready := true
@export var show_debug_labels := true

## Демо-цели пост-Кошмарной цепочки. Держим их рядом с локацией, чтобы
## сцена не зависела от отдельного режиссёра на первом этапе.
const POST_NIGHTMARE_OBJECTIVES := {
	&"police_precinct": "Очнуться в участке. Найти выход к академии.",
	&"academy_approach": "Добраться до ворот Академии Пробуждённых.",
	&"academy_gate": "Пройти проверку и войти на территорию академии.",
	&"academy_campus": "Найти корпус Sleeper Center.",
	&"academy_sleeper_center": "Пройти индукцию и лечь в капсулу.",
	&"black_sea_platform": "Осмотреть статую и найти спуск к кораллам.",
	&"tide_descent": "Спуститься к коралловому лабиринту до прилива.",
	&"coral_labyrinth": "Войти в Лабиринт Забытого берега.",
}
const GAMEPLAY_HUD_SCENE := preload("res://scenes/quests/gameplay_hud.tscn")
## Музыка/эмбиент пост-Кошмарной цепочки. Ключ — location_id, значение —
## [music_cue, ambience_zone]. Cue-таблица уже существует в AudioDirector.
const POST_NIGHTMARE_AUDIO := {
	&"police_precinct": [&"m1_precinct", &"m1_precinct"],
	&"academy_approach": [&"m1_academy", &"m1_academy"],
	&"academy_gate": [&"m1_academy", &"m1_academy"],
	&"academy_campus": [&"m1_academy", &"m1_academy"],
	&"academy_sleeper_center": [&"m1_sleeper", &"m1_sleeper"],
	&"black_sea_platform": [&"m1_black_sea", &"m1_black_sea"],
	&"tide_descent": [&"m1_descent", &"m1_descent"],
}

var _generated: Node3D
var _structure: Node3D
var _props: Node3D
var _lights: Node3D
var _labels: Node3D
var _modules: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"greybox_location")
	add_to_group(&"post_nightmare_location")
	set_meta(&"blockout", true)
	if map_id == &"":
		map_id = location_id
	if build_on_ready:
		rebuild()
	_aim_shots()
	call_deferred(&"_apply_pending_spawn")
	_setup_post_nightmare_demo()


## Только для реального запуска сцены, не для тестов: тесты добавляют
## локацию ребёнком и не должны получать второй HUD.
func _setup_post_nightmare_demo() -> void:
	if get_tree().current_scene != self:
		return
	NightmareRunState.set_flag(&"post_nightmare_started")
	var objective := String(POST_NIGHTMARE_OBJECTIVES.get(location_id, ""))
	if not objective.is_empty():
		var guide := get_node_or_null(^"/root/CampaignGuide")
		if guide != null and guide.has_method(&"set_external_objective"):
			guide.call(&"set_external_objective", objective, &"post_nightmare")
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio != null:
		var pair: Array = POST_NIGHTMARE_AUDIO.get(location_id, [])
		if pair.size() == 2:
			if audio.has_method(&"play_music"):
				audio.call(&"play_music", pair[0], 3.0)
			if audio.has_method(&"play_ambience"):
				audio.call(&"play_ambience", pair[1], 3.0)
			if audio.has_method(&"set_reverb_profile"):
				audio.call(&"set_reverb_profile", &"outdoor")
	var hud := get_node_or_null(^"GameplayHud") as CanvasLayer
	if hud == null:
		hud = GAMEPLAY_HUD_SCENE.instantiate() as CanvasLayer
		if hud != null:
			hud.name = "GameplayHud"
			hud.layer = 0
			add_child(hud)
	if hud != null:
		# Post-nightmare scenes are a continuation, not a first-time tutorial.
		hud.set(&"tutorial_enabled", false)


## Пересобрать всю сгенерированную геометрию. Безопасно вызывать в тестах.
func rebuild() -> void:
	if _generated != null and is_instance_valid(_generated):
		_generated.free()
	_generated = null
	_modules.clear()

	_generated = Node3D.new()
	_generated.name = "Generated"
	add_child(_generated)
	_structure = _make_group("Structure", _generated)
	_props = _make_group("Props", _generated)
	_lights = _make_group("Lights", _generated)
	_labels = _make_group("Labels", _generated)

	build_layout()
	layout_built.emit()


## Переопределяется наследником. Точка (0, 0, 0) — уровень пола первой комнаты.
func build_layout() -> void:
	pass


## Проигрывает линейную последовательность через DialogueRunner игрового HUD.
## Если HUD ещё не создан (тесты, прямой вызов), возвращает false.
func play_dialogue(sequence: DialogueSequence) -> bool:
	if sequence == null:
		return false
	var hud := get_node_or_null(^"GameplayHud")
	if hud == null:
		return false
	var runner := hud.get_node_or_null(^"DialogueRunner") as DialogueRunner
	if runner == null:
		return false
	runner.run(sequence)
	return true


## Запускает кат-сцену Cutscene/<stage_name>, если она есть в сцене.
## Возвращает false, чтобы вызывающий код мог откатиться на обычный диалог.
func play_cutscene(stage_name: StringName) -> bool:
	var stage := get_node_or_null(NodePath("Cutscene/%s" % String(stage_name)))
	if stage == null:
		return false
	var director := get_tree().root.get_node_or_null(^"CutsceneDirector")
	if director == null or not director.has_method(&"start_stage"):
		return false
	return bool(director.call(&"start_stage", stage))


## Refines the existing external objective; does not create a second HUD.
func set_scene_objective(text: String) -> void:
	var guide := get_node_or_null(^"/root/CampaignGuide")
	if guide != null and guide.has_method(&"set_external_objective"):
		guide.call(&"set_external_objective", text, &"post_nightmare")


func get_map_id() -> StringName:
	return map_id if map_id != &"" else location_id


func get_map_title() -> String:
	return display_name if not display_name.is_empty() else String(name)


func get_spawn(spawn: StringName) -> Node3D:
	return get_node_or_null(NodePath("Spawns/%s" % spawn)) as Node3D


func get_module(module_id: StringName) -> Node3D:
	return _modules.get(module_id, null) as Node3D


func has_module(module_id: StringName) -> bool:
	return _modules.has(module_id)


func module_count() -> int:
	return _modules.size()


## Проверка для тестов: все именованные модули существуют в дереве.
func module_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in _modules.keys():
		result.append(StringName(key))
	return result


func material(key: StringName) -> StandardMaterial3D:
	var found := MATERIALS.get(key, null) as StandardMaterial3D
	if found == null:
		push_warning("GreyboxLocation: неизвестный материал '%s', используется concrete" % key)
		return MATERIALS[&"concrete"] as StandardMaterial3D
	return found


# ---------------------------------------------------------------------------
# Каркас
# ---------------------------------------------------------------------------

## Одиночный блок. size — полные габариты; position — центр блока.
func structure(
	module_id: StringName,
	position: Vector3,
	size: Vector3,
	material_key: StringName = &"concrete",
	collision := true,
	rotation_y := 0.0
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = module_id
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = position
	mesh_instance.rotation.y = rotation_y
	_structure.add_child(mesh_instance)
	_register(module_id, mesh_instance)
	if collision:
		_add_box_collision(mesh_instance, size)
	return mesh_instance


## Комната/коридор с полом, потолком и стенами. size: x — ширина, y — высота,
## z — длина. openings — стороны (&"north", &"south", &"east", &"west") или
## словари {side, width, height, offset}. Опция open_ceiling убирает потолок.
func room(
	module_id: StringName,
	center: Vector3,
	size: Vector3,
	material_key: StringName = &"concrete",
	openings: Array = [],
	options: Dictionary = {},
	rotation_y := 0.0
) -> Node3D:
	var root := Node3D.new()
	root.name = module_id
	root.position = center
	root.rotation.y = rotation_y
	_structure.add_child(root)
	_register(module_id, root)

	var floor_material: StringName = options.get("floor_material", material_key)
	var wall_material: StringName = options.get("wall_material", material_key)
	var ceiling_material: StringName = options.get("ceiling_material", wall_material)
	var thickness: float = options.get("wall_thickness", WALL_THICKNESS)
	var door_width: float = options.get("door_width", DOOR_WIDTH)
	var door_height: float = options.get("door_height", DOOR_HEIGHT)

	_box_child(root, &"Floor", Vector3(0, -0.25, 0), Vector3(size.x, 0.5, size.z), floor_material, true)
	if not bool(options.get("open_ceiling", false)):
		_box_child(root, &"Ceiling", Vector3(0, size.y + 0.15, 0), Vector3(size.x, 0.3, size.z), wall_material, false)

	_build_wall(root, &"north", size, thickness, openings, wall_material, door_width, door_height)
	_build_wall(root, &"south", size, thickness, openings, wall_material, door_width, door_height)
	_build_wall(root, &"west", size, thickness, openings, wall_material, door_width, door_height)
	_build_wall(root, &"east", size, thickness, openings, wall_material, door_width, door_height)
	return root


func corridor(
	module_id: StringName,
	center: Vector3,
	width: float,
	length: float,
	height: float = 3.0,
	material_key: StringName = &"concrete",
	openings: Array = [&"north", &"south"],
	options: Dictionary = {},
	rotation_y := 0.0
) -> Node3D:
	return room(module_id, center, Vector3(width, height, length), material_key, openings, options, rotation_y)


## Круглая площадка. Верхняя поверхность на y = 0.
func platform(
	module_id: StringName,
	center: Vector3,
	radius: float,
	height: float,
	material_key: StringName = &"concrete",
	with_rings := false
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = module_id
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 48
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = center + Vector3(0, -height * 0.5, 0)
	_structure.add_child(mesh_instance)
	_register(module_id, mesh_instance)
	_add_cylinder_collision(mesh_instance, radius, height)
	if with_rings:
		for i in 3:
			var ring := MeshInstance3D.new()
			ring.name = "Groove%d" % i
			var torus := TorusMesh.new()
			torus.inner_radius = radius * (0.32 + 0.17 * i)
			torus.outer_radius = radius * (0.325 + 0.17 * i)
			torus.rings = 48
			torus.ring_segments = 6
			ring.mesh = torus
			ring.material_override = material(&"concrete_dark")
			ring.position = Vector3(0, 0.01, 0)
			mesh_instance.add_child(ring)
	return mesh_instance


## Лестница, поднимающаяся в локальную сторону -Z. start — низ первой ступени.
func stairs(
	module_id: StringName,
	start: Vector3,
	width: float,
	step_height: float,
	step_depth: float,
	steps: int,
	material_key: StringName = &"concrete",
	rotation_y := 0.0
) -> Node3D:
	var root := Node3D.new()
	root.name = module_id
	root.position = start
	root.rotation.y = rotation_y
	_structure.add_child(root)
	_register(module_id, root)
	for i in steps:
		var step_top := step_height * (i + 1)
		var box_size := Vector3(width, step_top, step_depth)
		var box_pos := Vector3(0, step_top * 0.5, -step_depth * (i + 0.5))
		_box_child(root, StringName("Step%d" % i), box_pos, box_size, material_key, true)
	return root


## Наклонная плита. center — центр плиты, rise — перепад по -Z.
func ramp(
	module_id: StringName,
	center: Vector3,
	width: float,
	run: float,
	rise: float,
	thickness: float = 0.3,
	material_key: StringName = &"concrete",
	rotation_y := 0.0
) -> MeshInstance3D:
	var length := sqrt(run * run + rise * rise)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = module_id
	var box := BoxMesh.new()
	box.size = Vector3(width, thickness, length)
	mesh_instance.mesh = box
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = center
	mesh_instance.rotation = Vector3(-atan2(rise, run), rotation_y, 0.0)
	_structure.add_child(mesh_instance)
	_register(module_id, mesh_instance)
	_add_box_collision(mesh_instance, box.size)
	return mesh_instance


## Невидимая стена/граница. Не даёт выйти за пределы прототипа.
func boundary(module_id: StringName, center: Vector3, size: Vector3, rotation_y := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = module_id
	body.position = center
	body.rotation.y = rotation_y
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_structure.add_child(body)
	_register(module_id, body)
	return body


## Перила: стойки и две перекладины. Без коллизии — границу задаёт boundary().
func railing(
	module_id: StringName,
	start: Vector3,
	length: float,
	rotation_y := 0.0,
	height := 1.1
) -> Node3D:
	var root := Node3D.new()
	root.name = module_id
	root.position = start
	root.rotation.y = rotation_y
	_structure.add_child(root)
	_register(module_id, root)
	var posts := maxi(2, int(ceil(length / 2.0)) + 1)
	for i in posts:
		var z := -length * float(i) / float(posts - 1)
		_prop_cylinder(root, StringName("Post%d" % i), Vector3(0, height * 0.5, z), 0.035, height, &"metal_light", 10)
	_prop_box(root, &"RailTop", Vector3(0, height, -length * 0.5), Vector3(0.06, 0.06, length), &"metal_light")
	_prop_box(root, &"RailMid", Vector3(0, height * 0.55, -length * 0.5), Vector3(0.05, 0.05, length), &"metal_light")
	return root


# ---------------------------------------------------------------------------
# Свет и подписи
# ---------------------------------------------------------------------------

func omni(
	light_id: StringName,
	position: Vector3,
	color: Color = Color(1, 0.95, 0.85, 1),
	energy := 2.0,
	range_m := 8.0,
	shadows := false
) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = light_id
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.shadow_enabled = shadows
	_lights.add_child(light)
	_register(light_id, light)
	return light


func spot(
	light_id: StringName,
	position: Vector3,
	target: Vector3,
	color: Color = Color(0.9, 0.95, 1, 1),
	energy := 4.0,
	range_m := 30.0,
	angle_deg := 35.0,
	shadows := false
) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.name = light_id
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.spot_range = range_m
	light.spot_angle = angle_deg
	light.shadow_enabled = shadows
	_lights.add_child(light)
	var direction := target - position
	var up := Vector3.UP
	if direction.length_squared() > 0.0001 and absf(direction.normalized().dot(Vector3.UP)) > 0.999:
		up = Vector3.FORWARD
	light.look_at(target, up)
	_register(light_id, light)
	return light


func label(
	label_id: StringName,
	position: Vector3,
	text: String,
	color: Color = Color(0.85, 0.9, 1, 0.9),
	font_size := 42,
	rotation_y := 0.0
) -> Label3D:
	var node := Label3D.new()
	node.name = label_id
	node.position = position
	node.text = text
	node.font_size = font_size
	node.outline_size = 8
	node.modulate = color
	node.outline_modulate = Color(0, 0, 0, 0.8)
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = true
	node.rotation.y = rotation_y
	node.visible = show_debug_labels
	_labels.add_child(node)
	_register(label_id, node)
	return node


# ---------------------------------------------------------------------------
# Реквизит
# ---------------------------------------------------------------------------

func prop_box(
	prop_id: StringName,
	position: Vector3,
	size: Vector3,
	material_key: StringName = &"metal_dark",
	rotation_y := 0.0,
	collision := false
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = prop_id
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = position
	mesh_instance.rotation.y = rotation_y
	_props.add_child(mesh_instance)
	_register(prop_id, mesh_instance)
	if collision:
		_add_box_collision(mesh_instance, size)
	return mesh_instance


func prop_cylinder(
	prop_id: StringName,
	position: Vector3,
	radius: float,
	height: float,
	material_key: StringName = &"metal_dark",
	segments := 16,
	rotation := Vector3.ZERO,
	collision := false
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = prop_id
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = segments
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = position
	mesh_instance.rotation = rotation
	_props.add_child(mesh_instance)
	_register(prop_id, mesh_instance)
	if collision:
		_add_cylinder_collision(mesh_instance, radius, height)
	return mesh_instance


func prop_sphere(
	prop_id: StringName,
	position: Vector3,
	radius: float,
	material_key: StringName = &"metal_dark",
	segments := 16
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = prop_id
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = segments
	sphere.rings = maxi(4, int(segments * 0.5))
	mesh_instance.mesh = sphere
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = position
	_props.add_child(mesh_instance)
	_register(prop_id, mesh_instance)
	return mesh_instance


func prop_cone(
	prop_id: StringName,
	position: Vector3,
	radius: float,
	height: float,
	material_key: StringName = &"metal_dark",
	segments := 12,
	rotation := Vector3.ZERO
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = prop_id
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = segments
	mesh_instance.mesh = cone
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = position
	mesh_instance.rotation = rotation
	_props.add_child(mesh_instance)
	_register(prop_id, mesh_instance)
	return mesh_instance


## Кровать: медицинская или обычная койка.
func bed(prop_id: StringName, position: Vector3, rotation_y := 0.0, medical := true) -> Node3D:
	var root := _prop_root(prop_id, position, rotation_y)
	var frame_material := &"metal_light" if medical else &"wood_dark"
	var mattress_material := &"fabric_blue" if medical else &"fabric_grey"
	_prop_box(root, &"Frame", Vector3(0, 0.32, 0), Vector3(2.05, 0.22, 0.95), frame_material)
	_prop_box(root, &"Mattress", Vector3(0, 0.5, 0), Vector3(1.95, 0.16, 0.85), mattress_material)
	_prop_box(root, &"Pillow", Vector3(-0.72, 0.62, 0), Vector3(0.42, 0.12, 0.55), &"white")
	_prop_box(root, &"Headboard", Vector3(-1.08, 0.65, 0), Vector3(0.08, 0.9, 0.95), frame_material)
	if medical:
		_prop_box(root, &"RailL", Vector3(0.25, 0.78, -0.48), Vector3(1.2, 0.06, 0.05), &"metal_light")
		_prop_box(root, &"RailR", Vector3(0.25, 0.78, 0.48), Vector3(1.2, 0.06, 0.05), &"metal_light")
		_prop_cylinder(root, &"MonitorPole", Vector3(0.95, 0.9, 0.32), 0.025, 1.8, &"metal_light", 8)
		_prop_box(root, &"Monitor", Vector3(0.95, 1.8, 0.32), Vector3(0.05, 0.35, 0.5), &"metal_dark")
		_prop_box(root, &"MonitorScreen", Vector3(0.91, 1.8, 0.32), Vector3(0.01, 0.25, 0.38), &"screen_cyan")
	return root


func chair(prop_id: StringName, position: Vector3, rotation_y := 0.0, material_key: StringName = &"metal_dark") -> Node3D:
	var root := _prop_root(prop_id, position, rotation_y)
	_prop_box(root, &"Seat", Vector3(0, 0.45, 0), Vector3(0.5, 0.06, 0.5), material_key)
	_prop_box(root, &"Back", Vector3(0, 0.75, 0.23), Vector3(0.5, 0.55, 0.06), material_key)
	_prop_box(root, &"LegL", Vector3(-0.2, 0.22, 0), Vector3(0.05, 0.45, 0.42), material_key)
	_prop_box(root, &"LegR", Vector3(0.2, 0.22, 0), Vector3(0.05, 0.45, 0.42), material_key)
	return root


func bench(prop_id: StringName, position: Vector3, length := 2.0, rotation_y := 0.0) -> Node3D:
	var root := _prop_root(prop_id, position, rotation_y)
	_prop_box(root, &"Seat", Vector3(0, 0.45, 0), Vector3(length, 0.08, 0.42), &"wood_light")
	_prop_box(root, &"Back", Vector3(0, 0.78, 0.2), Vector3(length, 0.3, 0.06), &"wood_light")
	_prop_box(root, &"LegL", Vector3(-length * 0.4, 0.22, 0), Vector3(0.08, 0.45, 0.38), &"metal_dark")
	_prop_box(root, &"LegR", Vector3(length * 0.4, 0.22, 0), Vector3(0.08, 0.45, 0.38), &"metal_dark")
	return root


func table(prop_id: StringName, position: Vector3, size := Vector2(1.6, 0.9), rotation_y := 0.0) -> Node3D:
	var root := _prop_root(prop_id, position, rotation_y)
	_prop_box(root, &"Top", Vector3(0, 0.75, 0), Vector3(size.x, 0.08, size.y), &"wood_light")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_prop_box(
				root,
				StringName("Leg%d%d" % [int(sx), int(sz)]),
				Vector3(sx * (size.x * 0.5 - 0.12), 0.37, sz * (size.y * 0.5 - 0.1)),
				Vector3(0.07, 0.74, 0.07),
				&"metal_dark"
			)
	return root


func locker(prop_id: StringName, position: Vector3, rotation_y := 0.0, width := 0.8) -> Node3D:
	var root := _prop_root(prop_id, position, rotation_y)
	_prop_box(root, &"Body", Vector3(0, 0.95, 0), Vector3(width, 1.9, 0.5), &"metal_dark")
	_prop_box(root, &"Door", Vector3(0, 0.95, 0.26), Vector3(width - 0.08, 1.76, 0.03), &"metal_light")
	_prop_box(root, &"Handle", Vector3(width * 0.34, 1.0, 0.3), Vector3(0.04, 0.18, 0.04), &"metal_dark")
	_prop_box(root, &"Vent", Vector3(0, 1.62, 0.28), Vector3(width - 0.25, 0.05, 0.02), &"metal_dark")
	return root


func shower_stall(prop_id: StringName, position: Vector3, rotation_y := 0.0) -> Node3D:
	var root := _prop_root(prop_id, position, rotation_y)
	_prop_box(root, &"Back", Vector3(0, 1.2, 0.6), Vector3(1.0, 2.4, 0.05), &"tile")
	_prop_box(root, &"SideL", Vector3(-0.5, 1.2, 0), Vector3(0.05, 2.4, 1.2), &"tile")
	_prop_box(root, &"SideR", Vector3(0.5, 1.2, 0), Vector3(0.05, 2.4, 1.2), &"tile")
	_prop_cylinder(root, &"Pipe", Vector3(0, 2.1, 0.45), 0.025, 0.55, &"metal_light", 8)
	_prop_cylinder(root, &"Head", Vector3(0, 1.85, 0.5), 0.11, 0.05, &"metal_light", 12, Vector3(1.57, 0, 0))
	_prop_box(root, &"Drain", Vector3(0, 0.01, 0), Vector3(0.28, 0.02, 0.28), &"metal_dark")
	return root


func sink(prop_id: StringName, position: Vector3, rotation_y := 0.0) -> Node3D:
	var root := _prop_root(prop_id, position, rotation_y)
	_prop_box(root, &"Cabinet", Vector3(0, 0.42, 0), Vector3(0.7, 0.85, 0.45), &"white")
	_prop_box(root, &"Basin", Vector3(0, 0.88, 0), Vector3(0.75, 0.12, 0.5), &"metal_light")
	_prop_cylinder(root, &"Faucet", Vector3(0, 1.02, 0.16), 0.02, 0.28, &"metal_light", 8)
	_prop_box(root, &"MirrorFrame", Vector3(0, 1.6, 0.23), Vector3(0.72, 0.9, 0.05), &"metal_dark")
	_prop_box(root, &"Mirror", Vector3(0, 1.6, 0.26), Vector3(0.64, 0.8, 0.01), &"mirror")
	return root


func counter(prop_id: StringName, position: Vector3, size := Vector2(4.0, 0.8), rotation_y := 0.0) -> Node3D:
	var root := _prop_root(prop_id, position, rotation_y)
	_prop_box(root, &"Base", Vector3(0, 0.55, 0), Vector3(size.x, 1.1, size.y), &"metal_light")
	_prop_box(root, &"Top", Vector3(0, 1.12, 0), Vector3(size.x + 0.12, 0.08, size.y + 0.12), &"white")
	_prop_box(root, &"Front", Vector3(0, 0.55, size.y * 0.5 + 0.02), Vector3(size.x - 0.2, 0.8, 0.04), &"metal_dark")
	return root


func vending(prop_id: StringName, position: Vector3, rotation_y := 0.0) -> Node3D:
	var root := _prop_root(prop_id, position, rotation_y)
	_prop_box(root, &"Body", Vector3(0, 1.1, 0), Vector3(1.1, 2.2, 0.75), &"metal_red")
	_prop_box(root, &"Window", Vector3(0, 1.35, 0.39), Vector3(0.8, 1.1, 0.02), &"glass_blue")
	_prop_box(root, &"Screen", Vector3(0, 0.45, 0.39), Vector3(0.7, 0.28, 0.02), &"screen_cyan")
	_prop_box(root, &"Slot", Vector3(0.3, 0.18, 0.39), Vector3(0.25, 0.08, 0.03), &"black")
	return root


func capsule(prop_id: StringName, position: Vector3, rotation_y := 0.0) -> Node3D:
	var root := _prop_root(prop_id, position, rotation_y)
	_prop_box(root, &"Base", Vector3(0, 0.18, 0), Vector3(1.1, 0.36, 2.3), &"metal_dark")
	_prop_box(root, &"Body", Vector3(0, 0.72, 0), Vector3(1.0, 0.72, 2.15), &"metal_light")
	_prop_box(root, &"Lid", Vector3(0, 1.15, 0), Vector3(1.02, 0.12, 2.18), &"glass_blue")
	_prop_box(root, &"Light", Vector3(0, 1.22, 0.95), Vector3(0.16, 0.04, 0.16), &"screen_cyan")
	return root


func hollow_chair(prop_id: StringName, position: Vector3, rotation_y := 0.0) -> Node3D:
	var root := _prop_root(prop_id, position, rotation_y)
	_prop_box(root, &"Seat", Vector3(0, 0.45, 0), Vector3(0.6, 0.08, 0.6), &"fabric_grey")
	_prop_box(root, &"Back", Vector3(0, 0.9, 0.26), Vector3(0.6, 0.8, 0.08), &"fabric_grey")
	_prop_cylinder(root, &"Torso", Vector3(0, 0.85, 0), 0.18, 0.55, &"hollow", 10)
	_prop_sphere(root, &"Head", Vector3(0, 1.22, 0), 0.13, &"hollow", 10)
	_prop_box(root, &"ArmL", Vector3(-0.3, 0.7, 0), Vector3(0.06, 0.5, 0.1), &"hollow")
	_prop_box(root, &"ArmR", Vector3(0.3, 0.7, 0), Vector3(0.06, 0.5, 0.1), &"hollow")
	return root


func turret(prop_id: StringName, position: Vector3, rotation_y := 0.0, scale_factor := 1.0) -> Node3D:
	var root := _prop_root(prop_id, position, rotation_y)
	_prop_cylinder(root, &"Base", Vector3(0, 0.35 * scale_factor, 0), 0.7 * scale_factor, 0.7 * scale_factor, &"metal_dark", 12)
	_prop_box(root, &"Housing", Vector3(0, 1.05 * scale_factor, 0), Vector3(1.1, 0.75, 1.3) * scale_factor, &"metal_light")
	_prop_box(root, &"BarrelL", Vector3(-0.22, 1.1 * scale_factor, -0.9 * scale_factor), Vector3(0.1, 0.1, 1.5) * scale_factor, &"metal_dark")
	_prop_box(root, &"BarrelR", Vector3(0.22, 1.1 * scale_factor, -0.9 * scale_factor), Vector3(0.1, 0.1, 1.5) * scale_factor, &"metal_dark")
	_prop_box(root, &"Sensor", Vector3(0, 1.45 * scale_factor, 0), Vector3(0.18, 0.12, 0.18) * scale_factor, &"red_glow")
	return root


func coral_cluster(prop_id: StringName, position: Vector3, height := 4.0, seed_value := 1) -> Node3D:
	var root := _prop_root(prop_id, position, 0.0)
	_rng.seed = seed_value
	var branches := _rng.randi_range(3, 6)
	for i in branches:
		var angle := _rng.randf_range(0.0, TAU)
		var radius := _rng.randf_range(0.0, height * 0.16)
		var branch_height := height * _rng.randf_range(0.45, 1.0)
		var branch_radius := _rng.randf_range(0.12, 0.32)
		var local := Vector3(cos(angle) * radius, branch_height * 0.5, sin(angle) * radius)
		var material_key := &"coral" if i % 3 != 0 else &"coral_pale"
		_prop_cylinder(root, StringName("Branch%d" % i), local, branch_radius, branch_height, material_key, 8)
		if i % 2 == 0:
			_prop_cone(
				root,
				StringName("Tip%d" % i),
				local + Vector3(0, branch_height * 0.55, 0),
				branch_radius * 0.9,
				branch_height * 0.35,
				material_key,
				8
			)
	return root


func bone(prop_id: StringName, position: Vector3, length := 2.0, rotation := Vector3.ZERO) -> Node3D:
	var root := _prop_root(prop_id, position, 0.0)
	_prop_cylinder(root, &"Shaft", Vector3(0, 0, 0), 0.08, length, &"bone", 8, rotation)
	# Концы считаются по полному базису поворота, иначе шарики не совпадают
	# с цилиндром при наклоне по Z (горизонтальные рёбра).
	var offset := Basis.from_euler(rotation) * Vector3(0, length * 0.5, 0)
	_prop_sphere(root, &"EndA", offset, 0.16, &"bone", 8)
	_prop_sphere(root, &"EndB", -offset, 0.16, &"bone", 8)
	return root


func fire_pit(prop_id: StringName, position: Vector3, radius := 1.2) -> Node3D:
	var root := _prop_root(prop_id, position, 0.0)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		_prop_cylinder(
			root,
			StringName("Stone%d" % i),
			Vector3(cos(angle) * radius, 0.14, sin(angle) * radius),
			0.22,
			0.28,
			&"concrete_dark",
			8
		)
	_prop_cylinder(root, &"LogA", Vector3(0, 0.22, 0), 0.09, 1.1, &"wood_dark", 8, Vector3(0, 0, 1.2))
	_prop_cylinder(root, &"LogB", Vector3(0, 0.22, 0), 0.09, 1.1, &"wood_dark", 8, Vector3(0, 0, -1.2))
	_prop_cone(root, &"Flame", Vector3(0, 0.7, 0), 0.35, 1.0, &"fire", 8)
	omni(StringName("%sLight" % prop_id), position + Vector3(0, 1.2, 0), Color(1, 0.55, 0.2, 1), 3.2, 12.0, false)
	return root


func statue_star(prop_id: StringName, position: Vector3, radius := 0.5) -> Node3D:
	var root := _prop_root(prop_id, position, 0.0)
	for i in 5:
		var angle := TAU * float(i) / 5.0 - PI * 0.5
		_prop_box(
			root,
			StringName("Ray%d" % i),
			Vector3(cos(angle) * radius * 0.5, sin(angle) * radius * 0.5, 0),
			Vector3(radius * 0.85, 0.08, 0.08),
			&"strip",
			0.0
		)
		root.get_child(i).rotation.z = angle
	return root


func terminal(prop_id: StringName, position: Vector3, rotation_y := 0.0) -> Node3D:
	var root := _prop_root(prop_id, position, rotation_y)
	_prop_box(root, &"Base", Vector3(0, 0.45, 0), Vector3(0.75, 0.9, 0.5), &"metal_dark")
	_prop_box(root, &"Screen", Vector3(0, 1.02, 0.0), Vector3(0.8, 0.55, 0.06), &"metal_dark")
	_prop_box(root, &"Glow", Vector3(0, 1.02, 0.035), Vector3(0.68, 0.43, 0.01), &"screen_cyan")
	return root


# ---------------------------------------------------------------------------
# Внутренние помощники
# ---------------------------------------------------------------------------

func _make_group(group_name: String, parent: Node3D) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	parent.add_child(node)
	return node


func _register(module_id: StringName, node: Node3D) -> void:
	if module_id == &"":
		push_warning("GreyboxLocation: модуль без id (%s)" % node.get_path())
		return
	if _modules.has(module_id):
		push_warning("GreyboxLocation: повторный id модуля '%s'" % module_id)
	_modules[module_id] = node


func _box_child(
	parent: Node3D,
	child_name: StringName,
	local_position: Vector3,
	size: Vector3,
	material_key: StringName,
	collision: bool
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = child_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = local_position
	parent.add_child(mesh_instance)
	if collision:
		_add_box_collision(mesh_instance, size)
	return mesh_instance


func _add_box_collision(parent: Node3D, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body


func _add_cylinder_collision(parent: Node3D, radius: float, height: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	body.add_child(shape)
	parent.add_child(body)
	return body


func _build_wall(
	room_root: Node3D,
	side: StringName,
	room_size: Vector3,
	thickness: float,
	openings: Array,
	material_key: StringName,
	default_width: float,
	default_height: float
) -> void:
	var length := room_size.x if side == &"north" or side == &"south" else room_size.z
	var intervals: Array = []
	for entry in openings:
		var spec := _opening_spec(entry, side, default_width, default_height)
		if spec.is_empty():
			continue
		var width: float = spec.get("width", default_width)
		var opening_height: float = minf(float(spec.get("height", default_height)), room_size.y)
		var offset: float = spec.get("offset", 0.0)
		var start := maxf(-length * 0.5, offset - width * 0.5)
		var end := minf(length * 0.5, offset + width * 0.5)
		if end - start < 0.2:
			continue
		intervals.append({"start": start, "end": end, "height": opening_height})
	intervals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.start) < float(b.start))

	var cursor := -length * 0.5
	for interval in intervals:
		var start: float = interval.start
		var end: float = interval.end
		if start > cursor + 0.01:
			_wall_piece(room_root, side, room_size, cursor, start, room_size.y * 0.5, room_size.y, thickness, material_key)
		var opening_height: float = interval.height
		if opening_height < room_size.y - 0.05:
			var lintel_height := room_size.y - opening_height
			_wall_piece(
				room_root,
				side,
				room_size,
				start,
				end,
				opening_height + lintel_height * 0.5,
				lintel_height,
				thickness,
				material_key
			)
		cursor = maxf(cursor, end)
	if cursor < length * 0.5 - 0.01:
		_wall_piece(room_root, side, room_size, cursor, length * 0.5, room_size.y * 0.5, room_size.y, thickness, material_key)


func _opening_spec(entry: Variant, side: StringName, default_width: float, default_height: float) -> Dictionary:
	if entry is StringName or entry is String:
		if StringName(entry) == side:
			return {"width": default_width, "height": default_height, "offset": 0.0}
		return {}
	if entry is Dictionary:
		var entry_side := StringName(entry.get("side", &""))
		if entry_side != side:
			return {}
		return {
			"width": float(entry.get("width", default_width)),
			"height": float(entry.get("height", default_height)),
			"offset": float(entry.get("offset", 0.0)),
		}
	return {}


func _wall_piece(
	room_root: Node3D,
	side: StringName,
	room_size: Vector3,
	start: float,
	end: float,
	y_center: float,
	height: float,
	thickness: float,
	material_key: StringName
) -> void:
	var span := end - start
	if span <= 0.01 or height <= 0.01:
		return
	if side == &"north" or side == &"south":
		var z := -room_size.z * 0.5 if side == &"north" else room_size.z * 0.5
		_box_child(
			room_root,
			&"Wall",
			Vector3((start + end) * 0.5, y_center, z),
			Vector3(span, height, thickness),
			material_key,
			true
		)
	else:
		var x := -room_size.x * 0.5 if side == &"west" else room_size.x * 0.5
		_box_child(
			room_root,
			&"Wall",
			Vector3(x, y_center, (start + end) * 0.5),
			Vector3(thickness, height, span),
			material_key,
			true
		)


func _prop_root(prop_id: StringName, position: Vector3, rotation_y := 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = prop_id
	root.position = position
	root.rotation.y = rotation_y
	_props.add_child(root)
	_register(prop_id, root)
	return root


func _prop_box(
	parent: Node3D,
	child_name: StringName,
	local_position: Vector3,
	size: Vector3,
	material_key: StringName,
	rotation_y := 0.0
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = child_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = local_position
	mesh_instance.rotation.y = rotation_y
	parent.add_child(mesh_instance)
	return mesh_instance


func _prop_cylinder(
	parent: Node3D,
	child_name: StringName,
	local_position: Vector3,
	radius: float,
	height: float,
	material_key: StringName,
	segments := 12,
	rotation := Vector3.ZERO
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = child_name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = segments
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = local_position
	mesh_instance.rotation = rotation
	parent.add_child(mesh_instance)
	return mesh_instance


func _prop_sphere(
	parent: Node3D,
	child_name: StringName,
	local_position: Vector3,
	radius: float,
	material_key: StringName,
	segments := 12
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = child_name
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = segments
	sphere.rings = maxi(4, int(segments * 0.5))
	mesh_instance.mesh = sphere
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = local_position
	parent.add_child(mesh_instance)
	return mesh_instance


func _prop_cone(
	parent: Node3D,
	child_name: StringName,
	local_position: Vector3,
	radius: float,
	height: float,
	material_key: StringName,
	segments := 12,
	rotation := Vector3.ZERO
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = child_name
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = segments
	mesh_instance.mesh = cone
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = local_position
	mesh_instance.rotation = rotation
	parent.add_child(mesh_instance)
	return mesh_instance


## Ракурсы в сцене: у каждой Camera3D ищется цель LookAt. Цель — отдельный
## Marker3D рядом с камерой (Shots/<Camera>Target) либо дочерний LookAt.
## Это избавляет от ручного расчёта базисов и не зависит от поворота камеры.
func _aim_shots() -> void:
	var shots := get_node_or_null(^"Shots")
	if shots == null:
		return
	for child in shots.get_children():
		var camera := child as Camera3D
		if camera == null:
			continue
		var target := shots.get_node_or_null(NodePath("%sTarget" % camera.name)) as Node3D
		if target == null:
			target = camera.get_node_or_null(^"LookAt") as Node3D
		if target == null:
			continue
		var direction := target.global_position - camera.global_position
		if direction.length_squared() < 0.0001:
			continue
		var up := Vector3.UP
		if absf(direction.normalized().dot(Vector3.UP)) > 0.999:
			up = Vector3.FORWARD
		camera.look_at(target.global_position, up)


func _apply_pending_spawn() -> void:
	var path := scene_file_path
	if path.is_empty():
		return
	var pending := LevelPortal.take_pending_spawn(path)
	if pending == &"":
		return
	var spawn := get_spawn(pending)
	if spawn == null:
		push_warning("GreyboxLocation: нет Spawns/%s в %s" % [pending, path])
		return
	var player := get_tree().get_first_node_in_group(&"player") as SunnyController
	if player != null:
		player.global_position = spawn.global_position
		# Поворот Marker3D задаёт направление продолжения пути. Без этого
		# игрок после перехода смотрел бы в старую сторону, и стык читался бы
		# как телепорт, даже если позиция совпадает с дверью.
		player.apply_spawn_orientation(spawn.global_rotation.y)
