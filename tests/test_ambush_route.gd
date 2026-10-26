extends GutTest
## Геометрия маршрута засады: проход к укрытию, каньон и точка эвакуации.
## Проверки используют физические запросы капсулой игрока, а не только
## координаты узлов, поэтому ловят реальные коллизии после генерации CSG.

const SITE_SCENE := "res://scenes/locations/ambush_site/ambush_site.tscn"
const PLAYER_RADIUS := 0.34
const PLAYER_HEIGHT := 1.8
const CANYON_CENTER_Z := -12.0

var site: AmbushController
var space: PhysicsDirectSpaceState3D


func before_each() -> void:
	site = (load(SITE_SCENE) as PackedScene).instantiate() as AmbushController
	add_child_autofree(site)
	await wait_physics_frames(4)
	space = site.get_world_3d().direct_space_state


func _floor_height(x: float, z: float = CANYON_CENTER_Z) -> float:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(x, 8.0, z),
		Vector3(x, -4.0, z),
		1
	)
	var hit := space.intersect_ray(query)
	return hit.position.y if not hit.is_empty() else NAN


func _capsule_hits(position: Vector3) -> int:
	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = PLAYER_HEIGHT

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, position)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_shape(query, 8).size()


func test_floor_transition_from_arena_to_canyon_is_walkable() -> void:
	var arena_floor := _floor_height(-19.5)
	var canyon_floor := _floor_height(-20.5)
	assert_false(is_nan(arena_floor), "пол арены найден")
	assert_false(is_nan(canyon_floor), "вход в каньон имеет пол")
	if not is_nan(arena_floor) and not is_nan(canyon_floor):
		assert_lt(absf(canyon_floor - arena_floor), 0.25, "на входе в каньон нет высокого уступа")


func test_canyon_corridor_is_wide_enough_for_player() -> void:
	var floor_y := _floor_height(-27.5)
	assert_false(is_nan(floor_y))
	if is_nan(floor_y):
		return

	var ray_y := floor_y + 1.2
	var north := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(-27.5, ray_y, CANYON_CENTER_Z),
		Vector3(-27.5, ray_y, -15.0),
		1
	))
	var south := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(-27.5, ray_y, CANYON_CENTER_Z),
		Vector3(-27.5, ray_y, -9.0),
		1
	))
	assert_false(north.is_empty(), "северная стена каньона найдена")
	assert_false(south.is_empty(), "южная стена каньона найдена")
	if north.is_empty() or south.is_empty():
		return
	var width := absf(north.position.z - south.position.z)
	assert_gt(width, 1.45, "проход не уже капсулы игрока с запасом")
	assert_lt(width, 2.4, "проход остаётся локальным сужением, а не новой ареной")


func test_player_capsule_can_traverse_canyon_to_escape_point() -> void:
	var x := -20.5
	while x > -33.6:
		var floor_y := _floor_height(x)
		assert_false(is_nan(floor_y), "пол каньона найден в x=%.1f" % x)
		if not is_nan(floor_y):
			assert_eq(
				_capsule_hits(Vector3(x, floor_y + 1.1, CANYON_CENTER_Z)),
				0,
				"капсула игрока проходит каньон в x=%.1f" % x
			)
		x -= 1.0


func test_escape_trigger_stands_on_walkable_floor() -> void:
	var trigger := site.get_node("Triggers/Trigger_EscapeReach") as Area3D
	assert_not_null(trigger)
	if trigger == null:
		return

	assert_lt(trigger.global_position.x, -24.0, "точка эвакуации в глубине каньона")
	assert_almost_eq(trigger.global_position.z, CANYON_CENTER_Z, 0.25)
	var floor_y := _floor_height(trigger.global_position.x, trigger.global_position.z)
	assert_false(is_nan(floor_y), "под точкой эвакуации есть пол")
	if not is_nan(floor_y):
		assert_eq(
			_capsule_hits(Vector3(trigger.global_position.x, floor_y + 1.1, trigger.global_position.z)),
			0,
			"в точке эвакуации игрок помещается"
		)


func test_wagon_cover_has_reachable_approach() -> void:
	var cover_trigger := site.get_node("Triggers/Trigger_WagonCover") as Area3D
	assert_not_null(cover_trigger)
	if cover_trigger == null:
		return

	# Точка перед восточным краем повозки: внутри зоны укрытия, но не в коллизии телеги.
	var approach := Vector3(-5.8, 1.1, -3.5)
	assert_eq(_capsule_hits(approach), 0, "к укрытию можно подойти, не застряв в повозке")


func test_monster_does_not_start_in_attack_range() -> void:
	var king := site.get_node("MountainKing") as MountainKing
	var start_trigger := site.get_node("Triggers/Trigger_AmbushStart") as Area3D
	assert_not_null(king)
	assert_not_null(start_trigger)
	if king == null or start_trigger == null:
		return

	var distance := king.global_position.distance_to(start_trigger.global_position)
	assert_gt(distance, 15.0, "при первом обнаружении монстр не достаёт игрока")
	assert_gt(distance, king.config.attack_distance + 5.0)
