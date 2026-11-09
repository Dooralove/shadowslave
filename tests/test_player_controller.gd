extends GutTest
## Поток C: единая боевая модель Санни, прыжок и удар вне боя.
## Проверяет, что кампания использует тот же v3-Санни, что и пролог,
## а jump/attack не зависят от combat_enabled.

const CAMPAIGN_ENTRY := "res://scenes/campaign/campaign_entry.tscn"
const POC := "res://assets/characters/sunny_realistic_poc/sunny_waking_poc.tscn"
const CAMPAIGN_PLAYER_SCENES := [
	"res://scenes/campaign/first_nightmare_pass.tscn",
	"res://scenes/campaign/caravan_site_arrival.tscn",
	"res://scenes/campaign/pilgrim_path_arrival.tscn",
	"res://scenes/locations/shadow_sanctuary/shadow_sanctuary.tscn",
]


func after_each() -> void:
	Input.action_release(&"jump")
	Input.action_release(&"attack")
	Input.action_release(&"move_forward")
	NightmareRunState.reset()


func _spawn_poc() -> SunnyController:
	var sunny := (load(POC) as PackedScene).instantiate() as SunnyController
	add_child_autofree(sunny)
	return sunny


func _spawn_campaign_entry() -> Node3D:
	var entry := (load(CAMPAIGN_ENTRY) as PackedScene).instantiate() as Node3D
	entry.set(&"autostart", false)
	entry.set(&"transition_enabled", false)
	add_child_autofree(entry)
	return entry


func _spawn_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "TestFloor"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	shape.shape = box
	floor.add_child(shape)
	floor.position = Vector3(0.0, -0.5, 0.0)
	add_child_autofree(floor)
	return floor


func test_jump_and_attack_actions_are_mapped() -> void:
	assert_true(InputMap.has_action(&"jump"), "action jump объявлен в project.godot")
	assert_true(InputMap.has_action(&"attack"), "action attack объявлен в project.godot")
	assert_gt(InputMap.action_get_events(&"jump").size(), 0, "у jump есть клавиша")
	assert_gt(InputMap.action_get_events(&"attack").size(), 0, "у attack есть кнопка")


func test_campaign_entry_uses_the_same_v3_sunny_as_prologue() -> void:
	var entry := _spawn_campaign_entry()
	var prologue := entry.get_node("Prologue") as SliceDirector
	var sunny := prologue.get_node("Sunny") as SunnyController
	var model := sunny.get_node_or_null("Visual/ModelPoc") as Node3D
	assert_not_null(model, "POC-модель существует")
	if model == null:
		return
	assert_true(model.get_script() != null, "у POC-модели есть скрипт")
	assert_string_ends_with(model.get_script().resource_path, "sunny_v3_model.gd",
		"в прологе и кампании стоит v3-Санни, а не P1 nightmare")
	assert_not_null(sunny.get_node_or_null("Visual/ModelPoc/Model/AnimationPlayer"),
		"у v3-модели есть AnimationPlayer")
	assert_false((sunny.get_node("Visual/Model") as Node3D).visible,
		"KayKit/chibi-модель скрыта")
	assert_null(sunny.find_child("SunnyNightmareV2", true, false),
		"nightmare-модель не подмешана в кампанию")


func test_campaign_wrappers_reference_the_same_sunny_scene() -> void:
	for path in CAMPAIGN_PLAYER_SCENES:
		var text := FileAccess.get_file_as_string(path)
		assert_string_contains(text, "sunny_waking_poc.tscn", "%s использует v3-Санни" % path)
		assert_false(text.contains("sunny_waking_nightmare.tscn"),
			"%s не использует P1 nightmare" % path)


func test_campaign_entry_jump_works_without_combat_enabled() -> void:
	_spawn_floor()
	var entry := _spawn_campaign_entry()
	var prologue := entry.get_node("Prologue") as SliceDirector
	var sunny := prologue.get_node("Sunny") as SunnyController
	prologue.set_mode(SliceDirector.Mode.FREE)
	sunny.global_position = Vector3(0.0, 0.05, 0.0)
	sunny.velocity = Vector3.ZERO
	sunny.combat_enabled = false
	sunny.allow_jump = true
	await wait_physics_frames(30)
	assert_true(sunny.is_on_floor(), "Санни стоит на полу")

	Input.action_press(&"jump")
	await wait_physics_frames(1)
	Input.action_release(&"jump")

	assert_gt(sunny.velocity.y, 0.0, "прыжок срабатывает при combat_enabled=false")
	assert_true(sunny.get_node("Animator").animation_player.has_animation(
		(sunny.get_node("Animator") as SunnyAnimator).jump_clip),
		"у модели есть клип прыжка")


func test_campaign_entry_attack_works_without_combat_enabled() -> void:
	var entry := _spawn_campaign_entry()
	var prologue := entry.get_node("Prologue") as SliceDirector
	var sunny := prologue.get_node("Sunny") as SunnyController
	prologue.set_mode(SliceDirector.Mode.FREE)
	sunny.combat_enabled = false

	assert_true(sunny.try_attack(), "удар доступен вне боя")
	assert_true(sunny.attack.is_attacking(), "анимация/хитбокс удара запущены")
	assert_false(sunny.try_attack(), "второй удар во время анимации не ломает состояние")


func test_attack_does_not_lock_movement() -> void:
	_spawn_floor()
	var sunny := _spawn_poc()
	sunny.global_position = Vector3(0.0, 0.05, 0.0)
	sunny.velocity = Vector3.ZERO
	await wait_physics_frames(30)
	assert_true(sunny.is_on_floor(), "Санни стоит на полу")

	assert_true(sunny.try_attack())
	Input.action_press(&"move_forward")
	for i in 5:
		sunny._physics_process(1.0 / 60.0)
	Input.action_release(&"move_forward")

	assert_gt(Vector2(sunny.velocity.x, sunny.velocity.z).length(), 0.1,
		"во время удара управление движением сохраняется")
