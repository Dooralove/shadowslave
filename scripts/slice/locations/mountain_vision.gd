extends SliceLocation
## B14: видение Заклинания — гора под луной, затем время идёт вспять: дни и ночи мелькают,
## снег сходит с дороги, проступают и исчезают кости, караван пятится вниз по склону.

const NIGHT_SKY := Color(0.02, 0.03, 0.07)
const DAY_SKY := Color(0.55, 0.62, 0.72)

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var road: Node3D = $Road
@onready var snow: Node3D = $Road/SnowCover
@onready var bones: Node3D = $Road/Bones
@onready var caravan: Node3D = $Road/Caravan
@onready var caravan_end: Marker3D = $Road/CaravanEnd

var environment: Environment


func _ready() -> void:
	super._ready()
	# Своя копия: постановка меняет небо, а ресурс сцены должен остаться прежним для следующего запуска.
	environment = world_environment.environment.duplicate() as Environment
	world_environment.environment = environment


func play_cutscene(id: StringName, fast: bool) -> void:
	match id:
		&"vision":
			await _vision(fast)
		_:
			super.play_cutscene(id, fast)


func _vision(fast: bool) -> void:
	await _orbit(fast)
	use_shot(&"RoadShot")
	caravan.visible = true
	animate(caravan, ^"position", caravan_end.position, 6.0, fast)
	animate(snow, ^"scale:y", 0.02, 4.0, fast)
	await _rewind_days(3, 0.9, fast)
	bones.visible = true
	await _rewind_days(3, 0.6, fast)
	bones.visible = false
	snow.visible = false
	await _rewind_days(2, 0.45, fast)
	await pause(1.0, fast)


## Медленный облёт горы вокруг точки LookAt ракурса Orbit.
func _orbit(fast: bool) -> void:
	var camera := shot(&"Orbit")
	use_shot(&"Orbit")
	if fast:
		return
	set_orbit_mode(true)
	var center := (camera.get_node(^"LookAt") as Node3D).global_position
	var offset := camera.global_position - center
	var start := atan2(offset.x, offset.z)
	var radius := Vector2(offset.x, offset.z).length()
	var tween := create_tween()
	tween.tween_method(func(angle: float) -> void:
		camera.global_position = center + Vector3(sin(angle) * radius, offset.y, cos(angle) * radius)
		camera.look_at(center), start, start + 1.3, 6.0)
	await tween.finished
	set_orbit_mode(false)


## Декорация дороги стоит у начала координат, в двух километрах от горы: с орбиты она
## висела бы обломком над облаками. На время облёта она скрыта, к ракурсу RoadShot — снова видна.
func set_orbit_mode(on: bool) -> void:
	road.visible = not on


## Дни в обратную сторону: вспышка дня, затем снова ночь.
func _rewind_days(count: int, period: float, fast: bool) -> void:
	if fast:
		environment.background_color = NIGHT_SKY
		sun.light_energy = 0.0
		return
	for i in count:
		var tween := create_tween().set_parallel()
		tween.tween_property(environment, "background_color", DAY_SKY, period * 0.5)
		tween.tween_property(sun, "light_energy", 1.4, period * 0.5)
		tween.chain().tween_property(environment, "background_color", NIGHT_SKY, period * 0.5)
		tween.tween_property(sun, "light_energy", 0.0, period * 0.5)
		await tween.finished
