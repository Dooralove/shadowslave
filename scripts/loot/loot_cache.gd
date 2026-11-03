class_name LootCache
extends Interactable
## Интерактивное хранилище: сундук, бочки или саркофаг.
##
## Наследует Interactable, поэтому использует тот же E, Interactor и подсказку,
## что и остальные мировые объекты. Один контейнер выдаёт лут ровно один раз;
## факт открытия хранится флагом NightmareRunState, чтобы смерть/загрузка не
## позволяли фармить один и тот же тайник.

signal opened(container_id: StringName, drops: Array)

const OVERFLOW_BAG_SCENE := preload("res://scenes/loot/loot_bag.tscn")

@export var container_id: StringName
@export var loot_pool: LootPool
@export var opened_flag: StringName
## Необязательная крышка/створка. Если не задана, проигрывается только
## короткая осадка визуала — каменный саркофаг не должен «открываться» как
## деревянный сундук.
@export var lid: Node3D
@export var visual_root: Node3D
@export var glow: Node3D
@export var state_label: Label3D
@export var lid_open_degrees := -100.0
@export var open_duration := 0.55
@export var start_enabled := true
@export var require_flags: Array[StringName] = []
## Включать GD_FUTURE-записи (бандитская экипировка, реликтовые сеты).
@export var include_future := false
@export var overflow_bag_scene: PackedScene
## Гарантированный «флейвор» конкретного тайника. Позволяет двум контейнерам
## с общим пулом не выдавать одинаковый набор.
@export var flavor_item: LootItemData
@export_range(1, 9, 1) var flavor_count := 1
@export var loot_text_prefix := "Найдено: "
@export var empty_text := "Пусто. Только соль, кости и мокрый камень."

var _opened := false
var _busy := false
var _base_lid_rotation := Vector3.ZERO
var _glow_base_energy := 0.0
var _pulse := 0.0


func _ready() -> void:
	super._ready()
	add_to_group(&"loot_cache")
	if lid == null:
		lid = get_node_or_null(^"VisualRoot/Model/Lid") as Node3D
	if visual_root == null:
		var visual_parent := get_node_or_null(^"VisualRoot")
		if visual_parent != null and visual_parent.get_child_count() > 0:
			visual_root = visual_parent.get_child(0) as Node3D
	if glow == null:
		glow = get_node_or_null(^"Glow") as Node3D
	if state_label == null:
		state_label = get_node_or_null(^"StateLabel") as Label3D
	if container_id == &"":
		container_id = interaction_id
	if opened_flag == &"":
		opened_flag = StringName("loot_%s_opened" % String(container_id))
	if lid != null:
		_base_lid_rotation = lid.rotation_degrees
	if glow is OmniLight3D:
		_glow_base_energy = (glow as OmniLight3D).light_energy
	if _is_already_opened():
		_opened = true
		enabled = false
		_set_opened_visual()
		return
	enabled = start_enabled and _requirements_met()
	set_process(glow != null)


func _process(delta: float) -> void:
	if _opened or glow == null:
		return
	_pulse += delta
	if glow is OmniLight3D:
		var light := glow as OmniLight3D
		light.light_energy = _glow_base_energy * (0.82 + sin(_pulse * 1.6) * 0.18)


func roll_drops() -> Array[LootDrop]:
	var rng := LootPoolRoller.seeded_rng(hash(String(container_id)) ^ 0x5EAF00D)
	var drops := LootPoolRoller.roll(loot_pool, rng, include_future)
	if flavor_item != null:
		var flavor := LootDrop.new()
		flavor.item = flavor_item
		flavor.count = maxi(flavor_count, 1)
		flavor.source_table_id = loot_pool.id if loot_pool != null else &""
		drops.append(flavor)
		drops = LootPoolRoller.merge_drops(drops)
	return drops


func interact() -> void:
	if not enabled or _opened or _busy:
		return
	if loot_pool == null:
		push_warning("LootCache %s: loot_pool не назначен" % String(container_id))
		return
	_busy = true
	var drops := roll_drops()
	var leftovers := LootPoolRoller.apply(drops)
	_opened = true
	var state := _run_state()
	if state != null and opened_flag != &"":
		state.set_flag(opened_flag)
	_set_opened_visual(true)
	_animate_open()
	_show_loot(drops)
	if not leftovers.is_empty():
		_spawn_overflow_bag(leftovers)
		_show_overflow(leftovers)
	super.interact()
	enabled = false
	opened.emit(container_id, drops)
	_busy = false


func is_opened() -> bool:
	return _opened


func _is_already_opened() -> bool:
	var state := _run_state()
	return state != null and opened_flag != &"" and state.has_flag(opened_flag)


func _requirements_met() -> bool:
	var state := _run_state()
	return state == null or state.require(require_flags)


func _run_state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(^"NightmareRunState")


func _set_opened_visual(animate_lid := false) -> void:
	if lid != null and not animate_lid:
		lid.rotation_degrees = _base_lid_rotation + Vector3(lid_open_degrees, 0.0, 0.0)
	if glow is OmniLight3D:
		(glow as OmniLight3D).light_energy = 0.0
	if glow != null:
		glow.visible = false
	if state_label != null:
		state_label.text = "Обыскано"
		state_label.visible = true


func _animate_open() -> void:
	OneShotVfx.spawn_dust(global_position + Vector3.UP * 0.4)
	if lid != null:
		var target := _base_lid_rotation + Vector3(lid_open_degrees, 0.0, 0.0)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(lid, "rotation_degrees", target, open_duration)
		return
	if visual_root != null:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var start := visual_root.rotation_degrees
		tween.tween_property(visual_root, "rotation_degrees", start + Vector3(0.0, 0.0, 0.8), 0.12)
		tween.tween_property(visual_root, "rotation_degrees", start, 0.28)


func _show_loot(drops: Array[LootDrop]) -> void:
	var text := LootPoolRoller.format_drops(drops)
	if text.is_empty():
		text = empty_text
	else:
		text = loot_text_prefix + text
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests != null and quests.has_method(&"show_message"):
		quests.call(&"show_message", text, &"pickup")


func _show_overflow(drops: Array[LootDrop]) -> void:
	var text := LootPoolRoller.format_drops(drops)
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests != null and quests.has_method(&"show_message"):
		quests.call(&"show_message", "Сумка полна. Осталось в мешке: " + text, &"warning")


func _spawn_overflow_bag(leftovers: Array[LootDrop]) -> void:
	var packed := overflow_bag_scene
	if packed == null:
		packed = OVERFLOW_BAG_SCENE
	var bag := packed.instantiate() as LootBag
	if bag == null:
		return
	bag.bag_id = StringName("%s_overflow" % container_id)
	bag.drops = leftovers
	bag.drop_flag = opened_flag
	bag.announce = true
	add_child(bag)
	bag.global_position = global_position + Vector3(0.0, 0.45, 0.0)
	var state := _run_state()
	if state == null:
		return
	var scene_path := ""
	var current := get_tree().current_scene
	if current != null:
		scene_path = current.scene_file_path
	state.register_loot_bag(
		bag.bag_id,
		scene_path,
		bag.global_position,
		LootPoolRoller.serialize_drops(leftovers),
		opened_flag,
		bag.collected_flag
	)
