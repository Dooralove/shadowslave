extends SliceLocation
## P2.5 / B13: Spell Void — переход из реального мира в Первый Кошмар.
## Сцена не содержит геймплея: только камера, руны, силуэт и частицы.
## Никаких коллизий, маршрутов и интерактивных объектов здесь нет.

@onready var _rune: Node3D = $RuneCircle
@onready var _halo: Node3D = $Halo
@onready var _sunny: Node3D = $SunnyVoid
@onready var _sunny_animation: AnimationPlayer = $SunnyVoid/AnimationPlayer
@onready var _spell_camera: Camera3D = $Shots/SpellShot


func _ready() -> void:
	super._ready()
	_rune.scale = Vector3(0.001, 0.001, 0.001)
	_halo.scale = Vector3(0.35, 0.35, 0.35)
	if _sunny_animation != null:
		_sunny_animation.play(&"sunny/Idle_Relaxed")


func play_cutscene(id: StringName, fast: bool) -> void:
	match id:
		&"spell":
			await _spell_sequence(fast)
		_:
			super.play_cutscene(id, fast)


func _spell_sequence(fast: bool) -> void:
	var camera := shot(&"SpellShot")
	if camera != null:
		camera.make_current()
	if fast:
		_rune.scale = Vector3.ONE
		_halo.scale = Vector3(0.6, 0.6, 0.6)
		_sunny.position.y = 0.12
		return

	_rune.scale = Vector3(0.001, 0.001, 0.001)
	_halo.scale = Vector3(0.35, 0.35, 0.35)
	_sunny.position.y = 0.0

	var grow := create_tween().set_parallel()
	grow.tween_property(_rune, "scale", Vector3.ONE, 3.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	grow.tween_property(_halo, "scale", Vector3(0.6, 0.6, 0.6), 3.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	grow.tween_property(_sunny, "position:y", 0.12, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if camera != null:
		var from := camera.global_position
		var to := Vector3(0.55, 1.8, 4.0)
		var move := create_tween()
		move.tween_method(func(t: float) -> void:
			camera.global_position = from.lerp(to, t)
			camera.look_at(Vector3(0, 1.12, 0), Vector3.UP)
		, 0.0, 1.0, 5.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await move.finished
	else:
		await pause(3.2, fast)

	var pulse := create_tween().set_loops(2)
	pulse.tween_property(_rune, "scale", Vector3(1.035, 1.0, 1.035), 0.55).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_rune, "scale", Vector3.ONE, 0.55).set_trans(Tween.TRANS_SINE)
	await pulse.finished
	await pause(0.9, fast)
