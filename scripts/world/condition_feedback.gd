class_name ConditionFeedback
extends Node
## Диегетическая обратная связь холода и шума: дыхание, виньетка и звук.
## Никаких полосок: значения cold/noise задают будущие системы погоды и стелса.

const BREATH_STREAM := preload("res://assets/audio/combat/breath_cold_loop.wav")
const NOISE_STREAM := preload("res://assets/audio/combat/noise_rustle_loop.wav")
const VIGNETTE_SHADER := preload("res://assets/shaders/condition_vignette.gdshader")

@export_range(0.0, 1.0) var cold := 0.0:
	set(value):
		cold = clampf(value, 0.0, 1.0)
		_apply()
@export_range(0.0, 1.0) var noise := 0.0:
	set(value):
		noise = clampf(value, 0.0, 1.0)
		_apply()

var _layer: CanvasLayer
var _vignette: ColorRect
var _material: ShaderMaterial
var _breath: AudioStreamPlayer
var _noise_player: AudioStreamPlayer


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "ConditionLayer"
	_layer.layer = 7
	add_child(_layer)
	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	_material.shader = VIGNETTE_SHADER
	_vignette.material = _material
	_layer.add_child(_vignette)
	_breath = AudioStreamPlayer.new()
	_breath.name = "ColdBreath"
	_breath.bus = &"Ambience"
	_breath.stream = _looped(BREATH_STREAM)
	_breath.volume_db = -80.0
	add_child(_breath)
	_noise_player = AudioStreamPlayer.new()
	_noise_player.name = "NoiseRustle"
	_noise_player.bus = &"Ambience"
	_noise_player.stream = _looped(NOISE_STREAM)
	_noise_player.volume_db = -80.0
	add_child(_noise_player)
	_apply()


func _exit_tree() -> void:
	for player in [_breath, _noise_player]:
		if player != null and is_instance_valid(player):
			player.stop()
			player.stream = null


func set_cold(value: float) -> void:
	cold = value


func set_noise(value: float) -> void:
	noise = value


func get_vignette() -> ColorRect:
	return _vignette


func get_breath_player() -> AudioStreamPlayer:
	return _breath


func get_noise_player() -> AudioStreamPlayer:
	return _noise_player


func _apply() -> void:
	if _material != null:
		_material.set_shader_parameter(&"cold", cold)
		_material.set_shader_parameter(&"noise", noise)
		if _vignette != null:
			_vignette.visible = cold > 0.01 or noise > 0.01
	_apply_audio(_breath, cold, -34.0, -12.0)
	_apply_audio(_noise_player, noise, -38.0, -16.0)


func _apply_audio(player: AudioStreamPlayer, level: float, min_db: float, max_db: float) -> void:
	if player == null:
		return
	player.volume_db = lerpf(min_db, max_db, level)
	if level <= 0.01:
		if player.playing:
			player.stop()
	elif not player.playing:
		player.play()


func _looped(source: AudioStream) -> AudioStream:
	var wav := source as AudioStreamWAV
	if wav == null:
		return source
	var copy := wav.duplicate() as AudioStreamWAV
	copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
	copy.loop_begin = 0
	copy.loop_end = int(copy.get_length() * copy.mix_rate)
	return copy
