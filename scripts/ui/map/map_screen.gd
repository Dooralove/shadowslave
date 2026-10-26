class_name MapScreen
extends CanvasLayer
## Единый экран карты для всех локаций и общей карты мира.
##
## Сцена не дублируется под каждую локацию: MapScreen получает MapDefinition
## из MapAtlas и переключается между локальным и мировым видом. Закрытие
## обрабатывает MapSystem, чтобы пауза и режим мыши восстанавливались в одном
## месте для любого способа закрытия.

signal close_requested
signal location_viewed(location: MapDefinition)

enum View { LOCAL, WORLD }

const KICKER_LOCAL := "ЛОКАЛЬНАЯ КАРТА"
const KICKER_WORLD := "ОБЩАЯ КАРТА МИРА"
const HINT_LOCAL := "M / ESC — закрыть  ·  клик по маркеру — подробности"
const HINT_WORLD := "M / ESC — закрыть  ·  доступный регион открывает свою карту"

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
var current_location: MapDefinition
var displayed_location: MapDefinition
var showing_world := false

var _marker_rows: Dictionary = {}
var _location_rows: Dictionary = {}


func _ready() -> void:
	visible = false
	world_button.pressed.connect(_on_mode_pressed)
	close_button.pressed.connect(_request_close)
	map_canvas.marker_selected.connect(_on_marker_selected)
	map_canvas.location_selected.connect(_on_location_selected)
	map_canvas.location_hovered.connect(_on_location_hovered)


func setup(map_atlas: MapAtlas) -> void:
	atlas = map_atlas


func is_open() -> bool:
	return visible


## Открывает карту конкретной локации. Вызывается из MapSystem при нажатии M.
func open_for_location(location: MapDefinition) -> void:
	if location == null:
		return
	current_location = location
	visible = true
	_show_local(location)
	world_button.grab_focus()
	location_viewed.emit(location)


func close_screen() -> void:
	visible = false
	showing_world = false


func show_world() -> void:
	if atlas == null or atlas.world_map == null:
		return
	visible = true
	showing_world = true
	var current_id := current_location.id if current_location != null else &""
	map_canvas.show_world(atlas.world_map, atlas.locations, current_id)
	_update_header()
	_build_location_list()
	_show_detail(
		atlas.world_map.title,
		atlas.world_map.description,
		"Выберите регион на карте или в списке"
	)
	world_button.grab_focus()


## Открывает локальную карту по id — из списка регионов или из теста.
func open_location_by_id(location_id: StringName) -> bool:
	if atlas == null:
		return false
	var location := atlas.get_location(location_id)
	if location == null or not location.available:
		return false
	visible = true
	_show_local(location)
	location_viewed.emit(location)
	return true


func _show_local(location: MapDefinition) -> void:
	displayed_location = location
	showing_world = false
	var current_id := current_location.id if current_location != null else location.id
	map_canvas.show_local(location, current_id)
	_update_header()
	_build_marker_list()
	_show_detail(
		location.title,
		location.description,
		"Маркеров: %d" % location.markers.size()
	)


func _update_header() -> void:
	var is_fallback := displayed_location != null and displayed_location.is_fallback

	if showing_world and atlas != null and atlas.world_map != null:
		kicker_label.text = KICKER_WORLD
		title_label.text = atlas.world_map.title
		subtitle_label.text = atlas.world_map.subtitle
		world_button.text = "К ТЕКУЩЕЙ ЛОКАЦИИ"
		world_button.disabled = current_location == null
		side_kicker.text = "РЕГИОНЫ"
		side_title.text = "РЕГИОНЫ · %d" % atlas.locations.size()
		breadcrumb.text = "КАРТА МИРА · ВЫБЕРИТЕ РЕГИОН"
		hint_label.text = HINT_WORLD
		return

	kicker_label.text = "УНИВЕРСАЛЬНАЯ КАРТА" if is_fallback else KICKER_LOCAL
	title_label.text = displayed_location.title if displayed_location != null else "Карта"
	subtitle_label.text = displayed_location.subtitle if displayed_location != null else ""
	world_button.text = "КАРТА МИРА"
	world_button.disabled = atlas == null or atlas.world_map == null
	side_kicker.text = "ОРИЕНТИРЫ"
	var marker_count := displayed_location.markers.size() if displayed_location != null else 0
	side_title.text = "ОРИЕНТИРЫ · %d" % marker_count

	var viewing_other := (
		current_location != null
		and displayed_location != null
		and displayed_location.id != current_location.id
	)
	var suffix := " · ПРОСМОТР" if viewing_other else ""
	breadcrumb.text = "ЛОКАЛЬНАЯ КАРТА · %s%s" % [
		displayed_location.title.to_upper() if displayed_location != null else "",
		suffix,
	]
	hint_label.text = HINT_LOCAL


func _build_marker_list() -> void:
	_clear_list()
	_marker_rows.clear()

	if displayed_location == null or displayed_location.markers.is_empty():
		var empty := Label.new()
		empty.text = "Маркеров пока нет.\nПоказан только контур карты."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.58, 0.59, 0.56))
		list_container.add_child(empty)
		return

	var group := ButtonGroup.new()
	for marker in displayed_location.markers:
		if marker == null:
			continue
		var tint := MapCanvas.color_for(marker.kind)
		var row := _make_row(
			"%s   %s" % [MapCanvas.symbol_for(marker.kind), marker.label],
			false, 34.0
		)
		row.toggle_mode = true
		row.button_group = group
		row.add_theme_color_override("font_color", tint)
		row.tooltip_text = "%s\n%s" % [marker.kind_title(), marker.description]
		row.pressed.connect(_on_marker_row_pressed.bind(marker))
		list_container.add_child(row)
		_marker_rows[marker.id] = row


func _build_location_list() -> void:
	_clear_list()
	_location_rows.clear()

	if atlas == null or atlas.locations.is_empty():
		var empty := Label.new()
		empty.text = "Регионы ещё не добавлены в атлас."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.58, 0.59, 0.56))
		list_container.add_child(empty)
		return

	for location in atlas.locations:
		if location == null:
			continue
		var is_current := current_location != null and location.id == current_location.id
		var status := "ТЕКУЩАЯ ЛОКАЦИЯ" if is_current else (
			"ДОСТУПЕН" if location.available else "ЗАКРЫТО"
		)
		var prefix := "●  " if is_current else "    "
		var row := _make_row(
			"%s%s\n    %s" % [prefix, location.title, status],
			not location.available,
			50.0
		)
		if is_current:
			row.add_theme_color_override("font_color", Color(0.96, 0.84, 0.56))
		elif not location.available:
			row.add_theme_color_override("font_disabled_color", Color(0.48, 0.48, 0.46))
		row.tooltip_text = location.description
		row.pressed.connect(_on_location_row_pressed.bind(location))
		row.mouse_entered.connect(_on_location_hovered.bind(location))
		row.focus_entered.connect(_on_location_hovered.bind(location))
		list_container.add_child(row)
		_location_rows[location.id] = row


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
	row.add_theme_color_override("font_disabled_color", Color(0.50, 0.50, 0.47))
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


func _show_marker_detail(marker: MapMarker) -> void:
	_show_detail(
		marker.label,
		marker.description,
		"%s · %s" % [marker.kind_title(), String(marker.id)]
	)


func _show_location_detail(location: MapDefinition) -> void:
	if location == null:
		return
	var status := "Текущая локация"
	if current_location == null or location.id != current_location.id:
		status = "Регион доступен" if location.available else "Регион закрыт"
	_show_detail(location.title, location.description, status)


func _on_mode_pressed() -> void:
	if showing_world:
		var target := current_location if current_location != null else displayed_location
		if target != null:
			_show_local(target)
		else:
			show_world()
	else:
		show_world()


func _on_marker_row_pressed(marker: MapMarker) -> void:
	if marker == null:
		return
	map_canvas.highlight_marker(marker.id)
	_show_marker_detail(marker)


func _on_marker_selected(marker: MapMarker) -> void:
	if marker == null:
		return
	for marker_id in _marker_rows:
		var row := _marker_rows[marker_id] as Button
		if row != null:
			row.set_pressed_no_signal(StringName(marker_id) == marker.id)
	_show_marker_detail(marker)


func _on_location_row_pressed(location: MapDefinition) -> void:
	if location == null or not location.available:
		return
	open_location_by_id(location.id)


func _on_location_selected(location_id: StringName) -> void:
	open_location_by_id(location_id)


func _on_location_hovered(location: MapDefinition) -> void:
	if showing_world:
		_show_location_detail(location)


func _request_close() -> void:
	close_requested.emit()
