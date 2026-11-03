extends Node3D
## Боевое испытание: связывает здоровье бойцов с HUD, показывает итог, перезапускает сцену.

@onready var sunny: SunnyController = $Level/Sunny
## The arena can host TestEnemy, LarvaEnemy or CarapaceEnemy; only the shared
## health/combat contract is used here.
@onready var enemy: Node = $TestEnemy
@onready var hud: CombatHud = $HUD
@onready var enemy_health: HealthComponent = enemy.get("health") as HealthComponent


func _ready() -> void:
	hud.bind_player(sunny, enemy)
	sunny.health.died.connect(_on_sunny_died)
	enemy_health.died.connect(_on_enemy_died)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _on_sunny_died() -> void:
	hud.show_message("Санни погиб\nR — начать заново")


func _on_enemy_died() -> void:
	if not sunny.is_dead():
		hud.show_message("Победа\nR — начать заново")
