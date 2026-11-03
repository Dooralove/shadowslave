extends SceneTree
## One-shot persistence test for LootCache.
##
## Opens a chest, snapshots NightmareRunState, restores it, then instantiates a
## fresh chest and verifies it is already open and cannot grant loot twice.
##
## Usage:
##   godot --headless --path . -s tools/audit/loot_save_roundtrip_test.gd

const CHEST_SCENE := "res://scenes/loot/containers/chest_wood_iron.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var state := root.get_node_or_null(^"NightmareRunState")
	if state == null:
		push_error("loot_save_roundtrip_test: NightmareRunState autoload missing")
		quit(2)
		return
	state.reset()
	await process_frame

	var packed := load(CHEST_SCENE) as PackedScene
	if packed == null:
		push_error("loot_save_roundtrip_test: chest scene missing")
		quit(2)
		return
	var first := packed.instantiate() as LootCache
	root.add_child(first)
	await process_frame
	first.interact()
	await process_frame
	var shards_before := int(state.get_currency(&"soul_shard"))
	var rope_before := int(state.get_item_count(&"rope"))
	var flag_before := bool(state.has_flag(&"loot_secret_z02_wreck_chest_opened"))
	var snapshot: Dictionary = state.snapshot()

	state.reset()
	await process_frame
	var flag_after_reset := bool(state.has_flag(&"loot_secret_z02_wreck_chest_opened"))
	state.restore(snapshot)
	await process_frame
	var flag_after_restore := bool(state.has_flag(&"loot_secret_z02_wreck_chest_opened"))

	var second := packed.instantiate() as LootCache
	root.add_child(second)
	await process_frame
	var second_opened := second.is_opened()
	var second_enabled := second.enabled
	var second_lid := second.get_node_or_null(^"VisualRoot/Model/Lid") as Node3D
	var second_lid_angle := second_lid.rotation_degrees.x if second_lid != null else 0.0
	second.interact()
	await process_frame
	var shards_after := int(state.get_currency(&"soul_shard"))
	var rope_after := int(state.get_item_count(&"rope"))

	var ok: bool = (
		shards_before >= 2
		and rope_before >= 1
		and flag_before
		and not flag_after_reset
		and flag_after_restore
		and second_opened
		and not second_enabled
		and absf(second_lid_angle - 100.0) < 1.0
		and shards_after == shards_before
		and rope_after == rope_before
	)
	print(
		"SAVE_ROUNDTRIP shards=%d rope=%d flag=%s reset=%s restored=%s fresh_opened=%s fresh_enabled=%s fresh_lid=%.1f repeat_shards=%d repeat_rope=%d %s" % [
			shards_before, rope_before, str(flag_before), str(flag_after_reset),
			str(flag_after_restore), str(second_opened), str(second_enabled),
			second_lid_angle, shards_after, rope_after, "OK" if ok else "FAIL",
		]
	)
	quit(0 if ok else 1)
