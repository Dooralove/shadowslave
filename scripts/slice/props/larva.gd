extends Node3D
## Временная личинка Горного Короля: примитивы, без AI и без коллизии.
## Анимация — только дрожь и повороты; сценарий управляет масштабом и видимостью.

@export var writhe_speed := 7.0
@export var writhe_amount := 0.08

var _time := 0.0
var _animation_player: AnimationPlayer


func _ready() -> void:
	# The rigged corpse-larva ships with an idle clip; keep the whole-body
	# writhe below as the gameplay-driven layer on top of it.
	_animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _animation_player != null:
		var clips := _animation_player.get_animation_list()
		if not clips.is_empty():
			var clip := _animation_player.get_animation(clips[0])
			if clip != null:
				clip.loop_mode = Animation.LOOP_LINEAR
			_animation_player.play(clips[0])


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	rotation.z = sin(_time * writhe_speed) * writhe_amount
	rotation.x = sin(_time * writhe_speed * 0.7 + 0.8) * writhe_amount * 0.6
