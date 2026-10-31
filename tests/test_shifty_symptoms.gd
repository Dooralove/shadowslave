extends GutTest
## B1-B.1: визуальные признаки ослабления Шифти в алькове.
##
## Позы проверяются на самой локации: переход в альков идёт через Interactable
## «rest», как в игре. Состояние отравления выставляется как входное условие
## (его реальная выдача проверяется в test_poison_flasks), а не как сюжетный шаг.

const LOCATION_SCENE := "res://scenes/locations/pilgrim_path/pilgrim_path.tscn"


func before_each() -> void:
	NightmareRunState.reset()


func after_each() -> void:
	NightmareRunState.reset()


func _spawn_location() -> PilgrimPath:
	var site := (load(LOCATION_SCENE) as PackedScene).instantiate() as PilgrimPath
	add_child_autofree(site)
	return site


func _press(site: PilgrimPath, id: StringName) -> void:
	site.get_interactable(id).interact()


func _reach_alcove(site: PilgrimPath) -> void:
	_press(site, &"road_gap")
	_press(site, &"sword")
	_press(site, &"rest")


func test_shifty_looks_weakened_before_the_fall_when_poisoned() -> void:
	NightmareRunState.set_flag(&"flasks_poisoned")
	var site := _spawn_location()
	await wait_process_frames(2)
	var shifty := site.get_node("NPCs/Shifty") as Node3D
	var base_height := shifty.scale.y
	assert_false(site.is_shifty_weakened(), "до альков Шифти в обычной позе")

	_reach_alcove(site)
	assert_true(NightmareRunState.has_flag(&"alcove_reached"))
	assert_true(site.is_shifty_weakened(), "в алькове Шифти наклонён вперёд")
	assert_lt(shifty.scale.y, base_height, "в алькове Шифти сгорблен")
	assert_true(shifty.visible, "до падения Шифти виден")
	assert_false(NightmareRunState.has_flag(&"shifty_dead"), "наклон сам смерть не ставит")


func test_no_weakness_without_poisoning() -> void:
	var site := _spawn_location()
	await wait_process_frames(2)
	_reach_alcove(site)
	assert_true(NightmareRunState.has_flag(&"alcove_reached"))
	assert_false(site.is_shifty_weakened(), "без отравления признаков нет")


func test_fall_hides_shifty_and_keeps_blood_and_no_body() -> void:
	NightmareRunState.set_flag(&"flasks_poisoned")
	var site := _spawn_location()
	await wait_process_frames(2)
	_reach_alcove(site)
	site.kill_shifty()

	var shifty := site.get_node("NPCs/Shifty") as Node3D
	assert_false(shifty.visible, "после падения Шифти скрыт")
	assert_false(site.get_node("NPCs/ShiftyBody").visible, "тело не показывается")
	assert_true(site.get_node("Props/BloodStain").visible, "кровь остаётся видимой")
	assert_false(site.is_shifty_weakened(), "у мёртвого Шифти поза сброшена")


func test_reload_after_fall_restores_hidden_shifty_and_blood() -> void:
	NightmareRunState.set_flag(&"flasks_poisoned")
	NightmareRunState.set_flag(&"alcove_reached")
	NightmareRunState.set_flag(&"shifty_dead")
	var site := _spawn_location()
	await wait_process_frames(2)
	var shifty := site.get_node("NPCs/Shifty") as Node3D
	assert_false(shifty.visible, "перезагрузка не возвращает Шифти")
	assert_false(site.is_shifty_weakened(), "мёртвый Шифти не получает позу больного")
	assert_false(site.get_node("NPCs/ShiftyBody").visible, "перезагрузка не показывает тело")
	assert_true(site.get_node("Props/BloodStain").visible, "кровь видима после перезагрузки")


func test_reload_in_alcove_before_fall_restores_weakness() -> void:
	NightmareRunState.set_flag(&"flasks_poisoned")
	NightmareRunState.set_flag(&"alcove_reached")
	var site := _spawn_location()
	await wait_process_frames(2)
	assert_true(site.is_shifty_weakened(), "при возвращении в альков до падения признаки сохраняются")
	assert_true((site.get_node("NPCs/Shifty") as Node3D).visible, "Шифти жив и виден")
	assert_false((site.get_node("Props/BloodStain") as Node3D).visible, "крови до падения нет")
