class_name GuideBeacon
extends Node3D
## Переиспользуемый маяк текущей цели: мягкий свет, кольцо на земле, луч
## и несколько «следов», ведущих к точке. Включается на событие и гаснет,
## когда цель сменилась. Сам по себе ничего не знает о сюжете: id приходит
## из BeatData.guide_beacon_id, а решение принимает владелец локации.

@export var beacon_id: StringName = &""
@export var accent_color := Color(0.96, 0.72, 0.42)
@export var light_energy := 1.35
@export var light_range := 4.5
@export var ring_radius := 0.52
@export var beam_height := 2.6
@export var trail_marks := 3
@export var fade_seconds := 0.6
@export var pulse_speed := 1.7
@export var enabled := false

var _active := false
var _opacity := 0.0
var _time := 0.0
var _light: OmniLight3D
var _ring: MeshInstance3D
var _beam: MeshInstance3D
var _marks: Array[MeshInstance3D] = []
var _ring_material: StandardMaterial3D
var _beam_material: StandardMaterial3D
var _mark_material: StandardMaterial3D
var _sense_suppressors: Dictionary = {}


func _ready() -> void:
	add_to_group(&"guide_beacon")
	_build_visuals()
	_apply_opacity()
	set_enabled(enabled, true)


func set_enabled(value: bool, instant := false) -> void:
	_active = value
	enabled = value
	if instant:
		_opacity = 1.0 if value else 0.0
		_apply_opacity()


func is_active() -> bool:
	return _active


func get_opacity() -> float:
	return _opacity


## Чутьё временно гасит маяк, чтобы не дублировать ту же подсказку.
## Несколько источников могут подавлять один маяк одновременно.
func set_sense_suppressed(value: bool, source: Object = null) -> void:
	var key := source.get_instance_id() if source != null else 0
	if value:
		_sense_suppressors[key] = true
	else:
		_sense_suppressors.erase(key)
	_apply_opacity()


func is_sense_suppressed() -> bool:
	return not _sense_suppressors.is_empty()


func _process(delta: float) -> void:
	_time += delta
	var target := 1.0 if _active else 0.0
	var speed := 1.0 / maxf(fade_seconds, 0.01)
	_opacity = move_toward(_opacity, target, speed * delta)
	_apply_opacity()


func _apply_opacity() -> void:
	var pulse := 0.88 + 0.12 * sin(_time * pulse_speed)
	var visible_opacity := 0.0 if is_sense_suppressed() else _opacity
	if _light != null:
		_light.light_energy = light_energy * visible_opacity * pulse
		_light.visible = visible_opacity > 0.01
	if _ring != null:
		_ring.visible = visible_opacity > 0.01
		_ring.transparency = 1.0 - visible_opacity
	if _beam != null:
		_beam.visible = visible_opacity > 0.01
		_beam.transparency = 1.0 - visible_opacity * 0.85
	if _ring_material != null:
		_ring_material.emission_energy_multiplier = 1.4 * visible_opacity * pulse
	if _beam_material != null:
		_beam_material.emission_energy_multiplier = 0.7 * visible_opacity
	for mark in _marks:
		mark.visible = visible_opacity > 0.01
		mark.transparency = 1.0 - visible_opacity


func _build_visuals() -> void:
	_ring_material = _glow_material(0.9, 0.65)
	_beam_material = _glow_material(0.28, 0.9)
	_mark_material = _glow_material(0.42, 0.85)

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = maxf(ring_radius - 0.06, 0.05)
	ring_mesh.outer_radius = ring_radius + 0.06
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 8
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	_ring.mesh = ring_mesh
	_ring.material_override = _ring_material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = 0.03
	add_child(_ring)

	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.035
	beam_mesh.bottom_radius = 0.09
	beam_mesh.height = beam_height
	beam_mesh.radial_segments = 8
	_beam = MeshInstance3D.new()
	_beam.name = "Beam"
	_beam.mesh = beam_mesh
	_beam.material_override = _beam_material
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position.y = beam_height * 0.5
	add_child(_beam)

	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = accent_color
	light.light_energy = light_energy
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.position.y = 0.35
	add_child(light)
	_light = light

	var mark_mesh := BoxMesh.new()
	mark_mesh.size = Vector3(0.26, 0.012, 0.075)
	for index in maxi(trail_marks, 0):
		var mark := MeshInstance3D.new()
		mark.name = "Track%02d" % index
		mark.mesh = mark_mesh
		mark.material_override = _mark_material
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var distance := 0.45 + float(index) * 0.55
		mark.position = Vector3(0.08 * (index % 2 * 2 - 1), 0.025, distance)
		add_child(mark)
		_marks.append(mark)


func _glow_material(alpha: float, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(accent_color.r, accent_color.g, accent_color.b, alpha)
	material.emission_enabled = true
	material.emission = accent_color
	material.emission_energy_multiplier = emission
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
