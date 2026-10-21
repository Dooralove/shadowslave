class_name SunnyAnimator
extends Node
## Выбирает анимацию Санни по его фактическому состоянию. Только визуальный слой:
## урон наносит MeleeAttack, здоровье ведёт HealthComponent, передвижение — SunnyController.
## Все клипы проигрывает один AnimationPlayer модели, поэтому кости не делят разные проигрыватели.

enum State { IDLE, WALK, RUN, JUMP, FALL, LAND, ATTACK, HIT, DEAD }

@export var body: SunnyController
@export var animation_player: AnimationPlayer
# Ссылки на компоненты задаются в сцене напрямую: _ready аниматора выполняется раньше,
# чем @onready-поля контроллера.
@export var attack: MeleeAttack
@export var health: HealthComponent

@export_group("Clips")
@export var idle_clip: StringName = &"Idle"
@export var walk_clip: StringName = &"Walking_A"
@export var run_clip: StringName = &"Running_A"
@export var jump_clip: StringName = &"Jump_Start"
@export var fall_clip: StringName = &"Jump_Idle"
@export var land_clip: StringName = &"Jump_Land"
@export var attack_clip: StringName = &"1H_Melee_Attack_Slice_Horizontal"
@export var hit_clip: StringName = &"Hit_A"
@export var death_clip: StringName = &"Death_A"

@export_group("Tuning")
## Горизонтальная скорость, ниже которой персонаж считается стоящим, м/с.
@export var move_threshold := 0.3
## Время в воздухе без прыжка, после которого включается падение (сглаживает ступеньки), с.
@export var fall_delay := 0.12
@export var blend_time := 0.15
## Момент удара в клипе атаки (пик скорости замаха руки), с. Клип начинается так,
## чтобы этот момент пришёлся на середину окна попадания MeleeAttack.
@export var attack_impact_time := 0.267
## Через сколько секунд реакцию на урон можно прервать движением, с.
@export var hit_interrupt_time := 0.25

var state := State.IDLE
var _state_time := 0.0
var _air_time := 0.0


func _ready() -> void:
	attack.attack_started.connect(_on_attack_started)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_play(idle_clip)


func _physics_process(delta: float) -> void:
	update(delta, body.is_on_floor(), body.velocity)


## Переход по фактическому движению тела; вызывается каждый физический кадр.
func update(delta: float, on_floor: bool, velocity: Vector3) -> void:
	if state == State.DEAD:
		return
	_state_time += delta
	_air_time = 0.0 if on_floor else _air_time + delta
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	# Разовые анимации держатся, пока не закончатся или их не прервёт движение.
	match state:
		State.ATTACK:
			if _state_time < attack.stats.cooldown:
				return
		State.HIT:
			var moving := horizontal_speed > move_threshold and _state_time >= hit_interrupt_time
			if _state_time < _clip_length(hit_clip) and not moving:
				return
		State.LAND:
			if on_floor and horizontal_speed <= move_threshold and _state_time < _clip_length(land_clip):
				return
		State.JUMP:
			if not on_floor and velocity.y > 0.0 and _state_time < _clip_length(jump_clip):
				return
	_enter(_movement_state(on_floor, velocity.y, horizontal_speed))
	if state == State.WALK:
		animation_player.speed_scale = clampf(horizontal_speed / body.walk_speed, 0.5, 1.5)
	elif state == State.RUN:
		animation_player.speed_scale = clampf(horizontal_speed / body.sprint_speed, 0.5, 1.5)


func _movement_state(on_floor: bool, vertical_speed: float, horizontal_speed: float) -> State:
	if not on_floor:
		if state == State.JUMP or state == State.FALL:
			return State.FALL
		if vertical_speed > 0.0 and _air_time <= fall_delay:
			return State.JUMP
		if _air_time >= fall_delay:
			return State.FALL
		# Короткий отрыв от пола (ступенька) — продолжаем наземную анимацию.
	elif state == State.JUMP or state == State.FALL:
		return State.LAND
	if horizontal_speed <= move_threshold:
		return State.IDLE
	var run_threshold := (body.walk_speed + body.sprint_speed) * 0.5
	return State.RUN if horizontal_speed > run_threshold else State.WALK


func _enter(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	_state_time = 0.0
	animation_player.speed_scale = 1.0
	match new_state:
		State.IDLE:
			_play(idle_clip)
		State.WALK:
			_play(walk_clip)
		State.RUN:
			_play(run_clip)
		State.JUMP:
			_play(jump_clip)
		State.FALL:
			_play(fall_clip)
		State.LAND:
			_play(land_clip)


func _on_attack_started() -> void:
	if state == State.DEAD:
		return
	_force(State.ATTACK)
	var offset := maxf(attack_impact_time - attack.stats.active_time * 0.5, 0.0)
	_play(attack_clip, offset, 0.05)


func _on_damaged(_amount: float) -> void:
	# Реакция не прерывает удар, чтобы анимация оставалась согласованной с окном попадания.
	if state == State.DEAD or state == State.ATTACK:
		return
	_force(State.HIT)
	_play(hit_clip, 0.0, 0.05)


func _on_died() -> void:
	_force(State.DEAD)
	_play(death_clip, 0.0, 0.1)
	set_physics_process(false)


## Вход в разовое состояние с перезапуском, даже если оно уже активно.
func _force(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	animation_player.speed_scale = 1.0


func _play(clip: StringName, from := 0.0, blend := -1.0) -> void:
	animation_player.play(clip, blend_time if blend < 0.0 else blend)
	animation_player.seek(from, true)


func _clip_length(clip: StringName) -> float:
	return animation_player.get_animation(clip).length
