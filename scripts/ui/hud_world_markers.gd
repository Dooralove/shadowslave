class_name HudWorldMarkers
extends Control
## Ненавязчивые мировые маркеры HUD:
##   • ромбы у доступных точек взаимодействия;
##   • золотой компас текущей цели (квест или GuideBeacon).
##
## Слой только рисует и ничего не перехватывает. В меню, паузе и диалоге
## маркеры скрываются, чтобы не спорить с модальными окнами.

const INTERACT_RANGE := 12.0
const OBJECTIVE_HIDE_DISTANCE := 2.5
const EDGE_MARGIN := 58.0

## Куда ведёт objective target_id в сцене Лабиринта.
const QUEST_TARGET_PATHS := {
	&"first_fork": "Gameplay/Triggers/FirstFight",
	&"clearing": "Gameplay/Companions/Nephis",
	&"nephis": "Gameplay/Companions/Nephis",
	&"cassia": "Gameplay/Companions/Cassia",
	&"camp": "Markers/CampCheckpoint",
	&"wounded_scavenger": "Gameplay/Encounters/WoundedScavenger",
	&"azure_blade": "Gameplay/Interactables/AzureBlade",
	&"carapace": "Gameplay/Encounters/PacksZ13",
	&"hunting": "Gameplay/Encounters/PacksZ13",
	&"bridge": "Gameplay/Triggers/Bridge",
	&"refuge": "Markers/RefugeCheckpoint",
	&"storm": "Gameplay/Triggers/Storm",
	&"cliffs": "Gameplay/Triggers/Cliffs",
}
const SHARD_PATHS := [
	"Gameplay/Interactables/SoulShardDryPocket",
	"Gameplay/Interactables/SoulShardTunnel",
	"Gameplay/Interactables/SoulShardBridge",
]
const SHARD_FLAGS := [
	&"soul_shard_dry_pocket",
	&"soul_shard_tunnel",
	&"soul_shard_bridge",
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _should_hide():
		return
	var camera := get_viewport().get_camera_3d()
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if camera == null or player == null:
		return
	_draw_interactables(camera, player)
	_draw_objective(camera, player)


func _should_hide() -> bool:
	if get_tree().paused:
		return true
	var scene := _scene_root()
	if scene == null:
		return true
	var player_menu := get_node_or_null(^"/root/PlayerMenuSystem")
	if player_menu != null and player_menu.has_method(&"is_open") and bool(player_menu.call(&"is_open")):
		return true
	var map_system := get_node_or_null(^"/root/MapSystem")
	if map_system != null and map_system.has_method(&"is_open") and bool(map_system.call(&"is_open")):
		return true
	for group in [&"inventory_modal", &"soul_sea_modal"]:
		var node := get_tree().get_first_node_in_group(group)
		if node == null:
			continue
		if node.has_method(&"is_open") and bool(node.call(&"is_open")):
			return true
		if node.has_method(&"is_active") and bool(node.call(&"is_active")):
			return true
	for runner in get_tree().get_nodes_in_group(&"dialogue_runner"):
		if runner is DialogueRunner and bool(runner.get(&"running")):
			return true
	return false


func _draw_interactables(camera: Camera3D, player: Node3D) -> void:
	var focused: Interactable = null
	var interactor := player.get_node_or_null(^"Interactor") as Interactor
	if interactor != null:
		focused = interactor.focused
	for node in get_tree().get_nodes_in_group(&"interactable"):
		var target := node as Interactable
		if target == null or not target.enabled or not target.is_inside_tree():
			continue
		var distance := _horizontal_distance(player.global_position, target.global_position)
		if distance > INTERACT_RANGE:
			continue
		var world := target.global_position + Vector3.UP * 1.05
		if camera.is_position_behind(world):
			continue
		var point := camera.unproject_position(world)
		if not Rect2(Vector2.ZERO, size).grow(-4.0).has_point(point):
			continue
		var alpha := clampf(1.0 - distance / INTERACT_RANGE, 0.16, 0.7)
		var is_focused := target == focused
		var radius := 5.5 if is_focused else 3.6
		var color := Color(0.93, 0.82, 0.55, alpha)
		_draw_diamond(point, radius, color)
		if is_focused:
			draw_arc(point, radius + 4.0, 0.0, TAU, 24, Color(0.93, 0.82, 0.55, 0.45), 1.0, true)
			_draw_centered_text(point + Vector2(0, radius + 15.0), "E", 11, Color(0.96, 0.90, 0.76, 0.9))


func _draw_objective(camera: Camera3D, player: Node3D) -> void:
	var target := _resolve_objective_target()
	if target == null or not target.is_inside_tree():
		return
	var world := target.global_position + Vector3.UP * 1.35
	var distance := _horizontal_distance(player.global_position, target.global_position)
	if distance <= OBJECTIVE_HIDE_DISTANCE:
		return
	var point := camera.unproject_position(world)
	var on_screen := not camera.is_position_behind(world) and Rect2(Vector2.ZERO, size).grow(-EDGE_MARGIN).has_point(point)
	if on_screen:
		_draw_objective_marker(point, distance)
		return
	var center := size * 0.5
	var direction := point - center
	if camera.is_position_behind(world):
		direction = -direction
	if direction.length_squared() < 0.001:
		direction = Vector2(0, -1)
	direction = direction.normalized()
	var half := size * 0.5 - Vector2(EDGE_MARGIN, EDGE_MARGIN)
	var scale_x := half.x / maxf(absf(direction.x), 0.001)
	var scale_y := half.y / maxf(absf(direction.y), 0.001)
	var edge := center + direction * minf(scale_x, scale_y)
	_draw_edge_arrow(edge, direction, distance)


func _draw_objective_marker(point: Vector2, distance: float) -> void:
	draw_circle(point, 11.0, Color(0.98, 0.86, 0.48, 0.12))
	draw_arc(point, 10.0, 0.0, TAU, 32, Color(0.98, 0.86, 0.48, 0.75), 1.5, true)
	_draw_diamond(point, 4.4, Color(0.98, 0.86, 0.48, 0.95))
	if distance >= 8.0:
		_draw_centered_text(point + Vector2(0, -16.0), "%d м" % roundi(distance), 11, Color(0.95, 0.90, 0.78, 0.85))


func _draw_edge_arrow(point: Vector2, direction: Vector2, distance: float) -> void:
	var side := Vector2(-direction.y, direction.x)
	var tip := point + direction * 11.0
	var arrow := PackedVector2Array([
		tip,
		point - direction * 5.0 + side * 7.0,
		point - direction * 2.0,
		point - direction * 5.0 - side * 7.0,
	])
	draw_colored_polygon(arrow, Color(0.98, 0.86, 0.48, 0.82))
	draw_polyline(_closed(arrow), Color(0.05, 0.04, 0.03, 0.85), 1.0, true)
	_draw_centered_text(point - direction * 20.0, "%d м" % roundi(distance), 10, Color(0.95, 0.90, 0.78, 0.78))


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius * 0.72, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius * 0.72, 0),
	])
	draw_colored_polygon(points, Color(0.02, 0.02, 0.025, 0.55))
	draw_polyline(_closed(points), color, 1.2, true)


func _draw_centered_text(center: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center + Vector2(-width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	if points.is_empty():
		return points
	var closed := points.duplicate()
	if closed[0] != closed[closed.size() - 1]:
		closed.append(closed[0])
	return closed


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _resolve_objective_target() -> Node3D:
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests != null and quests.has_method(&"is_scope_active") and bool(quests.call(&"is_scope_active")):
		return _resolve_quest_target(quests)
	return _resolve_beacon_target()


func _resolve_quest_target(quests: Node) -> Node3D:
	var objective: Variant = quests.call(&"get_tracked_objective")
	if objective == null:
		return null
	var scene := _scene_root()
	if scene == null:
		return null
	var target_id := StringName(objective.get(&"target_id"))
	if target_id == &"soul_shard":
		var flags := _game_flags()
		for index in SHARD_PATHS.size():
			var flag: StringName = SHARD_FLAGS[index]
			if bool(flags.get(flag, false)):
				continue
			var shard := scene.get_node_or_null(NodePath(SHARD_PATHS[index]))
			if shard is Node3D:
				return shard as Node3D
		return null
	var path: String = QUEST_TARGET_PATHS.get(target_id, "")
	if path.is_empty():
		return null
	return scene.get_node_or_null(NodePath(path)) as Node3D


func _scene_root() -> Node:
	var scene := get_tree().current_scene
	if scene is Node3D:
		return scene
	var player := get_tree().get_first_node_in_group(&"player") as Node
	if player != null and player.get_parent() is Node3D:
		return player.get_parent()
	return null


func _resolve_beacon_target() -> Node3D:
	var guide := get_node_or_null(^"/root/CampaignGuide")
	if guide == null:
		return null
	var beat: Variant = guide.get(&"current_beat")
	if beat == null:
		return null
	var beacon_id := StringName(beat.get(&"guide_beacon_id"))
	if beacon_id == &"":
		return null
	for node in get_tree().get_nodes_in_group(&"guide_beacon"):
		var beacon := node as GuideBeacon
		if beacon != null and beacon.beacon_id == beacon_id:
			return beacon as Node3D
	return null


func _game_flags() -> Dictionary:
	var run_state := get_node_or_null(^"/root/NightmareRunState")
	if run_state == null or not run_state.has_method(&"snapshot"):
		return {}
	var snapshot: Variant = run_state.call(&"snapshot")
	if snapshot is Dictionary:
		var flags: Variant = (snapshot as Dictionary).get("flags", {})
		return flags if flags is Dictionary else {}
	return {}
