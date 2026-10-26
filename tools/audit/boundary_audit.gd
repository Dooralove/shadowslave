extends SceneTree
## Аудит границ локаций. Только читает сцены: загружает локацию с физикой, заливкой лучей проходит
## всю площадь, куда Санни может дойти пешком от точек Spawns/*, и ищет:
##  - смертельные края: шаг в сторону без стены, а под ногами пусто или обрыв глубже fall_limit;
##  - смертельные прыжки: стена ниже высоты прыжка, за ней обрыв (там, где прыжок разрешён);
##  - «призрачный пол»: у такого края видна модель, но коллизии под ней нет (выглядит как дорога);
##  - висящие объекты: модель без опоры под собой и без соседей.
## Результат — отчёт Markdown и карта PNG на локацию (север, -Z, сверху).
##
## С --write-boundary инструмент ещё и пишет <сцена>_boundary.tscn: невидимые стены по каждому
## смертельному краю на слое boundary (игрок упирается, камера проходит). Старая граница
## (узел AuditBoundary) при этом убирается до заливки, поэтому результат воспроизводим.
##
## Запуск из корня проекта:
##   godot --headless --path . -s tools/audit/boundary_audit.gd -- --out=<папка> [--scene=res://...tscn] [--step=0.5] [--jump=0|1] [--write-boundary]

const DEFAULT_SCENES := [
	"res://scenes/slice/locations/caravan_road_art.tscn",
	"res://scenes/locations/caravan_site/caravan_site_art.tscn",
	"res://scenes/locations/pilgrim_path/pilgrim_path_art.tscn",
	"res://scenes/locations/shadow_sanctuary/shadow_sanctuary_art.tscn",
	"res://scenes/slice/locations/mountain_vision_art.tscn",
]
## Мир и границы — то, во что упирается тело Санни (collision_mask 37 без слоя врагов).
const WORLD_MASK := 1 | 32
## Как в SunnyController: шаг выше — стена, уклон круче — склон, по которому не пройти.
const MAX_STEP_UP := 0.45
const MIN_FLOOR_NORMAL_Y := 0.7
## Падение глубже — смерть (FallRecovery.fall_limit).
const FALL_LIMIT := 10.0
const KNEE := 0.6
## Высота прыжка Санни (jump_velocity 5 м/с) — около 1,27 м; стену ниже этого он перепрыгивает.
const JUMP_CLEAR := 1.1
const MAX_CELLS := 400000
## Модели крупнее — фон (горы, небо), они не опора и не «висящий мусор».
const BACKDROP_SIZE := 60.0
## Обёртки этих локаций запрещают прыжок (allow_jump = false).
const NO_JUMP := ["caravan_road_art", "caravan_site_art", "pilgrim_path_art", "shadow_sanctuary_art", "mountain_vision_art"]
## Слой 6 «boundary» (project.godot): его видит тело Санни, но не пружина камеры.
const BOUNDARY_LAYER := 32
const BOUNDARY_NODE := "AuditBoundary"
const WALL_HEIGHT := 3.0
const WALL_THICKNESS := 0.3

var _step := 0.5
var _out_dir := ""
## -1 — по сцене (NO_JUMP), 0/1 — принудительно для всех сцен.
var _jump_override := -1
var _write_boundary := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scenes: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--scene="):
			scenes.append(arg.trim_prefix("--scene="))
		elif arg.begins_with("--jump="):
			_jump_override = int(arg.trim_prefix("--jump="))
		elif arg == "--write-boundary":
			_write_boundary = true
		elif arg.begins_with("--step="):
			_step = float(arg.trim_prefix("--step="))
	if _out_dir.is_empty():
		push_error("boundary_audit: нужен --out=<папка>")
		quit(2)
		return
	if scenes.is_empty():
		scenes = DEFAULT_SCENES
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var report := PackedStringArray(["# Аудит границ локаций", "", "Шаг сетки: %.2f м. Смертельное падение: > %.0f м." % [_step, FALL_LIMIT], ""])
	for path in scenes:
		report.append_array(await _audit(path))
	var file := FileAccess.open(_out_dir.path_join("boundary_audit.md"), FileAccess.WRITE)
	file.store_string("\n".join(report))
	file.close()
	print("boundary_audit: отчёт в ", _out_dir)
	quit(0)


func _audit(path: String) -> PackedStringArray:
	var packed := load(path) as PackedScene
	if packed == null:
		return PackedStringArray(["## %s" % path, "", "Не загружается.", ""])
	var scene := packed.instantiate()
	var old_boundary := scene.get_node_or_null(BOUNDARY_NODE)
	if _write_boundary and old_boundary:
		old_boundary.free()
	root.add_child(scene)
	for i in 4:
		await physics_frame
	var space := (scene as Node3D).get_world_3d().direct_space_state

	var visuals := _visual_bounds(scene)
	var seeds := _seeds(scene)
	var jump := not NO_JUMP.has(path.get_file().get_basename()) if _jump_override < 0 else _jump_override == 1
	var flood := _flood(space, seeds, jump)
	var floating := _floating(space, scene, visuals)

	var ghost: Array[Vector3] = []
	var ghost_sources := {}
	var lethal: Array[Vector3] = flood.lethal
	for point in lethal:
		var source := _covering_visual(point, visuals)
		if not source.is_empty():
			ghost.append(point)
			ghost_sources[source] = ghost_sources.get(source, 0) + 1

	var map_name := path.get_file().get_basename()
	_draw_map(map_name, flood, ghost, floating, seeds)
	var boundary_boxes := -1
	if _write_boundary:
		boundary_boxes = _write_boundary_scene(path, scene as Node3D, flood.edges)

	var lines := PackedStringArray()
	lines.append("## %s" % map_name)
	lines.append("")
	lines.append("`%s`" % path)
	lines.append("")
	lines.append("| Показатель | Значение |")
	lines.append("|---|---|")
	lines.append("| Точек появления (seeds) | %d |" % seeds.size())
	lines.append("| Досягаемая площадь | %.0f м² |" % (flood.cells.size() * _step * _step))
	lines.append("| Смертельных краёв (ячеек) | %d |" % lethal.size())
	lines.append("| Из них «призрачный пол» | %d |" % ghost.size())
	lines.append("| Прыжок разрешён | %s |" % ("да" if jump else "нет"))
	lines.append("| Смертельных прыжков через низкую стену | %d |" % flood.jump_lethal.size())
	lines.append("| Краёв со стеной | %d |" % flood.walls)
	lines.append("| Висящих объектов | %d |" % floating.size())
	if boundary_boxes >= 0:
		lines.append("| Записано стен границы | %d → `%s` |" % [boundary_boxes, _boundary_path(path)])
	lines.append("")
	if not ghost.is_empty():
		lines.append("**Призрачный пол** (видна модель, коллизии нет) — кластеры 4×4 м:")
		lines.append("")
		lines.append_array(_clusters(ghost))
		lines.append("")
		lines.append("Модели над этими ячейками:")
		lines.append("")
		for source in ghost_sources:
			lines.append("- `%s` — %d яч." % [source, ghost_sources[source]])
		lines.append("")
	if not lethal.is_empty():
		lines.append("**Смертельные края** — кластеры 4×4 м:")
		lines.append("")
		lines.append_array(_clusters(lethal))
		lines.append("")
	if not flood.jump_lethal.is_empty():
		lines.append("**Смертельные прыжки** (стена ниже 1,1 м, за ней обрыв) — кластеры 4×4 м:")
		lines.append("")
		lines.append_array(_clusters(flood.jump_lethal))
		lines.append("")
	if not floating.is_empty():
		lines.append("**Висящие объекты:**")
		lines.append("")
		for item in floating:
			lines.append("- `%s` — низ на y=%.1f, центр (%.1f, %.1f)" % [item.path, item.aabb.position.y, item.aabb.get_center().x, item.aabb.get_center().z])
		lines.append("")
	lines.append("Карта: `%s.png`" % map_name)
	lines.append("")
	scene.queue_free()
	await process_frame
	return lines


## Заливка от точек появления по сетке. Ключ ячейки учитывает этаж, чтобы карниз над пещерой
## и пол пещеры не сливались.
func _flood(space: PhysicsDirectSpaceState3D, seeds: Array[Vector3], jump: bool) -> Dictionary:
	var cells := {}
	var lethal: Array[Vector3] = []
	var jump_lethal: Array[Vector3] = []
	## Пара [ячейка, направление] на каждый смертельный край — по ним ставятся стены границы.
	var edges: Array = []
	var walls := 0
	var queue: Array[Vector3] = []
	for seed in seeds:
		var hit := _floor_below(space, seed + Vector3.UP * 0.9, 4.0)
		if not hit.is_empty():
			var start := _snap(hit.position)
			if not cells.has(_key(start)):
				cells[_key(start)] = start
				queue.append(start)
	var dirs := [Vector3(_step, 0, 0), Vector3(-_step, 0, 0), Vector3(0, 0, _step), Vector3(0, 0, -_step)]
	var head := 0
	while head < queue.size() and cells.size() < MAX_CELLS:
		var cell: Vector3 = queue[head]
		head += 1
		for dir in dirs:
			var target: Vector3 = cell + dir
			if _blocked(space, cell, target, KNEE):
				walls += 1
				if jump and not _blocked(space, cell, target, JUMP_CLEAR):
					_jump_over(space, cell, dir.normalized(), cells, queue, jump_lethal)
				continue
			var hit := _floor_below(space, target + Vector3.UP * 0.9, FALL_LIMIT + 0.9)
			if hit.is_empty():
				lethal.append(Vector3(target.x, cell.y, target.z))
				edges.append([cell, dir])
				continue
			var dy: float = hit.position.y - cell.y
			if hit.normal.y < MIN_FLOOR_NORMAL_Y:
				continue
			if dy > MAX_STEP_UP and not (jump and dy <= JUMP_CLEAR):
				continue
			_add_cell(Vector3(target.x, hit.position.y, target.z), cells, queue)
	return {"cells": cells, "lethal": lethal, "jump_lethal": jump_lethal, "edges": edges, "walls": walls}


## Прыжок через низкую стену: ищем, куда Санни приземлится в 1–3 м за ней.
func _jump_over(space: PhysicsDirectSpaceState3D, cell: Vector3, dir: Vector3, cells: Dictionary, queue: Array[Vector3], jump_lethal: Array[Vector3]) -> void:
	for distance in [1.0, 2.0, 3.0]:
		var target: Vector3 = cell + dir * distance
		if _blocked(space, cell, target, JUMP_CLEAR):
			return
		var hit := _floor_below(space, target + Vector3.UP * (JUMP_CLEAR + 0.2), FALL_LIMIT + JUMP_CLEAR + 0.2)
		if hit.is_empty():
			jump_lethal.append(Vector3(target.x, cell.y, target.z))
			return
		if hit.normal.y >= MIN_FLOOR_NORMAL_Y and hit.position.y - cell.y <= JUMP_CLEAR:
			_add_cell(Vector3(snappedf(target.x, _step), hit.position.y, snappedf(target.z, _step)), cells, queue)
			return


func _add_cell(point: Vector3, cells: Dictionary, queue: Array[Vector3]) -> void:
	var key := _key(point)
	if not cells.has(key):
		cells[key] = point
		queue.append(point)


func _blocked(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, height: float) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * height, to + Vector3.UP * height, WORLD_MASK)
	var hit := space.intersect_ray(query)
	return not hit.is_empty() and hit.normal.y < MIN_FLOOR_NORMAL_Y


func _floor_below(space: PhysicsDirectSpaceState3D, from: Vector3, depth: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * depth, WORLD_MASK)
	return space.intersect_ray(query)


func _snap(point: Vector3) -> Vector3:
	return Vector3(snappedf(point.x, _step), point.y, snappedf(point.z, _step))


func _key(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x / _step), floori(point.y / 2.0), roundi(point.z / _step))


func _seeds(scene: Node) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var spawns := scene.get_node_or_null(^"Spawns")
	if spawns:
		for child in spawns.get_children():
			if child is Node3D:
				result.append((child as Node3D).global_position)
	return result


## Границы видимых моделей по экземплярам ассетов (узлы с scene_file_path): дорога, стена, валун.
func _visual_bounds(scene: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_collect_visuals(scene, scene, result)
	return result


func _collect_visuals(scene: Node, node: Node, result: Array[Dictionary]) -> void:
	for child in node.get_children():
		if child is Node3D and not (child as Node3D).is_visible_in_tree():
			continue
		if child != scene and not child.scene_file_path.is_empty() and child is Node3D:
			var box := _merged_aabb(child)
			if box.has_volume() and box.get_longest_axis_size() < BACKDROP_SIZE:
				result.append({"path": str(scene.get_path_to(child)), "aabb": box})
			continue
		_collect_visuals(scene, child, result)


func _merged_aabb(node: Node) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is MeshInstance3D and (current as MeshInstance3D).is_visible_in_tree():
			var mesh := current as MeshInstance3D
			var world := mesh.global_transform * mesh.get_aabb()
			box = world if first else box.merge(world)
			first = false
		stack.append_array(current.get_children())
	return box


## Путь модели, чей верх на уровне пола над этой точкой; пусто — модели нет.
func _covering_visual(point: Vector3, visuals: Array[Dictionary]) -> String:
	for item in visuals:
		var box: AABB = item.aabb
		if point.x >= box.position.x and point.x <= box.end.x and point.z >= box.position.z and point.z <= box.end.z:
			if absf(box.end.y - point.y) < 0.6:
				return item.path
	return ""


## Висит: под низом модели нет коллизии в пределах 3 м, и модель не касается соседей.
func _floating(space: PhysicsDirectSpaceState3D, _scene: Node, visuals: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in visuals.size():
		var box: AABB = visuals[i].aabb
		var bottom := Vector3(box.get_center().x, box.position.y + 0.2, box.get_center().z)
		if not _floor_below(space, bottom, 3.2).is_empty():
			continue
		var grown := box.grow(0.5)
		var touches := false
		for j in visuals.size():
			if i != j and grown.intersects(visuals[j].aabb):
				touches = true
				break
		if not touches:
			result.append(visuals[i])
	return result


func _clusters(points: Array[Vector3]) -> PackedStringArray:
	var buckets := {}
	for point in points:
		var key := Vector2i(floori(point.x / 4.0), floori(point.z / 4.0))
		buckets[key] = buckets.get(key, 0) + 1
	var keys := buckets.keys()
	keys.sort_custom(func(a, b): return buckets[a] > buckets[b])
	var lines := PackedStringArray()
	for key in keys.slice(0, 12):
		lines.append("- x≈%d, z≈%d — %d яч." % [key.x * 4 + 2, key.y * 4 + 2, buckets[key]])
	if keys.size() > 12:
		lines.append("- … ещё %d кластеров" % (keys.size() - 12))
	return lines


func _draw_map(map_name: String, flood: Dictionary, ghost: Array[Vector3], floating: Array[Dictionary], seeds: Array[Vector3]) -> void:
	var cells: Dictionary = flood.cells
	var all: Array[Vector3] = []
	all.append_array(cells.values())
	all.append_array(flood.lethal)
	all.append_array(flood.jump_lethal)
	if all.is_empty():
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var ymin := INF
	var ymax := -INF
	for p in all:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	for p in cells.values():
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
	var scale := 4
	var size := Vector2i(int((hi.x - lo.x) / _step) + 3, int((hi.y - lo.y) / _step) + 3) * scale
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	image.fill(Color(0.08, 0.08, 0.1))
	var plot := func(p: Vector3, color: Color) -> void:
		var px := Vector2i(int((p.x - lo.x) / _step) + 1, int((p.z - lo.y) / _step) + 1) * scale
		image.fill_rect(Rect2i(px, Vector2i(scale, scale)), color)
	for p in cells.values():
		var t: float = 0.0 if ymax - ymin < 0.01 else (p.y - ymin) / (ymax - ymin)
		plot.call(p, Color(0.25, 0.4, 0.25).lerp(Color(0.75, 0.85, 0.7), t))
	for p in flood.lethal:
		plot.call(p, Color(0.9, 0.15, 0.15))
	for p in flood.jump_lethal:
		plot.call(p, Color(0.3, 0.6, 1.0))
	for p in ghost:
		plot.call(p, Color(1.0, 0.2, 0.9))
	for item in floating:
		plot.call(item.aabb.get_center(), Color(1.0, 0.6, 0.0))
	for p in seeds:
		plot.call(p, Color(1.0, 1.0, 0.2))
	image.save_png(_out_dir.path_join(map_name + ".png"))


func _boundary_path(scene_path: String) -> String:
	return scene_path.get_basename() + "_boundary.tscn"


## Стены по смертельным краям. Соседние отрезки одного края (то же направление, та же линия,
## близкая высота) склеиваются в одну коробку.
func _write_boundary_scene(scene_path: String, scene: Node3D, edges: Array) -> int:
	var runs := {}
	for edge in edges:
		var cell: Vector3 = edge[0]
		var dir: Vector3 = edge[1]
		var along_x := absf(dir.x) > 0.0
		var plane := (cell.x if along_x else cell.z) + signf(dir.x if along_x else dir.z) * _step * 0.5
		var key := "%s|%d|%d" % [str(dir), roundi(plane / _step * 2.0), floori(cell.y)]
		if not runs.has(key):
			runs[key] = {"along_x": along_x, "plane": plane, "cells": []}
		runs[key].cells.append(cell)
	var body := StaticBody3D.new()
	body.name = BOUNDARY_NODE
	body.collision_layer = BOUNDARY_LAYER
	body.collision_mask = 0
	var count := 0
	for key in runs:
		var run: Dictionary = runs[key]
		var cells: Array = run.cells
		# Вдоль стены идёт ось z для краёв по x, и наоборот.
		cells.sort_custom(func(a, b): return (a.z if run.along_x else a.x) < (b.z if run.along_x else b.x))
		var start := 0
		for i in range(1, cells.size() + 1):
			var broken := i == cells.size()
			if not broken:
				var prev: float = cells[i - 1].z if run.along_x else cells[i - 1].x
				var curr: float = cells[i].z if run.along_x else cells[i].x
				broken = curr - prev > _step * 1.01
			if broken:
				var wall := _wall_shape(cells.slice(start, i), run.along_x, run.plane, scene)
				wall.name = "Wall%03d" % count
				body.add_child(wall)
				count += 1
				start = i
	for child in body.get_children():
		child.owner = body
	var packed := PackedScene.new()
	packed.pack(body)
	ResourceSaver.save(packed, _boundary_path(scene_path))
	body.free()
	return count


func _wall_shape(cells: Array, along_x: bool, plane: float, scene: Node3D) -> CollisionShape3D:
	var lo := INF
	var hi := -INF
	var ymin := INF
	var ymax := -INF
	for cell in cells:
		var t: float = cell.z if along_x else cell.x
		lo = minf(lo, t)
		hi = maxf(hi, t)
		ymin = minf(ymin, cell.y)
		ymax = maxf(ymax, cell.y)
	var length := hi - lo + _step
	var height := ymax - ymin + WALL_HEIGHT
	var center_y := ymin - 0.5 + height * 0.5
	var center := Vector3(plane, center_y, (lo + hi) * 0.5) if along_x else Vector3((lo + hi) * 0.5, center_y, plane)
	var box := BoxShape3D.new()
	box.size = Vector3(WALL_THICKNESS, height, length) if along_x else Vector3(length, height, WALL_THICKNESS)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = scene.to_local(center)
	return shape
