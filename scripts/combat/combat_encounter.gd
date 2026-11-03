class_name CombatEncounter
extends Node3D
## One hand-placed combat encounter: a group of enemies, an activation radius and
## a clear condition. The encounter does not own AI or damage: it only wakes the
## enemies, gives them the player as a target and reports when the group is dead.
##
## Enemies are gathered from children in the "enemy" group. A dormant encounter
## keeps their bodies non-blocking and their AI off until the player comes close,
## so a hand-placed patrol cannot accidentally block a route or aggro through a
## wall before the scene starts.

signal started
signal enemy_defeated(remaining: int)
signal cleared

@export var encounter_id: StringName = &""
@export var display_name := ""
## 0 — активировать сразу в _ready; иначе ждать игрока в этом радиусе.
@export var activation_radius := 9.0
## Не давать врагам ходить/блокировать проход до активации.
@export var dormant_until_activated := true
## Если игрок ушёл дальше этого радиуса, вернуть группу на исходные точки.
@export var leash_radius := 26.0
## Явная цель; если пусто — первый узел группы "player".
@export var target: Node3D

var _enemies: Array[Node] = []
var _health: Dictionary = {}
var _spawn_transforms: Dictionary = {}
var _dormant_state: Dictionary = {}
var _active := false
var _cleared := false
var _player: Node3D
var _scan_timer := 0.0


func _ready() -> void:
	add_to_group(&"combat_encounter")
	call_deferred(&"_setup")


func _setup() -> void:
	_player = target if target != null else get_tree().get_first_node_in_group(&"player") as Node3D
	_collect_enemies()
	if dormant_until_activated:
		for enemy in _enemies:
			_set_enemy_dormant(enemy, true)
	if activation_radius <= 0.0 and not _enemies.is_empty():
		activate()


func _collect_enemies() -> void:
	_enemies.clear()
	_health.clear()
	for node in find_children("*", "", true, false):
		if not node.is_in_group(&"enemy"):
			continue
		var component := node.get(&"health") as HealthComponent
		if component == null:
			continue
		_enemies.append(node)
		_health[node] = component
		_spawn_transforms[node] = node.global_transform
		component.died.connect(_on_enemy_died.bind(node))
	if _enemies.is_empty() and not encounter_id.is_empty():
		push_warning("CombatEncounter %s: no enemies in group 'enemy'" % encounter_id)


func _physics_process(delta: float) -> void:
	if _cleared:
		return
	if _player == null or not is_instance_valid(_player):
		_scan_timer -= delta
		if _scan_timer <= 0.0:
			_scan_timer = 0.5
			_player = get_tree().get_first_node_in_group(&"player") as Node3D
		if _player == null:
			return
	if not _active:
		if activation_radius <= 0.0 or _player.global_position.distance_to(global_position) <= activation_radius:
			activate()
		return
	if leash_radius > 0.0 and _player.global_position.distance_to(global_position) > leash_radius:
		_reset_to_spawn()
		_active = false


## Разбудить группу и выдать ей цель. Повторный вызов безопасен.
func activate() -> bool:
	if _cleared or _active or _enemies.is_empty():
		return false
	_active = true
	for enemy in _enemies:
		_set_enemy_dormant(enemy, false)
		if enemy.has_method(&"alert_to"):
			enemy.call(&"alert_to", _player)
		elif enemy.has_method(&"activate"):
			enemy.call(&"activate")
		elif enemy.has_method(&"set_target"):
			enemy.call(&"set_target", _player)
	started.emit()
	return true


func is_active() -> bool:
	return _active


func is_cleared() -> bool:
	return _cleared


func remaining() -> int:
	var count := 0
	for enemy in _enemies:
		var component := _health.get(enemy) as HealthComponent
		if component != null and not component.is_dead():
			count += 1
	return count


func enemy_count() -> int:
	return _enemies.size()


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	return String(encounter_id) if not encounter_id.is_empty() else String(name)


func _on_enemy_died(enemy: Node) -> void:
	if _cleared:
		return
	var left := remaining()
	enemy_defeated.emit(left)
	if left <= 0:
		_cleared = true
		_active = false
		cleared.emit()


func _reset_to_spawn() -> void:
	for enemy in _enemies:
		var component := _health.get(enemy) as HealthComponent
		if component != null and component.is_dead():
			continue
		var saved: Transform3D = _spawn_transforms.get(enemy, Transform3D.IDENTITY)
		(enemy as Node3D).global_transform = saved
		if enemy.has_method(&"alert_to"):
			continue  # AI сам выйдет из боя по lose_range
	_set_dormant_all(true)


func _set_dormant_all(value: bool) -> void:
	for enemy in _enemies:
		_set_enemy_dormant(enemy, value)


func _set_enemy_dormant(enemy: Node, value: bool) -> void:
	if enemy.has_method(&"set_dormant"):
		enemy.call(&"set_dormant", value)
		return
	var body := enemy as CollisionObject3D
	if body == null:
		enemy.set_physics_process(not value)
		return
	if value:
		if not _dormant_state.has(enemy):
			_dormant_state[enemy] = {
				"layer": body.collision_layer,
				"mask": body.collision_mask,
			}
		body.collision_layer = 0
		body.collision_mask = 0
		var enemy_attack := enemy.get(&"attack") as MeleeAttack
		if enemy_attack != null:
			enemy_attack.disable()
			enemy_attack.enabled = false
		var telegraph := enemy.get(&"telegraph_visual") as Node3D
		if telegraph != null:
			telegraph.visible = false
		enemy.set_physics_process(false)
	else:
		var saved: Dictionary = _dormant_state.get(enemy, {})
		if not saved.is_empty():
			body.collision_layer = int(saved.get("layer", 4))
			body.collision_mask = int(saved.get("mask", 3))
		var enemy_attack := enemy.get(&"attack") as MeleeAttack
		if enemy_attack != null:
			enemy_attack.enabled = true
		enemy.set_physics_process(true)
