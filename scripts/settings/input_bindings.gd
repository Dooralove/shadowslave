class_name InputBindings
extends RefCounted
## Справочник переназначаемых действий и утилиты для работы с событиями ввода.
##
## Хранит человекочитаемые названия, разбиение по разделам и преобразование
## InputEvent в строку/словарь. Формат словаря используется GameSettings для
## сохранения в user://settings.cfg, поэтому его нельзя менять без миграции.

const ACTIONS: Array[StringName] = [
	&"move_forward",
	&"move_back",
	&"move_left",
	&"move_right",
	&"sprint",
	&"jump",
	&"attack",
	&"interact",
	&"advance_dialogue",
	&"open_status",
	&"open_map",
	&"open_character",
	&"open_inventory",
	&"open_soul_sea",
	&"release_mouse",
	&"restart",
]

const ACTION_TITLES := {
	&"move_forward": "Движение вперёд",
	&"move_back": "Движение назад",
	&"move_left": "Влево",
	&"move_right": "Вправо",
	&"sprint": "Бег / блок",
	&"jump": "Прыжок / уклонение",
	&"attack": "Удар",
	&"interact": "Взаимодействие",
	&"advance_dialogue": "Следующая реплика",
	&"open_status": "Статус Заклятия",
	&"open_map": "Карта",
	&"open_character": "Меню персонажа",
	&"open_inventory": "Рюкзак",
	&"open_soul_sea": "Море Души",
	&"release_mouse": "Пауза / освободить мышь",
	&"restart": "Перезапуск",
}

## Дефолтные привязки геймпада. Применяются только к действиям без
## пользовательского override: ручная перенастройка не должна получать
## неожиданные дополнительные кнопки. Формат: int — кнопка, [axis, value] — стик.
const GAMEPAD_DEFAULTS := {
	&"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"sprint": JOY_BUTTON_LEFT_SHOULDER,
	&"jump": JOY_BUTTON_A,
	&"attack": JOY_BUTTON_X,
	&"interact": JOY_BUTTON_Y,
	&"advance_dialogue": JOY_BUTTON_A,
	&"open_status": JOY_BUTTON_BACK,
	&"open_map": JOY_BUTTON_DPAD_UP,
	&"open_character": JOY_BUTTON_DPAD_DOWN,
	&"open_inventory": JOY_BUTTON_DPAD_LEFT,
	&"open_soul_sea": JOY_BUTTON_DPAD_RIGHT,
	&"release_mouse": JOY_BUTTON_START,
}

const SECTIONS := [
	{
		"title": "ДВИЖЕНИЕ",
		"actions": [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"jump"],
	},
	{
		"title": "БОЙ И ВЗАИМОДЕЙСТВИЕ",
		"actions": [&"attack", &"interact", &"advance_dialogue"],
	},
	{
		"title": "ИНТЕРФЕЙС",
		"actions": [
			&"open_status",
			&"open_map",
			&"open_character",
			&"open_inventory",
			&"open_soul_sea",
			&"release_mouse",
		],
	},
	{
		"title": "СЛУЖЕБНЫЕ",
		"actions": [&"restart"],
	},
]


static func action_title(action: StringName) -> String:
	return str(ACTION_TITLES.get(action, action))


## Возвращает новые события геймпада для действия. Пустой массив, если
## у действия нет дефолта или оно переопределено пользователем.
static func default_gamepad_events(action: StringName) -> Array:
	var result: Array = []
	var entry: Variant = GAMEPAD_DEFAULTS.get(action, null)
	if entry == null:
		return result
	if entry is Array:
		if entry.size() == 2 and entry[0] is int and entry[1] is float:
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(entry[0])
			motion.axis_value = float(entry[1])
			motion.device = -1
			result.append(motion)
	elif entry is int:
		var button := InputEventJoypadButton.new()
		button.button_index = int(entry)
		button.device = -1
		result.append(button)
	return result


## Создаёт независимую копию события из сырого ввода, пригодную для InputMap
## и сохранения. Мышь и геймпад сохраняются как есть; клавиши — по physical
## keycode, чтобы раскладка не ломала WASD.
static func event_from_input(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var source_key := event as InputEventKey
		var code := source_key.physical_keycode
		if code == 0:
			code = source_key.keycode
		if code == 0:
			return null
		var key := InputEventKey.new()
		key.physical_keycode = code
		key.keycode = 0
		if not [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META].has(code):
			key.ctrl_pressed = source_key.ctrl_pressed
			key.shift_pressed = source_key.shift_pressed
			key.alt_pressed = source_key.alt_pressed
			key.meta_pressed = source_key.meta_pressed
		return key
	if event is InputEventMouseButton:
		var source_mouse := event as InputEventMouseButton
		var mouse := InputEventMouseButton.new()
		mouse.button_index = source_mouse.button_index
		mouse.ctrl_pressed = source_mouse.ctrl_pressed
		mouse.shift_pressed = source_mouse.shift_pressed
		mouse.alt_pressed = source_mouse.alt_pressed
		mouse.meta_pressed = source_mouse.meta_pressed
		return mouse
	if event is InputEventJoypadButton:
		var source_button := event as InputEventJoypadButton
		var button := InputEventJoypadButton.new()
		button.button_index = source_button.button_index
		button.device = -1
		return button
	if event is InputEventJoypadMotion:
		var source_motion := event as InputEventJoypadMotion
		if absf(source_motion.axis_value) < 0.01:
			return null
		var motion := InputEventJoypadMotion.new()
		motion.axis = source_motion.axis
		motion.axis_value = 1.0 if source_motion.axis_value > 0.0 else -1.0
		motion.device = -1
		return motion
	return null


static func serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		return {
			"type": "key",
			"physical_keycode": int(key.physical_keycode),
			"keycode": int(key.keycode),
			"ctrl": key.ctrl_pressed,
			"shift": key.shift_pressed,
			"alt": key.alt_pressed,
			"meta": key.meta_pressed,
		}
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return {
			"type": "mouse",
			"button_index": int(mouse.button_index),
			"ctrl": mouse.ctrl_pressed,
			"shift": mouse.shift_pressed,
			"alt": mouse.alt_pressed,
			"meta": mouse.meta_pressed,
		}
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		return {"type": "joy_button", "button_index": int(button.button_index)}
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return {
			"type": "joy_motion",
			"axis": int(motion.axis),
			"axis_value": 1.0 if motion.axis_value > 0.0 else -1.0,
		}
	return {}


static func deserialize_event(data: Dictionary) -> InputEvent:
	match String(data.get("type", "")):
		"key":
			var code := int(data.get("physical_keycode", 0))
			if code == 0:
				code = int(data.get("keycode", 0))
			if code == 0:
				return null
			var key := InputEventKey.new()
			key.physical_keycode = code
			key.keycode = 0
			key.ctrl_pressed = bool(data.get("ctrl", false))
			key.shift_pressed = bool(data.get("shift", false))
			key.alt_pressed = bool(data.get("alt", false))
			key.meta_pressed = bool(data.get("meta", false))
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = clampi(int(data.get("button_index", MOUSE_BUTTON_LEFT)), 1, 9)
			mouse.ctrl_pressed = bool(data.get("ctrl", false))
			mouse.shift_pressed = bool(data.get("shift", false))
			mouse.alt_pressed = bool(data.get("alt", false))
			mouse.meta_pressed = bool(data.get("meta", false))
			return mouse
		"joy_button":
			var button := InputEventJoypadButton.new()
			button.button_index = clampi(int(data.get("button_index", 0)), 0, 31)
			button.device = -1
			return button
		"joy_motion":
			var motion := InputEventJoypadMotion.new()
			motion.axis = clampi(int(data.get("axis", 0)), 0, 7)
			motion.axis_value = 1.0 if float(data.get("axis_value", 1.0)) >= 0.0 else -1.0
			motion.device = -1
			return motion
	return null


static func events_equal(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	if a is InputEventKey and b is InputEventKey:
		var key_a := a as InputEventKey
		var key_b := b as InputEventKey
		return (
			_key_code(key_a) == _key_code(key_b)
			and key_a.ctrl_pressed == key_b.ctrl_pressed
			and key_a.shift_pressed == key_b.shift_pressed
			and key_a.alt_pressed == key_b.alt_pressed
			and key_a.meta_pressed == key_b.meta_pressed
		)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		var mouse_a := a as InputEventMouseButton
		var mouse_b := b as InputEventMouseButton
		return (
			mouse_a.button_index == mouse_b.button_index
			and mouse_a.ctrl_pressed == mouse_b.ctrl_pressed
			and mouse_a.shift_pressed == mouse_b.shift_pressed
			and mouse_a.alt_pressed == mouse_b.alt_pressed
			and mouse_a.meta_pressed == mouse_b.meta_pressed
		)
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		var motion_a := a as InputEventJoypadMotion
		var motion_b := b as InputEventJoypadMotion
		return motion_a.axis == motion_b.axis and signf(motion_a.axis_value) == signf(motion_b.axis_value)
	return false


static func event_text(event: InputEvent) -> String:
	if event == null:
		return "—"
	if event is InputEventKey:
		var key := event as InputEventKey
		return _modifier_prefix(key) + OS.get_keycode_string(_key_code(key))
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		var button := "Мышь %d" % mouse.button_index
		match mouse.button_index:
			MOUSE_BUTTON_LEFT:
				button = "ЛКМ"
			MOUSE_BUTTON_RIGHT:
				button = "ПКМ"
			MOUSE_BUTTON_MIDDLE:
				button = "СКМ"
		return _modifier_prefix(mouse) + button
	if event is InputEventJoypadButton:
		var button_index := (event as InputEventJoypadButton).button_index
		var button_name := str(button_index)
		if Input.has_method(&"get_joy_button_string"):
			var resolved := String(Input.call(&"get_joy_button_string", button_index)).strip_edges()
			if not resolved.is_empty():
				button_name = resolved
		return "Геймпад: %s" % button_name
	if event is InputEventJoypadMotion:
		var axis := (event as InputEventJoypadMotion).axis
		var direction := "+" if (event as InputEventJoypadMotion).axis_value > 0.0 else "−"
		var axis_name := str(axis)
		if Input.has_method(&"get_joy_axis_string"):
			var resolved := String(Input.call(&"get_joy_axis_string", axis)).strip_edges()
			if not resolved.is_empty():
				axis_name = resolved
		return "Стик: %s %s" % [axis_name, direction]
	return event.as_text()


static func events_text(events: Array) -> String:
	var parts: Array[String] = []
	for event in events:
		if event is InputEvent:
			var text := event_text(event)
			if not text.is_empty() and not parts.has(text):
				parts.append(text)
	return " / ".join(parts) if not parts.is_empty() else "—"


static func _key_code(event: InputEventKey) -> int:
	return event.physical_keycode if event.physical_keycode != 0 else event.keycode


static func _modifier_prefix(event: InputEventWithModifiers) -> String:
	var prefix := ""
	if event.ctrl_pressed:
		prefix += "Ctrl+"
	if event.shift_pressed:
		prefix += "Shift+"
	if event.alt_pressed:
		prefix += "Alt+"
	if event.meta_pressed:
		prefix += "Meta+"
	return prefix
