extends GutTest
## S07–S12: подъём, альков, смерть Шифти, Учёный, пещера, ранение,
## Silver Bell и переход к святилищу. Тесты гоняют логику локации без
## длинных диалогов оболочки; оболочка проверяется отдельно.

const LOCATION_SCENE := "res://scenes/locations/pilgrim_path/pilgrim_path.tscn"
const WRAPPER_SCENE := "res://scenes/campaign/pilgrim_path_arrival.tscn"
const BELL_SEQUENCE_PATH := "res://resources/dialogue/pilgrim/pilgrim_bell.tres"


func before_each() -> void:
	NightmareRunState.reset()


func after_each() -> void:
	NightmareRunState.reset()


func _make_location() -> Node3D:
	var site := (load(LOCATION_SCENE) as PackedScene).instantiate() as Node3D
	add_child_autofree(site)
	await wait_physics_frames(1)
	return site


func _make_wrapper(manual_bell := false) -> Node3D:
	var wrapper := (load(WRAPPER_SCENE) as PackedScene).instantiate() as Node3D
	for property in [&"fade_in", &"transition_enabled"]:
		for entry in wrapper.get_property_list():
			if StringName(entry.get("name", "")) == property:
				wrapper.set(property, false)
				break
	for entry in wrapper.get_property_list():
		if StringName(entry.get("name", "")) == &"fast_mode":
			wrapper.set(&"fast_mode", true)
			break
	if manual_bell:
		wrapper.set(&"bell_sequence", _manual_bell_sequence())
	add_child_autofree(wrapper)
	await wait_physics_frames(1)
	return wrapper


## Копия канонической последовательности, но с ручным продвижением:
## duration = 0 заставляет DialogueRunner ждать advance() на каждой реплике.
func _manual_bell_sequence() -> DialogueSequence:
	var source := load(BELL_SEQUENCE_PATH) as DialogueSequence
	assert_not_null(source, "каноническая последовательность Колокольчика загружается")
	var sequence := DialogueSequence.new()
	if source == null:
		return sequence
	for line in source.lines:
		var source_line := line as DialogueLine
		var copy := DialogueLine.new()
		copy.speaker = source_line.speaker
		copy.text = source_line.text
		copy.duration = 0.0
		sequence.lines.append(copy)
	return sequence


func _interact(site: Node3D, id: StringName) -> void:
	var point := site.call(&"get_interactable", id) as Interactable
	assert_not_null(point, "точка %s существует" % id)
	if point != null:
		point.interact()


func _trigger(site: Node3D, id: StringName) -> void:
	var zone := site.call(&"get_trigger", id) as TriggerZone
	assert_not_null(zone, "зона %s существует" % id)
	if zone != null:
		zone.fire()


func test_scene_has_cast_route_and_no_premature_completion() -> void:
	var site := await _make_location()
	assert_true(site.get_node("NPCs/Hero") is Mannequin)
	assert_true(site.get_node("NPCs/Shifty") is Mannequin)
	assert_true(site.get_node("NPCs/Scholar") is Mannequin)
	assert_false(site.get_node("NPCs/ShiftyBody").visible, "тело Шифти скрыто до падения")
	assert_false(site.get_node("Props/BloodStain").visible, "кровь появляется только после падения")
	assert_false(site.get_node("NPCs/TyrantSighting").visible, "Тиран не виден до ночи")
	assert_true((site.call(&"get_trigger", &"road_gap") as TriggerZone).enabled)
	assert_false((site.call(&"get_trigger", &"sword") as TriggerZone).enabled)
	assert_false((site.call(&"get_trigger", &"rest") as TriggerZone).enabled)
	assert_false((site.call(&"get_interactable", &"bell") as Interactable).enabled)
	assert_false((site.call(&"get_trigger", &"temple") as TriggerZone).enabled)
	assert_false(NightmareRunState.has_flag(&"first_nightmare_completed"))
	assert_false(NightmareRunState.has_flag(&"tyrant_death_confirmed"))


func test_trail_keeps_e_only_for_the_bell_act() -> void:
	var site := await _make_location()
	for id in [&"road_gap", &"sword", &"rest", &"scholar", &"cave", &"cave_exit", &"hero"]:
		assert_null(site.call(&"get_interactable", id), "у %s больше нет E-точки" % id)
		assert_not_null(site.call(&"get_trigger", id), "у %s есть зона прохода" % id)
	assert_not_null(site.call(&"get_interactable", &"bell"), "Колокольчик остаётся поступком")
	assert_null(site.call(&"get_interactable", &"temple"), "храм остаётся триггером")


func test_art_trail_keeps_the_trigger_conversion() -> void:
	var site := (load("res://scenes/locations/pilgrim_path/pilgrim_path_art.tscn") as PackedScene).instantiate() as PilgrimPath
	add_child_autofree(site)
	await wait_physics_frames(1)
	for id in [&"road_gap", &"sword", &"rest", &"scholar", &"cave", &"cave_exit", &"hero"]:
		assert_null(site.get_interactable(id), "арт-тропа не возвращает E-точку %s" % id)
		assert_not_null(site.get_trigger(id), "арт-тропа сохраняет зону %s" % id)
	assert_not_null(site.get_interactable(&"bell"), "Колокольчик остаётся E-поступком")


func test_route_requires_each_canonical_step_once() -> void:
	var site := await _make_location()
	var gap := site.call(&"get_trigger", &"road_gap") as TriggerZone
	var sword := site.call(&"get_trigger", &"sword") as TriggerZone
	var rest := site.call(&"get_trigger", &"rest") as TriggerZone
	var scholar := site.call(&"get_trigger", &"scholar") as TriggerZone
	var cave := site.call(&"get_trigger", &"cave") as TriggerZone
	var cave_exit := site.call(&"get_trigger", &"cave_exit") as TriggerZone
	var hero := site.call(&"get_trigger", &"hero") as TriggerZone
	var bell := site.call(&"get_interactable", &"bell") as Interactable
	var temple := site.call(&"get_trigger", &"temple") as TriggerZone

	assert_true(gap.enabled, "провал открыт с самого начала")
	assert_false(sword.enabled, "меч недоступен до осмотра провала")
	_trigger(site, &"road_gap")
	assert_true(NightmareRunState.has_flag(&"road_gap_seen"))
	assert_true(sword.enabled, "после провала открывается верхняя площадка с мечом")

	_trigger(site, &"sword")
	assert_true(NightmareRunState.has_flag(&"sword_discarded"))
	assert_false(site.get_node("Props/Sword").visible, "меч остаётся на камне")
	assert_true(rest.enabled, "после меча открывается альков")

	_trigger(site, &"rest")
	assert_true(NightmareRunState.has_flag(&"alcove_reached"))
	assert_false(rest.enabled, "альков одноразовый")
	assert_false(NightmareRunState.has_flag(&"shifty_dead"), "ночь ещё не убила Шифти")
	assert_false(scholar.enabled, "Учёный ждёт рассвета")

	# Ночная постановка оболочки вызывает эти два шага.
	watch_signals(site)
	site.call(&"kill_shifty")
	assert_true(NightmareRunState.has_flag(&"shifty_dead"))
	assert_false(site.get_node("NPCs/Shifty").visible, "Шифти исчезает после падения")
	assert_false(site.get_node("NPCs/ShiftyBody").visible, "тело Шифти не показывается")
	assert_true(site.get_node("Props/BloodStain").visible, "на камне остаётся кровь")
	assert_signal_not_emitted(site, "hint_requested", "констатация о крови не возвращается")
	var thought := (get_node_or_null("/root/CampaignGuide") as Node)
	assert_not_null(thought, "система подсказок доступна")
	if thought != null:
		assert_string_contains(thought.call(&"get_thought_text", &"thought_scholar"), "Кровь")
	assert_false(scholar.enabled, "Учёный ждёт N18, а не только смерти Шифти")
	NightmareRunState.set_flag(&"shifty_larva_killed")
	site.call(&"begin_dawn")
	assert_true(scholar.enabled, "после N18 на рассвете открывается Учёный")

	_trigger(site, &"scholar")
	assert_true(NightmareRunState.has_flag(&"scholar_confronted"))
	assert_true(cave.enabled, "вход в пещеру доступен, но требует ухода Учёного")
	site.call(&"abandon_scholar")
	assert_true(NightmareRunState.has_flag(&"scholar_abandoned"))
	assert_false(site.get_node("NPCs/Scholar").visible, "Учёный не возвращается")
	assert_true(cave.enabled, "после Учёного открывается пещера")

	_trigger(site, &"cave")
	assert_true(NightmareRunState.has_flag(&"cave_entered"))
	assert_false(cave_exit.enabled, "из пещеры нельзя выйти до ранения")
	assert_false(NightmareRunState.has_flag(&"hero_dead"), "Герой ещё жив в пещере")
	site.call(&"mark_confession")
	site.call(&"wound_sunny")
	assert_true(NightmareRunState.has_flag(&"wound_taken"))
	assert_true(cave_exit.enabled, "после ранения открыт северный выход")

	_trigger(site, &"cave_exit")
	assert_true(NightmareRunState.has_flag(&"cave_escaped"))
	assert_false(hero.enabled, "после пещеры сначала идёт стелс N21")
	assert_false(NightmareRunState.has_flag(&"hero_dead"), "встреча с Героем не убивает его заранее")
	NightmareRunState.set_flag(&"stealth_completed")
	site.call(&"prepare_route")
	assert_true(hero.enabled, "после завершения стелса Герой ждёт на карнизе")

	_trigger(site, &"hero")
	assert_true(NightmareRunState.has_flag(&"hero_confrontation_seen"))
	assert_true(bell.enabled, "после разговора доступен Колокольчик")
	assert_false(NightmareRunState.has_flag(&"hero_dead"))
	assert_false(temple.enabled, "храм закрыт до звонка")
	NightmareRunState.add_item(&"silver_bell", 1)

	_interact(site, &"bell")
	assert_true(NightmareRunState.has_flag(&"silver_bell_used"))
	assert_true(NightmareRunState.has_item(&"silver_bell"), "Колокольчик остаётся Памятью")
	assert_false(NightmareRunState.has_flag(&"hero_taken"), "звонок сам по себе не начинает захват")
	assert_false(NightmareRunState.has_flag(&"hero_dead"))
	assert_false(bell.enabled, "Колокольчик больше не используется")
	assert_true(site.get_node("NPCs/Hero").visible, "Герой виден до реплики захвата")
	assert_false(site.get_node("NPCs/TyrantAtHero").visible)
	assert_false(site.get_node("Props/TempleGlow").visible)
	assert_false(temple.enabled, "храм закрыт до захвата")

	# В реальной сцене эти шаги вызывает оболочка на репликах bell_sequence.
	site.call(&"turn_hero_toward_bell")
	site.call(&"begin_hero_capture")
	assert_true(NightmareRunState.has_flag(&"hero_taken"))
	assert_false(NightmareRunState.has_flag(&"hero_dead"), "захват ещё идёт")
	assert_false(site.get_node("NPCs/Hero").visible, "Герой больше не стоит на тропе")
	assert_true(site.get_node("NPCs/TyrantAtHero").visible, "Тиран забирает Героя")
	assert_false(site.get_node("Props/TempleGlow").visible)
	assert_false(temple.enabled, "храм не открывается в момент захвата")

	site.call(&"complete_hero_capture")
	assert_true(NightmareRunState.has_flag(&"hero_dead"))
	assert_false(site.get_node("NPCs/TyrantAtHero").visible, "после захвата Тиран скрыт")
	assert_true(site.get_node("Props/TempleGlow").visible, "после захвата виден храм")
	assert_true(temple.enabled, "после гибели Героя открыт храм")
	assert_false(NightmareRunState.has_flag(&"first_nightmare_completed"))

	# Mark of Divinity выставляется на B16 штатно (slice_director); пролог здесь не проигрывается.
	NightmareRunState.set_flag(&"mark_of_divinity")
	temple.fire()
	assert_true(NightmareRunState.has_flag(&"temple_reached"))
	assert_eq(site.phase, &"COMPLETE")
	assert_false(temple.enabled, "храм срабатывает один раз")
	temple.fire()
	assert_true(NightmareRunState.has_flag(&"temple_reached"))
	assert_false(NightmareRunState.has_flag(&"first_nightmare_completed"),
		"даже вход в храм не подтверждает смерть Тирана")


func test_interactions_do_not_retrigger_or_unlock_out_of_order() -> void:
	var site := await _make_location()
	var sword := site.call(&"get_trigger", &"sword") as TriggerZone
	var rest := site.call(&"get_trigger", &"rest") as TriggerZone
	var bell := site.call(&"get_interactable", &"bell") as Interactable
	var temple := site.call(&"get_trigger", &"temple") as TriggerZone

	_trigger(site, &"sword")
	assert_false(NightmareRunState.has_flag(&"sword_discarded"), "меч нельзя бросить до провала")
	_trigger(site, &"rest")
	assert_false(NightmareRunState.has_flag(&"alcove_reached"), "альков закрыт")
	_interact(site, &"bell")
	assert_false(NightmareRunState.has_flag(&"silver_bell_used"), "Колокольчик закрыт")
	temple.fire()
	assert_false(NightmareRunState.has_flag(&"temple_reached"), "храм закрыт")

	_trigger(site, &"road_gap")
	_trigger(site, &"road_gap")
	_trigger(site, &"sword")
	_trigger(site, &"sword")
	assert_true(NightmareRunState.has_flag(&"road_gap_seen"))
	assert_true(NightmareRunState.has_flag(&"sword_discarded"))
	assert_eq(site.phase, &"ASCENT")


func test_persistent_absence_after_ascent_reload() -> void:
	var site := await _make_location()
	_trigger(site, &"road_gap")
	_trigger(site, &"sword")
	_trigger(site, &"rest")
	site.call(&"kill_shifty")
	site.call(&"begin_dawn")
	_trigger(site, &"scholar")
	site.call(&"abandon_scholar")
	_trigger(site, &"cave")
	site.call(&"wound_sunny")
	_trigger(site, &"cave_exit")
	NightmareRunState.set_flag(&"stealth_completed")
	site.call(&"prepare_route")
	_trigger(site, &"hero")
	_interact(site, &"bell")
	site.call(&"begin_hero_capture")
	site.call(&"complete_hero_capture")

	var reloaded := await _make_location()
	assert_false(reloaded.get_node("NPCs/Shifty").visible, "Шифти не возвращается после перезагрузки")
	assert_false(reloaded.get_node("NPCs/ShiftyBody").visible, "тело не возвращается после перезагрузки")
	assert_true(reloaded.get_node("Props/BloodStain").visible, "кровь остаётся после перезагрузки")
	reloaded.call(&"prepare_route")
	assert_false(reloaded.get_node("NPCs/ShiftyBody").visible,
		"повторная подготовка маршрута не показывает тело")
	assert_true(reloaded.get_node("Props/BloodStain").visible,
		"повторная подготовка маршрута сохраняет кровь")
	assert_false(reloaded.get_node("NPCs/Scholar").visible, "Учёный не возвращается")
	assert_false(reloaded.get_node("NPCs/Hero").visible, "Герой не возвращается")
	assert_false(reloaded.get_node("NPCs/TyrantAtHero").visible, "Тиран у места захвата скрыт")
	assert_true(reloaded.get_node("Props/TempleGlow").visible, "храм остаётся видимым")
	assert_true(NightmareRunState.has_flag(&"hero_dead"))
	assert_eq(reloaded.phase, &"TEMPLE")
	assert_true((reloaded.call(&"get_trigger", &"temple") as TriggerZone).enabled,
		"после возврата храм остаётся доступен")
	assert_false(NightmareRunState.has_flag(&"first_nightmare_completed"))


func test_bell_dialogue_orders_turn_capture_and_temple_glow() -> void:
	var canonical := load(BELL_SEQUENCE_PATH) as DialogueSequence
	assert_not_null(canonical)
	if canonical == null:
		return
	assert_eq(canonical.lines.size(), 9)
	assert_string_contains((canonical.lines[1] as DialogueLine).text, "оборачивается")
	assert_string_contains((canonical.lines[2] as DialogueLine).text, "Прекрати")
	assert_string_contains((canonical.lines[3] as DialogueLine).text, "Тиран уже рядом")
	assert_string_contains((canonical.lines[8] as DialogueLine).text, "Храм уже виден")

	NightmareRunState.set_flag(&"cave_escaped")
	NightmareRunState.set_flag(&"hero_confrontation_seen")
	NightmareRunState.add_item(&"silver_bell", 1)
	var wrapper := await _make_wrapper(true)
	var site := wrapper.get_node("PilgrimPath") as Node3D
	var hero := site.get_node("NPCs/Hero") as Node3D
	var tyrant := site.get_node("NPCs/TyrantAtHero") as Node3D
	var glow := site.get_node("Props/TempleGlow") as Node3D
	var bell := site.call(&"get_interactable", &"bell") as Interactable
	var temple := site.call(&"get_trigger", &"temple") as TriggerZone
	var dialogue := wrapper.get_node("DialogueRunner") as DialogueRunner
	assert_not_null(bell)
	assert_not_null(temple)
	assert_not_null(dialogue)
	if bell == null or temple == null or dialogue == null:
		return

	assert_true(hero.visible, "до звонка Герой виден")
	assert_false(tyrant.visible, "до звонка Тиран у Героя скрыт")
	assert_false(glow.visible, "до захвата храм не подсвечен")
	assert_false(NightmareRunState.has_flag(&"hero_taken"))
	assert_false(NightmareRunState.has_flag(&"hero_dead"))

	var seen_lines: Array[int] = []
	dialogue.line_started.connect(func(_line: DialogueLine, index: int, _count: int) -> void:
		seen_lines.append(index)
	)
	var rotation_before := hero.rotation.y
	bell.interact()
	assert_true(dialogue.running, "звонок запускает последовательность")
	assert_eq(seen_lines.size(), 1)
	assert_eq(seen_lines[0], 0)
	assert_false(bell.enabled, "Колокольчик больше не используется")
	assert_false(NightmareRunState.has_flag(&"hero_taken"), "начало сцены не захватывает Героя")
	assert_false(NightmareRunState.has_flag(&"hero_dead"))
	assert_true(hero.visible)
	assert_false(tyrant.visible)
	assert_false(temple.enabled, "храм закрыт до захвата")

	# Реплика 1: «Герой оборачивается».
	dialogue.advance()
	assert_eq(seen_lines.size(), 2)
	assert_true(hero.visible, "на реплике оборачивания Герой ещё виден")
	assert_false(is_equal_approx(hero.rotation.y, rotation_before), "Герой развернулся")
	assert_almost_eq(hero.rotation.y, 0.0, 0.001)
	assert_false(NightmareRunState.has_flag(&"hero_taken"))

	# Реплика 2: «Прекрати».
	dialogue.advance()
	assert_eq(seen_lines.size(), 3)
	assert_true(hero.visible, "на «Прекрати» Герой ещё виден")
	assert_false(tyrant.visible)
	assert_false(NightmareRunState.has_flag(&"hero_taken"))
	assert_false(NightmareRunState.has_flag(&"hero_dead"))

	# Реплика 3: «Тиран уже рядом» — начало захвата.
	dialogue.advance()
	assert_eq(seen_lines.size(), 4)
	assert_true(NightmareRunState.has_flag(&"hero_taken"), "Тиран появляется вместе с hero_taken")
	assert_false(NightmareRunState.has_flag(&"hero_dead"), "hero_dead не ставится одновременно с hero_taken")
	assert_false(hero.visible)
	assert_true(tyrant.visible, "Тиран виден в момент захвата")
	assert_false(glow.visible, "храм ещё не подсвечен")
	assert_false(temple.enabled, "проход к храму ещё закрыт")

	# Реплики 4–7: крик, когти, захват и обещание. Смерть ещё не подтверждена.
	for index in range(4, 8):
		dialogue.advance()
		assert_eq(seen_lines.size(), index + 1)
		assert_true(NightmareRunState.has_flag(&"hero_taken"))
		assert_false(NightmareRunState.has_flag(&"hero_dead"),
			"hero_dead не ставится на реплике захвата %d" % index)
		assert_false(glow.visible)

	# Реплика 8: захват закончен, начинается раненый подъём к храму.
	dialogue.advance()
	assert_eq(seen_lines.size(), 9)
	assert_true(NightmareRunState.has_flag(&"hero_dead"))
	assert_false(hero.visible)
	assert_false(tyrant.visible, "после захвата Тиран скрыт")
	assert_true(glow.visible, "после захвата храм подсвечен")
	assert_true(temple.enabled, "после захвата открыт подход к храму")
	assert_true(NightmareRunState.has_item(&"silver_bell"), "Колокольчик остаётся Памятью")

	dialogue.advance()
	await wait_process_frames(1)
	assert_false(dialogue.running)
	var emitted := seen_lines.size()
	bell.interact()
	await wait_process_frames(1)
	assert_eq(seen_lines.size(), emitted, "повторный звонок не запускает сцену")

	site.call(&"prepare_route")
	assert_false(hero.visible, "повторная подготовка не возвращает Героя")
	assert_false(tyrant.visible, "повторная подготовка не возвращает Тирана")
	assert_true(glow.visible, "повторная подготовка сохраняет храм видимым")
	assert_true(temple.enabled)
	assert_eq(site.get(&"phase"), &"TEMPLE")


func test_wrapper_connects_route_signals_without_completing_nightmare() -> void:
	var wrapper := await _make_wrapper()
	var site := wrapper.get_node("PilgrimPath") as Node3D
	assert_not_null(site)
	assert_true(site.call(&"get_trigger", &"road_gap") is TriggerZone)
	assert_true((wrapper.get_node("Sunny") as SunnyController).is_in_group(&"player"))
	assert_false(wrapper.has_started_transition())
	for signal_name in [
		&"road_gap_seen",
		&"sword_discarded",
		&"rest_requested",
		&"scholar_requested",
		&"cave_requested",
		&"cave_escape_requested",
		&"hero_requested",
		&"bell_rung",
		&"temple_reached",
	]:
		var connected_to_wrapper := false
		for connection in site.get_signal_connection_list(signal_name):
			if connection["callable"].get_object() == wrapper:
				connected_to_wrapper = true
				break
		assert_true(connected_to_wrapper, "оболочка слушает %s" % signal_name)
	# Mark of Divinity выставляется на B16 штатно (slice_director); пролог здесь не проигрывается.
	NightmareRunState.set_flag(&"mark_of_divinity")
	site.call(&"reach_temple")
	assert_true(wrapper.has_started_transition(), "вход в храм ведёт к святилищу")
	assert_true(NightmareRunState.has_flag(&"pilgrim_path_completed"))
	assert_false(NightmareRunState.has_flag(&"first_nightmare_completed"))


func test_wrapper_hides_shifty_on_fall_dialogue_line() -> void:
	var wrapper := await _make_wrapper()
	var site := wrapper.get_node("PilgrimPath") as Node3D
	var line := DialogueLine.new()
	wrapper.call(&"_on_shifty_dialogue_line", line, 3, 9)
	assert_true(site.get_node("NPCs/Shifty").visible, "до падения Шифти виден")
	assert_false(site.get_node("Props/BloodStain").visible, "до падения крови нет")
	wrapper.call(&"_on_shifty_dialogue_line", line, 4, 9)
	assert_true(NightmareRunState.has_flag(&"shifty_dead"))
	assert_false(site.get_node("NPCs/Shifty").visible, "на строке падения Шифти исчезает")
	assert_false(site.get_node("NPCs/ShiftyBody").visible, "тело не появляется")
	assert_true(site.get_node("Props/BloodStain").visible, "кровь остаётся")


func test_cave_survival_spawns_threats_and_clears_the_exit() -> void:
	var site := await _make_location()
	NightmareRunState.set_flag(&"cave_entered")
	NightmareRunState.set_flag(&"wound_taken")
	site.call(&"prepare_route")
	var target := Node3D.new()
	add_child_autofree(target)
	target.global_position = Vector3(3.6, 4.2, -48.5)
	var spawned: int = site.call(&"begin_cave_survival", target)
	assert_eq(spawned, 2, "после ранения в пещере появляются две угрозы")
	var first := site.get_node_or_null("CaveLarva0") as TestEnemy
	var second := site.get_node_or_null("CaveLarva1") as TestEnemy
	assert_not_null(first, "первая пещерная личинка существует")
	assert_not_null(second, "вторая пещерная личинка существует")
	if first == null or second == null:
		return
	assert_eq(first.target, target, "угроза нацелена на игрока")
	assert_true((site.call(&"get_trigger", &"cave_exit") as TriggerZone).enabled,
		"выход открыт после ранения, даже если бой ещё идёт")
	first.health.take_damage(999.0)
	await wait_physics_frames(2)
	assert_false(NightmareRunState.has_flag(&"cave_threats_cleared"),
		"одна убитая личинка не закрывает событие")
	second.health.take_damage(999.0)
	await wait_physics_frames(2)
	assert_true(NightmareRunState.has_flag(&"cave_threats_cleared"),
		"после двух смертей событие «выжить» закрыто")
	assert_true(site.call(&"cave_threats_cleared"))


func test_wrapper_tracks_v2_beats_n14_to_n23_and_activates_checkpoints() -> void:
	var wrapper := await _make_wrapper()
	var sunny := wrapper.get_node("Sunny") as SunnyController
	var recovery := sunny.get_node("FallRecovery") as FallRecovery
	var director: BeatDirector = wrapper.beat_director
	assert_not_null(director)
	assert_eq(director.get_current_beat_id(), &"N14")
	assert_eq(director.current_objective, "Подняться за Героем по старой тропе")

	await wrapper.call(&"_handle_road_gap")
	assert_eq(director.get_current_beat_id(), &"N15")
	assert_eq(recovery.get_checkpoint_id(), &"CP-N15a")

	await wrapper.call(&"_handle_sword_discarded")
	assert_eq(recovery.get_checkpoint_id(), &"CP-N15c")
	assert_true(sunny.is_unarmed(), "после брошенного меча Санни переходит в режим без оружия")

	await wrapper.call(&"_handle_rest")
	assert_eq(director.get_current_beat_id(), &"N18")
	assert_eq(recovery.get_checkpoint_id(), &"CP-N18")

	await wrapper.call(&"_handle_scholar")
	assert_eq(director.get_current_beat_id(), &"N19")

	# В живом маршруте флаг ставит TriggerZone пещеры; здесь сцена-оболочка
	# вызывается напрямую, поэтому вход отмечаем явно.
	NightmareRunState.set_flag(&"cave_entered")
	await wrapper.call(&"_handle_cave")
	assert_eq(director.get_current_beat_id(), &"N20")
	assert_eq(recovery.get_checkpoint_id(), &"CP-N20")
	assert_true(NightmareRunState.has_flag(&"cave_entered"), "вход в пещеру отмечен")
	assert_not_null(wrapper.get_node_or_null("PilgrimPath/CaveLarva0"), "после ранения появляется первая угроза")
	assert_not_null(wrapper.get_node_or_null("PilgrimPath/CaveLarva1"), "после ранения появляется вторая угроза")

	wrapper.call(&"_handle_cave_escape")
	assert_eq(director.get_current_beat_id(), &"N21")
	assert_eq(recovery.get_checkpoint_id(), &"CP-N21a")

	await wrapper.call(&"_handle_hero")
	assert_eq(director.get_current_beat_id(), &"N22")

	NightmareRunState.set_flag(&"silver_bell_used")
	await wrapper.call(&"_handle_bell")
	assert_eq(director.get_current_beat_id(), &"N23")
	assert_eq(recovery.get_checkpoint_id(), &"CP-N23")
