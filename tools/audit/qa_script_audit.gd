extends SceneTree
## QA script compile audit: load every .gd under res:// and report failures.
##   godot --headless --path . -s tools/audit/qa_script_audit.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var files: Array[String] = []
	_collect("res://", files)
	files.sort()
	var failures: Array[String] = []
	for path in files:
		var resource: Resource = load(path)
		if resource == null or (resource is GDScript and not (resource as GDScript).can_instantiate()):
			failures.append(path)
			print("QA_SCRIPT_FAIL ", path)
	print("QA_SCRIPT_SUMMARY checked=", files.size(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)


func _collect(dir_path: String, files: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var path := dir_path.path_join(name)
		if dir.current_is_dir():
			if path != "res://experiments" and path != "res://incoming_models" and path != "res://addons" and path != "res://tools":
				_collect(path, files)
		elif path.get_extension() == "gd":
			files.append(path)
		name = dir.get_next()
	dir.list_dir_end()
