extends SceneTree
## Аудит «объекты без опоры». READ-ONLY: ничего не удаляет и не меняет в сцене.
##
## Проверяет видимые MeshInstance3D: под нижней гранью AABB ищет коллизию
## (raycast) и визуальную геометрию (AABB других мешей). Если опоры нет в
## пределах порога, объект попадает в отчёт.
##
## Запуск:
##   godot --headless --path . -s tools/audit/floating_objects.gd -- \
##     --scene=res://scenes/locations/... --out=C:/.../floating_objects.md \
##     --threshold=0.6

const DEFAULT_THRESHOLD := 0.6
const SKIP_NAME_PARTS := [
	"cloud", "sky", "snowfall", "flakes", "particle", "fog", "light", "label",
	"ui", "hud", "cursor", "spell", "objective",
]
const CHARACTER_NAME_PARTS := [
	"sunny", "shifty", "hero", "veteran", "scholar", "tyrant", "larva",
	"mannequin", "slave", "rider", "soldier", "guard", "merchant", "npc",
]
const BACKGROUND_PATH_PARTS := [
	"backdrop", "seamsmidground", "midground", "outside", "ridge", "cloud",
]

var _scene_path := ""
var _out_path := ""
var _threshold := DEFAULT_THRESHOLD
var _max_report := 240


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--threshold="):
			_threshold = float(arg.trim_prefix("--threshold="))
		elif arg.begins_with("--max-report="):
			_max_report = maxi(1, int(arg.trim_prefix("--max-report=")))
	if _scene_path.is_empty():
		push_error("floating_objects: нужен --scene=res://...")
		quit(2)
		return
	if _out_path.is_empty():
		_out_path = "user://floating_objects.md"
	DirAccess.make_dir_recursive_absolute(_out_path.get_base_dir())
	var packed := load(_scene_path) as PackedScene
	if packed == null:
		push_error("floating_objects: сцена не загрузилась: %s" % _scene_path)
		quit(3)
		return
	var scene := packed.instantiate() as Node3D
	if scene == null:
		push_error("floating_objects: сцена не Node3D")
		quit(4)
		return
	root.add_child(scene)
	for i in 4:
		await process_frame
	await physics_frame
	await physics_frame

	var meshes := _collect_meshes(scene)
	var space := scene.get_world_3d().direct_space_state
	var findings: Array[Dictionary] = []
	for mesh in meshes:
		var finding := _check_mesh(mesh, meshes, space)
		if not finding.is_empty():
			findings.append(finding)
	findings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["gap"]) > float(b["gap"])
	)
	_write_report(scene, meshes.size(), findings)
	print("floating_objects: scene=%s meshes=%d findings=%d out=%s" % [
		_scene_path, meshes.size(), findings.size(), _out_path
	])
	for finding in findings.slice(0, 12):
		print("  %s | bottom=%.2f gap=%.2f | %s" % [
			finding["kind"], finding["bottom"], finding["gap"], finding["path"]
		])
	scene.queue_free()
	await process_frame
	quit(0)


func _collect_meshes(scene: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		if _has_skipped_ancestor(mesh, scene):
			continue
		if String(mesh.name).to_lower() in SKIP_NAME_PARTS:
			continue
		if _is_character(mesh):
			continue
		result.append(mesh)
	return result


func _has_skipped_ancestor(node: Node, scene: Node) -> bool:
	var cursor := node
	while cursor != null and cursor != scene:
		var stem := String(cursor.name).to_lower()
		for part in SKIP_NAME_PARTS:
			if stem.contains(part):
				return true
		cursor = cursor.get_parent()
	return false


func _is_character(node: Node) -> bool:
	var cursor := node
	while cursor != null:
		for group in [&"player", &"npc", &"enemy"]:
			if cursor.is_in_group(group):
				return true
		for part in CHARACTER_NAME_PARTS:
			if String(cursor.name).to_lower().contains(part):
				return true
		cursor = cursor.get_parent()
	return false


func _check_mesh(mesh: MeshInstance3D, meshes: Array[MeshInstance3D],
		space: PhysicsDirectSpaceState3D) -> Dictionary:
	var box := mesh.global_transform * mesh.get_aabb()
	if box.size.y < 0.04 or box.size.x * box.size.z < 0.01:
		return {}
	var bottom := box.position.y
	if bottom < -1000.0:
		return {}
	var sample_points := _sample_points(box)
	var collision_gap := 9999.0
	var visual_gap := 9999.0
	var supported := false
	var visual_support := false
	for point in sample_points:
		var from := Vector3(point.x, bottom - 0.02, point.z)
		var to := Vector3(point.x, bottom - 30.0, point.z)
		var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 32)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var hit_y: float = hit.position.y
			collision_gap = maxf(0.0, bottom - hit_y)
			if collision_gap <= _threshold:
				supported = true
		for other in meshes:
			if other == mesh or not _is_support_provider(other):
				continue
			var other_box := other.global_transform * other.get_aabb()
			var probe := Vector3(point.x, bottom - 0.03, point.z)
			if other_box.has_point(probe):
				visual_support = true
				visual_gap = 0.0
			var top := other_box.end.y
			if top <= bottom + 0.05 and top >= bottom - _threshold:
				if probe.x >= other_box.position.x - 0.01 and probe.x <= other_box.end.x + 0.01 \
						and probe.z >= other_box.position.z - 0.01 and probe.z <= other_box.end.z + 0.01:
					visual_support = true
					visual_gap = maxf(0.0, bottom - top)
			if not visual_support:
				var below_gap := bottom - top
				if below_gap >= 0.0:
					visual_gap = minf(visual_gap, below_gap)
	var gap := minf(collision_gap, visual_gap)
	if supported or visual_support or gap <= _threshold:
		return {}
	var path := String(mesh.get_path())
	var kind := "floating"
	var lowered := path.to_lower()
	for part in BACKGROUND_PATH_PARTS:
		if lowered.contains(part):
			kind = "floating_midground"
			break
	if _is_hanging(mesh):
		kind = "hanging_intentional"
	if gap == 9999.0:
		gap = 999.0
	return {
		"kind": kind,
		"path": path,
		"bottom": bottom,
		"gap": gap,
		"size": box.size,
		"position": mesh.global_position,
	}


func _is_support_provider(mesh: MeshInstance3D) -> bool:
	var box := mesh.global_transform * mesh.get_aabb()
	if maxf(box.size.x, maxf(box.size.y, box.size.z)) > 260.0:
		return false
	var path := String(mesh.get_path()).to_lower()
	for part in ["backdrop", "cloud", "sky", "ridge", "black_mountain", "range"]:
		if path.contains(part):
			return false
	return true


func _sample_points(box: AABB) -> Array[Vector3]:
	var inset := 0.08
	var min_x := box.position.x + box.size.x * inset
	var max_x := box.end.x - box.size.x * inset
	var min_z := box.position.z + box.size.z * inset
	var max_z := box.end.z - box.size.z * inset
	var mid_x := (min_x + max_x) * 0.5
	var mid_z := (min_z + max_z) * 0.5
	return [
		Vector3(mid_x, 0, mid_z),
		Vector3(min_x, 0, min_z), Vector3(min_x, 0, max_z),
		Vector3(max_x, 0, min_z), Vector3(max_x, 0, max_z),
	]


func _is_hanging(mesh: MeshInstance3D) -> bool:
	var cursor: Node = mesh
	while cursor != null:
		var stem := String(cursor.name).to_lower()
		for part in ["chain", "rope", "banner", "lantern", "hanging", "vine", "cable"]:
			if stem.contains(part):
				return true
		cursor = cursor.get_parent()
	return false


func _write_report(scene: Node3D, mesh_count: int, findings: Array[Dictionary]) -> void:
	var lines: Array[String] = [
		"# Объекты без опоры",
		"",
		"Сцена: `%s`  " % _scene_path,
		"Проверено видимых мешей: **%d**  " % mesh_count,
		"Порог опоры: **%.2f м**  " % _threshold,
		"Найдено: **%d**  " % findings.size(),
		"",
		"Аудит только читает сцену. Ничего не удалено.",
		"",
	]
	if findings.is_empty():
		lines.append("Подозрительных объектов нет.")
	else:
		lines.append("| # | Тип | Нижняя грань | Зазор | Путь |")
		lines.append("|---|---|---:|---:|---|")
		for i in findings.size():
			if i >= _max_report:
				lines.append("| … | … | … | … | ещё %d объектов не показано |" % (findings.size() - _max_report))
				break
			var row: Dictionary = findings[i]
			lines.append("| %d | %s | %.2f | %.2f | `%s` |" % [
				i + 1, row["kind"], row["bottom"], row["gap"], row["path"]
			])
	lines.append("")
	lines.append("## Как читать")
	lines.append("")
	lines.append("- `floating` — нижняя грань AABB висит над коллизией/геометрией.")
	lines.append("- `floating_midground` — то же в фоновом декоре; проверить, скрыт ли низ облаком.")
	lines.append("- `hanging_intentional` — цепь/канат/флаг; геометрически висит намеренно.")
	var file := FileAccess.open(_out_path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()
