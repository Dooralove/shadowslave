extends GutTest
## Focused checks for the demo-fragment audio/VFX layer.

const VFX_PATHS := [
	"res://scenes/environment/vfx/impact_ichor.tscn",
	"res://scenes/environment/vfx/impact_dust.tscn",
	"res://scenes/environment/vfx/death_carapace.tscn",
	"res://scenes/environment/vfx/tide_spray.tscn",
	"res://scenes/environment/vfx/storm_rain.tscn",
	"res://scenes/environment/vfx/azure_motes.tscn",
]


class FakeVoice:
	extends Node
	var playing := true


func test_demo_cues_are_merged() -> void:
	var music := AudioLibrary.music_cues()
	var sfx := AudioLibrary.sfx_cues()
	assert_true(music.has(&"labyrinth_storm"), "storm music cue is merged")
	assert_true(sfx.has(&"creature_carapace_chitter"), "carapace chitter exists")
	assert_true(sfx.has(&"creature_carapace_death"), "carapace death exists")
	assert_true(sfx.has(&"world_tide_warning"), "tide warning exists")
	assert_true(sfx.has(&"world_echo_whisper"), "echo whisper exists")
	assert_true(sfx.has(&"world_campfire_rest"), "campfire rest cue exists")
	var cue := sfx[&"world_tide_warning"] as SfxCue
	assert_eq(cue.priority, SfxCue.Priority.CRITICAL)
	assert_eq(cue.caption, "Прилив поднимается")
	assert_true(cue.spatial)
	assert_gt(cue.max_distance, 50.0)


func test_zone_overrides_add_campfire_and_storm() -> void:
	var zones := AudioLibrary.ambience_zones()
	assert_true(zones.has(&"labyrinth_z17"))
	var storm: Dictionary = zones[&"labyrinth_z17"]
	assert_not_null(storm["bed"], "storm zone has a bed")
	assert_true(String(storm["bed"].resource_path).contains("storm_rain_loop"), "storm bed is the rain loop")
	var camp: Dictionary = zones[&"labyrinth_z10"]
	assert_not_null(camp["bed"], "camp zone keeps its base bed")
	assert_gt(camp["details"].size(), 0, "camp zone has wind detail")
	# The fire itself is a positional 3D loop in LabyrinthAtmosphere; it must
	# not become a zone-wide 2D wash.
	assert_true(camp["mid"] == null or not String(camp["mid"].resource_path).contains("campfire_loop"))


func test_vfx_scenes_load_and_have_emitters() -> void:
	for path in VFX_PATHS:
		var packed := load(path) as PackedScene
		assert_not_null(packed, "VFX scene loads: %s" % path)
		if packed == null:
			continue
		var inst := packed.instantiate()
		add_child_autofree(inst)
		var emitters := inst.find_children("*", "GPUParticles3D", true, false)
		assert_gt(emitters.size(), 0, "VFX scene has particles: %s" % path)
		for emitter in emitters:
			var particles := emitter as GPUParticles3D
			assert_gt(particles.amount, 0)
			assert_true(particles.amount <= 900, "particle budget per emitter: %s" % path)


func test_atmosphere_builds_without_player() -> void:
	var root := Node3D.new()
	root.name = "AtmosphereTest"
	add_child_autofree(root)
	var gameplay := Node3D.new()
	gameplay.name = "Gameplay"
	root.add_child(gameplay)
	var interactables := Node3D.new()
	interactables.name = "Interactables"
	gameplay.add_child(interactables)
	var campfire := Marker3D.new()
	campfire.name = "Campfire"
	campfire.position = Vector3(-100, 18, -5)
	interactables.add_child(campfire)
	var atmosphere := LabyrinthAtmosphere.new()
	atmosphere.name = "LabyrinthAtmosphere"
	root.add_child(atmosphere)
	await get_tree().process_frame
	assert_not_null(atmosphere.get_node_or_null(^"CampFireVfx"), "campfire particles are instanced")
	assert_not_null(atmosphere.get_node_or_null(^"CampSmokeVfx"), "camp smoke is instanced")
	assert_not_null(atmosphere.get_node_or_null(^"CampfireLoop"), "campfire loop player exists")
	assert_not_null(atmosphere.get_node_or_null(^"StormRainVfx"), "storm rain node exists")
	assert_not_null(atmosphere.get_node_or_null(^"StormLightning"), "lightning light exists")


func test_one_shot_vfx_spawns_and_frees() -> void:
	var inst := OneShotVfx.spawn("res://scenes/environment/vfx/impact_dust.tscn", Vector3(1, 2, 3))
	assert_not_null(inst, "one-shot VFX instantiates")
	await wait_seconds(2.2)
	assert_false(is_instance_valid(inst), "one-shot VFX frees itself")


func test_atmosphere_assigns_gameplay_interaction_cues() -> void:
	var root := Node3D.new()
	root.name = "InteractionCueTest"
	add_child_autofree(root)
	var gameplay := Node3D.new()
	gameplay.name = "Gameplay"
	root.add_child(gameplay)
	var runtime := Node3D.new()
	runtime.name = "Runtime"
	gameplay.add_child(runtime)
	var campfire := Interactable.new()
	campfire.name = "CampfireInteractable"
	runtime.add_child(campfire)
	var pickup := Interactable.new()
	pickup.name = "Pickup_Test"
	pickup.add_to_group(&"quest_pickup")
	root.add_child(pickup)
	var npc := Node3D.new()
	npc.name = "NPC_Test"
	npc.add_to_group(&"quest_npc")
	var talk := Interactable.new()
	talk.name = "Interactable"
	npc.add_child(talk)
	root.add_child(npc)
	var atmosphere := LabyrinthAtmosphere.new()
	root.add_child(atmosphere)
	await wait_process_frames(2)
	assert_eq(pickup.interact_cue, &"world_soul_shard", "shard pickup gets its own cue")
	assert_eq(talk.interact_cue, &"ui_confirm", "NPC talk gets a UI confirmation")
	assert_eq(campfire.interact_cue, &"world_campfire_rest", "campfire gets a rest cue")


func test_interactable_defaults_to_world_cue() -> void:
	var interactable := Interactable.new()
	assert_eq(interactable.interact_cue, &"world_pickup")
	assert_true(interactable.interact_volume_db <= -4.0)
	interactable.free()


func test_sfx_pool_steals_the_least_important_voice() -> void:
	var pool := SfxPool.new()
	add_child_autofree(pool)
	var low := FakeVoice.new()
	var high := FakeVoice.new()
	var critical := FakeVoice.new()
	low.set_meta(&"priority", SfxCue.Priority.LOW)
	high.set_meta(&"priority", SfxCue.Priority.HIGH)
	critical.set_meta(&"priority", SfxCue.Priority.CRITICAL)
	for voice in [low, high, critical]:
		voice.set_meta(&"started", 1)
	var voices := [low, high, critical]
	assert_eq(pool._acquire(voices), low, "the oldest low-priority voice is stolen")
	assert_true(pool._can_replace(voices, SfxCue.Priority.LOW), "low may replace an equal low voice")
	assert_true(pool._can_replace(voices, SfxCue.Priority.CRITICAL), "critical may replace low")
	var higher := [high, critical]
	assert_false(pool._can_replace(higher, SfxCue.Priority.LOW), "low may not evict high/critical when full")
	low.free()
	high.free()
	critical.free()
