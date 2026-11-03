class_name RpgMapScreen
extends Control
## Встроенная карта единого меню.
##
## Не заменяет MapSystem и полноэкранный MapScreen: использует тот же
## MapAtlas, MapCanvas и live-маркер игрока, но живёт внутри рабочей области
## меню, чтобы «Карта мира» была вкладкой одного окна, как в референсе.

const ATLAS_PATH := "res://resources/map/map_atlas.tres"

## Объективные цели квестов не всегда совпадают с id маркера карты.
## Таблица переводит target_id из QuestObjective в понятный маркер.
const OBJECTIVE_MARKER_ALIASES := {
	&"first_fork": &"first_fork",
	&"clearing": &"clearing",
	&"camp": &"camp",
	&"nephis": &"clearing",
	&"cassia": &"clearing",
	&"wounded_scavenger": &"wounded_scavenger",
	&"azure_blade": &"azure_blade",
	&"soul_shard": &"soul_shard_dry_pocket",
	&"carapace": &"hunting",
	&"hunting": &"hunting",
	&"bridge": &"bone_bridge",
	&"refuge": &"refuge",
	&"storm": &"storm",
	&"cliffs": &"cliffs",
}

var atlas: MapAtlas
var map_canvas: MapCanvas
var showing_world := false
var displayed_region: MapRegion
var displayed_map: MapDefinition

var _current_location: MapDefinition
var _list: VBoxContainer
var _side_title: Label
var _side_kicker: Label
var _kicker_label: Label
var _title_label: Label
var _subtitle_label: Label
var _objective_line: Label
var _world_button: Button
var _region_button: Button
var _detail_title: Label
var _detail_meta: Label
var _detail_text: Label
var _marker_rows: Dictionary = {}
var _region_rows: Dictionary = {}


func _ready() -> void:
	theme = RpgMenuTheme.build()
	_build_ui()
	if atlas == null:
		atlas = load(ATLAS_PATH) as MapAtlas
	refresh_from_game()


func setup(map_atlas: MapAtlas) -> void:
	var changed := map_atlas != atlas
	atlas = map_atlas
	if changed and is_inside_tree():
		refresh_from_game()


func refresh_from_game() -> void:
	if atlas == null:
		atlas = load(ATLAS_PATH) as MapAtlas
	if atlas == null or atlas.world_map == null:
		_show_detail("Карта недоступна", "Атлас карты не загружен.", "")
		return
	_current_location = _resolve_current_location()
	if _current_location != null:
		var region := atlas.region_for_location(_current_location.id)
		if region != null and region.is_playable() and show_region(region):
			return
		if _current_location.has_world_bounds():
			show_local(_current_location)
			return
	show_world()


func show_world() -> void:
	if atlas == null or atlas.world_map == null:
		return
	showing_world = true
	displayed_region = null
	displayed_map = null
	map_canvas.show_world(atlas.world_map, atlas.regions, _current_region_id())
	map_canvas.hide_player()
	_refresh_objective_line()
	_update_header()
	_build_region_list()
	_show_detail(
		atlas.world_map.title,
		atlas.world_map.description,
		"Выберите регион на карте или в списке"
	)


func show_region(region: MapRegion) -> bool:
	if atlas == null or region == null or not region.is_playable():
		return false
	var map := atlas.compose_region_map(region)
	if map == null:
		return false
	showing_world = false
	displayed_region = region
	displayed_map = map
	map_canvas.show_local(map, _current_location_id(), _game_flags(), "КАРТА РЕГИОНА", false)
	_apply_player()
	_refresh_objective_line()
	_highlight_tracked_objective()
	_update_header()
	_build_marker_list()
	_show_detail(
		region.title,
		region.description,
		"%s · мест на карте: %d" % [region.subtitle, map.markers.size()]
	)
	return true


## Карта отдельной сцены, у которой ещё нет региона или он в разработке.
## Показывает реальную геометрию этой сцены, а не заглушку мира.
func show_local(location: MapDefinition) -> bool:
	if location == null or not location.has_world_bounds():
		return false
	showing_world = false
	displayed_region = null
	displayed_map = location
	map_canvas.show_local(location, location.id, _game_flags(), "КАРТА МЕСТА", true)
	_apply_player()
	_refresh_objective_line()
	_highlight_tracked_objective()
	_update_header()
	_build_marker_list()
	_show_detail(
		location.title,
		location.description,
		"%s · мест на карте: %d" % [location.subtitle, location.markers.size()]
	)
	return true


func get_mode() -> String:
	if showing_world:
		return "world"
	if displayed_region == null and displayed_map != null:
		return "local"
	return "region"


func get_displayed_region_id() -> StringName:
	return displayed_region.id if displayed_region != null else &""


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)

	_kicker_label = Label.new()
	_kicker_label.text = "КАРТА МИРА"
	_kicker_label.theme_type_variation = &"OverlineLabel"
	titles.add_child(_kicker_label)

	_title_label = Label.new()
	_title_label.theme_type_variation = &"ScreenTitleSmall"
	titles.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.theme_type_variation = &"MutedLabel"
	titles.add_child(_subtitle_label)

	_objective_line = Label.new()
	_objective_line.theme_type_variation = &"BodyLabel"
	_objective_line.add_theme_color_override("font_color", RpgMenuTheme.BRONZE_BRIGHT)
	_objective_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_line.visible = false
	titles.add_child(_objective_line)

	_world_button = Button.new()
	_world_button.text = "ОБЩАЯ КАРТА"
	_world_button.theme_type_variation = &"SecondaryButton"
	_world_button.custom_minimum_size = Vector2(150, 38)
	_world_button.pressed.connect(show_world)
	header.add_child(_world_button)

	_region_button = Button.new()
	_region_button.text = "КАРТА РЕГИОНА"
	_region_button.theme_type_variation = &"SecondaryButton"
	_region_button.custom_minimum_size = Vector2(150, 38)
	_region_button.pressed.connect(_on_region_button_pressed)
	header.add_child(_region_button)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(0.27, 0.25, 0.21, 0.65)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)

	var map_panel := PanelContainer.new()
	map_panel.theme_type_variation = &"DeepPanel"
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.custom_minimum_size = Vector2(620, 480)
	body.add_child(map_panel)

	var map_margin := MarginContainer.new()
	map_margin.add_theme_constant_override("margin_left", 6)
	map_margin.add_theme_constant_override("margin_right", 6)
	map_margin.add_theme_constant_override("margin_top", 6)
	map_margin.add_theme_constant_override("margin_bottom", 6)
	map_panel.add_child(map_margin)

	map_canvas = MapCanvas.new()
	map_canvas.custom_minimum_size = Vector2(600, 450)
	map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_canvas.marker_selected.connect(_on_marker_selected)
	map_canvas.region_selected.connect(_on_region_selected)
	map_canvas.region_hovered.connect(_on_region_hovered)
	map_margin.add_child(map_canvas)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(360, 0)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 7)
	body.add_child(side)

	var side_head := HBoxContainer.new()
	side_head.add_theme_constant_override("separation", 8)
	side.add_child(side_head)

	_side_kicker = Label.new()
	_side_kicker.theme_type_variation = &"SectionLabel"
	_side_kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_head.add_child(_side_kicker)

	_side_title = Label.new()
	_side_title.theme_type_variation = &"TinyMutedLabel"
	side_head.add_child(_side_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)

	var detail_panel := PanelContainer.new()
	detail_panel.theme_type_variation = &"SubPanel"
	side.add_child(detail_panel)

	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 3)
	detail_panel.add_child(detail_box)

	_detail_title = Label.new()
	_detail_title.theme_type_variation = &"BodyLargeLabel"
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_detail_title)

	_detail_meta = Label.new()
	_detail_meta.theme_type_variation = &"TinyMutedLabel"
	_detail_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_detail_meta)

	_detail_text = Label.new()
	_detail_text.theme_type_variation = &"MutedLabel"
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.custom_minimum_size = Vector2(0, 52)
	detail_box.add_child(_detail_text)

	var footer := Label.new()
	footer.text = "КОЛЕСО — ПРИБЛИЖЕНИЕ · ПЕРЕТАСКИВАНИЕ — СДВИГ · КЛИК ПО ЗНАЧКУ — ПОДРОБНОСТИ"
	footer.theme_type_variation = &"TinyMutedLabel"
	column.add_child(footer)


func _update_header() -> void:
	if showing_world:
		_kicker_label.text = "КАРТА МИРА · ЦАРСТВО СНОВ"
		_title_label.text = atlas.world_map.title
		_subtitle_label.text = atlas.world_map.subtitle
		_side_kicker.text = "РЕГИОНЫ"
		_side_title.text = "%d" % atlas.regions.size()
		var current := _current_region()
		_region_button.disabled = current == null or not current.is_playable()
		return
	if displayed_region == null:
		_kicker_label.text = "КАРТА МЕСТА · %s" % (displayed_map.title if displayed_map != null else "ЛОКАЦИЯ")
		_title_label.text = displayed_map.title if displayed_map != null else "Карта"
		_subtitle_label.text = displayed_map.subtitle if displayed_map != null else ""
		_side_kicker.text = "МЕСТА"
		_side_title.text = "%d" % (displayed_map.markers.size() if displayed_map != null else 0)
		_region_button.disabled = true
		return
	_kicker_label.text = "КАРТА МИРА · %s" % displayed_region.title
	_title_label.text = displayed_region.title
	_subtitle_label.text = displayed_map.subtitle if displayed_map != null else ""
	_side_kicker.text = "МЕСТА"
	_side_title.text = "%d" % (displayed_map.markers.size() if displayed_map != null else 0)
	_region_button.disabled = false


func _build_region_list() -> void:
	_clear_list()
	_region_rows.clear()
	if atlas == null or atlas.regions.is_empty():
		_add_note("Регионы ещё не добавлены в атлас.")
		return
	_add_group_header("ЦАРСТВО СНОВ")
	var outside_header := false
	for outside in [false, true]:
		for region in atlas.regions:
			if region == null or region.outside_realm != outside:
				continue
			if outside and not outside_header:
				_add_group_header("ЗА ПРЕДЕЛАМИ ЦАРСТВА")
				outside_header = true
			var is_current := region.id == _current_region_id()
			var prefix := "●  " if is_current else "    "
			var row := _make_row(
				"%s%s\n    %s" % [prefix, region.title, region.status_title()],
				44.0
			)
			row.tooltip_text = region.description
			row.pressed.connect(_on_region_row_pressed.bind(region))
			row.mouse_entered.connect(_on_region_hovered.bind(region))
			row.focus_entered.connect(_on_region_hovered.bind(region))
			_list.add_child(row)
			_region_rows[region.id] = row


func _build_marker_list() -> void:
	_clear_list()
	_marker_rows.clear()
	if displayed_map == null or displayed_map.markers.is_empty():
		_add_note("Мест на карте пока нет.")
		return
	var group := ButtonGroup.new()
	var current_group := &"__none__"
	for marker in displayed_map.visible_markers(_game_flags()):
		if marker.location_id != current_group:
			current_group = marker.location_id
			var placement := displayed_map.placement_for(marker.location_id)
			if placement != null:
				_add_group_header(placement.label)
		var tint := MapCanvas.color_for(marker.kind)
		var row := _make_row(
			"%s   %s" % [MapCanvas.symbol_for(marker.kind), marker.label],
			30.0
		)
		row.toggle_mode = true
		row.button_group = group
		row.add_theme_color_override("font_color", tint)
		row.tooltip_text = "%s\n%s" % [marker.kind_title(), marker.description]
		row.pressed.connect(_on_marker_row_pressed.bind(marker))
		_list.add_child(row)
		_marker_rows[marker.id] = row


func _make_row(text: String, min_height: float) -> Button:
	var row := Button.new()
	row.text = text
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(0, min_height)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.theme_type_variation = &"ListButton"
	row.add_theme_font_size_override("font_size", 12)
	return row


func _add_group_header(text: String) -> void:
	var header := Label.new()
	header.text = String(text).to_upper()
	header.theme_type_variation = &"SectionLabel"
	header.add_theme_font_size_override("font_size", 10)
	header.custom_minimum_size.y = 18
	_list.add_child(header)


func _add_note(text: String) -> void:
	var note := Label.new()
	note.text = text
	note.theme_type_variation = &"MutedLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(note)


func _clear_list() -> void:
	for child in _list.get_children():
		child.visible = false
		child.queue_free()


func _show_detail(title: String, text: String, meta: String) -> void:
	_detail_title.text = title
	_detail_meta.text = meta
	_detail_text.text = text if not text.strip_edges().is_empty() else "Описание пока не добавлено."


func _on_region_button_pressed() -> void:
	var region := _current_region()
	if region != null:
		show_region(region)
	else:
		show_world()


func _on_region_row_pressed(region: MapRegion) -> void:
	if region == null:
		return
	if region.is_playable():
		show_region(region)
	else:
		_show_detail(region.title, region.description, "%s · %s" % [region.subtitle, region.status_title()])


func _on_region_selected(region: MapRegion) -> void:
	if region != null and region.is_playable():
		show_region(region)


func _on_region_hovered(region: MapRegion) -> void:
	if region == null or not showing_world:
		return
	_show_detail(region.title, region.description, "%s · %s" % [region.subtitle, region.status_title()])


func _on_marker_row_pressed(marker: MapMarker) -> void:
	_select_marker(marker)


func _on_marker_selected(marker: MapMarker) -> void:
	_select_marker(marker)


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


func _apply_player() -> void:
	if showing_world or displayed_map == null or atlas == null:
		map_canvas.hide_player()
		return
	var map_system := get_node_or_null("/root/MapSystem")
	if map_system == null or not map_system.has_method(&"player_state"):
		map_canvas.hide_player()
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		var player := get_tree().get_first_node_in_group(&"player") as Node
		scene_root = player.get_parent() if player != null else null
	var state: Variant = map_system.call(&"player_state", scene_root)
	if not state is Dictionary or not bool(state.get("found", false)):
		map_canvas.hide_player()
		return
	if displayed_region == null:
		# Локальная карта использует координаты сцены напрямую.
		map_canvas.set_player(state.get("position", Vector2.ZERO), state.get("forward", Vector2.ZERO))
		return
	var point := atlas.to_region_point(
		displayed_region,
		_current_location_id(),
		state.get("position", Vector2.ZERO)
	)
	if point == Vector2.INF:
		map_canvas.hide_player()
		return
	map_canvas.set_player(
		point,
		atlas.to_region_direction(
			displayed_region,
			_current_location_id(),
			state.get("forward", Vector2.ZERO)
		)
	)


func _resolve_current_location() -> MapDefinition:
	var map_system := get_node_or_null("/root/MapSystem")
	if map_system != null and map_system.has_method(&"resolve_current_location"):
		var value: Variant = map_system.call(&"resolve_current_location")
		if value is MapDefinition:
			return value
	# Резерв для редакторского запуска, где current_scene ещё не назначен.
	var player := get_tree().get_first_node_in_group(&"player") as Node
	if player != null and atlas != null:
		var found := atlas.find_location_for_scene(player.get_parent())
		if found != null:
			return found
	if atlas != null and not atlas.locations.is_empty():
		return atlas.locations[0]
	return null


func _current_region() -> MapRegion:
	if atlas == null or _current_location == null:
		return null
	return atlas.region_for_location(_current_location.id)


func _current_location_id() -> StringName:
	return _current_location.id if _current_location != null else &""


func _current_region_id() -> StringName:
	var region := _current_region()
	return region.id if region != null else &""


## Флаги игры для условных маркеров (убитые враги, подобранные осколки).
func _game_flags() -> Dictionary:
	var run_state := get_node_or_null(^"/root/NightmareRunState")
	if run_state == null or not run_state.has_method(&"snapshot"):
		return {}
	var snapshot: Variant = run_state.call(&"snapshot")
	if snapshot is Dictionary:
		var flags: Variant = (snapshot as Dictionary).get("flags", {})
		return flags if flags is Dictionary else {}
	return {}


func _tracked_objective_text() -> String:
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests != null and quests.has_method(&"is_scope_active") and bool(quests.call(&"is_scope_active")):
		return String(quests.call(&"get_tracked_objective_text")).strip_edges()
	var guide := get_node_or_null(^"/root/CampaignGuide")
	if guide != null:
		return String(guide.get(&"display_objective")).strip_edges()
	return ""


func _refresh_objective_line() -> void:
	if _objective_line == null:
		return
	var text := _tracked_objective_text()
	_objective_line.text = "ЦЕЛЬ · %s" % text if not text.is_empty() else ""
	_objective_line.visible = not text.is_empty()


## Подсвечивает маркер, соответствующий текущей цели. Если совпадения нет,
## карта остаётся без кольца, но строка цели всё равно видна.
func _highlight_tracked_objective() -> void:
	if map_canvas == null or displayed_map == null:
		return
	var target_id := _tracked_target_id()
	if target_id == &"":
		return
	var marker_id: StringName = OBJECTIVE_MARKER_ALIASES.get(target_id, target_id)
	var marker := _find_displayed_marker(marker_id)
	if marker == null and target_id == &"soul_shard":
		for candidate in [&"soul_shard_dry_pocket", &"soul_shard_tunnel", &"soul_shard_bridge"]:
			var item := _find_displayed_marker(candidate)
			if item != null and item.is_visible_with(_game_flags()):
				marker = item
				break
	if marker != null and marker.is_visible_with(_game_flags()):
		map_canvas.highlight_marker(marker.id)


func _find_displayed_marker(marker_id: StringName) -> MapMarker:
	if displayed_map == null:
		return null
	var direct := displayed_map.marker_by_id(marker_id)
	if direct != null:
		return direct
	var location_id := _current_location_id()
	if location_id != &"":
		return displayed_map.marker_by_id(StringName("%s/%s" % [location_id, marker_id]))
	return null


func _tracked_target_id() -> StringName:
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests != null and quests.has_method(&"is_scope_active") and bool(quests.call(&"is_scope_active")):
		var objective: Variant = quests.call(&"get_tracked_objective")
		if objective != null:
			return StringName(objective.get(&"target_id"))
	var guide := get_node_or_null(^"/root/CampaignGuide")
	if guide != null:
		var beat: Variant = guide.get(&"current_beat")
		if beat != null:
			return StringName(beat.get(&"guide_beacon_id"))
	return &""
