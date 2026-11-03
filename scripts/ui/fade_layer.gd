class_name FadeLayer
extends ColorRect
## Чёрная шторка для переходов между сценами.
##
## Если сцена загружена через LevelPortal с fade_in_duration, шторка стартует
## полностью чёрной и сама открывает кадр. Обычный запуск сцены остаётся
## прозрачным и не зависит от статического состояния портала.


func _ready() -> void:
	var scene_root := owner
	if scene_root == null:
		scene_root = get_tree().current_scene
	var scene_path := scene_root.scene_file_path if scene_root != null else ""
	var duration := LevelPortal.take_arrival_fade(scene_path)
	if duration < 0.0:
		return
	color.a = 1.0
	if duration <= 0.001:
		color.a = 0.0
		return
	var tween := create_tween()
	tween.tween_property(self, "color:a", 0.0, duration)


func fade_to(alpha: float, duration: float) -> void:
	if duration <= 0.0:
		color.a = alpha
		return
	var tween := create_tween()
	tween.tween_property(self, "color:a", alpha, duration)
	await tween.finished
