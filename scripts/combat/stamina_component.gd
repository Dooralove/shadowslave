class_name StaminaComponent
extends Node
## Выносливость: запас, трата, задержка восстановления и сигналы для HUD.

signal stamina_changed(current: float, maximum: float)
signal spent(amount: float)
signal depleted

@export var max_stamina := 100.0
@export var regen_per_second := 18.0
@export var regen_delay := 0.7

var current_stamina := 0.0
var _regen_delay_left := 0.0


func _ready() -> void:
	current_stamina = max_stamina
	stamina_changed.emit(current_stamina, max_stamina)


func configure(settings: CombatSettings) -> void:
	if settings == null:
		return
	var was_full := is_equal_approx(current_stamina, max_stamina)
	max_stamina = settings.max_stamina
	regen_per_second = settings.stamina_regen_per_second
	regen_delay = settings.stamina_regen_delay
	current_stamina = max_stamina if was_full else minf(current_stamina, max_stamina)
	stamina_changed.emit(current_stamina, max_stamina)


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if current_stamina >= max_stamina:
		current_stamina = max_stamina
		return
	if _regen_delay_left > 0.0:
		_regen_delay_left = maxf(_regen_delay_left - delta, 0.0)
		return
	_set_current(current_stamina + regen_per_second * delta)


func can_spend(amount: float) -> bool:
	return amount >= 0.0 and current_stamina >= amount


## Трата на действие. Возвращает true, если выносливости хватило.
func spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if not can_spend(amount):
		return false
	_set_current(current_stamina - amount)
	_regen_delay_left = regen_delay
	spent.emit(amount)
	if current_stamina <= 0.0:
		depleted.emit()
	return true


## Непрерывная трата (блок). Возвращает false, когда запас закончился.
func drain(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if current_stamina <= 0.0:
		return false
	_set_current(current_stamina - amount)
	_regen_delay_left = regen_delay
	spent.emit(minf(amount, maxf(current_stamina, 0.0)))
	if current_stamina <= 0.0:
		depleted.emit()
		return false
	return true


func refill() -> void:
	_regen_delay_left = 0.0
	_set_current(max_stamina)


func set_current(value: float) -> void:
	_set_current(clampf(value, 0.0, max_stamina))
	_regen_delay_left = 0.0


func _set_current(value: float) -> void:
	var next := clampf(value, 0.0, max_stamina)
	if is_equal_approx(next, current_stamina):
		return
	current_stamina = next
	stamina_changed.emit(current_stamina, max_stamina)
