class_name FollowCamera
extends Node3D
## Держит узел над активной камерой (эмиттер снегопада): частицы живут в мировых координатах,
## поэтому снег не «едет» за камерой, а эмиттер просто всегда засыпает то, что в кадре.

@export var offset := Vector3(0.0, 9.0, 0.0)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position + offset
