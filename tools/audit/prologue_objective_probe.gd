extends SceneTree
## Проверка цели пролога: какой бит активен и что показывает CampaignGuide.


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var entry := (load("res://scenes/campaign/campaign_entry.tscn") as PackedScene).instantiate()
	root.add_child(entry)
	current_scene = entry
	await process_frame
	var prologue := entry.get_node_or_null(^"Prologue")
	if prologue == null:
		print("NO PROLOGUE")
		quit(1)
		return
	prologue.call(&"start")
	await process_frame
	await process_frame
	print("start beat=", prologue.get(&"beat"))
	var guide := root.get_node_or_null(^"CampaignGuide")
	print("start obj=", guide.get(&"display_objective"), " src=", guide.call(&"get_external_source"), " base=", guide.get(&"base_objective"))
	prologue.call(&"_set_beat", 7) # B07_ENTER_STATION
	await process_frame
	await process_frame
	print("after beat=", prologue.get(&"beat"))
	print("after obj=", guide.get(&"display_objective"), " src=", guide.call(&"get_external_source"), " base=", guide.get(&"base_objective"))
	var bd := prologue.get_node_or_null(^"BeatDirector")
	if bd == null:
		for child in prologue.get_children():
			if child.has_method(&"get_current_beat_id"):
				bd = child
				break
	if bd != null:
		print("beat_id=", bd.call(&"get_current_beat_id"))
	prologue.call(&"_set_beat", 8) # B08_DESK
	await process_frame
	await process_frame
	print("after8 beat=", prologue.get(&"beat"))
	print("after8 obj=", guide.get(&"display_objective"), " src=", guide.call(&"get_external_source"), " base=", guide.get(&"base_objective"))
	if bd != null:
		print("beat_id8=", bd.call(&"get_current_beat_id"))
	var ui := prologue.get_node_or_null(^"UI")
	if ui != null:
		var line := ui.get_node_or_null(^"ObjectiveLine")
		if line != null:
			print("ui_obj=", line.call(&"get_objective_text"), " showing=", line.call(&"is_showing"))
	quit()
