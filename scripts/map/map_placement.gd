class_name MapPlacement
extends Resource
## Где локация стоит на общей карте региона.
##
## Карта региона собирает геометрию нескольких сцен на одной подложке. Каждая
## сцена — со своим началом координат, поэтому размещение задаёт перенос
## центра области локации (world_bounds.get_center()) в точку подложки, масштаб
## и поворот. Внутри локации геометрия точная; расстояния между локациями —
## условные (сцены не связаны общей геометрией).

@export var location_id: StringName
## Подпись локации на карте региона.
@export var label := ""
## Куда на подложке (в её пикселях) ставится центр области локации.
@export var center := Vector2.ZERO
@export var pixels_per_meter := 1.0
## Поворот по часовой стрелке: север сцены (-Z) после поворота смотрит туда же,
## куда указывает (0, -1), повёрнутый на этот угол.
@export var rotation_degrees := 0.0
## Смещение подписи локации от center (пиксели подложки).
@export var label_offset := Vector2.ZERO


## Мировые XZ локации → координаты подложки региона.
func to_region(world_xz: Vector2, pivot: Vector2) -> Vector2:
	return center + (world_xz - pivot).rotated(deg_to_rad(rotation_degrees)) * pixels_per_meter


## Направление в мировых XZ → направление на подложке (без масштаба).
func direction_to_region(direction_xz: Vector2) -> Vector2:
	return direction_xz.rotated(deg_to_rad(rotation_degrees))
