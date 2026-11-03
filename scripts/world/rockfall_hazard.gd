class_name RockfallHazard
extends Node3D
## Опасная зона камнепада: пыль и звук предупреждают заранее, затем удар
## проверяет, успел ли игрок выйти. Это не второй AI и не отдельный режиссёр.

signal warning_started
signal impact_resolved(hit: bool)

const WARNING_SOUND := preload("res://assets/audio/sanctuary/stone_door_large_001.ogg")

@export var radius := 5.8
@export var warning_time := 1.4
@export var damage := 9999.0

var _warning_active := false
var _audio: AudioStreamPlayer3D
var _dust: GPUParticles3D


func _ready() -> void:
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "Warning"
	_audio.bus = &"SFX"
	_audio.stream = WARNING_SOUND
	_audio.volume_db = -10.0
	_audio.max_distance = 28.0
	add_child(_audio)
	_dust = GPUParticles3D.new()
	_dust.name = "Dust"
	_dust.amount = 48
	_dust.lifetime = 1.1
	_dust.emitting = false
	_dust.visibility_aabb = AABB(Vector3(-radius * 2.0, -1.0, -radius * 2.0), Vector3(radius * 4.0, 7.0, radius * 4.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = radius * 0.55
	process.direction = Vector3.UP
	process.spread = 38.0
	process.initial_velocity_min = 0.8
	process.initial_velocity_max = 2.2
	process.gravity = Vector3(0.0, -2.5, 0.0)
	process.scale_min = 0.25
	process.scale_max = 0.7
	_dust.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.55, 0.53, 0.5, 0.32)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = material
	_dust.draw_pass_1 = quad
	add_child(_dust)


func _exit_tree() -> void:
	if _audio != null and is_instance_valid(_audio):
		_audio.stop()
		_audio.stream = null


func start_warning() -> void:
	_warning_active = true
	_dust.emitting = true
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.has_method(&"apply_3d_occlusion"):
		director.call(&"apply_3d_occlusion", _audio, global_position)
	if not _audio.playing:
		_audio.play()
	warning_started.emit()


func stop_warning() -> void:
	_warning_active = false
	_dust.emitting = false
	if _audio.playing:
		_audio.stop()


func is_warning_active() -> bool:
	return _warning_active


## Возвращает true, если игрок не успел выйти из зоны.
func resolve_impact() -> bool:
	stop_warning()
	var hit := is_player_inside()
	if hit:
		var player := get_tree().get_first_node_in_group(&"player")
		var health: HealthComponent = null
		if player != null:
			health = player.get_node_or_null(^"Health") as HealthComponent
		if health != null:
			health.take_damage(damage)
	impact_resolved.emit(hit)
	return hit


func is_player_inside() -> bool:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return false
	var offset := player.global_position - global_position
	offset.y = 0.0
	return offset.length() <= radius


func reset() -> void:
	stop_warning()
