extends GutTest
## Сцена боевого испытания: загрузка, связи бойцов, HUD, итоговые сообщения.

const ARENA_SCENE := "res://scenes/levels/combat_arena.tscn"

var arena: Node3D
var sunny: SunnyController
var enemy: TestEnemy
var hud: CombatHud


func before_each() -> void:
	arena = (load(ARENA_SCENE) as PackedScene).instantiate()
	add_child_autofree(arena)
	sunny = arena.get_node("Level/Sunny")
	enemy = arena.get_node("TestEnemy")
	hud = arena.get_node("HUD")


func test_arena_has_fighters_and_hud() -> void:
	assert_not_null(sunny)
	assert_not_null(enemy)
	assert_not_null(hud)
	assert_eq(enemy.target, sunny, "противник нацелен на Санни")


func test_enemy_starts_idle_out_of_detection_range() -> void:
	assert_gt(enemy.distance_to_target(), enemy.detection_range, "есть время осмотреться до боя")
	assert_eq(enemy.state, TestEnemy.State.IDLE)


func test_health_bars_follow_health() -> void:
	assert_eq(hud.player_bar.max_value, sunny.health.max_health)
	assert_eq(hud.enemy_bar.max_value, enemy.health.max_health)
	enemy.health.take_damage(20.0)
	assert_eq(hud.enemy_bar.value, enemy.health.current_health)
	sunny.health.take_damage(15.0)
	assert_eq(hud.player_bar.value, sunny.health.current_health)


func test_victory_message() -> void:
	assert_false(hud.message.visible)
	enemy.health.take_damage(1000.0)
	assert_true(hud.message.visible)
	assert_string_contains(hud.message.text, "Победа")


func test_defeat_message() -> void:
	sunny.health.take_damage(1000.0)
	assert_true(hud.message.visible)
	assert_string_contains(hud.message.text, "погиб")
