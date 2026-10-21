class_name EnemyAnimator
extends Node
## Анимации тестового противника по состояниям его автомата (TestEnemy.State).
## Только визуальный слой: решения принимает TestEnemy, урон наносит MeleeAttack.
## Подготовка, удар и восстановление — один непрерывный клип атаки: его замах занимает
## Telegraph, контакт приходится на окно попадания, доводка служит восстановлением.

@export var enemy: TestEnemy
@export var animation_player: AnimationPlayer
@export var health: HealthComponent
@export var attack: MeleeAttack

@export_group("Clips")
@export var idle_clip: StringName = &"2H_Melee_Idle"
@export var chase_clip: StringName = &"Walking_A"
@export var attack_clip: StringName = &"2H_Melee_Attack_Chop"
@export var hit_clip: StringName = &"Hit_A"
@export var death_clip: StringName = &"Death_B"

@export_group("Tuning")
## Момент контакта в клипе атаки: максимальная скорость кисти с топором перед корпусом,
## измерена покадрово по позе скелета, с.
@export var attack_contact_time := 0.717
## Скорость передвижения, при которой клип ходьбы играет с нормальной скоростью, м/с.
@export var chase_clip_speed := 3.0
@export var blend_time := 0.15

var _hit_left := 0.0


func _ready() -> void:
	enemy.state_changed.connect(_on_state_changed)
	health.damaged.connect(_on_damaged)
	animation_player.animation_finished.connect(_on_animation_finished)
	_play_state_clip()


func _process(delta: float) -> void:
	if _hit_left <= 0.0:
		return
	_hit_left -= delta
	if _hit_left <= 0.0:
		_play_state_clip()


## Скорость клипа атаки, при которой контакт совпадает с серединой окна попадания.
func attack_clip_speed() -> float:
	var contact_at := enemy.telegraph_time + attack.stats.active_time * 0.5
	return clampf(attack_contact_time / contact_at, 0.5, 2.0)


func _on_state_changed(new_state: TestEnemy.State) -> void:
	# Подготовка, удар и смерть важнее реакции на урон.
	if new_state in [TestEnemy.State.TELEGRAPH, TestEnemy.State.ATTACK, TestEnemy.State.DEAD]:
		_hit_left = 0.0
	if _hit_left > 0.0:
		return
	_play_state_clip()


func _play_state_clip() -> void:
	match enemy.state:
		TestEnemy.State.IDLE:
			_play(idle_clip)
		TestEnemy.State.CHASE:
			_play(chase_clip)
			animation_player.speed_scale = clampf(enemy.move_speed / chase_clip_speed, 0.5, 1.5)
		TestEnemy.State.TELEGRAPH:
			_play(attack_clip, 0.05)
			animation_player.speed_scale = attack_clip_speed()
		TestEnemy.State.ATTACK, TestEnemy.State.RECOVERY:
			# Клип атаки продолжается с подготовки; если его нет (атака сорвалась) — стойка.
			if animation_player.assigned_animation != String(attack_clip):
				_play(idle_clip)
		TestEnemy.State.DEAD:
			_play(death_clip, 0.1)


func _on_damaged(_amount: float) -> void:
	# Реакцию показываем, только когда противник не готовит и не наносит удар.
	if enemy.state in [TestEnemy.State.TELEGRAPH, TestEnemy.State.ATTACK, TestEnemy.State.DEAD]:
		return
	_play(hit_clip, 0.05)
	_hit_left = animation_player.get_animation(hit_clip).length


func _on_animation_finished(clip: StringName) -> void:
	# Доводка удара закончилась раньше восстановления — переходим в стойку.
	if clip == attack_clip and enemy.state == TestEnemy.State.RECOVERY:
		_play(idle_clip)


func _play(clip: StringName, blend := -1.0) -> void:
	animation_player.speed_scale = 1.0
	animation_player.play(clip, blend_time if blend < 0.0 else blend)
	animation_player.seek(0.0, true)
