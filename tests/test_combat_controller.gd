extends GutTest
## Боевая основа Санни: удар, уворот с i-frames, блок, выносливость,
## данные из .tres и возврат на чекпоинт после смерти.

const SUNNY_SCENE := "res://scenes/characters/sunny.tscn"
const ARMED_PATH := "res://resources/combat/attacks/sunny_light_armed.tres"
const UNARMED_PATH := "res://resources/combat/attacks/sunny_light_unarmed.tres"

var sunny: SunnyController
var combat: CombatController
var stamina: StaminaComponent
var hurtbox: Hurtbox


func before_each() -> void:
	sunny = (load(SUNNY_SCENE) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	sunny.attack.set_physics_process(false)
	combat = sunny.get_node("CombatController") as CombatController
	combat.set_physics_process(false)
	stamina = sunny.stamina
	stamina.set_physics_process(false)
	hurtbox = sunny.get_node("Hurtbox") as Hurtbox
	combat.set_forced_combat(true)


func after_each() -> void:
	Input.action_release("sprint")
	Input.action_release("jump")
	Input.action_release("attack")


func test_attack_data_is_loaded_from_tres_and_spends_stamina() -> void:
	var data := combat.current_attack_data()
	assert_not_null(data, "удар берёт AttackData")
	assert_true(data is AttackData)
	assert_eq(data.damage, 20.0)
	assert_gt(data.stamina_cost, 0.0)
	var before := stamina.current_stamina
	assert_true(combat.try_light_attack())
	assert_almost_eq(stamina.current_stamina, before - data.stamina_cost, 0.001)
	assert_true(sunny.attack.is_attacking())
	assert_false(combat.try_light_attack(), "второй удар во время атаки не начинается")

	sunny.attack.tick(10.0)
	stamina.set_current(0.0)
	assert_false(combat.try_light_attack(), "без выносливости удара нет")


func test_light_attack_damages_target_only_in_active_window() -> void:
	var victim := Hurtbox.new()
	var victim_health := HealthComponent.new()
	victim_health.max_health = 100.0
	victim.add_child(victim_health)
	victim.health = victim_health
	add_child_autofree(victim)
	var data := combat.current_attack_data()
	assert_true(combat.try_light_attack())
	assert_false(sunny.attack.apply_hit(victim), "замах не наносит урон")
	sunny.attack.tick(data.windup_time + 0.01)
	assert_true(sunny.attack.is_active())
	assert_true(sunny.attack.apply_hit(victim), "в активном окне урон проходит")
	assert_eq(victim_health.current_health, 100.0 - data.damage)


func test_dodge_has_iframes_and_consumes_stamina() -> void:
	var before := stamina.current_stamina
	assert_true(combat.try_dodge())
	assert_true(combat.is_dodging())
	assert_true(sunny.is_dodging())
	assert_true(hurtbox.invulnerable, "во время i-frames урон не проходит")
	assert_almost_eq(stamina.current_stamina, before - combat.settings.dodge_stamina_cost, 0.001)
	var health_before := sunny.health.current_health
	assert_false(hurtbox.receive_hit(12.0, self), "удар в i-frames игнорируется")
	assert_eq(sunny.health.current_health, health_before)

	combat.advance(combat.settings.dodge_iframe_time + 0.01)
	assert_false(hurtbox.invulnerable, "окно неуязвимости закрылось")
	assert_true(hurtbox.receive_hit(12.0, self), "после i-frames урон снова проходит")
	assert_lt(sunny.health.current_health, health_before)


func test_block_reduces_damage_and_spends_stamina() -> void:
	stamina.set_current(100.0)
	combat.set_blocking(true)
	assert_true(combat.is_blocking())
	assert_almost_eq(hurtbox.damage_scale, combat.settings.block_damage_multiplier, 0.001)
	var health_before := sunny.health.current_health
	var stamina_before := stamina.current_stamina
	assert_true(hurtbox.receive_hit(20.0, self))
	assert_almost_eq(sunny.health.current_health, health_before - 6.0, 0.001, "блок пропускает 30% урона")
	assert_lt(stamina.current_stamina, stamina_before, "блок тратит выносливость")

	combat.set_blocking(false)
	assert_almost_eq(hurtbox.damage_scale, 1.0, 0.001)


func test_block_breaks_when_stamina_runs_out() -> void:
	stamina.set_current(5.0)
	combat.set_blocking(true)
	watch_signals(combat)
	hurtbox.receive_hit(10.0, self)
	assert_false(combat.is_blocking(), "на нуле выносливости блок ломается")
	assert_true(combat.is_staggered())
	assert_signal_emitted(combat, "guard_broken")


func test_post_hit_iframes_prevent_double_hit() -> void:
	var health_before := sunny.health.current_health
	assert_true(hurtbox.receive_hit(10.0, self))
	assert_true(combat.is_invulnerable(), "после попадания открыто короткое окно i-frames")
	var after_first := sunny.health.current_health
	assert_eq(after_first, health_before - 10.0)
	assert_false(hurtbox.receive_hit(10.0, self), "второй удар в том же окне игнорируется")
	assert_eq(sunny.health.current_health, after_first)
	combat.advance(combat.settings.post_hit_iframe_time + 0.01)
	assert_false(combat.is_invulnerable(), "окно закрылось")
	assert_true(hurtbox.receive_hit(10.0, self), "после окна урон снова проходит")


func test_stamina_regenerates_after_delay() -> void:
	stamina.set_current(10.0)
	stamina.tick(combat.settings.stamina_regen_delay + 0.5)
	assert_gt(stamina.current_stamina, 10.0)
	stamina.tick(20.0)
	assert_eq(stamina.current_stamina, stamina.max_stamina)


func test_unarmed_mode_uses_another_attack_data() -> void:
	var armed := load(ARMED_PATH) as AttackData
	var unarmed := load(UNARMED_PATH) as AttackData
	assert_not_null(armed)
	assert_not_null(unarmed)
	assert_lt(unarmed.damage, armed.damage)
	combat.set_unarmed(true)
	assert_true(combat.is_unarmed())
	assert_eq(combat.current_attack_data(), unarmed)
	combat.set_unarmed(false)
	assert_eq(combat.current_attack_data(), armed)


func test_death_in_combat_returns_to_last_checkpoint() -> void:
	var recovery := sunny.get_node("FallRecovery") as FallRecovery
	var checkpoint := Vector3(3.0, 0.05, 3.0)
	recovery.set_checkpoint(checkpoint, &"CP-COMBAT")
	sunny.global_position = Vector3(8.0, 0.05, 4.0)
	stamina.set_current(12.0)
	sunny.health.take_damage(sunny.health.max_health)
	await wait_process_frames(1)
	assert_almost_eq(sunny.global_position.x, checkpoint.x, 0.01, "смерть возвращает на X чекпоинта")
	assert_almost_eq(sunny.global_position.z, checkpoint.z, 0.01, "смерть возвращает на Z чекпоинта")
	assert_lt(absf(sunny.global_position.y - checkpoint.y), 0.2, "по высоте чекпоинта")
	assert_false(sunny.is_dead(), "после возврата Санни снова жив")
	assert_eq(stamina.current_stamina, stamina.max_stamina, "чекпоинт восстанавливает выносливость")
