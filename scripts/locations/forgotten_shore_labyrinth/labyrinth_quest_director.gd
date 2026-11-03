class_name LabyrinthQuestDirector
extends Node3D
## Собирает игровой слой первого фрагмента Лабиринта по авторским маркерам.
##
## Сцена остаётся greybox: сюда вынесены только изменяемые игровые объекты —
## триггеры, чекпоинты, подбираемые предметы, NPC и противники. Задания,
## прогресс и награды живут в QuestSystem/NightmareRunState.

const PICKUP_SCENE := preload("res://scenes/quests/quest_pickup.tscn")
const NPC_SCENE := preload("res://scenes/quests/quest_npc.tscn")
const CARAPACE_SCENE := preload("res://scenes/enemies/carapace_enemy.tscn")
const CARAPACE_LOOT := preload("res://resources/loot/tables/enemy_carapace_scavenger.tres")
const NEPHIS_DIALOGUE := preload("res://resources/dialogue/labyrinth/nephis_meeting.tres")
const CASSIA_DIALOGUE := preload("res://resources/dialogue/labyrinth/cassia_meeting.tres")

@export var quest_scope: StringName = &"forgotten_shore"
@export var enable_gameplay := true
@export var spawn_encounters := true

var _runtime: Node3D
var _gameplay: Node3D


func _ready() -> void:
	call_deferred(&"_build")


func _build() -> void:
	if not enable_gameplay:
		var inactive_quests := get_node_or_null(^"/root/QuestSystem")
		if inactive_quests != null and inactive_quests.has_method(&"deactivate_scope"):
			inactive_quests.call(&"deactivate_scope")
		return
	_gameplay = get_parent() as Node3D
	if _gameplay == null:
		push_error("LabyrinthQuestDirector: родитель должен быть Gameplay")
		return
	_runtime = _gameplay.get_node_or_null(^"Runtime") as Node3D
	if _runtime == null:
		_runtime = Node3D.new()
		_runtime.name = "Runtime"
		_gameplay.add_child(_runtime)

	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests != null and quests.has_method(&"activate_scope"):
		quests.call(&"activate_scope", quest_scope)

	_build_triggers()
	_build_checkpoints()
	_build_interactions()
	_build_npcs()
	if spawn_encounters:
		_build_encounters()


func _exit_tree() -> void:
	# Autoload lookup by absolute path is invalid once this node has left the
	# tree (scene reload / save-load). The singleton is stable across scenes.
	if Engine.get_main_loop() != null:
		QuestSystem.deactivate_scope()


# ---------------------------------------------------------------------------
# Триггеры и чекпоинты
# ---------------------------------------------------------------------------

func _build_triggers() -> void:
	_add_trigger(&"first_fork", &"first_fork", &"shore_fork_reached", 7.0, &"../Triggers/FirstFight")
	_add_trigger(&"clearing", &"clearing", &"shore_clearing_reached", 12.0, &"../Triggers/FirstSighting")
	_add_trigger(&"camp", &"camp", &"shore_camp_reached", 8.0, &"../Triggers/Camp")
	_add_trigger(&"hunting", &"hunting", &"shore_hunting_reached", 18.0, &"../Encounters/PacksZ13")
	_add_trigger(&"bridge", &"bridge", &"shore_bridge_reached", 8.0, &"../Triggers/Bridge")
	_add_trigger(&"refuge", &"refuge", &"shore_refuge_reached", 8.0, &"../Triggers/Refuge")
	_add_trigger(&"storm", &"storm", &"shore_storm_reached", 10.0, &"../Triggers/Storm")
	_add_trigger(&"cliffs", &"cliffs", &"shore_cliffs_reached", 10.0, &"../Triggers/Cliffs")


func _add_trigger(
	node_name: StringName,
	subject_id: StringName,
	flag_name: StringName,
	radius: float,
	marker_path: StringName
) -> void:
	var marker := _marker(marker_path)
	if marker == null:
		return
	var zone := QuestTriggerZone.new()
	zone.name = StringName("Trigger_%s" % node_name)
	zone.trigger_id = node_name
	zone.quest_subject = subject_id
	zone.quest_event = &"reached"
	zone.set_flag = flag_name
	zone.enabled = true
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	zone.add_child(shape)
	_runtime.add_child(zone)
	zone.global_position = marker.global_position + Vector3.UP * 1.4


func _build_checkpoints() -> void:
	_add_checkpoint(&"CP-SHORE-START", _marker(&"../../Spawns/Start"), 3.0)
	_add_checkpoint(&"CP-SHORE-CAMP", _marker(&"../../Markers/CampCheckpoint"), 3.2)
	_add_checkpoint(&"CP-SHORE-REFUGE", _marker(&"../../Markers/RefugeCheckpoint"), 3.2)
	_add_checkpoint(&"CP-SHORE-CLIFF", _marker(&"../../Markers/CliffCheckpoint"), 3.2)


func _add_checkpoint(checkpoint_id: StringName, marker: Node3D, radius: float) -> void:
	if marker == null:
		return
	var zone := CheckpointZone.new()
	zone.name = StringName("Checkpoint_%s" % checkpoint_id)
	zone.checkpoint_id = checkpoint_id
	zone.one_shot = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	zone.add_child(shape)
	_runtime.add_child(zone)
	zone.global_position = marker.global_position + Vector3.UP * 1.0


# ---------------------------------------------------------------------------
# Предметы, костёр, NPC
# ---------------------------------------------------------------------------

func _build_interactions() -> void:
	_add_pickup(
		&"AzureBladePickup", &"azure_blade", "Забрать Азурный клинок",
		"blade", &"", 1, &"", 0, &"", &"azure_blade_picked",
		&"interacted", &"azure_blade",
		"Азурный клинок отзывается на прикосновение и уходит в Море Души.",
		[&"wounded_scavenger_slain"],
		_marker(&"../../Markers/AzureBladePickup")
	)
	_add_shard(&"SoulShardDryPocket", &"soul_shard_dry_pocket", _marker(&"../Interactables/SoulShardDryPocket"))
	_add_shard(&"SoulShardTunnel", &"soul_shard_tunnel", _marker(&"../Interactables/SoulShardTunnel"))
	_add_shard(&"SoulShardBridge", &"soul_shard_bridge", _marker(&"../Interactables/SoulShardBridge"))
	_add_campfire(_marker(&"../Interactables/Campfire"))


func _add_shard(node_name: StringName, pickup_flag: StringName, marker: Node3D) -> void:
	_add_pickup(
		node_name, &"soul_shard_pickup", "Собрать осколок души",
		"shard", &"", 0, &"soul_shard", 1, &"", pickup_flag,
		&"collected", &"soul_shard", "Осколок души +1.", [], marker
	)


func _add_pickup(
	node_name: StringName,
	interaction_id: StringName,
	prompt: String,
	visual_kind: String,
	item_id: StringName,
	item_count: int,
	currency_id: StringName,
	currency_amount: int,
	memory_id: StringName,
	pickup_flag: StringName,
	quest_event: StringName,
	quest_subject: StringName,
	pickup_text: String,
	required_flags: Array[StringName],
	marker: Node3D
) -> void:
	if marker == null:
		return
	var pickup := PICKUP_SCENE.instantiate() as QuestPickup
	if pickup == null:
		return
	pickup.name = StringName("Pickup_%s" % node_name)
	pickup.interaction_id = interaction_id
	pickup.prompt = prompt
	pickup.visual_kind = visual_kind
	pickup.item_id = item_id
	pickup.item_count = maxi(item_count, 1)
	pickup.currency_id = currency_id
	pickup.currency_amount = currency_amount
	pickup.memory_id = memory_id
	pickup.pickup_flag = pickup_flag
	pickup.quest_event = quest_event
	pickup.quest_subject = quest_subject
	pickup.pickup_text = pickup_text
	pickup.required_flags = required_flags
	_runtime.add_child(pickup)
	pickup.global_position = marker.global_position + Vector3.UP * 0.75
	pickup.reset_float_origin()


func _add_campfire(marker: Node3D) -> void:
	if marker == null:
		return
	var interactable := Interactable.new()
	interactable.name = "CampfireInteractable"
	interactable.interaction_id = &"campfire"
	interactable.prompt = "Отдохнуть у костра"
	interactable.radius = 2.6
	interactable.enabled = true
	interactable.interacted.connect(_on_campfire_interacted)
	_runtime.add_child(interactable)
	interactable.global_position = marker.global_position


func _on_campfire_interacted(_id: StringName) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as SunnyController
	if player == null:
		return
	NightmareRunState.set_checkpoint(&"CP-SHORE-CAMP", player.global_position, true)
	var recovery := player.get_node_or_null(^"FallRecovery") as FallRecovery
	if recovery != null:
		recovery.set_named_checkpoint(&"CP-SHORE-CAMP", player.global_position)
	QuestSystem.notify_event(&"interacted", &"campfire", 1)
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests != null and quests.has_method(&"show_message"):
		quests.call(&"show_message", "Костёр трещит. Здесь можно перевести дух.", &"info")


func _build_npcs() -> void:
	_add_npc(
		&"Nephis", &"nephis", "Нефис", NEPHIS_DIALOGUE,
		[&"shore_clearing_reached"], &"nephis_met", &"mass_female", 1.0,
		_marker(&"../Companions/Nephis")
	)
	_add_npc(
		&"Cassia", &"cassia", "Кассия", CASSIA_DIALOGUE,
		[&"nephis_met"], &"cassia_met", &"mass_female", 0.96,
		_marker(&"../Companions/Cassia")
	)


func _add_npc(
	node_name: StringName,
	npc_id: StringName,
	display_name: String,
	dialogue: DialogueSequence,
	required_flags: Array[StringName],
	completion_flag: StringName,
	archetype: String,
	height_scale: float,
	marker: Node3D
) -> void:
	if marker == null:
		return
	var npc := NPC_SCENE.instantiate() as QuestNpc
	if npc == null:
		return
	npc.name = StringName("NPC_%s" % node_name)
	npc.npc_id = npc_id
	npc.display_name = display_name
	npc.dialogue = dialogue
	npc.required_flags = required_flags
	npc.completion_flag = completion_flag
	npc.one_shot = false
	_runtime.add_child(npc)
	npc.global_position = marker.global_position
	npc.rotation.y = marker.global_rotation.y
	var mannequin := npc.get_node_or_null(^"Mannequin")
	if mannequin != null:
		mannequin.set(&"archetype", archetype)
		mannequin.set(&"height_scale", height_scale)


# ---------------------------------------------------------------------------
# Противники
# ---------------------------------------------------------------------------

func _build_encounters() -> void:
	_spawn_enemy(
		&"WoundedScavenger", &"wounded_scavenger", &"wounded_scavenger_slain",
		_marker(&"../Encounters/WoundedScavenger"), 65.0, Vector3.ZERO
	)
	var pack_marker := _marker(&"../Encounters/PacksZ13")
	if pack_marker != null:
		for index in 3:
			var offsets := [
				Vector3(-6, 0, -8),
				Vector3(5, 0, -2),
				Vector3(0, 0, 12),
			]
			_spawn_enemy(
				StringName("PackCarapace%d" % (index + 1)),
				&"carapace",
				StringName("pack_carapace_%d" % (index + 1)),
				pack_marker,
				0.0,
				offsets[index] as Vector3
			)
	var bridge_marker := _marker(&"../Encounters/TwoCarapaces")
	if bridge_marker != null:
		for index in 2:
			_spawn_enemy(
				StringName("BridgeCarapace%d" % (index + 1)),
				&"bridge_carapace",
				StringName("bridge_carapace_%d" % (index + 1)),
				bridge_marker,
				0.0,
				Vector3(-8.0 + float(index) * 16.0, 0, 0)
			)


func _spawn_enemy(
	node_name: StringName,
	enemy_tag: StringName,
	credit_flag: StringName,
	marker: Node3D,
	health_override: float,
	offset: Vector3
) -> void:
	if marker == null or NightmareRunState.has_flag(credit_flag):
		return
	var enemy := CARAPACE_SCENE.instantiate() as CarapaceEnemy
	if enemy == null:
		return
	enemy.name = node_name
	_runtime.add_child(enemy)
	enemy.global_position = marker.global_position + offset
	enemy.rotation.y = marker.global_rotation.y
	if health_override > 0.0 and enemy.health != null:
		enemy.health.configure(health_override)
	var credit := QuestKillCredit.new()
	credit.name = "QuestKillCredit"
	credit.enemy_tag = enemy_tag
	credit.credit_flag = credit_flag
	enemy.add_child(credit)
	# Generic loot: crystal + carapace trophies. The dropper only reads
	# HealthComponent.died and never touches CarapaceEnemy AI.
	var dropper := LootDropper.new()
	dropper.name = "LootDropper"
	dropper.loot_pool = CARAPACE_LOOT
	dropper.drop_flag = StringName("loot_%s_dropped" % String(enemy_tag))
	dropper.drop_seed = hash(String(enemy_tag))
	enemy.add_child(dropper)


func _marker(path: StringName) -> Node3D:
	return get_node_or_null(NodePath(path)) as Node3D


## Совместимость с будущими сценами: сбросить только игровые объекты,
## не трогая авторские маркеры и Generated-геометрию.
func refresh() -> void:
	if _runtime == null:
		return
	for child in _runtime.get_children():
		child.queue_free()
	_refresh_after_clear.call_deferred()


func _refresh_after_clear() -> void:
	await get_tree().process_frame
	_build()
