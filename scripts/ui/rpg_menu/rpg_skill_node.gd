class_name RpgSkillNode
extends Button
## Карточка узла DEMO-дерева. Отображает состояние и выбранный узел,
## но не меняет данные: решение об изучении принимает экран аспекта.

@onready var code_label: Label = %Code
@onready var state_label: Label = %State
@onready var name_label: Label = %Name

var skill: RpgDemoSkill
var node_state: RpgDemoSkillSession.State = RpgDemoSkillSession.State.LOCKED
var selected := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func setup(data: RpgDemoSkill, state: RpgDemoSkillSession.State, is_selected: bool) -> void:
	skill = data
	node_state = state
	selected = is_selected
	if not is_node_ready():
		await ready

	code_label.text = skill.code
	name_label.text = skill.display_name
	state_label.text = "%s %s" % [state_mark(state), state_title(state)]
	state_label.add_theme_color_override("font_color", state_color(state))
	name_label.add_theme_color_override("font_color", _name_color(state))
	code_label.add_theme_color_override("font_color", _code_color(state))
	_apply_style()
	tooltip_text = "%s\n%s · %s" % [
		skill.display_name,
		skill.branch_title,
		state_title(state),
	]


func set_selected(is_selected: bool) -> void:
	if selected == is_selected:
		return
	selected = is_selected
	_apply_style()


static func state_title(state: RpgDemoSkillSession.State) -> String:
	match state:
		RpgDemoSkillSession.State.LEARNED:
			return "ИЗУЧЕН"
		RpgDemoSkillSession.State.AVAILABLE:
			return "ДОСТУПЕН"
		_:
			return "ЗАБЛОКИРОВАН"


static func state_mark(state: RpgDemoSkillSession.State) -> String:
	match state:
		RpgDemoSkillSession.State.LEARNED:
			return "◆"
		RpgDemoSkillSession.State.AVAILABLE:
			return "◇"
		_:
			return "—"


static func state_color(state: RpgDemoSkillSession.State) -> Color:
	match state:
		RpgDemoSkillSession.State.LEARNED:
			return RpgMenuTheme.BRONZE_BRIGHT
		RpgDemoSkillSession.State.AVAILABLE:
			return RpgMenuTheme.TEXT_BRIGHT
		_:
			return RpgMenuTheme.DIM


func _name_color(state: RpgDemoSkillSession.State) -> Color:
	match state:
		RpgDemoSkillSession.State.LEARNED:
			return RpgMenuTheme.BRONZE_BRIGHT
		RpgDemoSkillSession.State.AVAILABLE:
			return RpgMenuTheme.TEXT_BRIGHT
		_:
			return RpgMenuTheme.MUTED


func _code_color(state: RpgDemoSkillSession.State) -> Color:
	if state == RpgDemoSkillSession.State.LOCKED:
		return RpgMenuTheme.DIM
	return RpgMenuTheme.BRONZE


func _apply_style() -> void:
	var normal := _state_box()
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", _hover_box(normal))
	add_theme_stylebox_override("pressed", _hover_box(normal))
	add_theme_stylebox_override("hover_pressed", _hover_box(normal))
	add_theme_stylebox_override("focus", _focus_box())


func _state_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 2
	box.border_width_left = 3 if selected or node_state == RpgDemoSkillSession.State.LEARNED else 2
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1

	match node_state:
		RpgDemoSkillSession.State.LEARNED:
			box.bg_color = Color(0.13, 0.108, 0.073, 0.94)
			box.border_color = (
				RpgMenuTheme.BRONZE_BRIGHT if selected else RpgMenuTheme.BRONZE
			)
		RpgDemoSkillSession.State.AVAILABLE:
			box.bg_color = Color(0.062, 0.067, 0.068, 0.92)
			box.border_color = (
				RpgMenuTheme.BRONZE_BRIGHT if selected else RpgMenuTheme.BRONZE_DIM
			)
		_:
			box.bg_color = Color(0.035, 0.038, 0.04, 0.82)
			box.border_color = (
				RpgMenuTheme.BRONZE_DIM if selected else RpgMenuTheme.LINE_SOFT
			)
	return box


func _hover_box(base: StyleBoxFlat) -> StyleBoxFlat:
	var box := base.duplicate() as StyleBoxFlat
	box.bg_color = base.bg_color.lightened(0.055)
	if node_state != RpgDemoSkillSession.State.LOCKED:
		box.border_color = RpgMenuTheme.BRONZE
	return box


func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.border_color = Color(0.83, 0.68, 0.46, 0.9)
	box.expand_margin_left = 2.0
	box.expand_margin_top = 2.0
	box.expand_margin_right = 2.0
	box.expand_margin_bottom = 2.0
	return box
