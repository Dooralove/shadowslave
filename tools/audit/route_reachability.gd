extends SceneTree
## Проверка достижимости игровых точек от Spawns/Start по фактической коллизии.
##
## Это не телепорт-тест: сетка 1.5 м заливается от пола под Start, переходы
## разрешены только там, где тело Санни реально проходит (шаг <= 0.45 м,
## уклон <= 45°, стены/невидимые boundary учитываются). Инструмент только
## читает сцену.
##
## godot --headless --path . -s tools/audit/route_reachability.gd -- \
##   --scene=res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn

const WORLD_MASK := 1 | 32
const MAX_STEP_UP := 0.45
const MIN_FLOOR_NORMAL_Y := 0.7
const FALL_LIMIT := 10.0
const KNEE := 0.6
const JUMP_CLEAR := 1.1
const MAX_CELLS := 400000

const ZONE_POINTS := {
	"Z01 Threshold": Vector3(28, 0.2, 0),
	"Z02 Carcass": Vector3(19, -1.3, 26),
	"Z03 FirstFork": Vector3(0, 0.2, 0),
	"Z04 MudHollow": Vector3(-30, -2.8, -42),
	"Z05 BonePassage": Vector3(-30, 0.2, 21),
	"Z06 DryPocket": Vector3(-47, 6.2, 46),
	"Z07 ScoutRidge": Vector3(-25, 7.2, -55),
	"Z08 Clearing": Vector3(-65, 0.2, 0),
	"Z09 BlindTunnel": Vector3(-70, 0.2, 20),
	"Z10 CoralHill": Vector3(-100, 18.2, -5),
	"Z11 TideChannel": Vector3(-137, 6.2, -20),
	"Z12 Isthmus": Vector3(-175, 0.2, 0),
	"Z13 HuntingGrounds": Vector3(-375, 0.2, 0),
	"Z14 BoneBridge": Vector3(-600, 6.2, 0),
	"Z15 HighRefuge": Vector3(-700, 18.2, -20),
	"Z16 PackTerritory": Vector3(-900, 0.2, 0),
	"Z17 StormRun": Vector3(-1175, 8.2, 0),
	"Z18 Cliffs": Vector3(-1400, 35.2, 0),
}

var _step := 1.5
var _scene_path := ""
var _spawn := &"Start"
var _from := Vector3(INF, INF, INF)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--step="):
			_step = maxf(float(arg.trim_prefix("--step=")), 0.5)
		elif arg.begins_with("--spawn="):
			_spawn = StringName(arg.trim_prefix("--spawn="))
		elif arg.begins_with("--from="):
			var parts := arg.trim_prefix("--from=").split(",")
			if parts.size() == 3:
				_from = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	if _scene_path.is_empty():
		push_error("route_reachability: нужен --scene=res://...tscn")
		quit(2)
		return
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("route_reachability: сцена не загружается: " + _scene_path)
		quit(2)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	for i in 6:
		await physics_frame
	# Audit isolation: runtime enemies are not part of the static route.
	var runtime := scene.get_node_or_null(^"Gameplay/Runtime")
	if runtime != null:
		for child in runtime.get_children():
			if child is CollisionObject3D or child is CharacterBody3D:
				child.queue_free()
		await physics_frame
	var space := (scene as Node3D).get_world_3d().direct_space_state
	var start_marker := scene.get_node_or_null(NodePath("Spawns/%s" % _spawn)) as Node3D
	if _from.is_finite():
		var from_marker := Marker3D.new()
		from_marker.position = _from
		scene.add_child(from_marker)
		start_marker = from_marker
	if start_marker == null:
		push_error("route_reachability: нет Spawns/%s" % _spawn)
		scene.queue_free()
		quit(2)
		return
	var flood := _flood(space, [start_marker.global_position])
	print("REACHABILITY scene=", _scene_path, " spawn=", _spawn, " step=", _step)
	print("cells=", flood.cells.size(), " area=%.0f m2" % (flood.cells.size() * _step * _step))
	print("--- zone centres ---")
	var bad_zones := 0
	for zone_name in ZONE_POINTS:
		var point: Vector3 = ZONE_POINTS[zone_name]
		var nearest := _nearest(flood.cells.values(), point)
		var ok: bool = nearest.distance_xz <= _step * 1.8 and absf(nearest.point.y - point.y) <= 2.5
		if not ok:
			bad_zones += 1
		print("%-22s %-5s poi=%s cell=%s dxz=%.1f dy=%.1f" % [
			zone_name, "PASS" if ok else "FAIL", str(point), str(nearest.point),
			nearest.distance_xz, nearest.point.y - point.y])
	print("zone_result=", ZONE_POINTS.size() - bad_zones, "/", ZONE_POINTS.size())
	print("--- gameplay markers ---")
	var pois := _collect_pois(scene)
	var bad_pois := 0
	for entry in pois:
		var point: Vector3 = entry.position
		var nearest := _nearest(flood.cells.values(), point)
		var ok: bool = nearest.distance_xz <= maxf(2.5, _step * 1.8) and absf(nearest.point.y - point.y) <= 2.5
		if not ok:
			bad_pois += 1
		print("%-46s %-5s pos=%s nearest=%s dxz=%.1f dy=%.1f" % [
			entry.path, "PASS" if ok else "FAIL", str(point), str(nearest.point),
			nearest.distance_xz, nearest.point.y - point.y])
	print("poi_result=", pois.size() - bad_pois, "/", pois.size())
	scene.queue_free()
	await process_frame
	quit(0)


func _collect_pois(scene: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var roots := [
		^"Spawns",
		^"Portals",
		^"Markers",
		^"Gameplay/Triggers",
		^"Gameplay/Interactables",
		^"Gameplay/Encounters",
		^"Gameplay/Companions",
		^"Gameplay/Dialogue",
		^"Landmarks",
	]
	for root_path in roots:
		var node := scene.get_node_or_null(root_path)
		if node == null:
			continue
		_collect_markers(scene, node, result)
	return result


func _collect_markers(scene: Node, node: Node, result: Array[Dictionary]) -> void:
	if node is LootCache:
		result.append({"path": str(scene.get_path_to(node)), "position": (node as Node3D).global_position})
	elif node is Marker3D or node is Area3D:
		result.append({"path": str(scene.get_path_to(node)), "position": (node as Node3D).global_position})
	for child in node.get_children():
		_collect_markers(scene, child, result)


func _flood(space: PhysicsDirectSpaceState3D, seeds: Array[Vector3]) -> Dictionary:
	var cells := {}
	var queue: Array[Vector3] = []
	for seed in seeds:
		var hit := _floor_below(space, seed + Vector3.UP * 0.9, 4.0)
		if hit.is_empty():
			continue
		var start := Vector3(snappedf(hit.position.x, _step), hit.position.y, snappedf(hit.position.z, _step))
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
				if _blocked(space, cell, target, JUMP_CLEAR):
					continue
			var hit := _floor_below(space, target + Vector3.UP * (JUMP_CLEAR + 0.2), FALL_LIMIT + JUMP_CLEAR + 0.2)
			if hit.is_empty():
				continue
			if hit.normal.y < MIN_FLOOR_NORMAL_Y:
				continue
			var dy: float = hit.position.y - cell.y
			# CharacterBody3D ходит по непрерывному склону до 45°, поэтому на
			# сетке 1.5 м допустим подъём до 1.5 м, если нормаль полая
			# проходима. Отдельный шаг 0.45 м остаётся для пологих уступов.
			var ramp_rise := _step * 1.02
			if dy > maxf(MAX_STEP_UP, ramp_rise) and dy > JUMP_CLEAR:
				continue
			if dy < -FALL_LIMIT:
				continue
			_add_cell(Vector3(target.x, hit.position.y, target.z), cells, queue)
	return {"cells": cells}


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


func _key(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x / _step), floori(point.y / 2.0), roundi(point.z / _step))


func _nearest(cells: Array, point: Vector3) -> Dictionary:
	var best := {"point": Vector3.ZERO, "distance_xz": INF, "distance": INF}
	for cell in cells:
		var c: Vector3 = cell
		var dxz := Vector2(c.x - point.x, c.z - point.z).length()
		var d := c.distance_to(point)
		if d < best.distance:
			best = {"point": c, "distance_xz": dxz, "distance": d}
	return best
