class_name LootBagPersistence
extends Node3D
## Восстанавливает неподобранные LootBag из NightmareRunState после загрузки
## сцены. Сами мешки не сериализуются как узлы: в снимке лежит только
## bag_id, позиция и сериализованные дропы.
##
## Узел живёт в сцене Лабиринта и срабатывает один раз после _ready.

const DEFAULT_BAG_SCENE := preload("res://scenes/loot/loot_bag.tscn")

@export var bag_scene: PackedScene


func _ready() -> void:
	call_deferred(&"_respawn")


func _respawn() -> void:
	var state := _run_state()
	if state == null:
		return
	var scene_path := ""
	var current := get_tree().current_scene
	if current != null:
		scene_path = current.scene_file_path
	var records: Array = state.get_loot_bags(scene_path)
	for record in records:
		var bag_id := StringName(record.get("bag_id", ""))
		if bag_id == &"" or _has_bag(bag_id):
			continue
		var packed := bag_scene
		if packed == null:
			packed = DEFAULT_BAG_SCENE
		var bag := packed.instantiate() as LootBag
		if bag == null:
			continue
		bag.bag_id = bag_id
		bag.drops = LootPoolRoller.deserialize_drops(record.get("drops", []))
		bag.collected_flag = StringName(record.get("collected_flag", ""))
		if bag.drops.is_empty():
			state.unregister_loot_bag(bag_id)
			bag.free()
			continue
		add_child(bag)
		var position_value: Variant = record.get("position", Vector3.ZERO)
		if position_value is Vector3:
			bag.global_position = position_value


func _has_bag(bag_id: StringName) -> bool:
	for node in get_tree().get_nodes_in_group(&"loot_bag"):
		if node is LootBag and (node as LootBag).bag_id == bag_id:
			return true
	return false


func _run_state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(^"NightmareRunState")
