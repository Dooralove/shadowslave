extends GutTest
## Правила HealthComponent: урон, лечение, пределы, смерть ровно один раз.


func _make_health(max_health := 100.0, initial := -1.0) -> HealthComponent:
	var health := HealthComponent.new()
	health.max_health = max_health
	health.initial_health = initial
	add_child_autofree(health)
	return health


func test_starts_at_max_by_default() -> void:
	var health := _make_health(80.0)
	assert_eq(health.current_health, 80.0)
	assert_false(health.is_dead())


func test_initial_health_is_clamped_to_max() -> void:
	assert_eq(_make_health(50.0, 500.0).current_health, 50.0)


func test_take_damage_reduces_health_and_reports_applied() -> void:
	var health := _make_health()
	assert_eq(health.take_damage(30.0), 30.0)
	assert_eq(health.current_health, 70.0)


func test_health_never_goes_below_zero() -> void:
	var health := _make_health(40.0)
	assert_eq(health.take_damage(100.0), 40.0, "засчитывается только оставшееся здоровье")
	assert_eq(health.current_health, 0.0)


func test_heal_is_clamped_to_max() -> void:
	var health := _make_health(100.0, 90.0)
	assert_eq(health.heal(50.0), 10.0)
	assert_eq(health.current_health, 100.0)


func test_non_positive_amounts_are_ignored() -> void:
	var health := _make_health()
	watch_signals(health)
	assert_eq(health.take_damage(0.0), 0.0)
	assert_eq(health.take_damage(-10.0), 0.0)
	assert_eq(health.heal(-10.0), 0.0)
	assert_eq(health.current_health, 100.0)
	assert_signal_not_emitted(health, "health_changed")


func test_signals_on_damage() -> void:
	var health := _make_health()
	watch_signals(health)
	health.take_damage(25.0)
	assert_signal_emitted_with_parameters(health, "damaged", [25.0])
	assert_signal_emitted_with_parameters(health, "health_changed", [75.0, 100.0])


func test_died_is_emitted_exactly_once() -> void:
	var health := _make_health(50.0)
	watch_signals(health)
	health.take_damage(30.0)
	health.take_damage(30.0)
	health.take_damage(30.0)
	assert_true(health.is_dead())
	assert_signal_emit_count(health, "died", 1)


func test_dead_ignores_damage_and_healing() -> void:
	var health := _make_health(10.0)
	health.take_damage(10.0)
	watch_signals(health)
	assert_eq(health.take_damage(5.0), 0.0)
	assert_eq(health.heal(5.0), 0.0)
	assert_eq(health.current_health, 0.0)
	assert_signal_not_emitted(health, "health_changed")
