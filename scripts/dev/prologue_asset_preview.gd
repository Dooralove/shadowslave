extends "res://scripts/dev/nightmare_asset_preview.gd"
## Изолированная сцена осмотра ассетов пролога (партия 5): бокс изолятора, угол лобби, деревья и фонари
## парка, ряды моделей. Инструмент проверки, не игровой путь: сюжетные сцены и состояние кампании не трогает.
## Общие помощники (_report, _spawn, _aabb, _mannequin, _shot, _capture) — из сцены осмотра Первого Кошмара.
##
## Захват кадров и выход:
##   godot --path . res://scenes/dev/prologue_asset_preview.tscn -- --capture=<абсолютная папка>
##
## Раскладка — как в `assets/environments/prologue/source/build_prologue_kit.py`: Blender (x, y, z) →
## Godot (x, z, −y), поворот вокруг вертикали тот же.

const PR_DIRS := ["res://assets/environments/prologue/cell/", "res://assets/environments/prologue/lobby/"]
const PARK_PROPS := "res://assets/environments/park/props/"
const ROW_ORDER := ["cell", "lobby", "park"]

var _group := {}


func _ready() -> void:
	for d: String in PR_DIRS:
		_load_dir(d, d.get_base_dir().get_file())
	_load_dir(PARK_PROPS, "park")
	_build_cell(Vector3.ZERO)
	_build_lobby(Vector3(30.0, 0.0, 0.0))
	_build_park(Vector3(80.0, 0.0, 0.0))
	_build_pr_rows(Vector3(-20.0, 0.0, 80.0))
	var capture := _arg("--capture=")
	if capture != "":
		_capture(capture)


func _load_dir(path: String, group: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("NM_PREVIEW no dir: " + path)
		return
	for f: String in dir.get_files():
		if not f.ends_with(".glb"):
			continue
		var scene := load(path + f) as PackedScene
		if scene == null:
			push_error("NM_PREVIEW load failed: " + path + f)
			continue
		_scenes[f.get_basename()] = scene
		_group[f.get_basename()] = group
		_report(path + f, scene)


func _omni(pos: Vector3, energy: float, rng: float, color: Color, shadow := true) -> void:
	var l := OmniLight3D.new()
	l.light_energy = energy
	l.omni_range = rng
	l.light_color = color
	l.shadow_enabled = shadow
	add_child(l)
	l.position = pos


## Бокс 3,6 × 4,4 × 2,45 м (бриф изолятора §3): дверь у z = +2,2, смотровое стекло на дальней стене (z = −2,2).
func _build_cell(o: Vector3) -> void:
	if not _scenes.has("restraint_chair"):
		return
	_spawn("cell_floor", o)
	_spawn("cell_ceiling", o)
	_spawn("cell_wall_panel_a", o + Vector3(-1.25, 0, -2.2))
	_spawn("cell_wall_window", o + Vector3(0, 0, -2.2))
	_spawn("cell_wall_panel_b", o + Vector3(1.25, 0, -2.2))
	var left := ["cell_wall_panel_a", "cell_wall_panel_c", "cell_wall_panel_a", "cell_wall_panel_b"]
	var right := ["cell_wall_panel_c", "cell_wall_panel_a", "cell_wall_panel_c", "cell_wall_panel_a"]
	for k in 4:
		_spawn(left[k], o + Vector3(-1.8, 0, 1.65 - 1.1 * k), 90.0)
		_spawn(right[k], o + Vector3(1.8, 0, 1.65 - 1.1 * k), -90.0)
	_spawn("cell_wall_panel_a", o + Vector3(-1.25, 0, 2.2), 180.0)
	for c: Array in [[Vector3(-1.8, 0, -2.2), 0.0], [Vector3(1.8, 0, -2.2), -90.0], [Vector3(1.8, 0, 2.2), 180.0],
			[Vector3(-1.8, 0, 2.2), 90.0]]:
		_spawn("cell_corner", o + c[0], c[1])
	_spawn("cell_door_frame", o + Vector3(0, 0, 2.2), 180.0)
	_spawn("cell_wall_panel_c", o + Vector3(1.25, 0, 2.2), 180.0)
	_spawn("vault_door", o + Vector3(0.555, 0.01, 2.30), 180.0)
	_spawn("restraint_chair", o + Vector3(-0.45, 0, -0.20))
	_spawn("cell_terminal", o + Vector3(1.78, 0, 1.35), -90.0)
	_spawn("vent_grille", o + Vector3(1.25, 2.16, -2.18))
	_spawn("ceiling_light_cell", o + Vector3(-0.45, 2.45, -0.35))
	_spawn("cell_power_box", o + Vector3(-1.78, 0, 1.1), 90.0)
	_spawn("cell_ceiling_hatch", o + Vector3(0.7, 2.45, -1.4))
	_spawn("cell_camera", o + Vector3(-1.5, 2.45, -1.9), -135.0)
	# Свет дезинфекции — холодный, сверху; слабая заливка у двери (бриф §7, состояние A).
	# Пост наблюдения за стеклом (только превью): тусклое помещение и холодный прямоугольник света (бриф Z3).
	var post := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.6, 2.45, 2.0)
	box.flip_faces = true
	post.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.13, 0.14)
	post.material_override = mat
	add_child(post)
	post.position = o + Vector3(0, 1.225, -3.45)
	_omni(o + Vector3(0.4, 2.0, -3.6), 0.35, 3.0, Color(0.75, 0.82, 0.9), false)
	_omni(o + Vector3(-0.45, 2.25, -0.35), 1.6, 5.0, Color(0.78, 0.9, 0.92))
	_omni(o + Vector3(0.8, 2.2, 1.6), 0.25, 4.0, Color(0.7, 0.75, 0.8), false)
	_shot(o + Vector3(1.55, 1.75, 2.05), o + Vector3(-0.55, 0.75, -0.9), 62.0)
	_shot(o + Vector3(-0.45, 1.16, -0.98), o + Vector3(-0.3, 1.85, 1.6), 46.0)
	_shot(o + Vector3(-1.55, 1.9, -1.95), o + Vector3(0.2, 1.0, 2.0), 62.0)


## Угол лобби (габариты CSG 12 × 12 × 4 м): бронеплиты на северной стене, стойка с терминалом, турели в углах.
func _build_lobby(o: Vector3) -> void:
	if not _scenes.has("desk_counter"):
		return
	var room := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(12.0, 4.0, 12.0)
	box.flip_faces = true
	room.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.22, 0.24)
	mat.roughness = 0.8
	room.material_override = mat
	add_child(room)
	room.position = o + Vector3(0, 2.0, 0)
	var plates := [["armor_plate_a", -4.3], ["armor_plate_b", -2.25], ["armor_plate_a", -0.2], ["armor_plate_a", 2.6]]
	for item: Array in plates:
		_spawn(item[0], o + Vector3(item[1], 0, -6.0))
	_spawn("desk_counter", o + Vector3(0, 0, -3.0))
	_spawn("terminal_desk", o + Vector3(0.9, 0.76, -3.15), 180.0)
	_spawn("turret_nest_a", o + Vector3(-5.4, 4.0, -5.4), 45.0)
	_spawn("turret_nest_a", o + Vector3(5.4, 4.0, -5.4), -45.0)
	_spawn("ceiling_light_lobby", o + Vector3(0, 4.0, -2.0), 90.0)
	_spawn("ceiling_light_lobby", o + Vector3(0, 4.0, 2.5), 90.0)
	_spawn("door_station_entrance", o + Vector3(0, 0, 6.0), 180.0)
	for p: Vector3 in [Vector3(0, 3.6, -2.0), Vector3(0, 3.6, 2.5), Vector3(-3.5, 3.6, -4.2), Vector3(3.5, 3.6, -4.2)]:
		_omni(o + p, 1.4, 9.0, Color(0.9, 0.95, 1.0))
	_mannequin(o + Vector3(-0.8, 0, -1.2))
	_shot(o + Vector3(0.4, 1.65, 4.6), o + Vector3(-0.2, 1.5, -3.5), 50.0)
	_shot(o + Vector3(2.6, 1.6, -2.6), o + Vector3(5.3, 3.75, -5.3), 38.0)


## Парк: деревья в кадках и фонари на местах блок-аута (`build_park_blockout.py`, координаты Godot).
func _build_park(o: Vector3) -> void:
	if not _scenes.has("tree_planter_a"):
		return
	var lawn := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 30.0)
	lawn.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.5, 0.44)
	mat.roughness = 0.7
	lawn.material_override = mat
	add_child(lawn)
	lawn.position = o + Vector3(0, -0.01, 0)
	var trees := [[-6.2, 4.8, 1.0, "a"], [5.9, 5.6, 1.1, "b"], [-4.0, 6.2, 0.8, "c"], [-6.6, -2.6, 1.05, "a"],
		[6.8, -2.2, 0.95, "c"]]
	for t: Array in trees:
		var inst := _spawn("tree_planter_" + t[3], o + Vector3(t[0], 0, t[1]))
		if inst:
			inst.scale = Vector3.ONE * float(t[2])
	for x: float in [-6.5, 6.5]:
		_spawn("lamp_street_a", o + Vector3(x, 0, -7.25), 180.0)
	_spawn("bench", o + Vector3(0.6, 0, 3.6))
	_mannequin(o + Vector3(-1.2, 0, 2.0))
	_shot(o + Vector3(0.0, 1.7, -9.0), o + Vector3(0.0, 2.0, 4.0), 55.0)


## Ряды по группам (бокс, лобби, парк), не длиннее ROW_MAX; потолочные и настенные модели (начало у потолка или
## на стене) поднимаются над полом ряда.
func _build_pr_rows(origin: Vector3) -> void:
	var names := _scenes.keys()
	names.sort()
	var z := origin.z
	for g: String in ROW_ORDER:
		var x := origin.x
		var count := 0
		for name: String in names:
			if _group.get(name, "") != g:
				continue
			var inst := _spawn(name, Vector3(x, 0, z))
			var box := _aabb(inst)
			inst.position.x += x - box.position.x
			if box.position.y < -0.01:
				inst.position.y -= box.position.y
			x += box.size.x + 0.8
			count += 1
		if count == 0:
			continue
		_row_finish(origin.x, x, z)
		z += ROW_STEP
