extends Node3D
## Изолированная визуальная приёмка подхода к храму. Только для просмотра кадра, не игровой путь.
## Не меняет NightmareRunState: демонстрационное состояние задаётся видимостью узлов этой сцены.

const SITE := preload("res://scenes/locations/pilgrim_path/pilgrim_path.tscn")
const MANNEQUIN := preload("res://scenes/slice/props/mannequin.tscn")

## Камера у нижней ступени; смотрит на разрушенные ворота.
@export var camera_position := Vector3(1.0, 5.6, -58.0)
@export var camera_target := Vector3(1.0, 4.8, -72.0)


func _ready() -> void:
	var site := SITE.instantiate() as PilgrimPath
	add_child(site)
	# Показ стража и ворот — узлами этой сцены, после _ready локации.
	(site.get_node("Props/TempleGuard") as Node3D).visible = true
	(site.get_node("Props/TempleGlow") as Node3D).visible = true
	# Масштабный ориентир: фигура человеческого роста у входа.
	var figure := MANNEQUIN.instantiate() as Node3D
	figure.position = Vector3(1.0, 4.15, -63.5)
	add_child(figure)
	var camera := Camera3D.new()
	camera.fov = 60.0
	add_child(camera)
	camera.position = camera_position
	camera.look_at(camera_target)
	camera.current = true
