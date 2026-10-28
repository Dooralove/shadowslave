extends GutTest
## Связка контроллера засады и AI Горного Короля:
## сцена стартует спящей, триггер будит монстра, укрытие передаётся в AI,
## а точка эвакуации открывается только после полноценного укрытия.

const SITE_SCENE := "res://scenes/locations/ambush_site/ambush_site.tscn"
const DEMO_SCENE := "res://scenes/levels/ambush_site_demo.tscn"
const SPELL_CATALOG := "res://resources/spell/ambush_site_messages.tres"
const STEP := 0.05


class FakePlayer extends Node3D:
	pass


var site: AmbushController
var king: MountainKing
var player: FakePlayer


func before_each() -> void:
	site = (load(SITE_SCENE) as PackedScene).instantiate() as AmbushController
	add_child_autofree(site)
	await wait_physics_frames(1)
	site.set_process(false)

	king = site.get_node("MountainKing") as MountainKing
	king.set_physics_process(false)
	king.attack.set_physics_process(false)

	player = FakePlayer.new()
	player.add_to_group(&"player")
	add_child_autofree(player)
	player.global_position = king.global_position + Vector3(0.0, 0.0, 5.0)
	king.target = player


func _reach_threat() -> void:
	site.start_ambush()
	site.tick_scenario(site.ambush_intro_time + 0.1)


func _hide_and_wait(dwell: float = -1.0) -> void:
	site._on_wagon_cover_body_entered(player)
	var wait := site.cover_dwell_to_open_escape + 0.1 if dwell < 0.0 else dwell
	site.tick_scenario(wait)
	site._on_wagon_cover_body_exited(player)


func test_scene_starts_dormant_and_controller_is_wired() -> void:
	assert_eq(site.mountain_king, king)
	assert_eq(king.state, MountainKing.State.DORMANT)
	assert_false(king.is_ai_enabled(), "до начала засады AI выключен")
	assert_false(site.is_ambush_started())
	assert_eq(site.get_state(), AmbushController.State.WAITING)
	assert_false(site.is_player_hidden())
	assert_false(site.is_escape_path_open())
	assert_false(site.is_escape_available())


func test_ambush_start_activates_monster_once() -> void:
	watch_signals(site)
	site.start_ambush()
	assert_true(site.is_ambush_started())
	assert_eq(site.get_state(), AmbushController.State.AMBUSH_STARTED)
	assert_eq(king.state, MountainKing.State.CHASE)
	assert_signal_emit_count(site, "ambush_cutscene_started", 1)
	assert_signal_emit_count(site, "mountain_king_activated", 1)

	site.start_ambush()
	assert_signal_emit_count(site, "ambush_cutscene_started", 1, "повторный старт игнорируется")
	assert_signal_emit_count(site, "mountain_king_activated", 1)
	assert_eq(site.get_state(), AmbushController.State.AMBUSH_STARTED, "повторный старт не сбрасывает фазу")


func test_start_after_threat_does_not_restart_episode() -> void:
	_reach_threat()
	watch_signals(site)
	assert_eq(site.get_state(), AmbushController.State.THREAT_ACTIVE)

	site.start_ambush()
	assert_eq(site.get_state(), AmbushController.State.THREAT_ACTIVE)
	assert_signal_emit_count(site, "ambush_cutscene_started", 0)
	assert_signal_emit_count(site, "mountain_king_activated", 0)


func test_threat_state_opens_route_but_not_evacuation() -> void:
	watch_signals(site)
	_reach_threat()
	assert_eq(site.get_state(), AmbushController.State.THREAT_ACTIVE)
	assert_true(site.is_escape_path_open())
	assert_false(site.is_escape_available())
	assert_signal_emit_count(site, "escape_path_opened", 1)
	assert_signal_emit_count(site, "escape_available", 0)
	assert_eq(king.state, MountainKing.State.CHASE)


func test_cover_state_is_forwarded_to_ai() -> void:
	site.start_ambush()
	watch_signals(site)

	site._on_wagon_cover_body_entered(player)
	assert_true(site.is_player_hidden())
	assert_true(king.is_player_hidden())
	assert_signal_emit_count(site, "player_hidden_in_cover", 1)
	assert_signal_emit_count(site, "player_cover_changed", 1)

	site._on_wagon_cover_body_exited(player)
	assert_false(site.is_player_hidden())
	assert_false(king.is_player_hidden())
	assert_signal_emit_count(site, "player_cover_changed", 2)


func test_cover_is_ignored_before_ambush() -> void:
	site._on_wagon_cover_body_entered(player)
	assert_false(site.is_player_hidden(), "в WAITING укрытие ещё не часть эпизода")
	assert_false(king.is_player_hidden())


func test_short_cover_does_not_arm_evacuation() -> void:
	_reach_threat()
	_hide_and_wait(0.2)
	assert_false(site.is_player_hidden())
	assert_false(site.is_cover_ready())
	assert_eq(site.get_state(), AmbushController.State.THREAT_ACTIVE)
	assert_false(site.is_escape_available())


func test_cover_dwell_arms_evacuation_on_exit() -> void:
	_reach_threat()
	watch_signals(site)

	site._on_wagon_cover_body_entered(player)
	site.tick_scenario(site.cover_dwell_to_open_escape + 0.1)
	assert_true(site.is_cover_ready())
	assert_signal_emit_count(site, "cover_hold_completed", 1)
	assert_eq(site.get_state(), AmbushController.State.THREAT_ACTIVE, "пока игрок в укрытии, эвакуация ещё не открыта")

	site._on_wagon_cover_body_exited(player)
	assert_eq(site.get_state(), AmbushController.State.ESCAPE_AVAILABLE)
	assert_true(site.is_escape_available())
	assert_signal_emit_count(site, "escape_available", 1)


func test_escape_requires_available_state_and_finishes_once() -> void:
	_reach_threat()
	watch_signals(site)

	site._on_escape_reach_body_entered(player)
	assert_eq(site.get_state(), AmbushController.State.THREAT_ACTIVE, "до укрытия эвакуация не срабатывает")
	assert_signal_emit_count(site, "escape_denied", 1)
	assert_signal_emit_count(site, "episode_completed", 0)

	site._on_escape_reach_body_entered(player)
	assert_signal_emit_count(site, "escape_denied", 1, "отказ в эвакуации не спамит")

	_hide_and_wait()
	assert_eq(site.get_state(), AmbushController.State.ESCAPE_AVAILABLE)

	site._on_escape_reach_body_entered(player)
	assert_eq(site.get_state(), AmbushController.State.ESCAPED)
	assert_true(site.is_escaped())
	assert_signal_emit_count(site, "episode_completed", 1)
	assert_eq(king.state, MountainKing.State.DORMANT, "после побега AI выключен")
	assert_false(king.is_ai_enabled())

	site._on_escape_reach_body_entered(player)
	assert_signal_emit_count(site, "episode_completed", 1, "эпизод завершается один раз")


func test_escape_trigger_ignores_non_player() -> void:
	_reach_threat()
	_hide_and_wait()
	var stranger := Node3D.new()
	add_child_autofree(stranger)
	watch_signals(site)

	site._on_escape_reach_body_entered(stranger)
	assert_eq(site.get_state(), AmbushController.State.ESCAPE_AVAILABLE)
	assert_signal_emit_count(site, "episode_completed", 0)


func test_escaped_episode_ignores_cover_and_start() -> void:
	_reach_threat()
	_hide_and_wait()
	site._on_escape_reach_body_entered(player)
	watch_signals(site)

	site._on_wagon_cover_body_entered(player)
	site.start_ambush()
	assert_false(site.is_player_hidden())
	assert_eq(site.get_state(), AmbushController.State.ESCAPED)
	assert_signal_emit_count(site, "player_cover_changed", 0)
	assert_signal_emit_count(site, "ambush_cutscene_started", 0)


func test_controller_can_disable_and_reactivate_ai() -> void:
	site.start_ambush()
	assert_eq(king.state, MountainKing.State.CHASE)

	site.disable_monster_ai()
	assert_eq(king.state, MountainKing.State.DORMANT)
	assert_false(king.is_ai_enabled())

	site.activate_monster()
	assert_eq(king.state, MountainKing.State.CHASE)
	assert_true(king.is_ai_enabled())


func test_controller_can_order_retreat() -> void:
	site.start_ambush()
	watch_signals(site)
	var destination := king.global_position + Vector3(0.0, 0.0, 8.0)
	assert_true(site.order_monster_retreat(destination, 1.0))
	assert_eq(king.state, MountainKing.State.RETREAT)
	assert_signal_emit_count(site, "mountain_king_retreated", 1)

	var elapsed := 0.0
	while king.state != MountainKing.State.DORMANT and elapsed < 2.0:
		king.update_ai(STEP)
		elapsed += STEP
	assert_eq(king.state, MountainKing.State.DORMANT)


func test_playable_demo_runs_full_trigger_path() -> void:
	var demo := (load(DEMO_SCENE) as PackedScene).instantiate() as Node3D
	add_child_autofree(demo)
	await wait_physics_frames(3)

	var playable_site := demo.get_node("AmbushSite") as AmbushController
	var sunny := demo.get_node("Sunny") as SunnyController
	var playable_king := playable_site.get_node("MountainKing") as MountainKing
	playable_king.set_physics_process(false)
	playable_king.attack.set_physics_process(false)
	playable_site.set_process(false)

	assert_eq(playable_site.get_state(), AmbushController.State.WAITING)

	sunny.global_position = Vector3(0.0, 0.2, 17.5)
	await wait_physics_frames(3)
	assert_true(playable_site.is_ambush_started(), "вход в зону запускает засаду")
	assert_eq(playable_site.get_state(), AmbushController.State.AMBUSH_STARTED)

	playable_site.tick_scenario(playable_site.ambush_intro_time + 0.1)
	assert_eq(playable_site.get_state(), AmbushController.State.THREAT_ACTIVE)

	sunny.global_position = Vector3(-5.8, 0.5, -3.5)
	await wait_physics_frames(3)
	assert_true(playable_site.is_player_hidden(), "реальный Area3D укрытия срабатывает")
	playable_site.tick_scenario(playable_site.cover_dwell_to_open_escape + 0.1)
	assert_true(playable_site.is_cover_ready())

	sunny.global_position = Vector3(-2.0, 0.5, -1.0)
	await wait_physics_frames(3)
	assert_false(playable_site.is_player_hidden(), "выход из укрытия снимает скрытность")
	assert_eq(playable_site.get_state(), AmbushController.State.ESCAPE_AVAILABLE)

	sunny.global_position = Vector3(-27.5, 2.0, -12.0)
	await wait_physics_frames(3)
	assert_eq(playable_site.get_state(), AmbushController.State.ESCAPED)
	assert_true(playable_site.is_escaped())


func test_ambush_spell_catalog_contains_episode_messages() -> void:
	var catalog := load(SPELL_CATALOG) as SpellMessageCatalog
	assert_not_null(catalog)
	for message_id in [&"ambush_started", &"escape_available", &"escaped"]:
		var message := catalog.get_message(message_id)
		assert_not_null(message, "есть сообщение %s" % message_id)
		if message:
			assert_true(message.is_valid())


func test_site_has_spell_feedback_wired_to_controller() -> void:
	var overlay := site.get_node_or_null("SpellOverlay") as SpellOverlay
	var feedback := site.get_node_or_null("SiteFeedback") as AmbushSiteUI
	assert_not_null(overlay, "слой Заклятия подключён к локации")
	assert_not_null(feedback, "переходник сообщений Заклятия подключён")
	if feedback:
		assert_eq(feedback.controller, site)
		assert_eq(feedback.spell_overlay, overlay)
		assert_not_null(feedback.messages)
