class_name QuestPickup
extends Interactable
## Мировой предмет-подбор. Наследует существующую точку взаимодействия,
## поэтому игрок использует тот же E, Interactor и подсказку, что и в
## остальных сценах. Состояние подбора хранится флагом NightmareRunState.

signal picked_up(pickup_id: StringName)

@export_enum("shard", "blade", "token") var visual_kind := "shard"
@export var item_id: StringName
@export_range(1, 99, 1) var item_count := 1
@export var currency_id: StringName
@export_range(0, 9999, 1) var currency_amount := 0
@export var memory_id: StringName
@export var pickup_flag: StringName
@export var quest_event: StringName = &"collected"
@export var quest_subject: StringName
## Явный старт задания по первому контакту (для auto_start=false).
@export var start_quest_id: StringName
## Предмет не появляется, пока не выполнены условия. Нужен, чтобы награду
## нельзя было забрать раньше задания и потерять точку завершения.
@export var required_flags: Array[StringName] = []
@export_multiline var pickup_text := ""
@export var float_amplitude := 0.08
@export var spin_speed := 0.55

var _collected := false
var _base_y := 0.0
var _time := 0.0


func _ready() -> void:
	super._ready()
	add_to_group(&"quest_pickup")
	if quest_subject == &"":
		quest_subject = interaction_id
	if pickup_flag != &"" and NightmareRunState.has_flag(pickup_flag):
		_collected = true
		enabled = false
		visible = false
		return
	_base_y = position.y
	if get_child_count() == 0:
		_build_visual()
	var run_state := get_node_or_null(^"/root/NightmareRunState")
	if run_state != null and not run_state.flag_changed.is_connected(_on_flag_changed):
		run_state.flag_changed.connect(_on_flag_changed)
	_refresh_availability()


func _process(delta: float) -> void:
	if _collected or not visible:
		return
	_time += delta
	position.y = _base_y + sin(_time * 1.4) * float_amplitude
	rotation.y += delta * spin_speed


## Директор ставит предмет после add_child(); вызывается, чтобы плавание
## считалось от фактической мировой высоты, а не от нуля контейнера.
func reset_float_origin() -> void:
	_base_y = position.y
	_time = 0.0


func _on_flag_changed(_flag_name: StringName, _value: bool) -> void:
	_refresh_availability()


func _refresh_availability() -> void:
	if _collected:
		return
	var available := NightmareRunState.require(required_flags)
	enabled = available
	visible = available


func interact() -> void:
	if not enabled or _collected:
		return
	_collected = true
	_grant()
	super.interact()
	if pickup_flag != &"":
		NightmareRunState.set_flag(pickup_flag)
	if start_quest_id != &"":
		QuestSystem.start_quest(start_quest_id)
	QuestSystem.notify_event(quest_event, quest_subject, 1)
	if not pickup_text.strip_edges().is_empty():
		_show_pickup_text()
	picked_up.emit(interaction_id)
	enabled = false
	visible = false


func _grant() -> void:
	if item_id != &"":
		NightmareRunState.add_item(item_id, item_count)
	if currency_id != &"" and currency_amount > 0:
		NightmareRunState.add_currency(currency_id, currency_amount)
	if memory_id != &"":
		NightmareRunState.unlock_memory(memory_id)


func _show_pickup_text() -> void:
	# Тост показывает GameplayHud; предмет не исчезает без обратной связи.
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests != null and quests.has_method(&"show_message"):
		quests.call(&"show_message", pickup_text, &"pickup")


func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PickupVisual"
	var material := StandardMaterial3D.new()
	material.emission_enabled = true
	material.emission_energy_multiplier = 1.6
	material.roughness = 0.35
	if visual_kind == "blade":
		var blade := BoxMesh.new()
		blade.size = Vector3(0.08, 0.08, 1.05)
		mesh_instance.mesh = blade
		material.albedo_color = Color(0.32, 0.62, 0.78, 1.0)
		material.emission = Color(0.18, 0.45, 0.65, 1.0)
		mesh_instance.rotation_degrees = Vector3(0, 25, 0)
	else:
		var shard := PrismMesh.new()
		shard.size = Vector3(0.22, 0.42, 0.22)
		mesh_instance.mesh = shard
		material.albedo_color = Color(0.55, 0.78, 0.82, 1.0)
		material.emission = Color(0.3, 0.62, 0.72, 1.0)
	mesh_instance.material_override = material
	add_child(mesh_instance)
	var light := OmniLight3D.new()
	light.name = "PickupLight"
	light.light_color = material.emission
	light.light_energy = 0.9
	light.omni_range = 2.2
	light.shadow_enabled = false
	add_child(light)
