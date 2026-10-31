class_name SoulSeaScene
extends Node3D
## Каркас внутреннего пространства. Сцена ничего не знает о здоровье,
## инвентаре или основной камере: контроллер добавляет её аддитивно
## в удалённую точку World3D и переключает активную камеру.

signal beacon_activated(active: bool)

@onready var camera_rig: SoulSeaCameraRig = $CameraRig
@onready var beacon: SoulSeaBeacon = $MemoryBeacon


func _ready() -> void:
	beacon.activated.connect(_on_beacon_activated)


func get_camera() -> Camera3D:
	return camera_rig.camera


func set_active(value: bool) -> void:
	camera_rig.set_active(value)


func _on_beacon_activated(active: bool) -> void:
	beacon_activated.emit(active)
