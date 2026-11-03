class_name LabyrinthNarrativeDirector
extends Node3D
## Runtime-слой побочных историй Забытого берега (A02).
##
## Строит только SQ-контент и никогда не активирует QuestSystem scope:
## это делает существующий LabyrinthQuestDirector. Директор живёт рядом с
## Gameplay/QuestDirector и складывает объекты в Gameplay/RuntimeNarrative,
## поэтому refresh() базового директора их не очищает.
##
## Контракт маркеров: A03 размещает Marker3D по путям из poi_manifest.md,
## например Gameplay/Quests/SQ_FS_01/Token. Если маркеров ещё нет, директор
## пишет предупреждение и ничего не создаёт — координаты здесь не дублируются.
##
## Зависимости, которые приходят от других агентов:
## - A01: диалоги resources/dialogue/labyrinth/sq_fs_*.tres;
## - A04: QuestInspectable, QuestChoicePanel, TideController.advance_to_low/high;
## - A05: сцена echo_polyp и Old Shell;
## - A08: UI выбора SQ-03.

const PICKUP_SCENE := preload("res://scenes/quests/quest_pickup.tscn")
const NPC_SCENE := preload("res://scenes/quests/quest_npc.tscn")
const CHOICE_PANEL_SCENE := preload("res://scenes/ui/quest_choice_panel.tscn")
const LEVER_SCRIPT := preload("res://scripts/quests/quest_lever.gd")
## A04 закрепляет адаптер в scripts/inspect/; старый путь оставлен как совместимость.
const INSPECTABLE_SCRIPTS: Array[String] = [
	"res://scripts/inspect/quest_inspectable.gd",
	"res://scripts/quests/quest_inspectable.gd",
]
const SQ_SCOPE := &"forgotten_shore"
const THEO_DIALOGUE_CANDIDATES: Array[String] = [
	"res://resources/dialogue/labyrinth/sq_fs_01_theo.tres",
	"res://resources/dialogue/labyrinth/sq_fs_01_ninth_token.tres",
	"res://resources/dialogue/labyrinth/theo_meeting.tres",
]
const THEO_RETURN_DIALOGUE_CANDIDATES: Array[String] = [
	"res://resources/dialogue/labyrinth/sq_fs_03_theo.tres",
	"res://resources/dialogue/labyrinth/sq_fs_03_truth_without_lies.tres",
	"res://resources/dialogue/labyrinth/theo_return.tres",
]

## Корень маркеров SQ. A03 может поставить Gameplay/Quests или Gameplay/Narrative.
@export var marker_root: NodePath = ^"../Quests"
@export var build_sq_01 := true
@export var build_sq_02 := true
@export var build_sq_03 := true
## SQ-05 имеет безопасный bypass-путь без alpha; SQ-04 использует tide API.
@export var build_sq_04 := true
@export var build_sq_05 := true

var _runtime: Node3D
var _markers: Node3D
var _missing_markers: Dictionary = {}
var _warned_missing_inspectable := false
var _triggers: Array[QuestTriggerZone] = []
var _inspectables: Array[Dictionary] = []
var _fallback_clues: Array[Dictionary] = []
var _choice_panel: QuestChoicePanel
var _choice_controller: QuestChoiceController
var _tide: Node


func _ready() -> void:
	call_deferred(&"_build")
	var run_state := get_node_or_null(^"/root/NightmareRunState")
	if run_state != null and not run_state.flag_changed.is_connected(_on_run_flag_changed):
		run_state.flag_changed.connect(_on_run_flag_changed)
	if run_state != null and not run_state.state_restored.is_connected(_on_run_state_restored):
		run_state.state_restored.connect(_on_run_state_restored)
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests != null and quests.has_signal(&"quest_started"):
		var handler := Callable(self, &"_on_quest_started")
		if not quests.is_connected(&"quest_started", handler):
			quests.connect(&"quest_started", handler)


func _build() -> void:
	if not build_sq_01 and not build_sq_02 and not build_sq_03 and not build_sq_04 and not build_sq_05:
		return
	var quests := get_node_or_null(^"/root/QuestSystem")
	if quests == null or not quests.has_method(&"is_scope_active"):
		return
	# Не активируем scope сами: даём LabyrinthQuestDirector шанс сделать это
	# первым, если порядок sibling-узлов в сцене оказался другим.
	for _attempt in 3:
		if bool(quests.call(&"is_scope_active")):
			break
		await get_tree().process_frame
	if not bool(quests.call(&"is_scope_active")):
		# M1/S00-S15: SQ не строятся.
		return
	if StringName(quests.get(&"active_scope")) != SQ_SCOPE:
		# Чужой scope: не строим SQ даже в загруженной сцене Лабиринта.
		return
	var gameplay := get_parent() as Node3D
	if gameplay == null:
		push_error("LabyrinthNarrativeDirector: родитель должен быть Gameplay")
		return
	_runtime = gameplay.get_node_or_null(^"RuntimeNarrative") as Node3D
	if _runtime == null:
		_runtime = Node3D.new()
		_runtime.name = "RuntimeNarrative"
		gameplay.add_child(_runtime)
	_sync_derived_flags()
	_markers = _resolve_marker_root()
	if _markers == null:
		push_warning("LabyrinthNarrativeDirector: не найден корень маркеров SQ. Ожидается Gameplay/Quests или Gameplay/Narrative.")
		return
	_ensure_choice_ui()

	if build_sq_01:
		_build_sq_01()
	if build_sq_02:
		_build_sq_02()
	if build_sq_03:
		_build_sq_03()
	if build_sq_04:
		_build_sq_04()
	if build_sq_05:
		_build_sq_05()
	_report_missing_markers()
	_sync_derived_flags()
	_repair_early_polyp_kill()
	_repair_alpha_kill()
	_refresh_inspectables()
	_refresh_fallback_clues()
	_retry_overlapping_triggers()


func _on_run_state_restored() -> void:
	if is_inside_tree() and _runtime != null and is_instance_valid(_runtime):
		refresh()


## Публичный сброс для повторной сборки после смены сцены/флагов.
func refresh() -> void:
	if _runtime == null:
		return
	for child in _runtime.get_children():
		_runtime.remove_child(child)
		child.queue_free()
	_missing_markers.clear()
	_triggers.clear()
	_inspectables.clear()
	_fallback_clues.clear()
	_build.call_deferred()


# ---------------------------------------------------------------------------
# SQ-01 «Девятый жетон»
# ---------------------------------------------------------------------------

func _build_sq_01() -> void:
	var token_marker := _marker(&"SQ_FS_01/Token")
	if token_marker != null:
		_add_pickup(
			&"SQ01_Token", &"sq_fs_01_token", "Осмотреть девятый жетон",
			&"sq_fs_01_ninth_token", 1, &"", 0,
			&"sq_fs_01_token_taken", &"interacted", &"sq_fs_01_token",
			"Латунный жетон с номером IX. На обороте — имя Лиссы.",
			[], &"sq_fs_01_ninth_token", token_marker
		)
	for trace_name in [&"Heel", &"Shell", &"Blood"]:
		var trace_marker := _marker(StringName("SQ_FS_01/Traces/%s" % trace_name))
		if trace_marker == null:
			continue
		var trace_flag := StringName("sq_fs_01_trace_%s" % String(trace_name).to_lower())
		var trace_text := "Следы складываются в один путь."
		var trace_color := Color(0.72, 0.62, 0.42, 1.0)
		match trace_name:
			&"Heel":
				trace_text = "Каблук. Человек шёл к костяному проходу, хромая."
				trace_color = Color(0.72, 0.48, 0.30, 1.0)
			&"Shell":
				trace_text = "Панцирный след. Карапакс тащил что-то тяжёлое."
				trace_color = Color(0.68, 0.63, 0.48, 1.0)
			&"Blood":
				trace_text = "Кровь на арке. Ещё не смыло приливом."
				trace_color = Color(0.64, 0.26, 0.22, 1.0)
		_add_inspectable(
			StringName("SQ01_Trace_%s" % trace_name),
			StringName("sq_fs_01_trace_%s" % String(trace_name).to_lower()),
			"Осмотреть след",
			&"sq_fs_01_trail",
			trace_flag,
			[&"sq_fs_01_started"],
			trace_marker,
			trace_text,
			trace_color
		)
	var theo_marker := _marker(&"SQ_FS_01/Theo")
	if theo_marker != null:
		_add_npc(
			&"SQ01_Theo", &"theo", "Тео",
			[&"sq_fs_01_started"], &"sq_fs_01_theo_met",
			&"", "mass_male", 0.96,
			THEO_DIALOGUE_CANDIDATES,
			theo_marker, true, true, _theo_fallback_dialogue()
		)


# ---------------------------------------------------------------------------
# SQ-02 «Голос из слепого туннеля»
# ---------------------------------------------------------------------------

func _build_sq_02() -> void:
	var tunnel_marker := _marker(&"SQ_FS_02/Tunnel")
	if tunnel_marker != null:
		_add_trigger(
			&"SQ02_Tunnel", &"sq_fs_02_tunnel", &"sq_fs_02_voice_heard",
			&"sq_fs_02_echo_tunnel", [&"sq_fs_01_complete"], 3.0, tunnel_marker
		)
	var echo_flags: Array[StringName] = [
		&"sq_fs_02_echo_a",
		&"sq_fs_02_echo_b",
		&"sq_fs_02_echo_c",
	]
	var echo_texts: Array[String] = [
		"Голос с востока. Слишком чистое эхо — стена близко.",
		"Звук идёт сверху. Пыль сыплется в такт «смеху».",
		"Голос с запада. Эхо уходит в глубину, а не к выходу.",
	]
	for index in 3:
		var echo_name: String = ["A", "B", "C"][index]
		var echo_marker := _marker(StringName("SQ_FS_02/Echo%s" % echo_name))
		if echo_marker == null:
			continue
		_add_inspectable(
			StringName("SQ02_Echo%s" % echo_name),
			StringName("sq_fs_02_echo_%s" % echo_name.to_lower()),
			"Прислушаться к голосу",
			&"sq_fs_02_echo",
			echo_flags[index],
			[&"sq_fs_02_voice_heard"],
			echo_marker,
			echo_texts[index],
			Color(0.36, 0.72, 0.78, 1.0)
		)
	var polyp_marker := _marker(&"SQ_FS_02/Polyp")
	if polyp_marker != null:
		_add_polyp(polyp_marker)
	var cloak_marker := _marker(&"SQ_FS_02/Cloak")
	if cloak_marker != null:
		_add_pickup(
			&"SQ02_Cloak", &"sq_fs_02_cloak", "Забрать плащ Лиссы",
			&"sq_fs_02_lissa_cloak", 1, &"", 0,
			&"sq_fs_02_cloak_taken", &"interacted", &"sq_fs_02_cloak",
			"Плащ Лиссы. Тела нет. Застёжка совпадает с жетоном.",
			[&"sq_fs_02_polyp_dead", &"sq_fs_02_voice_heard"], &"", cloak_marker
		)
	var core_marker := _marker(&"SQ_FS_02/Core")
	if core_marker != null:
		_add_pickup(
			&"SQ02_EchoCore", &"sq_fs_02_echo_core", "Забрать ядро пересмешника",
			&"sq_fs_02_echo_core", 1, &"", 0,
			&"sq_fs_02_echo_core_taken", &"interacted", &"sq_fs_02_echo_core",
			"Ядро пересмешника ещё пульсирует.",
			[&"sq_fs_02_polyp_dead", &"sq_fs_02_voice_heard"], &"", core_marker
		)


func _on_run_flag_changed(flag_name: StringName, value: bool) -> void:
	if not value:
		return
	if QuestSystem.active_scope != SQ_SCOPE:
		return
	if flag_name == &"sq_fs_02_echo_a" or flag_name == &"sq_fs_02_echo_b" or flag_name == &"sq_fs_02_echo_c":
		_sync_echo_found(true)
	elif flag_name == &"sq_fs_02_polyp_dead":
		_set_flag_once(&"sq_fs_02_tunnel_safe")
	elif flag_name == &"sq_fs_05_alpha_dead":
		NightmareRunState.clear_flag(&"sq_fs_05_alpha_spared")
		_set_flag_once(&"sq_fs_05_low_route_safe")
		# KILL-событие приходит после credit_flag. Не завершаем активный SQ-05
		# раньше, иначе необязательная цель kill_alpha останется с прогрессом 0.
		if QuestSystem.is_active(&"sq_fs_05_bone_bridge_master"):
			call_deferred(&"_repair_alpha_kill")
		else:
			_set_flag_once(&"sq_fs_05_resolved")
	_refresh_inspectables()
	_refresh_fallback_clues()
	_retry_overlapping_triggers()


## A04-адаптер не обязан сам слушать flags; держим enabled в согласии с
## required_flags/completion_flag, не создавая второй inspect-фреймворк.
func _refresh_inspectables() -> void:
	for record in _inspectables:
		var node := record.get("node") as Node
		if node == null or not is_instance_valid(node):
			continue
		var completion := StringName(record.get("completion_flag", &""))
		var enabled := completion == &"" or not NightmareRunState.has_flag(completion)
		if enabled:
			var required: Array[StringName] = []
			for flag in record.get("required_flags", []):
				required.append(StringName(flag))
			enabled = NightmareRunState.require(required)
		node.set(&"enabled", enabled)


## Игрок мог стоять в зоне, когда prerequisite-флаг ещё не был выставлен.
## body_entered в таком случае уже не повторится — перепроверяем overlap.
func _refresh_fallback_clues() -> void:
	for record in _fallback_clues:
		var root := record.get("node") as Node3D
		var interactable := record.get("interactable") as Interactable
		var material := record.get("material") as StandardMaterial3D
		if root == null or not is_instance_valid(root):
			continue
		if interactable == null or not is_instance_valid(interactable):
			continue
		var completion := StringName(record.get("completion_flag", &""))
		var completed := completion != &"" and NightmareRunState.has_flag(completion)
		var required: Array[StringName] = []
		for flag in record.get("required_flags", []):
			required.append(StringName(flag))
		var available := NightmareRunState.require(required)
		root.visible = completed or available
		interactable.enabled = available and not completed
		if material != null:
			var color: Color = record.get("color", Color(0.55, 0.78, 0.82, 1.0))
			material.albedo_color = color.darkened(0.65) if completed else color
			material.emission_energy_multiplier = 0.16 if completed else 0.9


func _on_clue_interacted(
	_interaction_id: StringName,
	completion_flag: StringName,
	quest_subject: StringName,
	text: String
) -> void:
	if completion_flag != &"" and NightmareRunState.has_flag(completion_flag):
		return
	if completion_flag != &"":
		NightmareRunState.set_flag(completion_flag)
	if quest_subject != &"":
		QuestSystem.notify_event(&"interacted", quest_subject, 1)
	if not text.is_empty():
		QuestSystem.show_message(text, &"info")
	_refresh_fallback_clues()


func _retry_overlapping_triggers() -> void:
	for zone in _triggers:
		if zone == null or not is_instance_valid(zone) or not zone.enabled:
			continue
		if zone.set_flag != &"" and NightmareRunState.has_flag(zone.set_flag):
			continue
		if not NightmareRunState.require(zone.required_flags):
			continue
		for body in zone.get_overlapping_bodies():
			if body.is_in_group(&"player"):
				zone.fire()
				break


func _on_quest_started(quest: QuestDefinition) -> void:
	if quest == null or quest.scope != SQ_SCOPE:
		return
	_sync_started_flags()
	if quest.id == &"sq_fs_02_echo_tunnel":
		_repair_early_polyp_kill()
	elif quest.id == &"sq_fs_04_salt_box":
		_sync_sq04_tide()
	elif quest.id == &"sq_fs_05_bone_bridge_master":
		_repair_alpha_kill()


## SQ-01 стартует из QuestPickup, а не из QuestTriggerZone, поэтому флаг
## started нужно выставлять по сигналу QuestSystem, иначе следы/Тео закрыты.
func _sync_started_flags() -> void:
	_ensure_started(&"sq_fs_01_ninth_token", &"sq_fs_01_started")
	_ensure_started(&"sq_fs_02_echo_tunnel", &"sq_fs_02_started")
	_ensure_started(&"sq_fs_03_truth_without_lies", &"sq_fs_03_started")
	_ensure_started(&"sq_fs_04_salt_box", &"sq_fs_04_started")
	_ensure_started(&"sq_fs_05_bone_bridge_master", &"sq_fs_05_started")


func _ensure_started(quest_id: StringName, started_flag: StringName) -> void:
	if QuestSystem.get_state(quest_id) == &"":
		return
	_set_flag_once(started_flag)


func _sync_derived_flags() -> void:
	_sync_started_flags()
	_sync_echo_found(false)
	if NightmareRunState.has_flag(&"sq_fs_02_polyp_dead"):
		_set_flag_once(&"sq_fs_02_tunnel_safe")
	if NightmareRunState.has_flag(&"sq_fs_05_alpha_dead"):
		NightmareRunState.clear_flag(&"sq_fs_05_alpha_spared")
		_set_flag_once(&"sq_fs_05_low_route_safe")


func _sync_echo_found(announce: bool) -> void:
	if not _all_echoes_found():
		return
	if _set_flag_once(&"sq_fs_02_polyp_found") and announce:
		QuestSystem.show_message("Три эха сходятся вверху: источник над световой щелью.", &"quest")


func _all_echoes_found() -> bool:
	return (
		NightmareRunState.has_flag(&"sq_fs_02_echo_a")
		and NightmareRunState.has_flag(&"sq_fs_02_echo_b")
		and NightmareRunState.has_flag(&"sq_fs_02_echo_c")
	)


func _set_flag_once(flag_name: StringName) -> bool:
	if NightmareRunState.has_flag(flag_name):
		return false
	NightmareRunState.set_flag(flag_name)
	return true


## Если полипа убили до старта SQ-02, KILL-цель стартует с нулём и не может
## быть закрыта повторно. Восстанавливаем её по уже установленному флагу.
func _repair_early_polyp_kill() -> void:
	if not QuestSystem.is_active(&"sq_fs_02_echo_tunnel"):
		return
	if not NightmareRunState.has_flag(&"sq_fs_02_polyp_dead"):
		return
	if QuestSystem.get_objective_progress(&"sq_fs_02_echo_tunnel", &"destroy_polyp") >= 1:
		return
	QuestSystem.notify_event(&"killed", &"echo_polyp", 1)


func _repair_alpha_kill() -> void:
	if not NightmareRunState.has_flag(&"sq_fs_05_alpha_dead"):
		return
	if not QuestSystem.is_active(&"sq_fs_05_bone_bridge_master"):
		_set_flag_once(&"sq_fs_05_resolved")
		return
	if QuestSystem.get_objective_progress(&"sq_fs_05_bone_bridge_master", &"kill_alpha") < 1:
		QuestSystem.notify_event(&"killed", &"sq_fs_05_old_shell", 1)
	_set_flag_once(&"sq_fs_05_resolved")


func _add_polyp(marker: Node3D) -> void:
	if NightmareRunState.has_flag(&"sq_fs_02_polyp_dead"):
		return
	var path := "res://scenes/enemies/echo_polyp.tscn"
	if not ResourceLoader.exists(path):
		push_warning("LabyrinthNarrativeDirector: echo_polyp.tscn отсутствует; SQ-02 ждёт A05.")
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var polyp := packed.instantiate() as Node3D
	if polyp == null:
		return
	polyp.name = "SQ02_EchoPolyp"
	_runtime.add_child(polyp)
	polyp.global_position = marker.global_position
	var credit := QuestKillCredit.new()
	credit.name = "QuestKillCredit"
	credit.enemy_tag = &"echo_polyp"
	credit.credit_flag = &"sq_fs_02_polyp_dead"
	polyp.add_child(credit)


# ---------------------------------------------------------------------------
# SQ-03 «Правда без лжи»
# ---------------------------------------------------------------------------

func _build_sq_03() -> void:
	var return_marker := _marker(&"SQ_FS_03/TheoReturn")
	if return_marker != null:
		var return_npc := _add_npc(
			&"SQ03_TheoReturn", &"theo_return", "Тео",
			[&"sq_fs_02_complete"], &"sq_fs_03_returned",
			&"sq_fs_03_truth_without_lies", "mass_male", 0.96,
			THEO_RETURN_DIALOGUE_CANDIDATES,
			return_marker, false, false
		)
		if return_npc != null and not return_npc.dialogue_finished.is_connected(_on_sq03_dialogue_finished):
			return_npc.dialogue_finished.connect(_on_sq03_dialogue_finished)
	var cord_marker := _marker(&"SQ_FS_03/Cord")
	if cord_marker != null:
		_add_pickup(
			&"SQ03_Cord", &"sq_fs_03_cord", "Забрать нить Лиссы",
			&"sq_fs_03_lissa_cord", 1, &"", 0,
			&"sq_fs_03_cord_taken", &"interacted", &"sq_fs_03_cord",
			"Нить Лиссы. Тео завязал ею руку.",
			[&"sq_fs_03_choice_truth"], &"", cord_marker
		)
	var cache_marker := _marker(&"SQ_FS_03/Cache")
	if cache_marker != null:
		_add_pickup(
			&"SQ03_Cache", &"sq_fs_03_cache", "Открыть тайник",
			&"sq_fs_03_lissa_letter", 1, &"soul_shard", 1,
			&"sq_fs_03_cache_open", &"interacted", &"sq_fs_03_cache",
			"Письмо Лиссы и один осколок души.",
			[&"sq_fs_03_cache_allowed"], &"", cache_marker
		)
	var token_marker := _marker(&"SQ_FS_03/Token")
	if token_marker != null:
		_add_pickup(
			&"SQ03_TheoToken", &"sq_fs_03_theo_token", "Забрать жетон Тео",
			&"sq_fs_03_theo_token", 1, &"", 0,
			&"sq_fs_03_theo_token_found", &"interacted", &"sq_fs_03_theo_token",
			"Жетон Тео. Он ушёл искать сестру.",
			[&"sq_fs_03_theo_left"], &"", token_marker
		)


# ---------------------------------------------------------------------------
# P1/P2 hooks: данные уже есть, runtime ждёт A04/A05.
# ---------------------------------------------------------------------------

func _build_sq_04() -> void:
	var root := _marker(&"SQ_FS_04")
	if root == null:
		push_warning("LabyrinthNarrativeDirector: нет маркеров SQ_FS_04; квест недоступен.")
		return
	var ledge := _marker(&"SQ_FS_04/Ledge")
	if ledge != null:
		_add_trigger(
			&"SQ04_Ledge", &"sq_fs_04_ledge", &"sq_fs_04_ledge",
			&"sq_fs_04_salt_box", [], 4.0, ledge
		)
	var low_sill := _marker(&"SQ_FS_04/LowSill")
	if low_sill != null:
		_add_trigger(
			&"SQ04_LowSill", &"sq_fs_04_ledge", &"sq_fs_04_ledge",
			&"sq_fs_04_salt_box", [], 3.0, low_sill
		)
	var levers := _marker(&"SQ_FS_04/Levers")
	if levers != null:
		for lever_name in ["A", "B", "C"]:
			var marker := levers.get_node_or_null(NodePath(lever_name)) as Node3D
			if marker == null:
				continue
			var lever := LEVER_SCRIPT.new() as Node3D
			if lever == null:
				continue
			lever.name = StringName("SQ04_Lever%s" % lever_name)
			lever.set(&"lever_id", StringName(lever_name.to_lower()))
			lever.set(&"prompt", "Переключить рычаг %s" % lever_name)
			lever.set(&"radius", 2.0)
			lever.set(&"required_flags", [&"sq_fs_04_started", &"sq_fs_04_low_tide"])
			lever.set(&"initial_high", lever_name != "B")
			lever.set(&"director_path", get_path())
			_runtime.add_child(lever)
			lever.global_position = marker.global_position
	var box_marker := _marker(&"SQ_FS_04/Box")
	if box_marker != null:
		_add_inspectable(
			&"SQ04_Box", &"sq_fs_04_box_open", "Открыть соляной ящик",
			&"sq_fs_04_box_open", &"sq_fs_04_box_open",
			[&"sq_fs_04_low_tide", &"sq_fs_04_levers_correct"], box_marker,
			"Крышка тяжёлая. Под ней — карта прилива и два осколка.",
			Color(0.78, 0.66, 0.42, 1.0)
		)
	var chart_marker := _marker(&"SQ_FS_04/Chart")
	if chart_marker != null:
		_add_inspectable(
			&"SQ04_Chart", &"sq_fs_04_chart", "Прочитать карту прилива",
			&"sq_fs_04_chart", &"sq_fs_04_chart",
			[&"sq_fs_04_box_open"], chart_marker,
			"Карта отмечает низкую воду и три рычага.",
			Color(0.64, 0.74, 0.86, 1.0)
		)
	var tide := get_node_or_null(^"../../Tide/TideController")
	if tide != null:
		_tide = tide
		if tide.has_signal(&"tide_changed") and not tide.tide_changed.is_connected(_on_sq04_tide_changed):
			tide.tide_changed.connect(_on_sq04_tide_changed)
		_sync_sq04_tide()


func _on_sq04_tide_changed(_high: bool) -> void:
	_sync_sq04_tide()


func _sync_sq04_tide() -> void:
	if _tide == null or not _tide.has_method(&"is_high_water"):
		return
	var active := QuestSystem.is_active(&"sq_fs_04_salt_box") or NightmareRunState.has_flag(&"sq_fs_04_started")
	if not active:
		return
	if _tide.call(&"is_high_water"):
		NightmareRunState.clear_flag(&"sq_fs_04_low_tide")
	else:
		NightmareRunState.set_flag(&"sq_fs_04_low_tide")


## Called by QuestLever after every pull. Correct combination: A=LOW, B=HIGH, C=LOW.
func evaluate_sq04_levers() -> void:
	var a_high := NightmareRunState.has_flag(&"sq_fs_04_lever_a_high")
	var b_high := NightmareRunState.has_flag(&"sq_fs_04_lever_b_high")
	var c_high := NightmareRunState.has_flag(&"sq_fs_04_lever_c_high")
	if not a_high and b_high and not c_high:
		NightmareRunState.set_flag(&"sq_fs_04_levers_correct")
	else:
		NightmareRunState.clear_flag(&"sq_fs_04_levers_correct")


func _build_sq_05() -> void:
	var bridge_marker := _marker(&"SQ_FS_05/Bridge")
	if bridge_marker != null:
		_add_trigger(
			&"SQ05_Bridge", &"sq_fs_05_bridge", &"sq_fs_05_started",
			&"sq_fs_05_bone_bridge_master", [], 4.0, bridge_marker
		)
	var trail_marker := _marker(&"SQ_FS_05/Trail")
	if trail_marker != null:
		_add_trigger(
			&"SQ05_Trail", &"sq_fs_05_trail", &"sq_fs_05_started",
			&"sq_fs_05_bone_bridge_master", [], 3.0, trail_marker
		)
		_add_inspectable(
			&"SQ05_TrailMarks", &"sq_fs_05_trail", "Осмотреть следы",
			&"sq_fs_05_trail", &"sq_fs_05_trail_found",
			[&"sq_fs_05_started"], trail_marker,
			"Клешни больше обычных. Панцирь треснул.",
			Color(0.70, 0.58, 0.36, 1.0)
		)
	var lair_marker := _marker(&"SQ_FS_05/Lair")
	if lair_marker != null:
		_add_inspectable(
			&"SQ05_Lair", &"sq_fs_05_lair", "Осмотреть логово",
			&"sq_fs_05_lair", &"sq_fs_05_lair_found",
			[&"sq_fs_05_started"], lair_marker,
			"Логово под каналом. Здесь он ждёт воду.",
			Color(0.32, 0.56, 0.55, 1.0)
		)
	var carcass_marker := _marker(&"SQ_FS_05/Carcass")
	if carcass_marker != null:
		_add_pickup(
			&"SQ05_Chum", &"sq_fs_05_chum", "Взять приманку",
			&"sq_fs_05_chum", 1, &"", 0,
			&"sq_fs_05_chum_taken", &"interacted", &"sq_fs_05_chum",
			"Кусок мяса из туши. Пахнет достаточно сильно.",
			[&"sq_fs_05_started"], &"", carcass_marker
		)
	var bait_marker := _marker(&"SQ_FS_05/Bait")
	if bait_marker != null:
		_add_pickup(
			&"SQ05_BaitDrop", &"sq_fs_05_bait", "Сбросить приманку в канал",
			&"", 0, &"", 0,
			&"sq_fs_05_lured", &"interacted", &"sq_fs_05_bait",
			"Приманка уходит в воду. Что-то большое двигается внизу.",
			[&"sq_fs_05_chum_taken"], &"", bait_marker
		)
	var alpha_marker := _marker(&"SQ_FS_05/Alpha")
	if alpha_marker != null:
		_add_old_shell(alpha_marker)
	var west_marker := _marker(&"SQ_FS_05/WestEnd")
	if west_marker != null:
		var west := _add_trigger(
			&"SQ05_WestEnd", &"sq_fs_05_west_end", &"sq_fs_05_west_end_reached",
			&"", [], 4.0, west_marker
		)
		if west != null:
			west.triggered.connect(_on_sq05_west_end)
	var reward_marker := _marker(&"SQ_FS_05/Reward")
	if reward_marker != null:
		_add_pickup(
			&"SQ05_Reward", &"sq_fs_05_reward", "Забрать панцирный резец",
			&"sq_fs_05_shell_cutter", 1, &"soul_shard", 2,
			&"sq_fs_05_reward_taken", &"interacted", &"sq_fs_05_reward",
			"Панцирный резец и два осколка души.",
			[&"sq_fs_05_alpha_dead", &"sq_fs_05_started"], &"", reward_marker
		)
	var tide_bonus_marker := _marker(&"SQ_FS_05/TideBonus")
	if tide_bonus_marker != null:
		_add_pickup(
			&"SQ05_TideBonus", &"sq_fs_05_tide_bonus", "Забрать приливный осколок",
			&"", 0, &"soul_shard", 1,
			&"sq_fs_05_tide_bonus_taken", &"interacted", &"sq_fs_05_tide_bonus",
			"Осколок души, выброшенный приливом.",
			[&"sq_fs_05_tide_trap", &"sq_fs_05_started"], &"", tide_bonus_marker
		)


func _on_sq05_west_end(_id: StringName) -> void:
	var was_active := QuestSystem.is_active(&"sq_fs_05_bone_bridge_master")
	var already_resolved := NightmareRunState.has_flag(&"sq_fs_05_resolved")
	var alpha_dead := NightmareRunState.has_flag(&"sq_fs_05_alpha_dead")
	if alpha_dead:
		_repair_alpha_kill()
	else:
		NightmareRunState.set_flag(&"sq_fs_05_alpha_spared")
	NightmareRunState.set_flag(&"sq_fs_05_resolved")
	if was_active and not already_resolved:
		var text := "Мост пройден. Старый Панцирь остался внизу — низкий путь по-прежнему опасен."
		if alpha_dead:
			text = "Мост пройден. Старый Панцирь мёртв — низкий путь свободен."
		QuestSystem.show_message(text, &"quest")


func _on_sq05_alpha_credited(_tag: StringName) -> void:
	NightmareRunState.clear_flag(&"sq_fs_05_alpha_spared")
	NightmareRunState.set_flag(&"sq_fs_05_low_route_safe")
	NightmareRunState.set_flag(&"sq_fs_05_resolved")


func _add_old_shell(marker: Node3D) -> void:
	if NightmareRunState.has_flag(&"sq_fs_05_alpha_dead"):
		return
	var candidates: Array[String] = [
		"res://scenes/enemies/old_shell.tscn",
		"res://scenes/enemies/carapace_old_shell.tscn",
	]
	for path in candidates:
		if not ResourceLoader.exists(path):
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var alpha := packed.instantiate() as Node3D
		if alpha == null:
			continue
		alpha.name = "SQ05_OldShell"
		_runtime.add_child(alpha)
		alpha.global_position = marker.global_position
		var credit := QuestKillCredit.new()
		credit.name = "QuestKillCredit"
		credit.enemy_tag = &"sq_fs_05_old_shell"
		credit.credit_flag = &"sq_fs_05_alpha_dead"
		credit.credited.connect(_on_sq05_alpha_credited)
		alpha.add_child(credit)
		return
	push_warning("LabyrinthNarrativeDirector: Old Shell scene отсутствует; SQ-05 пока работает только через обход.")


# ---------------------------------------------------------------------------
# Общие адаптеры
# ---------------------------------------------------------------------------

func _add_trigger(
	node_name: StringName,
	trigger_id: StringName,
	set_flag: StringName,
	start_quest_id: StringName,
	required_flags: Array[StringName],
	radius: float,
	marker: Node3D
) -> QuestTriggerZone:
	var zone := QuestTriggerZone.new()
	zone.name = StringName("Narrative_%s" % node_name)
	zone.trigger_id = trigger_id
	zone.quest_subject = trigger_id
	zone.quest_event = &"reached"
	zone.set_flag = set_flag
	zone.start_quest_id = start_quest_id
	zone.required_flags = required_flags
	# Одноразовый триггер не должен срабатывать повторно после загрузки.
	zone.enabled = set_flag == &"" or not NightmareRunState.has_flag(set_flag)
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	zone.add_child(shape)
	_runtime.add_child(zone)
	zone.global_position = marker.global_position + Vector3.UP * 1.2
	_triggers.append(zone)
	return zone


func _add_pickup(
	node_name: StringName,
	interaction_id: StringName,
	prompt: String,
	item_id: StringName,
	item_count: int,
	currency_id: StringName,
	currency_amount: int,
	pickup_flag: StringName,
	quest_event: StringName,
	quest_subject: StringName,
	pickup_text: String,
	required_flags: Array[StringName],
	start_quest_id: StringName,
	marker: Node3D
) -> QuestPickup:
	var pickup := PICKUP_SCENE.instantiate() as QuestPickup
	if pickup == null:
		return null
	pickup.name = StringName("Narrative_%s" % node_name)
	pickup.interaction_id = interaction_id
	pickup.prompt = prompt
	pickup.visual_kind = "token" if item_id != &"" else "shard"
	pickup.item_id = item_id
	pickup.item_count = maxi(item_count, 1)
	pickup.currency_id = currency_id
	pickup.currency_amount = currency_amount
	pickup.pickup_flag = pickup_flag
	pickup.quest_event = quest_event
	pickup.quest_subject = quest_subject
	pickup.pickup_text = pickup_text
	pickup.required_flags = required_flags
	pickup.start_quest_id = start_quest_id
	_runtime.add_child(pickup)
	pickup.global_position = marker.global_position + Vector3.UP * 0.75
	pickup.reset_float_origin()
	return pickup


func _add_inspectable(
	node_name: StringName,
	interaction_id: StringName,
	prompt: String,
	quest_subject: StringName,
	completion_flag: StringName,
	required_flags: Array[StringName],
	marker: Node3D,
	fallback_text := "",
	clue_color := Color(0.55, 0.78, 0.82, 1.0)
) -> void:
	var script: Script = null
	for path in INSPECTABLE_SCRIPTS:
		if not ResourceLoader.exists(path):
			continue
		script = load(path) as Script
		if script != null:
			break
	if script != null:
		var node := script.new() as Node3D
		if node != null:
			node.name = StringName("Narrative_%s" % node_name)
			node.set(&"interaction_id", interaction_id)
			node.set(&"prompt", prompt)
			node.set(&"quest_event", &"interacted")
			node.set(&"quest_subject", quest_subject)
			node.set(&"completion_flag", completion_flag)
			node.set(&"required_flags", required_flags)
			node.set(&"enabled", true)
			_runtime.add_child(node)
			node.global_position = marker.global_position
			_inspectables.append({
				"node": node,
				"required_flags": required_flags,
				"completion_flag": completion_flag,
			})
			return
	# Fallback без A04: кольцо-улика остаётся в мире и гаснет после осмотра.
	if not _warned_missing_inspectable:
		push_warning("LabyrinthNarrativeDirector: QuestInspectable отсутствует; использую clue-ring адаптер.")
		_warned_missing_inspectable = true
	var text := fallback_text if not fallback_text.is_empty() else "Следы складываются в один путь."
	_add_fallback_clue(
		node_name, interaction_id, prompt, quest_subject, completion_flag,
		required_flags, marker, text, clue_color
	)


func _add_fallback_clue(
	node_name: StringName,
	interaction_id: StringName,
	prompt: String,
	quest_subject: StringName,
	completion_flag: StringName,
	required_flags: Array[StringName],
	marker: Node3D,
	text: String,
	clue_color: Color
) -> void:
	var root := Node3D.new()
	root.name = StringName("Narrative_%s" % node_name)
	_runtime.add_child(root)
	root.global_position = marker.global_position

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.22
	torus.outer_radius = 0.31
	torus.rings = 12
	torus.ring_segments = 24
	ring.mesh = torus
	ring.position = Vector3(0.0, 0.04, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = clue_color
	material.emission_enabled = true
	material.emission = clue_color
	material.emission_energy_multiplier = 0.9
	material.roughness = 0.35
	ring.material_override = material
	root.add_child(ring)

	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 0.28, 0.0)
	light.light_color = clue_color
	light.light_energy = 0.45
	light.omni_range = 2.0
	light.shadow_enabled = false
	root.add_child(light)

	var interactable := Interactable.new()
	interactable.name = "Interactable"
	interactable.interaction_id = interaction_id
	interactable.prompt = prompt
	interactable.radius = 2.0
	interactable.interact_cue = &"world_pickup"
	interactable.interact_volume_db = -6.0
	interactable.position = Vector3(0.0, 0.45, 0.0)
	interactable.enabled = NightmareRunState.require(required_flags)
	interactable.interacted.connect(
		_on_clue_interacted.bind(completion_flag, quest_subject, text)
	)
	root.add_child(interactable)

	_fallback_clues.append({
		"node": root,
		"interactable": interactable,
		"material": material,
		"required_flags": required_flags,
		"completion_flag": completion_flag,
		"color": clue_color,
	})
	_refresh_fallback_clues()


## A01 может ещё не поставить speaker names; не перезаписываем существующие.
func _ensure_sq_speakers() -> void:
	var runner := get_tree().get_first_node_in_group(&"dialogue_runner") as DialogueRunner
	if runner == null:
		return
	var names: Dictionary = runner.speaker_names
	if not names.has(&"theo"):
		names[&"theo"] = "Тео"
	if not names.has(&"theo_return"):
		names[&"theo_return"] = "Тео"
	if not names.has(&"lissa_echo"):
		names[&"lissa_echo"] = "Голос Лиссы"


## Временный fallback до A01. Если файл A01 существует, он имеет приоритет.
## Текст — утверждённые строки Design Package, без новых реплик.
func _theo_fallback_dialogue() -> DialogueSequence:
	var lines: Array = [
		[&"sunny", "Живой. В этом месте это уже странно."],
		[&"theo", "Не подходи. У меня нож."],
		[&"sunny", "Вижу. Держишь как ложку."],
		[&"theo", "Мне не до шуток."],
		[&"sunny", "Мне тоже. Это твой жетон? Он лежал у туши."],
		[&"theo", "Лисса. Это её. Она повела нас через риф."],
		[&"sunny", "Где она?"],
		[&"theo", "В туннеле. Я слышал её голос. Она звала меня. Я хотел идти, но нога..."],
		[&"sunny", "И ты сидел здесь. Один."],
		[&"theo", "Я не трус."],
		[&"sunny", "Я не говорил, что трус. Я сказал, что ты сидел."],
		[&"theo", "Найди её. Пожалуйста. Я отдам всё, что у меня есть."],
		[&"sunny", "Оставь себе. Мне нужен жетон и то, что ты видел."],
	]
	var sequence := DialogueSequence.new()
	for item in lines:
		var line := DialogueLine.new()
		line.speaker = item[0]
		line.text = item[1]
		sequence.lines.append(line)
	return sequence


func _add_npc(
	node_name: StringName,
	npc_id: StringName,
	display_name: String,
	required_flags: Array[StringName],
	completion_flag: StringName,
	start_quest_id: StringName,
	archetype: String,
	height_scale: float,
	dialogue_paths: Array[String],
	marker: Node3D,
	show_mannequin := true,
	one_shot := true,
	fallback_dialogue: DialogueSequence = null
) -> QuestNpc:
	var dialogue: DialogueSequence = null
	for path in dialogue_paths:
		if not ResourceLoader.exists(path):
			continue
		dialogue = load(path) as DialogueSequence
		if dialogue != null:
			break
	if dialogue == null:
		dialogue = fallback_dialogue
	if dialogue == null:
		push_warning("LabyrinthNarrativeDirector: нет диалога %s; NPC %s не создан." % [", ".join(dialogue_paths), npc_id])
		return null
	_ensure_sq_speakers()
	var npc := NPC_SCENE.instantiate() as QuestNpc
	if npc == null:
		return null
	npc.name = StringName("Narrative_%s" % node_name)
	npc.npc_id = npc_id
	npc.display_name = display_name
	npc.dialogue = dialogue
	npc.required_flags = required_flags
	npc.completion_flag = completion_flag
	npc.start_quest_id = start_quest_id
	npc.one_shot = one_shot
	_runtime.add_child(npc)
	npc.global_position = marker.global_position
	npc.rotation.y = marker.global_rotation.y
	var mannequin := npc.get_node_or_null(^"Mannequin") as Node3D
	if mannequin != null:
		mannequin.visible = show_mannequin
		mannequin.set(&"archetype", archetype)
		mannequin.set(&"height_scale", height_scale)
	var talk := npc.get_node_or_null(^"Interactable") as Interactable
	if talk != null:
		talk.interact_cue = &"ui_confirm"
		talk.interact_volume_db = -6.0
	return npc


func _ensure_choice_ui() -> void:
	if _choice_controller != null and is_instance_valid(_choice_controller):
		return
	var scene_root := get_parent().get_parent() as Node
	if scene_root == null:
		scene_root = get_tree().current_scene
	if scene_root == null:
		return
	_choice_panel = CHOICE_PANEL_SCENE.instantiate() as QuestChoicePanel
	if _choice_panel == null:
		return
	_choice_panel.name = "QuestChoicePanel"
	scene_root.add_child(_choice_panel)
	_choice_controller = QuestChoiceController.new()
	_choice_controller.name = "QuestChoiceController"
	add_child(_choice_controller)
	_choice_controller.set_panel(_choice_panel)
	_choice_controller.choice_selected.connect(_on_sq03_choice_selected)
	_choice_controller.closed.connect(_on_sq03_choice_closed)
	if not _choice_panel.closed.is_connected(_on_choice_panel_closed):
		_choice_panel.closed.connect(_on_choice_panel_closed)


func _on_sq03_dialogue_finished(npc_id: StringName) -> void:
	if npc_id != &"theo_return":
		return
	if QuestSystem.is_completed(&"sq_fs_03_truth_without_lies"):
		return
	if _choice_controller == null:
		push_warning("LabyrinthNarrativeDirector: choice controller не создан для SQ-03.")
		return
	var player := get_tree().get_first_node_in_group(&"player") as SunnyController
	if player != null:
		player.input_enabled = false
	var opened := _choice_controller.present("Что сказать Тео?", [
		{
			"id": &"truth",
			"text": "Сказать правду о Лиссе.",
			"flag": &"sq_fs_03_choice_truth",
		},
		{
			"id": &"omission",
			"text": "Скрыть часть правды.",
			"flag": &"sq_fs_03_choice_omission",
		},
		{
			"id": &"unknown",
			"text": "Сказать, что не знаешь.",
			"flag": &"sq_fs_03_choice_unknown",
		},
	])
	if not opened:
		_on_sq03_choice_closed()


func _on_sq03_choice_selected(choice_id: StringName) -> void:
	match choice_id:
		&"truth":
			NightmareRunState.set_flag(&"sq_fs_03_cache_allowed")
			NightmareRunState.set_flag(&"sq_fs_03_theo_stayed")
		&"omission":
			NightmareRunState.set_flag(&"sq_fs_03_theo_stayed")
		&"unknown":
			NightmareRunState.set_flag(&"sq_fs_03_theo_left")
		_:
			return
	NightmareRunState.set_flag(&"sq_fs_03_resolved")
	QuestSystem.notify_event(&"interacted", &"sq_fs_03_resolved", 1)


func _on_sq03_choice_closed() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as SunnyController
	if player != null:
		player.input_enabled = true


func _on_choice_panel_closed() -> void:
	if _choice_controller != null and _choice_controller.is_active():
		_choice_controller.close()


func _resolve_marker_root() -> Node3D:
	var candidates: Array[NodePath] = [
		marker_root,
		^"../Quests",
		^"../Narrative",
		^"../../Quests",
		^"../../Narrative",
	]
	for candidate in candidates:
		var node := get_node_or_null(candidate) as Node3D
		if node != null:
			return node
	return null


func _marker(relative_path: StringName) -> Node3D:
	if _markers == null:
		return null
	var node := _markers.get_node_or_null(NodePath(relative_path)) as Node3D
	if node == null:
		_missing_markers[String(relative_path)] = true
	return node


func _report_missing_markers() -> void:
	if _missing_markers.is_empty():
		return
	var names: Array[String] = []
	for key in _missing_markers.keys():
		names.append(String(key))
	names.sort()
	push_warning("LabyrinthNarrativeDirector: нет маркеров SQ: %s" % ", ".join(names))
