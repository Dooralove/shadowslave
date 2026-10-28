extends Node
## Состояние прохождения Первого Кошмара между сценами.
##
## Autoload. Хранит только сюжетные флаги и предметы, а не ссылки на узлы:
## поэтому состояние переживает change_scene_to_file() и не зависит от того,
## какая сцена сейчас загружена. Кампания вызывает reset() при старте и по R.

signal flag_changed(name: StringName, value: bool)
signal item_changed(id: StringName, count: int)
signal state_reset

## Сюжетные предметы, которые разрешено хранить в инвентаре.
## Атрибуты вроде Mark of Divinity хранятся сюжетными флагами, а не здесь.
const ITEM_IDS: Array[StringName] = [
	&"key",
	&"silver_bell",
	&"cloak",
	&"boots",
	&"flasks",
	&"sword",
	&"puppeteer_shroud",
	&"shadow_blessing",
]

var _flags: Dictionary = {}
var _items: Dictionary = {}


## Полный сброс перед новым прохождением или отладочным запуском.
func reset() -> void:
	_flags.clear()
	_items.clear()
	state_reset.emit()


func set_flag(flag_name: StringName, value := true) -> void:
	var key := StringName(flag_name)
	var enabled := bool(value)
	var previous := _flags.has(key)
	if previous == enabled:
		return
	if enabled:
		_flags[key] = true
	else:
		_flags.erase(key)
	flag_changed.emit(key, enabled)


func clear_flag(flag_name: StringName) -> void:
	set_flag(flag_name, false)


func has_flag(flag_name: StringName) -> bool:
	return _flags.has(StringName(flag_name))


func get_flag(flag_name: StringName, default_value := false) -> bool:
	return bool(_flags.get(StringName(flag_name), default_value))


## Все перечисленные флаги должны быть установлены.
func require(flags: Array[StringName]) -> bool:
	for flag in flags:
		if not has_flag(flag):
			return false
	return true


## Сюжетный предмет. count <= 0 удаляет предмет; значение хранится как
## количество, чтобы фляги можно было собирать по одной.
func set_item(id: StringName, count := 1) -> void:
	var key := StringName(id)
	var previous := int(_items.get(key, 0))
	var next := maxi(int(count), 0)
	if previous == next:
		return
	if next <= 0:
		_items.erase(key)
	else:
		_items[key] = next
	item_changed.emit(key, next)


func add_item(id: StringName, count := 1) -> void:
	set_item(id, get_item_count(id) + maxi(int(count), 0))


## Возвращает true, если предмета хватило и он был списан.
func remove_item(id: StringName, count := 1) -> bool:
	var key := StringName(id)
	var amount := maxi(int(count), 0)
	var current := get_item_count(key)
	if amount <= 0 or current < amount:
		return false
	set_item(key, current - amount)
	return true


func has_item(id: StringName) -> bool:
	return get_item_count(id) > 0


func get_item_count(id: StringName) -> int:
	return int(_items.get(StringName(id), 0))


## Копия для отладки, сохранения или сравнения в тестах.
func snapshot() -> Dictionary:
	return {
		"flags": _flags.duplicate(true),
		"items": _items.duplicate(true),
	}


func restore(snapshot_value: Dictionary) -> void:
	reset()
	var flags_value: Variant = snapshot_value.get("flags", {})
	if flags_value is Dictionary:
		for key in flags_value:
			if bool(flags_value[key]):
				_flags[StringName(key)] = true
	var items_value: Variant = snapshot_value.get("items", {})
	if items_value is Dictionary:
		for key in items_value:
			var count := int(items_value[key])
			if count > 0:
				_items[StringName(key)] = count
