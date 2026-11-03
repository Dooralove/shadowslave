extends GutTest
## Интеграционный тест демонстрационного боевого полигона: три столкновения,
## активация по дистанции, урон игрока, завершение группы и итоговое сообщение.

const COURSE_SCENE := "res://scenes/levels/combat_course.tscn"

var course: Node3D
var player: SunnyController
var hud: CombatHud
var encounters: Array[CombatEncounter] = []


func before_each() -> void:
	course = (load(COURSE_SCENE) as PackedScene).instantiate() as Node3D
	add_child_autofree(course)
	await wait_process_frames(2)
	player = course.get_node("Level/Sunny") as SunnyController
	hud = course.get_node("HUD") as CombatHud
	player.attack.set_physics_process(false)
	encounters.clear()
	for child in course.get_node("Encounters").get_children():
		var encounter := child as CombatEncounter
		if encounter != null:
			encounters.append(encounter)


func _enemies(encounter: CombatEncounter) -> Array[Node]:
	var result: Array[Node] = []
	for node in encounter.find_children("*", "", true, false):
		if node.is_in_group(&"enemy"):
			result.append(node)
	return result


func test_course_has_three_encounters_and_five_enemies() -> void:
	assert_eq(encounters.size(), 3, "три сцены столкновений")
	var total := 0
	for encounter in encounters:
		total += encounter.enemy_count()
	assert_eq(total, 5, "один раненый карапакс, две личинки и два карапакса")
	assert_not_null(hud)
	assert_false(encounters[0].is_active(), "до подхода группа спит")


func test_encounter_activates_on_approach_and_clears_on_death() -> void:
	var encounter := encounters[0]
	var enemies := _enemies(encounter)
	assert_gt(enemies.size(), 0)
	var carapace := enemies[0] as CarapaceEnemy
	assert_true(carapace.is_dormant())
	assert_eq(carapace.collision_layer, 0, "спящий не блокирует проход")

	player.global_position = encounter.global_position + Vector3(0.0, 0.05, 2.5)
	await wait_physics_frames(4)
	assert_true(encounter.is_active(), "игрок в радиусе — группа проснулась")
	assert_false(carapace.is_dormant())
	assert_eq(carapace.collision_layer, 4)
	assert_eq(carapace.target, player)

	carapace.health.take_damage(1000.0)
	assert_true(encounter.is_cleared())
	assert_eq(encounter.remaining(), 0)


func test_player_light_attack_damages_carapace_once_per_swing() -> void:
	var encounter := encounters[0]
	var carapace := _enemies(encounter)[0] as CarapaceEnemy
	var hurtbox := carapace.get_node("Hurtbox") as Hurtbox
	player.global_position = encounter.global_position + Vector3(0.0, 0.05, 2.0)
	await wait_physics_frames(2)
	var before := carapace.health.current_health
	assert_true(player.try_attack())
	var stats := player.attack.stats
	player.attack.tick(stats.windup_time + 0.01)
	assert_true(player.attack.is_active())
	assert_true(player.attack.apply_hit(hurtbox))
	assert_false(player.attack.apply_hit(hurtbox), "один удар — одно попадание")
	assert_eq(carapace.health.current_health, before - stats.damage)


func test_player_can_kill_standard_carapace() -> void:
	var encounter := encounters[2]
	var carapace := _enemies(encounter)[0] as CarapaceEnemy
	var hurtbox := carapace.get_node("Hurtbox") as Hurtbox
	player.global_position = encounter.global_position + Vector3(0.0, 0.05, 2.0)
	await wait_physics_frames(2)
	var stats := player.attack.stats
	for i in 12:
		if carapace.health.is_dead():
			break
		if player.try_attack():
			player.attack.tick(stats.windup_time + 0.01)
			player.attack.apply_hit(hurtbox)
		player.attack.tick(2.0)
		player.stamina.refill()
	assert_true(carapace.health.is_dead(), "стандартный карапакс умирает от ударов игрока")
	assert_eq(encounter.remaining(), 1, "в паре остался второй карапакс")


func test_all_encounters_cleared_shows_course_message() -> void:
	for encounter in encounters:
		for enemy in _enemies(encounter):
			var health := enemy.get(&"health") as HealthComponent
			health.take_damage(1000.0)
	await wait_process_frames(1)
	assert_true(hud.message.visible)
	assert_string_contains(hud.message.text, "Полигон пройден")
