extends Node3D
## Декоративный силуэт среднего/дальнего плана. Коллизии не участвуют в
## маршруте: игрок не должен застревать в фоновых скалах или деревьях.

func _ready() -> void:
	add_to_group(&"background_decor")
	for body in find_children("*", "StaticBody3D", true, false):
		var static_body := body as StaticBody3D
		static_body.collision_layer = 0
		static_body.collision_mask = 0
	for shape in find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).disabled = true
