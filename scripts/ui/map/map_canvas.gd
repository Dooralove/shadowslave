class_name MapCanvas
extends Control
## Рисует карту и размещает интерактивные маркеры и регионы.
##
## Холст не знает, какая карта открыта: он получает MapDefinition (карту
## региона, собранную MapAtlas, или карту локации) либо общую карту с регионами.
## Основа — рисованная растровая подложка (tools/map/build_maps.py); поверх неё
## из данных рисуются границы регионов, геометрия локаций, подписи, иконки и игрок.

signal marker_selected(marker: MapMarker)
signal region_selected(region: MapRegion)
signal region_hovered(region: MapRegion)

enum Mode { LOCAL, WORLD }

const STYLES := [&"kingdom", &"snow", &"pass", &"temple", &"city", &"stone"]
const VOID := Color(0.025, 0.028, 0.032)
## Приближение карты региона колёсиком: 1 — вся карта, MAX_ZOOM — вплотную.
const MAX_ZOOM := 5.0
const ZOOM_STEP := 1.25
## С этого приближения на карте региона видны все значки, а не только задания.
const DETAIL_ZOOM := 1.9

const MARKER_COLORS := {
	MapMarker.Kind.LANDMARK: Color(0.86, 0.74, 0.50),
	MapMarker.Kind.CAMP: Color(0.62, 0.76, 0.52),
	MapMarker.Kind.DANGER: Color(0.86, 0.38, 0.30),
	MapMarker.Kind.QUEST: Color(0.98, 0.86, 0.48),
	MapMarker.Kind.PLAYER: Color(0.95, 0.91, 0.80),
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
var _regions: Array[MapRegion] = []
var _current_location_id: StringName
var _current_region_id: StringName
var _selected_marker_id: StringName
var _flags: Dictionary = {}
var _caption := "КАРТА"
var _metric := true
var _hover_region: MapRegion
var _has_player := false
var _player_world := Vector2.ZERO
var _player_forward := Vector2.ZERO
var _zoom := 1.0
var _pan := Vector2.ZERO
var _dragging := false

var _button_layer: Control
var _marker_buttons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_button_layer = Control.new()
	_button_layer.name = "InteractiveLayer"
	_button_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_button_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_button_layer)
	resized.connect(_layout_buttons)
	# Шумовые текстуры генерируются в фоне: перерисовываемся, когда готовы.
	for texture in MapPaint.all_textures(STYLES):
		if not texture.changed.is_connected(queue_redraw):
			texture.changed.connect(queue_redraw)


## Карта региона или локации. flags — флаги игры для видимости маркеров;
## caption — подпись в углу; metric — масштаб в метрах (только для карты сцены).
func show_local(
	map_definition: MapDefinition,
	current_location_id: StringName,
	flags: Dictionary = {},
	caption := "КАРТА",
	metric := true
) -> void:
	if map_definition == null:
		return
	_mode = Mode.LOCAL
	_map = map_definition
	_current_location_id = current_location_id
	_flags = flags
	_caption = caption
	_metric = metric
	_selected_marker_id = &""
	_zoom = 1.0
	_pan = Vector2.ZERO
	_rebuild_buttons()
	_layout_buttons()
	queue_redraw()


func get_zoom() -> float:
	return _zoom


## Приближение с сохранением точки focus (пиксели холста) под курсором.
func zoom_by(factor: float, focus: Vector2) -> void:
	if _mode != Mode.LOCAL or _map == null:
		return
	var before := _local_area()
	var anchor := (focus - before.position) / before.size
	_zoom = clampf(_zoom * factor, 1.0, MAX_ZOOM)
	var base := _base_local_area()
	var new_size := base.size * _zoom
	var new_position := focus - anchor * new_size
	_pan = new_position + new_size * 0.5 - base.get_center()
	_clamp_pan()
	_layout_buttons()
	queue_redraw()


func reset_view() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	_layout_buttons()
	queue_redraw()


func _clamp_pan() -> void:
	var base := _base_local_area()
	var limit := base.size * (_zoom - 1.0) * 0.5
	_pan = Vector2(clampf(_pan.x, -limit.x, limit.x), clampf(_pan.y, -limit.y, limit.y))


func show_world(
	world_map: MapDefinition,
	regions: Array[MapRegion],
	current_region_id: StringName
) -> void:
	if world_map == null:
		return
	_mode = Mode.WORLD
	_world_map = world_map
	_regions = regions
	_current_region_id = current_region_id
	_hover_region = null
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


## Клик по региону общей карты. Возвращает false для недоступного региона.
func click_region(region_id: StringName) -> bool:
	if _mode != Mode.WORLD:
		return false
	var region := _find_region(region_id)
	if region == null or not region.is_playable():
		return false
	region_selected.emit(region)
	return true


## Регион под точкой холста (в пикселях) или null. Вставки вне Царства
## проверяются первыми: они лежат поверх колонки справа.
func region_at(pixel: Vector2) -> MapRegion:
	var area := _world_area()
	var normalized := (pixel - area.position) / area.size
	for outside in [true, false]:
		for region in _regions:
			if region != null and region.outside_realm == outside and region.contains_point(normalized):
				return region
	return null


## Живой маркер игрока: позиция и направление взгляда в координатах карты.
## Направление не отражается: север (-Z) остаётся вверху карты.
func set_player(world_xz: Vector2, forward_xz: Vector2) -> void:
	_has_player = true
	_player_world = world_xz
	_player_forward = forward_xz
	queue_redraw()


func hide_player() -> void:
	_has_player = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _mode == Mode.LOCAL:
		_local_input(event)
		return
	if event is InputEventMouseMotion:
		var hovered := region_at(event.position)
		if hovered != _hover_region:
			_hover_region = hovered
			if hovered != null:
				region_hovered.emit(hovered)
			mouse_default_cursor_shape = (
				Control.CURSOR_POINTING_HAND if hovered != null and hovered.is_playable()
				else Control.CURSOR_ARROW
			)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var region := region_at(event.position)
		if region != null and region.is_playable():
			region_selected.emit(region)
			accept_event()


## Колесо — приближение к курсору, перетаскивание — сдвиг приближенной карты.
func _local_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(ZOOM_STEP, event.position)
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.0 / ZOOM_STEP, event.position)
			accept_event()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = event.pressed and _zoom > 1.0
			mouse_default_cursor_shape = Control.CURSOR_DRAG if _dragging else Control.CURSOR_ARROW
	elif event is InputEventMouseMotion and _dragging:
		_pan += event.relative
		_clamp_pan()
		_layout_buttons()
		queue_redraw()
		accept_event()


func _find_region(region_id: StringName) -> MapRegion:
	for region in _regions:
		if region != null and region.id == region_id:
			return region
	return null


# --- Кнопки маркеров -------------------------------------------------------

func _rebuild_buttons() -> void:
	for child in _button_layer.get_children():
		child.visible = false
		child.queue_free()
	_marker_buttons.clear()

	if _mode == Mode.LOCAL and _map != null:
		for marker in _map.visible_markers(_flags):
			_add_marker_button(marker)


func _add_marker_button(marker: MapMarker) -> void:
	var tint := color_for(marker.kind)
	var button := Button.new()
	button.name = "Marker_%s" % String(marker.id).replace("/", "_")
	button.text = symbol_for(marker.kind)
	button.tooltip_text = "%s · %s" % [marker.kind_title(), marker.label]
	if not marker.description.is_empty():
		button.tooltip_text += "\n%s" % marker.description
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", MapPaint.serif_font())
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", tint)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.86))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.96, 0.86))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.96, 0.86))
	button.add_theme_stylebox_override("normal", _pin_style(
		Color(0.035, 0.035, 0.035, 0.92), Color(MapPaint.GOLD, 0.85), 2
	))
	button.add_theme_stylebox_override("hover", _pin_style(
		Color(0.12, 0.10, 0.07, 0.98), Color(1.0, 0.88, 0.60), 2
	))
	button.add_theme_stylebox_override("pressed", _pin_style(
		Color(0.22, 0.17, 0.09, 1.0), Color(1.0, 0.90, 0.62), 3
	))
	button.add_theme_stylebox_override("focus", _pin_style(
		Color(0.10, 0.09, 0.07, 0.98), Color(1.0, 0.88, 0.60, 0.9), 2
	))
	button.pressed.connect(_on_marker_pressed.bind(marker))
	_button_layer.add_child(button)
	_marker_buttons[marker.id] = button


func _layout_buttons() -> void:
	if _button_layer == null or size.x <= 4.0 or size.y <= 4.0:
		return
	if _mode != Mode.LOCAL or _map == null:
		return
	for marker in _map.visible_markers(_flags):
		var button := get_marker_button(marker.id)
		if button == null:
			continue
		button.size = Vector2(26.0, 26.0)
		var point := _local_point(_map.marker_point(marker))
		button.position = point - Vector2(13.0, 13.0)
		button.visible = _shows_marker(marker) and Rect2(Vector2.ZERO, size).grow(-4.0).has_point(point)


## На карте региона при общем виде видны только задания и выбранный значок;
## остальные места появляются при приближении (DETAIL_ZOOM).
func _shows_marker(marker: MapMarker) -> bool:
	if _map == null or _map.placements.is_empty():
		return true
	return _zoom >= DETAIL_ZOOM or marker.is_objective() or marker.kind == MapMarker.Kind.QUEST \
		or marker.id == _selected_marker_id


# --- Отрисовка --------------------------------------------------------------

func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	draw_rect(full, VOID)
	draw_texture_rect(MapPaint.void_texture(), full, true)

	if _mode == Mode.LOCAL:
		_draw_local_map()
	else:
		_draw_world_map()

	draw_texture_rect(MapPaint.grain_texture(), full, true)
	draw_texture_rect(MapPaint.vignette_texture(), full, false)
	MapPaint.draw_ornate_frame(self, full)


func _draw_background(map: MapDefinition, area: Rect2) -> void:
	if map.background_texture == null:
		return
	var rect := Rect2(
		area.position + map.background_rect.position * area.size,
		map.background_rect.size * area.size
	)
	draw_rect(Rect2(rect.position + Vector2(6, 8), rect.size), Color(0, 0, 0, 0.5))
	draw_texture_rect(map.background_texture, rect, false)
	draw_rect(rect, Color(0, 0, 0, 0.85), false, 2.0)
	draw_rect(rect.grow(-3.0), Color(MapPaint.GOLD, 0.25), false, 1.0)


func _draw_local_map() -> void:
	if _map == null:
		return
	var area := _local_area()
	_draw_background(_map, area)
	if _map.has_world_bounds():
		_draw_world_geometry(area)
	else:
		_draw_stub_geometry(area)

	if _map.is_fallback:
		_draw_fallback_marks(area)

	for marker in _map.visible_markers(_flags):
		if marker.is_objective():
			var center := _local_point(_map.marker_point(marker))
			draw_circle(center, 22.0, Color(1.0, 0.85, 0.45, 0.12))
			draw_arc(center, 20.0, 0.0, TAU, 48, Color(1.0, 0.86, 0.50, 0.95), 2.0, true)
			draw_arc(center, 25.0, 0.0, TAU, 48, Color(1.0, 0.86, 0.50, 0.35), 1.0, true)

	_draw_placement_labels(area)
	_draw_marker_labels()

	var selected := _map.marker_by_id(_selected_marker_id)
	if selected != null:
		var point := _local_point(_map.marker_point(selected))
		draw_circle(point, 18.0, Color(1.0, 0.88, 0.58, 0.12))
		draw_arc(point, 18.0, 0.0, TAU, 40, Color(1.0, 0.88, 0.58, 0.95), 2.0, true)

	_draw_player_marker(area)
	var view := _base_local_area()
	MapPaint.draw_compass_rose(self, Vector2(view.end.x - 44.0, view.end.y - 46.0), 22.0)
	if _metric and _map.has_world_bounds():
		_draw_scale_bar(area)
	if not _map.placements.is_empty():
		_draw_zoom_hint(view)


## Геометрия по координатам карты: площадки, скалы, обрывы и маршрут. На
## подложке региона это вставки реальных уровней. Слой UNAVAILABLE — туман.
func _draw_world_geometry(area: Rect2) -> void:
	var land := MapPaint.land_texture(_map.terrain_style)
	var on_painting := _map.background_texture != null
	for feature in _map.features:
		if feature == null or feature.points.size() < 2:
			continue
		var points := _map_points(_map.world_feature_points(feature), area)
		match feature.kind:
			MapFeature.Kind.WALKABLE:
				if points.size() < 3:
					continue
				draw_colored_polygon(_offset(points, Vector2(2, 3)), Color(0, 0, 0, 0.45))
				MapPaint.draw_textured_polygon(self, points, land, 200.0,
					Color(1.05, 1.05, 1.08, 0.92) if on_painting else Color.WHITE)
				MapPaint.draw_textured_polygon(self, points, MapPaint.relief_texture(), 140.0)
				draw_polyline(_closed_polygon(points), Color(0.02, 0.02, 0.02, 0.9), 1.4, true)
				draw_polyline(_closed_polygon(_scale_polygon(points, 0.97)),
					Color(1.0, 0.97, 0.88, 0.18), 1.0, true)
			MapFeature.Kind.BLOCKED:
				if points.size() < 3:
					continue
				draw_colored_polygon(_offset(points, Vector2(2, 3)), Color(0, 0, 0, 0.55))
				MapPaint.draw_textured_polygon(self, points, MapPaint.rock_texture(), 90.0)
				draw_polyline(_closed_polygon(points), Color(0.0, 0.0, 0.0, 0.9), 1.2, true)
			MapFeature.Kind.HAZARD:
				if points.size() < 3:
					continue
				draw_colored_polygon(points, Color(0.05, 0.02, 0.02, 0.55))
				draw_colored_polygon(points, Color(0.40, 0.06, 0.05, 0.28))
				_draw_dashed_outline(points, Color(0.86, 0.34, 0.25, 0.85))
			MapFeature.Kind.UNAVAILABLE:
				if points.size() < 3:
					continue
				MapPaint.draw_textured_polygon(self, points, MapPaint.fog_texture(), 160.0)
				_draw_dashed_outline(points, Color(0.80, 0.78, 0.72, 0.55))
			MapFeature.Kind.ROUTE:
				MapPaint.draw_road(self, points)
			MapFeature.Kind.EDGE:
				draw_polyline(points, Color(0.02, 0.02, 0.02, 1.0), 3.0, true)
				draw_polyline(_offset(points, Vector2(1.0, 0)), Color(0.86, 0.80, 0.68, 0.40), 1.0, true)


## Подписи локаций на карте региона (MapPlacement.label + label_offset).
func _draw_placement_labels(area: Rect2) -> void:
	if _map.placements.is_empty():
		return
	var font := MapPaint.serif_font(3)
	for placement in _map.placements:
		if placement == null or placement.label.is_empty():
			continue
		var at := area.position + _map.world_to_normalized(placement.center + placement.label_offset) * area.size
		var current := placement.location_id == _current_location_id
		var color := Color(1.0, 0.90, 0.62) if current else MapPaint.INK
		MapPaint.draw_label(self, font, at, placement.label, 14, color, 5)


## Подписи маркеров без наложений. На карте региона подписываются только
## выбранный маркер и задания: остальные видны в списке и подсказке, как в
## картах больших RPG.
func _draw_marker_labels() -> void:
	var font := MapPaint.serif_font(1)
	var font_size := 12
	var markers: Array[MapMarker] = []
	for marker in _map.visible_markers(_flags):
		if _shows_marker(marker):
			markers.append(marker)
	# Подписи всех мест — только вплотную; при общем виде — задания и выбранное.
	var dense := not _map.placements.is_empty() and _zoom < DETAIL_ZOOM + 0.8
	var occupied: Array[Rect2] = []
	for marker in markers:
		occupied.append(Rect2(_local_point(_map.marker_point(marker)) - Vector2(13, 13), Vector2(26, 26)))

	var ordered := markers.duplicate()
	ordered.sort_custom(func(a: MapMarker, b: MapMarker) -> bool:
		return _label_priority(a) > _label_priority(b)
	)
	for marker in ordered:
		if dense and marker.id != _selected_marker_id and not marker.is_objective():
			continue
		var center := _local_point(_map.marker_point(marker))
		var width := font.get_string_size(marker.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		for anchor in [
			Vector2(0.0, 28.0),
			Vector2(width * 0.5 + 18.0, 5.0),
			Vector2(-width * 0.5 - 18.0, 5.0),
		]:
			var at: Vector2 = center + anchor
			var rect := Rect2(at + Vector2(-width * 0.5 - 2.0, -font_size), Vector2(width + 4.0, font_size + 4.0))
			if not Rect2(Vector2.ZERO, size).encloses(rect):
				continue
			var free := true
			for other in occupied:
				if other.intersects(rect):
					free = false
					break
			if free:
				MapPaint.draw_label(self, font, at, marker.label, font_size)
				occupied.append(rect)
				break


func _label_priority(marker: MapMarker) -> int:
	if marker.id == _selected_marker_id:
		return 10
	if marker.is_objective():
		return 8
	match marker.kind:
		MapMarker.Kind.QUEST:
			return 6
		MapMarker.Kind.CAMP:
			return 5
		MapMarker.Kind.DANGER:
			return 3
	return 4


## Заглушка для карт без геометрии: условный контур, река и дорога.
func _draw_stub_geometry(area: Rect2) -> void:
	var points := _map_points(_map.get_contour(), area)
	draw_colored_polygon(_offset(points, Vector2(7.0, 9.0)), Color(0.0, 0.0, 0.0, 0.40))
	MapPaint.draw_textured_polygon(self, points, MapPaint.land_texture(_map.terrain_style), 260.0)
	MapPaint.draw_textured_polygon(self, points, MapPaint.relief_texture(), 180.0)
	draw_polyline(_closed_polygon(points), Color(0.02, 0.02, 0.02, 0.85), 2.0, true)
	draw_polyline(PackedVector2Array([
		_local_point(Vector2(0.23, 0.18)),
		_local_point(Vector2(0.33, 0.35)),
		_local_point(Vector2(0.30, 0.53)),
		_local_point(Vector2(0.43, 0.72)),
		_local_point(Vector2(0.60, 0.86)),
	]), Color(0.30, 0.42, 0.46, 0.60), 3.0, true)
	MapPaint.draw_road(self, PackedVector2Array([
		_local_point(Vector2(0.17, 0.70)),
		_local_point(Vector2(0.48, 0.54)),
		_local_point(Vector2(0.79, 0.37)),
	]))


func _draw_fallback_marks(area: Rect2) -> void:
	_draw_dashed_outline(PackedVector2Array([
		area.position, Vector2(area.end.x, area.position.y),
		area.end, Vector2(area.position.x, area.end.y),
	]), Color(0.62, 0.53, 0.37, 0.45))
	MapPaint.draw_label(self, MapPaint.serif_font(2),
		Vector2(area.get_center().x, area.end.y - 18.0),
		"СХЕМА-ЗАГЛУШКА · МАРКЕРЫ НЕ ЗАДАНЫ", 12, MapPaint.INK_DIM)


## Живой маркер игрока: стрелка направления в кольце.
func _draw_player_marker(area: Rect2) -> void:
	if not _has_player or _map == null or not _map.has_world_bounds():
		return
	var point := area.position + _map.world_to_normalized(_player_world) * area.size
	var dir := _player_forward.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(0.0, -1.0)
	var side := Vector2(-dir.y, dir.x)
	var ink := MapPaint.INK
	draw_circle(point, 22.0, Color(1.0, 0.95, 0.80, 0.12))
	draw_arc(point, 21.0, 0.0, TAU, 48, Color(0, 0, 0, 0.7), 4.0, true)
	draw_arc(point, 21.0, 0.0, TAU, 48, Color(ink, 0.95), 2.0, true)
	var arrow := PackedVector2Array([
		point + dir * 16.0,
		point - dir * 7.0 + side * 8.0,
		point - dir * 2.5,
		point - dir * 7.0 - side * 8.0,
	])
	draw_colored_polygon(_offset(arrow, Vector2(1.5, 2.0)), Color(0, 0, 0, 0.6))
	draw_colored_polygon(arrow, ink)
	draw_polyline(_closed_polygon(arrow), Color(0.05, 0.04, 0.03, 0.9), 1.2, true)


## Масштаб в метрах для карт сцен: подбирается «круглая» длина 60–160 px.
func _draw_scale_bar(area: Rect2) -> void:
	var px_per_meter := area.size.x / _map.world_bounds.size.x
	var meters := 1.0
	for candidate in [1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0]:
		meters = candidate
		if candidate * px_per_meter >= 60.0:
			break
	var length := meters * px_per_meter
	var origin := Vector2(size.x - 40.0 - length, size.y - 34.0)
	draw_line(origin, origin + Vector2(length, 0), Color(0, 0, 0, 0.8), 5.0)
	draw_line(origin, origin + Vector2(length * 0.5, 0), MapPaint.INK, 3.0)
	draw_line(origin + Vector2(length * 0.5, 0), origin + Vector2(length, 0), Color(0.25, 0.22, 0.18), 3.0)
	MapPaint.draw_label(self, MapPaint.serif_font(), origin + Vector2(length * 0.5, -8.0),
		"%d м" % int(meters), 11, MapPaint.INK, 3)


# --- Общая карта -------------------------------------------------------------

func _draw_world_map() -> void:
	if _world_map == null:
		return
	var area := _world_area()
	_draw_background(_world_map, area)

	for region in _regions:
		if region != null and not region.outside_realm:
			_draw_realm_region(region, area)
	var realm_end := area.position.x + _world_map.background_rect.end.x * area.size.x
	var compass := Vector2(area.position.x + 44.0, area.end.y - 46.0)
	var occupied: Array[Rect2] = [
		Rect2(Vector2(realm_end - 2.0, area.position.y), Vector2(area.end.x - realm_end + 2.0, area.size.y)),
		Rect2(compass - Vector2(34, 46), Vector2(68, 80)),
	]
	for region in _regions:
		if region != null and not region.outside_realm:
			occupied.append(_draw_region_label(region, area))
	_draw_landmarks(area, occupied)

	_draw_outside_column(area)
	MapPaint.draw_compass_rose(self, compass, 22.0)


func _draw_realm_region(region: MapRegion, area: Rect2) -> void:
	if region.outline.size() < 3:
		return
	var points := _map_points(region.outline, area)
	var hovered := region == _hover_region
	if hovered:
		draw_colored_polygon(points, Color(1.0, 0.92, 0.70, 0.10))
		draw_polyline(_closed_polygon(points), Color(1.0, 0.88, 0.58, 0.9), 2.0, true)
	else:
		_draw_dashed_outline(points, Color(0.04, 0.035, 0.03, 0.55))
	if region.id == _current_region_id:
		_draw_here_mark(area.position + region.label_position * area.size + Vector2(0, -26))


## Подпись региона; возвращает занятый ею прямоугольник.
func _draw_region_label(region: MapRegion, area: Rect2) -> Rect2:
	var at := area.position + region.label_position * area.size
	var font := MapPaint.serif_font(3)
	var title_color := MapPaint.INK if region.is_playable() else Color(0.90, 0.86, 0.76, 0.95)
	MapPaint.draw_label(self, font, at, region.title, 14, title_color, 5)
	var status_color := Color(MapPaint.GOLD, 0.95) if region.is_playable() else Color(0.72, 0.68, 0.60, 0.95)
	MapPaint.draw_label(self, MapPaint.serif_font(1), at + Vector2(0, 14.0),
		region.status_title(), 9, status_color, 3)
	var width := font.get_string_size(region.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	return Rect2(at + Vector2(-width * 0.5 - 2.0, -14.0), Vector2(width + 4.0, 32.0))


## Ключевые места Царства: точка и подпись, без кнопок — регионы в разработке.
## Подпись ставится сверху, справа, слева или снизу — где не занято.
func _draw_landmarks(area: Rect2, occupied: Array[Rect2]) -> void:
	var font := MapPaint.serif_font(0)
	var font_size := 10
	for marker in _world_map.markers:
		if marker != null:
			var point := area.position + _world_map.marker_point(marker) * area.size
			occupied.append(Rect2(point - Vector2(5, 5), Vector2(10, 10)))
	for marker in _world_map.markers:
		if marker == null:
			continue
		var point := area.position + _world_map.marker_point(marker) * area.size
		var tint := color_for(marker.kind)
		draw_circle(point + Vector2(1, 1.5), 4.5, Color(0, 0, 0, 0.7))
		draw_circle(point, 4.0, Color(0.06, 0.05, 0.04))
		draw_circle(point, 2.6, tint)
		var width := font.get_string_size(marker.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		for anchor in [
			Vector2(0, -8.0),
			Vector2(width * 0.5 + 8.0, 4.0),
			Vector2(-width * 0.5 - 8.0, 4.0),
			Vector2(0, 16.0),
		]:
			var at: Vector2 = point + anchor
			var rect := Rect2(at + Vector2(-width * 0.5 - 1.0, -font_size), Vector2(width + 2.0, font_size + 3.0))
			var free := true
			for other in occupied:
				if other.intersects(rect):
					free = false
					break
			if free:
				MapPaint.draw_label(self, font, at, marker.label, font_size, Color(0.95, 0.92, 0.84, 0.95), 3)
				occupied.append(rect)
				break


## Колонка справа: регионы вне Царства снов вставками с миниатюрой их карты.
func _draw_outside_column(area: Rect2) -> void:
	var column_x := area.position.x + _world_map.background_rect.end.x * area.size.x
	var column := Rect2(Vector2(column_x, area.position.y), Vector2(area.end.x - column_x, area.size.y))
	MapPaint.draw_label(self, MapPaint.serif_font(2), Vector2(column.get_center().x, column.position.y + 26.0),
		"ЗА ПРЕДЕЛАМИ", 11, Color(MapPaint.GOLD, 0.95), 3)
	MapPaint.draw_label(self, MapPaint.serif_font(2), Vector2(column.get_center().x, column.position.y + 40.0),
		"ЦАРСТВА СНОВ", 11, Color(MapPaint.GOLD, 0.95), 3)

	for region in _regions:
		if region == null or not region.outside_realm:
			continue
		var normalized := region.outline_rect()
		var rect := Rect2(area.position + normalized.position * area.size, normalized.size * area.size)
		var hovered := region == _hover_region and region.is_playable()
		draw_rect(Rect2(rect.position + Vector2(4, 6), rect.size), Color(0, 0, 0, 0.55))
		var texture := region.region_map.background_texture if region.region_map != null else null
		if texture != null:
			var src := _cover_source(texture, rect.size)
			draw_texture_rect_region(texture, rect, src)
		else:
			draw_rect(rect, Color(0.12, 0.12, 0.12))
		if not region.is_playable():
			draw_rect(rect, Color(0, 0, 0, 0.55))
		draw_rect(rect, Color(0, 0, 0, 0.9), false, 4.0)
		draw_rect(rect, Color(1.0, 0.88, 0.58) if hovered else Color(MapPaint.GOLD, 0.85), false, 2.0 if hovered else 1.5)
		draw_rect(rect.grow(-5.0), Color(MapPaint.GOLD, 0.30), false, 1.0)
		if region.id == _current_region_id:
			_draw_here_mark(rect.position + Vector2(16, 16))
		var at := area.position + region.label_position * area.size
		MapPaint.draw_label(self, MapPaint.serif_font(2), at, region.title, 12,
			Color(1.0, 0.95, 0.82) if hovered else MapPaint.INK, 4)
		MapPaint.draw_label(self, MapPaint.serif_font(1), at + Vector2(0, 13.0), region.subtitle, 9,
			Color(0.80, 0.76, 0.68, 0.95), 3)


## Кадрирование текстуры под прямоугольник без искажения (как object-fit: cover).
func _cover_source(texture: Texture2D, target: Vector2) -> Rect2:
	var tex_size := Vector2(texture.get_width(), texture.get_height())
	var scale := maxf(target.x / tex_size.x, target.y / tex_size.y)
	var src_size := target / scale
	return Rect2((tex_size - src_size) * 0.5, src_size)


## Отметка «вы здесь» на общей карте: кольцо с точкой.
func _draw_here_mark(center: Vector2) -> void:
	draw_circle(center, 11.0, Color(0, 0, 0, 0.6))
	draw_arc(center, 9.0, 0.0, TAU, 32, MapPaint.INK, 2.0, true)
	draw_circle(center, 3.5, MapPaint.INK)


func _draw_dashed_outline(points: PackedVector2Array, color: Color) -> void:
	_draw_dashed_polyline(_closed_polygon(points), color)


func _draw_dashed_polyline(points: PackedVector2Array, color: Color) -> void:
	for index in range(points.size() - 1):
		draw_dashed_line(points[index], points[index + 1], color, 1.5, 8.0, true, true)


## Подсказка в углу карты региона: приближение и что появится вплотную.
func _draw_zoom_hint(view: Rect2) -> void:
	var text := "КОЛЕСО — ПРИБЛИЖЕНИЕ · ×%.1f" % _zoom
	if _zoom < DETAIL_ZOOM:
		text += " · ПРИБЛИЗЬТЕ, ЧТОБЫ УВИДЕТЬ ВСЕ МЕСТА"
	var font := MapPaint.serif_font(1)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	MapPaint.draw_label(self, font, Vector2(view.position.x + 14.0 + width * 0.5, view.end.y - 12.0),
		text, 10, Color(MapPaint.GOLD, 0.9), 3)


func _pin_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	style.shadow_size = 3
	return style


# --- Геометрия холста --------------------------------------------------------

## Область карты с учётом приближения и сдвига.
func _local_area() -> Rect2:
	var base := _base_local_area()
	if is_equal_approx(_zoom, 1.0):
		return base
	var zoomed := base.size * _zoom
	return Rect2(base.get_center() + _pan - zoomed * 0.5, zoomed)


## Область карты региона/локации без приближения: пропорции world_bounds сохраняются.
func _base_local_area() -> Rect2:
	var margin := Vector2(minf(30.0, size.x * 0.04), minf(26.0, size.y * 0.05))
	var inner := Rect2(margin, size - margin * 2.0)
	if _map != null and _map.has_world_bounds() and _map.preserve_aspect:
		return _fit_area(inner, _map.world_bounds.size.x / _map.world_bounds.size.y)
	return inner


## Область общей карты: растр Царства в background_rect сохраняет пропорции,
## остаток справа — колонка регионов вне Царства.
func _world_area() -> Rect2:
	var margin := Vector2(minf(24.0, size.x * 0.03), minf(22.0, size.y * 0.045))
	var inner := Rect2(margin, size - margin * 2.0)
	var ratio := 1.6667
	if _world_map != null and _world_map.background_texture != null:
		var texture := _world_map.background_texture
		var tex_ratio := float(texture.get_width()) / float(texture.get_height())
		ratio = tex_ratio * _world_map.background_rect.size.y / _world_map.background_rect.size.x
	return _fit_area(inner, ratio)


func _fit_area(inner: Rect2, ratio: float) -> Rect2:
	var fitted := inner.size
	if inner.size.x / inner.size.y > ratio:
		fitted.x = inner.size.y * ratio
	else:
		fitted.y = inner.size.x / ratio
	return Rect2(inner.position + (inner.size - fitted) * 0.5, fitted)


func _local_point(normalized: Vector2) -> Vector2:
	var area := _local_area()
	return area.position + normalized * area.size


func _map_points(normalized: PackedVector2Array, area: Rect2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in normalized:
		result.append(area.position + point * area.size)
	return result


func _offset(points: PackedVector2Array, delta: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point + delta)
	return result


func _polygon_center(points: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for point in points:
		center += point
	return center / float(maxi(points.size(), 1))


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
	var center := _polygon_center(points)
	var result := PackedVector2Array()
	for point in points:
		result.append(center + (point - center) * factor)
	return result


func _on_marker_pressed(marker: MapMarker) -> void:
	_selected_marker_id = marker.id
	queue_redraw()
	marker_selected.emit(marker)
