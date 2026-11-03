extends SceneTree
## Read-only probe for the demo labyrinth combat layer.
## Instantiates the location, waits for LabyrinthQuestDirector, and prints the
## player's combat flag plus every spawned enemy, its health and position.
##
## Usage:
##   godot --headless --path . -s tools/audit/combat_labyrinth_probe.gd

const SCENE := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE) as PackedScene
	if packed == null:
		push_error("combat_labyrinth_probe: cannot load scene")
		quit(2)
		return
	var location := packed.instantiate()
	get_root().add_child(location)
	await process_frame
	await physics_frame
	await process_frame
	await physics_frame

	var player := location.get_node_or_null(^"Player") as SunnyController
	if player == null:
		push_error("combat_labyrinth_probe: no Player")
		quit(2)
		return
	print("PLAYER combat_enabled=", player.combat_enabled,
		" controls=", player.controls_enabled,
		" pos=", player.global_position,
		" attack_damage=", player.attack.stats.damage if player.attack.stats != null else -1)
	var enemies: Array[Node] = get_nodes_in_group(&"enemy")
	print("ENEMIES count=", enemies.size())
	for node in enemies:
		var enemy := node as Node3D
		if enemy == null:
			continue
		var health := enemy.get(&"health") as HealthComponent
		print("  ", enemy.name, " pos=", enemy.global_position,
			" hp=", health.current_health if health != null else -1,
			" script=", enemy.get_script().resource_path if enemy.get_script() != null else "")
	quit(0)
