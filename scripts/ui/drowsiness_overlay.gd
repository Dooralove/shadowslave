class_name DrowsinessOverlay
extends ColorRect
## Затемнение краёв кадра, передающее сонливость Санни. Только визуальный слой.

@export_range(0.0, 1.0) var intensity := 0.0:
	set(value):
		intensity = clampf(value, 0.0, 1.0)
		var shader_material := material as ShaderMaterial
		if shader_material:
			shader_material.set_shader_parameter(&"intensity", intensity)


func animate_to(value: float, duration: float) -> void:
	if duration <= 0.0:
		intensity = value
		return
	var tween := create_tween()
	tween.tween_property(self, "intensity", value, duration)
	await tween.finished
