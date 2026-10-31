class_name MapScreen
extends CanvasLayer
## Экран карты: общая карта мира и карта региона.
##
## Общая карта — всё Царство снов и регионы вне его. Карта региона — рисованная
## подложка, на которой собраны все локации региона с их реальной геометрией и
## положением игрока. Карты отдельных локаций в этом экране не открываются: это
## данные для будущей мини-карты (MapSystem.minimap_snapshot). Закрытие
## обрабатывает MapSystem, чтобы пауза и мышь восстанавливались в одном месте.

signal close_requested
signal location_viewed(location: MapDefinition)

const KICKER_REGION := "КАРТА РЕГИОНА"
const KICKER_WORLD := "ОБЩАЯ КАРТА"
const HINT_REGION := "M / ESC — закрыть  ·  C — персонаж  ·  клик по значку — подробности"
const HINT_WORLD := "M / ESC — закрыть  ·  доступный регион открывает свою карту  ·  остальные в разработке"
const BUTTON_WORLD := "КАРТА МИРА"
const BUTTON_REGION := "КАРТА РЕГИОНА"

@onready var kicker_label: Label = %Kicker
@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var world_button: Button = %WorldButton
@onready var close_button: Button = %CloseButton
@onready var map_canvas: MapCanvas = %MapCanvas
@onready var side_kicker: Label = %SideKicker
@onready var side_title: Label = %SideTitle
@onready var list_container: VBoxContainer = %List
@onready var detail_title: Label = %DetailTitle
@onready var detail_meta: Label = %DetailMeta
@onready var detail_text: Label = %DetailText
@onready var breadcrumb: Label = %Breadcrumb
@onready var hint_label: Label = %HintLabel

var atlas: MapAtlas
## Локация текущей сцены (может быть заглушкой вне атласа).
var current_location: MapDefinition
## Регион, карта которого открыта (null на общей карте).
var displayed_region: MapRegion
## Собранная карта открытого региона (MapAtlas.compose_region_map).
var displayed_map: MapDefinition
var showing_world := false

var _marker_rows: Dictionary = {}
var _region_rows: Dictionary = {}
var _live_player_shown := false
var _live_player_world := Vector2.ZERO
var _live_player_forward := Vector2.ZERO


func _ready() -> void:
	visible = false
	world_button.pressed.connect(_on_mode_pressed)
	close_button.pressed.connect(_request_close)
	map_canvas.marker_selected.connect(_on_marker_selected)
	map_canvas.region_selected.connect(_on_region_selected)
	map_canvas.region_hovered.connect(_on_region_hovered)


func setup(map_atlas: MapAtlas) -> void:
	atlas = map_atlas


func is_open() -> bool:
	return visible


## Живой маркер игрока в координатах сцены текущей локации. Передаётся до
## open_for_location; на карте региона переводится через размещение локации.
func set_player(world_xz: Vector2, forward_xz: Vector2, shown: bool) -> void:
	_live_player_shown = shown
	_live_player_world = world_xz
	_live_player_forward = forward_xz
	_apply_player()


## Открывает карту для локации текущей сцены: карту её региона, а если
## локация вне регионов — общую карту. Вызывается из MapSystem по M.
func open_for_location(location: MapDefinition) -> void:
	if location == null:
		return
	current_location = location
	visible = true
	var region := current_region()
	if region == null or not show_region(region):
		show_world()
	world_button.grab_focus()
	location_viewed.emit(location)


func close_screen() -> void:
	visible = false
	showing_world = false


## Общая карта: Царство снов и регионы вне его.
func show_world() -> void:
	if atlas == null or atlas.world_map == null:
		return
	visible = true
	showing_world = true
	displayed_region = null
	displayed_map = null
	map_canvas.show_world(atlas.world_map, atlas.regions, _current_region_id())
	map_canvas.hide_player()
	_update_header()
	_build_region_list()
	_show_detail(
		atlas.world_map.title,
		atlas.world_map.description,
		"Выберите регион на карте или в списке"
	)
	world_button.grab_focus()


## Карта региона. Регион в разработке не открывается.
func show_region(region: MapRegion) -> bool:
	if atlas == null or region == null or not region.is_playable():
		return false
	var map := atlas.compose_region_map(region)
	if map == null:
		return false
	visible = true
	showing_world = false
	displayed_region = region
	displayed_map = map
	map_canvas.show_local(map, _current_location_id(), {}, KICKER_REGION, false)
	_apply_player()
	_update_header()
	_build_marker_list()
	_show_detail(region.title, region.description, "%s · мест на карте: %d" % [
		region.subtitle, map.markers.size(),
	])
	return true


## Регион текущей локации (null — локация вне регионов).
func current_region() -> MapRegion:
	if atlas == null or current_location == null:
		return null
	return atlas.region_for_location(current_location.id)


func _current_location_id() -> StringName:
	return current_location.id if current_location != null else &""


func _current_region_id() -> StringName:
	var region := current_region()
	return region.id if region != null else &""


## Игрок показывается только на карте своего региона — в точке, куда его
## позицию в сцене переносит размещение текущей локации.
func _apply_player() -> void:
	if showing_world or displayed_region == null or not _live_player_shown:
		map_canvas.hide_player()
		return
	var point := atlas.to_region_point(displayed_region, _current_location_id(), _live_player_world)
	if point == Vector2.INF:
		map_canvas.hide_player()
		return
	map_canvas.set_player(
		point,
		atlas.to_region_direction(displayed_region, _current_location_id(), _live_player_forward)
	)


func _update_header() -> void:
	var region := current_region()
	if showing_world:
		world_button.text = BUTTON_REGION
		world_button.disabled = region == null or not region.is_playable()
		kicker_label.text = KICKER_WORLD
		title_label.text = atlas.world_map.title
		subtitle_label.text = atlas.world_map.subtitle
		side_kicker.text = "РЕГИОНЫ"
		side_title.text = "РЕГИОНЫ · %d" % atlas.regions.size()
		breadcrumb.text = "ОБЩАЯ КАРТА · ВЫБЕРИТЕ РЕГИОН"
		hint_label.text = HINT_WORLD
		return

	world_button.text = BUTTON_WORLD
	world_button.disabled = atlas == null or atlas.world_map == null
	kicker_label.text = KICKER_REGION
	title_label.text = displayed_region.title if displayed_region != null else "Карта"
	subtitle_label.text = displayed_map.subtitle if displayed_map != null else ""
	side_kicker.text = "МЕСТА"
	side_title.text = "МЕСТА · %d" % (displayed_map.markers.size() if displayed_map != null else 0)
	var viewing_other := displayed_region != null and displayed_region != region
	breadcrumb.text = "РЕГИОН · %s%s" % [
		displayed_region.title if displayed_region != null else "",
		" · ПРОСМОТР" if viewing_other else "",
	]
	hint_label.text = HINT_REGION


## Список мест карты региона, сгруппированный по локациям.
func _build_marker_list() -> void:
	_clear_list()
	_marker_rows.clear()
	if displayed_map == null or displayed_map.markers.is_empty():
		_add_note("Мест на карте пока нет.")
		return

	var group := ButtonGroup.new()
	var current_group := &"__none__"
	for marker in displayed_map.visible_markers({}):
		if marker.location_id != current_group:
			current_group = marker.location_id
			var placement := displayed_map.placement_for(marker.location_id)
			if placement != null:
				_add_group_header(placement.label, marker.location_id == _current_location_id())
		var tint := MapCanvas.color_for(marker.kind)
		var row := _make_row("%s   %s" % [MapCanvas.symbol_for(marker.kind), marker.label], false, 32.0)
		row.toggle_mode = true
		row.button_group = group
		row.add_theme_color_override("font_color", tint)
		row.tooltip_text = "%s\n%s" % [marker.kind_title(), marker.description]
		row.pressed.connect(_on_marker_row_pressed.bind(marker))
		list_container.add_child(row)
		_marker_rows[marker.id] = row


func _build_region_list() -> void:
	_clear_list()
	_region_rows.clear()
	if atlas == null or atlas.regions.is_empty():
		_add_note("Регионы ещё не добавлены в атлас.")
		return

	var outside_header_added := false
	_add_group_header("ЦАРСТВО СНОВ", false)
	for outside in [false, true]:
		for region in atlas.regions:
			if region == null or region.outside_realm != outside:
				continue
			if outside and not outside_header_added:
				_add_group_header("ЗА ПРЕДЕЛАМИ ЦАРСТВА", false)
				outside_header_added = true
			var is_current := region.id == _current_region_id()
			var prefix := "●  " if is_current else "    "
			var row := _make_row(
				"%s%s\n    %s" % [prefix, region.title, region.status_title()],
				not region.is_playable(),
				48.0
			)
			if is_current:
				row.add_theme_color_override("font_color", Color(0.96, 0.84, 0.56))
			row.tooltip_text = region.description
			row.pressed.connect(_on_region_row_pressed.bind(region))
			row.mouse_entered.connect(_on_region_hovered.bind(region))
			row.focus_entered.connect(_on_region_hovered.bind(region))
			list_container.add_child(row)
			_region_rows[region.id] = row


func _add_group_header(text: String, current: bool) -> void:
	var header := Label.new()
	header.text = ("●  " if current else "") + text
	header.add_theme_font_override("font", MapPaint.serif_font(2))
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.96, 0.84, 0.56) if current else MapPaint.GOLD)
	list_container.add_child(header)


func _add_note(text: String) -> void:
	var note := Label.new()
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.58, 0.59, 0.56))
	list_container.add_child(note)


func _make_row(text: String, disabled: bool, min_height: float) -> Button:
	var row := Button.new()
	row.text = text
	row.disabled = disabled
	row.custom_minimum_size = Vector2(0.0, min_height)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_theme_font_size_override("font_size", 13)
	row.add_theme_color_override("font_color", Color(0.82, 0.80, 0.73))
	row.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.82))
	row.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.68))
	row.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.82))
	row.add_theme_color_override("font_disabled_color", Color(0.56, 0.55, 0.51))
	row.add_theme_stylebox_override("normal", _row_style(
		Color(0.055, 0.07, 0.08, 0.55), Color(0.36, 0.31, 0.22, 0.35)
	))
	row.add_theme_stylebox_override("hover", _row_style(
		Color(0.14, 0.14, 0.12, 0.92), Color(0.73, 0.58, 0.32, 0.75)
	))
	row.add_theme_stylebox_override("pressed", _row_style(
		Color(0.23, 0.19, 0.12, 0.96), Color(0.92, 0.75, 0.42, 0.95)
	))
	row.add_theme_stylebox_override("focus", _row_style(
		Color(0.12, 0.13, 0.12, 0.92), Color(0.73, 0.58, 0.32, 0.85)
	))
	row.add_theme_stylebox_override("disabled", _row_style(
		Color(0.045, 0.052, 0.058, 0.45), Color(0.30, 0.30, 0.28, 0.30)
	))
	return row


func _row_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 10.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _clear_list() -> void:
	for child in list_container.get_children():
		# Не удаляем узел из дерева вручную: сигнал нажатия может прийти
		# именно от этой кнопки. Скрываем и освобождаем в конце кадра.
		child.visible = false
		child.queue_free()


func _show_detail(title: String, text: String, meta: String) -> void:
	detail_title.text = title
	detail_text.text = text if not text.is_empty() else "Описание пока не добавлено."
	detail_meta.text = meta


func _select_marker(marker: MapMarker) -> void:
	if marker == null:
		return
	map_canvas.highlight_marker(marker.id)
	for marker_id in _marker_rows:
		var row := _marker_rows[marker_id] as Button
		if row != null:
			row.set_pressed_no_signal(StringName(marker_id) == marker.id)
	var placement := displayed_map.placement_for(marker.location_id) if displayed_map != null else null
	_show_detail(
		marker.label,
		marker.description,
		"%s%s" % [marker.kind_title(), " · %s" % placement.label if placement != null else ""]
	)


## Кнопка в шапке: с карты региона — на общую карту, с общей — к региону игрока.
func _on_mode_pressed() -> void:
	if showing_world:
		var region := current_region()
		if region != null:
			show_region(region)
		return
	show_world()


func _on_marker_row_pressed(marker: MapMarker) -> void:
	_select_marker(marker)


func _on_marker_selected(marker: MapMarker) -> void:
	_select_marker(marker)


func _on_region_row_pressed(region: MapRegion) -> void:
	show_region(region)


func _on_region_selected(region: MapRegion) -> void:
	show_region(region)


func _on_region_hovered(region: MapRegion) -> void:
	if region == null or not showing_world:
		return
	_show_detail(region.title, region.description, "%s · %s" % [region.subtitle, region.status_title()])


func _request_close() -> void:
	close_requested.emit()
