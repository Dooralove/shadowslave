class_name CheckpointZone
extends Area3D
## Безопасная точка: обновляет чекпоинт NightmareRunState и FallRecovery,
## лечит тело и пополняет выносливость. Не является квестом и не создаёт
## второй системы сохранений.

signal checkpoint_activated(checkpoint_id: StringName, position: Vector3)

@export var checkpoint_id: StringName
@export var player_group: StringName = &"player"
@export var heal := true
@export var refill_stamina := true
@export var one_shot := false

var _used := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(player_group):
		return
	if one_shot and _used:
		return
	_used = true
	var player := body as SunnyController
	if player == null:
		return
	var point := global_position
	NightmareRunState.set_checkpoint(checkpoint_id, point, true)
	var recovery := player.get_node_or_null(^"FallRecovery") as FallRecovery
	if recovery != null:
		recovery.set_named_checkpoint(checkpoint_id, point)
	if heal and player.health != null:
		player.health.heal(player.health.max_health)
	if refill_stamina and player.stamina != null:
		player.stamina.refill()
	if not OS.has_feature("headless"):
		var save_system := get_node_or_null(^"/root/SaveSystem")
		if save_system != null and save_system.has_method(&"save_game"):
			save_system.call(&"save_game", "checkpoint")
	checkpoint_activated.emit(checkpoint_id, point)
