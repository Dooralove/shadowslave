class_name MapCanvas
extends Control
## Рисует карту-заглушку и размещает интерактивные маркеры/регионы.
##
## Холст не знает, какая локация открыта: он получает MapDefinition и
## работает с любой картой атласа. Контуры, сетка, компас и дороги —
## временная графика штатными средствами Godot.

signal marker_selected(marker: MapMarker)
signal location_selected(location_id: StringName)
signal location_hovered(location: MapDefinition)

enum Mode { LOCAL, WORLD }

const MARKER_COLORS := {
	MapMarker.Kind.LANDMARK: Color(0.77, 0.64, 0.38),
	MapMarker.Kind.CAMP: Color(0.48, 0.60, 0.43),
	MapMarker.Kind.DANGER: Color(0.68, 0.29, 0.23),
	MapMarker.Kind.QUEST: Color(0.45, 0.60, 0.70),
	MapMarker.Kind.PLAYER: Color(0.91, 0.87, 0.74),
}

const MARKER_SYMBOLS := {
	MapMarker.Kind.LANDMARK: "◆",
	MapMarker.Kind.CAMP: "▲",
	MapMarker.Kind.DANGER: "!",
	MapMarker.Kind.QUEST: "?",
	MapMarker.Kind.PLAYER: "●",
}


static func symbol_for(kind: MapMarker.Kind) -> String:
	return String(MARKER_SYMBOLS.get(kind, "◆"))


static func color_for(kind: MapMarker.Kind) -> Color:
	return MARKER_COLORS.get(kind, MARKER_COLORS[MapMarker.Kind.LANDMARK])

var _mode := Mode.LOCAL
var _map: MapDefinition
var _world_map: MapDefinition
var _locations: Array[MapDefinition] = []
var _current_location_id: StringName
var _selected_marker_id: StringName

var _button_layer: Control
var _marker_buttons: Dictionary = {}
var _location_buttons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_button_layer = Control.new()
	_button_layer.name = "InteractiveLayer"
	_button_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_button_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_button_layer)
	resized.connect(_layout_buttons)


func show_local(map_definition: MapDefinition, current_location_id: StringName) -> void:
	if map_definition == null:
		return
	_mode = Mode.LOCAL
	_map = map_definition
	_current_location_id = current_location_id
	_selected_marker_id = &""
	_rebuild_buttons()
	_layout_buttons()
	queue_redraw()


func show_world(
	world_map: MapDefinition,
	locations: Array[MapDefinition],
	current_location_id: StringName
) -> void:
	if world_map == null:
		return
	_mode = Mode.WORLD
	_world_map = world_map
	_locations = locations
	_current_location_id = current_location_id
	_selected_marker_id = &""
	_rebuild_buttons()
	_layout_buttons()
	queue_redraw()


func highlight_marker(marker_id: StringName) -> void:
	if _mode != Mode.LOCAL:
		return
	_selected_marker_id = StringName(marker_id)
	queue_redraw()


func get_marker_button(marker_id: StringName) -> Button:
	return _marker_buttons.get(StringName(marker_id), null) as Button


func get_location_button(location_id: StringName) -> Button:
	return _location_buttons.get(StringName(location_id), null) as Button


func _rebuild_buttons() -> void:
	for child in _button_layer.get_children():
		child.visible = false
		child.queue_free()
	_marker_buttons.clear()
	_location_buttons.clear()

	if _mode == Mode.LOCAL:
		if _map != null:
			for marker in _map.markers:
				if marker != null:
					_add_marker_button(marker)
	else:
		for location in _locations:
			if location != null:
				_add_location_button(location)


func _add_marker_button(marker: MapMarker) -> void:
	var tint: Color = MARKER_COLORS.get(marker.kind, MARKER_COLORS[MapMarker.Kind.LANDMARK])
	var button := Button.new()
	button.name = "Marker_%s" % marker.id
	button.text = String(MARKER_SYMBOLS.get(marker.kind, "◆"))
	button.tooltip_text = "%s · %s" % [marker.kind_title(), marker.label]
	if not marker.description.is_empty():
		button.tooltip_text += "\n%s" % marker.description
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", tint)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.82))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.82))
	button.add_theme_stylebox_override("normal", _pin_style(
		Color(0.07, 0.085, 0.095, 0.94), Color(tint, 0.85), 1
	))
	button.add_theme_stylebox_override("hover", _pin_style(
		Color(0.15, 0.16, 0.16, 0.98), tint, 2
	))
	button.add_theme_stylebox_override("pressed", _pin_style(
		Color(0.20, 0.18, 0.13, 1.0), Color(1.0, 0.88, 0.58), 2
	))
	button.add_theme_stylebox_override("focus", _pin_style(
		Color(0.14, 0.15, 0.15, 0.98), Color(tint, 0.9), 2
	))
	button.pressed.connect(_on_marker_pressed.bind(marker))
	_button_layer.add_child(button)
	_marker_buttons[marker.id] = button


func _add_location_button(location: MapDefinition) -> void:
	var button := Button.new()
	button.name = "Region_%s" % location.id
	button.text = location.title.to_upper()
	button.tooltip_text = "%s\n%s" % [
		location.title,
		"Регион доступен" if location.available else "Регион ещё закрыт",
	]
	if not location.description.is_empty():
		button.tooltip_text += "\n%s" % location.description
	button.focus_mode = Control.FOCUS_ALL
	button.disabled = not location.available
	button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if location.available else Control.CURSOR_FORBIDDEN
	)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color(0.88, 0.84, 0.73, 0.95))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.84))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.68))
	button.add_theme_color_override(
		"font_disabled_color", Color(0.52, 0.52, 0.50, 0.65)
	)
	button.add_theme_stylebox_override("normal", _region_style(
		Color(location.land_color, 0.10), Color(location.accent_color, 0.55)
	))
	button.add_theme_stylebox_override("hover", _region_style(
		Color(location.land_color, 0.36), Color(location.accent_color, 1.0)
	))
	button.add_theme_stylebox_override("pressed", _region_style(
		Color(0.30, 0.25, 0.16, 0.70), Color(1.0, 0.88, 0.58)
	))
	button.add_theme_stylebox_override("focus", _region_style(
		Color(location.land_color, 0.22), Color(location.accent_color, 0.9)
	))
	button.add_theme_stylebox_override("disabled", _region_style(
		Color(0.08, 0.09, 0.095, 0.58), Color(0.36, 0.37, 0.36, 0.55)
	))
	button.pressed.connect(_on_region_pressed.bind(location))
	button.mouse_entered.connect(_on_region_hovered.bind(location))
	button.focus_entered.connect(_on_region_hovered.bind(location))
	_button_layer.add_child(button)
	_location_buttons[location.id] = button


func _layout_buttons() -> void:
	if _button_layer == null or size.x <= 4.0 or size.y <= 4.0:
		return

	if _mode == Mode.LOCAL and _map != null:
		for marker in _map.markers:
			if marker == null:
				continue
			var button := get_marker_button(marker.id)
			if button == null:
				continue
			button.size = Vector2(32.0, 32.0)
			var point := _local_point(marker.position)
			button.position = Vector2(
				clampf(point.x - 16.0, 3.0, size.x - 35.0),
				clampf(point.y - 16.0, 3.0, size.y - 35.0)
			)
	elif _mode == Mode.WORLD:
		for location in _locations:
			if location == null:
				continue
			var button := get_location_button(location.id)
			if button == null:
				continue
			var rect := _world_region_rect(location.world_rect)
			button.position = rect.position
			button.size = rect.size


func _draw() -> void:
	var background := Color(0.055, 0.07, 0.082, 1.0)
	if _mode == Mode.LOCAL and _map != null:
		background = _map.background_color
	elif _mode == Mode.WORLD and _world_map != null:
		background = _world_map.background_color

	draw_rect(Rect2(Vector2.ZERO, size), background)
	_draw_grid()

	if _mode == Mode.LOCAL:
		_draw_local_map()
	else:
		_draw_world_map()
	_draw_frame_corners()


func _draw_grid() -> void:
	var step := 64.0
	var line_color := Color(0.62, 0.67, 0.70, 0.055)
	var x := step
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), line_color, 1.0)
		x += step
	var y := step
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), line_color, 1.0)
		y += step


func _draw_local_map() -> void:
	if _map == null:
		return
	var area := _local_area()
	var points := _map_points(_map.get_contour(), area)
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(7.0, 9.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.28))
	draw_colored_polygon(points, _map.land_color)

	var closed := _closed_polygon(points)
	draw_polyline(closed, Color(_map.accent_color, 0.88), 1.8, true)
	draw_polyline(_closed_polygon(_scale_polygon(points, 0.93)),
		Color(_map.accent_color, 0.24), 1.0, true)
	draw_polyline(_closed_polygon(_scale_polygon(points, 0.84)),
		Color(_map.accent_color, 0.15), 1.0, true)

	var river := PackedVector2Array([
		_local_point(Vector2(0.23, 0.18)),
		_local_point(Vector2(0.33, 0.35)),
		_local_point(Vector2(0.30, 0.53)),
		_local_point(Vector2(0.43, 0.72)),
		_local_point(Vector2(0.60, 0.86)),
	])
	draw_polyline(river, Color(0.36, 0.51, 0.55, 0.38), 2.0, true)

	draw_dashed_line(
		_local_point(Vector2(0.17, 0.70)),
		_local_point(Vector2(0.48, 0.54)),
		Color(_map.accent_color, 0.48), 1.5, 5.0, true, true
	)
	draw_dashed_line(
		_local_point(Vector2(0.48, 0.54)),
		_local_point(Vector2(0.79, 0.37)),
		Color(_map.accent_color, 0.48), 1.5, 5.0, true, true
	)

	if _map.is_fallback:
		_draw_fallback_marks(area)

	var selected := _map.marker_by_id(_selected_marker_id)
	if selected != null:
		var point := _local_point(selected.position)
		draw_circle(point, 18.0, Color(_map.accent_color, 0.10))
		draw_arc(point, 18.0, 0.0, TAU, 40, Color(_map.accent_color, 0.95), 2.0, true)

	_draw_compass(Vector2(size.x - 58.0, 58.0), 20.0, _map.accent_color)
	_draw_caption("ЛОКАЛЬНАЯ КАРТА · %s" % String(_map.id).to_upper(), _map.accent_color)


func _draw_world_map() -> void:
	if _world_map == null:
		return
	var area := _world_area()
	var points := _map_points(_world_map.get_contour(), area)
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(8.0, 10.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.30))
	draw_colored_polygon(points, _world_map.land_color)
	draw_polyline(_closed_polygon(points), Color(_world_map.accent_color, 0.88), 2.0, true)
	draw_polyline(
		_closed_polygon(_scale_polygon(points, 0.94)),
		Color(_world_map.accent_color, 0.22), 1.0, true
	)

	for index in range(1, _locations.size()):
		var previous := _locations[index - 1]
		var current := _locations[index]
		if previous == null or current == null:
			continue
		if not previous.available or not current.available:
			continue
		draw_dashed_line(
			_region_center(previous), _region_center(current),
			Color(_world_map.accent_color, 0.28), 1.2, 7.0, true, true
		)

	for location in _locations:
		if location == null:
			continue
		_draw_region(location)

	_draw_compass(Vector2(size.x - 58.0, 58.0), 20.0, _world_map.accent_color)
	_draw_caption("ОБЩАЯ КАРТА · ИЗВЕСТНЫЕ ЗЕМЛИ", _world_map.accent_color)


func _draw_region(location: MapDefinition) -> void:
	var rect := _world_region_rect(location.world_rect)
	var heavy := location.id == _current_location_id
	var fill := Color(location.land_color, 0.72 if location.available else 0.28)
	var outline := Color(
		location.accent_color, 0.92 if location.available else 0.38
	)
	var polygon := _beveled_polygon(rect, minf(rect.size.x, rect.size.y) * 0.14)
	draw_colored_polygon(polygon, fill)
	draw_polyline(_closed_polygon(polygon), outline, 2.4 if heavy else 1.2, true)

	if not location.available:
		_draw_hatch(rect, Color(0.04, 0.05, 0.055, 0.42))
	elif heavy:
		draw_dashed_line(
			rect.position - Vector2(5.0, 5.0),
			Vector2(rect.end.x + 5.0, rect.position.y - 5.0),
			Color(0.96, 0.84, 0.55, 0.88), 1.5, 4.0, true, true
		)
		draw_dashed_line(
			Vector2(rect.end.x + 5.0, rect.position.y - 5.0),
			rect.end + Vector2(5.0, 5.0),
			Color(0.96, 0.84, 0.55, 0.88), 1.5, 4.0, true, true
		)
		draw_dashed_line(
			rect.end + Vector2(5.0, 5.0),
			Vector2(rect.position.x - 5.0, rect.end.y + 5.0),
			Color(0.96, 0.84, 0.55, 0.88), 1.5, 4.0, true, true
		)
		draw_dashed_line(
			Vector2(rect.position.x - 5.0, rect.end.y + 5.0),
			rect.position - Vector2(5.0, 5.0),
			Color(0.96, 0.84, 0.55, 0.88), 1.5, 4.0, true, true
		)
		draw_circle(rect.position + Vector2(12.0, 12.0), 3.5, Color(0.97, 0.87, 0.62))


func _draw_fallback_marks(area: Rect2) -> void:
	var dash := 10.0
	var color := Color(0.62, 0.53, 0.37, 0.35)
	var corners := [
		[area.position, Vector2(area.end.x, area.position.y)],
		[Vector2(area.end.x, area.position.y), area.end],
		[area.end, Vector2(area.position.x, area.end.y)],
		[Vector2(area.position.x, area.end.y), area.position],
	]
	for edge in corners:
		draw_dashed_line(edge[0], edge[1], color, 1.5, dash, true, true)

	var font := get_theme_default_font()
	if font != null:
		draw_string(
			font,
			Vector2(area.position.x, area.position.y + area.size.y - 22.0),
			"СХЕМА-ЗАГЛУШКА · МАРКЕРЫ НЕ ЗАДАНЫ",
			HORIZONTAL_ALIGNMENT_CENTER,
			area.size.x,
			11,
			Color(0.62, 0.58, 0.49, 0.65)
		)


func _draw_compass(center: Vector2, radius: float, accent: Color) -> void:
	var color := Color(accent, 0.52)
	draw_arc(center, radius, 0.0, TAU, 40, Color(accent, 0.24), 1.0, true)
	draw_line(center + Vector2(0.0, -radius + 3.0), center + Vector2(0.0, radius - 3.0),
		color, 1.0, true)
	draw_line(center + Vector2(-radius + 3.0, 0.0), center + Vector2(radius - 3.0, 0.0),
		Color(accent, 0.30), 1.0, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -radius + 1.0),
		center + Vector2(-4.0, 4.0),
		center + Vector2(4.0, 4.0),
	]), color)
	var font := get_theme_default_font()
	if font != null:
		draw_string(font, center + Vector2(-5.0, -radius - 4.0), "С",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(accent, 0.62))


func _draw_caption(text: String, accent: Color) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	draw_string(font, Vector2(16.0, size.y - 12.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(accent, 0.42))


func _draw_frame_corners() -> void:
	var color := Color(0.74, 0.61, 0.39, 0.35)
	var length := 18.0
	var inset := 6.0
	var corners := [
		Vector2(inset, inset),
		Vector2(size.x - inset, inset),
		Vector2(size.x - inset, size.y - inset),
		Vector2(inset, size.y - inset),
	]
	for index in corners.size():
		var point: Vector2 = corners[index]
		var x_dir := 1.0 if index == 0 or index == 3 else -1.0
		var y_dir := 1.0 if index < 2 else -1.0
		draw_line(point, point + Vector2(length * x_dir, 0.0), color, 1.0)
		draw_line(point, point + Vector2(0.0, length * y_dir), color, 1.0)


func _draw_hatch(rect: Rect2, color: Color) -> void:
	var step := 12.0
	var x := rect.position.x - rect.size.y
	while x < rect.end.x:
		var start := Vector2(maxf(x, rect.position.x), rect.position.y)
		var end_x := x + rect.size.y
		var end := Vector2(minf(end_x, rect.end.x), rect.end.y)
		if end.x > start.x:
			draw_line(start, end, color, 1.0)
		x += step


func _pin_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 3
	return style


func _region_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _local_area() -> Rect2:
	var margin := Vector2(minf(48.0, size.x * 0.06), minf(44.0, size.y * 0.07))
	return Rect2(margin, size - margin * 2.0)


func _world_area() -> Rect2:
	var margin := Vector2(minf(54.0, size.x * 0.065), minf(46.0, size.y * 0.07))
	return Rect2(margin, size - margin * 2.0)


func _local_point(normalized: Vector2) -> Vector2:
	var area := _local_area()
	return area.position + normalized * area.size


func _world_region_rect(normalized: Rect2) -> Rect2:
	var area := _world_area()
	return Rect2(
		area.position + normalized.position * area.size,
		normalized.size * area.size
	)


func _region_center(location: MapDefinition) -> Vector2:
	var rect := _world_region_rect(location.world_rect)
	return rect.position + rect.size * 0.5


func _map_points(normalized: PackedVector2Array, area: Rect2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in normalized:
		result.append(area.position + point * area.size)
	return result


func _closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
	if points.is_empty():
		return points
	var closed := points.duplicate()
	if closed[0] != closed[closed.size() - 1]:
		closed.append(closed[0])
	return closed


func _scale_polygon(points: PackedVector2Array, factor: float) -> PackedVector2Array:
	if points.is_empty():
		return points
	var center := Vector2.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	var result := PackedVector2Array()
	for point in points:
		result.append(center + (point - center) * factor)
	return result


func _beveled_polygon(rect: Rect2, bevel: float) -> PackedVector2Array:
	var b := minf(bevel, minf(rect.size.x, rect.size.y) * 0.45)
	return PackedVector2Array([
		rect.position + Vector2(b, 0.0),
		Vector2(rect.end.x - b, rect.position.y),
		Vector2(rect.end.x, rect.position.y + b),
		Vector2(rect.end.x, rect.end.y - b),
		Vector2(rect.end.x - b, rect.end.y),
		Vector2(rect.position.x + b, rect.end.y),
		Vector2(rect.position.x, rect.end.y - b),
		Vector2(rect.position.x, rect.position.y + b),
	])


func _on_marker_pressed(marker: MapMarker) -> void:
	_selected_marker_id = marker.id
	queue_redraw()
	marker_selected.emit(marker)


func _on_region_pressed(location: MapDefinition) -> void:
	if location == null or not location.available:
		return
	location_selected.emit(location.id)


func _on_region_hovered(location: MapDefinition) -> void:
	location_hovered.emit(location)
