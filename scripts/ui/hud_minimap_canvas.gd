class_name HudMinimapCanvas
extends Control
## Draws the local map visible in the circular HUD minimap.
##
## North is up. The player arrow rotates with the camera/character forward.
## The canvas is rendered inside a SubViewport and masked to a circle by the
## parent HUDMinimap, so it must keep its background opaque enough to read.

const VIEW_RADIUS_METERS := 55.0

const BG := Color(0.025, 0.035, 0.040, 0.92)
const WALKABLE := Color(0.10, 0.16, 0.14, 0.92)
const BLOCKED := Color(0.045, 0.060, 0.065, 0.94)
const HAZARD := Color(0.26, 0.10, 0.08, 0.88)
const UNAVAILABLE := Color(0.035, 0.045, 0.050, 0.90)
const ROUTE := Color(0.64, 0.50, 0.29, 0.62)
const EDGE := Color(0.30, 0.41, 0.34, 0.70)
const BONE := Color(0.88, 0.82, 0.68, 0.95)
const BRONZE := Color(0.76, 0.61, 0.39, 0.95)
const RUST := Color(0.78, 0.34, 0.25, 0.95)
const MOSS := Color(0.58, 0.75, 0.51, 0.95)

var _snapshot: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_snapshot(value: Dictionary) -> void:
	_snapshot = value
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	draw_circle(center, radius, BG)

	var map := _snapshot.get("location") as MapDefinition
	if map == null:
		_draw_grid(center, radius)
		_draw_player(center, Vector2.UP)
		return

	var player: Vector2 = _snapshot.get("player", Vector2.ZERO)
	var forward: Vector2 = _snapshot.get("forward", Vector2.UP)
	var scale := radius / VIEW_RADIUS_METERS
	_draw_features(map, center, player, scale)
	_draw_markers(map, center, player, scale)
	_draw_player(center, forward)


func _draw_features(map: MapDefinition, center: Vector2, player: Vector2, scale: float) -> void:
	for feature in map.features:
		if feature == null or feature.points.is_empty():
			continue
		var points := PackedVector2Array()
		for point in feature.points:
			points.append(center + (point - player) * scale)
		if feature.is_area() and points.size() >= 3:
			var fill := WALKABLE
			var edge := EDGE
			match feature.kind:
				MapFeature.Kind.BLOCKED:
					fill = BLOCKED
					edge = Color(0.18, 0.22, 0.22, 0.65)
				MapFeature.Kind.HAZARD:
					fill = HAZARD
					edge = RUST
				MapFeature.Kind.UNAVAILABLE:
					fill = UNAVAILABLE
					edge = Color(0.16, 0.16, 0.16, 0.5)
			draw_colored_polygon(points, fill)
			draw_polyline(_closed(points), edge, 1.0, true)
		elif points.size() >= 2:
			var color := ROUTE if feature.kind == MapFeature.Kind.ROUTE else EDGE
			draw_polyline(points, color, 1.2, true)


func _draw_markers(map: MapDefinition, center: Vector2, player: Vector2, scale: float) -> void:
	var flags := _flags()
	for marker in map.visible_markers(flags):
		if marker == null or marker.kind == MapMarker.Kind.PLAYER:
			continue
		var world := _marker_world(map, marker)
		if world == Vector2.INF:
			continue
		var offset := world - player
		var distance := offset.length()
		var screen := center + offset * scale
		if distance > VIEW_RADIUS_METERS:
			if marker.kind == MapMarker.Kind.QUEST:
				var direction := offset.normalized()
				_draw_diamond(center + direction * (size.x * 0.5 - 12.0), 4.0, BRONZE)
			continue
		match marker.kind:
			MapMarker.Kind.QUEST:
				draw_circle(screen, 7.0, Color(0.98, 0.86, 0.48, 0.16))
				draw_arc(screen, 6.0, 0.0, TAU, 24, Color(0.98, 0.86, 0.48, 0.68), 1.0, true)
				_draw_diamond(screen, 3.8, BRONZE)
			MapMarker.Kind.CAMP:
				_draw_triangle(screen, 4.5, MOSS)
			MapMarker.Kind.DANGER:
				_draw_diamond(screen, 3.6, RUST)
			_:
				_draw_diamond(screen, 3.0, BONE)


func _draw_player(center: Vector2, forward: Vector2) -> void:
	var direction := forward.normalized() if forward.length_squared() > 0.001 else Vector2.UP
	var side := Vector2(-direction.y, direction.x)
	var arrow := PackedVector2Array([
		center + direction * 10.0,
		center - direction * 5.0 + side * 5.0,
		center - direction * 2.0,
		center - direction * 5.0 - side * 5.0,
	])
	draw_colored_polygon(arrow, Color(0.95, 0.88, 0.70, 0.98))
	draw_polyline(_closed(arrow), Color(0.05, 0.045, 0.035, 0.95), 1.0, true)


func _draw_grid(center: Vector2, radius: float) -> void:
	for index in range(1, 4):
		draw_arc(center, radius * float(index) / 4.0, 0.0, TAU, 48, Color(0.25, 0.25, 0.22, 0.35), 1.0, true)
	draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(0.25, 0.25, 0.22, 0.28), 1.0, true)
	draw_line(center - Vector2(0, radius), center + Vector2(0, radius), Color(0.25, 0.25, 0.22, 0.28), 1.0, true)


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius * 0.78, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius * 0.78, 0),
	])
	draw_colored_polygon(points, Color(0.02, 0.02, 0.025, 0.72))
	draw_polyline(_closed(points), color, 1.2, true)


func _draw_triangle(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius, radius),
		center + Vector2(-radius, radius),
	])
	draw_colored_polygon(points, Color(0.02, 0.02, 0.025, 0.72))
	draw_polyline(_closed(points), color, 1.2, true)


func _marker_world(map: MapDefinition, marker: MapMarker) -> Vector2:
	if marker.use_world_position:
		return marker.world_position
	if map.has_world_bounds():
		return map.normalized_to_world(marker.position)
	return Vector2.INF


func _flags() -> Dictionary:
	var run_state := get_node_or_null(^"/root/NightmareRunState")
	if run_state == null or not run_state.has_method(&"snapshot"):
		return {}
	var snapshot: Variant = run_state.call(&"snapshot")
	if snapshot is Dictionary:
		var flags: Variant = (snapshot as Dictionary).get("flags", {})
		if flags is Dictionary:
			return flags
	return {}


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if result.size() > 1 and result[0] != result[result.size() - 1]:
		result.append(result[0])
	return result
