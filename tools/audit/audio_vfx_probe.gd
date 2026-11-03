extends SceneTree
## Read-only probe for the Labyrinth demo audio/VFX layer.
## Ignores the unrelated player animation warnings produced by the POC model.
## Run:
##   godot --headless --path . -s tools/audit/audio_vfx_probe.gd

const SCENE := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE) as PackedScene
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	for i in 8:
		await process_frame

	var atmosphere := scene.get_node_or_null(^"LabyrinthAtmosphere") as LabyrinthAtmosphere
	print("scene=", SCENE)
	print("atmosphere=", atmosphere != null)
	if atmosphere != null:
		for node_name in ["CampFireVfx", "CampSmokeVfx", "CampfireLoop", "StormRainVfx", "StormLightning"]:
			print("atmosphere/", node_name, "=", atmosphere.get_node_or_null(NodePath(node_name)) != null)

	var water := scene.get_node_or_null(^"Tide/WaterPlane") as MeshInstance3D
	if water != null and water.material_override is ShaderMaterial:
		var material := water.material_override as ShaderMaterial
		print("water_shader=", material.shader.resource_path if material.shader != null else "null")
		print("water_foam=", material.get_shader_parameter("foam_strength"))

	var particle_count := 0
	var particle_amount := 0
	for node in scene.find_children("*", "GPUParticles3D", true, false):
		var particles := node as GPUParticles3D
		particle_count += 1
		particle_amount += particles.amount
	print("particles=", particle_count, " amount=", particle_amount)

	var audio := AudioLibrary.sfx_cues()
	for cue in [&"creature_carapace_chitter", &"creature_carapace_death", &"world_tide_warning", &"world_echo_whisper", &"world_soul_shard"]:
		print("cue/", cue, "=", audio.has(cue))
	print("music/labyrinth_storm=", AudioLibrary.music_cues().has(&"labyrinth_storm"))
	var zones := AudioLibrary.ambience_zones()
	print("ambience/z17_bed=", zones.has(&"labyrinth_z17") and zones[&"labyrinth_z17"]["bed"] != null)
	print("ambience/z10_campfire_2d=", zones.has(&"labyrinth_z10") and zones[&"labyrinth_z10"]["mid"] != null and String(zones[&"labyrinth_z10"]["mid"].resource_path).contains("campfire"))

	var pickups := get_nodes_in_group(&"quest_pickup")
	if not pickups.is_empty():
		var first_pickup := pickups[0] as Interactable
		print("pickup_count=", pickups.size(), " first_cue=", first_pickup.interact_cue)
	var npcs := get_nodes_in_group(&"quest_npc")
	if not npcs.is_empty():
		var first_npc := npcs[0]
		var talk := first_npc.get_node_or_null(^"Interactable") as Interactable
		print("npc_count=", npcs.size(), " talk_cue=", talk.interact_cue if talk != null else "null")
	var campfire := scene.get_node_or_null(^"Gameplay/Runtime/CampfireInteractable") as Interactable
	print("campfire_cue=", campfire.interact_cue if campfire != null else "null")
	print("enemy_count=", get_nodes_in_group(&"enemy").size())

	if atmosphere != null:
		atmosphere.call(&"_set_storm", true)
		var rain := atmosphere.get_node_or_null(^"StormRainVfx/Rain") as GPUParticles3D
		print("storm_emitting=", rain != null and rain.emitting)
		atmosphere.call(&"_flash_lightning")
		await create_timer(0.12).timeout
		var lightning := atmosphere.get_node_or_null(^"StormLightning") as DirectionalLight3D
		print("lightning_energy=", lightning.light_energy if lightning != null else -1.0)
		for zone_id in [&"labyrinth_z01", &"labyrinth_z10", &"labyrinth_z14", &"labyrinth_z17", &"labyrinth_z18"]:
			atmosphere.call(&"_enter_zone", zone_id)
		await process_frame
		print("event_smoke=ok")

	# A soul shard must use its own cue, not the generic world pickup click.
	for pickup_node in pickups:
		var pickup := pickup_node as Interactable
		if pickup != null and pickup.enabled and pickup.interact_cue == &"world_soul_shard":
			pickup.call(&"interact")
			await process_frame
			print("pickup_interacted=", not (pickup as Node3D).visible)
			break

	# Death VFX and cue are driven by the same HealthComponent.died signal.
	var enemies := get_nodes_in_group(&"enemy")
	if not enemies.is_empty():
		var enemy := enemies[0] as CarapaceEnemy
		enemy.health.take_damage(99999.0)
		await process_frame
		print("enemy_dead=", enemy.state == CarapaceEnemy.State.DEAD)
		print("death_vfx=", root.find_children("DeathCarapace", "", true, false).size() > 0)

	await process_frame
	quit(0)
