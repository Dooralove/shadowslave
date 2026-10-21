extends SliceLocation
## B10–B12: камера изоляции в подвале — стул с фиксаторами, охрана с оружием, бронедверь.

@onready var restraints: Node3D = $Chair/Restraints
@onready var door_pivot: Node3D = $Geometry/DoorPivot
@onready var policeman: Node3D = $Policeman
@onready var chair_front: Marker3D = $Markers/ChairFront
@onready var guards: Array[Node] = $Guards.get_children()
@onready var cuff_marks: Array[Node] = $Markers/CuffMarks.get_children()


func play_cutscene(id: StringName, fast: bool) -> void:
	match id:
		&"restrain":
			await _restrain(fast)
		&"policeman_enters":
			await _policeman_enters(fast)
		_:
			super.play_cutscene(id, fast)


## Полицейские пристёгивают Санни к стулу и отходят на посты, не опуская оружия.
func _restrain(fast: bool) -> void:
	use_shot(&"RoomShot")
	var posts: Array[Vector3] = []
	var headings: Array[float] = []
	for i in guards.size():
		var guard := guards[i] as Node3D
		var mark := cuff_marks[i] as Node3D
		posts.append(guard.global_position)
		headings.append(guard.global_rotation.y)
		guard.global_rotation.y = mark.global_rotation.y
		animate(guard, ^"global_position", mark.global_position, 1.0, fast)
	await pause(1.2, fast)
	restraints.visible = true
	await pause(0.8, fast)
	for i in guards.size():
		animate(guards[i], ^"global_position", posts[i], 1.0, fast)
	await pause(1.0, fast)
	for i in guards.size():
		(guards[i] as Node3D).global_rotation.y = headings[i]


## Седой полицейский входит, проверяет фиксаторы и смотрит на часы.
func _policeman_enters(fast: bool) -> void:
	use_shot(&"DoorShot")
	await animate(door_pivot, ^"rotation:y", -1.6, 1.4, fast)
	await animate(policeman, ^"global_position", chair_front.global_position, 3.0, fast)
	use_shot(&"RoomShot")
	var height := policeman.scale.y
	await animate(policeman, ^"scale:y", height * 0.82, 0.4, fast)
	await pause(0.6, fast)
	await animate(policeman, ^"scale:y", height, 0.4, fast)
	await pause(1.0, fast)
