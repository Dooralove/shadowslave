class_name CombatHud
extends CanvasLayer
## Полосы здоровья и итоговое сообщение боевого испытания.

@onready var player_bar: ProgressBar = %PlayerHealth
@onready var enemy_bar: ProgressBar = %EnemyHealth
@onready var message: Label = %Message


func bind(player_health: HealthComponent, enemy_health: HealthComponent) -> void:
	_bind_bar(player_bar, player_health)
	_bind_bar(enemy_bar, enemy_health)


func show_message(text: String) -> void:
	message.text = text
	message.visible = true


func _bind_bar(bar: ProgressBar, health: HealthComponent) -> void:
	bar.max_value = health.max_health
	bar.value = health.current_health
	health.health_changed.connect(func(current: float, maximum: float) -> void:
		bar.max_value = maximum
		bar.value = current
	)
