class_name MapAtlas
extends Resource
## Связь игрового мира с картами.
##
## Атлас — единственное место, где перечислены все локации. MapSystem
## определяет по нему текущую карту, а MapScreen строит из него карту мира.
## Новая локация добавляется одним ресурсом MapDefinition и строкой здесь,
## без копирования UI-сцены или скрипта.

@export var world_map: MapDefinition
@export var locations: Array[MapDefinition] = []

var _id_index: Dictionary = {}
var _scene_index: Dictionary = {}
var _indexed := false


func get_location(location_id: StringName) -> MapDefinition:
	_ensure_index()
	return _id_index.get(StringName(location_id), null) as MapDefinition


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
