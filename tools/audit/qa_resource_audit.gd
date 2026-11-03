extends SceneTree
## QA integrity audit: load every .tscn / .tres in scenes, resources and assets
## and report resources that fail to load. Read-only; nothing is saved.
##   godot --headless --path . -s tools/audit/qa_resource_audit.gd -- --out=...

var _extensions := ["tscn", "tres"]
var _roots := ["res://scenes", "res://resources", "res://assets"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var files: Array[String] = []
	for root_path in _roots:
		_collect(root_path, files)
	files.sort()
	var failures: Array[String] = []
	var scene_count := 0
	var resource_count := 0
	var checked := 0
	for path in files:
		checked += 1
		if checked % 50 == 0:
			print("QA_RES_PROGRESS ", checked, "/", files.size())
		var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if path.get_extension() == "tscn":
			scene_count += 1
		else:
			resource_count += 1
		if resource == null:
			failures.append(path)
			print("QA_RES_FAIL ", path)
	print("QA_RES_SUMMARY checked=", files.size(), " scenes=", scene_count,
		" resources=", resource_count, " failures=", failures.size())
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var file := FileAccess.open(out, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({
				"checked": files.size(),
				"scenes": scene_count,
				"resources": resource_count,
				"failures": failures,
			}, "\t"))
			file.close()
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
			_collect(path, files)
		elif _extensions.has(path.get_extension()):
			files.append(path)
		name = dir.get_next()
	dir.list_dir_end()
