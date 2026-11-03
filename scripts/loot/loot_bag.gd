class_name LootBag
extends Interactable
## Физическая добыча врага. Создаётся LootDropper при смерти и выдаёт
## generic-лут только при взаимодействии игрока.
##
## Это закрывает контракт «добыча только ручная»: смерть врага больше не
## добавляет предметы в NightmareRunState. Флаг drop_flag ставится при
## создании мешка, чтобы один и тот же враг не оставил второй мешок.
##
## Если часть дропа не помещается в стек, мешок остаётся в мире с остатком;
## игрок может освободить место и вернуться.

signal collected(bag_id: StringName, drops: Array)

@export var bag_id: StringName = &"loot_bag"
@export var drop_flag: StringName
## Необязательный флаг «мешок собран» для UI/тестов.
@export var collected_flag: StringName
@export var prompt_text := "Собрать добычу"
@export var announce := true
## 0 — мешок живёт до подбора. Иначе исчезает через N секунд.
@export var lifetime := 0.0

## Заполняется LootDropper до add_child(); не экспортируется, потому что
## LootDrop — RefCounted, а не Resource.
var drops: Array[LootDrop] = []

var _collected := false
var _busy := false


func _ready() -> void:
	super._ready()
	add_to_group(&"loot_bag")
	prompt = prompt_text
	enabled = true
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(_expire)
	_update_label()


func interact() -> void:
	if _busy or _collected or not enabled:
		return
	_busy = true
	var leftovers := LootPoolRoller.apply(drops)
	if not leftovers.is_empty():
		drops = leftovers
		_refresh_registry()
		_update_label()
		_show_overflow()
		_busy = false
		return
	_collected = true
	var state := _run_state()
	if state != null:
		state.unregister_loot_bag(bag_id)
		if collected_flag != &"":
			state.set_flag(collected_flag)
	if announce:
		_show_loot()
	super.interact()
	enabled = false
	collected.emit(bag_id, drops)
	queue_free()


func _refresh_registry() -> void:
	var state := _run_state()
	if state == null:
		return
	var scene_path := ""
	var current := get_tree().current_scene
	if current != null:
		scene_path = current.scene_file_path
	state.register_loot_bag(
		bag_id,
		scene_path,
		global_position,
		LootPoolRoller.serialize_drops(drops),
		drop_flag,
		collected_flag
	)


func _show_loot() -> void:
	var text := LootPoolRoller.format_drops(drops)
	if text.is_empty():
		text = "Пусто."
	_message("Добыча: " + text, &"pickup")


func _show_overflow() -> void:
	var text := LootPoolRoller.format_drops(drops)
	_message("Сумка полна. Осталось: " + text, &"warning")


func _message(text: String, tone: StringName) -> void:
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests != null and quests.has_method(&"show_message"):
		quests.call(&"show_message", text, tone)


func _update_label() -> void:
	var label := get_node_or_null(^"Label") as Label3D
	if label != null:
		label.text = "Добыча" if not drops.is_empty() else "Пусто"
	var icon := get_node_or_null(^"Icon") as Sprite3D
	if icon != null:
		icon.texture = LootRegistry.get_icon(drops[0].get_id()) if not drops.is_empty() else null


func _expire() -> void:
	if not _collected:
		queue_free()


func _run_state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(^"NightmareRunState")
