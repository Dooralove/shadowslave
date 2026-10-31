@tool
extends EditorScenePostImport
## Пост-импорт библиотек анимаций прототипа S2 (UAL и собственный Idle).
##
## Каждый клип должен задавать позу целиком, иначе кости без дорожек сохраняют позу предыдущего клипа
## (так после сидения таз оставался внизу). Поэтому в импорте отключено `remove_immutable_tracks`.
## Но дорожки положения всех костей несут длины костей исходного манекена — на скелете Санни они
## ломают пропорции. Штатная опция `retarget/remove_tracks/unimportant_positions` в Godot 4.7.2 при
## импорте даёт ошибки индексов и удаляет лишнее, поэтому то же делается здесь: остаются вращения всех
## костей, масштаб не трогается, а положение — только у Root и Hips (перемещение тела).

const KEEP_POSITION := [&"Root", &"Hips"]


func _post_import(scene: Node) -> Object:
	for player in scene.find_children("*", "AnimationPlayer", true, false):
		for library_name in player.get_animation_library_list():
			var library: AnimationLibrary = player.get_animation_library(library_name)
			for animation_name in library.get_animation_list():
				_strip(library.get_animation(animation_name))
	return scene


func _strip(animation: Animation) -> void:
	for i in range(animation.get_track_count() - 1, -1, -1):
		var type := animation.track_get_type(i)
		var bone := StringName(animation.track_get_path(i).get_concatenated_subnames())
		if type == Animation.TYPE_POSITION_3D and bone not in KEEP_POSITION:
			animation.remove_track(i)
		elif type == Animation.TYPE_SCALE_3D:
			animation.remove_track(i)
