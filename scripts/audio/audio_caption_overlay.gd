class_name AudioCaptionOverlay
extends CanvasLayer
## Minimal accessibility overlay for important non-dialogue sounds.
## Dialogue subtitles remain owned by the dialogue UI.

const HOLD_SECONDS := 2.5

var _panel: PanelContainer
var _label: Label
var _generation := 0
var _scene: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 96
	var root := Control.new()
	root.name = "CaptionRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.name = "CaptionPanel"
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -280.0
	_panel.offset_right = 280.0
	_panel.offset_top = -168.0
	_panel.offset_bottom = -108.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	root.add_child(_panel)

	_label = Label.new()
	_label.name = "CaptionLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 18)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)


func show_caption(text: String) -> void:
	if text.strip_edges().is_empty() or _panel == null:
		return
	_scene = get_tree().current_scene
	_generation += 1
	var generation := _generation
	_label.text = text
	_panel.visible = true
	_panel.modulate.a = 1.0
	await get_tree().create_timer(HOLD_SECONDS, true).timeout
	if generation != _generation or _panel == null:
		return
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.35)
	await tween.finished
	if generation == _generation and _panel != null:
		_panel.visible = false


func clear() -> void:
	_generation += 1
	if _panel != null:
		_panel.visible = false


## Подпись не должна переезжать в следующую сцену: при смене current_scene
## старый текст исчезает, иначе он накладывается на подсказки новой сцены.
func _process(_delta: float) -> void:
	if _scene == null:
		return
	var current := get_tree().current_scene
	if current != _scene:
		_scene = current
		clear()
