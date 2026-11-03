extends GutTest
## Stage 5 regression coverage for A05: wounded profile, weak spot dedup,
## group attack tokens, player-death respawn and the combat target API.

const ENEMY_SCENE := "res://scenes/enemies/carapace_enemy.tscn"
const HUD_SCENE := "res://scenes/ui/combat_hud.tscn"
const SUNNY_SCENE := "res://scenes/characters/sunny.tscn"
const WOUNDED := "res://resources/combat/enemies/carapace_wounded_e01.tres"
const ARMED := "res://resources/combat/attacks/sunny_light_armed.tres"


func _make_hurtbox(max_health: float, multiplier := 1.0) -> Hurtbox:
	var box := Hurtbox.new()
	var hp := HealthComponent.new()
	hp.max_health = max_health
	box.add_child(hp)
	box.health = hp
	box.damage_multiplier = multiplier
	add_child_autofree(box)
	return box


func _make_attack() -> MeleeAttack:
	var attack := MeleeAttack.new()
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	attack.add_child(shape)
	var stats := AttackStats.new()
	stats.damage = 10.0
	stats.cooldown = 1.0
	stats.windup_time = 0.0
	stats.active_time = 0.2
	attack.stats = stats
	add_child_autofree(attack)
	attack.set_physics_process(false)
	return attack


func _make_enemy() -> CarapaceEnemy:
	var enemy := (load(ENEMY_SCENE) as PackedScene).instantiate() as CarapaceEnemy
	add_child_autofree(enemy)
	return enemy


func test_wounded_e01_profile_is_valid() -> void:
	var data := load(WOUNDED) as EnemyData
	assert_not_null(data)
	assert_eq(data.id, &"carapace_wounded_e01")
	assert_almost_eq(data.max_health, 65.0, 0.001)
	assert_almost_eq(data.attack.damage, 18.0, 0.001)
	assert_almost_eq(data.telegraph_time, 0.95, 0.001)
	assert_almost_eq(data.move_speed, 1.6, 0.001)


func test_spawn_profile_applies_by_quest_tag() -> void:
	var enemy := (load(ENEMY_SCENE) as PackedScene).instantiate() as CarapaceEnemy
	enemy.spawn_profile = load(WOUNDED) as EnemyData
	enemy.spawn_profile_tag = &"wounded_scavenger"
	var credit := QuestKillCredit.new()
	credit.name = "QuestKillCredit"
	credit.enemy_tag = &"wounded_scavenger"
	enemy.add_child(credit)
	add_child_autofree(enemy)
	await wait_process_frames(2)
	enemy.call(&"_apply_spawn_profile")
	assert_eq(enemy.data.id, &"carapace_wounded_e01")
	assert_almost_eq(enemy.telegraph_time, 0.95, 0.001)
	assert_almost_eq(enemy.health.max_health, 65.0, 0.001)


func test_weak_spot_hurtbox_uses_multiplier() -> void:
	var enemy := _make_enemy()
	await wait_process_frames(2)
	var weak := enemy.get_node_or_null(^"Visual/Model/WeakSpot/WeakSpotHurtbox") as Hurtbox
	assert_not_null(weak)
	if weak == null:
		return
	assert_eq(weak.health, enemy.health)
	assert_almost_eq(weak.damage_multiplier, 1.5, 0.001)
	var before := enemy.health.current_health
	weak.receive_hit(10.0, null)
	assert_almost_eq(before - enemy.health.current_health, 15.0, 0.001)


func test_melee_attack_prefers_weak_spot_and_does_not_double_hit() -> void:
	var weak := _make_hurtbox(100.0, 1.5)
	var body := _make_hurtbox(100.0)
	body.health = weak.health
	var attack := _make_attack()
	var areas: Array[Area3D] = [body, weak]
	var selected := attack.select_hit_targets(areas)
	assert_eq(selected.size(), 1)
	assert_eq(selected[0], weak)
	assert_true(attack.try_attack())
	assert_true(attack.apply_hit(weak))
	assert_false(attack.apply_hit(body), "same HealthComponent must not be hit twice")
	assert_almost_eq(weak.health.current_health, 85.0, 0.001)


func test_group_token_limits_simultaneous_attackers() -> void:
	var enemies: Array[CarapaceEnemy] = []
	for index in 3:
		var enemy := _make_enemy()
		enemy.global_position = Vector3(float(index) * 1.5, 0.0, 0.0)
		enemy.group_attack_gap = 0.0
		enemy.set_physics_process(false)
		enemies.append(enemy)
	var target := Node3D.new()
	add_child_autofree(target)
	for enemy in enemies:
		enemy.target = target
	enemies[0].state = CarapaceEnemy.State.TELEGRAPH
	enemies[1].state = CarapaceEnemy.State.TELEGRAPH
	enemies[2].state = CarapaceEnemy.State.IDLE
	assert_eq(enemies[2].nearby_attacker_count(), 2)
	assert_false(enemies[2].can_start_attack())
	enemies[0].state = CarapaceEnemy.State.IDLE
	assert_true(enemies[2].can_start_attack())


func test_group_gap_delays_second_attack() -> void:
	var first := _make_enemy()
	var second := _make_enemy()
	first.global_position = Vector3.ZERO
	second.global_position = Vector3(1.5, 0.0, 0.0)
	first.set_physics_process(false)
	second.set_physics_process(false)
	var target := Node3D.new()
	add_child_autofree(target)
	first.target = target
	second.target = target
	first.state = CarapaceEnemy.State.TELEGRAPH
	first._state_time = 0.0
	second.state = CarapaceEnemy.State.CHASE
	second.group_attack_gap = 1.0
	assert_false(second.can_start_attack(), "second attack must wait for group gap")
	first._state_time = 1.0
	assert_true(second.can_start_attack(), "gap expires without requiring a third attacker")


func test_respawn_heals_living_enemy_and_does_not_revive_dead() -> void:
	var enemy := _make_enemy()
	enemy.global_position = Vector3(4.0, 0.0, 0.0)
	await wait_process_frames(2)
	var player := Node3D.new()
	player.name = "Player"
	var player_health := HealthComponent.new()
	player_health.name = "Health"
	player_health.max_health = 100.0
	player.add_child(player_health)
	add_child_autofree(player)
	enemy.target = player
	enemy.alert_to(player)
	enemy.set_physics_process(false)
	var spawn := enemy._spawn_transform.origin
	enemy.health.take_damage(40.0)
	player_health.take_damage(1000.0)
	await wait_process_frames(3)
	assert_almost_eq(enemy.health.current_health, enemy.health.max_health, 0.001)
	assert_eq(enemy.state, CarapaceEnemy.State.IDLE)
	assert_true(enemy.global_position.is_equal_approx(spawn))
	enemy.health.take_damage(1000.0)
	assert_eq(enemy.state, CarapaceEnemy.State.DEAD)
	player_health.revive()
	player_health.take_damage(1000.0)
	await wait_process_frames(3)
	assert_eq(enemy.state, CarapaceEnemy.State.DEAD, "dead enemy must not be revived")


func test_combat_target_api_tracks_death() -> void:
	var sunny := (load(SUNNY_SCENE) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	await wait_process_frames(2)
	assert_true(sunny.combat.has_signal("combat_target_changed"))
	assert_true(sunny.combat.has_method("get_combat_target"))
	var seen: Array[Node3D] = []
	sunny.combat.combat_target_changed.connect(func(target: Node3D) -> void: seen.append(target))
	var enemy := _make_enemy()
	enemy.global_position = sunny.global_position + Vector3(3.0, 0.0, 0.0)
	enemy.set_physics_process(false)
	await wait_seconds(0.35)
	assert_eq(sunny.combat.get_combat_target(), enemy)
	assert_true(seen.has(enemy), "signal must report the acquired target")
	enemy.health.take_damage(1000.0)
	await wait_seconds(0.35)
	assert_null(sunny.combat.get_combat_target())
	assert_true(seen.has(null), "signal must report the cleared target")


func test_equip_armed_api_rejects_missing_clip() -> void:
	var sunny := (load(SUNNY_SCENE) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	await wait_process_frames(2)
	var data := load(ARMED) as AttackData
	assert_true(sunny.combat.equip_armed(data, &"1H_Melee_Attack_Slice_Diagonal"))
	assert_almost_eq(sunny.combat.current_attack_data().damage, 20.0, 0.001)
	assert_false(sunny.combat.equip_armed(data, &"Missing_Blade_Clip"))


func test_authored_enemy_clips_are_registered() -> void:
	var carapace := _make_enemy()
	await wait_process_frames(2)
	var carapace_player := carapace.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(carapace_player, "carapace AnimationPlayer найден")
	if carapace_player != null:
		assert_true(carapace_player.has_animation(&"Hit"), "carapace authored Hit подключён")
	var larva := (load("res://scenes/enemies/larva_enemy.tscn") as PackedScene).instantiate()
	add_child_autofree(larva)
	await wait_process_frames(2)
	var larva_player := larva.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(larva_player, "larva AnimationPlayer найден")
	if larva_player != null:
		assert_true(larva_player.has_animation(&"Hit"), "larva authored Hit подключён")
		assert_true(larva_player.has_animation(&"Death"), "larva authored Death подключён")


func test_hud_switches_target_and_hides_after_both_dead() -> void:
	var hud := (load(HUD_SCENE) as PackedScene).instantiate() as CombatHud
	hud.first_reveal_seconds = 0.0
	add_child_autofree(hud)
	var sunny := (load(SUNNY_SCENE) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	await wait_process_frames(2)
	hud.bind_player(sunny)
	var first := _make_enemy()
	var second := _make_enemy()
	first.global_position = sunny.global_position + Vector3(3.0, 0.0, 0.0)
	second.global_position = sunny.global_position + Vector3(6.0, 0.0, 0.0)
	first.set_physics_process(false)
	second.set_physics_process(false)
	await wait_seconds(0.7)
	assert_eq(hud._enemy_health, first.health)
	first.health.take_damage(1000.0)
	await wait_seconds(0.7)
	assert_eq(hud._enemy_health, second.health)
	second.health.take_damage(1000.0)
	await wait_seconds(0.7)
	assert_false(hud.enemy_panel.visible)
