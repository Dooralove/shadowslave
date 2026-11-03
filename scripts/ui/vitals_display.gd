class_name VitalsDisplay
extends RefCounted
## Frame-rate independent display model for a health/stamina bar.
##
## Gameplay code writes the real values; the HUD reads the smoothed values.
## The model never owns a Control and never emits signals, so it can be tested
## headlessly without a scene tree.

var maximum := 100.0
var current := 100.0
var target_ratio := 1.0
var displayed_ratio := 1.0
var ghost_ratio := 1.0
var flash := 0.0
var ghost_delay_left := 0.0

var catch_up_speed := 14.0
var ghost_delay := 0.28
var ghost_drain_speed := 0.85
var flash_decay := 4.5
var use_ghost := true


func setup(maximum_value: float, current_value: float) -> void:
	maximum = maxf(maximum_value, 1.0)
	current = clampf(current_value, 0.0, maximum)
	target_ratio = current / maximum
	displayed_ratio = target_ratio
	ghost_ratio = target_ratio
	ghost_delay_left = 0.0
	flash = 0.0


func set_values(current_value: float, maximum_value: float) -> void:
	var old_maximum := maximum
	var old_target := target_ratio
	maximum = maxf(maximum_value, 1.0)
	current = clampf(current_value, 0.0, maximum)
	target_ratio = current / maximum

	if not is_equal_approx(old_maximum, maximum):
		# A max-health change is a rules event, not a hit: do not animate a
		# misleading damage trail across the whole bar.
		displayed_ratio = target_ratio
		ghost_ratio = target_ratio
		ghost_delay_left = 0.0
		return

	if target_ratio < old_target - 0.0001:
		if use_ghost:
			ghost_ratio = maxf(ghost_ratio, maxf(old_target, displayed_ratio))
			ghost_delay_left = ghost_delay
	elif target_ratio > old_target + 0.0001:
		# Healing should not leave a stale "lost health" trail.
		ghost_ratio = target_ratio
		ghost_delay_left = 0.0

	if target_ratio <= 0.0:
		ghost_ratio = 0.0


func tick(delta: float) -> void:
	var dt := maxf(delta, 0.0)
	var k := 1.0 - exp(-catch_up_speed * dt)
	displayed_ratio = lerpf(displayed_ratio, target_ratio, k)
	if absf(displayed_ratio - target_ratio) < 0.0005:
		displayed_ratio = target_ratio

	if use_ghost and ghost_ratio > displayed_ratio + 0.0005:
		ghost_delay_left = maxf(ghost_delay_left - dt, 0.0)
		if ghost_delay_left <= 0.0:
			ghost_ratio = move_toward(ghost_ratio, displayed_ratio, ghost_drain_speed * dt)
	else:
		ghost_ratio = displayed_ratio

	flash = maxf(flash - flash_decay * dt, 0.0)


func snap() -> void:
	displayed_ratio = target_ratio
	ghost_ratio = target_ratio
	ghost_delay_left = 0.0


func is_critical(threshold := 0.3) -> bool:
	return target_ratio <= threshold and target_ratio > 0.0


func is_dead() -> bool:
	return target_ratio <= 0.0
