class_name PilgrimPath
extends SliceLocation
## S07–S12: разрушенная дорога, подъём, альков, смерть Шифти, Учёный,
## пещера, ранение и Silver Bell.
##
## Локация хранит флаги и одноразовые точки взаимодействия. Диалоги,
## камера, затемнение и переход в святилище принадлежат оболочке
## pilgrim_path_arrival. Ни один шаг здесь не подтверждает смерть Тирана.

signal hint_requested(text: String)
signal road_gap_seen
signal sword_discarded
signal rest_requested
signal scholar_requested
signal cave_requested
signal cave_escape_requested
signal stealth_started
signal stealth_completed
signal stealth_caught
signal hero_requested
signal bell_rung
signal temple_reached

const FLAG_STARTED := &"pilgrim_path_started"
const FLAG_GAP := &"road_gap_seen"
const FLAG_SWORD := &"sword_discarded"
const FLAG_ALCOVE := &"alcove_reached"
const FLAG_TYRANT_SIGHTING := &"tyrant_sighting_seen"
const FLAG_SHIFTY_DEAD := &"shifty_dead"
const FLAG_DAWN := &"dawn_ascent"
const FLAG_SCHOLAR := &"scholar_confronted"
const FLAG_SCHOLAR_GONE := &"scholar_abandoned"
const FLAG_CAVE := &"cave_entered"
const FLAG_CONFESSION := &"scholar_confession_seen"
const FLAG_WOUND := &"wound_taken"
const FLAG_CAVE_ESCAPED := &"cave_escaped"
const FLAG_STEALTH_DONE := &"stealth_completed"
const FLAG_STEALTH_ACTIVE := &"stealth_active"
const FLAG_STONE := &"stealth_stone_used"
const FLAG_HERO := &"hero_confrontation_seen"
const FLAG_HERO_TAKEN := &"hero_taken"
const FLAG_HERO_DEAD := &"hero_dead"
const FLAG_BELL := &"silver_bell_used"
const FLAG_TEMPLE := &"temple_reached"
## Mark of Divinity — атрибут B16 (не предмет). Невидимый страж пропускает только с ним.
const FLAG_MARK := &"mark_of_divinity"
## Текст-заглушка проекта, не канон: без Mark канон не описывает реакцию стража.
const GUARD_BLOCKED_HINT := "Путь к храму закрыт."
## Звук святилища (docs/ASSET_LICENSES.md, раздел «Звук святилища»).
## Ветер — фоновый слой площадки без позиции. Скрип — без позиции: канон A02 «непонятно откуда».
const WIND_LOOP := preload("res://assets/audio/sanctuary/wind_whoosh_loop.ogg")
const GUARD_PRESENCE := preload("res://assets/audio/sanctuary/guard_presence_ambience_1.wav")
const THRESHOLD_CREAK := preload("res://assets/audio/sanctuary/stone_door_large_001.ogg")
## Рассеянные кости у ступеней: один MultiMesh вместо тысяч узлов (канон: «тысячи костей»).
const BONE_COUNT := 420
const BONE_SEED := 20261026

const PHASE_ROAD := &"ROAD"
const PHASE_ASCENT := &"ASCENT"
const PHASE_ALCOVE := &"ALCOVE"
const PHASE_DAWN := &"DAWN"
const PHASE_SCHOLAR := &"SCHOLAR"
const PHASE_CAVE := &"CAVE"
const PHASE_HERO := &"HERO"
const PHASE_TEMPLE := &"TEMPLE"
const PHASE_COMPLETE := &"COMPLETE"

## Герой стоит спиной к храму и лицом к Санни; на звонок он разворачивается
## к источнику звука. Значение задаётся один раз, чтобы постановка не зависела
## от случайного угла после предыдущих состояний сцены.
const HERO_BELL_FACING_Y := 0.0
## Признаки ослабления Шифти в алькове: наклон вперёд (~14°) и сгорбленная поза
## (высота 88%). Меш Шифти примитивный, анимаций у него нет, поэтому только transform.
const SHIFTY_WEAK_LEAN := 0.24
const SHIFTY_WEAK_CROUCH := 0.88
const LARVA_ENEMY_SCENE := preload("res://scenes/enemies/larva_enemy.tscn")

var phase: StringName = PHASE_ROAD
var _shifty_base_scale := Vector3.ONE
var _wind_player: AudioStreamPlayer
var _guard_player: AudioStreamPlayer3D
var _creak_player: AudioStreamPlayer
var _guard_sound_plays := 0
var _creak_plays := 0
var _bone_origins: Array[Vector3] = []
var _guide_beacons: Dictionary = {}
var _active_beat_shot: StringName = &""
var _beat_serial := 0
var _shifty_falling := false

@onready var hero: Mannequin = $NPCs/Hero
@onready var shifty: Mannequin = $NPCs/Shifty
@onready var scholar: Mannequin = $NPCs/Scholar
@onready var shifty_body: Node3D = $NPCs/ShiftyBody
@onready var blood_stain: Node3D = $Props/BloodStain
@onready var tyrant_sighting: Node3D = $NPCs/TyrantSighting
@onready var tyrant_at_hero: Node3D = $NPCs/TyrantAtHero
@onready var stealth: StealthSection = $StealthSection
@onready var sword_prop: Node3D = $Props/Sword
@onready var dawn_light: DirectionalLight3D = $Environment/DawnLight
@onready var temple_glow: Node3D = $Props/TempleGlow
## Искажение воздуха у входа: невидимый страж не показывается полностью (E6.3, S12).
@onready var temple_guard: Node3D = $Props/TempleGuard


func _ready() -> void:
	super._ready()
	interacted.connect(_on_interacted)
	triggered.connect(_on_triggered)
	_shifty_falling = false
	_shifty_base_scale = shifty.scale
	_scatter_bones()
	_setup_audio()
	_cache_guide_beacons()
	if stealth != null:
		stealth.stealth_completed.connect(_on_stealth_completed)
		stealth.tyrant_caught.connect(_on_stealth_caught)
	prepare_route()


func _cache_guide_beacons() -> void:
	_guide_beacons.clear()
	var root := get_node_or_null(^"GuideBeacons")
	if root == null:
		return
	for child in root.get_children():
		var beacon := child as GuideBeacon
		if beacon != null and beacon.beacon_id != &"":
			_guide_beacons[beacon.beacon_id] = beacon


## Включает маяк только текущей цели. Остальные гаснут: в мире не остаётся
## хвоста из старых подсказок.
func apply_guide_beat(beat: BeatData) -> void:
	var active_id := beat.guide_beacon_id if beat != null else &""
	for beacon_id in _guide_beacons:
		var beacon := _guide_beacons[beacon_id] as GuideBeacon
		beacon.set_enabled(beacon_id == active_id)


func get_guide_beacon(beacon_id: StringName) -> GuideBeacon:
	return _guide_beacons.get(StringName(beacon_id), null) as GuideBeacon


## Вызывается один раз при входе. Восстанавливает состояние после отладки,
## но не выдаёт награды и не подтверждает смерть Тирана.
func prepare_route() -> void:
	NightmareRunState.set_flag(FLAG_STARTED)
	_release_beat_shot(0.0)
	_shifty_falling = false
	_reconcile_capture_state()
	if NightmareRunState.has_flag(FLAG_TEMPLE):
		phase = PHASE_COMPLETE
	elif NightmareRunState.has_flag(FLAG_HERO_TAKEN):
		phase = PHASE_TEMPLE
	elif NightmareRunState.has_flag(FLAG_HERO):
		phase = PHASE_HERO
	elif NightmareRunState.has_flag(FLAG_CAVE_ESCAPED) and NightmareRunState.has_flag(FLAG_STEALTH_DONE):
		phase = PHASE_HERO
	elif NightmareRunState.has_flag(FLAG_CAVE_ESCAPED):
		phase = PHASE_HERO
	elif NightmareRunState.has_flag(FLAG_WOUND):
		phase = PHASE_CAVE
	elif NightmareRunState.has_flag(FLAG_CAVE):
		phase = PHASE_CAVE
	elif NightmareRunState.has_flag(FLAG_SCHOLAR_GONE):
		phase = PHASE_CAVE
	elif NightmareRunState.has_flag(FLAG_SCHOLAR):
		phase = PHASE_SCHOLAR
	elif NightmareRunState.has_flag(FLAG_ALCOVE):
		phase = PHASE_ALCOVE
	_restore_visuals()
	_restore_party_positions()
	_update_shifty_pose()
	_refresh_route_points()


## Возвращение в сцену не может оставить её в середине захвата: если Герой уже
## взят, значит звонок состоялся и захват нужно считать завершённым. Иначе
## загрузка показала бы Тирана/свечение в состоянии, которого уже нет.
func _reconcile_capture_state() -> void:
	if NightmareRunState.has_flag(FLAG_HERO_DEAD):
		NightmareRunState.set_flag(FLAG_HERO_TAKEN)
	if NightmareRunState.has_flag(FLAG_HERO_TAKEN):
		NightmareRunState.set_flag(FLAG_BELL)
		NightmareRunState.set_flag(FLAG_HERO)
		NightmareRunState.set_flag(FLAG_HERO_DEAD)


func _restore_visuals() -> void:
	var gone := NightmareRunState.has_flag(FLAG_SHIFTY_DEAD)
	var scholar_gone := NightmareRunState.has_flag(FLAG_SCHOLAR_GONE) or NightmareRunState.has_flag(FLAG_HERO_DEAD)
	var hero_gone := NightmareRunState.has_flag(FLAG_HERO_TAKEN) or NightmareRunState.has_flag(FLAG_HERO_DEAD)
	var capture_done := NightmareRunState.has_flag(FLAG_HERO_DEAD)
	shifty.visible = not gone
	# Тело Шифти исчезает: на камне остаётся только кровь.
	shifty_body.visible = false
	blood_stain.visible = gone
	scholar.visible = not scholar_gone
	hero.visible = not hero_gone
	tyrant_sighting.visible = false
	tyrant_at_hero.visible = false
	_set_temple_glow_visible(capture_done)
	temple_guard.visible = capture_done and not NightmareRunState.has_flag(FLAG_TEMPLE)
	sword_prop.visible = not NightmareRunState.has_flag(FLAG_SWORD)
	dawn_light.visible = NightmareRunState.has_flag(FLAG_DAWN)
	dawn_light.light_energy = 0.8 if dawn_light.visible else 0.0


## Скрытый храм не должен оставлять активную коллизию: иначе игрок стоит
## на «призрачном полу» скрытых ступеней. Видимая снежная площадка имеет
## собственную коллизию (Art/PlateauCollision), а ступени включаются вместе
## с моделью храма.
func _set_temple_glow_visible(value: bool) -> void:
	temple_glow.visible = value
	for node in temple_glow.find_children("*", "CollisionShape3D", true, false):
		var shape := node as CollisionShape3D
		if shape != null:
			shape.disabled = not value


func _restore_party_positions() -> void:
	if NightmareRunState.has_flag(FLAG_ALCOVE):
		hero.position = Vector3(1.55, 4.1, -31.6)
		shifty.position = Vector3(0.95, 4.1, -31.0)
		scholar.position = Vector3(1.2, 4.1, -32.8)
	elif not NightmareRunState.has_flag(FLAG_STARTED):
		hero.position = Vector3(0.8, 0.05, 6.5)
		shifty.position = Vector3(1.5, 0.05, 7.4)
		scholar.position = Vector3(-0.5, 0.05, 6.8)
	if NightmareRunState.has_flag(FLAG_DAWN):
		scholar.position = ($Spawns/ScholarAhead as Node3D).position
	if NightmareRunState.has_flag(FLAG_HERO_TAKEN) or NightmareRunState.has_flag(FLAG_HERO_DEAD):
		hero.visible = false


func _refresh_route_points() -> void:
	var gap := NightmareRunState.has_flag(FLAG_GAP)
	var sword := NightmareRunState.has_flag(FLAG_SWORD)
	var alcove := NightmareRunState.has_flag(FLAG_ALCOVE)
	var shifty_dead := NightmareRunState.has_flag(FLAG_SHIFTY_DEAD)
	var larva_dead := NightmareRunState.has_flag(&"shifty_larva_killed")
	var scholar_seen := NightmareRunState.has_flag(FLAG_SCHOLAR)
	var scholar_gone := NightmareRunState.has_flag(FLAG_SCHOLAR_GONE)
	var cave := NightmareRunState.has_flag(FLAG_CAVE)
	var wound := NightmareRunState.has_flag(FLAG_WOUND)
	var escaped := NightmareRunState.has_flag(FLAG_CAVE_ESCAPED)
	var stealth_done := NightmareRunState.has_flag(FLAG_STEALTH_DONE)
	var stealth_active := NightmareRunState.has_flag(FLAG_STEALTH_ACTIVE)
	var stone_used := NightmareRunState.has_flag(FLAG_STONE)
	var hero_seen := NightmareRunState.has_flag(FLAG_HERO)
	var capture_done := NightmareRunState.has_flag(FLAG_HERO_DEAD)
	var bell := NightmareRunState.has_flag(FLAG_BELL)
	var temple := NightmareRunState.has_flag(FLAG_TEMPLE)
	# E остаётся только у поступков. Дорога, отдых, Учёный, пещера и Герой —
	# зоны прохода: игрок входит в них, а сцену играет постановка.
	set_trigger_enabled(&"road_gap", not gap)
	set_trigger_enabled(&"sword", gap and not sword)
	set_trigger_enabled(&"rest", sword and not alcove)
	set_trigger_enabled(&"scholar", shifty_dead and larva_dead and not scholar_seen)
	# Вход остаётся активным, чтобы игрок получил объяснение, если Учёный ещё
	# не ушёл, а не упирался в молчаливую стену.
	set_trigger_enabled(&"cave", not cave)
	set_trigger_enabled(&"cave_exit", cave and wound and not escaped)
	# N21: проход к Герою открывается только после стелса. Иначе игрок
	# проскочил бы участок и сцену N22 без проверки слуха и тени.
	set_trigger_enabled(&"hero", escaped and stealth_done and not hero_seen)
	set_interactable_enabled(&"bell", hero_seen and not bell)
	set_interactable_enabled(&"stone", stealth_active and not stone_used)
	var stone := get_node_or_null("Interactables/Stone") as Node3D
	if stone != null:
		stone.visible = stealth_active and not stone_used
	# Проход к храму открывается только после завершения захвата, а не в
	# момент появления Тирана: иначе игрок мог бы уйти вперёд во время сцены.
	set_trigger_enabled(&"temple", capture_done and not temple)
	# После ухода Учёного вход в пещеру должен быть виден, даже если beat
	# director ещё не переключил guide_beacon_id.
	if scholar_gone and not cave:
		var cave_beacon := get_guide_beacon(&"cave")
		if cave_beacon != null:
			cave_beacon.set_enabled(true)
	_update_objective()


## Цель всегда отражает текущий участок подъёма. Без этого после лагеря
## оставалась цель «подойти к ветерану» на всю оставшуюся сцену.
func _update_objective() -> void:
	var text := ""
	if phase == PHASE_ROAD:
		text = "Пройти по дороге к перевалу."
	elif phase == PHASE_ASCENT:
		text = "Подняться по карнизу к Учёному."
	elif phase == PHASE_ALCOVE:
		text = "Обыскать альков у костра."
	elif phase == PHASE_DAWN:
		text = "Идти за Шифти к пещере."
	elif phase == PHASE_SCHOLAR:
		text = "Поговорить с Учёным у входа в пещеру."
	elif phase == PHASE_CAVE:
		text = "Войти в пещеру и перевязать рану."
	elif phase == PHASE_HERO:
		text = "Пробраться мимо Тирана к Герою."
	elif phase == PHASE_TEMPLE:
		text = "Войти в храм."
	elif phase == PHASE_COMPLETE:
		text = "Испытание завершено."
	_set_campaign_objective(text)


func _set_campaign_objective(text: String) -> void:
	var guide := get_node_or_null(^"/root/CampaignGuide")
	if guide == null:
		return
	if text.is_empty():
		if guide.has_method(&"clear_external_objective"):
			guide.call(&"clear_external_objective", &"campaign")
		return
	if guide.has_method(&"set_external_objective"):
		guide.call(&"set_external_objective", text, &"campaign")


## --- Постановка ключевых beat-ов: позы и камера ---------------------------

func _beat_stage() -> BeatShotStage:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null(^"BeatStage") as BeatShotStage


func _is_fast_mode() -> bool:
	var parent := get_parent()
	if parent == null:
		return false
	var value: Variant = parent.get(&"fast_mode")
	return value != null and bool(value)


func _play_beat_shot(shot_id: StringName, blend := 0.45) -> void:
	var stage := _beat_stage()
	if stage == null:
		return
	_beat_serial += 1
	_active_beat_shot = shot_id
	await stage.play_shot(shot_id, blend)


func _release_beat_shot(delay := 0.0, shot_id: StringName = &"") -> void:
	var stage := _beat_stage()
	if stage == null:
		return
	_beat_serial += 1
	var serial := _beat_serial
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if serial != _beat_serial:
		return
	if shot_id != &"" and _active_beat_shot != shot_id:
		return
	_active_beat_shot = &""
	await stage.release()


func _player_position() -> Vector3:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player != null:
		return player.global_position
	return global_position


func _pose_actor(actor: Node, pose_name: String, focus: Vector3) -> void:
	var mannequin := actor as Mannequin
	if mannequin == null:
		return
	mannequin.pose = pose_name
	mannequin.face_position(focus)


## N16–N17: слабый Шифти срывается с карниза; Герой указывает на край,
## Учёный читает записи. Камера держит падение, а не только реплику.
func stage_shifty_fall() -> void:
	if _shifty_falling:
		return
	_shifty_falling = true
	var focus := shifty_body.global_position if is_instance_valid(shifty_body) else _player_position()
	_pose_actor(shifty, "fall", focus)
	_pose_actor(hero, "point", shifty.global_position if is_instance_valid(shifty) else focus)
	_pose_actor(scholar, "read", _player_position())
	_play_beat_shot(&"ShiftyFall", 0.4)
	_release_beat_shot(2.4, &"ShiftyFall")


## N20: рана в пещере. Герой оседает на колено, Санни остаётся один.
func stage_cave_wound() -> void:
	var inside := get_spawn(&"CaveInside") as Node3D
	var focus := inside.global_position if inside != null else _player_position()
	if is_instance_valid(hero):
		if inside != null:
			hero.global_position = inside.global_position + Vector3(1.2, 0.0, 0.4)
		_pose_actor(hero, "kneel", _player_position())
	_play_beat_shot(&"CaveWound", 0.45)
	_release_beat_shot(3.2, &"CaveWound")


## N21–N22: Герой ждёт на карнизе и указывает на Санни.
func stage_hero_confrontation() -> void:
	if is_instance_valid(hero):
		var stand := get_spawn(&"HeroStand") as Node3D
		if stand != null:
			hero.global_position = stand.global_position
		hero.visible = true
		_pose_actor(hero, "point", _player_position())
	_play_beat_shot(&"HeroConfront", 0.4)
	_release_beat_shot(9.0, &"HeroConfront")


## N22: захват. Тиран появляется над Героем; рука идёт вниз, камера
## фиксирует момент, когда Герой исчезает из кадра.
func stage_hero_capture() -> void:
	if is_instance_valid(hero):
		_pose_actor(hero, "fall", tyrant_at_hero.global_position)
		var start := hero.global_position
		var lift := start + Vector3(-0.4, 0.75, -0.25)
		var lift_tween := create_tween()
		lift_tween.tween_property(hero, "global_position", lift, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tyrant_at_hero.visible = true
	_animate_tyrant_grab()
	_play_beat_shot(&"HeroCapture", 0.35)
	_release_beat_shot(4.5, &"HeroCapture")


func _animate_tyrant_grab() -> void:
	var arm := tyrant_at_hero.get_node_or_null(^"Arm") as Node3D
	if arm == null:
		return
	var start := arm.position
	var strike := start + Vector3(0.8, -1.0, 0.4)
	var tween := create_tween()
	tween.tween_property(arm, "position", strike, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(arm, "position", start, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)



func _on_interacted(id: StringName) -> void:
	if id == &"bell":
		_ring_bell()
	elif id == &"stone":
		throw_stealth_stone()


func _on_triggered(id: StringName) -> void:
	match id:
		&"road_gap":
			_see_road_gap()
		&"sword":
			_discard_sword()
		&"rest":
			_request_rest()
		&"scholar":
			_request_scholar()
		&"cave":
			_enter_cave()
		&"cave_exit":
			_escape_cave()
		&"hero":
			_request_hero()
		&"temple":
			if not _enter_temple() and not NightmareRunState.has_flag(FLAG_TEMPLE):
				# TriggerZone одноразовый: закрытый страж не должен сжечь вход навсегда.
				set_trigger_enabled(&"temple", true)


## Вход в храм через невидимого стража (S12, 03_ascent_and_climax_canon.md E6.3).
## Страж чувствует Mark of Divinity и пропускает; без Mark вход закрыт. Боя нет.
func _enter_temple() -> bool:
	if NightmareRunState.has_flag(FLAG_TEMPLE):
		return false
	if not NightmareRunState.has_flag(FLAG_MARK):
		hint_requested.emit(GUARD_BLOCKED_HINT)
		return false
	NightmareRunState.set_flag(FLAG_TEMPLE)
	phase = PHASE_COMPLETE
	# Страж чувствует Mark of Divinity и отступает (E6.3): искажение у входа гаснет.
	temple_guard.visible = false
	_play_threshold_creak()
	_refresh_route_points()
	temple_reached.emit()
	return true


## Тихий каменный скрип при пересечении порога (beats_shrine_climax.md, A02). Один раз: вход проходится один раз.
func _play_threshold_creak() -> void:
	if _creak_plays > 0 or _creak_player == null:
		return
	_creak_plays += 1
	if AudioLibrary.playback_enabled():
		_creak_player.play()


func _see_road_gap() -> void:
	if NightmareRunState.has_flag(FLAG_GAP):
		return
	NightmareRunState.set_flag(FLAG_GAP)
	phase = PHASE_ASCENT
	_refresh_route_points()
	road_gap_seen.emit()


func _discard_sword() -> void:
	if not NightmareRunState.has_flag(FLAG_GAP) or NightmareRunState.has_flag(FLAG_SWORD):
		return
	NightmareRunState.set_flag(FLAG_SWORD)
	NightmareRunState.remove_item(&"sword", NightmareRunState.get_item_count(&"sword"))
	sword_prop.visible = false
	_refresh_route_points()
	sword_discarded.emit()


func _request_rest() -> void:
	if not NightmareRunState.has_flag(FLAG_SWORD) or NightmareRunState.has_flag(FLAG_ALCOVE):
		return
	NightmareRunState.set_flag(FLAG_ALCOVE)
	phase = PHASE_ALCOVE
	_restore_party_positions()
	place_party_at_alcove()
	_update_shifty_pose()
	_play_beat_shot(&"ShiftyFall", 0.5)
	_refresh_route_points()
	rest_requested.emit()
	hint_requested.emit("")


func show_tyrant_sighting() -> void:
	NightmareRunState.set_flag(FLAG_TYRANT_SIGHTING)
	tyrant_sighting.visible = true


func kill_shifty() -> void:
	if NightmareRunState.has_flag(FLAG_SHIFTY_DEAD):
		return
	NightmareRunState.set_flag(FLAG_SHIFTY_DEAD)
	stage_shifty_fall()
	if not _is_fast_mode():
		await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(shifty):
		return
	shifty.visible = false
	shifty_body.visible = false
	blood_stain.visible = true
	_update_shifty_pose()
	_refresh_route_points()


## N18: личинка, поднявшаяся из тела Шифти. Спавнится у края карниза,
## после смерти ставит отдельный флаг и открывает N19.
func spawn_shifty_larva(target: Node3D) -> TestEnemy:
	var existing := get_node_or_null(^"ShiftyLarva") as TestEnemy
	if existing != null:
		return existing
	var enemy := LARVA_ENEMY_SCENE.instantiate() as TestEnemy
	if enemy == null:
		return null
	enemy.name = "ShiftyLarva"
	enemy.target = target
	add_child(enemy)
	enemy.global_position = Vector3(2.4, 4.15, -33.8)
	# В тёмной сцене личинку легко потерять: даём читаемый маркер и красный
	# подсвет, пока она жива. Это не второй AI, только визуальная навигация.
	var marker := Label3D.new()
	marker.name = "CombatMarker"
	marker.text = "ЛИЧИНКА ШИФТИ"
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.font_size = 48
	marker.pixel_size = 0.01
	marker.modulate = Color(1.0, 0.38, 0.22, 1.0)
	marker.position = Vector3(0.0, 2.2, 0.0)
	enemy.add_child(marker)
	var glow := OmniLight3D.new()
	glow.name = "CombatGlow"
	glow.light_color = Color(1.0, 0.35, 0.2, 1.0)
	glow.light_energy = 1.6
	glow.omni_range = 5.0
	glow.position = Vector3(0.0, 1.2, 0.0)
	enemy.add_child(glow)
	if enemy.health != null:
		enemy.health.died.connect(marker.hide)
		enemy.health.died.connect(glow.hide)
	return enemy


## Поза Шифти зависит только от сохранённого состояния: отравление, альков и
## то, что он ещё жив. После смерти поза не важна, тело скрыто в _restore_visuals.
## Повторная подготовка сцены даёт ту же позу, без отдельного события.
func _update_shifty_pose() -> void:
	var weak := (
		NightmareRunState.has_flag(&"flasks_poisoned")
		and NightmareRunState.has_flag(FLAG_ALCOVE)
		and not NightmareRunState.has_flag(FLAG_SHIFTY_DEAD)
	)
	shifty.rotation.x = SHIFTY_WEAK_LEAN if weak else 0.0
	var crouch := SHIFTY_WEAK_CROUCH if weak else 1.0
	shifty.scale = Vector3(_shifty_base_scale.x, _shifty_base_scale.y * crouch, _shifty_base_scale.z)


func is_shifty_weakened() -> bool:
	return shifty.rotation.x > 0.0


func begin_dawn() -> void:
	NightmareRunState.set_flag(FLAG_DAWN)
	phase = PHASE_DAWN
	dawn_light.visible = true
	dawn_light.light_energy = 0.85
	scholar.position = ($Spawns/ScholarAhead as Node3D).position
	_pose_actor(scholar, "read", _player_position())
	_refresh_route_points()


func _request_scholar() -> void:
	if not NightmareRunState.has_flag(FLAG_SHIFTY_DEAD) or NightmareRunState.has_flag(FLAG_SCHOLAR):
		return
	NightmareRunState.set_flag(FLAG_SCHOLAR)
	phase = PHASE_SCHOLAR
	_pose_actor(scholar, "read", _player_position())
	_refresh_route_points()
	scholar_requested.emit()
	hint_requested.emit("")


func abandon_scholar() -> void:
	NightmareRunState.set_flag(FLAG_SCHOLAR_GONE)
	scholar.visible = false
	_refresh_route_points()


func _enter_cave() -> void:
	if NightmareRunState.has_flag(FLAG_CAVE):
		return
	if not NightmareRunState.has_flag(FLAG_SCHOLAR_GONE):
		hint_requested.emit("Сначала поговорите с Учёным у входа.")
		return
	NightmareRunState.set_flag(FLAG_CAVE)
	phase = PHASE_CAVE
	_refresh_route_points()
	cave_requested.emit()
	hint_requested.emit("")


func mark_confession() -> void:
	NightmareRunState.set_flag(FLAG_CONFESSION)


func wound_sunny() -> void:
	NightmareRunState.set_flag(FLAG_WOUND)
	stage_cave_wound()
	_refresh_route_points()


func _escape_cave() -> void:
	if not NightmareRunState.has_flag(FLAG_WOUND) or NightmareRunState.has_flag(FLAG_CAVE_ESCAPED):
		return
	NightmareRunState.set_flag(FLAG_CAVE_ESCAPED)
	phase = PHASE_HERO
	_refresh_route_points()
	cave_escape_requested.emit()
	hint_requested.emit("")


## N21: запуск стелс-участка после выхода из пещеры. Игрок остаётся
## управляемым; сцена только включает слух Тирана, взгляд Героя и тени.
func begin_stealth(player: Node3D) -> bool:
	if not NightmareRunState.has_flag(FLAG_CAVE_ESCAPED):
		return false
	if NightmareRunState.has_flag(FLAG_STEALTH_DONE):
		return false
	if stealth == null:
		return false
	_release_beat_shot(0.0)
	NightmareRunState.set_flag(FLAG_STEALTH_ACTIVE)
	stealth.begin(player)
	_refresh_route_points()
	stealth_started.emit()
	return true


## N21: отвлечь Тирана камнем. Шум остаётся опасным, но источник можно
## сместить от Санни; это не отменяет правило, а использует его.
func throw_stealth_stone(origin: Vector3 = Vector3.INF) -> bool:
	if not NightmareRunState.has_flag(FLAG_STEALTH_ACTIVE):
		return false
	if NightmareRunState.has_flag(FLAG_STONE):
		return false
	if stealth == null:
		return false
	var stone := get_node_or_null("Interactables/Stone") as Node3D
	var point := origin
	if point == Vector3.INF:
		point = stone.global_position if stone != null else global_position
	NightmareRunState.set_flag(FLAG_STONE)
	stealth.emit_noise(&"rockfall", point, stone)
	if stone != null:
		stone.visible = false
	_refresh_route_points()
	return true


func reset_stealth() -> void:
	if stealth != null:
		stealth.reset()
	NightmareRunState.clear_flag(FLAG_STEALTH_ACTIVE)
	NightmareRunState.clear_flag(FLAG_STONE)
	_refresh_route_points()


func get_stealth() -> StealthSection:
	return stealth


func _on_stealth_completed() -> void:
	if NightmareRunState.has_flag(FLAG_STEALTH_DONE):
		return
	NightmareRunState.clear_flag(FLAG_STEALTH_ACTIVE)
	NightmareRunState.set_flag(FLAG_STEALTH_DONE)
	phase = PHASE_HERO
	_refresh_route_points()
	stealth_completed.emit()
	# Санни уже стоит в зоне Героя в момент завершения. TriggerZone не
	# пришлёт body_entered повторно, поэтому запускаем N22 явно.
	var hero_trigger := get_trigger(&"hero") as TriggerZone
	if hero_trigger != null and hero_trigger.enabled:
		hero_trigger.fire()


func _on_stealth_caught() -> void:
	NightmareRunState.clear_flag(FLAG_STEALTH_ACTIVE)
	_refresh_route_points()
	stealth_caught.emit()


func _request_hero() -> void:
	if not NightmareRunState.has_flag(FLAG_CAVE_ESCAPED):
		return
	if not NightmareRunState.has_flag(FLAG_STEALTH_DONE):
		return
	if NightmareRunState.has_flag(FLAG_HERO):
		return
	NightmareRunState.set_flag(FLAG_HERO)
	phase = PHASE_HERO
	stage_hero_confrontation()
	_refresh_route_points()
	hero_requested.emit()
	hint_requested.emit("")


func _ring_bell() -> void:
	if not NightmareRunState.has_flag(FLAG_HERO) or NightmareRunState.has_flag(FLAG_BELL):
		return
	# Колокольчик расходуется как действие, но остаётся Памятью в инвентаре.
	# Захват начинается позже, на соответствующей реплике оболочки.
	NightmareRunState.set_flag(FLAG_BELL)
	# Звон — громкое событие, но исключение из правила: Тиран идёт к Герою.
	if stealth != null:
		var bell_node := get_node_or_null("Interactables/Bell") as Node3D
		var bell_position := bell_node.global_position if bell_node != null else global_position
		stealth.emit_bell_rescue(bell_position, hero)
		var director := get_node_or_null(^"/root/AudioDirector")
		if director != null and director.has_method(&"play_sfx"):
			director.call(&"play_sfx", &"world_silver_bell", bell_position, -2.0)
	_refresh_route_points()
	bell_rung.emit()


## Реплика «Герой оборачивается»: до этого момента Герой остаётся на месте.
func turn_hero_toward_bell() -> void:
	if not hero.visible or NightmareRunState.has_flag(FLAG_HERO_TAKEN):
		return
	hero.pose = "guard"
	hero.rotation.y = HERO_BELL_FACING_Y


## Реплика «Тиран уже рядом»: начало захвата. Герой исчезает, Тиран
## появляется, но hero_dead ещё не устанавливается — захват продолжается.
func begin_hero_capture() -> void:
	if not NightmareRunState.has_flag(FLAG_BELL):
		return
	if NightmareRunState.has_flag(FLAG_HERO_DEAD):
		return
	NightmareRunState.set_flag(FLAG_HERO_TAKEN)
	stage_hero_capture()
	tyrant_at_hero.visible = true
	_set_temple_glow_visible(false)
	if not _is_fast_mode():
		await get_tree().create_timer(0.55).timeout
	if not is_instance_valid(hero):
		return
	hero.visible = false
	_refresh_route_points()


## Завершение захвата: Герой погиб, Тиран уходит, храм подсвечивается.
## Вызывается на последней реплике захвата или как страховка после диалога.
func complete_hero_capture() -> void:
	if not NightmareRunState.has_flag(FLAG_BELL):
		return
	NightmareRunState.set_flag(FLAG_HERO_TAKEN)
	NightmareRunState.set_flag(FLAG_HERO_DEAD)
	hero.visible = false
	tyrant_at_hero.visible = false
	_set_temple_glow_visible(true)
	# Живой захват должен показывать стража у входа, а не только после перезагрузки (B3.1).
	temple_guard.visible = not NightmareRunState.has_flag(FLAG_TEMPLE)
	_play_guard_presence()
	phase = PHASE_TEMPLE
	_release_beat_shot(1.6, &"HeroCapture")
	_refresh_route_points()


## Звук присутствия стража: проигрывается один раз, в момент захвата (событие), не при загрузке.
func _play_guard_presence() -> void:
	if _guard_sound_plays > 0 or _guard_player == null:
		return
	_guard_sound_plays += 1
	if AudioLibrary.playback_enabled():
		_guard_player.play()


var _occlusion_poll := 0.0


func _process(delta: float) -> void:
	if _guard_player == null or not is_instance_valid(_guard_player):
		return
	_occlusion_poll = maxf(_occlusion_poll - delta, 0.0)
	if _occlusion_poll > 0.0:
		return
	_occlusion_poll = 0.4
	var director := get_node_or_null(^"/root/AudioDirector")
	if director != null and director.has_method(&"apply_3d_occlusion"):
		director.call(&"apply_3d_occlusion", _guard_player, _guard_player.global_position)


func _exit_tree() -> void:
	for player in [_wind_player, _guard_player, _creak_player]:
		if player != null and is_instance_valid(player):
			player.stop()
			player.stream = null


func _setup_audio() -> void:
	# Дубликат, а не изменение общего ресурса: зацикливание задаётся только для этого проигрывателя.
	var wind := WIND_LOOP.duplicate() as AudioStreamOggVorbis
	wind.loop = true
	_wind_player = AudioStreamPlayer.new()
	_wind_player.name = "WindSource"
	_wind_player.bus = &"Ambience"
	_wind_player.stream = wind
	_wind_player.volume_db = -12.0
	add_child(_wind_player)
	_wind_player.play()
	_guard_player = AudioStreamPlayer3D.new()
	_guard_player.bus = &"Ambience"
	_guard_player.stream = GUARD_PRESENCE
	_guard_player.volume_db = -12.0
	_guard_player.max_distance = 14.0
	temple_guard.add_child(_guard_player)
	_creak_player = AudioStreamPlayer.new()
	_creak_player.name = "ThresholdCreak"
	_creak_player.bus = &"SFX"
	_creak_player.stream = THRESHOLD_CREAK
	_creak_player.volume_db = -6.0
	add_child(_creak_player)


## Рассеивает кости вдоль боков ступеней. Позиции детерминированы (seed), коллизий нет.
func _scatter_bones() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.07
	mesh.bottom_radius = 0.07
	mesh.height = 0.55
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.66, 0.63, 0.55)
	material.roughness = 0.85
	mesh.material = material
	var field := MultiMesh.new()
	field.transform_format = MultiMesh.TRANSFORM_3D
	field.mesh = mesh
	field.instance_count = BONE_COUNT
	var rng := RandomNumberGenerator.new()
	rng.seed = BONE_SEED
	for index in BONE_COUNT:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var offset := side * rng.randf_range(2.1, 2.9)
		var place := Vector3(1.0 + offset, 4.1 + rng.randf_range(0.0, 0.03), rng.randf_range(-72.8, -66.4))
		var turn := Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.0, TAU), PI / 2.0 + rng.randf_range(-0.25, 0.25))
		field.set_instance_transform(index, Transform3D(Basis.from_euler(turn), place))
		# Позиции хранятся отдельно: в headless (dummy-рендерер) MultiMesh не сохраняет transform, get_instance_transform даёт нули.
		# Проверено пробой: в оконном режиме чтение совпадает с записью.
		_bone_origins.append(place)
	var instance := MultiMeshInstance3D.new()
	instance.name = "BoneField"
	instance.multimesh = field
	$Props/Bones.add_child(instance)


func reach_temple() -> void:
	_enter_temple()


func place_party_at_alcove() -> void:
	hero.global_position = Vector3(1.55, 4.15, -31.6)
	shifty.global_position = Vector3(0.95, 4.15, -31.0)
	scholar.global_position = Vector3(1.2, 4.15, -32.8)
	var focus := _player_position()
	_pose_actor(hero, "guard", focus)
	_pose_actor(shifty, "idle", focus)
	_pose_actor(scholar, "read", focus)


func get_party_position() -> Vector3:
	return hero.global_position
