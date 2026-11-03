class_name LootDropper
extends Node3D
## Необязательный компонент врага: один раз оставить физический мешок лута.
##
## Не меняет AI и не зависит от CarapaceEnemy. Смерть врага только создаёт
## LootBag; предметы попадают в NightmareRunState при взаимодействии игрока.
## Это сохраняет контракт «добыча только ручная» и не даёт фармить труп.

const DEFAULT_BAG_SCENE := preload("res://scenes/loot/loot_bag.tscn")

@export var loot_pool: LootPool
@export var drop_flag: StringName
## Stable seed per spawn. 0 — fall back to pool id + death position.
@export var drop_seed: int = 0
@export var include_future := false
@export var announce := true
@export var loot_bag_scene: PackedScene
## Куда складывать мешок. Пусто — current_scene, затем родитель врага.
@export var spawn_parent: Node3D
@export var drop_radius := 0.6

var _dropped := false
var _health: HealthComponent


func _ready() -> void:
	var owner_node := get_parent()
	if owner_node == null:
		return
	_health = owner_node.get_node_or_null(^"Health") as HealthComponent
	if _health == null:
		_health = owner_node.get(&"health") as HealthComponent
	if _health == null:
		push_warning("LootDropper: у %s нет HealthComponent" % owner_node.name)
		return
	_health.died.connect(_on_died)
	var state := _run_state()
	if state != null and drop_flag != &"" and state.has_flag(drop_flag):
		_dropped = true


func _on_died() -> void:
	if _dropped or loot_pool == null:
		return
	_dropped = true
	var seed_value := drop_seed
	if seed_value == 0:
		seed_value = hash(String(loot_pool.id))
		seed_value ^= int(global_position.x * 100.0)
		seed_value ^= int(global_position.z * 100.0)
	var rng := LootPoolRoller.seeded_rng(seed_value)
	var drops := LootPoolRoller.roll(loot_pool, rng, include_future)
	_mark_dropped()
	if drops.is_empty():
		return
	if _spawn_bag(drops, rng) == null:
		# Fallback: never lose loot if the bag scene is missing/broken.
		LootPoolRoller.apply(drops)


func _spawn_bag(drops: Array[LootDrop], rng: RandomNumberGenerator) -> LootBag:
	var packed := loot_bag_scene
	if packed == null:
		packed = DEFAULT_BAG_SCENE
	if packed == null:
		push_warning("LootDropper: loot_bag_scene не назначена")
		return null
	var bag := packed.instantiate() as LootBag
	if bag == null:
		push_warning("LootDropper: сцена мешка не является LootBag")
		return null
	var bag_id := StringName("%s_bag" % String(drop_flag)) if drop_flag != &"" else StringName(
		"loot_bag_%d_%d" % [int(global_position.x * 100.0), int(global_position.z * 100.0)]
	)
	bag.bag_id = bag_id
	bag.drops = drops
	bag.drop_flag = drop_flag
	bag.announce = announce
	var parent := spawn_parent
	if parent == null:
		parent = get_tree().current_scene as Node3D
	if parent == null:
		parent = get_parent() as Node3D
	if parent == null:
		bag.free()
		push_warning("LootDropper: нет родителя для мешка")
		return null
	parent.add_child(bag)
	var angle := rng.randf_range(0.0, TAU)
	var radius := rng.randf_range(0.0, drop_radius)
	bag.global_position = global_position + Vector3(
		cos(angle) * radius,
		0.35,
		sin(angle) * radius
	)
	var state := _run_state()
	if state != null:
		var scene_path := ""
		var current := get_tree().current_scene
		if current != null:
			scene_path = current.scene_file_path
		state.register_loot_bag(
			bag_id,
			scene_path,
			bag.global_position,
			LootPoolRoller.serialize_drops(drops),
			drop_flag,
			bag.collected_flag
		)
	return bag


func _mark_dropped() -> void:
	var state := _run_state()
	if state != null and drop_flag != &"":
		state.set_flag(drop_flag)


func _run_state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(^"NightmareRunState")
