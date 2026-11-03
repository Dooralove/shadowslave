extends GutTest
## Alpha-проверки слоя экипировки: данные, shared skeleton, сокеты, скрытие
## одежды и A/B-переключение. Тесты не трогают кампанию и сохранения.

const LAB := "res://scenes/dev/equipment_lab.tscn"
const ARMOR_A := "res://resources/equipment/armor/caravan_alpha.tres"
const ARMOR_B := "res://resources/equipment/armor/coral_alpha.tres"
const WEAPON := "res://resources/equipment/weapons/short_sword_alpha.tres"
const ACCESSORY := "res://resources/equipment/accessories/water_flask_alpha.tres"
const LOADOUT := "res://resources/equipment/loadouts/nightmare_alpha.tres"

var lab: Node3D
var equipment: EquipmentComponent
var skeleton: Skeleton3D
var base_mesh: MeshInstance3D


func before_each() -> void:
	lab = (load(LAB) as PackedScene).instantiate() as Node3D
	add_child_autofree(lab)
	await wait_process_frames(2)
	equipment = lab.get_node("Equipment") as EquipmentComponent
	skeleton = lab.get_node("Sunny/Model/Armature/Skeleton3D") as Skeleton3D
	base_mesh = lab.get_node("Sunny/Model/Armature/Skeleton3D/model") as MeshInstance3D


func test_rig_profile_has_required_bones_and_sockets() -> void:
	var profile := load("res://resources/equipment/rig_profiles/generated_v3.tres") as CharacterRigProfile
	assert_not_null(profile)
	assert_eq(profile.id, &"generated_v3")
	assert_eq(profile.resolve_socket_bone(&"hand_r"), &"RightHand")
	assert_eq(profile.resolve_socket_bone(&"hips"), &"Hips")
	assert_eq(profile.missing_required_bones(skeleton).size(), 0)


func test_armor_resources_are_valid() -> void:
	for path in [ARMOR_A, ARMOR_B]:
		var armor := load(path) as ArmorSetData
		assert_not_null(armor, path)
		assert_eq(armor.validate().size(), 0, "%s: %s" % [path, armor.validate()])
		assert_eq(armor.slot, EquipmentItemData.Slot.BODY)
		assert_eq(armor.hide_surfaces, PackedInt32Array([1, 2, 3]))


func test_body_attaches_to_shared_skeleton_and_hides_clothing() -> void:
	assert_not_null(equipment.get_equipped(EquipmentItemData.Slot.BODY))
	assert_eq(equipment.get_equipped(EquipmentItemData.Slot.BODY).id, &"caravan_alpha")
	var armor_meshes := _equipment_meshes()
	assert_gt(armor_meshes.size(), 0, "нет skinned-меша брони")
	var lod0_count := 0
	for mesh in armor_meshes:
		assert_not_null(mesh.skin)
		var resolved := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		assert_eq(resolved, skeleton, "броня ссылается не на общий скелет")
		var mesh_name := String(mesh.name).to_lower()
		if not mesh_name.contains("lod1") and not mesh_name.contains("lod2"):
			lod0_count += 1
			assert_gt(mesh.visibility_range_end, 0.0, "LOD0 должен иметь visibility_range_end")
	assert_eq(lod0_count, 1, "в сете должен быть ровно один LOD0-меш")
	assert_eq(base_mesh.mesh.get_surface_count(), 1, "одежда должна быть скрыта, остаётся body surface")


func test_weapon_uses_right_hand_socket() -> void:
	var socket := skeleton.get_node_or_null("Socket_hand_r") as BoneAttachment3D
	assert_not_null(socket)
	assert_eq(socket.bone_name, &"RightHand")
	assert_eq(socket.get_child_count(), 1)
	assert_eq(equipment.get_equipped(EquipmentItemData.Slot.WEAPON).id, &"short_sword_alpha")


func test_accessory_uses_hip_socket() -> void:
	var socket := skeleton.get_node_or_null("Socket_hips") as BoneAttachment3D
	assert_not_null(socket)
	assert_eq(socket.bone_name, &"Hips")
	assert_eq(socket.get_child_count(), 1)
	assert_eq(equipment.get_equipped(EquipmentItemData.Slot.ACCESSORY).id, &"water_flask_alpha")


func test_unequip_restores_clothing_surfaces() -> void:
	assert_eq(base_mesh.mesh.get_surface_count(), 1)
	equipment.unequip(EquipmentItemData.Slot.BODY)
	await wait_process_frames(1)
	assert_eq(base_mesh.mesh.get_surface_count(), 4, "исходные surface должны вернуться")
	assert_eq(_equipment_meshes().size(), 0, "меши брони должны быть удалены")


func test_ab_switch_changes_body() -> void:
	assert_true(equipment.set_ab_variant(&"B"))
	await wait_process_frames(1)
	assert_eq(equipment.get_equipped(EquipmentItemData.Slot.BODY).id, &"coral_alpha")
	assert_gt(_equipment_meshes().size(), 0)


func test_loadout_serializes_ids_only() -> void:
	var loadout := load(LOADOUT) as EquipmentLoadout
	assert_not_null(loadout)
	var ids := loadout.to_ids()
	assert_eq(ids["body"], &"caravan_alpha")
	assert_eq(ids["weapon"], &"short_sword_alpha")
	assert_eq(ids["accessories"][0], &"water_flask_alpha")


func test_duplicate_accessory_is_rejected() -> void:
	var accessory := load(ACCESSORY) as EquipmentItemData
	assert_not_null(accessory)
	assert_false(equipment.equip(accessory), "один и тот же аксессуар не должен дублироваться")
	assert_eq(equipment.loadout.accessories.size(), 1)


func test_run_state_equipment_roundtrip() -> void:
	var state: Node = (load("res://scripts/campaign/nightmare_run_state.gd") as GDScript).new()
	add_child_autofree(state)
	state.call(&"set_equipment_ids", {
		"body": &"caravan_alpha",
		"weapon": &"short_sword_alpha",
		"accessories": [&"water_flask_alpha"],
	})
	var snapshot: Dictionary = state.call(&"snapshot")
	assert_eq(snapshot["equipment"]["body"], &"caravan_alpha")
	state.call(&"reset")
	state.call(&"restore", snapshot)
	var restored: Dictionary = state.call(&"get_equipment_ids")
	assert_eq(restored["body"], &"caravan_alpha")
	assert_eq(restored["weapon"], &"short_sword_alpha")
	assert_eq(restored["accessories"][0], &"water_flask_alpha")


func test_combat_bridge_controls_weapon_visibility() -> void:
	var player := (load("res://scenes/dev/sunny_equipment_preview.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	await wait_process_frames(2)
	var combat := player.get_node("CombatController") as CombatController
	var gear := player.get_node("Equipment") as EquipmentComponent
	assert_not_null(combat)
	assert_not_null(gear)
	var animator := player.get_node("Animator") as SunnyAnimator
	assert_not_null(animator)
	assert_true(animator.animation_player.has_animation(&"Sword_Attack"))
	combat.set_unarmed(false)
	assert_true(gear.weapon_drawn)
	combat.set_unarmed(true)
	assert_false(gear.weapon_drawn)


func test_p1_profile_attaches_full_set() -> void:
	var scene := (load("res://scenes/dev/equipment_lab_p1.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	await wait_process_frames(2)
	var gear := scene.get_node("Equipment") as EquipmentComponent
	var skeleton: Skeleton3D
	for node in scene.find_children("*", "Skeleton3D", true, false):
		if (node as Skeleton3D).get_bone_count() == 53:
			skeleton = node as Skeleton3D
			break
	assert_not_null(gear)
	assert_not_null(skeleton)
	assert_eq(skeleton.get_bone_count(), 53)
	assert_eq(gear.get_equipped(EquipmentItemData.Slot.BODY).id, &"caravan_alpha_p1")
	var armor_root := skeleton.get_node_or_null("EquipmentVisual") as Node3D
	assert_not_null(armor_root)
	assert_gt(armor_root.find_children("*", "MeshInstance3D", true, false).size(), 0)


func test_v3_sword_attack_clip_is_available() -> void:
	var player := (load("res://assets/characters/sunny_realistic_poc/sunny_waking_poc.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	await wait_process_frames(2)
	var animator := player.get_node("Animator") as SunnyAnimator
	assert_not_null(animator)
	assert_true(animator.animation_player.has_animation(&"Sword_Attack"))


func test_real_v3_split_attaches() -> void:
	var scene := (load("res://scenes/dev/equipment_lab_v3.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	await wait_process_frames(2)
	var gear := scene.get_node("Equipment") as EquipmentComponent
	assert_not_null(gear)
	assert_eq(gear.get_equipped(EquipmentItemData.Slot.BODY).id, &"caravan_alpha_v3")
	var skeleton: Skeleton3D
	for node in scene.find_children("*", "Skeleton3D", true, false):
		if (node as Skeleton3D).get_bone_count() == 52:
			skeleton = node as Skeleton3D
			break
	assert_not_null(skeleton)
	var armor_root := skeleton.get_node_or_null("EquipmentVisual") as Node3D
	assert_not_null(armor_root)
	assert_gt(armor_root.find_children("*", "MeshInstance3D", true, false).size(), 0)


func test_demo_session_equips_real_component() -> void:
	var session := RpgDemoSession.new()
	var demo_catalog := load("res://resources/rpg_menu/demo_catalog.tres") as RpgDemoCatalog
	session.initialize(demo_catalog)
	session.set_equipment_component(equipment)
	var jacket := session.get_item(&"demo_quilted_jacket")
	assert_not_null(jacket)
	assert_true(session.equip_item(jacket))
	assert_eq(equipment.get_equipped(EquipmentItemData.Slot.BODY).id, &"caravan_alpha")
	assert_true(jacket.equipped)


func test_shared_loadout_resource_is_not_mutated() -> void:
	var original := load(LOADOUT) as EquipmentLoadout
	assert_not_null(original.body)
	equipment.unequip(EquipmentItemData.Slot.BODY)
	assert_not_null(original.body, "экземпляр компонента не должен менять общий .tres")


func test_apply_ids_rebuilds_loadout() -> void:
	var ids := {
		"body": &"coral_alpha",
		"weapon": &"short_sword_alpha",
		"accessories": [&"water_flask_alpha"],
	}
	assert_true(equipment.apply_ids(ids))
	await wait_process_frames(1)
	assert_eq(equipment.get_equipped(EquipmentItemData.Slot.BODY).id, &"coral_alpha")
	assert_eq(equipment.get_equipped(EquipmentItemData.Slot.WEAPON).id, &"short_sword_alpha")
	assert_eq(equipment.get_equipped(EquipmentItemData.Slot.ACCESSORY).id, &"water_flask_alpha")


func _equipment_meshes() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if skeleton == null:
		return result
	var root := skeleton.get_node_or_null("EquipmentVisual") as Node3D
	if root == null:
		return result
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh != null and mesh.skin != null:
			result.append(mesh)
	return result
