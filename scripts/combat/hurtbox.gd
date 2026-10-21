class_name Hurtbox
extends Area3D
## Зона, по которой можно попасть. Передаёт урон в HealthComponent.
## Слой коллизии задаёт, чьи атаки её видят (player_hurtbox / enemy_hurtbox).

signal hit_received(damage: float, source: Node)

@export var health: HealthComponent


func _ready() -> void:
	# Хёртбокс только обнаруживают, сам он ничего не ищет.
	monitoring = false
	monitorable = true


## Возвращает true, если урон был нанесён.
func receive_hit(damage: float, source: Node) -> bool:
	if health == null or health.is_dead():
		return false
	var applied := health.take_damage(damage)
	hit_received.emit(applied, source)
	return applied > 0.0
