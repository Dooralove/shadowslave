class_name LabyrinthGreybox
extends GreyboxLocation
## Общий строитель greybox-локаций Лабиринта.
##
## Отличается от GreyboxLocation тем, что визуальная геометрия и коллизии
## лежат в разных контейнерах:
##   Generated/Visual/<Zone>     — меши, которые заменит Claude;
##   Generated/Collision/<Zone>  — StaticBody3D, которые переживут замену арта;
##   Generated/Lights/<Zone>     — временный свет;
##   Generated/Labels/<Zone>     — отладочные подписи.
##
## Игровые точки (Spawns, Portals, Shots, Markers, Gameplay, Landmarks, Tide)
## живут в .tscn и никогда не пересобираются этим скриптом. Поэтому rebuild()
## безопасен для логики и маркеров.

const BOUNDARY_LAYER := 32
const TIDE_GATE_GROUP := &"tide_gate"

var _collision: Node3D
var _zone_visual: Dictionary = {}
var _zone_collision: Dictionary = {}
var _zone_lights: Dictionary = {}
var _zone_labels: Dictionary = {}
var _col_index := 0


func rebuild() -> void:
	if _generated != null and is_instance_valid(_generated):
		_generated.free()
	_generated = null
	_modules.clear()
	_zone_visual.clear()
	_zone_collision.clear()
	_zone_lights.clear()
	_zone_labels.clear()
	_col_index = 0

	_generated = Node3D.new()
	_generated.name = "Generated"
	add_child(_generated)
	_structure = _make_group("Visual", _generated)
	_props = _make_group("VisualProps", _generated)
	_lights = _make_group("Lights", _generated)
	_labels = _make_group("Labels", _generated)
	_collision = _make_group("Collision", _generated)

	build_layout()
	layout_built.emit()


# ---------------------------------------------------------------------------
# Группы по зонам
# ---------------------------------------------------------------------------

func zone_visual(zone: StringName) -> Node3D:
	var key := String(zone)
	if _zone_visual.has(key):
		return _zone_visual[key] as Node3D
	var node := Node3D.new()
	node.name = key
	_structure.add_child(node)
	_zone_visual[key] = node
	return node


func zone_collision(zone: StringName) -> Node3D:
	var key := String(zone)
	if _zone_collision.has(key):
		return _zone_collision[key] as Node3D
	var node := Node3D.new()
	node.name = key
	_collision.add_child(node)
	_zone_collision[key] = node
	return node


func zone_lights(zone: StringName) -> Node3D:
	var key := String(zone)
	if _zone_lights.has(key):
		return _zone_lights[key] as Node3D
	var node := Node3D.new()
	node.name = key
	_lights.add_child(node)
	_zone_lights[key] = node
	return node


func zone_labels(zone: StringName) -> Node3D:
	var key := String(zone)
	if _zone_labels.has(key):
		return _zone_labels[key] as Node3D
	var node := Node3D.new()
	node.name = key
	_labels.add_child(node)
	_zone_labels[key] = node
	return node


# ---------------------------------------------------------------------------
# Простая геометрия
# ---------------------------------------------------------------------------

func box(
	zone: StringName,
	id: StringName,
	center: Vector3,
	size: Vector3,
	material_key: StringName = &"coral",
	rotation_y := 0.0,
	collision := true
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = id
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = center
	mesh_instance.rotation.y = rotation_y
	# Art layer reads these values to replace the primitive without touching
	# the collision. Kept as metadata so the greybox remains self-contained.
	mesh_instance.set_meta(&"art_center", center)
	mesh_instance.set_meta(&"art_size", size)
	mesh_instance.set_meta(&"art_rotation_y", rotation_y)
	mesh_instance.set_meta(&"art_material", String(material_key))
	zone_visual(zone).add_child(mesh_instance)
	_register(StringName("%s/%s" % [zone, id]), mesh_instance)
	if collision:
		_add_collision_box(zone, id, center, size, rotation_y, material_key)
	return mesh_instance


func cyl(
	zone: StringName,
	id: StringName,
	center: Vector3,
	radius: float,
	height: float,
	material_key: StringName = &"coral",
	rotation := Vector3.ZERO,
	collision := false,
	segments := 8,
	top_scale := 1.0
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = id
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * top_scale
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = segments
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = center
	mesh_instance.rotation = rotation
	mesh_instance.set_meta(&"art_center", center)
	mesh_instance.set_meta(&"art_size", Vector3(radius * 2.0, height, radius * 2.0))
	mesh_instance.set_meta(&"art_rotation_y", 0.0)
	mesh_instance.set_meta(&"art_material", String(material_key))
	zone_visual(zone).add_child(mesh_instance)
	_register(StringName("%s/%s" % [zone, id]), mesh_instance)
	if collision:
		_add_collision_cylinder(zone, id, center, radius, height, rotation)
	return mesh_instance


func floor_zone(
	zone: StringName,
	id: StringName,
	center_xz: Vector2,
	size_xz: Vector2,
	top_y: float,
	material_key: StringName = &"mud"
) -> MeshInstance3D:
	var thickness := 0.6
	return box(
		zone,
		id,
		Vector3(center_xz.x, top_y - thickness * 0.5, center_xz.y),
		Vector3(size_xz.x, thickness, size_xz.y),
		material_key,
		0.0,
		true
	)


func floor_between(
	zone: StringName,
	id: StringName,
	a: Vector2,
	b: Vector2,
	width: float,
	top_y: float,
	material_key: StringName = &"mud"
) -> MeshInstance3D:
	var dx := b.x - a.x
	var dz := b.y - a.y
	var length := sqrt(dx * dx + dz * dz)
	var center := Vector3((a.x + b.x) * 0.5, top_y - 0.3, (a.y + b.y) * 0.5)
	var rot_y := atan2(-dz, dx)
	return box(zone, id, center, Vector3(length, 0.6, width), material_key, rot_y, true)


func wall_segment(
	zone: StringName,
	id: StringName,
	a: Vector2,
	b: Vector2,
	base_y: float,
	height: float,
	thickness := 2.0,
	material_key: StringName = &"coral"
) -> void:
	var dx := b.x - a.x
	var dz := b.y - a.y
	var length := sqrt(dx * dx + dz * dz)
	if length < 0.1:
		return
	var center := Vector3((a.x + b.x) * 0.5, base_y + height * 0.5, (a.y + b.y) * 0.5)
	var rot_y := atan2(-dz, dx)
	box(zone, id, center, Vector3(length, height, thickness), material_key, rot_y, true)


func coral_mass(
	zone: StringName,
	id: StringName,
	base_center: Vector3,
	size: Vector3,
	material_key: StringName = &"coral",
	seed_value := 1
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 3:
		var offset := Vector3(
			rng.randf_range(-size.x * 0.22, size.x * 0.22),
			0.0,
			rng.randf_range(-size.z * 0.22, size.z * 0.22)
		)
		var part_size := Vector3(
			size.x * rng.randf_range(0.6, 0.9),
			size.y * rng.randf_range(0.7, 1.0),
			size.z * rng.randf_range(0.6, 0.9)
		)
		var part := box(
			zone,
			StringName("%s_%d" % [id, i]),
			base_center + offset + Vector3(0, part_size.y * 0.5, 0),
			part_size,
			material_key,
			rng.randf_range(-0.28, 0.28),
			true
		)
		part.rotation.x = rng.randf_range(-0.05, 0.05)
		# The three overlapping boxes are one art mass. The art layer replaces
		# the group with one or more organic modules using this footprint.
		part.set_meta(&"art_mass_group", String(id))
		part.set_meta(&"art_mass_base", base_center)
		part.set_meta(&"art_mass_size", size)
		part.set_meta(&"art_mass_seed", seed_value)


## Лестница из горизонтальных ступеней. start — низ, end — верх.
## Для спуска вызывать с низкой точкой первой, чтобы rise был положительным.
## Вертикальные связки сделаны пологими рампами, а не ступенями:
## стандартный CharacterBody3D Санни не умеет автоматически шагать на 0,25 м,
## и телепорт-тесты это маскировали. Рампа проверена реальным движением.
## step_height сохранён в сигнатуре для совместимости вызовов.
func stairs_between(
	zone: StringName,
	id: StringName,
	start: Vector3,
	end: Vector3,
	width: float,
	_step_height := 0.25,
	material_key: StringName = &"statue"
) -> void:
	var delta := end - start
	var run := Vector2(delta.x, delta.z).length()
	var rise := delta.y
	if run < 0.1 or absf(rise) < 0.02:
		floor_between(zone, id, Vector2(start.x, start.z), Vector2(end.x, end.z), width, start.y, material_key)
		return
	var thickness := 0.3
	var length := sqrt(run * run + rise * rise)
	var rot_y := atan2(-delta.x, -delta.z)
	# local -Z смотрит от start к end; положительный pitch поднимает end.
	var pitch := atan2(rise, run)
	var center := (start + end) * 0.5 - Vector3(0.0, thickness * 0.5 * cos(pitch), 0.0)
	var rotation := Vector3(pitch, rot_y, 0.0)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = id
	var ramp_mesh := BoxMesh.new()
	ramp_mesh.size = Vector3(width, thickness, length)
	mesh_instance.mesh = ramp_mesh
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = center
	mesh_instance.rotation = rotation
	mesh_instance.set_meta(&"art_center", center)
	mesh_instance.set_meta(&"art_size", ramp_mesh.size)
	mesh_instance.set_meta(&"art_rotation_y", rot_y)
	mesh_instance.set_meta(&"art_material", String(material_key))
	mesh_instance.set_meta(&"art_role", "ramp")
	zone_visual(zone).add_child(mesh_instance)
	_register(StringName("%s/%s" % [zone, id]), mesh_instance)

	_col_index += 1
	var body := StaticBody3D.new()
	body.name = "Col_%s_%d" % [id, _col_index]
	body.position = center
	body.rotation = rotation
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta(&"surface", _surface_for_material(material_key))
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = ramp_mesh.size
	shape.shape = box_shape
	body.add_child(shape)
	zone_collision(zone).add_child(body)

	# Боковые парапеты намеренно не генерируются: автоматические стенки
	# перекрывали площадки на концах рамп и делали связки непроходимыми.
	# Открытые края — временный blockout-компромисс; Claude добавит парапеты
	# вручную, не затрагивая проходимую поверхность.


func zone_boundary(zone: StringName, id: StringName, center: Vector3, size: Vector3, rotation_y := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Boundary_%s" % id
	body.position = center
	body.rotation.y = rotation_y
	body.collision_layer = BOUNDARY_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	zone_collision(zone).add_child(body)
	return body


## Невидимый шлюз, который TideController включает при высокой воде.
func tide_gate(zone: StringName, id: StringName, center: Vector3, size: Vector3, rotation_y := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "TideGate_%s" % id
	body.position = center
	body.rotation.y = rotation_y
	body.collision_layer = 0
	body.collision_mask = 0
	body.add_to_group(TIDE_GATE_GROUP)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.disabled = true
	body.add_child(shape)
	zone_collision(zone).add_child(body)
	return body


# ---------------------------------------------------------------------------
# Свет и подписи
# ---------------------------------------------------------------------------

func zone_omni(
	zone: StringName,
	id: StringName,
	position: Vector3,
	color: Color = Color(1, 0.95, 0.85, 1),
	energy := 1.2,
	range_m := 18.0,
	shadows := false
) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = id
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.shadow_enabled = shadows
	zone_lights(zone).add_child(light)
	return light


func zone_label(
	zone: StringName,
	id: StringName,
	position: Vector3,
	text: String,
	color: Color = Color(0.85, 0.9, 1, 0.9),
	font_size := 24
) -> Label3D:
	var node := Label3D.new()
	node.name = id
	node.position = position
	node.text = text
	node.font_size = font_size
	node.outline_size = 6
	node.modulate = color
	node.outline_modulate = Color(0, 0, 0, 0.8)
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = false
	node.visible = show_debug_labels
	zone_labels(zone).add_child(node)
	return node


# ---------------------------------------------------------------------------
# Служебное
# ---------------------------------------------------------------------------

func _add_collision_box(
	zone: StringName,
	id: StringName,
	center: Vector3,
	size: Vector3,
	rotation_y: float,
	material_key: StringName = &"coral"
) -> void:
	_col_index += 1
	var body := StaticBody3D.new()
	body.name = "Col_%s_%d" % [id, _col_index]
	body.position = center
	body.rotation.y = rotation_y
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta(&"surface", _surface_for_material(material_key))
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	zone_collision(zone).add_child(body)


func _add_collision_cylinder(
	zone: StringName,
	id: StringName,
	center: Vector3,
	radius: float,
	height: float,
	rotation: Vector3
) -> void:
	_col_index += 1
	var body := StaticBody3D.new()
	body.name = "Col_%s_%d" % [id, _col_index]
	body.position = center
	body.rotation = rotation
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder_shape := CylinderShape3D.new()
	cylinder_shape.radius = radius
	cylinder_shape.height = height
	shape.shape = cylinder_shape
	body.add_child(shape)
	zone_collision(zone).add_child(body)


func _surface_for_material(material_key: StringName) -> StringName:
	match material_key:
		&"mud":
			return &"mud"
		&"bone":
			return &"bone"
		&"coral", &"coral_pale":
			return &"coral"
		&"wood", &"wood_dark":
			return &"wood"
		&"metal", &"iron":
			return &"metal"
		_:
			return &"stone"


func clear_landmark(landmark_name: StringName) -> Node3D:
	var node := get_node_or_null(NodePath("Landmarks/%s" % landmark_name)) as Node3D
	if node != null:
		for child in node.get_children():
			child.free()
	return node
