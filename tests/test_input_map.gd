extends GutTest
## Действия ввода, на которые опираются персонаж и камера, должны быть настроены в project.godot.

const REQUIRED_ACTIONS := [
	"move_forward",
	"move_back",
	"move_left",
	"move_right",
	"sprint",
	"jump",
	"release_mouse",
	"capture_mouse",
	"attack",
	"restart",
	"interact",
	"advance_dialogue",
	"open_status",
	"open_map",
	"open_character",
]

const EXPECTED_KEYS := {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"sprint": KEY_SHIFT,
	"jump": KEY_SPACE,
	"release_mouse": KEY_ESCAPE,
	"restart": KEY_R,
	"interact": KEY_E,
	"advance_dialogue": KEY_SPACE,
	"open_status": KEY_TAB,
	"open_map": KEY_M,
	"open_character": KEY_C,
}


func test_required_actions_exist_with_events() -> void:
	for action in REQUIRED_ACTIONS:
		assert_true(InputMap.has_action(action), "нет действия %s" % action)
		if InputMap.has_action(action):
			assert_gt(InputMap.action_get_events(action).size(), 0, "у %s нет привязок" % action)


func test_keyboard_bindings() -> void:
	for action in EXPECTED_KEYS:
		var found := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and (event.physical_keycode == EXPECTED_KEYS[action] or event.keycode == EXPECTED_KEYS[action]):
				found = true
		assert_true(found, "%s должно быть привязано к %s" % [action, OS.get_keycode_string(EXPECTED_KEYS[action])])


func test_mouse_actions_are_left_click() -> void:
	for action in ["capture_mouse", "attack"]:
		var found := false
		for event in InputMap.action_get_events(action):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				found = true
		assert_true(found, "%s должно быть на левой кнопке мыши" % action)
