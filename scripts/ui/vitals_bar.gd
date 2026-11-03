class_name VitalsBar
extends Control
## Layered coral reliquary health bar.
##
## It owns only presentation: CombatHud binds HealthComponent/StaminaComponent
## and forwards values. VitalsDisplay does the frame-rate independent smoothing;
## this script maps ratios to widths, colors and feedback.

@export var actor_name := "Санни"
@export_range(4.0, 40.0, 0.5) var health_catch_up := 14.0
@export_range(4.0, 40.0, 0.5) var stamina_catch_up := 22.0
@export_range(0.0, 1.0, 0.01) var ghost_delay := 0.18
@export_range(0.1, 4.0, 0.05) var ghost_drain_speed := 1.6
@export_range(0.0, 1.0, 0.01) var low_health_threshold := 0.3
@export_range(0.0, 1.0, 0.01) var wounded_threshold := 0.6

@export var healthy_color := Color(0.56, 0.84, 0.60)
@export var wounded_color := Color(0.95, 0.74, 0.38)
@export var critical_color := Color(0.90, 0.30, 0.22)
@export var stamina_color := Color(0.95, 0.78, 0.45)
@export var ghost_color := Color(0.58, 0.22, 0.16, 0.28)

@onready var _bar_glow: TextureRect = %BarGlow
@onready var _bar_clip: Control = %BarClip
@onready var _ghost: ColorRect = %Ghost
@onready var _fill: TextureRect = %Fill
@onready var _shine: TextureRect = %Shine
@onready var _stamina_fill: TextureRect = %StaminaFill
@onready var _medallion_glow: TextureRect = %MedallionGlow
@onready var _medallion: TextureRect = %Medallion
@onready var _medallion_core: TextureRect = %MedallionCore
@onready var _health_label: Label = %HealthLabel
@onready var _status_label: Label = %StatusLabel
@onready var _damage_overlay: ColorRect = %DamageOverlay

var health := VitalsDisplay.new()
var stamina := VitalsDisplay.new()

var _time := 0.0
var _bar_height := 24.0
var _stamina_height := 6.0
var _health_bound := false
var _stamina_bound := false


func _ready() -> void:
	stamina.use_ghost = false
	stamina.catch_up_speed = stamina_catch_up
	health.catch_up_speed = health_catch_up
	health.ghost_delay = ghost_delay
	health.ghost_drain_speed = ghost_drain_speed
	health.setup(100.0, 100.0)
	stamina.setup(100.0, 100.0)
	_bar_height = _fill.size.y
	_stamina_height = _stamina_fill.size.y
	_stamina_fill.modulate = stamina_color
	_status_label.add_theme_color_override("font_color", Color(0.95, 0.48, 0.34, 1.0))
	resized.connect(_update_pivots)
	_update_pivots()
	_apply_visuals()


func set_health(current: float, maximum: float) -> void:
	if not _health_bound:
		health.setup(maximum, current)
		_health_bound = true
		_apply_visuals()
		return
	var previous_target := health.target_ratio
	health.set_values(current, maximum)
	if health.target_ratio < previous_target - 0.0001:
		flash_damage()
	_apply_visuals()


## Public alias for gameplay code that uses the current_hp/max_hp naming.
func set_hp(current_hp: float, max_hp: float) -> void:
	set_health(current_hp, max_hp)


func set_stamina(current: float, maximum: float) -> void:
	if not _stamina_bound:
		stamina.setup(maximum, current)
		_stamina_bound = true
		_apply_visuals()
		return
	stamina.set_values(current, maximum)
	_apply_visuals()


func flash_damage() -> void:
	health.flash = 1.0


func _process(delta: float) -> void:
	health.tick(delta)
	stamina.tick(delta)
	_time += delta
	_apply_visuals()


func _update_pivots() -> void:
	if _medallion != null:
		_medallion.pivot_offset = _medallion.size * 0.5
	if _medallion_glow != null:
		_medallion_glow.pivot_offset = _medallion_glow.size * 0.5


func _apply_visuals() -> void:
	if _bar_clip == null:
		return
	var width := maxf(_bar_clip.size.x, 1.0)
	var health_width := width * clampf(health.displayed_ratio, 0.0, 1.0)
	var ghost_width := width * clampf(health.ghost_ratio, 0.0, 1.0)
	var stamina_width := width * clampf(stamina.displayed_ratio, 0.0, 1.0)

	_fill.size = Vector2(health_width, _bar_height)
	_ghost.size = Vector2(ghost_width, _bar_height)
	_shine.size = Vector2(health_width, _bar_height)
	_stamina_fill.size = Vector2(stamina_width, _stamina_height)

	var ratio := health.displayed_ratio
	var fill_color := healthy_color
	if ratio <= low_health_threshold:
		fill_color = critical_color
	elif ratio <= wounded_threshold:
		fill_color = wounded_color
	_fill.modulate = Color(fill_color.r, fill_color.g, fill_color.b, 1.0)
	_ghost.color = ghost_color

	var low := ratio <= low_health_threshold and health.target_ratio > 0.0
	var pulse := 0.5 + 0.5 * sin(_time * TAU / 1.05)
	var flash := clampf(health.flash, 0.0, 1.0)
	_bar_glow.modulate = Color(1.0, 1.0, 1.0, 0.10 + 0.16 * flash + (0.16 * pulse if low else 0.0))
	_medallion_glow.modulate = Color(1.0, 1.0, 1.0, 0.18 + 0.42 * flash + (0.20 * pulse if low else 0.0))
	_damage_overlay.color = Color(0.82, 0.08, 0.05, 0.24 * flash)
	var medallion_scale := 1.0 + 0.055 * flash
	_medallion.scale = Vector2(medallion_scale, medallion_scale)
	_medallion_glow.scale = Vector2(1.0 + 0.08 * flash, 1.0 + 0.08 * flash)
	_medallion_core.modulate = Color(0.55, 0.85, 1.0, 0.42 + 0.25 * flash + (0.15 * pulse if low else 0.0))

	_health_label.text = "%s · %d / %d" % [actor_name, roundi(health.current), roundi(health.maximum)]
	_health_label.modulate = Color(1.0, 0.78, 0.70, 1.0) if low else Color.WHITE
	_stamina_fill.modulate = stamina_color

	var show_status := low and not health.is_dead()
	if health.is_dead():
		_status_label.text = "ПАМЯТЬ УГАСЛА"
		show_status = true
	elif low:
		_status_label.text = "КРИТИЧЕСКОЕ СОСТОЯНИЕ"
	_status_label.visible = show_status
	_status_label.modulate = Color(1.0, 1.0, 1.0, 0.45 + 0.55 * pulse if low else 0.8)
