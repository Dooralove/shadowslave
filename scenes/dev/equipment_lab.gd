extends Node3D
## Alpha-лаборатория экипировки: один персонаж, два сета, оружие и аксессуар.
## Сцена изолирована от кампании и не сохраняет состояние.

@export var model: Node3D
@export var equipment: EquipmentComponent
@export var ab_test: EquipmentABTest
@export var catalog: EquipmentCatalog

@onready var camera: Camera3D = $Camera3D
@onready var info: Label = $UI/Info

var _player: AnimationPlayer
var _pose_index := 0
var _poses: Array[Dictionary] = [
	{"label": "IDLE", "clip": &"HumanStandingIdle"},
	{"label": "WALK", "clip": &"WalkClean"},
	{"label": "RUN", "clip": &"HumanSprintLoop"},
	{"label": "ATTACK", "clip": &"Sword_Attack"},
	{"label": "GUARD", "clip": &"HumanStandingIdle"},
	{"label": "DODGE", "clip": &"HumanRoll"},
	{"label": "DEATH", "clip": &"HumanDeath"},
]


func _ready() -> void:
	_add_environment()
	if model == null:
		model = get_node_or_null("Sunny") as Node3D
	if equipment == null:
		equipment = get_node_or_null("Equipment") as EquipmentComponent
	if ab_test == null and equipment != null:
		ab_test = equipment.ab_test
	if catalog == null and equipment != null:
		catalog = equipment.catalog

	if model != null:
		_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if equipment != null:
		equipment.equipment_changed.connect(_on_equipment_changed)
		equipment.equipment_failed.connect(_on_equipment_failed)

	camera.position = Vector3(1.45, 1.25, 4.35)
	camera.look_at(Vector3(0.0, 0.92, 0.0), Vector3.UP)
	_play_pose(0)
	_update_info()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_equip_variant(&"A")
		KEY_2:
			_equip_variant(&"B")
		KEY_3:
			_toggle_body()
		KEY_4:
			if equipment != null:
				equipment.set_weapon_drawn(not equipment.weapon_drawn)
		KEY_5:
			_toggle_accessory()
		KEY_6:
			_play_pose((_pose_index + 1) % _poses.size())
		KEY_R:
			_reset()


func _equip_variant(variant: StringName) -> void:
	if equipment == null:
		return
	equipment.set_ab_variant(variant)
	_update_info()


func _toggle_body() -> void:
	if equipment == null:
		return
	if equipment.get_equipped(EquipmentItemData.Slot.BODY) == null:
		var active := equipment.ab_test.active_variant if equipment.ab_test != null else &"A"
		_equip_variant(active)
	else:
		equipment.unequip(EquipmentItemData.Slot.BODY)
	_update_info()


func _toggle_accessory() -> void:
	if equipment == null:
		return
	if equipment.get_equipped(EquipmentItemData.Slot.ACCESSORY) != null:
		equipment.unequip(EquipmentItemData.Slot.ACCESSORY)
	elif catalog != null:
		var accessory := catalog.get_item(&"water_flask_alpha")
		if accessory != null:
			equipment.equip(accessory)
	_update_info()


func _play_pose(index: int) -> void:
	_pose_index = index
	if _player == null:
		return
	var entry := _poses[_pose_index]
	var clip: StringName = entry["clip"]
	if not _player.has_animation(clip):
		push_warning("EquipmentLab: clip %s отсутствует" % clip)
		return
	_player.play(clip)
	_player.seek(0.0, true)
	_update_info()


func _reset() -> void:
	if equipment != null:
		var fresh := load("res://resources/equipment/loadouts/nightmare_alpha.tres") as EquipmentLoadout
		equipment.loadout = fresh.duplicate(true) as EquipmentLoadout
		equipment.rebuild()
	_play_pose(0)


func _on_equipment_changed(_slot: int, _item: EquipmentItemData) -> void:
	_update_info()


func _on_equipment_failed(reason: String) -> void:
	if info != null:
		info.text += "\nERROR: " + reason


func _add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.03, 0.04, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.4, 0.5, 1.0)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.25
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.2
	var world := WorldEnvironment.new()
	world.name = "LabEnvironment"
	world.environment = env
	add_child(world)


func _update_info() -> void:
	if info == null:
		return
	var body_id := &"-"
	var weapon_id := &"-"
	var accessory_id := &"-"
	if equipment != null:
		var body := equipment.get_equipped(EquipmentItemData.Slot.BODY)
		var weapon := equipment.get_equipped(EquipmentItemData.Slot.WEAPON)
		var accessory := equipment.get_equipped(EquipmentItemData.Slot.ACCESSORY)
		body_id = body.id if body != null else &"-"
		weapon_id = weapon.id if weapon != null else &"-"
		accessory_id = accessory.id if accessory != null else &"-"
	info.text = "EQUIPMENT ALPHA\n1/2 — A/B set\n3 — body on/off\n4 — weapon\n5 — accessory\n6 — pose\nR — reset\n\nbody: %s\nweapon: %s\naccessory: %s\npose: %s" % [
		body_id,
		weapon_id,
		accessory_id,
		_poses[_pose_index]["label"] if _pose_index < _poses.size() else "?",
	]
