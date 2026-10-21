class_name FadeLayer
extends ColorRect
## Чёрная шторка для переходов между сценами.


func fade_to(alpha: float, duration: float) -> void:
	if duration <= 0.0:
		color.a = alpha
		return
	var tween := create_tween()
	tween.tween_property(self, "color:a", alpha, duration)
	await tween.finished
