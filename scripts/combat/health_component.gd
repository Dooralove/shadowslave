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
## Плоское снижение входящего урона 0..0.95. Выставляется CharacterStats из брони.
@export_range(0.0, 0.95, 0.01) var damage_reduction := 0.0
## Сопротивления по типам урона: physical, slash, pierce, blunt, fire, cold, shadow.
@export var damage_resistances: Dictionary = {}
## Временная неуязвимость на время кат-сцены/постановки.
@export var invulnerable := false

var current_health := 0.0
var _dead := false


func _ready() -> void:
	var start := initial_health if initial_health >= 0.0 else max_health
	current_health = clampf(start, 0.0, max_health)
	_dead = current_health <= 0.0


## Меняет максимум из EnemyData/другого ресурса. По умолчанию заполняет здоровье.
func configure(maximum: float, fill := true) -> void:
	max_health = maxf(maximum, 1.0)
	if fill:
		current_health = max_health
	else:
		current_health = minf(current_health, max_health)
	_dead = current_health <= 0.0
	health_changed.emit(current_health, max_health)


## Меняет максимум, сохраняя долю текущего здоровья. Отправляет один
## health_changed с уже новым current_health, чтобы HUD не показывал старые HP.
func set_max_health_preserving_ratio(new_max: float) -> void:
	var ratio := 1.0
	if max_health > 0.0:
		ratio = current_health / max_health
	max_health = maxf(new_max, 1.0)
	current_health = clampf(max_health * ratio, 0.0, max_health)
	_dead = current_health <= 0.0
	health_changed.emit(current_health, max_health)


## Возвращает фактически снятое здоровье. После смерти урон игнорируется.
## damage_type позволяет броне/сопротивлениям работать по типу урона.
func take_damage(amount: float, damage_type: StringName = &"physical") -> float:
	if invulnerable:
		return 0.0
	if _dead or amount <= 0.0:
		return 0.0
	var reduction := clampf(
		damage_reduction + float(damage_resistances.get(StringName(damage_type), 0.0)),
		0.0,
		0.95
	)
	var incoming := amount * (1.0 - reduction)
	if incoming <= 0.0:
		return 0.0
	var before := current_health
	current_health = maxf(current_health - incoming, 0.0)
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


## Восстанавливает персонажа после смерти при возврате на чекпоинт.
func revive(full_heal := true) -> void:
	_dead = false
	if full_heal or current_health <= 0.0:
		current_health = max_health
	health_changed.emit(current_health, max_health)
