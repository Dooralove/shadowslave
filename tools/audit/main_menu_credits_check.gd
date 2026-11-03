extends SceneTree
## Проверка, что CC BY-атрибуция доступна из главного меню.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/ui/main_menu/main_menu.tscn") as PackedScene
	if packed == null:
		push_error("cannot load main menu")
		quit(2)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	var button := scene.find_child("CreditsButton", true, false) as Button
	var dialog := scene.find_child("CreditsDialog", true, false) as AcceptDialog
	print("CREDITS_BUTTON=", button != null)
	print("CREDITS_DIALOG=", dialog != null)
	if dialog != null:
		print("HAS_MZEE92=", dialog.dialog_text.contains("mzee92"))
		print("HAS_CC_BY=", dialog.dialog_text.contains("CC BY 4.0"))
		print("HAS_SOURCE=", dialog.dialog_text.contains("sketchfab.com"))
	quit(0)
