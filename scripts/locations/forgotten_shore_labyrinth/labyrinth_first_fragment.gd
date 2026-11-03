extends LabyrinthGreybox
## Первый greybox-фрагмент Лабиринта Забытого берега (B03–B05).
##
## Пространственная схема: docs/design/level_brief_labyrinth_first_fragment.md
## Это не финальный арт. Задача сцены — проверить масштаб, маршруты, высоты,
## коллизии и прилив, а также дать Claude чистую структуру для замены
## Generated/Visual/<Zone> финальными моделями.
##
## Все размеры — предложения blockout, не канонические измерения.

const Z01 := &"Z01_Threshold"
const Z02 := &"Z02_Carcass"
const Z03 := &"Z03_FirstFork"
const Z04 := &"Z04_MudHollow"
const Z05 := &"Z05_BonePassage"
const Z06 := &"Z06_DryPocket"
const Z07 := &"Z07_ScoutRidge"
const Z08 := &"Z08_Clearing"
const Z09 := &"Z09_BlindTunnel"
const Z10 := &"Z10_CoralHill"
const Z11 := &"Z11_TideChannel"
const Z12 := &"Z12_Isthmus"
const Z13 := &"Z13_HuntingGrounds"
const Z14 := &"Z14_BoneBridge"
const Z15 := &"Z15_HighRefuge"
const Z16 := &"Z16_PackTerritory"
const Z17 := &"Z17_StormRun"
const Z18 := &"Z18_Cliffs"
const STATUE_STAR_MATERIAL := preload("res://resources/locations/post_nightmare/materials/statue_star.tres")
const CAMP_NIGHT_FULL := preload("res://resources/dialogue/post_nightmare/b03_camp_night_full.tres")
const CAMP_NIGHT_SHORT := preload("res://resources/dialogue/post_nightmare/b03_camp_night_short.tres")

@export var audio_zone_set: LabyrinthAudioZoneSet
@export var enable_art := true
## Тестовый и арт-проход может отключить игровой слой, не трогая геометрию.
@export var enable_demo_gameplay := true

var art: LabyrinthArt


func _ready() -> void:
	# Если сцена запущена напрямую (без LevelPortal), ставим игрока лицом
	# на запад по Spawns/Start. При переходе из tide_descent ориентацию
	# задаёт pending spawn, и этот код не вмешивается.
	var had_pending := not LevelPortal.peek_pending_spawn(scene_file_path).is_empty()
	super._ready()
	if enable_art:
		art = LabyrinthArt.new()
		art.name = "ArtFinal"
		add_child(art)
		art.setup(self)
		layout_built.connect(art.rebuild)
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var audio := LabyrinthAudio.new()
	audio.name = "LabyrinthAudio"
	audio.zone_set = audio_zone_set
	add_child(audio)
	audio.setup(
		player,
		get_node_or_null(^"Tide/TideController")
	)
	var atmosphere := LabyrinthAtmosphere.new()
	atmosphere.name = "LabyrinthAtmosphere"
	atmosphere.audio = audio
	atmosphere.player = player
	add_child(atmosphere)
	_setup_demo_gameplay(player as SunnyController)
	_connect_camp_night()
	if not had_pending:
		call_deferred(&"_apply_start_orientation")


func _connect_camp_night() -> void:
	if NightmareRunState.has_flag(&"camp_night_seen"):
		return
	var camp_night := get_node_or_null(^"Gameplay/Triggers/CampNight") as QuestTriggerZone
	if camp_night != null and not camp_night.triggered.is_connected(_on_camp_night_triggered):
		camp_night.triggered.connect(_on_camp_night_triggered)


func _on_camp_night_triggered(_id: StringName) -> void:
	var hud := get_node_or_null(^"GameplayHud")
	var runner := hud.get_node_or_null(^"DialogueRunner") as DialogueRunner if hud != null else null
	if runner == null:
		return
	var sequence := CAMP_NIGHT_FULL if NightmareRunState.has_flag(&"cassia_met") else CAMP_NIGHT_SHORT
	runner.run(sequence)


func _setup_demo_gameplay(player: SunnyController) -> void:
	if player == null:
		return
	player.combat_enabled = enable_demo_gameplay
	if not enable_demo_gameplay:
		return
	player.allow_sprint = true
	player.allow_jump = true
	var recovery := player.get_node_or_null(^"FallRecovery") as FallRecovery
	if recovery == null:
		return
	recovery.recover_on_death = true
	if not NightmareRunState.has_checkpoint():
		NightmareRunState.set_checkpoint(&"CP-SHORE-START", player.global_position, true)
		recovery.set_named_checkpoint(&"CP-SHORE-START", player.global_position)
	elif NightmareRunState.has_checkpoint_position():
		recovery.set_named_checkpoint(
			NightmareRunState.get_checkpoint_id(),
			NightmareRunState.get_checkpoint_position()
		)


func _apply_start_orientation() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as SunnyController
	var start := get_spawn(&"Start")
	if player != null and start != null:
		player.apply_spawn_orientation(start.global_rotation.y)


func build_layout() -> void:
	_clear_all_landmarks()
	_build_z01_threshold()
	_build_z02_carcass()
	_build_z03_first_fork()
	_build_z04_mud_hollow()
	_build_z05_bone_passage()
	_build_z06_dry_pocket()
	_build_z07_scout_ridge()
	_build_z08_clearing()
	_build_z09_blind_tunnel()
	_build_z10_coral_hill()
	_build_z11_tide_channel()
	_build_z12_isthmus()
	_build_z13_hunting_grounds()
	_build_z14_bone_bridge()
	_build_z15_high_refuge()
	_build_z16_pack_territory()
	_build_z17_storm_run()
	_build_z18_cliffs()
	_build_boundaries()
	_build_landmarks()
	_build_collision_patches()
	_build_lights()
	_build_labels()
	_build_tide_gates()


# ---------------------------------------------------------------------------
# Z01. Порог статуи
# ---------------------------------------------------------------------------

func _build_z01_threshold() -> void:
	floor_zone(Z01, &"Z01_Floor", Vector2(28.5, 0), Vector2(33, 24), 0.0, &"mud")
	# Входной карниз на +6 и лестница вниз.
	box(Z01, &"Z01_EntryLedge", Vector3(41.5, 5.75, 0), Vector3(7, 0.5, 10), &"statue", 0.0, true)
	stairs_between(Z01, &"Z01_EntryStairs", Vector3(30, 0, 0), Vector3(38, 6, 0), 5.0, 0.25, &"statue")

	# Стены порога. Южный разрыв ведёт к туше, западный — к развилке.
	wall_segment(Z01, &"Z01_NorthWall", Vector2(12, -12), Vector2(45, -12), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z01, &"Z01_SouthWallA", Vector2(12, 12), Vector2(18, 12), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z01, &"Z01_SouthWallB", Vector2(26, 12), Vector2(45, 12), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z01, &"Z01_WestWallA", Vector2(12, -12), Vector2(12, -4), 0.0, 8.0, 2.0, &"coral")
	wall_segment(Z01, &"Z01_WestWallB", Vector2(12, 4), Vector2(12, 12), 0.0, 8.0, 2.0, &"coral")
	# Восточная стена — стопа статуи.
	coral_mass(Z01, &"Z01_StatueFoot", Vector3(55, 0, 0), Vector3(18, 18, 40), &"statue", 11)
	# Короткий спуск к туше.
	stairs_between(Z01, &"Z01_CarcassStairs", Vector3(22, -1.5, 15), Vector3(22, 0, 12), 6.0, 0.25, &"mud")

	# Кости и водоросли у входа.
	bone_line(Z01, &"Z01_Bones", Vector3(28, 0.15, -8), 3, 2.0, 7)
	zone_label(Z01, &"Z01_Label", Vector3(28, 10, 0), "Z01 - THRESHOLD", Color(0.75, 0.82, 0.9, 0.9), 28)


# ---------------------------------------------------------------------------
# Z02. Туша
# ---------------------------------------------------------------------------

func _build_z02_carcass() -> void:
	floor_zone(Z02, &"Z02_Floor", Vector2(19, 26.5), Vector2(22, 23), -1.5, &"mud")
	wall_segment(Z02, &"Z02_NorthWallA", Vector2(8, 15), Vector2(18, 15), -1.5, 10.0, 2.0, &"coral")
	wall_segment(Z02, &"Z02_NorthWallB", Vector2(26, 15), Vector2(30, 15), -1.5, 10.0, 2.0, &"coral")
	wall_segment(Z02, &"Z02_WestWall", Vector2(8, 15), Vector2(8, 38), -1.5, 10.0, 2.0, &"coral")
	wall_segment(Z02, &"Z02_EastWall", Vector2(30, 15), Vector2(30, 38), -1.5, 10.0, 2.0, &"coral")
	wall_segment(Z02, &"Z02_SouthWall", Vector2(8, 38), Vector2(30, 38), -1.5, 10.0, 2.0, &"coral")

	# Полуобъеденная туша и рёбра.
	box(Z02, &"Z02_Carcass", Vector3(19, -0.75, 26), Vector3(14, 1.5, 4), &"fin", 0.0, true)
	for i in 4:
		cyl(
			Z02,
			StringName("Z02_Rib%d" % i),
			Vector3(13.5 + float(i) * 3.5, 0.3, 26),
			0.22,
			6.0,
			&"bone",
			Vector3(0, 0, PI * 0.5),
			false,
			6
		)
	# Несколько статичных карапаксов для масштаба (без AI и без коллизии).
	for i in 3:
		_crab_placeholder(Z02, StringName("Z02_Crab%d" % i), Vector3(12.0 + float(i) * 5.0, -1.5, 31.0 + float(i % 2) * 1.5), 2.4, 0.8)
	puddle(Z02, &"Z02_PuddleA", Vector3(15, -1.45, 19), Vector2(5, 3))
	puddle(Z02, &"Z02_PuddleB", Vector3(25, -1.45, 22), Vector2(4, 2.5))
	zone_label(Z02, &"Z02_Label", Vector3(19, 6, 26), "Z02 - CARCASS", Color(0.8, 0.55, 0.5, 0.9), 26)


# ---------------------------------------------------------------------------
# Z03. Первая развилка
# ---------------------------------------------------------------------------

func _build_z03_first_fork() -> void:
	floor_zone(Z03, &"Z03_Floor", Vector2(0, 0), Vector2(24, 24), 0.0, &"mud")
	# Восточный вход.
	wall_segment(Z03, &"Z03_EastWallA", Vector2(12, -12), Vector2(12, -4), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z03, &"Z03_EastWallB", Vector2(12, 4), Vector2(12, 12), 0.0, 12.0, 2.0, &"coral")
	# Западные выходы: Z04 и Z05.
	wall_segment(Z03, &"Z03_WestWallA", Vector2(-12, -12), Vector2(-12, -10), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z03, &"Z03_WestWallB", Vector2(-12, -4), Vector2(-12, 4), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z03, &"Z03_WestWallC", Vector2(-12, 10), Vector2(-12, 12), 0.0, 12.0, 2.0, &"coral")
	# Северный выход на гряду.
	wall_segment(Z03, &"Z03_NorthWallA", Vector2(-12, -12), Vector2(-4, -12), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z03, &"Z03_NorthWallB", Vector2(4, -12), Vector2(12, -12), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z03, &"Z03_SouthWall", Vector2(-12, 12), Vector2(12, 12), 0.0, 12.0, 2.0, &"coral")

	# Центральный пень — место первого боя.
	box(Z03, &"Z03_Stump", Vector3(0, 1.0, 0), Vector3(3, 2, 3), &"coral", 0.35, true)
	cyl(Z03, &"Z03_StumpTip", Vector3(0, 2.3, 0), 0.8, 1.8, &"coral_pale", Vector3.ZERO, false, 6, 0.1)
	bone_line(Z03, &"Z03_Bones", Vector3(-4, 0.12, 3), 4, 1.6, 13)

	# Короткие связки к Z04 и Z05.
	floor_between(Z03, &"Z03_ToMud", Vector2(-12, -7), Vector2(-15, -12), 6.0, 0.0, &"mud")
	floor_between(Z03, &"Z03_ToBone", Vector2(-12, 7), Vector2(-15, 15), 6.0, 0.0, &"mud")
	# G5: площадка в углу Z03→Z05, чтобы два трапа сшивались без разрыва.
	floor_zone(Z03, &"Z03_BoneLanding", Vector2(-16, 14), Vector2(6, 6), 0.0, &"mud")
	zone_label(Z03, &"Z03_Label", Vector3(0, 8, 0), "Z03 - FIRST FORK", Color(0.85, 0.85, 0.8, 0.95), 30)


# ---------------------------------------------------------------------------
# Z04. Мутная низина
# ---------------------------------------------------------------------------

func _build_z04_mud_hollow() -> void:
	floor_zone(Z04, &"Z04_Floor", Vector2(-30, -42.5), Vector2(30, 25), -3.0, &"mud")
	stairs_between(Z04, &"Z04_Approach", Vector3(-15, 0, -12), Vector3(-20, -3, -35), 6.0, 0.25, &"mud")
	wall_segment(Z04, &"Z04_NorthWall", Vector2(-45, -55), Vector2(-15, -55), -3.0, 9.0, 2.0, &"coral")
	wall_segment(Z04, &"Z04_EastWallA", Vector2(-15, -55), Vector2(-15, -30), -3.0, 9.0, 2.0, &"coral")
	wall_segment(Z04, &"Z04_EastWallB", Vector2(-15, -12), Vector2(-15, -2), -3.0, 15.0, 2.0, &"coral")
	wall_segment(Z04, &"Z04_SouthWallA", Vector2(-45, -30), Vector2(-30, -30), -3.0, 15.0, 2.0, &"coral")
	wall_segment(Z04, &"Z04_WestWallA", Vector2(-45, -55), Vector2(-45, -25), -3.0, 9.0, 2.0, &"coral")
	wall_segment(Z04, &"Z04_WestWallB", Vector2(-45, -15), Vector2(-45, -30), -3.0, 15.0, 2.0, &"coral")

	# Центральный гребень и рёбра. Гребень низкий (0,35 м над полом),
	# чтобы его можно было перейти без прыжка и чтобы POI Z04 был достижим.
	box(Z04, &"Z04_Ridge", Vector3(-30, -2.9, -42), Vector3(12, 0.5, 6), &"coral_pale", 0.0, true)
	for i in 3:
		cyl(
			Z04,
			StringName("Z04_Rib%d" % i),
			Vector3(-38.0 + float(i) * 3.0, -2.0, -38.0),
			0.28,
			7.0,
			&"bone",
			Vector3(0, 0, PI * 0.5),
			false,
			6
		)
	puddle(Z04, &"Z04_PuddleA", Vector3(-24, -2.9, -45), Vector2(7, 4))
	puddle(Z04, &"Z04_PuddleB", Vector3(-35, -2.9, -33), Vector2(5, 3))

	# Связка к прогалине.
	floor_between(Z04, &"Z04_ToClearing", Vector2(-45, -30), Vector2(-50, -15), 8.0, -3.0, &"mud")
	stairs_between(Z04, &"Z04_ToClearingStairs", Vector3(-45, -3, -30), Vector3(-50, 0, -15), 8.0, 0.25, &"mud")
	zone_label(Z04, &"Z04_Label", Vector3(-30, 5, -42), "Z04 - MUD HOLLOW", Color(0.7, 0.62, 0.55, 0.9), 26)


# ---------------------------------------------------------------------------
# Z05. Костяной проход
# ---------------------------------------------------------------------------

func _build_z05_bone_passage() -> void:
	floor_between(Z05, &"Z05_Entry", Vector2(-15, 7), Vector2(-20, 20), 6.0, 0.0, &"mud")
	floor_zone(Z05, &"Z05_Floor", Vector2(-30, 21), Vector2(30, 10), 0.0, &"mud")
	floor_zone(Z05, &"Z05_Chamber", Vector2(-30, 30), Vector2(10, 10), 0.0, &"mud")
	wall_segment(Z05, &"Z05_SouthWallA", Vector2(-45, 16), Vector2(-22, 16), 0.0, 8.0, 2.0, &"coral")
	# Разрыв в северной стене: камера Z05 и выход к Z06 должны быть
	# доступны из костяного прохода.
	wall_segment(Z05, &"Z05_NorthWallA", Vector2(-45, 26), Vector2(-38, 26), 0.0, 8.0, 2.0, &"coral")
	wall_segment(Z05, &"Z05_NorthWallB", Vector2(-25, 26), Vector2(-15, 26), 0.0, 8.0, 2.0, &"coral")
	wall_segment(Z05, &"Z05_EastWall", Vector2(-15, 16), Vector2(-15, 26), 0.0, 8.0, 2.0, &"coral")
	wall_segment(Z05, &"Z05_WestWallA", Vector2(-45, 16), Vector2(-45, 18), 0.0, 8.0, 2.0, &"coral")
	wall_segment(Z05, &"Z05_WestWallB", Vector2(-45, 22), Vector2(-45, 26), 0.0, 8.0, 2.0, &"coral")

	# Арка из рёбер на входе.
	cyl(Z05, &"Z05_ArchWest", Vector3(-20, 4, 16.5), 0.45, 8.0, &"bone", Vector3.ZERO, false, 6, 0.8)
	cyl(Z05, &"Z05_ArchEast", Vector3(-20, 4, 25.5), 0.45, 8.0, &"bone", Vector3.ZERO, false, 6, 0.8)
	box(Z05, &"Z05_ArchLintel", Vector3(-20, 8.0, 21), Vector3(1.0, 0.8, 10.0), &"bone", 0.0, false)
	# Сужение до трёх метров.
	coral_mass(Z05, &"Z05_PinchWest", Vector3(-32, 0, 17.5), Vector3(3, 6, 4), &"coral", 51)
	coral_mass(Z05, &"Z05_PinchEast", Vector3(-32, 0, 24.5), Vector3(3, 6, 4), &"coral", 52)

	# Связка к прогалине.
	floor_between(Z05, &"Z05_ToClearing", Vector2(-45, 20), Vector2(-50, 15), 6.0, 0.0, &"mud")
	# Связка к сухому карману.
	floor_zone(Z05, &"Z05_PocketLanding", Vector2(-35, 28), Vector2(8, 8), 0.0, &"mud")
	floor_between(Z05, &"Z05_ToPocket", Vector2(-35, 26), Vector2(-50, 30), 6.0, 0.0, &"mud")
	zone_label(Z05, &"Z05_Label", Vector3(-30, 7, 21), "Z05 - BONE PASSAGE", Color(0.8, 0.78, 0.65, 0.9), 26)


# ---------------------------------------------------------------------------
# Z06. Сухой карман
# ---------------------------------------------------------------------------

func _build_z06_dry_pocket() -> void:
	floor_zone(Z06, &"Z06_Floor", Vector2(-47.5, 46), Vector2(15, 12), 6.0, &"coral_pale")
	stairs_between(Z06, &"Z06_Stairs", Vector3(-50, 0, 30), Vector3(-50, 6, 40), 6.0, 0.25, &"coral_pale")
	wall_segment(Z06, &"Z06_NorthWallA", Vector2(-55, 40), Vector2(-52, 40), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z06, &"Z06_NorthWallB", Vector2(-48, 40), Vector2(-40, 40), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z06, &"Z06_WestWall", Vector2(-55, 40), Vector2(-55, 52), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z06, &"Z06_SouthWall", Vector2(-55, 52), Vector2(-40, 52), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z06, &"Z06_EastWall", Vector2(-40, 40), Vector2(-40, 52), 0.0, 12.0, 2.0, &"coral")
	bone_line(Z06, &"Z06_Bones", Vector3(-48, 6.2, 47), 4, 1.5, 61)
	cyl(Z06, &"Z06_Shard", Vector3(-45, 6.6, 49), 0.25, 0.6, &"screen_cyan_dim", Vector3.ZERO, false, 6)
	zone_label(Z06, &"Z06_Label", Vector3(-47.5, 12, 46), "Z06 - DRY POCKET", Color(0.75, 0.85, 0.75, 0.9), 24)


# ---------------------------------------------------------------------------
# Z07. Смотровая гряда
# ---------------------------------------------------------------------------

func _build_z07_scout_ridge() -> void:
	stairs_between(Z07, &"Z07_Ramp", Vector3(0, 0, -12), Vector3(0, 7, -48), 8.0, 0.25, &"coral_pale")
	floor_zone(Z07, &"Z07_Ridge", Vector2(-25, -55), Vector2(60, 14), 7.0, &"coral_pale")
	wall_segment(Z07, &"Z07_NorthWall", Vector2(-55, -62), Vector2(5, -62), 0.0, 12.0, 2.0, &"coral")
	# G-route: два разрыва в южном парапете — вход с рампы (x≈0) и
	# выход на спуск к прогалу (x≈−50). Иначе маршрут упирается в стену
	# высотой 1,5 м сразу на кромке.
	wall_segment(Z07, &"Z07_SouthParapetA", Vector2(-55, -48), Vector2(-53, -48), 7.0, 1.5, 1.0, &"coral_pale")
	wall_segment(Z07, &"Z07_SouthParapetB", Vector2(-42, -48), Vector2(-3, -48), 7.0, 1.5, 1.0, &"coral_pale")
	wall_segment(Z07, &"Z07_SouthParapetC", Vector2(3, -48), Vector2(5, -48), 7.0, 1.5, 1.0, &"coral_pale")
	# Спуск к прогалине.
	stairs_between(Z07, &"Z07_Spur", Vector3(-55, 0, -20), Vector3(-50, 7, -48), 6.0, 0.25, &"coral_pale")
	floor_between(Z07, &"Z07_SpurLip", Vector2(-55, -20), Vector2(-55, -18), 6.0, 0.0, &"coral_pale")
	# Герой-лезвие.
	cyl(Z07, &"Z07_HeroBlade", Vector3(-35, 22, -55), 3.0, 30.0, &"coral_pale", Vector3.ZERO, true, 6, 0.1)
	zone_label(Z07, &"Z07_Label", Vector3(-25, 16, -55), "Z07 - SCOUT RIDGE", Color(0.85, 0.9, 1.0, 0.95), 28)


# ---------------------------------------------------------------------------
# Z08. Прогалина
# ---------------------------------------------------------------------------

func _build_z08_clearing() -> void:
	floor_zone(Z08, &"Z08_Floor", Vector2(-65, 0), Vector2(30, 36), 0.0, &"mud")
	wall_segment(Z08, &"Z08_EastWallA", Vector2(-50, -18), Vector2(-50, -18), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z08, &"Z08_EastWallB", Vector2(-50, -12), Vector2(-50, 12), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z08, &"Z08_EastWallC", Vector2(-50, 18), Vector2(-50, 18), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z08, &"Z08_NorthWallA", Vector2(-80, -18), Vector2(-58, -18), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z08, &"Z08_NorthWallB", Vector2(-52, -18), Vector2(-50, -18), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z08, &"Z08_SouthWallA", Vector2(-80, 18), Vector2(-58, 18), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z08, &"Z08_SouthWallB", Vector2(-52, 18), Vector2(-50, 18), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z08, &"Z08_WestWallA", Vector2(-80, -18), Vector2(-80, -4), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z08, &"Z08_WestWallB", Vector2(-80, 4), Vector2(-80, 18), 0.0, 12.0, 2.0, &"coral")

	# Центральный остров и лезвия.
	box(Z08, &"Z08_Island", Vector3(-65, 0.18, 0), Vector3(8, 0.35, 6), &"coral_pale", 0.0, true)
	for i in 4:
		var angle := TAU * float(i) / 4.0 + 0.4
		cyl(
			Z08,
			StringName("Z08_Blade%d" % i),
			Vector3(-65 + cos(angle) * 13.0, 4.0, sin(angle) * 13.0),
			1.2,
			8.0,
			&"coral_pale",
			Vector3.ZERO,
			true,
			6,
			0.1
		)
	# Вход в туннель.
	box(Z08, &"Z08_TunnelFrameL", Vector3(-55, 1.5, 17.5), Vector3(0.8, 3, 0.8), &"coral", 0.0, true)
	box(Z08, &"Z08_TunnelFrameR", Vector3(-55, 1.5, 22.5), Vector3(0.8, 3, 0.8), &"coral", 0.0, true)
	box(Z08, &"Z08_TunnelFrameTop", Vector3(-55, 3.2, 20), Vector3(0.8, 0.5, 6.0), &"coral", 0.0, true)
	# Связка к холму.
	floor_between(Z08, &"Z08_ToHill", Vector2(-80, 0), Vector2(-85, 0), 8.0, 0.0, &"mud")
	stairs_between(Z08, &"Z08_ToHillStairs", Vector3(-80, 0, 0), Vector3(-85, 1, 0), 8.0, 0.25, &"mud")
	zone_label(Z08, &"Z08_Label", Vector3(-65, 8, 0), "Z08 - CLEARING", Color(0.9, 0.85, 0.75, 0.95), 30)


# ---------------------------------------------------------------------------
# Z09. Слепой туннель
# ---------------------------------------------------------------------------

func _build_z09_blind_tunnel() -> void:
	floor_zone(Z09, &"Z09_Floor", Vector2(-70, 20), Vector2(30, 4), 0.0, &"mud")
	wall_segment(Z09, &"Z09_SouthWallA", Vector2(-82, 17), Vector2(-72, 17), 0.0, 4.0, 1.0, &"coral")
	wall_segment(Z09, &"Z09_SouthWallB", Vector2(-68, 17), Vector2(-55, 17), 0.0, 4.0, 1.0, &"coral")
	wall_segment(Z09, &"Z09_NorthWallA", Vector2(-85, 23), Vector2(-72, 23), 0.0, 4.0, 1.0, &"coral")
	wall_segment(Z09, &"Z09_NorthWallB", Vector2(-68, 23), Vector2(-55, 23), 0.0, 4.0, 1.0, &"coral")
	# Потолок с разрывом для света.
	box(Z09, &"Z09_CeilingWest", Vector3(-79, 4.0, 20), Vector3(12, 0.4, 6), &"coral", 0.0, true)
	box(Z09, &"Z09_CeilingEast", Vector3(-61, 4.0, 20), Vector3(12, 0.4, 6), &"coral", 0.0, true)
	# Световая щель.
	box(Z09, &"Z09_LightShaft", Vector3(-70, 3.5, 20), Vector3(3, 3.0, 2), &"coral_pale", 0.0, false)
	# Выход к холму.
	stairs_between(Z09, &"Z09_ToHill", Vector3(-85, 0, 20), Vector3(-88, 1, 20), 4.0, 0.25, &"coral_pale")
	zone_label(Z09, &"Z09_Label", Vector3(-70, 3.0, 20), "Z09 - BLIND TUNNEL", Color(0.65, 0.7, 0.75, 0.9), 22)


# ---------------------------------------------------------------------------
# Z10. Коралловый холм
# ---------------------------------------------------------------------------

func _build_z10_coral_hill() -> void:
	floor_zone(Z10, &"Z10_Base", Vector2(-105, -5), Vector2(40, 50), 1.0, &"mud")
	coral_mass(Z10, &"Z10_HillCore", Vector3(-102, 1, -10), Vector3(20, 10, 20), &"coral", 21)
	# Длинная лестница по южной кромке и мост к лагерю.
	stairs_between(Z10, &"Z10_Climb", Vector3(-87, 1, 20), Vector3(-105, 18, 20), 6.0, 0.25, &"coral_pale")
	floor_between(Z10, &"Z10_ClimbApron", Vector2(-85, 20), Vector2(-87, 20), 6.0, 1.0, &"coral_pale")
	# Мост начинается ровно на верхней кромке подъёма (x=-105) и уходит
	# на запад к лагерю: плита не должна висеть над последними метрами рампы.
	box(Z10, &"Z10_TopBridge", Vector3(-108, 17.75, 5), Vector3(6, 0.5, 30), &"coral_pale", 0.0, true)
	box(Z10, &"Z10_Top", Vector3(-105, 17.75, -10), Vector3(14, 0.5, 12), &"coral_pale", 0.0, true)
	# Западный спуск к приливному каналу — два switchback-сегмента.
	stairs_between(Z10, &"Z10_WestDescent1", Vector3(-125, 6, -20), Vector3(-128, 12, -5), 5.0, 0.25, &"coral_pale")
	stairs_between(Z10, &"Z10_WestDescent2", Vector3(-128, 12, -5), Vector3(-112, 18, -10), 5.0, 0.25, &"coral_pale")
	# Лагерь: костёр, лежанки, ветрозащита.
	_fire_pit(Z10, &"Z10_Campfire", Vector3(-100, 18.0, -5))
	for i in 3:
		box(
			Z10,
			StringName("Z10_Bed%d" % i),
			Vector3(-103.5 + float(i) * 3.0, 18.15, -8.5),
			Vector3(2.0, 0.3, 1.2),
			&"fabric_grey",
			0.1,
			false
		)
	for i in 3:
		cyl(
			Z10,
			StringName("Z10_Windbreak%d" % i),
			Vector3(-98.0 + float(i) * 1.6, 20.0, -11.0),
			0.8,
			4.0,
			&"coral_pale",
			Vector3.ZERO,
			false,
			6,
			0.1
		)
	zone_label(Z10, &"Z10_Label", Vector3(-105, 27, -10), "Z10 - CORAL HILL / CAMP", Color(1.0, 0.8, 0.55, 0.95), 28)


# ---------------------------------------------------------------------------
# Z11. Приливной канал
# ---------------------------------------------------------------------------

func _build_z11_tide_channel() -> void:
	floor_zone(Z11, &"Z11_Channel", Vector2(-137.5, 0), Vector2(25, 60), -6.0, &"mud")
	# Нижний порог — только в отлив.
	box(Z11, &"Z11_LowSill", Vector3(-137.5, -1.25, 0), Vector3(25, 0.5, 6), &"coral", 0.0, true)
	stairs_between(Z11, &"Z11_EastLowStairs", Vector3(-125, -1, 0), Vector3(-122, 1, 0), 6.0, 0.25, &"coral")
	stairs_between(Z11, &"Z11_WestLowStairs", Vector3(-147, -1, 0), Vector3(-150, 0, 0), 6.0, 0.25, &"coral")
	# Верхний карниз — всегда открыт.
	box(Z11, &"Z11_HighLedge", Vector3(-137.5, 5.75, -20), Vector3(25, 0.5, 4), &"coral_pale", 0.0, true)
	stairs_between(Z11, &"Z11_HighEastStairs", Vector3(-150, 6, -20), Vector3(-153, 5, -20), 4.0, 0.25, &"coral_pale")
	wall_segment(Z11, &"Z11_NorthWall", Vector2(-150, -30), Vector2(-125, -30), -6.0, 18.0, 2.0, &"coral")
	wall_segment(Z11, &"Z11_SouthWall", Vector2(-150, 30), Vector2(-125, 30), -6.0, 18.0, 2.0, &"coral")
	zone_label(Z11, &"Z11_Label", Vector3(-137.5, 10, -20), "Z11 - TIDE CHANNEL", Color(0.6, 0.8, 0.95, 0.95), 26)


# ---------------------------------------------------------------------------
# Z12. Западный перешеек
# ---------------------------------------------------------------------------

func _build_z12_isthmus() -> void:
	floor_zone(Z12, &"Z12_Low", Vector2(-175, 5), Vector2(50, 40), 0.0, &"mud")
	box(Z12, &"Z12_HighLedge", Vector3(-175, 4.75, -20), Vector3(50, 0.5, 10), &"coral_pale", 0.0, true)
	wall_segment(Z12, &"Z12_NorthWall", Vector2(-198, -25), Vector2(-150, -25), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z12, &"Z12_SouthWall", Vector2(-200, 25), Vector2(-150, 25), 0.0, 12.0, 2.0, &"coral")
	# Восточная стена: разрывы под низкий порог и верхний карниз.
	wall_segment(Z12, &"Z12_EastWallA", Vector2(-150, -25), Vector2(-150, -22), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z12, &"Z12_EastWallB", Vector2(-150, -18), Vector2(-150, -3), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z12, &"Z12_EastWallC", Vector2(-150, 3), Vector2(-150, 25), 0.0, 12.0, 2.0, &"coral")
	# Западная стена: широкий проход под высокий траверс Z13.
	wall_segment(Z12, &"Z12_WestWallB", Vector2(-200, -18), Vector2(-200, -3), 0.0, 12.0, 2.0, &"coral")
	wall_segment(Z12, &"Z12_WestWallC", Vector2(-200, 3), Vector2(-200, 25), 0.0, 12.0, 2.0, &"coral")
	# Сужение перешейка.
	coral_mass(Z12, &"Z12_NarrowNorth", Vector3(-175, 0, -12), Vector3(6, 8, 8), &"coral", 71)
	coral_mass(Z12, &"Z12_NarrowSouth", Vector3(-175, 0, 12), Vector3(6, 8, 8), &"coral", 72)
	# Высокий проход к северному траверсу Z13.
	floor_between(Z12, &"Z12_HighLink", Vector2(-200, -20), Vector2(-204, -20), 10.0, 5.0, &"coral_pale")
	floor_between(Z12, &"Z12_ToNorth", Vector2(-204, -20), Vector2(-204, -90), 10.0, 5.0, &"coral_pale")
	zone_label(Z12, &"Z12_Label", Vector3(-175, 12, -20), "Z12 - WEST ISTHMUS", Color(0.8, 0.85, 0.9, 0.95), 26)


# ---------------------------------------------------------------------------
# Z13. Охотничьи угодья
# ---------------------------------------------------------------------------

func _build_z13_hunting_grounds() -> void:
	floor_zone(Z13, &"Z13_Central", Vector2(-375, 0), Vector2(350, 60), 0.0, &"mud")
	floor_zone(Z13, &"Z13_North", Vector2(-375, -90), Vector2(350, 20), 5.0, &"coral_pale")
	floor_zone(Z13, &"Z13_South", Vector2(-375, 90), Vector2(350, 20), -2.0, &"mud")
	# Разделительные массы между маршрутами.
	wall_segment(Z13, &"Z13_DividerNorthA", Vector2(-550, -50), Vector2(-460, -50), 0.0, 12.0, 4.0, &"coral")
	wall_segment(Z13, &"Z13_DividerNorthB", Vector2(-440, -50), Vector2(-260, -50), 0.0, 12.0, 4.0, &"coral")
	wall_segment(Z13, &"Z13_DividerNorthC", Vector2(-240, -50), Vector2(-208, -50), 0.0, 12.0, 4.0, &"coral")
	wall_segment(Z13, &"Z13_DividerSouthA", Vector2(-550, 50), Vector2(-460, 50), 0.0, 12.0, 4.0, &"coral")
	wall_segment(Z13, &"Z13_DividerSouthB", Vector2(-440, 50), Vector2(-260, 50), 0.0, 12.0, 4.0, &"coral")
	wall_segment(Z13, &"Z13_DividerSouthC", Vector2(-240, 50), Vector2(-200, 50), 0.0, 12.0, 4.0, &"coral")
	# Низкие парапеты по краям центральной равнины: края видны, но не смертельны.
	for segment in [[-550.0, -454.0], [-446.0, -254.0], [-246.0, -200.0]]:
		var a: float = segment[0]
		var b: float = segment[1]
		wall_segment(Z13, StringName("Z13_CentralNorth_%d" % int(a)), Vector2(a, -30), Vector2(b, -30), 0.0, 1.5, 0.4, &"coral_pale")
		wall_segment(Z13, StringName("Z13_CentralSouth_%d" % int(a)), Vector2(a, 30), Vector2(b, 30), 0.0, 1.5, 0.4, &"coral_pale")
	# Северные и южные связки.
	stairs_between(Z13, &"Z13_NorthLink1", Vector3(-250, 0, -30), Vector3(-250, 5, -80), 8.0, 0.25, &"coral_pale")
	stairs_between(Z13, &"Z13_NorthLink2", Vector3(-450, 0, -30), Vector3(-450, 5, -80), 8.0, 0.25, &"coral_pale")
	stairs_between(Z13, &"Z13_SouthLink1", Vector3(-250, -2, 80), Vector3(-250, 0, 30), 8.0, 0.25, &"mud")
	stairs_between(Z13, &"Z13_SouthLink2", Vector3(-450, -2, 80), Vector3(-450, 0, 30), 8.0, 0.25, &"mud")
	# Вход из Z12 (низ и высокий траверс).
	# Выход к костяному мосту.
	# Гигантский скелет в центре.
	for i in 6:
		cyl(
			Z13,
			StringName("Z13_Rib%d" % i),
			Vector3(-380.0 + float(i) * 4.0, 3.0, 0),
			0.45,
			14.0,
			&"bone",
			Vector3(0, 0, PI * 0.5),
			false,
			6
		)
	box(Z13, &"Z13_Skull", Vector3(-360, 2.0, 0), Vector3(5, 4, 6), &"bone", 0.0, true)
	# Коралловые массы в центральной равнине: три маршрута читаются как петли,
	# а не как открытое поле. Гэпы оставляют проходы по центру и по краям.
	var z13_masses := [
		[-225.0, -10.0, 17],
		[-250.0, 10.0, 11],
		[-275.0, -10.0, 18],
		[-300.0, 10.0, 12],
		[-325.0, -10.0, 19],
		[-350.0, 10.0, 13],
		[-375.0, -10.0, 20],
		[-400.0, 10.0, 14],
		[-425.0, -10.0, 21],
		[-450.0, 10.0, 15],
		[-475.0, -10.0, 22],
		[-500.0, 10.0, 16],
		[-525.0, -10.0, 23],
	]
	for entry in z13_masses:
		coral_mass(
			Z13,
			StringName("Z13_Mass%d" % int(entry[0])),
			Vector3(float(entry[0]), 0.0, float(entry[1])),
			Vector3(12, 8, 12),
			&"coral",
			int(entry[2])
		)
	zone_label(Z13, &"Z13_LabelCentral", Vector3(-375, 9, 0), "Z13b - CENTRAL FLAT", Color(0.85, 0.8, 0.7, 0.9), 26)
	zone_label(Z13, &"Z13_LabelNorth", Vector3(-375, 12, -90), "Z13a - NORTH TRAVERSE", Color(0.75, 0.85, 0.95, 0.9), 24)
	zone_label(Z13, &"Z13_LabelSouth", Vector3(-375, 4, 90), "Z13c - SOUTH CHANNEL", Color(0.65, 0.6, 0.55, 0.9), 24)


# ---------------------------------------------------------------------------
# Z14. Костяной мост
# ---------------------------------------------------------------------------

func _build_z14_bone_bridge() -> void:
	floor_zone(Z14, &"Z14_Bridge", Vector2(-600, 0), Vector2(100, 6), 6.0, &"bone")
	floor_zone(Z14, &"Z14_Low", Vector2(-600, 18), Vector2(100, 6), 2.0, &"mud")
	floor_zone(Z14, &"Z14_Channel", Vector2(-600, 9), Vector2(100, 12), -2.0, &"mud")
	# Входы с востока.
	stairs_between(Z14, &"Z14_BridgeEast", Vector3(-540, 0, 0), Vector3(-550, 6, 0), 6.0, 0.25, &"bone")
	stairs_between(Z14, &"Z14_LowEast", Vector3(-540, 0, 18), Vector3(-550, 2, 18), 6.0, 0.25, &"mud")
	# Выход к убежищу.
	stairs_between(Z14, &"Z14_BridgeWest", Vector3(-660, 2, 0), Vector3(-650, 6, 0), 6.0, 0.25, &"bone")
	# Позвонки и рёбра моста.
	for i in 8:
		box(
			Z14,
			StringName("Z14_Vertebra%d" % i),
			Vector3(-645.0 + float(i) * 12.0, 6.3, 0),
			Vector3(8, 1.2, 6),
			&"bone",
			0.0,
			false
		)
	for i in 6:
		cyl(
			Z14,
			StringName("Z14_Rib%d" % i),
			Vector3(-640.0 + float(i) * 16.0, 8.0, -3.5),
			0.3,
			8.0,
			&"bone",
			Vector3(0, 0, PI * 0.5),
			false,
			6
		)
	zone_label(Z14, &"Z14_Label", Vector3(-600, 12, 0), "Z14 - BONE BRIDGE", Color(0.9, 0.85, 0.7, 0.95), 28)


# ---------------------------------------------------------------------------
# Z15. Высокое убежище
# ---------------------------------------------------------------------------

func _build_z15_high_refuge() -> void:
	floor_zone(Z15, &"Z15_Base", Vector2(-700, -20), Vector2(100, 120), 2.0, &"mud")
	coral_mass(Z15, &"Z15_Mound", Vector3(-700, 2, 10), Vector3(30, 12, 30), &"coral", 31)
	stairs_between(Z15, &"Z15_Climb", Vector3(-650, 2, -20), Vector3(-680, 18, -20), 8.0, 0.25, &"coral_pale")
	# Приёмная площадка на верхней кромке: сшивает рампу, мост и убежище
	# без grid-gap, который ловил BFS-аудит.
	floor_zone(Z15, &"Z15_TopLanding", Vector2(-684, -20), Vector2(8, 16), 18.0, &"coral_pale")
	box(Z15, &"Z15_Ledge", Vector3(-700, 17.75, -20), Vector3(20, 0.5, 20), &"coral_pale", 0.0, true)
	box(Z15, &"Z15_Bridge", Vector3(-690, 17.75, -20), Vector3(20, 0.5, 6), &"coral_pale", 0.0, true)
	# Навес убежища.
	box(Z15, &"Z15_Shelter", Vector3(-704, 20.5, -23), Vector3(6, 0.5, 6), &"coral_pale", 0.0, true)
	for i in 2:
		box(
			Z15,
			StringName("Z15_ShelterPost%d" % i),
			Vector3(-707.0 + float(i) * 6.0, 19.5, -25),
			Vector3(0.5, 3.0, 0.5),
			&"coral_pale",
			0.0,
			true
		)
	# Спуск к территории стаи.
	stairs_between(Z15, &"Z15_ToPack", Vector3(-800, 0, -20), Vector3(-750, 2, -20), 30.0, 0.25, &"mud")
	zone_label(Z15, &"Z15_Label", Vector3(-700, 28, -20), "Z15 - HIGH REFUGE", Color(0.95, 0.85, 0.65, 0.95), 28)


# ---------------------------------------------------------------------------
# Z16. Территория стаи
# ---------------------------------------------------------------------------

func _build_z16_pack_territory() -> void:
	floor_zone(Z16, &"Z16_Low", Vector2(-900, 0), Vector2(300, 80), 0.0, &"mud")
	floor_zone(Z16, &"Z16_Ridge", Vector2(-900, 90), Vector2(300, 20), 6.0, &"coral_pale")
	# Поперечные стены низкого лабиринта.
	wall_segment(Z16, &"Z16_CrossA", Vector2(-850, -40), Vector2(-850, -10), 0.0, 10.0, 3.0, &"coral")
	wall_segment(Z16, &"Z16_CrossB", Vector2(-850, 10), Vector2(-850, 40), 0.0, 10.0, 3.0, &"coral")
	wall_segment(Z16, &"Z16_CrossC", Vector2(-950, -40), Vector2(-950, -10), 0.0, 10.0, 3.0, &"coral")
	wall_segment(Z16, &"Z16_CrossD", Vector2(-950, 10), Vector2(-950, 40), 0.0, 10.0, 3.0, &"coral")
	# Разделитель низ/гребень с проходами.
	# Западный разрыв под длинную лестницу Z16_RidgeToStorm (x=-1050).
	wall_segment(Z16, &"Z16_DividerA", Vector2(-1046, 60), Vector2(-1010, 60), 0.0, 12.0, 4.0, &"coral")
	wall_segment(Z16, &"Z16_DividerB", Vector2(-990, 60), Vector2(-810, 60), 0.0, 12.0, 4.0, &"coral")
	wall_segment(Z16, &"Z16_DividerC", Vector2(-790, 60), Vector2(-750, 60), 0.0, 12.0, 4.0, &"coral")
	stairs_between(Z16, &"Z16_RidgeLink1", Vector3(-800, 0, 40), Vector3(-800, 6, 70), 6.0, 0.25, &"coral_pale")
	stairs_between(Z16, &"Z16_RidgeLink2", Vector3(-1000, 0, 40), Vector3(-1000, 6, 70), 6.0, 0.25, &"coral_pale")
	# Широкая приемная площадка перед гребнем: диагональный маршрут
	# с лестницы на Z16a не должен срезать край узкой полки.
	floor_zone(Z16, &"Z16_RidgeApron", Vector2(-825, 75), Vector2(150, 10), 6.0, &"coral_pale")
	floor_between(Z16, &"Z16_RidgeLip1", Vector2(-800, 70), Vector2(-800, 80), 6.0, 6.0, &"coral_pale")
	floor_between(Z16, &"Z16_RidgeLip2", Vector2(-1000, 70), Vector2(-1000, 80), 6.0, 6.0, &"coral_pale")
	# Парапеты по краям низкого лабиринта и гребня.
	for segment in [[-1050.0, -1004.0], [-996.0, -804.0], [-796.0, -750.0]]:
		var a: float = segment[0]
		var b: float = segment[1]
		wall_segment(Z16, StringName("Z16_LowSouth_%d" % int(a)), Vector2(a, 40), Vector2(b, 40), 0.0, 1.5, 0.4, &"coral_pale")
	# Восточный край гребня: разрыв под лестницу Z16_RidgeToStorm (x=-1050).
	for segment in [[-1046.0, -1004.0], [-996.0, -906.0], [-894.0, -804.0], [-796.0, -750.0]]:
		var a: float = segment[0]
		var b: float = segment[1]
		wall_segment(Z16, StringName("Z16_RidgeInner_%d" % int(a)), Vector2(a, 80), Vector2(b, 80), 6.0, 1.5, 0.4, &"coral_pale")
	wall_segment(Z16, &"Z16_LowNorth", Vector2(-1050, -40), Vector2(-750, -40), 0.0, 1.5, 0.4, &"coral_pale")
	wall_segment(Z16, &"Z16_RidgeOuter", Vector2(-1050, 100), Vector2(-750, 100), 6.0, 1.5, 0.4, &"coral_pale")
	# Массы внутри лабиринта стаи: плотный низ, а не открытое поле.
	var z16_masses := [
		[-775.0, 18.0, 31],
		[-825.0, -18.0, 32],
		[-825.0, 0.0, 37],
		[-875.0, 18.0, 33],
		[-875.0, -18.0, 38],
		[-925.0, -18.0, 34],
		[-925.0, 0.0, 39],
		[-975.0, 18.0, 35],
		[-975.0, 0.0, 40],
		[-1025.0, -18.0, 36],
	]
	for entry in z16_masses:
		coral_mass(
			Z16,
			StringName("Z16_Mass_%d_%d" % [int(entry[0]), int(entry[1])]),
			Vector3(float(entry[0]), 0.0, float(entry[1])),
			Vector3(10, 8, 10),
			&"coral",
			int(entry[2])
		)
	# Выход к грозе.
	stairs_between(Z16, &"Z16_ToStorm", Vector3(-1050, 0, 0), Vector3(-1070, 8, 0), 8.0, 0.25, &"coral_pale")
	# Длинная лестница должна примыкать к южной кромке Z17_High (z=10),
	# а не уходить под её плиту до z=0.
	stairs_between(Z16, &"Z16_RidgeToStorm", Vector3(-1050, 6, 85), Vector3(-1050, 8, 10), 6.0, 0.25, &"coral_pale")
	zone_label(Z16, &"Z16_Label", Vector3(-900, 10, 0), "Z16 - PACK TERRITORY", Color(0.65, 0.6, 0.65, 0.9), 28)
	zone_label(Z16, &"Z16_LabelRidge", Vector3(-900, 14, 90), "Z16a - SOUTH RIDGE", Color(0.7, 0.8, 0.85, 0.9), 24)


# ---------------------------------------------------------------------------
# Z17. Гроза
# ---------------------------------------------------------------------------

func _build_z17_storm_run() -> void:
	floor_zone(Z17, &"Z17_High", Vector2(-1175, 0), Vector2(250, 20), 8.0, &"coral_pale")
	floor_zone(Z17, &"Z17_Low", Vector2(-1175, 25), Vector2(250, 10), -2.0, &"mud")
	# Связка низ/верх.
	stairs_between(Z17, &"Z17_Link", Vector3(-1100, -2, 25), Vector3(-1100, 8, 0), 6.0, 0.25, &"coral_pale")
	# Препятствия на высоком пути.
	coral_mass(Z17, &"Z17_Collapse", Vector3(-1150, 8, -8), Vector3(8, 6, 8), &"coral", 81)
	coral_mass(Z17, &"Z17_NarrowNorth", Vector3(-1250, 8, -8), Vector3(6, 8, 8), &"coral", 82)
	coral_mass(Z17, &"Z17_NarrowSouth", Vector3(-1250, 8, 8), Vector3(6, 8, 8), &"coral", 83)
	# Выход к утёсам.
	stairs_between(Z17, &"Z17_ToCliffs", Vector3(-1320, 6, 0), Vector3(-1300, 8, 0), 6.0, 0.25, &"coral_pale")
	zone_label(Z17, &"Z17_Label", Vector3(-1175, 18, 0), "Z17 - STORM", Color(0.55, 0.7, 0.9, 0.95), 30)


# ---------------------------------------------------------------------------
# Z18. Утёсы
# ---------------------------------------------------------------------------

func _build_z18_cliffs() -> void:
	floor_zone(Z18, &"Z18_Base", Vector2(-1310, 0), Vector2(20, 20), 6.0, &"statue")
	# Серпантин из трёх отрезков.
	stairs_between(Z18, &"Z18_Switch1", Vector3(-1320, 6, 0), Vector3(-1350, 16, 20), 5.0, 0.25, &"statue")
	stairs_between(Z18, &"Z18_Switch2", Vector3(-1350, 16, 20), Vector3(-1380, 26, -10), 5.0, 0.25, &"statue")
	stairs_between(Z18, &"Z18_Switch3", Vector3(-1380, 26, -10), Vector3(-1400, 35, 0), 5.0, 0.25, &"statue")
	floor_zone(Z18, &"Z18_Top", Vector2(-1410, 0), Vector2(20, 20), 35.0, &"statue")
	coral_mass(Z18, &"Z18_CliffMass", Vector3(-1460, 0, 0), Vector3(20, 45, 200), &"statue", 41)
	zone_label(Z18, &"Z18_Label", Vector3(-1410, 42, 0), "Z18 - CLIFFS / END", Color(0.8, 0.85, 0.9, 0.95), 26)


# ---------------------------------------------------------------------------
# Границы
# ---------------------------------------------------------------------------

func _build_boundaries() -> void:
	# Внешние границы там, где нет стен.
	zone_boundary(Z01, &"EastEdge", Vector3(46, 8, 0), Vector3(1, 16, 30))
	zone_boundary(Z02, &"SouthEdge", Vector3(19, 4, 39), Vector3(24, 10, 1))
	# Разрыв под вход в Z09: сплошная граница перекрывала туннель.
	zone_boundary(Z08, &"SouthEdgeWest", Vector3(-69.5, 6, 19), Vector3(23, 12, 1))
	zone_boundary(Z08, &"SouthEdgeEast", Vector3(-50.5, 6, 19), Vector3(3, 12, 1))
	zone_boundary(Z10, &"SouthEdge", Vector3(-105, 10, 21), Vector3(42, 20, 1))
	zone_boundary(Z13, &"NorthEdge", Vector3(-375, 12, -101), Vector3(360, 20, 1))
	zone_boundary(Z13, &"SouthEdge", Vector3(-375, 6, 101), Vector3(360, 16, 1))
	zone_boundary(Z16, &"NorthEdge", Vector3(-900, 10, -41), Vector3(310, 16, 1))
	zone_boundary(Z16, &"SouthEdge", Vector3(-900, 12, 101), Vector3(310, 20, 1))
	zone_boundary(Z17, &"NorthEdge", Vector3(-1175, 14, -11), Vector3(260, 20, 1))
	# Разрыв под длинную лестницу Z16_RidgeToStorm на x=-1050.
	zone_boundary(Z17, &"SouthEdgeWest", Vector3(-1179.5, 10, 31), Vector3(251, 16, 1))
	zone_boundary(Z17, &"SouthEdgeEast", Vector3(-1045.5, 10, 31), Vector3(1, 16, 1))
	zone_boundary(Z18, &"WestEdge", Vector3(-1421, 30, 0), Vector3(1, 60, 40))
	zone_boundary(Z18, &"TopWest", Vector3(-1421, 40, 0), Vector3(1, 20, 30))


# ---------------------------------------------------------------------------
# Ориентиры
# ---------------------------------------------------------------------------

func _build_landmarks() -> void:
	_build_statue()
	_build_camp_pillar()
	_build_western_spire()
	_build_bone_bridge_landmark()
	_build_storm_wall()
	_build_cliffs_landmark()


func _build_statue() -> void:
	var root := clear_landmark(&"Statue")
	if root == null:
		return
	# Упрощённый безголовый рыцарь: ноги, торс, плечи, руки, меч.
	for z in [-9.0, 9.0]:
		_landmark_box(root, &"Leg", Vector3(100, 25, z), Vector3(10, 50, 10), &"statue")
	_landmark_box(root, &"Torso", Vector3(100, 60, 0), Vector3(24, 30, 24), &"statue")
	_landmark_box(root, &"Chest", Vector3(94, 66, 0), Vector3(4, 18, 18), &"statue_pale")
	_landmark_box(root, &"ShoulderL", Vector3(100, 78, -18), Vector3(18, 10, 14), &"statue")
	_landmark_box(root, &"ShoulderR", Vector3(100, 78, 18), Vector3(18, 10, 14), &"statue")
	_landmark_box(root, &"ArmL", Vector3(100, 55, -26), Vector3(8, 36, 8), &"statue")
	_landmark_box(root, &"ArmR", Vector3(100, 55, 26), Vector3(8, 36, 8), &"statue")
	_landmark_box(root, &"Sword", Vector3(112, 35, 0), Vector3(5, 70, 5), &"statue_pale")
	# Семь звёзд на нагруднике (видны с гряды и холма).
	for i in 7:
		var angle := TAU * float(i) / 7.0
		_landmark_box(
			root,
			StringName("Star%d" % i),
			Vector3(91.8, 66.0 + sin(angle) * 5.0, cos(angle) * 5.0),
			Vector3(0.6, 1.6, 0.25),
			&"statue_star"
		)


func _build_camp_pillar() -> void:
	var root := clear_landmark(&"CampPillar")
	if root == null:
		return
	# Столб — визуальный ориентир; нижние 6 м с коллизией.
	_landmark_cyl(root, &"PillarBase", Vector3(0, 6, 0), 5.0, 12.0, &"coral_pale", true)
	_landmark_cyl(root, &"Pillar", Vector3(0, 20, 0), 3.5, 28.0, &"coral_pale", false)
	for i in 3:
		var angle := TAU * float(i) / 3.0
		_landmark_cyl(
			root,
			StringName("Branch%d" % i),
			Vector3(cos(angle) * 3.0, 34.0, sin(angle) * 3.0),
			1.1,
			10.0,
			&"coral_pale",
			false
		)


func _build_western_spire() -> void:
	var root := clear_landmark(&"WesternSpire")
	if root == null:
		return
	_landmark_cyl(root, &"SpireBase", Vector3(0, 5, 0), 6.0, 10.0, &"coral_pale", true)
	_landmark_cyl(root, &"Spire", Vector3(0, 20, 0), 4.0, 30.0, &"coral_pale", false)
	for i in 2:
		var angle := TAU * float(i) / 2.0
		_landmark_cyl(
			root,
			StringName("SpireBranch%d" % i),
			Vector3(cos(angle) * 3.0, 33.0, sin(angle) * 3.0),
			1.0,
			8.0,
			&"coral_pale",
			false
		)


func _build_bone_bridge_landmark() -> void:
	var root := clear_landmark(&"BoneBridge")
	if root == null:
		return
	# Декоративные рёбра над мостом (сам мост — в Generated/Visual/Z14).
	for i in 6:
		_landmark_cyl(
			root,
			StringName("ArchRib%d" % i),
			Vector3(-40.0 + float(i) * 16.0, 4.0, -3.0),
			0.35,
			10.0,
			&"bone",
			false
		)


func _build_storm_wall() -> void:
	var root := clear_landmark(&"StormWall")
	if root == null:
		return
	_landmark_box(root, &"StormWall", Vector3(0, 20, 0), Vector3(5, 40, 200), &"black")


func _build_cliffs_landmark() -> void:
	var root := clear_landmark(&"Cliffs")
	if root == null:
		return
	_landmark_box(root, &"CliffFace", Vector3(0, 20, 0), Vector3(10, 45, 200), &"statue")


func _landmark_box(root: Node3D, id: StringName, local_position: Vector3, size: Vector3, material_key: StringName) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = id
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	if material_key == &"statue_star":
		mesh_instance.material_override = STATUE_STAR_MATERIAL
	else:
		mesh_instance.material_override = material(material_key)
	mesh_instance.position = local_position
	root.add_child(mesh_instance)
	return mesh_instance


func _landmark_cyl(
	root: Node3D,
	id: StringName,
	local_position: Vector3,
	radius: float,
	height: float,
	material_key: StringName,
	collision: bool = false
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = id
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.25
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 8
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = material(material_key)
	mesh_instance.position = local_position
	root.add_child(mesh_instance)
	if collision:
		var body := StaticBody3D.new()
		body.name = "Col_%s" % id
		body.position = local_position
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var cylinder_shape := CylinderShape3D.new()
		cylinder_shape.radius = radius
		cylinder_shape.height = height
		shape.shape = cylinder_shape
		body.add_child(shape)
		root.add_child(body)
	return mesh_instance


# ---------------------------------------------------------------------------
# Collision patches under art-only silhouettes on the main route
# ---------------------------------------------------------------------------

## ArtFinal replaces some greybox coral with visual-only meshes. These thin,
## invisible pads keep the underlying route walkable without turning the
## decorative silhouette into a wall.
func _build_collision_patches() -> void:
	_collision_patch(Z05, &"Z05_BoneShellPad", Vector3(-42, -0.1, 30), Vector3(8, 0.2, 8))
	_collision_patch(Z10, &"Z10_ArchPad", Vector3(-102, 17.7, 17), Vector3(4, 0.2, 4))
	_collision_patch(Z10, &"Z10_ArchPadLow", Vector3(-102, 17.7, 6), Vector3(20, 0.2, 12))
	_collision_patch(Z11, &"Z11_BladePad", Vector3(-132, 6.0, -22), Vector3(10, 0.2, 6))
	_collision_patch(Z13, &"Z13_NorthPad", Vector3(-198, 0.0, -30), Vector3(8, 0.2, 8))
	_collision_patch(Z16, &"Z16_RidgePad", Vector3(-750, 0.0, 42), Vector3(8, 0.2, 8))
	_collision_patch(Z16, &"Z16_MidPad", Vector3(-1002, 0.0, 42), Vector3(8, 0.2, 8))


func _collision_patch(zone: StringName, id: StringName, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = id
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	zone_collision(zone).add_child(body)


# ---------------------------------------------------------------------------
# Свет
# ---------------------------------------------------------------------------

func _build_lights() -> void:
	# The greybox used eleven unmotivated corridor lamps. The final pass relies
	# on the sun, sky and a few authored sources instead: campfire (in the
	# scene), the light crack in Z09, and cold bounce from the tide channel.
	zone_omni(Z11, &"Z11_WaterBounce", Vector3(-137, 4, 0), Color(0.42, 0.62, 0.82, 1), 0.55, 24.0)
	# Свет в туннеле.
	var shaft_light := SpotLight3D.new()
	shaft_light.name = "Z09_LightShaft"
	shaft_light.position = Vector3(-70, 10, 20)
	shaft_light.light_color = Color(0.6, 0.75, 0.95, 1)
	shaft_light.light_energy = 3.0
	shaft_light.spot_range = 18.0
	shaft_light.spot_angle = 28.0
	shaft_light.shadow_enabled = false
	zone_lights(Z09).add_child(shaft_light)
	shaft_light.look_at(Vector3(-70, 0, 20), Vector3.FORWARD)


# ---------------------------------------------------------------------------
# Подписи
# ---------------------------------------------------------------------------

func _build_labels() -> void:
	pass


# ---------------------------------------------------------------------------
# Приливные шлюзы
# ---------------------------------------------------------------------------

func _build_tide_gates() -> void:
	tide_gate(Z04, &"Z04_LowEntrance", Vector3(-18, 1.5, -13), Vector3(6, 3, 1), 0.0)
	tide_gate(Z05, &"Z05_LowEntrance", Vector3(-17, 1.5, 11), Vector3(6, 3, 1), 0.0)
	tide_gate(Z08, &"Z08_TunnelMouth", Vector3(-55, 1.5, 19), Vector3(6, 3, 1), 0.0)
	tide_gate(Z11, &"Z11_LowSillEast", Vector3(-126, 1.5, 0), Vector3(1, 3, 6), 0.0)
	tide_gate(Z14, &"Z14_LowPath", Vector3(-555, 3.5, 18), Vector3(1, 3, 6), 0.0)
	tide_gate(Z13, &"Z13_SouthChannel", Vector3(-549, 0.0, 90), Vector3(1, 3, 20), 0.0)
	tide_gate(Z16, &"Z16_LowEntrance", Vector3(-752, 1.5, -20), Vector3(1, 3, 8), 0.0)
	tide_gate(Z17, &"Z17_LowPath", Vector3(-1052, 1.5, 25), Vector3(1, 3, 10), 0.0)


# ---------------------------------------------------------------------------
# Вспомогательный реквизит
# ---------------------------------------------------------------------------

func _crab_placeholder(zone: StringName, id: StringName, base: Vector3, height: float, body_scale: float) -> void:
	var root := Node3D.new()
	root.name = id
	root.position = base
	zone_visual(zone).add_child(root)
	# Торс.
	var body := MeshInstance3D.new()
	body.name = "Body"
	var sphere := SphereMesh.new()
	sphere.radius = height * 0.28
	sphere.height = height * 0.5
	body.mesh = sphere
	body.material_override = material(&"coral")
	body.position = Vector3(0, height * 0.55, 0)
	body.scale = Vector3(1.2, 0.8, 1.0) * body_scale
	root.add_child(body)
	# Клешни.
	for sx in [-1.0, 1.0]:
		var pincer := MeshInstance3D.new()
		pincer.name = "Pincer%s" % str(sx)
		var pincer_mesh := BoxMesh.new()
		pincer_mesh.size = Vector3(0.45, 0.25, 1.1) * body_scale
		pincer.mesh = pincer_mesh
		pincer.material_override = material(&"coral_pale")
		pincer.position = Vector3(sx * 0.75, height * 0.5, -0.7)
		pincer.rotation.x = 0.25
		root.add_child(pincer)
	# Ноги.
	for i in 4:
		for sx in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			leg.name = "Leg%d%s" % [i, str(sx)]
			var leg_mesh := CylinderMesh.new()
			leg_mesh.top_radius = 0.06
			leg_mesh.bottom_radius = 0.1
			leg_mesh.height = height * 0.8
			leg.mesh = leg_mesh
			leg.material_override = material(&"coral")
			leg.position = Vector3(sx * 0.55, height * 0.38, -0.45 + float(i) * 0.3)
			leg.rotation.z = sx * 0.8
			root.add_child(leg)


func bone_line(zone: StringName, id: StringName, base: Vector3, count: int, length: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var angle := rng.randf_range(-0.7, 0.7)
		cyl(
			zone,
			StringName("%s_%d" % [id, i]),
			base + Vector3(rng.randf_range(-2.0, 2.0), 0.0, rng.randf_range(-2.0, 2.0)),
			0.09,
			length,
			&"bone",
			Vector3(0.0, angle, PI * 0.5 + rng.randf_range(-0.3, 0.3)),
			false,
			6
		)


func puddle(zone: StringName, id: StringName, center: Vector3, size: Vector2) -> void:
	box(zone, id, center, Vector3(size.x, 0.02, size.y), &"water", 0.0, false)


func _fire_pit(zone: StringName, id: StringName, base: Vector3) -> void:
	for i in 6:
		var angle := TAU * float(i) / 6.0
		cyl(
			zone,
			StringName("%s_Stone%d" % [id, i]),
			base + Vector3(cos(angle) * 1.2, 0.12, sin(angle) * 1.2),
			0.22,
			0.25,
			&"concrete_dark",
			Vector3.ZERO,
			false,
			8
		)
	cyl(zone, StringName("%s_LogA" % id), base + Vector3(0, 0.25, 0), 0.09, 1.1, &"wood_dark", Vector3(0, 0, 1.1), false, 6)
	cyl(zone, StringName("%s_LogB" % id), base + Vector3(0, 0.25, 0), 0.09, 1.1, &"wood_dark", Vector3(0, 0, -1.1), false, 6)
	cyl(zone, StringName("%s_Flame" % id), base + Vector3(0, 0.9, 0), 0.35, 1.2, &"fire", Vector3.ZERO, false, 8, 0.1)


func _clear_all_landmarks() -> void:
	for landmark_name in [&"Statue", &"CampPillar", &"WesternSpire", &"BoneBridge", &"StormWall", &"Cliffs"]:
		clear_landmark(landmark_name)
