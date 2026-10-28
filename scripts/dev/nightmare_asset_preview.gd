extends Node3D
## Изолированная сцена осмотра ассетов Первого Кошмара (инструмент проверки, не игровой путь).
##
## Загружает все .glb набора (`assets/environments/nightmare/<папки>`), печатает отчёт импорта
## (меши, материалы, цвет вершин, коллизии, габариты), собирает отрезок перевала из модулей
## и ряды остальных ассетов, ставит манекен 1,75 м. Состояние кампании не трогает.
##
## Захват кадров и выход:
##   godot --path . res://scenes/dev/nightmare_asset_preview.tscn -- --capture=<абсолютная папка>

const ROOT := "res://assets/environments/nightmare/"
const DIRS := ["mountain", "caravan", "remains", "flora", "temple", "trail"]
## Дальний план не ставится в ряд — уходит за сцену как фон.
const BACKDROP := {"black_mountain_far": Vector3(-600.0, -60.0, -2600.0), "mountain_range_far": Vector3(900.0, -80.0, -1900.0)}
## Сборка отрезка перевала: Blender (x, y, z) → Godot (x, z, −y). Те же позиции, что в build_mountain_kit.py.
const DIORAMA := [
	["road_old_01", Vector3(0, 0, 0)], ["road_old_02_ice", Vector3(0, 0, -4)],
	["road_old_03_step", Vector3(0, 0, -8)], ["road_old_01", Vector3(0, 0.2, -12)],
	["rock_wall_a", Vector3(1.3, 0, 0)], ["rock_overhang_b", Vector3(1.3, 0, -5.4)], ["rock_wall_b", Vector3(1.3, 0, -10.8)],
	["cliff_edge_a1", Vector3(0, 0, 0)], ["cliff_edge_collapsed_b", Vector3(0, 0, -5)],
	["cliff_edge_a2", Vector3(0, 0, -10)], ["cliff_edge_a1", Vector3(0, 0, -15)],
	["snow_drift_wall_b", Vector3(0.9, 0, -3.2)], ["scree_pile_a", Vector3(0.7, 0.15, -9.6)],
	["boulder_angular_a", Vector3(0.2, 0.2, -12.5)], ["snow_drift_low_a", Vector3(-0.6, 0, -6.0)],
	["boulder_split_a", Vector3(1.0, 0.2, -14.8)],
]

var _scenes := {}
var _dir_of := {}
var _shots: Array[Camera3D] = []


func _ready() -> void:
	_load_all()
	_build_diorama()
	_build_camp(Vector3(40.0, 0.0, 0.0))
	_build_temple(Vector3(100.0, 0.0, 0.0))
	_build_trail(Vector3(150.0, 0.0, 0.0))
	_build_rows(Vector3(-60.0, 0.0, 140.0))
	_place_backdrop()
	var capture := _arg("--capture=")
	if capture != "":
		_capture(capture)


func _arg(prefix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return ""


func _load_all() -> void:
	for d: String in DIRS:
		var dir := DirAccess.open(ROOT + d)
		if dir == null:
			continue
		for f: String in dir.get_files():
			if not f.ends_with(".glb"):
				continue
			var path := ROOT + d + "/" + f
			var scene := load(path) as PackedScene
			if scene == null:
				push_error("NM_PREVIEW load failed: " + path)
				continue
			_scenes[f.get_basename()] = scene
			_dir_of[f.get_basename()] = d
			_report(path, scene)


func _report(path: String, scene: PackedScene) -> void:
	var inst := scene.instantiate()
	var meshes := 0
	var tris := 0
	var colors := true
	var mats := {}
	var shapes := 0
	for n in inst.find_children("*", "", true, false):
		if n is MeshInstance3D:
			meshes += 1
			var mesh: Mesh = n.mesh
			for s in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(s)
				tris += arr[Mesh.ARRAY_INDEX].size() / 3 if arr[Mesh.ARRAY_INDEX] != null else 0
				colors = colors and arr[Mesh.ARRAY_COLOR] != null
				var m := mesh.surface_get_material(s)
				mats[m.resource_path.get_file() if m and m.resource_path != "" else "EMBEDDED:" + (m.resource_name if m else "none")] = true
		elif n is CollisionShape3D:
			shapes += 1
	print("NM_PREVIEW %s meshes=%d tris=%d vertex_colors=%s collision_shapes=%d materials=%s" % [
		path.get_file(), meshes, tris, colors, shapes, ",".join(mats.keys())])
	inst.free()


func _spawn(name: String, pos: Vector3, yaw_deg := 0.0) -> Node3D:
	if not _scenes.has(name):
		return null
	var inst := (_scenes[name] as PackedScene).instantiate() as Node3D
	add_child(inst)
	inst.position = pos
	inst.rotation_degrees.y = yaw_deg
	return inst


func _aabb(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = n.global_transform * (n as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _build_diorama() -> void:
	for item: Array in DIORAMA:
		_spawn(item[0], item[1])
	_mannequin(Vector3(-0.2, 0, -6.5))
	_shot(Vector3(-0.3, 1.6, 2.0), Vector3(0.4, 1.3, -12.0), 62.0)
	_shot(Vector3(-9.0, 6.0, 4.0), Vector3(0.6, -1.0, -8.0), 55.0)


## Стоянка каравана (канон гл. 2–3): площадка-расширение дороги, выступ скалы от ветра,
## повозка боком на верхнем конце — передом к стене, задом к обрыву, клинья под задними
## колёсами, цепь от повозки, костёр в центре, Bloodbane на границе мостовой и камней.
func _build_camp(o: Vector3) -> void:
	if not _scenes.has("wagon_cargo"):
		return
	# Площадка 8 × 12 м (по −Z), дорога подходит и уходит дальше вверх.
	if _scenes.has("camp_platform_a"):
		_spawn("camp_platform_a", o)
	_spawn("road_old_01", o + Vector3(0, 0, 4.0))
	_spawn("road_old_02_ice", o + Vector3(0, 0, -12.0))
	for i in 4:
		_spawn("cliff_edge_a1" if i % 2 == 0 else "cliff_edge_a2", o + Vector3(-2.2, 0, -5.0 * i + 2.0))
	_spawn("rock_wall_a", o + Vector3(4.1, 0, 1.0))
	_spawn("rock_overhang_b", o + Vector3(4.1, 0, -5.0))
	_spawn("rock_wall_b", o + Vector3(4.1, 0, -10.5))
	_spawn("snow_drift_wall_b", o + Vector3(3.5, 0, 0.5))
	# Повозка боком на верхнем конце: перед (−Z модели) к стене (+X), задние колёса у обрыва.
	_spawn("wagon_cargo", o + Vector3(-0.9, 0, -10.6), -90.0)
	for side in [-1.0, 1.0]:
		_spawn("wheel_chock", o + Vector3(-2.05 - 0.55, 0, -10.6 + side * 0.98), -90.0)
	_spawn("chain_main_slack", o + Vector3(-1.6, 0.0, -7.4), 15.0)
	_spawn("campfire_large", o + Vector3(0.4, 0.0, -5.0))
	_spawn("firewood_bundle", o + Vector3(1.9, 0.0, -3.6), 40.0)
	_spawn("barrel_water_a", o + Vector3(2.6, 0.0, -8.8))
	_spawn("sack_grain_a", o + Vector3(2.2, 0.0, -9.6), 30.0)
	_spawn("bloodbane_bush_a", o + Vector3(-3.2, 0.0, -1.0))
	_spawn("bloodbane_bush_b", o + Vector3(-2.9, 0.0, -2.0), 70.0)
	_spawn("bloodbane_bush_c", o + Vector3(3.1, 0.0, -1.4), 20.0)
	_mannequin(o + Vector3(0.6, 0, -2.0))
	_shot(o + Vector3(0.4, 1.6, 3.4), o + Vector3(-0.9, 0.9, -10.6), 62.0)
	_shot(o + Vector3(-11.0, 10.0, 5.0), o + Vector3(0.0, 0.0, -6.0), 55.0)


## Зал храма из модулей (как hall_diorama в build_temple_kit.py; Blender (x, y, z) → Godot (x, z, −y)).
func _build_temple(o: Vector3) -> void:
	if not _scenes.has("altar_black_marble"):
		return
	var z0 := 6 * 0.22
	_spawn("stairs_a", o + Vector3(0, 0, 7.3))
	for x in [-6.0, -2.0, 2.0, 6.0]:
		_spawn("floor_a", o + Vector3(x, z0, 4.0))
	var px := [-8.75, -5.25, -1.75, 1.75, 5.25, 8.75]
	for k in px.size():
		_spawn("column_broken_a" if k == 4 else "column_intact", o + Vector3(px[k], z0, 3.0))
	for x in [-6.0, 0.0]:
		_spawn("entablature_a", o + Vector3(x, z0 + 9.95, 3.0))
	var fx := [-6.0, -2.0, 2.0, 6.0]
	for i in fx.size():
		for j in 7:
			_spawn("floor_b" if (i + j) % 3 == 0 else "floor_a", o + Vector3(fx[i], z0, -4.0 * j))
	_spawn("portal_frame", o + Vector3(0, z0, 0))
	_spawn("gate_broken", o + Vector3(-1.5, z0, -0.6))
	var cy := [3.0, 8.0, 13.0, 18.0, 23.0]
	for k in cy.size():
		for sx in [-1, 1]:
			var n := "column_intact"
			if (k == 1 and sx == 1) or (k == 3 and sx == -1):
				n = "column_broken_a"
			if k == 2 and sx == 1:
				n = "column_broken_b"
			_spawn(n, o + Vector3(sx * 5.0, z0, -cy[k]))
	_spawn("column_fallen", o + Vector3(4.2, z0, -13.5), 75.0)
	var wy := [3.0, 9.0, 15.0, 21.0]
	for k in wy.size():
		for sx in [-1, 1]:
			var ruined: bool = (k + (1 if sx > 0 else 0)) % 3 == 0
			_spawn("wall_block_ruined" if ruined else "wall_block_intact", o + Vector3(sx * 8.7, z0, -wy[k]))
			if not ((k == 1 and sx == 1) or (k == 2 and sx == 1)):
				_spawn("entablature_a", o + Vector3(sx * 5.0, z0 + 9.95, -wy[k]), 90.0)
	for x in [-6.0, 0.0, 6.0]:
		_spawn("wall_block_intact", o + Vector3(x, z0, -26.6), 90.0)
	_spawn("wall_block_intact", o + Vector3(-5.6, z0, 0.2), 90.0)
	_spawn("wall_block_ruined", o + Vector3(5.6, z0, 0.2), 90.0)
	_spawn("pediment_fragment", o + Vector3(-0.5, z0 + 12.85, 3.3))
	var roof_z := z0 + 12.85
	for y in [1.3, 3.7, 10.9, 13.3, 20.5]:
		_spawn("roof_slab_a", o + Vector3(0, roof_z, -y), 90.0)
	for item: Array in [[-1, 3.0], [-1, 15.0], [1, 9.0], [1, 21.0]]:
		_spawn("roof_slab_a", o + Vector3(item[0] * 6.9, roof_z, -item[1]))
	for item: Array in [[-1.5, 8.0, 0.0], [2.4, 15.5, 30.0], [-3.9, 19.5, 60.0]]:
		_spawn("roof_rubble_a", o + Vector3(item[0], z0, -item[1]), item[2])
	_spawn("relief_panel_figure", o + Vector3(-7.95, z0 + 1.0, -23.5), 90.0)
	_spawn("relief_panel_geometric", o + Vector3(7.95, z0 + 1.0, -23.5), -90.0)
	_spawn("altar_black_marble", o + Vector3(0, z0, -23.6))
	_spawn("bones_pile_c", o + Vector3(-3.5, 0, 9.0))
	_spawn("bones_pile_c", o + Vector3(3.8, 0, 9.8), 120.0)
	_spawn("bones_monster_a", o + Vector3(7.5, 0, 10.5), 40.0)
	_spawn("bones_scatter_b", o + Vector3(0.5, 0, 11.5))
	_mannequin(o + Vector3(0.8, z0, -20.5))
	_shot(o + Vector3(0.9, z0 + 1.65, -13.0), o + Vector3(0, z0 + 0.8, -23.6), 70.0)
	_shot(o + Vector3(-22.0, 8.0, 30.0), o + Vector3(0, 6.0, -6.0), 55.0)


## Подъём от разрушенной дороги (гл. 9–12): обрыв дороги, крутой склон, тропа паломников со
## ступенями, узкий выступ, альков; отдельно — щель с пещерой. Blender (x, y, z) → Godot (x, z, −y).
func _build_trail(o: Vector3) -> void:
	if not _scenes.has("trail_pilgrim_01"):
		return
	for z in [8.0, 4.0]:
		_spawn("road_old_01", o + Vector3(0, 0, z))
	_spawn("road_old_broken_end", o)
	_spawn("cliff_edge_a1", o + Vector3(0, 0, 4.0))
	_spawn("rock_wall_a", o + Vector3(1.3, 0, 7.5))
	# Склон от правой кромки дороги вверх к +X (поворот −90°: «вперёд» модели −Z → +X).
	_spawn("slope_steep_a", o + Vector3(1.3, 0, -1.5), -90.0)
	var top := Vector3(9.2, 5.45, 1.5)
	_spawn("trail_pilgrim_01", o + top)
	# Ниже по маршруту — выступ, за которым Герой оставляет Учёного (E3.5); карман за ним не виден с тропы.
	_spawn("trail_pilgrim_03_spur", o + top + Vector3(0, 0, 6.0))
	_spawn("ice_flow_a", o + top + Vector3(0.95, 0.0, -3.2))
	_spawn("trail_pilgrim_02_steps", o + top + Vector3(0, 0, -6.0))
	_spawn("ledge_narrow", o + top + Vector3(0.4, 1.1, -12.0))
	_spawn("alcove_shelter", o + top + Vector3(0.9, 1.1, -21.6))
	_spawn("icicles_b", o + top + Vector3(0.75, 1.1 + 2.0, -22.9))
	_mannequin(o + Vector3(-0.2, 0, 1.0))
	_mannequin(o + top + Vector3(0.3, 1.1, -14.0))
	_shot(o + Vector3(-7.5, 3.2, -7.5), o + Vector3(3.0, 2.0, 0.0), 62.0)
	_shot(o + top + Vector3(-0.2, 1.65, 0.6), o + top + Vector3(0.6, 2.0, -20.0), 62.0)
	_shot(o + top + Vector3(-9.0, 4.0, -12.0), o + top + Vector3(1.0, 1.0, -18.0), 55.0)
	_shot(o + top + Vector3(-0.35, 1.62, 0.6), o + top + Vector3(0.15, 1.0, 4.8), 55.0)
	# Щель за высокими камнями и пещера (на своей площадке, вне тени склона): снаружи и изнутри.
	var cave := o + Vector3(25.0, 0, 25.0)
	_ground(cave + Vector3(2.0, -0.02, 0), 30.0)
	_spawn("cave_crevice", cave)
	_mannequin(cave + Vector3(-2.0, 0, 1.0))
	_shot(cave + Vector3(-9.0, 2.2, 5.0), cave + Vector3(1.0, 1.5, 0.0), 55.0)
	_shot(cave + Vector3(8.4, 1.4, -0.5), cave + Vector3(4.0, 1.2, 0.0), 75.0)


func _ground(pos: Vector3, size: float) -> void:
	var m := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	m.mesh = plane
	m.material_override = load(ROOT + "materials/nm_snow.tres")
	add_child(m)
	m.position = pos


## Ряды по папкам набора, не длиннее ROW_MAX м (общий ряд в 300 м тонул в тумане): у каждого
## ряда свой пол и свой кадр; ряды разнесены по Z, чтобы соседний не заслонял кадр.
const ROW_MAX := 60.0
const ROW_STEP := 60.0


func _build_rows(origin: Vector3) -> void:
	var skip := BACKDROP.keys()
	var names := _scenes.keys()
	names.sort()
	var row: Array[String] = []
	var z := origin.z
	for d: String in DIRS:
		for name: String in names:
			if name in skip or _dir_of[name] != d:
				continue
			row.append(name)
		var x := origin.x
		for i in row.size():
			var inst := _row_item(row[i], x, z)
			x += _aabb(inst).size.x + 1.2
			if x - origin.x > ROW_MAX or i == row.size() - 1:
				_row_finish(origin.x, x, z)
				x = origin.x
				z += ROW_STEP
		row.clear()


func _row_item(name: String, x: float, z: float) -> Node3D:
	# Стены и кромки — лицом к камере ряда (их лицо смотрит в −X).
	var face := name.begins_with("rock_wall") or name.begins_with("rock_overhang") or name.begins_with("cliff_edge")
	var inst := _spawn(name, Vector3(x, 0, z), 90.0 if face else 0.0)
	inst.position.x += x - _aabb(inst).position.x
	return inst


func _row_finish(x0: float, x1: float, z: float) -> void:
	_mannequin(Vector3(x1 + 0.5, 0, z + 1.0))
	var span := x1 - x0
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(span + 30.0, 50.0)
	ground.mesh = plane
	ground.material_override = load(ROOT + "materials/nm_snow.tres")
	add_child(ground)
	ground.position = Vector3((x0 + x1) * 0.5, -0.02, z)
	_shot(Vector3((x0 + x1) * 0.5, maxf(3.0, span * 0.2), z + maxf(8.0, span * 0.8)),
			Vector3((x0 + x1) * 0.5, 1.5, z), 45.0)


func _place_backdrop() -> void:
	for name: String in BACKDROP:
		_spawn(name, BACKDROP[name])


func _mannequin(pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.17
	cap.height = 1.75
	m.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.45, 0.38)
	m.material_override = mat
	add_child(m)
	m.position = pos + Vector3(0, 0.875, 0)


func _shot(from: Vector3, to: Vector3, fov: float) -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = from
	cam.look_at(to)
	cam.fov = fov
	cam.far = 6000.0
	_shots.append(cam)
	if _shots.size() == 1:
		cam.current = true


func _capture(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for i in _shots.size():
		_shots[i].current = true
		for _f in 30:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var path := folder.path_join("godot_nightmare_preview_%d.png" % i)
		img.save_png(path)
		print("NM_PREVIEW captured ", path)
	get_tree().quit()
