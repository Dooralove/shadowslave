class_name HealthComponent
extends Node
## Здоровье персонажа или противника. Не знает ни о моделях, ни о том, кто владелец.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal healed(amount: float)
## Испускается ровно один раз.
signal died

@export var max_health := 100.0
## Отрицательное значение — начать с max_health.
@export var initial_health := -1.0

var current_health := 0.0
var _dead := false


func _ready() -> void:
	var start := initial_health if initial_health >= 0.0 else max_health
	current_health = clampf(start, 0.0, max_health)
	_dead = current_health <= 0.0


## Возвращает фактически снятое здоровье. После смерти урон игнорируется.
func take_damage(amount: float) -> float:
	if _dead or amount <= 0.0:
		return 0.0
	var before := current_health
	current_health = maxf(current_health - amount, 0.0)
	var applied := before - current_health
	damaged.emit(applied)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_dead = true
		died.emit()
	return applied


## Возвращает фактически восстановленное здоровье. Мёртвых не лечит.
func heal(amount: float) -> float:
	if _dead or amount <= 0.0:
		return 0.0
	var before := current_health
	current_health = minf(current_health + amount, max_health)
	var applied := current_health - before
	if applied > 0.0:
		healed.emit(applied)
		health_changed.emit(current_health, max_health)
	return applied


func is_dead() -> bool:
	return _dead
