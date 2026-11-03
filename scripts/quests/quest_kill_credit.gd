class_name QuestKillCredit
extends Node
## Небольшой адаптер здоровья врага к шине заданий. Живёт рядом с Health,
## не меняет AI и не требует, чтобы Enemy знал о квестах.

signal credited(enemy_tag: StringName)

@export var enemy_tag: StringName = &"carapace"
@export var credit_flag: StringName
@export var kill_event: StringName = &"killed"

var _credited := false
var _health: HealthComponent


func _ready() -> void:
	_health = get_parent().get_node_or_null(^"Health") as HealthComponent
	if _health == null:
		push_warning("QuestKillCredit: у %s нет Health" % get_parent().name)
		return
	if not _health.died.is_connected(_on_died):
		_health.died.connect(_on_died)


func _on_died() -> void:
	if _credited:
		return
	_credited = true
	if credit_flag != &"":
		NightmareRunState.set_flag(credit_flag)
	QuestSystem.notify_event(kill_event, enemy_tag, 1)
	credited.emit(enemy_tag)
