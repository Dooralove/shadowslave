class_name MeleeAttack
extends Area3D
## Атака ближнего боя в фазах: подготовка (WINDUP) → окно попадания (ACTIVE) → восстановление (RECOVERY).
## Урон возможен только в окне попадания, не больше одного попадания по каждой цели за удар.
## Зона поражения — сфера вперёд по -Z узла; маска коллизии задаёт, чьи хёртбоксы она видит.

signal attack_started
signal hit_window_opened
signal hit_window_closed
## Атака полностью завершена (или отменена) — можно начинать следующую.
signal attack_finished
signal hit_landed(target: Hurtbox)

enum Phase { READY, WINDUP, ACTIVE, RECOVERY }

@export var stats: AttackStats
## Отладочная визуализация зоны поражения.
@export var swing_visual: Node3D
## Показывать зону поражения во время окна попадания. Только отладка: на физику и урон не влияет.
@export var show_hit_zone := false

var enabled := true
var phase := Phase.READY
var _phase_left := 0.0
var _hit_this_swing: Array[Hurtbox] = []
## Направление удара фиксируется при его начале: родитель (модель) может поворачиваться
## во время атаки, но зона, визуализация и урон остаются в исходном направлении.
var _rest_basis := Basis.IDENTITY
var _locked_basis := Basis.IDENTITY

@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	monitorable = false
	_rest_basis = transform.basis
	var sphere := SphereShape3D.new()
	sphere.radius = stats.radius
	_shape.shape = sphere
	_shape.position = Vector3(0.0, 0.0, -stats.reach)
	if swing_visual:
		swing_visual.position = _shape.position
		# SphereMesh по умолчанию радиусом 0.5.
		swing_visual.scale = Vector3.ONE * (stats.radius / 0.5)
		swing_visual.visible = false


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if phase == Phase.READY:
		return
	global_basis = _locked_basis
	if phase == Phase.ACTIVE:
		for area in get_overlapping_areas():
			if area is Hurtbox:
				apply_hit(area)
	_phase_left -= delta
	# Остаток времени переносится в следующую фазу; короткие фазы могут пройти за один вызов.
	while phase != Phase.READY and _phase_left <= 0.0:
		_advance_phase()


func can_attack() -> bool:
	return enabled and stats != null and phase == Phase.READY


func try_attack() -> bool:
	if not can_attack():
		return false
	_hit_this_swing.clear()
	_locked_basis = global_basis
	attack_started.emit()
	if stats.windup_time > 0.0:
		phase = Phase.WINDUP
		_phase_left = stats.windup_time
	else:
		_open_window(stats.active_time)
	return true


## Открыто ли окно попадания.
func is_active() -> bool:
	return phase == Phase.ACTIVE


## Идёт ли атака в любой фазе.
func is_attacking() -> bool:
	return phase != Phase.READY


## Засчитывает попадание, если окно открыто и эта цель ещё не получила урон в этом ударе.
func apply_hit(target: Hurtbox) -> bool:
	if not enabled or not is_active() or target in _hit_this_swing:
		return false
	_hit_this_swing.append(target)
	if target.receive_hit(stats.damage, self):
		hit_landed.emit(target)
		return true
	return false


## Окончательно отключает атаку (например, после смерти владельца) и обрывает текущую.
func disable() -> void:
	enabled = false
	if phase == Phase.ACTIVE:
		_close_window()
	if phase != Phase.READY:
		_finish()


func _advance_phase() -> void:
	match phase:
		Phase.WINDUP:
			_open_window(stats.active_time + _phase_left)
		Phase.ACTIVE:
			var overflow := _phase_left
			_close_window()
			phase = Phase.RECOVERY
			_phase_left = maxf(stats.cooldown - stats.windup_time - stats.active_time, 0.0) + overflow
		Phase.RECOVERY:
			_finish()


func _open_window(duration: float) -> void:
	phase = Phase.ACTIVE
	_phase_left = duration
	if swing_visual and show_hit_zone:
		swing_visual.visible = true
	hit_window_opened.emit()


func _close_window() -> void:
	if swing_visual:
		swing_visual.visible = false
	hit_window_closed.emit()


func _finish() -> void:
	phase = Phase.READY
	_phase_left = 0.0
	transform.basis = _rest_basis
	attack_finished.emit()
