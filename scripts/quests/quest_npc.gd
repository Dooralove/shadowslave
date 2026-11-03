class_name QuestNpc
extends Node3D
## NPC с одной репликой-сценой. Использует существующий Interactable,
## DialogueRunner и субтитры; не создаёт собственный диалоговый движок.

signal talked(npc_id: StringName)
signal dialogue_started(npc_id: StringName)
signal dialogue_finished(npc_id: StringName)

@export var npc_id: StringName
@export_multiline var display_name := ""
@export var prompt := "Поговорить"
@export var dialogue: DialogueSequence
@export var required_flags: Array[StringName] = []
@export var completion_flag: StringName
## Явный старт задания по первому разговору (для auto_start=false).
@export var start_quest_id: StringName
@export var talk_event: StringName = &"talked"
@export var one_shot := true
@export_range(1.0, 6.0, 0.1) var interaction_radius := 2.2

var _running := false
var _finished := false

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func _ready() -> void:
	add_to_group(&"quest_npc")
	if interactable == null:
		push_warning("QuestNpc: у %s нет Interactable" % name)
		return
	interactable.interaction_id = npc_id
	interactable.prompt = prompt
	interactable.radius = interaction_radius
	if not interactable.interacted.is_connected(_on_interacted):
		interactable.interacted.connect(_on_interacted)
	var run_state := get_node_or_null(^"/root/NightmareRunState")
	if run_state != null and not run_state.flag_changed.is_connected(_on_flag_changed):
		run_state.flag_changed.connect(_on_flag_changed)
	if completion_flag != &"" and NightmareRunState.has_flag(completion_flag):
		_finished = true
	_refresh_availability()


func _on_flag_changed(_flag_name: StringName, _value: bool) -> void:
	_refresh_availability()


func _refresh_availability() -> void:
	if interactable == null:
		return
	var available := not _running
	if one_shot and _finished:
		available = false
	if not NightmareRunState.require(required_flags):
		available = false
	interactable.enabled = available


func _on_interacted(_id: StringName) -> void:
	if _running or not interactable.enabled:
		return
	_running = true
	interactable.enabled = false
	if start_quest_id != &"":
		QuestSystem.start_quest(start_quest_id)
	dialogue_started.emit(npc_id)
	await _play_dialogue()
	if completion_flag != &"":
		NightmareRunState.set_flag(completion_flag)
	_finished = true
	QuestSystem.notify_event(talk_event, npc_id, 1)
	talked.emit(npc_id)
	dialogue_finished.emit(npc_id)
	_running = false
	_refresh_availability()


func _play_dialogue() -> void:
	if dialogue == null or dialogue.lines.is_empty():
		return
	var runner := get_tree().get_first_node_in_group(&"dialogue_runner") as DialogueRunner
	if runner == null:
		push_warning("QuestNpc: не найден DialogueRunner для %s" % npc_id)
		return
	var player := get_tree().get_first_node_in_group(&"player") as SunnyController
	var saved_input := true
	var interactor: Interactor = null
	var saved_interactor := true
	if player != null:
		saved_input = player.input_enabled
		player.input_enabled = false
		interactor = player.get_node_or_null(^"Interactor") as Interactor
		if interactor != null:
			saved_interactor = interactor.enabled
			interactor.enabled = false
	var dialogue_manager := get_node_or_null(^"/root/DialogueManager")
	if dialogue_manager != null and dialogue_manager.has_method(&"set_barks_suppressed"):
		dialogue_manager.call(&"set_barks_suppressed", true)
	await runner.run(dialogue)
	if player != null and is_instance_valid(player):
		player.input_enabled = saved_input
	if interactor != null and is_instance_valid(interactor):
		interactor.enabled = saved_interactor
	if dialogue_manager != null and dialogue_manager.has_method(&"set_barks_suppressed"):
		dialogue_manager.call(&"set_barks_suppressed", false)
