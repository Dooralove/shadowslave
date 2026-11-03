extends SceneTree
## Печатает видимые кнопки и подписи сцены — чтобы найти UI, который не должен
## показываться (остатки кнопок, наложенный текст).


func _init() -> void:
	var scene_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene_path = arg.trim_prefix("--scene=")
	call_deferred(&"_run", scene_path)


func _run(scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		print("MISSING ", scene_path)
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	for i in 20:
		await process_frame
	for node in scene.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		var text := ""
		if control is Button:
			text = (control as Button).text
		elif control is Label:
			text = (control as Label).text
		elif control is RichTextLabel:
			text = (control as RichTextLabel).text
		if text.strip_edges().is_empty():
			continue
		var rect := control.get_global_rect()
		print(
			"%-14s %-20s rect=(%.0f,%.0f %.0fx%.0f) text=%s"
			% [
				control.get_class(),
				control.name,
				rect.position.x,
				rect.position.y,
				rect.size.x,
				rect.size.y,
				text.replace("\n", " / "),
			]
		)
	quit()
