class_name LabyrinthAtmosphere
extends Node3D
## Demo-fragment atmosphere: local VFX, campfire, storm and tide accents.
##
## This node never changes routes, collision, markers or gameplay state. It
## listens to the zone id from LabyrinthAudio and to TideController's public
## level query, then fires one-shots at authored marker positions. Major cues
## are latched per zone so crossing a boundary cannot retrigger a stinger every
## frame, while SfxCue cooldowns cover the smaller accents.

const STORM_ZONES: Array[StringName] = [&"labyrinth_z16", &"labyrinth_z17", &"labyrinth_z18"]
const VFX := preload("res://scripts/vfx/one_shot_vfx.gd")
const FIRE_SCENE := preload("res://scenes/environment/nm_fire_flame.tscn")
const SMOKE_SCENE := preload("res://scenes/environment/p3_camp_smoke.tscn")
const DUST_SCENE := preload("res://scenes/environment/p3_dust_motes.tscn")
const RAIN_SCENE := preload("res://scenes/environment/vfx/storm_rain.tscn")
const MOTE_SCENE := preload("res://scenes/environment/vfx/azure_motes.tscn")

@export var audio: LabyrinthAudio
@export var player: Node3D

var _zone: StringName = &""
var _visited: Dictionary = {}
var _storm_active := false
var _rain: Node3D
var _lightning: DirectionalLight3D
var _lightning_wait := 4.0
var _campfire_audio: AudioStreamPlayer3D
var _director: Node
var _tide: Node
var _tide_warned := false
var _tide_sprayed := false
var _sprays: Array[Dictionary] = []
var _beacons: Array[Dictionary] = []
var _environment: Environment
var _sky_material: ShaderMaterial
var _sun: DirectionalLight3D
var _fill_a: DirectionalLight3D
var _fill_b: DirectionalLight3D
var _sky_timer := 0.0


func _ready() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group(&"player") as Node3D
	if audio == null:
		audio = get_parent().get_node_or_null(^"LabyrinthAudio") as LabyrinthAudio
	_director = get_node_or_null(^"/root/AudioDirector")
	_connect_quest_audio()
	_tide = get_parent().get_node_or_null(^"Tide/TideController")
	_cache_sky()
	_build_campfire()
	_build_dust()
	_build_rain()
	_build_lightning()
	_build_sprays()
	# One-shot signal connection is safer than a coroutine: if the scene is
	# freed before the next frame, Godot drops the connection instead of
	# resuming a method on a dead instance.
	get_tree().process_frame.connect(_configure_gameplay_interactions, CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var zone := audio.get_zone_id() if audio != null else &""
	if zone != _zone:
		_zone = zone
		_enter_zone(zone)
	var storm := zone in STORM_ZONES
	if storm != _storm_active:
		_storm_active = storm
		_set_storm(storm)
	if _storm_active:
		if _rain != null:
			_rain.global_position = player.global_position + Vector3.UP * 14.0
		_lightning_wait -= delta
		if _lightning_wait <= 0.0:
			_lightning_wait = randf_range(7.0, 15.0)
			_flash_lightning()
	_sky_timer += delta
	if _sky_timer >= 0.25:
		_sky_timer = 0.0
		_update_sky()
	_poll_beacons()
	_poll_tide()


## The fragment spans three sky regimes: pale eastern day at the statue,
## neutral grey in the hunting grounds, and a dark storm wall at the cliffs.
## The transition is driven by active-camera X, so the world changes as the
## player travels instead of switching at a zone border.
func _cache_sky() -> void:
	var root := get_parent()
	var world_env := root.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if world_env != null:
		var source_env := world_env.environment
		if source_env != null:
			# The scene resource is shared between instances and with tests.
			# Work on a private deep copy so one location cannot rewrite the
			# sky/fog of another instance.
			_environment = source_env.duplicate(true) as Environment
			world_env.environment = _environment
			if _environment.sky != null:
				var sky := _environment.sky.duplicate(true) as Sky
				_environment.sky = sky
				if sky.sky_material != null:
					var sky_material := sky.sky_material.duplicate(true) as Material
					sky.sky_material = sky_material
					_sky_material = sky_material as ShaderMaterial
	_sun = root.get_node_or_null(^"Sun") as DirectionalLight3D
	_fill_a = root.get_node_or_null(^"SkyFill") as DirectionalLight3D
	_fill_b = root.get_node_or_null(^"SkyFill2") as DirectionalLight3D
	if _environment == null:
		push_warning("LabyrinthAtmosphere: WorldEnvironment/Environment не найден; переход неба отключён.")
	elif _sky_material == null:
		push_warning("LabyrinthAtmosphere: sky ShaderMaterial не найден; переход неба отключён.")
	_update_sky()


func _update_sky() -> void:
	if _environment == null or _sky_material == null:
		return
	var view_position := player.global_position if player != null and is_instance_valid(player) else Vector3.ZERO
	# Cutscene and audit cameras can stand far from the player. Drive the sky
	# from the active camera so the storm reads correctly in authored shots.
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		view_position = camera.global_position
	var x := view_position.x
	var west := clampf((-250.0 - x) / 850.0, 0.0, 1.0)
	west = west * west * (3.0 - 2.0 * west)
	# Rain/lightning start in Z16, so the sky must start darkening there too.
	var storm := clampf((-850.0 - x) / 350.0, 0.0, 1.0)
	storm = storm * storm * (3.0 - 2.0 * storm)

	var sky_top := Color(0.30, 0.36, 0.44).lerp(Color(0.16, 0.19, 0.23), west)
	var sky_horizon := Color(0.70, 0.71, 0.70).lerp(Color(0.36, 0.40, 0.43), west)
	var cloud_cover := lerpf(0.30, 0.78, west)
	var sun_energy := lerpf(1.6, 0.35, west)
	var sun_color := Color(1.0, 0.93, 0.82).lerp(Color(0.72, 0.78, 0.86), west)
	var cloud_color := Color(0.78, 0.79, 0.80).lerp(Color(0.30, 0.34, 0.38), west)
	var fog_color := Color(0.50, 0.53, 0.56).lerp(Color(0.28, 0.32, 0.36), west)
	var fog_density := lerpf(0.40, 0.62, west)
	var ambient := lerpf(0.78, 0.52, west)
	var sun_light := lerpf(1.75, 0.85, west)

	if storm > 0.01:
		cloud_cover = lerpf(cloud_cover, 0.95, storm)
		sun_energy = lerpf(sun_energy, 0.08, storm)
		cloud_color = cloud_color.lerp(Color(0.18, 0.21, 0.24), storm)
		fog_color = fog_color.lerp(Color(0.20, 0.24, 0.28), storm)
		fog_density = lerpf(fog_density, 0.85, storm)
		ambient = lerpf(ambient, 0.42, storm)
		sun_light = lerpf(sun_light, 0.55, storm)

	_sky_material.set_shader_parameter("sky_top", sky_top)
	_sky_material.set_shader_parameter("sky_horizon", sky_horizon)
	_sky_material.set_shader_parameter("cloud_cover", cloud_cover)
	_sky_material.set_shader_parameter("cloud_color", cloud_color)
	_sky_material.set_shader_parameter("cloud_speed", lerpf(0.004, 0.012, west))
	_sky_material.set_shader_parameter("sun_energy", sun_energy)
	_sky_material.set_shader_parameter("sun_color", sun_color)
	_environment.fog_light_color = fog_color
	_environment.fog_density = fog_density
	_environment.ambient_light_energy = ambient
	if _sun != null:
		_sun.light_color = sun_color
		_sun.light_energy = sun_light
	if _fill_a != null:
		_fill_a.light_energy = lerpf(0.38, 0.22, west)
	if _fill_b != null:
		_fill_b.light_energy = lerpf(0.30, 0.18, west)


func _enter_zone(zone: StringName) -> void:
	if zone.is_empty():
		return
	if _visited.has(zone):
		return
	_visited[zone] = true
	match zone:
		&"labyrinth_z01":
			_play(&"world_stone_shift", Vector3(38, 2, 0), -8.0)
			_play(&"world_wind_gust", Vector3(30, 4, 0), -10.0)
		&"labyrinth_z02":
			_play(&"creature_carapace_click", Vector3(19, -1, 30), -6.0)
			_play(&"world_bone_creak", Vector3(19, 0, 26), -8.0)
		&"labyrinth_z03":
			_play(&"creature_carapace_chitter", Vector3(0, 1, 4), -7.0)
			_spawn_dust(Vector3(0, 0.2, 0))
		&"labyrinth_z04":
			_play(&"world_water_splash", Vector3(-30, -2.5, -42), -7.0)
		&"labyrinth_z05":
			_play(&"world_bone_creak", Vector3(-30, 3, 21), -6.0)
			_spawn_dust(Vector3(-30, 0.2, 21))
		&"labyrinth_z06":
			_play(&"world_wind_gust", Vector3(-47, 7, 46), -9.0)
		&"labyrinth_z07":
			_play(&"world_wind_gust", Vector3(-25, 9, -55), -8.0)
		&"labyrinth_z08":
			_play(&"world_echo_whisper", Vector3(-65, 2, 0), -7.0)
		&"labyrinth_z09":
			_play(&"world_water_drip", Vector3(-70, 1, 20), -7.0)
			_spawn_dust(Vector3(-70, 0.3, 20))
		&"labyrinth_z10":
			_play(&"world_wind_gust", Vector3(-100, 20, -5), -10.0)
		&"labyrinth_z11":
			_play(&"world_water_splash", Vector3(-137, 5, -20), -6.0)
		&"labyrinth_z12":
			_play(&"world_wind_gust", Vector3(-175, 3, 0), -9.0)
		&"labyrinth_z13":
			_play(&"creature_carapace_chitter", Vector3(-375, 3, 0), -8.0)
		&"labyrinth_z14":
			_play(&"world_bone_creak", Vector3(-600, 8, 0), -5.0)
			_play(&"world_echo_whisper", Vector3(-600, 7, 0), -10.0)
			_spawn_dust(Vector3(-600, 6.5, 0))
		&"labyrinth_z15":
			_play(&"world_soul_shard", Vector3(-700, 19, -20), -8.0)
		&"labyrinth_z16":
			_play(&"creature_carapace_chitter", Vector3(-850, 1, -20), -9.0)
			_play(&"creature_carapace_chitter", Vector3(-950, 1, 20), -10.0)
		&"labyrinth_z17":
			_play(&"world_wind_gust", Vector3(-1175, 9, 0), -6.0)
		&"labyrinth_z18":
			_play(&"world_wind_gust", Vector3(-1400, 36, 0), -7.0)
			_play(&"world_stone_shift", Vector3(-1400, 36, 0), -9.0)


func _connect_quest_audio() -> void:
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests == null:
		return
	if quests.has_signal(&"quest_started") and not quests.quest_started.is_connected(_on_quest_started):
		quests.quest_started.connect(_on_quest_started)
	if quests.has_signal(&"quest_objective_completed") and not quests.quest_objective_completed.is_connected(_on_quest_objective_completed):
		quests.quest_objective_completed.connect(_on_quest_objective_completed)
	if quests.has_signal(&"quest_completed") and not quests.quest_completed.is_connected(_on_quest_completed):
		quests.quest_completed.connect(_on_quest_completed)


func _on_quest_started(_quest: Variant) -> void:
	_play_ui(&"ui_quest_update", -4.0)


func _on_quest_objective_completed(_quest: Variant, _objective: Variant) -> void:
	_play_ui(&"ui_quest_update", -6.0)


func _on_quest_completed(_quest: Variant) -> void:
	_play_ui(&"ui_skill_unlock", -3.0)


func _play_ui(cue: StringName, volume_db := 0.0) -> void:
	if _director == null or not is_instance_valid(_director):
		return
	if _director.has_method(&"play_ui"):
		_director.call(&"play_ui", cue, volume_db)


func _play(cue: StringName, position: Vector3, volume_db := 0.0) -> void:
	if _director == null or not is_instance_valid(_director):
		return
	if _director.has_method(&"play_sfx"):
		_director.call(&"play_sfx", cue, position, volume_db)


func _spawn_dust(position: Vector3) -> void:
	VFX.spawn("res://scenes/environment/vfx/impact_dust.tscn", position)


func _build_campfire() -> void:
	var marker := get_parent().get_node_or_null(^"Gameplay/Interactables/Campfire") as Node3D
	if marker == null:
		return
	var fire := FIRE_SCENE.instantiate() as Node3D
	fire.name = "CampFireVfx"
	add_child(fire)
	fire.global_position = marker.global_position + Vector3.UP * 0.55
	var smoke := SMOKE_SCENE.instantiate() as Node3D
	smoke.name = "CampSmokeVfx"
	add_child(smoke)
	smoke.global_position = marker.global_position + Vector3.UP * 1.0
	# The greybox already has a static flame cylinder; hide it so the particle
	# flame does not read as a second, solid object.
	var static_flame := get_parent().get_node_or_null(
		^"Generated/Visual/Z10_CoralHill/Z10_Campfire_Flame"
	) as MeshInstance3D
	if static_flame != null:
		static_flame.visible = false
	_campfire_audio = AudioStreamPlayer3D.new()
	_campfire_audio.name = "CampfireLoop"
	_campfire_audio.bus = &"Ambience"
	_campfire_audio.stream = load("res://assets/audio/demo/ambience/campfire_loop_01.ogg") as AudioStream
	AudioLibrary.ensure_loop(_campfire_audio.stream)
	_campfire_audio.volume_db = 0.0
	_campfire_audio.unit_size = 4.0
	_campfire_audio.max_distance = 26.0
	_campfire_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	add_child(_campfire_audio)
	_campfire_audio.global_position = marker.global_position + Vector3.UP * 0.7
	if AudioLibrary.playback_enabled():
		_campfire_audio.play()


func _build_dust() -> void:
	var points := [
		Vector3(19, -0.4, 26),
		Vector3(-30, 0.4, 21),
		Vector3(-70, 0.5, 20),
		Vector3(-375, 1.2, 0),
		Vector3(-900, 1.2, 0),
		Vector3(-1400, 36.2, 0),
	]
	for i in points.size():
		var dust := DUST_SCENE.instantiate() as Node3D
		dust.name = "DustZone%02d" % (i + 1)
		add_child(dust)
		dust.global_position = points[i]
		dust.scale = Vector3.ONE * 0.8
		var emitter := dust.get_node_or_null(^"Motes") as GPUParticles3D
		if emitter != null:
			emitter.amount = 70


func _build_rain() -> void:
	_rain = RAIN_SCENE.instantiate() as Node3D
	_rain.name = "StormRainVfx"
	add_child(_rain)
	_rain.visible = false


func _build_lightning() -> void:
	_lightning = DirectionalLight3D.new()
	_lightning.name = "StormLightning"
	_lightning.light_color = Color(0.62, 0.74, 1.0, 1.0)
	_lightning.light_energy = 0.0
	_lightning.shadow_enabled = false
	_lightning.rotation_degrees = Vector3(-62, -28, 0)
	add_child(_lightning)


func _build_sprays() -> void:
	_sprays = [
		{"position": Vector3(-137.0, 5.5, -20.0), "rotation": 0.0},
		{"position": Vector3(-555.0, 3.2, 18.0), "rotation": 0.0},
		{"position": Vector3(-752.0, 1.2, -20.0), "rotation": PI * 0.5},
		{"position": Vector3(-1052.0, 1.2, 25.0), "rotation": PI * 0.5},
	]


func _configure_gameplay_interactions() -> void:
	# QuestDirector builds the runtime pickups/NPCs deferred. The caller fires
	# this once on the next process frame; assign cues by property, without
	# editing the quest scripts.
	for pickup_node in get_tree().get_nodes_in_group(&"quest_pickup"):
		var pickup := pickup_node as Interactable
		if pickup == null:
			continue
		var raw_kind: Variant = pickup.get(&"visual_kind")
		var kind := "shard" if raw_kind == null else str(raw_kind)
		pickup.interact_cue = &"world_azure_blade" if kind == "blade" else &"world_soul_shard"
		pickup.interact_volume_db = -3.0
		# Motes are children of the pickup, so collecting it also hides them.
		var motes := MOTE_SCENE.instantiate() as Node3D
		motes.name = "PickupMotes"
		pickup.add_child(motes)
		motes.position = Vector3(0, 0.35, 0)
		_beacons.append({
			"position": pickup.global_position,
			"cue": pickup.interact_cue,
			"radius": 6.0 if kind == "blade" else 4.0,
			"played": false,
			"node": pickup,
		})
	for npc_node in get_tree().get_nodes_in_group(&"quest_npc"):
		var talk := npc_node.get_node_or_null(^"Interactable") as Interactable
		if talk != null:
			talk.interact_cue = &"ui_confirm"
			talk.interact_volume_db = -6.0
	var campfire := get_parent().get_node_or_null(
		^"Gameplay/Runtime/CampfireInteractable"
	) as Interactable
	if campfire != null:
		campfire.interact_cue = &"world_campfire_rest"
		campfire.interact_volume_db = -4.0


func _poll_beacons() -> void:
	for beacon in _beacons:
		if bool(beacon["played"]):
			continue
		var node := beacon.get("node") as Node3D
		if node != null:
			if not is_instance_valid(node) or not node.visible:
				continue
			var enabled: Variant = node.get(&"enabled")
			if enabled != null and not bool(enabled):
				continue
		if player.global_position.distance_to(beacon["position"]) <= float(beacon["radius"]):
			beacon["played"] = true
			_play(beacon["cue"], beacon["position"], -4.0)


func _set_storm(active: bool) -> void:
	if _rain != null:
		_rain.visible = active
		for particle in _rain.find_children("*", "GPUParticles3D", true, false):
			(particle as GPUParticles3D).emitting = active
	if active:
		_play(&"world_storm_rumble", player.global_position + Vector3.UP * 18.0, -3.0)
		_lightning_wait = randf_range(2.0, 4.5)


func _flash_lightning() -> void:
	if _lightning == null:
		return
	var tween := create_tween()
	tween.tween_property(_lightning, "light_energy", 4.2, 0.04)
	tween.tween_property(_lightning, "light_energy", 0.2, 0.06)
	tween.tween_property(_lightning, "light_energy", 2.1, 0.05)
	tween.tween_property(_lightning, "light_energy", 0.0, 0.35)
	# Thunder lags the flash by 0.35-1.2 s; the exact delay is randomized.
	var delay := randf_range(0.35, 1.2)
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		_play(&"world_storm_rumble", player.global_position + Vector3.UP * 24.0, -2.0)
	)


func _poll_tide() -> void:
	if _tide == null or not is_instance_valid(_tide):
		return
	if not _tide.has_method(&"is_high_water"):
		return
	var high := bool(_tide.call(&"is_high_water"))
	var rising := bool(_tide.call(&"is_rising")) if _tide.has_method(&"is_rising") else false
	var until_high := float(_tide.call(&"seconds_until_high")) if _tide.has_method(&"seconds_until_high") else 999.0

	# Warn 12 seconds before the gates close; LabyrinthAudio owns the louder
	# surge when the water actually crosses the gate threshold.
	if rising and until_high > 0.0 and until_high <= 12.0 and not _tide_warned:
		_tide_warned = true
		_play(&"world_tide_warning", player.global_position + Vector3.UP * 2.0, -3.0)
	elif not rising and not high:
		_tide_warned = false

	if high and not _tide_sprayed:
		_tide_sprayed = true
		for spray in _sprays:
			var point: Vector3 = spray["position"]
			if player.global_position.distance_to(point) <= 100.0:
				VFX.spawn(
					"res://scenes/environment/vfx/tide_spray.tscn",
					point,
					float(spray["rotation"])
				)
	elif not high:
		_tide_sprayed = false


func _exit_tree() -> void:
	if _campfire_audio != null:
		_campfire_audio.stop()
