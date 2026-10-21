extends SliceLocation
## B08–B09: лобби полицейского участка — бронеплиты, турели под потолком, дежурный за стойкой.

@onready var alarm_lights: Array[Node] = $AlarmLights.get_children()
@onready var officers: Array[Node] = $Officers.get_children()
@onready var officer_marks: Array[Node] = $Markers/OfficerMarks.get_children()


func play_cutscene(id: StringName, fast: bool) -> void:
	match id:
		&"code_black":
			await _code_black(fast)
		_:
			super.play_cutscene(id, fast)


## Дежурный поднимает тревогу; в лобби вбегают вооружённые полицейские и берут Санни на прицел.
func _code_black(fast: bool) -> void:
	use_shot(&"AlarmShot")
	_start_alarm(fast)
	for i in officers.size():
		var officer := officers[i] as Node3D
		var mark := officer_marks[i] as Node3D
		officer.visible = true
		officer.global_rotation.y = mark.global_rotation.y
		animate(officer, ^"global_position", mark.global_position, 1.6, fast)
	await director.say(&"code_black")
	await pause(0.5, fast)


func _start_alarm(fast: bool) -> void:
	_set_alarm(2.0)
	if fast:
		return
	var pulse := create_tween().set_loops()
	pulse.tween_method(_set_alarm, 2.0, 0.2, 0.35)
	pulse.tween_method(_set_alarm, 0.2, 2.0, 0.35)


func _set_alarm(energy: float) -> void:
	for light in alarm_lights:
		(light as Light3D).light_energy = energy
