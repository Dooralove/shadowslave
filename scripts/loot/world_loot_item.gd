class_name WorldLootItem
extends RigidBody3D
## Физический предмет лута в мире.
##
## Это RigidBody3D с светящимся кристаллом, подписью и двумя путями подбора:
## Interactable (кнопка взаимодействия) и Area3D (автоподбор, если включён).
## Предмет не выдаётся в инвентарь при смерти врага — только при подборе.

signal picked_up(item: EquipmentItemData, quantity: int)
signal pickup_failed(reason: String)

const PICKUP_CUE := &"world_pickup"

@export var item: EquipmentItemData
@export var quantity := 1
@export var pickup_radius := 2.2
@export var auto_pickup := false
@export var inventory_path: NodePath
@export var glow_color := Color(0.92, 0.56, 0.22)
@export var lifetime := 120.0
@export var bob_height := 0.07
@export var bob_speed := 2.0
@export var spin_speed := 1.4

var _inventory: InventoryComponent
var _interactable: Interactable
var _pickup_area: Area3D
var _visual: Node3D
var _light: OmniLight3D
var _label: Label3D
var _time := 0.0
var _picked := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	mass = 0.3
	linear_damp = 0.9
	angular_damp = 2.0
	continuous_cd = true
	if item != null:
		glow_color = _color_for_item(item)
	_build_body()
	_build_interactable()
	_build_pickup_area()
	_update_presentation()
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(_expire)


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var sphere := SphereShape3D.new()
	sphere.radius = 0.16
	shape.shape = sphere
	add_child(shape)

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var gem := MeshInstance3D.new()
	gem.name = "Gem"
	var mesh := SphereMesh.new()
	mesh.radius = 0.115
	mesh.height = 0.23
	mesh.radial_segments = 8
	mesh.rings = 4
	gem.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = glow_color
	material.metallic = 0.35
	material.roughness = 0.2
	material.emission_enabled = true
	material.emission = glow_color
	material.emission_energy_multiplier = 2.6
	gem.material_override = material
	_visual.add_child(gem)

	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = 0.19
	halo_mesh.height = 0.38
	halo_mesh.radial_segments = 12
	halo_mesh.rings = 6
	halo.mesh = halo_mesh
	var halo_material := StandardMaterial3D.new()
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.albedo_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.12)
	halo_material.emission_enabled = true
	halo_material.emission = glow_color
	halo_material.emission_energy_multiplier = 1.2
	halo.material_override = halo_material
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(halo)

	_light = OmniLight3D.new()
	_light.name = "Glow"
	_light.light_color = glow_color
	_light.light_energy = 1.15
	_light.omni_range = 2.4
	_light.omni_attenuation = 1.6
	_light.shadow_enabled = false
	_visual.add_child(_light)

	_label = Label3D.new()
	_label.name = "Label"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 28
	_label.outline_size = 6
	_label.pixel_size = 0.004
	_label.position = Vector3(0.0, 0.36, 0.0)
	_label.modulate = Color(1.0, 0.92, 0.78, 1.0)
	_label.outline_modulate = Color(0.05, 0.03, 0.02, 0.95)
	_label.no_depth_test = true
	add_child(_label)


func _build_interactable() -> void:
	_interactable = Interactable.new()
	_interactable.name = "Interactable"
	_interactable.interaction_id = &"loot_pickup"
	_interactable.radius = pickup_radius
	_interactable.enabled = true
	_interactable.interact_cue = PICKUP_CUE
	add_child(_interactable)
	_interactable.interacted.connect(_on_interacted)


func _build_pickup_area() -> void:
	_pickup_area = Area3D.new()
	_pickup_area.name = "PickupArea"
	_pickup_area.collision_layer = 0
	_pickup_area.collision_mask = 2
	_pickup_area.monitoring = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = pickup_radius
	shape.shape = sphere
	_pickup_area.add_child(shape)
	add_child(_pickup_area)
	_pickup_area.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _picked:
		return
	_time += delta
	if _visual != null:
		_visual.position.y = sin(_time * bob_speed) * bob_height
		_visual.rotation.y += spin_speed * delta
	if _light != null:
		_light.light_energy = 0.9 + sin(_time * 2.4) * 0.25


func _update_presentation() -> void:
	if item == null:
		return
	glow_color = _color_for_item(item)
	_apply_glow_color()
	if _label != null:
		var suffix := " x%d" % quantity if quantity > 1 else ""
		_label.text = "%s%s" % [item.display_name, suffix]
	if _interactable != null:
		_interactable.prompt = "Подобрать: %s" % item.display_name


func _apply_glow_color() -> void:
	if _visual == null:
		return
	var gem := _visual.get_node_or_null("Gem") as MeshInstance3D
	if gem != null and gem.material_override is StandardMaterial3D:
		var gem_material := gem.material_override as StandardMaterial3D
		gem_material.albedo_color = glow_color
		gem_material.emission = glow_color
	var halo := _visual.get_node_or_null("Halo") as MeshInstance3D
	if halo != null and halo.material_override is StandardMaterial3D:
		var halo_material := halo.material_override as StandardMaterial3D
		halo_material.albedo_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.12)
		halo_material.emission = glow_color
	if _light != null:
		_light.light_color = glow_color


func _color_for_item(value: EquipmentItemData) -> Color:
	var armor := value as ArmorItem
	if armor != null:
		return armor.rarity_color
	return Color(0.92, 0.56, 0.22)


func apply_launch(impulse: Vector3) -> void:
	linear_velocity = impulse
	angular_velocity = Vector3(
		randf_range(-3.0, 3.0),
		randf_range(-3.0, 3.0),
		randf_range(-3.0, 3.0)
	)


func set_item(value: EquipmentItemData, amount := 1) -> void:
	item = value
	quantity = maxi(amount, 1)
	_update_presentation()


func get_prompt() -> String:
	return "Подобрать: %s" % (item.display_name if item != null else "предмет")


func _on_interacted(_id: StringName) -> void:
	# Interactable уже проиграл world_pickup; второй cue здесь был бы дублем.
	_try_pickup(false)


func _on_body_entered(body: Node3D) -> void:
	if not auto_pickup or _picked:
		return
	if body.is_in_group(&"player"):
		_try_pickup(false)


func _try_pickup(play_cue: bool) -> bool:
	if _picked:
		return false
	if item == null:
		pickup_failed.emit("У предмета нет item")
		return false
	var inventory := _resolve_inventory()
	if inventory != null:
		if not inventory.add_item(item, quantity):
			pickup_failed.emit("Инвентарь не принял предмет")
			_show_error("Инвентарь полон")
			return false
	else:
		# Кампания хранит предметы в NightmareRunState, демо-арена — в
		# InventoryComponent. Подбор работает в обоих режимах.
		var run_state := get_node_or_null(^"/root/NightmareRunState")
		if run_state == null or not run_state.has_method(&"add_item"):
			pickup_failed.emit("Не найден ни InventoryComponent, ни NightmareRunState")
			_show_error("Нет инвентаря")
			return false
		run_state.call(&"add_item", item.id, quantity)
	_picked = true
	if play_cue:
		var director := get_node_or_null(^"/root/AudioDirector")
		if director != null and director.has_method(&"play_ui"):
			director.call(&"play_ui", &"ui_item_pickup", -4.0)
	OneShotVfx.spawn_dust(global_position + Vector3.UP * 0.2)
	picked_up.emit(item, quantity)
	queue_free()
	return true


func _resolve_inventory() -> InventoryComponent:
	if _inventory != null and is_instance_valid(_inventory):
		return _inventory
	if not inventory_path.is_empty():
		_inventory = get_node_or_null(inventory_path) as InventoryComponent
	if _inventory == null:
		_inventory = get_tree().get_first_node_in_group(&"player_inventory") as InventoryComponent
	return _inventory


func _show_error(text: String) -> void:
	if _label != null:
		_label.text = text
		_label.modulate = Color(1.0, 0.45, 0.4, 1.0)


func _expire() -> void:
	if not _picked:
		queue_free()
