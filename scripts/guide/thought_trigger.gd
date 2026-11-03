class_name ThoughtTrigger
extends Area3D
## Мировая точка, которая вызывает короткую мысль Санни.
##
## В сцене хранится только id и форма зоны; текст лежит в GuideThought-ресурсе.
## Кнопка не показывается и не требуется: игрок просто проходит мимо.

signal thought_triggered(thought_id: StringName)

@export var thought_id: StringName = &""
## Если задано, мысль звучит только в это событие — не раньше и не позже.
@export var beat_id: StringName = &""
@export var enabled := true
@export var one_shot := true
@export var trigger_radius := 1.2


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	if get_child_count() == 0:
		var shape := CylinderShape3D.new()
		shape.radius = trigger_radius
		shape.height = 2.4
		var collision := CollisionShape3D.new()
		collision.shape = shape
		add_child(collision)
	body_entered.connect(_on_body_entered)
	add_to_group(&"guide_thought_trigger")


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		fire()


func fire() -> void:
	if not enabled or thought_id == &"":
		return
	var guide := get_node_or_null("/root/CampaignGuide")
	if beat_id != &"" and guide != null:
		if StringName(guide.call(&"get_current_beat_id")) != beat_id:
			return
	if one_shot:
		enabled = false
	thought_triggered.emit(thought_id)
	if guide != null and guide.has_method(&"show_thought"):
		guide.call(&"show_thought", thought_id)
