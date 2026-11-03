extends GutTest
## Layered vitals HUD: display-model smoothing and CombatHud forwarding.

const HUD_SCENE := "res://scenes/ui/combat_hud.tscn"
const BAR_SCENE := "res://scenes/ui/vitals_bar.tscn"
const SUNNY_SCENE := "res://scenes/characters/sunny.tscn"


func test_display_smoothing_is_frame_rate_independent() -> void:
	var slow := VitalsDisplay.new()
	var fast := VitalsDisplay.new()
	for display in [slow, fast]:
		display.setup(100.0, 100.0)
		display.use_ghost = false
		display.catch_up_speed = 14.0
		display.set_values(20.0, 100.0)
	for _i in range(10):
		fast.tick(0.016)
	slow.tick(0.16)
	assert_almost_eq(slow.displayed_ratio, fast.displayed_ratio, 0.01, "10x16ms matches one 160ms step")


func test_display_ghost_delays_then_drains() -> void:
	var display := VitalsDisplay.new()
	display.setup(100.0, 100.0)
	display.catch_up_speed = 20.0
	display.ghost_delay = 0.2
	display.ghost_drain_speed = 1.0
	display.set_values(50.0, 100.0)
	display.tick(0.05)
	assert_gt(display.ghost_ratio, display.displayed_ratio, "ghost bar waits above the fill")
	display.tick(0.2)
	var before := display.ghost_ratio
	display.tick(0.1)
	assert_lt(display.ghost_ratio, before, "ghost bar drains after the delay")
	assert_gt(display.ghost_ratio, display.displayed_ratio, "ghost bar is still trailing")


func test_display_heal_snaps_ghost() -> void:
	var display := VitalsDisplay.new()
	display.setup(100.0, 100.0)
	display.set_values(30.0, 100.0)
	display.tick(0.5)
	display.set_values(100.0, 100.0)
	assert_almost_eq(display.ghost_ratio, 1.0, 0.001, "healing removes the lost-health trail")


func test_display_max_change_snaps_to_new_ratio() -> void:
	var display := VitalsDisplay.new()
	display.setup(100.0, 100.0)
	display.set_values(50.0, 100.0)
	display.tick(0.1)
	display.set_values(50.0, 200.0)
	assert_almost_eq(display.target_ratio, 0.25, 0.001)
	assert_almost_eq(display.displayed_ratio, 0.25, 0.001, "max change snaps instead of showing a fake hit")
	assert_almost_eq(display.ghost_ratio, 0.25, 0.001)


func test_vitals_bar_shows_critical_state() -> void:
	var bar := (load(BAR_SCENE) as PackedScene).instantiate() as VitalsBar
	add_child_autofree(bar)
	await wait_process_frames(2)
	bar.health.catch_up_speed = 40.0
	bar.set_health(22.0, 100.0)
	await wait_process_frames(30)
	assert_almost_eq(bar.health.target_ratio, 0.22, 0.001)
	assert_true(bar.get_node("%StatusLabel").visible, "critical label is visible")
	assert_true((bar.get_node("%HealthLabel") as Label).text.contains("22 / 100"), "health label shows numbers")
	var fill := bar.get_node("%Fill") as TextureRect
	assert_gt(fill.size.x, 0.0, "fill has a visible width")
	assert_lt(fill.size.x, 288.0, "fill is shorter than the full bar")


func test_combat_hud_forwards_health_to_vitals_bar() -> void:
	var hud := (load(HUD_SCENE) as PackedScene).instantiate() as CombatHud
	hud.first_reveal_seconds = 0.0
	add_child_autofree(hud)
	var sunny := (load(SUNNY_SCENE) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	await wait_process_frames(2)
	hud.bind_player(sunny)
	sunny.health.take_damage(40.0)
	await wait_process_frames(2)
	assert_not_null(hud.vitals_bar, "layered bar is present")
	if hud.vitals_bar != null:
		assert_almost_eq(hud.vitals_bar.health.target_ratio, 0.6, 0.01, "damage reaches the layered bar")
		assert_true(hud.player_panel.visible, "damaged HUD stays visible")
