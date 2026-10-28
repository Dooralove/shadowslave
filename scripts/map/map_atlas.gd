class_name MapAtlas
extends Resource
## Связь игрового мира с картами.
##
## Атлас — единственное место, где перечислены все локации. MapSystem
## определяет по нему текущую карту, а MapScreen строит из него карту мира.
## Новая локация добавляется одним ресурсом MapDefinition и строкой здесь,
## без копирования UI-сцены или скрипта.

@export var world_map: MapDefinition
## Регионы общей карты. Каждый регион ссылается на локации по id.
@export var regions: Array[MapRegion] = []
@export var locations: Array[MapDefinition] = []

var _id_index: Dictionary = {}
var _scene_index: Dictionary = {}
var _indexed := false
var _composed: Dictionary = {}


func get_location(location_id: StringName) -> MapDefinition:
	_ensure_index()
	return _id_index.get(StringName(location_id), null) as MapDefinition


func get_region(region_id: StringName) -> MapRegion:
	for region in regions:
		if region != null and region.id == region_id:
			return region
	return null


## Регион, в который входит локация. Null — локация вне регионов (заглушки, песочницы).
func region_for_location(location_id: StringName) -> MapRegion:
	for region in regions:
		if region != null and region.has_location(location_id):
			return region
	return null


## Общая карта региона: подложка региона плюс геометрия и маркеры всех его
## локаций, перенесённые по размещениям (MapPlacement). Карты локаций при этом
## не меняются — они остаются данными для мини-карты.
func compose_region_map(region: MapRegion) -> MapDefinition:
	if region == null or region.region_map == null:
		return null
	if _composed.has(region.id):
		return _composed[region.id]

	var base := region.region_map
	var map := MapDefinition.new()
	map.id = base.id
	map.title = base.title
	map.subtitle = base.subtitle
	map.description = base.description
	map.background_color = base.background_color
	map.land_color = base.land_color
	map.accent_color = base.accent_color
	map.terrain_style = base.terrain_style
	map.world_bounds = base.world_bounds
	map.preserve_aspect = base.preserve_aspect
	map.background_texture = base.background_texture
	map.background_rect = base.background_rect
	map.placements = base.placements

	var features: Array[MapFeature] = []
	features.append_array(base.features)
	var markers: Array[MapMarker] = []
	markers.append_array(base.markers)
	for placement in base.placements:
		var location := get_location(placement.location_id) if placement != null else null
		if location == null or not location.has_world_bounds():
			continue
		var pivot := location.world_bounds.get_center()
		for feature in location.features:
			if feature == null:
				continue
			var moved := MapFeature.new()
			moved.kind = feature.kind
			moved.closed = feature.closed
			var points := PackedVector2Array()
			for point in feature.points:
				points.append(placement.to_region(point, pivot))
			moved.points = points
			features.append(moved)
		for marker in location.markers:
			if marker == null:
				continue
			var moved_marker := marker.duplicate() as MapMarker
			moved_marker.id = StringName("%s/%s" % [location.id, marker.id])
			moved_marker.use_world_position = true
			moved_marker.world_position = placement.to_region(_marker_world(location, marker), pivot)
			moved_marker.location_id = location.id
			markers.append(moved_marker)
	map.features = features
	map.markers = markers
	_composed[region.id] = map
	return map


## Точка локации на подложке её региона. Vector2.INF — локация не размещена.
func to_region_point(region: MapRegion, location_id: StringName, world_xz: Vector2) -> Vector2:
	var location := get_location(location_id)
	var placement := region.region_map.placement_for(location_id) if region != null and region.region_map != null else null
	if location == null or placement == null or not location.has_world_bounds():
		return Vector2.INF
	return placement.to_region(world_xz, location.world_bounds.get_center())


func to_region_direction(region: MapRegion, location_id: StringName, direction_xz: Vector2) -> Vector2:
	var placement := region.region_map.placement_for(location_id) if region != null and region.region_map != null else null
	return placement.direction_to_region(direction_xz) if placement != null else direction_xz


func _marker_world(location: MapDefinition, marker: MapMarker) -> Vector2:
	if marker.use_world_position:
		return marker.world_position
	return location.normalized_to_world(marker.position)


func find_location_for_scene_path(scene_path: String) -> MapDefinition:
	_ensure_index()
	return _scene_index.get(scene_path, null) as MapDefinition


## Ищет карту по корню текущей сцены. Сначала проверяются явные метаданные
## map_id / get_map_id(), затем scene_file_path самого узла и вложенных сцен.
func find_location_for_scene(scene_root: Node) -> MapDefinition:
	if scene_root == null:
		return null

	var direct := _find_for_node(scene_root)
	if direct != null:
		return direct

	for node in scene_root.find_children("*", "", true, false):
		var found := _find_for_node(node)
		if found != null:
			return found
	return null


func reset_cache() -> void:
	_indexed = false
	_id_index.clear()
	_scene_index.clear()
	_composed.clear()


func _find_for_node(node: Node) -> MapDefinition:
	if node == null:
		return null

	var explicit_id := &""
	if node.has_meta(&"map_id"):
		explicit_id = StringName(str(node.get_meta(&"map_id")))
	elif node.has_method(&"get_map_id"):
		explicit_id = StringName(str(node.call(&"get_map_id")))
	if explicit_id != &"":
		var by_id := get_location(explicit_id)
		if by_id != null:
			return by_id

	return find_location_for_scene_path(node.scene_file_path)


func _ensure_index() -> void:
	if _indexed:
		return
	_indexed = true
	_id_index.clear()
	_scene_index.clear()
	for location in locations:
		if location == null:
			continue
		if location.id != &"":
			_id_index[location.id] = location
		for scene_path in location.scene_paths:
			if not scene_path.is_empty():
				_scene_index[scene_path] = location
