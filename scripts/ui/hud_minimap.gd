class_name HudMinimap
extends Control
## Circular local minimap for the gameplay HUD.
##
## Map data comes from MapSystem.minimap_snapshot(); the map itself is drawn by
## HudMinimapCanvas inside a SubViewport and masked to a circle. The bronze
## compass ring and the region caption are drawn here, above the map texture.

const MAP_SIZE := 180.0
const MAP_CENTER := Vector2(95.0, 95.0)
const OUTER_RADIUS := 91.0
const INNER_RADIUS := 82.0
const LETTER_RADIUS := 71.0

@onready var _viewport: SubViewport = %Viewport
@onready var _canvas: HudMinimapCanvas = %MapCanvas
@onready var _map_texture: TextureRect = %MapTexture
@onready var _region_label: Label = %RegionLabel

var _refresh_timer := 0.0


func _ready() -> void:
	if _map_texture != null and _viewport != null:
		_map_texture.texture = _viewport.get_texture()
	_refresh()


func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = 0.12
	_refresh()


func _refresh() -> void:
	var system := get_node_or_null(^"/root/MapSystem")
	var snapshot: Dictionary = {}
	if system != null and system.has_method(&"minimap_snapshot"):
		var value: Variant = system.call(&"minimap_snapshot")
		if value is Dictionary:
			snapshot = value
	var map := snapshot.get("location") as MapDefinition
	var has_player := bool(snapshot.get("has_player", false))
	# Играбельная сцена без отдельной карты получает универсальную схему:
	# пустой компас лучше не показывать, но карта не должна исчезать у игрока.
	if map == null and has_player:
		map = MapDefinition.create_fallback("ОКРЕСТНОСТИ")
		snapshot["location"] = map
	visible = should_show_for(map, has_player)
	if not visible:
		return
	if _canvas != null:
		_canvas.set_snapshot(snapshot)
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _region_label != null:
		var title := "ОКРЕСТНОСТИ"
		if not map.title.strip_edges().is_empty():
			title = map.title.strip_edges().to_upper()
			if title.length() > 20:
				title = "ОКРЕСТНОСТИ"
		_region_label.text = title


## Реальная карта показывается всегда; универсальная заглушка — только когда
## в сцене есть игрок. Так видения и технические коридоры остаются без HUD.
static func should_show_for(map: MapDefinition, has_player: bool) -> bool:
	if map == null:
		return has_player
	if map.is_fallback:
		return has_player
	return true


func _draw() -> void:
	var center := MAP_CENTER
	draw_arc(center, OUTER_RADIUS, 0.0, TAU, 80, Color(0.66, 0.54, 0.36, 0.96), 2.0, true)
	draw_arc(center, INNER_RADIUS, 0.0, TAU, 80, Color(0.34, 0.28, 0.20, 0.72), 1.0, true)
	for index in 24:
		var angle := TAU * float(index) / 24.0 - PI * 0.5
		var direction := Vector2(cos(angle), sin(angle))
		var length := 8.0 if index % 6 == 0 else 4.0
		draw_line(
			center + direction * (OUTER_RADIUS - 2.0),
			center + direction * (OUTER_RADIUS - 2.0 - length),
			Color(0.72, 0.61, 0.42, 0.9),
			1.0,
			true
		)
	var font := ThemeDB.fallback_font
	if font != null:
		_draw_letter(font, center + Vector2(0, -LETTER_RADIUS), "N", Color(0.93, 0.83, 0.62, 0.98))
		_draw_letter(font, center + Vector2(LETTER_RADIUS, 0), "E", Color(0.76, 0.62, 0.42, 0.9))
		_draw_letter(font, center + Vector2(0, LETTER_RADIUS), "S", Color(0.76, 0.62, 0.42, 0.9))
		_draw_letter(font, center + Vector2(-LETTER_RADIUS, 0), "W", Color(0.76, 0.62, 0.42, 0.9))
	draw_circle(center, 1.8, Color(0.86, 0.75, 0.54, 0.9))


func _draw_letter(font: Font, point: Vector2, letter: String, color: Color) -> void:
	var font_size := 10
	var width := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(
		font,
		point + Vector2(-width * 0.5, font_size * 0.35),
		letter,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)
