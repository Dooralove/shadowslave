extends GutTest
## HUD боя: выносливость, скрытие вне боя и появление после траты.

const HUD_SCENE := "res://scenes/ui/combat_hud.tscn"
const SUNNY_SCENE := "res://scenes/characters/sunny.tscn"


func test_hud_shows_stamina_and_hides_when_idle_and_full() -> void:
	var hud := (load(HUD_SCENE) as PackedScene).instantiate() as CombatHud
	hud.first_reveal_seconds = 0.0
	add_child_autofree(hud)
	var sunny := (load(SUNNY_SCENE) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	await wait_process_frames(2)
	hud.bind_player(sunny)
	await wait_process_frames(1)
	assert_eq(hud.stamina_bar.max_value, sunny.stamina.max_stamina)
	assert_false(hud.player_panel.visible, "вне боя при полном запасе HUD скрыт")

	sunny.stamina.spend(20.0)
	await wait_process_frames(1)
	assert_true(hud.player_panel.visible, "после траты выносливости HUD появляется")

	sunny.stamina.refill()
	sunny.health.heal(sunny.health.max_health)
	hud.bind_player(sunny)
	await wait_process_frames(2)
	assert_false(hud.player_panel.visible, "после восстановления и вне боя HUD снова скрыт")


func test_hud_reveals_itself_on_first_bind() -> void:
	var hud := (load(HUD_SCENE) as PackedScene).instantiate() as CombatHud
	hud.first_reveal_seconds = 2.0
	add_child_autofree(hud)
	var sunny := (load(SUNNY_SCENE) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	await wait_process_frames(2)
	hud.bind_player(sunny)
	await wait_process_frames(1)
	assert_true(hud.player_panel.visible, "первое появление HUD показывает полосы")
	hud._reveal_left = 0.0
	hud._update_visibility()
	assert_false(hud.player_panel.visible, "после первого показа HUD снова скрыт")
