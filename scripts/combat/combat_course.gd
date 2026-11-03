extends Node3D
## Small combat course used by the demo sprint: three hand-placed encounters in
## the existing test level. It is a sandbox for verifying the combat loop, not a
## campaign scene. Keeps the HUD and the restart/summary flow in one place.

@onready var hud: CombatHud = $HUD
@onready var player: SunnyController = $Level/Sunny
@onready var encounters: Node3D = $Encounters

var _encounter_list: Array[CombatEncounter] = []


func _ready() -> void:
	for child in encounters.get_children():
		var encounter := child as CombatEncounter
		if encounter == null:
			continue
		_encounter_list.append(encounter)
		encounter.cleared.connect(_on_encounter_cleared)
	if player != null:
		player.health.died.connect(_on_player_died)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		get_tree().reload_current_scene()


func _on_encounter_cleared() -> void:
	if _all_cleared():
		hud.show_message("Полигон пройден\nВсе столкновения завершены\nR — начать заново")


func _on_player_died() -> void:
	hud.show_message("Санни погиб\nR — начать заново")


func _all_cleared() -> bool:
	if _encounter_list.is_empty():
		return false
	for encounter in _encounter_list:
		if not encounter.is_cleared():
			return false
	return true


func get_encounters() -> Array[CombatEncounter]:
	return _encounter_list
