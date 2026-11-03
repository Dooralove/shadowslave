extends Node3D
## QA prologue tour: runs the real CampaignEntry/Prologue in fast mode, advances
## dialogue/interactions programmatically and captures key beats. This is an
## automated graphical tour, not a human playthrough.
##   godot --path . res://tools/audit/qa_prologue_tour.tscn -- --out=<dir>

const ENTRY := "res://scenes/campaign/campaign_entry.tscn"

var _out := ""
var _entry: Node
var _prologue: SliceDirector
var _captured := {}
var _frame := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out.is_empty():
		push_error("qa_prologue_tour: need --out=<dir>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().root.size = Vector2i(1920, 1080)
	_entry = (load(ENTRY) as PackedScene).instantiate()
	_entry.set(&"autostart", false)
	_entry.set(&"transition_enabled", false)
	add_child(_entry)
	await get_tree().process_frame
	_entry.call(&"start")
	_prologue = _entry.get_node("Prologue") as SliceDirector
	_prologue.fast_mode = true
	_prologue.runner.fast_mode = true
	await get_tree().process_frame
	_run()


func _run() -> void:
	for i in 900:
		_frame += 1
		if _prologue == null or not is_instance_valid(_prologue):
			break
		await _capture_for_beat()
		if _prologue.runner.running:
			_prologue.runner.advance()
		elif _prologue.ui.rune_status.showing:
			await _capture("B16_runes")
			break
		elif _prologue.awaiting != &"":
			_prologue.notify(_prologue.awaiting)
		await get_tree().process_frame
		print("QA_PROLOGUE frame=", _frame, " beat=", _prologue.beat, " awaiting=", _prologue.awaiting)
	print("QA_PROLOGUE done frames=", _frame, " beat=", _prologue.beat if _prologue != null else -1)
	get_tree().quit(0)


func _capture_for_beat() -> void:
	var beat := int(_prologue.beat)
	var key := ""
	if beat == SliceDirector.Beat.B01_OPENING:
		key = "B01_park"
	elif beat == SliceDirector.Beat.B03_DOZE:
		key = "B03_doze"
	elif beat == SliceDirector.Beat.B07_ENTER_STATION:
		key = "B07_lobby"
	elif beat == SliceDirector.Beat.B08_DESK:
		key = "B08_desk"
	elif beat == SliceDirector.Beat.B09_CODE_BLACK:
		key = "B09_code_black"
	elif beat == SliceDirector.Beat.B14_VISION:
		key = "B14_vision"
	elif beat == SliceDirector.Beat.B15_CARAVAN:
		key = "B15_caravan"
	if not key.is_empty() and not _captured.has(key):
		await _capture(key)


func _capture(key: String) -> void:
	_captured[key] = true
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var path := _out.path_join(key + ".png")
	var error := image.save_png(path)
	print("QA_PROLOGUE_CAPTURE ", key, " error=", error, " out=", path)
