class_name StealthSection
extends Node3D
## N21: стелс после пещеры. Две угрозы:
## - Герой ищет Санни глазами; от взгляда прячут тени у скал.
## - Слепой Тиран слышит шум и идёт к его источнику.
##
## Узел живёт в базовой сцене pilgrim_path.tscn. Оболочка передаёт игрока
## через begin(player), а завершение/поимку обрабатывает PilgrimPath.

signal noise_emitted(event: NoiseEventData, origin: Vector3, source: Node3D)
signal tyrant_heard_noise(event: NoiseEventData, origin: Vector3)
signal player_hidden_changed(hidden: bool)
signal player_spotted
signal tyrant_caught
signal stealth_started
signal stealth_completed
signal bell_used

const STEP_EVENT := preload("res://resources/stealth/noise/step.tres")
const RUN_EVENT := preload("res://resources/stealth/noise/run.tres")
const ROCKFALL_EVENT := preload("res://resources/stealth/noise/rockfall.tres")
const BELL_EVENT := preload("res://resources/stealth/noise/bell.tres")

## Смещения теней вдоль карниза. Радиус — укрытие от взгляда, не от слуха.
const SHADOW_LAYOUT := [
	{"name": "ShadowWest", "position": Vector3(-0.75, 4.15, -55.8), "radius": 1.15},
	{"name": "ShadowEast", "position": Vector3(2.65, 4.15, -57.0), "radius": 1.15},
	{"name": "ShadowEdge", "position": Vector3(0.1, 4.15, -58.15), "radius": 1.0},
]
const TYRANT_START := Vector3(-0.8, 4.15, -56.4)

@export var step_interval := 0.52
@export var run_interval := 0.3
@export var hero_view_distance := 9.5
@export var hero_view_angle_degrees := 72.0
@export var hero_turn_speed := 5.0
@export var completion_distance := 1.35

var player: Node3D
var hero: Node3D
var tyrant_visual: Node3D
var hero_stand: Node3D
var start_marker: Node3D
var noise_system: NoiseEventSystem
var tyrant: BlindTyrant
var shadow_zones: Array[ShadowZone] = []

var active := false
var hidden := false
var bell_rescue := false
var hero_seen := false
var last_noise: NoiseEventData
var last_noise_origin := Vector3.ZERO

var _step_timer := 0.0
var _spotted_cooldown := 0.0
var _scan_phase := 0.0
var _scene_bound := false
var _tyrant_home_position := Vector3.ZERO
var _bell_hint_played := false


func _ready() -> void:
	_bind_scene()
	set_physics_process(true)


func _bind_scene() -> void:
	if _scene_bound:
		return
	_scene_bound = true
	var root := get_parent()
	if root == null:
		return
	hero = root.get_node_or_null("NPCs/Hero") as Node3D
	tyrant_visual = root.get_node_or_null("NPCs/TyrantAtHero") as Node3D
	hero_stand = root.get_node_or_null("Spawns/HeroStand") as Node3D
	start_marker = root.get_node_or_null("Spawns/StealthStart") as Node3D
	if tyrant_visual != null:
		_tyrant_home_position = tyrant_visual.global_position

	noise_system = NoiseEventSystem.new()
	noise_system.name = "NoiseEventSystem"
	add_child(noise_system)
	for event in [STEP_EVENT, RUN_EVENT, ROCKFALL_EVENT, BELL_EVENT]:
		noise_system.register_event(event)
	noise_system.noise_emitted.connect(_on_noise)

	tyrant = BlindTyrant.new()
	tyrant.name = "BlindTyrant"
	add_child(tyrant)
	tyrant.visual = tyrant_visual
	tyrant.target = null
	tyrant.heard_noise.connect(_on_tyrant_heard_noise)
	tyrant.caught_player.connect(_on_tyrant_caught)

	_create_shadow_zones()


func _create_shadow_zones() -> void:
	if not shadow_zones.is_empty():
		return
	var container := get_node_or_null("ShadowZones") as Node3D
	if container == null:
		container = self
	for entry in SHADOW_LAYOUT:
		var zone := ShadowZone.new()
		zone.name = String(entry["name"])
		zone.position = entry["position"] as Vector3
		zone.radius = float(entry["radius"])
		container.add_child(zone)
		shadow_zones.append(zone)


func begin(target_player: Node3D) -> void:
	if active:
		return
	if target_player == null or not is_instance_valid(target_player):
		return
	if not _scene_bound:
		_bind_scene()
	player = target_player
	active = true
	hidden = false
	bell_rescue = false
	hero_seen = false
	last_noise = null
	_step_timer = 0.0
	_spotted_cooldown = 0.0
	_scan_phase = 0.0
	if hero_stand == null and get_parent() != null:
		hero_stand = get_parent().get_node_or_null("Spawns/HeroStand") as Node3D
	if hero != null:
		hero.visible = true
		if hero_stand != null:
			hero.global_position = hero_stand.global_position
		hero.rotation.y = PI
	if tyrant != null:
		tyrant.configure(tyrant_visual, player, TYRANT_START)
		tyrant.set_active(true)
	_update_hidden(true)
	_play_bell_hint()
	set_physics_process(true)
	stealth_started.emit()


func finish() -> void:
	if not active:
		return
	active = false
	set_physics_process(false)
	if tyrant != null:
		tyrant.set_active(false)
	if tyrant_visual != null:
		tyrant_visual.visible = false
		# N22 снова показывает Тирана за спиной Героя, а не на месте стелса.
		tyrant_visual.global_position = _tyrant_home_position
	stealth_completed.emit()


func reset() -> void:
	active = false
	set_physics_process(false)
	hidden = false
	bell_rescue = false
	hero_seen = false
	last_noise = null
	if tyrant != null:
		tyrant.reset(TYRANT_START, null)
	if tyrant_visual != null:
		tyrant_visual.visible = false


func emit_noise(event_id: StringName, origin: Vector3, source: Node3D = null) -> bool:
	if noise_system == null:
		return false
	return noise_system.emit_event(event_id, origin, source)


func emit_bell_rescue(origin: Vector3, source: Node3D = null) -> bool:
	## Колокольчик — исключение из правила шума: он должен увести Тирана
	## к Герою, а не к Санни. Цель подставляет _on_noise.
	return emit_noise(&"bell", origin, source)


func is_player_hidden() -> bool:
	return hidden


func is_player_visible_to_hero() -> bool:
	if player == null or hero == null or not is_instance_valid(player) or not is_instance_valid(hero):
		return false
	if hidden:
		return false
	var offset := player.global_position - hero.global_position
	offset.y = 0.0
	if offset.length() > hero_view_distance:
		return false
	var facing := get_hero_facing()
	if facing.length_squared() <= 0.001:
		return false
	return facing.angle_to(offset.normalized()) <= deg_to_rad(hero_view_angle_degrees * 0.5)


func get_hero_facing() -> Vector3:
	if hero == null:
		return Vector3.ZERO
	return Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, hero.global_rotation.y).normalized()


func get_tyrant() -> BlindTyrant:
	return tyrant


func get_shadow_zones() -> Array[ShadowZone]:
	return shadow_zones


func _physics_process(delta: float) -> void:
	if not active:
		return
	if player == null or not is_instance_valid(player):
		return
	_update_hidden()
	_update_hero_look(delta)
	_update_player_noise(delta)
	if hero_stand != null and player.global_position.distance_to(hero_stand.global_position) <= completion_distance:
		finish()


func _update_hidden(force_signal := false) -> void:
	var now_hidden := false
	for zone in shadow_zones:
		if zone != null and zone.contains_point(player.global_position):
			now_hidden = true
			break
	if now_hidden != hidden or force_signal:
		hidden = now_hidden
		player_hidden_changed.emit(hidden)


func _update_hero_look(delta: float) -> void:
	if hero == null:
		return
	var offset := player.global_position - hero.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return
	# Герой поворачивается туда, куда смотрит. Если Санни в тени, обзор
	# не подтверждает цель, и Герой продолжает искать силуэтом.
	if not hidden:
		var desired := atan2(-offset.x, -offset.z)
		hero.rotation.y = lerp_angle(hero.rotation.y, desired, clampf(hero_turn_speed * delta, 0.0, 1.0))
		if is_player_visible_to_hero():
			if _spotted_cooldown <= 0.0:
				hero_seen = true
				player_spotted.emit()
				_spotted_cooldown = 1.2
	else:
		# Потеряв силуэт, Герой продолжает искать: медленно водит головой
		# в секторе перед карнизом. Игрок видит направление по повороту.
		_scan_phase += delta
		var scan_target := PI + sin(_scan_phase * 1.35) * 0.58
		hero.rotation.y = lerp_angle(hero.rotation.y, scan_target, clampf(hero_turn_speed * 0.55 * delta, 0.0, 1.0))
	_spotted_cooldown = maxf(_spotted_cooldown - delta, 0.0)


func _update_player_noise(delta: float) -> void:
	var speed := 0.0
	if player is CharacterBody3D:
		var body := player as CharacterBody3D
		speed = Vector2(body.velocity.x, body.velocity.z).length()
	if speed < 0.35:
		_step_timer = 0.0
		return
	_step_timer += delta
	var event := RUN_EVENT if speed >= 5.0 else STEP_EVENT
	var interval := run_interval if event == RUN_EVENT else step_interval
	if _step_timer < interval:
		return
	_step_timer = 0.0
	emit_noise(event.id, player.global_position, player)


func _on_noise(event: NoiseEventData, origin: Vector3, source: Node3D) -> void:
	if event == null:
		return
	last_noise = event
	last_noise_origin = origin
	noise_emitted.emit(event, origin, source)
	_play_noise_sfx(event, origin)
	if event.is_bell:
		bell_rescue = true
		bell_used.emit()
	if active and tyrant != null:
		var override_target: Node3D = hero if event.is_bell else null
		tyrant.hear_noise(event, origin, override_target)


func _on_tyrant_heard_noise(event: NoiseEventData, origin: Vector3) -> void:
	tyrant_heard_noise.emit(event, origin)


func _on_tyrant_caught() -> void:
	if not active:
		return
	active = false
	set_physics_process(false)
	if tyrant != null:
		tyrant.set_active(false)
	tyrant_caught.emit()


func _play_bell_hint() -> void:
	# Заранее готовим переворот правила: далёкий металлический звон в стороне
	# Героя. Это подсказка, что колокольчик существует, а не случайный шум.
	if _bell_hint_played:
		return
	_bell_hint_played = true
	var audio := get_node_or_null("/root/AudioDirector")
	if audio == null or not audio.has_method(&"play_sfx"):
		return
	var position := hero_stand.global_position if hero_stand != null else global_position
	audio.call(&"play_sfx", &"world_key", position + Vector3(0.0, 0.2, -1.0), -22.0)


func _play_noise_sfx(event: NoiseEventData, origin: Vector3) -> void:
	var audio := get_node_or_null("/root/AudioDirector")
	if audio == null or not audio.has_method(&"play_sfx"):
		return
	if event.id == &"rockfall":
		audio.call(&"play_sfx", &"world_rockfall", origin, -4.0)
	elif event.is_bell:
		audio.call(&"play_sfx", &"world_key", origin, -8.0)
