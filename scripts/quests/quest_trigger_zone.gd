class_name QuestTriggerZone
extends TriggerZone
## Триггер сюжетной/квестовой точки. Наследует существующую одноразовую
## TriggerZone, поэтому не появляется второй тип зон. Условия проверяются
## до выключения: закрытая зона не сгорает навсегда.

@export var quest_event: StringName = &"reached"
@export var quest_subject: StringName
## Явный старт задания по входу в зону (для auto_start=false).
@export var start_quest_id: StringName
@export var set_flag: StringName
@export var required_flags: Array[StringName] = []


func _ready() -> void:
	super._ready()
	if quest_subject == &"":
		quest_subject = trigger_id
	if not triggered.is_connected(_on_zone_triggered):
		triggered.connect(_on_zone_triggered)


func fire() -> void:
	if not enabled:
		return
	if not NightmareRunState.require(required_flags):
		return
	super.fire()


func _on_zone_triggered(_id: StringName) -> void:
	if set_flag != &"":
		NightmareRunState.set_flag(set_flag)
	if start_quest_id != &"":
		QuestSystem.start_quest(start_quest_id)
	QuestSystem.notify_event(quest_event, quest_subject, 1)
