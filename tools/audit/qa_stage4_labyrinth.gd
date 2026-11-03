extends Node3D
## Stage 4 QA: continuous Forgotten Shore labyrinth playthrough.
## Exercises the seven base quests, SQ-01..SQ-05 availability, all present
## combat encounters, item grants, objective transitions, checkpoint death,
## and records AC/softlock conditions. It drives the real scene nodes.
##   godot --path . res://tools/audit/qa_stage4_labyrinth.tscn -- --out=<dir>

const LABYRINTH := "res://scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn"

var _out := ""
var _fails := 0
var _passes := 0
var _scene: Node
var _player: SunnyController


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		push_error("qa_stage4_labyrinth: need --out=<dir>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().root.size = Vector2i(1600, 900)
	await get_tree().process_frame
	await _run()
	print("QA_STAGE4_LAB_RESULT pass=", _passes, " fail=", _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _run() -> void:
	NightmareRunState.reset()
	QuestSystem.deactivate_scope()
	# No normal entry sets demo_mode_full (see Stage 4 finding). Force it here to
	# exercise the Z11-Z18 tech demo; the normal M1 end is tested separately.
	NightmareRunState.set_flag(&"demo_mode_full")
	print("QA_STAGE4_LAB_FORCED demo_mode_full=true (no menu/entry setter exists)")
	_check(await _spawn(), "labyrinth scene boot")
	if _scene == null:
		return
	var final_zone := _scene.get_node_or_null(^"Gameplay/Triggers/FinalZone")
	if final_zone != null:
		final_zone.set(&"_fired", true)
		print("QA_STAGE4_LAB_FORCED FinalZone suppression for Z18 traversal")
	await _base_route()
	await _side_quest_01()
	await _side_quest_02()
	await _side_quest_03()
	await _side_quest_04()
	await _side_quest_05()
	await _tide()
	await _checkpoint_death()
	await _reentry()
	await _camera_report()


# ---------------------------------------------------------------------------
# Boot + base route
# ---------------------------------------------------------------------------

func _spawn() -> bool:
	var packed := load(LABYRINTH) as PackedScene
	if packed == null:
		_fail("cannot load labyrinth")
		return false
	_scene = packed.instantiate()
	add_child(_scene)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player = get_tree().get_first_node_in_group(&"player") as SunnyController
	_check(_player != null, "player exists")
	_check(QuestSystem.is_scope_active(), "quest scope active")
	_check(QuestSystem.is_active(&"first_day"), "first_day auto-started")
	_check(QuestSystem.is_active(&"crystal_cache"), "crystal_cache auto-started")
	var runtime := _scene.get_node_or_null(^"Gameplay/Runtime")
	_check(runtime != null, "runtime layer built")
	if runtime != null:
		_check(runtime.get_node_or_null(^"WoundedScavenger") != null, "E01 wounded scavenger spawned")
		_check(runtime.get_node_or_null(^"PackCarapace1") != null, "E02 pack spawned")
		_check(runtime.get_node_or_null(^"BridgeCarapace1") != null, "E03 bridge pair spawned")
	_check(_scene.get_node_or_null(^"Gameplay/RuntimeNarrative") != null, "SQ runtime layer built")
	await _capture("L00_start")
	return true


func _base_route() -> void:
	print("QA_STAGE4_LAB_OBJECTIVE start: ", QuestSystem.get_tracked_objective_text())

	# E01: let the wounded scavenger actually notice and hit the player once.
	await _enter("Gameplay/Runtime/Trigger_first_fork")
	_check(_flag(&"shore_fork_reached"), "base: first fork reached")
	_check(QuestSystem.is_active(&"first_blood"), "base: first_blood auto-started")
	var scavenger := _scene.get_node_or_null(^"Gameplay/Runtime/WoundedScavenger") as CarapaceEnemy
	_check(scavenger != null, "E01 enemy present")
	if scavenger != null:
		_player.global_position = scavenger.global_position + Vector3(0, 0.1, 2.4)
		await _wait(1.4)
		_check(scavenger.state != CarapaceEnemy.State.IDLE, "E01 enemy aggros")
		_check(_player.health.current_health < _player.health.max_health, "E01 enemy damages player")
		await _capture("L01_E01_combat")
		_kill(scavenger)
		await _wait(0.2)
	_check(_flag(&"wounded_scavenger_slain"), "E01 kill credit")
	_check(QuestSystem.is_completed(&"first_blood"), "base: first_blood complete")
	_check(QuestSystem.is_active(&"azure_blade"), "base: azure_blade auto-started")

	# Azure blade.
	var blade := _scene.get_node_or_null(^"Gameplay/Runtime/Pickup_AzureBladePickup") as QuestPickup
	_check(blade != null and blade.enabled, "base: azure blade available")
	if blade != null:
		await _touch(blade)
		blade.interact()
		await _wait(0.1)
	_check(_flag(&"azure_blade_picked"), "base: azure blade picked")
	_check(NightmareRunState.has_memory(&"azure_blade"), "base: azure blade memory granted")
	_check(QuestSystem.is_completed(&"azure_blade"), "base: azure_blade complete")
	await _capture("L02_azure_blade")

	# Three shards.
	for node_name in ["Pickup_SoulShardDryPocket", "Pickup_SoulShardTunnel", "Pickup_SoulShardBridge"]:
		var shard := _scene.get_node_or_null(NodePath("Gameplay/Runtime/" + node_name)) as QuestPickup
		_check(shard != null, "base: %s exists" % node_name)
		if shard != null:
			await _touch(shard)
			shard.interact()
			await _wait(0.1)
	_check(NightmareRunState.get_currency(&"soul_shard") >= 3, "base: three shards collected")
	_check(QuestSystem.is_completed(&"crystal_cache"), "base: crystal_cache complete")
	await _capture("L03_shards")

	# Nephis / clearing.
	await _enter("Gameplay/Runtime/Trigger_clearing")
	_check(_flag(&"shore_clearing_reached"), "base: clearing reached")
	var nephis_npc := _scene.get_node_or_null(^"Gameplay/Runtime/NPC_Nephis") as QuestNpc
	_check(nephis_npc != null, "base: Nephis NPC spawned")
	if nephis_npc != null:
		await _touch(nephis_npc)
		var nephis_interact := nephis_npc.get_node_or_null(^"Interactable") as Interactable
		_check(nephis_interact != null and nephis_interact.enabled, "base: Nephis available")
		if nephis_interact != null:
			nephis_interact.interact()
			await _finish_dialogues()
	_check(_flag(&"nephis_met"), "base: Nephis met")
	await _capture("L04_nephis")

	# Camp + campfire.
	await _enter("Gameplay/Runtime/Trigger_camp")
	_check(_flag(&"shore_camp_reached"), "base: camp reached")
	_check(QuestSystem.is_active(&"camp_rest"), "base: camp_rest auto-started")
	var fire := _scene.get_node_or_null(^"Gameplay/Runtime/CampfireInteractable") as Interactable
	_check(fire != null, "base: campfire exists")
	if fire != null:
		await _touch(fire)
		fire.interact()
		await _wait(0.15)
	_check(_flag(&"camp_rested"), "base: camp rested")
	_check(QuestSystem.is_completed(&"camp_rest"), "base: camp_rest complete")
	_check(QuestSystem.is_completed(&"first_day"), "base: first_day complete")
	_check(NightmareRunState.has_checkpoint(), "base: checkpoint set at camp")
	await _capture("L05_camp")

	# Cassia, gated by Nephis.
	var cassia_npc := _scene.get_node_or_null(^"Gameplay/Runtime/NPC_Cassia") as QuestNpc
	_check(cassia_npc != null, "base: Cassia NPC spawned")
	if cassia_npc != null:
		await _touch(cassia_npc)
		var cassia_interact := cassia_npc.get_node_or_null(^"Interactable") as Interactable
		_check(cassia_interact != null and cassia_interact.enabled, "base: Cassia available after Nephis")
		if cassia_interact != null:
			cassia_interact.interact()
			await _finish_dialogues()
	_check(_flag(&"cassia_met"), "base: Cassia met")

	# E02 pack.
	await _enter("Gameplay/Runtime/Trigger_hunting")
	_check(_flag(&"shore_hunting_reached"), "base: hunting reached")
	_check(QuestSystem.is_active(&"hunt_pack"), "base: hunt_pack auto-started")
	for index in 3:
		var enemy := _scene.get_node_or_null(NodePath("Gameplay/Runtime/PackCarapace%d" % (index + 1))) as CarapaceEnemy
		_check(enemy != null, "E02 pack member %d present" % (index + 1))
		if enemy != null:
			_kill(enemy)
	await _wait(0.3)
	_check(_flag(&"pack_thinned"), "E02 pack kill credit")
	_check(QuestSystem.is_completed(&"hunt_pack"), "base: hunt_pack complete")
	await _capture("L06_E02_pack")

	# E03 bridge pair.
	await _enter("Gameplay/Runtime/Trigger_bridge")
	_check(_flag(&"shore_bridge_reached"), "base: bridge reached")
	_check(QuestSystem.is_active(&"bridge_stand"), "base: bridge_stand auto-started")
	for index in 2:
		var enemy := _scene.get_node_or_null(NodePath("Gameplay/Runtime/BridgeCarapace%d" % (index + 1))) as CarapaceEnemy
		_check(enemy != null, "E03 bridge member %d present" % (index + 1))
		if enemy != null:
			_kill(enemy)
	await _wait(0.3)
	_check(_flag(&"bone_bridge_cleared"), "E03 bridge kill credit")
	_check(QuestSystem.is_completed(&"bridge_stand"), "base: bridge_stand complete")
	await _capture("L07_E03_bridge")

	# Story beats after the bridge.
	await _enter("Gameplay/Runtime/Trigger_refuge")
	_check(_flag(&"shore_refuge_reached"), "base: refuge reached")
	await _enter("Gameplay/Runtime/Trigger_storm")
	_check(_flag(&"shore_storm_reached"), "base: storm reached")
	await _enter("Gameplay/Runtime/Trigger_cliffs")
	_check(_flag(&"shore_cliffs_reached"), "base: cliffs reached")

	var completed := ["first_day", "first_blood", "azure_blade", "crystal_cache", "hunt_pack", "camp_rest", "bridge_stand"]
	for quest_id in completed:
		_check(QuestSystem.is_completed(StringName(quest_id)), "base: %s final state complete" % quest_id)
	print("QA_STAGE4_LAB_OBJECTIVE after base: ", QuestSystem.get_tracked_objective_text())


# ---------------------------------------------------------------------------
# SQ-01
# ---------------------------------------------------------------------------

func _side_quest_01() -> void:
	var token := _scene.get_node_or_null(^"Gameplay/RuntimeNarrative/Narrative_SQ01_Token") as QuestPickup
	_check(token != null, "SQ-01 token exists")
	if token == null:
		return
	_check(token.enabled, "SQ-01 token available")
	await _touch(token)
	token.interact()
	await _wait(0.1)
	_check(_flag(&"sq_fs_01_started"), "SQ-01 started from token")
	_check(QuestSystem.is_active(&"sq_fs_01_ninth_token"), "SQ-01 quest active")

	for trace_name in ["Heel", "Shell", "Blood"]:
		var trace := _scene.get_node_or_null(NodePath("Gameplay/RuntimeNarrative/Narrative_SQ01_Trace_%s" % trace_name)) as QuestInspectable
		_check(trace != null and trace.enabled, "SQ-01 trace %s available" % trace_name)
		if trace != null:
			await _touch(trace)
			trace.interact()
			await _wait(0.1)
		_check(_flag(StringName("sq_fs_01_trace_%s" % trace_name.to_lower())), "SQ-01 trace %s flag" % trace_name)
	await _capture("L08_SQ01_traces")

	var theo := _scene.get_node_or_null(^"Gameplay/RuntimeNarrative/Narrative_SQ01_Theo") as QuestNpc
	_check(theo != null, "SQ-01 Theo exists")
	if theo != null:
		await _touch(theo)
		var interact := theo.get_node_or_null(^"Interactable") as Interactable
		_check(interact != null and interact.enabled, "SQ-01 Theo available")
		if interact != null:
			interact.interact()
			await _wait(0.25)
			await _finish_dialogues()
			await _wait(0.25)
	_check(_flag(&"sq_fs_01_theo_met"), "SQ-01 Theo met")
	_check(QuestSystem.is_completed(&"sq_fs_01_ninth_token"), "SQ-01 complete")
	await _capture("L09_SQ01_done")


# ---------------------------------------------------------------------------
# SQ-02
# ---------------------------------------------------------------------------

func _side_quest_02() -> void:
	await _wait(0.3)
	var tunnel_zone := _scene.get_node_or_null(^"Gameplay/RuntimeNarrative/Narrative_SQ02_Tunnel") as TriggerZone
	_check(tunnel_zone != null and tunnel_zone.enabled, "SQ-02 tunnel unlocked by SQ-01")
	await _enter("Gameplay/RuntimeNarrative/Narrative_SQ02_Tunnel")
	_check(_flag(&"sq_fs_02_voice_heard"), "SQ-02 tunnel trigger")
	_check(QuestSystem.is_active(&"sq_fs_02_echo_tunnel"), "SQ-02 active")

	for echo_name in ["A", "B", "C"]:
		var echo := _scene.get_node_or_null(NodePath("Gameplay/RuntimeNarrative/Narrative_SQ02_Echo%s" % echo_name)) as QuestInspectable
		_check(echo != null and echo.enabled, "SQ-02 echo %s available" % echo_name)
		if echo != null:
			await _touch(echo)
			echo.interact()
			await _wait(0.1)
		_check(_flag(StringName("sq_fs_02_echo_%s" % echo_name.to_lower())), "SQ-02 echo %s flag" % echo_name)
	_check(_flag(&"sq_fs_02_polyp_found"), "SQ-02 all echoes -> polyp found")
	await _capture("L10_SQ02_echoes")

	var polyp := _scene.get_node_or_null(^"Gameplay/RuntimeNarrative/SQ02_EchoPolyp") as CarapaceEnemy
	_check(polyp != null, "SQ-02 EchoPolyp spawned")
	if polyp != null:
		await _touch(polyp)
		_kill(polyp)
		await _wait(0.4)
	_check(_flag(&"sq_fs_02_polyp_dead"), "SQ-02 polyp killed")
	_check(
		QuestSystem.get_objective_progress(&"sq_fs_02_echo_tunnel", &"destroy_polyp") == 1,
		"SQ-02 destroy_polyp credited"
	)
	var cloak := _scene.get_node_or_null(^"Gameplay/RuntimeNarrative/Narrative_SQ02_Cloak") as QuestPickup
	var core := _scene.get_node_or_null(^"Gameplay/RuntimeNarrative/Narrative_SQ02_EchoCore") as QuestPickup
	_check(cloak != null and cloak.enabled, "SQ-02 cloak unlocked by polyp death")
	_check(core != null and core.enabled, "SQ-02 core unlocked by polyp death")
	if cloak != null:
		await _touch(cloak)
		cloak.interact()
		await _wait(0.1)
	if core != null:
		await _touch(core)
		core.interact()
		await _wait(0.1)
	_check(_flag(&"sq_fs_02_cloak_taken"), "SQ-02 cloak taken")
	_check(_flag(&"sq_fs_02_echo_core_taken"), "SQ-02 core taken")
	_check(QuestSystem.is_completed(&"sq_fs_02_echo_tunnel"), "SQ-02 complete")
	_check(_flag(&"sq_fs_02_complete"), "SQ-02 completion flag set")
	await _capture("L11_SQ02_complete")


# ---------------------------------------------------------------------------
# SQ-03
# ---------------------------------------------------------------------------

func _side_quest_03() -> void:
	var theo_return := _scene.get_node_or_null(^"Gameplay/RuntimeNarrative/Narrative_SQ03_TheoReturn") as QuestNpc
	_check(theo_return != null, "SQ-03 Theo return node exists")
	if theo_return == null:
		return
	var interact := theo_return.get_node_or_null(^"Interactable") as Interactable
	_check(interact != null and interact.enabled, "SQ-03 Theo return unlocked by SQ-02")
	if interact != null and interact.enabled:
		await _touch(theo_return)
		interact.interact()
		await _wait(0.25)
		await _finish_dialogues()
		await _wait(0.35)
		_check(_flag(&"sq_fs_03_returned"), "SQ-03 Theo return talked")
	var controller := _scene.get_node_or_null(
		^"Gameplay/NarrativeQuestDirector/QuestChoiceController"
	) as QuestChoiceController
	_check(controller != null and controller.is_active(), "SQ-03 choice panel active")
	await _capture("L12a_SQ03_choice")
	if controller != null and controller.is_active():
		_check(controller.select(&"truth"), "SQ-03 truth choice accepted")
		await _wait(0.3)
	_check(_flag(&"sq_fs_03_choice_truth"), "SQ-03 truth flag")
	_check(_flag(&"sq_fs_03_resolved"), "SQ-03 resolved flag")
	_check(QuestSystem.is_completed(&"sq_fs_03_truth_without_lies"), "SQ-03 complete")
	var cord := _scene.get_node_or_null(^"Gameplay/RuntimeNarrative/Narrative_SQ03_Cord") as QuestPickup
	var cache := _scene.get_node_or_null(^"Gameplay/RuntimeNarrative/Narrative_SQ03_Cache") as QuestPickup
	_check(cord != null and cord.enabled, "SQ-03 cord available after truth")
	_check(cache != null and cache.enabled, "SQ-03 cache available after truth")
	if cord != null:
		await _touch(cord)
		cord.interact()
		await _wait(0.1)
	if cache != null:
		await _touch(cache)
		cache.interact()
		await _wait(0.1)
	_check(_flag(&"sq_fs_03_cord_taken"), "SQ-03 cord taken")
	_check(_flag(&"sq_fs_03_cache_open"), "SQ-03 cache opened")
	await _capture("L12_SQ03_complete")


# ---------------------------------------------------------------------------
# SQ-04
# ---------------------------------------------------------------------------

func _side_quest_04() -> void:
	var markers := _scene.get_node_or_null(^"Gameplay/Quests")
	_check(markers != null and markers.get_node_or_null(^"SQ_FS_04") != null, "SQ-04 markers exist")
	var tide := _scene.get_node_or_null(^"Tide/TideController")
	_check(tide != null, "tide controller exists")
	_check(tide != null and tide.has_method(&"advance_to_low"), "SQ-04 tide API advance_to_low exists")
	_check(tide != null and tide.has_method(&"advance_to_high"), "SQ-04 tide API advance_to_high exists")
	await _enter("Gameplay/RuntimeNarrative/Narrative_SQ04_Ledge")
	_check(_flag(&"sq_fs_04_started"), "SQ-04 started at ledge")
	_check(QuestSystem.is_active(&"sq_fs_04_salt_box"), "SQ-04 active")
	if tide != null:
		tide.call(&"advance_to_low")
		await _wait(0.3)
	_check(_flag(&"sq_fs_04_low_tide"), "SQ-04 low tide flag")

	for lever_name in ["A", "B", "C"]:
		var lever := _scene.get_node_or_null(
			NodePath("Gameplay/RuntimeNarrative/SQ04_Lever%s" % lever_name)
		)
		_check(lever != null and bool(lever.get(&"enabled")), "SQ-04 lever %s available" % lever_name)
		if lever is Node3D:
			await _touch(lever as Node3D)
			lever.call(&"interact")
			await _wait(0.1)
	_check(_flag(&"sq_fs_04_levers_correct"), "SQ-04 levers [LOW,HIGH,LOW]")
	var shards_before := NightmareRunState.get_currency(&"soul_shard")
	var box := _scene.get_node_or_null(^"Gameplay/RuntimeNarrative/Narrative_SQ04_Box") as QuestInspectable
	_check(box != null and box.enabled, "SQ-04 salt box available")
	if box != null:
		await _touch(box)
		box.interact()
		await _wait(0.3)
	_check(_flag(&"sq_fs_04_box_open"), "SQ-04 box open")
	_check(QuestSystem.is_completed(&"sq_fs_04_salt_box"), "SQ-04 complete")
	_check(
		NightmareRunState.get_currency(&"soul_shard") == shards_before + 2,
		"SQ-04 reward +2 soul shards"
	)
	var chart := _scene.get_node_or_null(^"Gameplay/RuntimeNarrative/Narrative_SQ04_Chart") as QuestInspectable
	_check(chart != null and chart.enabled, "SQ-04 chart available after box")
	if chart != null:
		await _touch(chart)
		chart.interact()
		await _wait(0.1)
	_check(_flag(&"sq_fs_04_chart"), "SQ-04 chart read")
	await _capture("L13_SQ04_complete")


# ---------------------------------------------------------------------------
# SQ-05
# ---------------------------------------------------------------------------

func _side_quest_05() -> void:
	await _enter("Gameplay/RuntimeNarrative/Narrative_SQ05_Bridge")
	_check(_flag(&"sq_fs_05_started"), "SQ-05 started at bridge")
	_check(QuestSystem.is_active(&"sq_fs_05_bone_bridge_master"), "SQ-05 active")
	await _enter("Gameplay/RuntimeNarrative/Narrative_SQ05_Trail")
	var trail := _scene.get_node_or_null(^"Gameplay/RuntimeNarrative/Narrative_SQ05_TrailMarks") as QuestInspectable
	_check(trail != null and trail.enabled, "SQ-05 trail inspectable available")
	if trail != null:
		await _touch(trail)
		trail.interact()
		await _wait(0.1)
	_check(_flag(&"sq_fs_05_trail_found"), "SQ-05 trail flag")
	var lair := _scene.get_node_or_null(^"Gameplay/RuntimeNarrative/Narrative_SQ05_Lair") as QuestInspectable
	_check(lair != null and lair.enabled, "SQ-05 lair inspectable available")
	if lair != null:
		await _touch(lair)
		lair.interact()
		await _wait(0.1)
	_check(_flag(&"sq_fs_05_lair_found"), "SQ-05 lair flag")

	var chum := _scene.get_node_or_null(^"Gameplay/RuntimeNarrative/Narrative_SQ05_Chum") as QuestPickup
	_check(chum != null and chum.enabled, "SQ-05 chum available")
	if chum != null:
		await _touch(chum)
		chum.interact()
		await _wait(0.1)
	_check(_flag(&"sq_fs_05_chum_taken"), "SQ-05 chum taken")
	var bait := _scene.get_node_or_null(^"Gameplay/RuntimeNarrative/Narrative_SQ05_BaitDrop") as QuestPickup
	_check(bait != null and bait.enabled, "SQ-05 bait available")
	if bait != null:
		await _touch(bait)
		bait.interact()
		await _wait(0.1)
	_check(_flag(&"sq_fs_05_lured"), "SQ-05 bait dropped")

	var alpha := _scene.get_node_or_null(^"Gameplay/RuntimeNarrative/SQ05_OldShell") as CarapaceEnemy
	_check(alpha != null, "SQ-05 Old Shell spawned")
	if alpha != null:
		await _touch(alpha)
		_kill(alpha)
		await _wait(0.5)
	_check(_flag(&"sq_fs_05_alpha_dead"), "SQ-05 alpha killed")
	_check(_flag(&"sq_fs_05_resolved"), "SQ-05 resolved by alpha kill")
	var shards_before := NightmareRunState.get_currency(&"soul_shard")
	var reward := _scene.get_node_or_null(^"Gameplay/RuntimeNarrative/Narrative_SQ05_Reward") as QuestPickup
	_check(reward != null and reward.enabled, "SQ-05 alpha reward available")
	if reward != null:
		await _touch(reward)
		reward.interact()
		await _wait(0.2)
	_check(_flag(&"sq_fs_05_reward_taken"), "SQ-05 reward taken")
	_check(NightmareRunState.has_item(&"sq_fs_05_shell_cutter"), "SQ-05 shell cutter granted")
	_check(
		NightmareRunState.get_currency(&"soul_shard") == shards_before + 2,
		"SQ-05 reward +2 soul shards"
	)
	_check(QuestSystem.is_completed(&"sq_fs_05_bone_bridge_master"), "SQ-05 complete")
	await _capture("L14_SQ05_complete")


# ---------------------------------------------------------------------------
# Tide
# ---------------------------------------------------------------------------

func _tide() -> void:
	var tide := _scene.get_node_or_null(^"Tide/TideController")
	if tide == null:
		return
	tide.set_phase(0.0)
	await _wait(0.1)
	_check(not tide.is_high_water(), "tide: low water at phase 0")
	var low_gate := _scene.get_node_or_null(^"Generated/GeneratedCollision/Z04/Z04_LowEntrance/TideGate_Z04_LowEntrance") as StaticBody3D
	if low_gate == null:
		# Generated path may be ArtFinal-owned; search by group instead.
		var gates := get_tree().get_nodes_in_group(&"tide_gate")
		_check(gates.size() >= 8, "tide: eight tide gates registered")
		if not gates.is_empty():
			var shape := gates[0].get_child(0) as CollisionShape3D
			_check(shape != null and shape.disabled, "tide: low water opens gates")
	else:
		var shape := low_gate.get_child(0) as CollisionShape3D
		_check(shape != null and shape.disabled, "tide: low water opens gates")
	tide.set_phase(0.5)
	await _wait(0.1)
	_check(tide.is_high_water(), "tide: high water at phase 0.5")
	var gates := get_tree().get_nodes_in_group(&"tide_gate")
	if not gates.is_empty():
		var shape := gates[0].get_child(0) as CollisionShape3D
		_check(shape != null and not shape.disabled, "tide: high water closes gates")
	tide.set_phase(0.0)
	await _wait(0.1)
	await _capture("L16_tide")


# ---------------------------------------------------------------------------
# Checkpoint / death
# ---------------------------------------------------------------------------

func _checkpoint_death() -> void:
	_check(NightmareRunState.has_checkpoint(), "checkpoint before death test")
	var before := _player.global_position
	var checkpoint := NightmareRunState.get_checkpoint_position()
	_player.health.take_damage(99999.0)
	await _wait(1.2)
	_check(not _player.health.is_dead(), "player recovered after death")
	var distance := _player.global_position.distance_to(checkpoint)
	_check(distance < 8.0, "player respawned near checkpoint (%.1f m)" % distance)
	_check(_player.global_position != before or distance < 1.0, "death did not softlock position")
	await _capture("L17_respawn")


# ---------------------------------------------------------------------------
# Re-entry
# ---------------------------------------------------------------------------

func _reentry() -> void:
	var before_items := NightmareRunState.get_currency(&"soul_shard")
	var before_quests := QuestSystem.get_completed_quests().size()
	var packed := load(LABYRINTH) as PackedScene
	var second := packed.instantiate()
	add_child(second)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var runtime := second.get_node_or_null(^"Gameplay/Runtime")
	_check(runtime != null, "re-entry: runtime rebuilt")
	if runtime != null:
		_check(runtime.get_node_or_null(^"WoundedScavenger") == null, "re-entry: dead E01 not respawned")
		_check(runtime.get_node_or_null(^"Pickup_AzureBladePickup") == null or not runtime.get_node_or_null(^"Pickup_AzureBladePickup").enabled, "re-entry: azure blade not re-granted")
	_check(NightmareRunState.get_currency(&"soul_shard") == before_items, "re-entry: currency preserved")
	_check(QuestSystem.get_completed_quests().size() == before_quests, "re-entry: quest states preserved")
	var narrative := second.get_node_or_null(^"Gameplay/RuntimeNarrative")
	_check(narrative != null, "re-entry: SQ runtime rebuilt")
	if narrative != null:
		var token := narrative.get_node_or_null(^"Narrative_SQ01_Token")
		_check(token == null or not token.enabled, "re-entry: SQ-01 token not repeatable")
	await _capture("L18_reentry")
	second.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# Camera / screenshot sanity
# ---------------------------------------------------------------------------

func _camera_report() -> void:
	var cams := _scene.find_children("*", "Camera3D", true, false)
	_check(not cams.is_empty(), "scene has cameras")
	print("QA_STAGE4_LAB_CAMERAS ", cams.size())


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

func _enter(path: String) -> void:
	var zone := _scene.get_node_or_null(NodePath(path)) as Area3D
	if zone == null:
		_fail("missing zone " + path)
		return
	_player.global_position = zone.global_position + Vector3(0, 0.2, 0)
	_player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _wait(0.05)
	# CampNight and other story triggers may open a dialogue on entry. Drain it
	# so the next quest interaction cannot re-enter the same DialogueRunner.
	await _finish_dialogues()


func _touch(node: Node3D) -> void:
	_player.global_position = node.global_position + Vector3(0, 0.1, 1.2)
	_player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await _wait(0.03)


func _kill(enemy: CarapaceEnemy) -> void:
	if enemy == null:
		return
	enemy.health.take_damage(99999.0)


func _finish_dialogues() -> void:
	var runners := get_tree().get_nodes_in_group(&"dialogue_runner")
	if runners.is_empty():
		await _wait(0.1)
		return
	# Let QuestNpc/QuestPickup coroutines reach runner.run() first.
	await _wait(0.1)
	for _i in 600:
		var any_running := false
		for runner in runners:
			if runner.get(&"running") == true:
				any_running = true
				runner.call(&"advance")
		await get_tree().process_frame
		if not any_running and _i > 12:
			break
	# Let the awaited coroutine write its completion flag.
	await _wait(0.25)


func _capture(name: String) -> void:
	_ensure_camera()
	await _wait(0.12)
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	var error := image.save_png(path)
	if error != OK:
		_fail("capture %s error %d" % [name, error])
	else:
		print("QA_STAGE4_LAB_CAPTURE ", path)


func _ensure_camera() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var rig := _player.get_node_or_null(^"CameraRig") as Node3D
	var cam := rig.get_node_or_null(^"Camera") as Camera3D if rig != null else null
	if cam == null and rig != null:
		for child in rig.get_children():
			if child is Camera3D:
				cam = child as Camera3D
				break
	if cam != null:
		cam.make_current()
		return
	for node in _scene.find_children("*", "Camera3D", true, false):
		(node as Camera3D).make_current()
		return


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _flag(name: StringName) -> bool:
	return NightmareRunState.has_flag(name)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("QA_STAGE4_LAB_PASS ", label)
	else:
		_fail("check failed: " + label)


func _fail(message: String) -> void:
	_fails += 1
	print("QA_STAGE4_LAB_FAIL ", message)
