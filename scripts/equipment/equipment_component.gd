class_name EquipmentComponent
extends Node
## Надевает цельный skinned-сет брони на общий Skeleton3D персонажа и
## цепляет оружие/аксессуары на BoneAttachment3D.
##
## Компонент не создаёт второй скелет и не копирует позы. Броня — это
## MeshInstance3D с Skin, который ссылается на существующий Skeleton3D.
## Визуал всегда пересобирается из Resource-описаний, поэтому сейв хранит
## только ID предметов.

signal equipment_changed(slot: int, item: EquipmentItemData)
signal visuals_rebuilt
signal equipment_failed(reason: String)
signal loadout_changed(loadout: EquipmentLoadout)
signal weapon_drawn_changed(drawn: bool)

const EQUIPMENT_VISUAL_NAME := &"EquipmentVisual"
const MAX_ACCESSORIES := 2

@export var visual_root: Node3D
@export var skeleton_path: NodePath
@export var rig_profile: CharacterRigProfile
@export var loadout: EquipmentLoadout
@export var catalog: EquipmentCatalog
@export var ab_test: EquipmentABTest
## Необязательный агрегатор статов. Если задан, броня применяется/снимается
## вместе с визуалом, а не отдельным вызовом из UI.
@export var character_stats: CharacterStats
## Сохранять только ID надетого в NightmareRunState и восстанавливать при старте.
@export var persist_to_run_state := false
@export var auto_apply := true
@export var weapon_drawn := true
@export var debug_log := false

var _skeleton: Skeleton3D
var _equipment_root: Node3D
var _body_meshes: Array[MeshInstance3D] = []
var _weapon_visual: Node3D
var _weapon_item: WeaponData
var _weapon_socket_id: StringName = &""
var _accessory_visuals: Array[Node3D] = []
var _hidden_nodes: Dictionary = {}
var _surface_originals: Dictionary = {}
var _socket_cache: Dictionary = {}
var _ready_done := false
var _rig_valid := false
var _persistence_ready := false


func _ready() -> void:
	if visual_root == null:
		visual_root = get_parent() as Node3D
	# The exported resources are shared between scene instances.  Duplicate the
	# mutable state so equipping on one character does not change another.
	if loadout != null:
		loadout = loadout.duplicate(true) as EquipmentLoadout
	if ab_test != null:
		ab_test = ab_test.duplicate(true) as EquipmentABTest
	_skeleton = _resolve_skeleton()
	_validate_rig()
	_ready_done = true
	if auto_apply:
		rebuild()
	if persist_to_run_state:
		_persistence_ready = true
		if not restore_from_run_state():
			save_to_run_state()


func _resolve_skeleton() -> Skeleton3D:
	if visual_root == null:
		return null
	if not skeleton_path.is_empty():
		var node := visual_root.get_node_or_null(skeleton_path)
		if node is Skeleton3D:
			return node as Skeleton3D
	var found := visual_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if found != null:
		return found
	var all := visual_root.find_children("*", "Skeleton3D", true, false)
	if not all.is_empty():
		return all[0] as Skeleton3D
	return null


func _validate_rig() -> void:
	if _skeleton == null:
		_fail("не найден Skeleton3D под %s" % visual_root)
		return
	if rig_profile == null:
		_fail("rig_profile не назначен")
		return
	if debug_log:
		print("[Equipment] visual_root=", visual_root.get_path(),
			" skeleton=", _skeleton.get_path(),
			" bones=", _skeleton.get_bone_count(),
			" first_bone=", _skeleton.get_bone_name(0) if _skeleton.get_bone_count() > 0 else &"")
	var missing := rig_profile.missing_required_bones(_skeleton)
	if not missing.is_empty():
		_fail("в скелете нет обязательных костей: %s" % ", ".join(missing))
		return
	_rig_valid = true
	if debug_log:
		print("[Equipment] skeleton=", _skeleton.name, " bones=", _skeleton.get_bone_count(),
			" profile=", rig_profile.id)


func _ensure_equipment_root() -> void:
	if _equipment_root != null and is_instance_valid(_equipment_root):
		return
	_equipment_root = Node3D.new()
	_equipment_root.name = EQUIPMENT_VISUAL_NAME
	_skeleton.add_child(_equipment_root)


func rebuild() -> void:
	if not _ready_done and not is_inside_tree():
		return
	if not _rig_valid:
		return
	if _skeleton == null or not is_instance_valid(_skeleton):
		_skeleton = _resolve_skeleton()
	if _skeleton == null:
		_fail("rebuild без Skeleton3D")
		return
	_ensure_equipment_root()
	_clear_body()
	_clear_weapon()
	_clear_accessories()

	if loadout != null:
		if loadout.body != null:
			_apply_body(loadout.body)
		if loadout.weapon != null:
			_apply_weapon(loadout.weapon)
		for accessory in loadout.accessories:
			if accessory != null:
				_apply_accessory(accessory)

	visuals_rebuilt.emit()
	_notify_loadout()
	if debug_log:
		print("[Equipment] rebuilt body=%s weapon=%s accessories=%d" % [
			loadout.body.id if loadout != null and loadout.body != null else &"",
			loadout.weapon.id if loadout != null and loadout.weapon != null else &"",
			loadout.accessories.size() if loadout != null else 0,
		])


func _notify_loadout() -> void:
	if character_stats != null:
		character_stats.apply_loadout(loadout)
	if persist_to_run_state and _persistence_ready:
		save_to_run_state()
	loadout_changed.emit(loadout)


## Сохраняет только ID. Визуал всегда пересобирается из каталога.
func save_to_run_state() -> void:
	var state := _run_state()
	if state == null:
		return
	if loadout == null:
		state.call(&"clear_equipment")
	else:
		state.call(&"set_equipment_ids", loadout.to_ids())


## Восстанавливает loadout из NightmareRunState. false — сохранения нет
## или каталог не содержит один из ID.
func restore_from_run_state() -> bool:
	var state := _run_state()
	if state == null or not bool(state.call(&"has_equipment")):
		return false
	var ids: Variant = state.call(&"get_equipment_ids")
	if not (ids is Dictionary):
		return false
	return apply_ids(ids)


func _run_state() -> Node:
	return get_node_or_null(^"/root/NightmareRunState")


func equip(item: EquipmentItemData) -> bool:
	if item == null:
		return false
	if not _rig_valid:
		_fail("equip при невалидном rig_profile")
		return false
	var errors := item.validate()
	if not errors.is_empty():
		_fail("%s: %s" % [item.id, "; ".join(errors)])
		return false
	if not _rig_matches(item):
		_fail("%s: rig_profile не совпадает с %s" % [
			item.id,
			rig_profile.id if rig_profile != null else &"?",
		])
		return false
	if loadout == null:
		loadout = EquipmentLoadout.new()

	match item.slot:
		EquipmentItemData.Slot.BODY:
			if not item is ArmorSetData:
				_fail("%s: BODY должен быть ArmorSetData" % item.id)
				return false
			loadout.body = item as ArmorSetData
		EquipmentItemData.Slot.WEAPON:
			if not item is WeaponData:
				_fail("%s: WEAPON должен быть WeaponData" % item.id)
				return false
			loadout.weapon = item as WeaponData
		EquipmentItemData.Slot.ACCESSORY:
			if loadout.accessories.size() >= MAX_ACCESSORIES:
				_reject("%s: максимум %d аксессуара" % [item.id, MAX_ACCESSORIES])
				return false
			for existing in loadout.accessories:
				if existing != null and existing.id == item.id:
					_reject("%s: аксессуар уже надет" % item.id)
					return false
			loadout.accessories.append(item)
		_:
			_fail("%s: неизвестный слот" % item.id)
			return false

	rebuild()
	equipment_changed.emit(item.slot, item)
	return true


func unequip(slot: int) -> bool:
	if loadout == null:
		return false
	match slot:
		EquipmentItemData.Slot.BODY:
			loadout.body = null
		EquipmentItemData.Slot.WEAPON:
			loadout.weapon = null
		EquipmentItemData.Slot.ACCESSORY:
			loadout.accessories.clear()
		_:
			return false
	rebuild()
	equipment_changed.emit(slot, null)
	return true


func get_equipped(slot: int) -> EquipmentItemData:
	if loadout == null:
		return null
	match slot:
		EquipmentItemData.Slot.BODY:
			return loadout.body
		EquipmentItemData.Slot.WEAPON:
			return loadout.weapon
		EquipmentItemData.Slot.ACCESSORY:
			return loadout.accessories[0] if not loadout.accessories.is_empty() else null
	return null


func set_weapon_drawn(value: bool) -> void:
	var changed := weapon_drawn != value
	weapon_drawn = value
	_place_weapon()
	if changed and _weapon_item != null:
		weapon_drawn_changed.emit(weapon_drawn)


## Восстановление из сейва: только ID, визуал пересобирается заново.
func apply_ids(ids: Dictionary, source_catalog: EquipmentCatalog = null) -> bool:
	if not _rig_valid:
		_fail("apply_ids при невалидном rig_profile")
		return false
	var cat := source_catalog if source_catalog != null else catalog
	if cat == null:
		_fail("apply_ids без EquipmentCatalog")
		return false
	var next := EquipmentLoadout.new()
	var body_id := StringName(ids.get("body", &""))
	var weapon_id := StringName(ids.get("weapon", &""))
	if body_id != &"":
		next.body = cat.get_armor(body_id)
		if next.body == null:
			_fail("apply_ids: броня %s не найдена" % body_id)
			return false
	if weapon_id != &"":
		next.weapon = cat.get_weapon(weapon_id)
		if next.weapon == null:
			_fail("apply_ids: оружие %s не найдено" % weapon_id)
			return false
	var accessory_value: Variant = ids.get("accessories", [])
	if accessory_value is Array:
		for raw_id in accessory_value:
			var accessory := cat.get_item(StringName(raw_id))
			if accessory == null:
				_fail("apply_ids: аксессуар %s не найден" % raw_id)
				return false
			if next.accessories.size() >= MAX_ACCESSORIES:
				_fail("apply_ids: слишком много аксессуаров")
				return false
			for existing in next.accessories:
				if existing != null and existing.id == accessory.id:
					_fail("apply_ids: аксессуар %s указан дважды" % accessory.id)
					return false
			next.accessories.append(accessory)
	# apply_ids — такой же вход в экипировку, как equip(): проверяем
	# визуал, сокеты и профиль скелета до замены текущего loadout.
	var candidates: Array[EquipmentItemData] = []
	if next.body != null:
		candidates.append(next.body)
	if next.weapon != null:
		candidates.append(next.weapon)
	candidates.append_array(next.accessories)
	for candidate in candidates:
		if candidate == null:
			continue
		var candidate_errors := candidate.validate()
		if not candidate_errors.is_empty():
			_fail("apply_ids %s: %s" % [candidate.id, "; ".join(candidate_errors)])
			return false
		if not _rig_matches(candidate):
			_fail("apply_ids %s: rig_profile не совпадает с %s" % [
				candidate.id,
				rig_profile.id if rig_profile != null else &"?",
			])
			return false
	loadout = next
	rebuild()
	return true


func set_ab_variant(variant: StringName) -> bool:
	if ab_test == null:
		_fail("set_ab_variant без ab_test")
		return false
	var armor := ab_test.get_variant(variant)
	if armor == null:
		_fail("A/B-вариант %s не назначен" % variant)
		return false
	ab_test.active_variant = variant
	return equip(armor)


func _rig_matches(item: EquipmentItemData) -> bool:
	if rig_profile == null or item.rig_profile == null:
		return true
	return rig_profile.id == item.rig_profile.id


func _apply_body(item: ArmorSetData) -> void:
	if item.visual_scene == null:
		_fail("броня %s без visual_scene" % item.id)
		return
	var instance := item.visual_scene.instantiate() as Node3D
	if instance == null:
		_fail("не удалось инстанциировать %s" % item.id)
		return
	var armor_skeleton := instance.find_child("Skeleton3D", true, false) as Skeleton3D
	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	var applied := 0
	for node in meshes:
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.skin == null:
			continue
		if _attach_skinned_mesh(mesh, item, armor_skeleton):
			applied += 1
	instance.free()
	if applied == 0:
		_fail("в сцене %s нет skinned-мешей" % item.id)
		return
	_apply_hide_rules(item)
	if item.enable_lod and _has_lod_meshes(_body_meshes):
		_configure_lod_ranges(item)


func _has_lod_meshes(meshes: Array[MeshInstance3D]) -> bool:
	for mesh in meshes:
		var lower := String(mesh.name).to_lower()
		if lower.contains("lod1") or lower.contains("lod2"):
			return true
	return false


## LOD-переключение делает рендерер через visibility_range. Базовая броня
## остаётся LOD0; _LOD1/_LOD2 должны быть в том же skinned GLB.
func _configure_lod_ranges(item: ArmorSetData) -> void:
	var lod1 := maxf(item.lod1_distance, 1.0)
	var lod2 := maxf(item.lod2_distance, lod1 + 1.0)
	for mesh in _body_meshes:
		if mesh == null or not is_instance_valid(mesh):
			continue
		var lower := String(mesh.name).to_lower()
		if lower.contains("lod2"):
			mesh.visibility_range_begin = lod2
			mesh.visibility_range_end = 0.0
		elif lower.contains("lod1"):
			mesh.visibility_range_begin = lod1
			mesh.visibility_range_end = lod2
		else:
			mesh.visibility_range_begin = 0.0
			mesh.visibility_range_end = lod1
		mesh.visibility_range_begin_margin = 0.5
		mesh.visibility_range_end_margin = 0.5
		if debug_log:
			print("[Equipment] LOD ", mesh.name,
				" begin=", mesh.visibility_range_begin,
				" end=", mesh.visibility_range_end)


func _attach_skinned_mesh(mesh: MeshInstance3D, item: EquipmentItemData, armor_skeleton: Skeleton3D) -> bool:
	if armor_skeleton != null and not _remap_skin(mesh, armor_skeleton):
		return false
	var parent := mesh.get_parent()
	if parent != null:
		parent.remove_child(mesh)
	mesh.owner = null
	var preserved := mesh.transform
	_equipment_root.add_child(mesh)
	mesh.transform = item.get_visual_transform() * preserved
	mesh.skeleton = mesh.get_path_to(_skeleton)
	mesh.visible = true
	# У брони пока нет собственных LOD; CharacterLodVisibility не должен
	# прятать её на средней/дальней дистанции вместе с телом.
	mesh.add_to_group(&"lod_ignore")
	_body_meshes.append(mesh)
	if debug_log:
		print("[Equipment] attached ", mesh.name, " skin=", mesh.skin, " skeleton_path=", mesh.skeleton)
	return true


## Пересобирает Skin по именам костей. Нужен, если порядок костей в броне
## отличается от базового скелета. Rest pose при этом всё равно должен совпадать.
func _remap_skin(mesh: MeshInstance3D, armor_skeleton: Skeleton3D) -> bool:
	var source := mesh.skin
	if source == null:
		return true
	var remapped := Skin.new()
	for i in source.get_bind_count():
		# glTF с use_named_skins может хранить имя вместо индекса.
		var bind_name := source.get_bind_name(i)
		var bone_name := bind_name
		if bone_name == &"":
			var source_bone := source.get_bind_bone(i)
			if source_bone < 0 or source_bone >= armor_skeleton.get_bone_count():
				_fail("skin %s: bind %d вне скелета брони" % [mesh.name, i])
				return false
			bone_name = armor_skeleton.get_bone_name(source_bone)
		var target_bone := _find_bone_normalized(bone_name)
		if target_bone < 0:
			_fail("skin %s: в базовом скелете нет кости %s" % [mesh.name, bone_name])
			return false
		remapped.add_bind(target_bone, source.get_bind_pose(i))
		remapped.set_bind_name(remapped.get_bind_count() - 1, bone_name)
	mesh.skin = remapped
	return true


## glTF-экспортёры иногда добавляют префикс mixamorig: или меняют регистр.
## Это не должно ломать надевание: ищем по нормализованному имени.
func _find_bone_normalized(bone_name: StringName) -> int:
	if _skeleton == null:
		return -1
	var direct := _skeleton.find_bone(bone_name)
	if direct >= 0:
		return direct
	var raw := String(bone_name)
	for prefix in ["mixamorig:", "mixamorig_", "Armature|", "root|"]:
		if raw.begins_with(prefix):
			var stripped := StringName(raw.substr(prefix.length()))
			var found := _skeleton.find_bone(stripped)
			if found >= 0:
				return found
	var lowered := raw.to_lower()
	for index in _skeleton.get_bone_count():
		if String(_skeleton.get_bone_name(index)).to_lower() == lowered:
			return index
	return -1


func _place_weapon() -> void:
	if _weapon_visual == null or not is_instance_valid(_weapon_visual) or _weapon_item == null:
		return
	var socket_id := _weapon_item.grip_socket if weapon_drawn else _weapon_item.sheath_socket
	if socket_id == &"":
		socket_id = _weapon_item.attach_socket
	var socket := _get_socket_if_bone_exists(socket_id)
	if socket == null:
		# Нет сокета в руке — это ошибка экипировки. Нет сокета ножен — это
		# допустимая деградация: оружие просто скрывается.
		if weapon_drawn:
			_fail("оружие %s: сокет %s не найден" % [_weapon_item.id, socket_id])
		_weapon_visual.visible = false
		return
	if _weapon_visual.get_parent() != socket:
		var parent := _weapon_visual.get_parent()
		if parent != null:
			parent.remove_child(_weapon_visual)
		socket.add_child(_weapon_visual)
	_weapon_visual.transform = (
		_weapon_item.get_grip_transform() if weapon_drawn else _weapon_item.get_sheath_transform()
	)
	_weapon_visual.visible = weapon_drawn or _weapon_item.visible_when_sheathed
	_weapon_socket_id = socket_id
	if debug_log:
		print("[Equipment] weapon ", _weapon_item.id, " drawn=", weapon_drawn,
			" socket=", socket.name, " visible=", _weapon_visual.visible)


func _get_socket_if_bone_exists(socket_id: StringName) -> BoneAttachment3D:
	if socket_id == &"" or _skeleton == null:
		return null
	var bone_name := socket_id
	if rig_profile != null:
		var mapped := rig_profile.resolve_socket_bone(socket_id)
		if mapped != &"":
			bone_name = mapped
	if _skeleton.find_bone(bone_name) < 0:
		return null
	return _get_or_create_socket(socket_id)


func _apply_weapon(item: WeaponData) -> void:
	if item.visual_scene == null:
		_fail("оружие %s без visual_scene" % item.id)
		return
	var visual := item.visual_scene.instantiate() as Node3D
	if visual == null:
		_fail("не удалось инстанциировать оружие %s" % item.id)
		return
	visual.name = "Weapon_%s" % item.id
	_weapon_item = item
	_weapon_visual = visual
	_place_weapon()
	if _weapon_visual.get_parent() == null:
		_dispose_visual(_weapon_visual)
		_weapon_visual = null
		_weapon_item = null
		return
	if debug_log:
		print("[Equipment] weapon ", item.id, " socket=", _weapon_socket_id,
			" visible=", _weapon_visual.visible)


func _apply_accessory(item: EquipmentItemData) -> void:
	if item.visual_scene == null:
		_fail("аксессуар %s без visual_scene" % item.id)
		return
	var socket := _get_or_create_socket(item.attach_socket)
	if socket == null:
		return
	var visual := item.visual_scene.instantiate() as Node3D
	if visual == null:
		_fail("не удалось инстанциировать аксессуар %s" % item.id)
		return
	visual.name = "Accessory_%s" % item.id
	visual.transform = item.get_visual_transform()
	socket.add_child(visual)
	_accessory_visuals.append(visual)


func _get_or_create_socket(socket_id: StringName) -> BoneAttachment3D:
	if socket_id == &"":
		_fail("пустой socket_id")
		return null
	if _socket_cache.has(socket_id) and is_instance_valid(_socket_cache[socket_id]):
		return _socket_cache[socket_id] as BoneAttachment3D
	var bone_name := StringName(socket_id)
	if rig_profile != null:
		var mapped := rig_profile.resolve_socket_bone(socket_id)
		if mapped != &"":
			bone_name = mapped
	var bone_idx := _skeleton.find_bone(bone_name)
	if bone_idx < 0:
		_fail("сокет %s: кость %s не найдена" % [socket_id, bone_name])
		return null
	var socket := BoneAttachment3D.new()
	socket.name = "Socket_%s" % socket_id
	socket.bone_name = bone_name
	_skeleton.add_child(socket)
	socket.bone_idx = bone_idx
	_socket_cache[socket_id] = socket
	return socket


func _apply_hide_rules(item: ArmorSetData) -> void:
	if item.mode == ArmorSetData.Mode.REPLACEMENT:
		_hide_node_named("model")
	for part in item.hide_parts:
		_hide_node_named(part)
	if not item.hide_part_prefixes.is_empty():
		_hide_nodes_with_prefixes(item.hide_part_prefixes)
	if not item.hide_surfaces.is_empty():
		_hide_surfaces(item.hide_surfaces)


func _hide_node_named(node_name: String) -> void:
	if node_name.is_empty():
		return
	var node := visual_root.get_node_or_null(NodePath(node_name))
	if node == null:
		node = visual_root.find_child(node_name, true, false)
	if node == null:
		if debug_log:
			print("[Equipment] hide part not found: ", node_name)
		return
	if not _hidden_nodes.has(node):
		_hidden_nodes[node] = node.visible
	node.visible = false


func _hide_nodes_with_prefixes(prefixes: PackedStringArray) -> void:
	if visual_root == null:
		return
	for node in visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null:
			continue
		var node_name := String(mesh.name)
		for prefix in prefixes:
			if prefix != "" and node_name.begins_with(prefix):
				if not _hidden_nodes.has(mesh):
					_hidden_nodes[mesh] = mesh.visible
				mesh.visible = false
				break


func _hide_surfaces(hidden: PackedInt32Array) -> void:
	for node in visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or not mesh.mesh is ArrayMesh:
			continue
		if _equipment_root != null and _equipment_root.is_ancestor_of(mesh):
			continue
		var source := mesh.mesh as ArrayMesh
		if source.get_surface_count() <= _max_surface_index(hidden):
			continue
		if not _surface_originals.has(mesh):
			_surface_originals[mesh] = source
		mesh.mesh = _filtered_mesh(source, hidden)
		if debug_log:
			print("[Equipment] surfaces hidden on ", mesh.name, " -> ", hidden)


func _filtered_mesh(source: ArrayMesh, hidden: PackedInt32Array) -> ArrayMesh:
	var result := ArrayMesh.new()
	for i in source.get_surface_count():
		if _contains_surface(hidden, i):
			continue
		var arrays := source.surface_get_arrays(i)
		result.add_surface_from_arrays(source.surface_get_primitive_type(i), arrays)
		var new_index := result.get_surface_count() - 1
		result.surface_set_material(new_index, source.surface_get_material(i))
	return result


func _max_surface_index(hidden: PackedInt32Array) -> int:
	var maximum := -1
	for value in hidden:
		maximum = maxi(maximum, value)
	return maximum


func _contains_surface(hidden: PackedInt32Array, index: int) -> bool:
	for value in hidden:
		if value == index:
			return true
	return false


func _dispose_visual(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.queue_free()


func _clear_body() -> void:
	for mesh in _body_meshes:
		_dispose_visual(mesh)
	_body_meshes.clear()
	for node in _hidden_nodes.keys():
		if is_instance_valid(node):
			node.visible = _hidden_nodes[node]
	_hidden_nodes.clear()
	for mesh in _surface_originals.keys():
		if is_instance_valid(mesh):
			mesh.mesh = _surface_originals[mesh]
	_surface_originals.clear()


func _clear_weapon() -> void:
	_dispose_visual(_weapon_visual)
	_weapon_visual = null
	_weapon_item = null
	_weapon_socket_id = &""


func _clear_accessories() -> void:
	for visual in _accessory_visuals:
		_dispose_visual(visual)
	_accessory_visuals.clear()


## Ожидаемый отказ пользовательского действия: без ERROR в консоли.
func _reject(reason: String) -> void:
	push_warning("[Equipment] " + reason)
	equipment_failed.emit(reason)


func _fail(reason: String) -> void:
	push_error("[Equipment] " + reason)
	equipment_failed.emit(reason)
