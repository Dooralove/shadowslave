class_name MeleeAttack
extends Area3D
## Атака ближнего боя: окно попадания, перезарядка, не больше одного попадания по цели за удар.
## Зона поражения — сфера вперёд по -Z узла; маска коллизии задаёт, чьи хёртбоксы она видит.

signal attack_started
signal attack_finished
signal hit_landed(target: Hurtbox)

@export var stats: AttackStats
## Необязательная визуализация удара; показывается на время окна попадания.
@export var swing_visual: Node3D

var enabled := true
var _cooldown_left := 0.0
var _active_left := 0.0
var _hit_this_swing: Array[Hurtbox] = []

@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	monitorable = false
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
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if not is_active():
		return
	for area in get_overlapping_areas():
		if area is Hurtbox:
			apply_hit(area)
	_active_left -= delta
	if _active_left <= 0.0:
		_end_swing()


func can_attack() -> bool:
	return enabled and stats != null and _cooldown_left <= 0.0 and not is_active()


func try_attack() -> bool:
	if not can_attack():
		return false
	_cooldown_left = stats.cooldown
	_active_left = stats.active_time
	_hit_this_swing.clear()
	if swing_visual:
		swing_visual.visible = true
	attack_started.emit()
	return true


func is_active() -> bool:
	return _active_left > 0.0


## Засчитывает попадание, если окно открыто и эта цель ещё не получила урон в этом ударе.
func apply_hit(target: Hurtbox) -> bool:
	if not enabled or not is_active() or target in _hit_this_swing:
		return false
	_hit_this_swing.append(target)
	if target.receive_hit(stats.damage, self):
		hit_landed.emit(target)
		return true
	return false


## Окончательно отключает атаку (например, после смерти владельца).
func disable() -> void:
	enabled = false
	if is_active():
		_end_swing()


func _end_swing() -> void:
	_active_left = 0.0
	if swing_visual:
		swing_visual.visible = false
	attack_finished.emit()
