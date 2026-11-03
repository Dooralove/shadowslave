class_name CutsceneUI
extends CanvasLayer
## Служебный UI кат-сцены: субтитры, затемнение, letterbox, skip prompt.

const SUBTITLES_SCENE := preload("res://scenes/ui/cutscene_subtitles.tscn")

var fade: ColorRect
var letterbox: Control
var skip_label: Label
var skip_progress: ProgressBar
var hint_label: Label
var title_label: Label
var subtitles: SubtitleUI
var dialogue_runner: DialogueRunner

var _fast := false
var _fade_tween: Tween
var _letterbox_tween: Tween
var _hint_timer: Timer
var _title_timer: Timer


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func begin_run(definition: CutsceneDefinition) -> void:
	fade.modulate.a = 0.0
	letterbox.visible = definition.letterbox
	letterbox.modulate.a = 1.0
	skip_label.visible = false
	skip_progress.visible = false
	skip_progress.value = 0.0
	hint_label.visible = false
	title_label.visible = false
	if subtitles != null:
		subtitles.hide_line()
	if dialogue_runner != null:
		dialogue_runner.fast_mode = _fast


func hide_for_idle() -> void:
	fade.modulate.a = 0.0
	letterbox.visible = false
	skip_label.visible = false
	skip_progress.visible = false
	skip_progress.value = 0.0
	hint_label.visible = false
	title_label.visible = false
	if subtitles != null:
		subtitles.hide_line()


func set_fast_mode(value: bool) -> void:
	_fast = value
	if dialogue_runner != null:
		dialogue_runner.fast_mode = value


func get_dialogue_runner() -> DialogueRunner:
	return dialogue_runner


func cancel_dialogue() -> void:
	if dialogue_runner != null:
		dialogue_runner.cancel()
	if subtitles != null:
		subtitles.hide_line()


func cancel_tweens() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	if _letterbox_tween != null and _letterbox_tween.is_valid():
		_letterbox_tween.kill()
	_letterbox_tween = null
	if _hint_timer != null:
		_hint_timer.stop()
	if _title_timer != null:
		_title_timer.stop()


func fade_to(alpha: float, duration := 0.4) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	if _fast or duration <= 0.0:
		fade.modulate.a = alpha
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade, "modulate:a", alpha, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _fade_tween.finished
	_fade_tween = null


func fade_clear(duration := 0.0) -> void:
	await fade_to(0.0, duration)


func letterbox_on(duration := 0.3) -> void:
	if _letterbox_tween != null and _letterbox_tween.is_valid():
		_letterbox_tween.kill()
	_letterbox_tween = null
	if _fast or duration <= 0.0:
		letterbox.visible = true
		letterbox.modulate.a = 1.0
		return
	letterbox.visible = true
	letterbox.modulate.a = 0.0
	_letterbox_tween = create_tween()
	_letterbox_tween.tween_property(letterbox, "modulate:a", 1.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _letterbox_tween.finished
	_letterbox_tween = null


func letterbox_off(duration := 0.3) -> void:
	if _letterbox_tween != null and _letterbox_tween.is_valid():
		_letterbox_tween.kill()
	_letterbox_tween = null
	if _fast or duration <= 0.0:
		letterbox.visible = false
		letterbox.modulate.a = 0.0
		return
	_letterbox_tween = create_tween()
	_letterbox_tween.tween_property(letterbox, "modulate:a", 0.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _letterbox_tween.finished
	letterbox.visible = false
	_letterbox_tween = null


func show_skip_prompt(on: bool) -> void:
	skip_label.visible = on
	skip_progress.visible = on
	if not on:
		skip_progress.value = 0.0


func set_skip_progress(value: float) -> void:
	skip_progress.value = clampf(value, 0.0, 1.0)


func show_hint(text: String, duration := 0.0) -> void:
	hint_label.text = text
	hint_label.visible = not text.is_empty()
	if duration > 0.0 and not _fast:
		_hint_timer.start(duration)
	else:
		_hint_timer.stop()


func show_title(text: String, subtitle := "", duration := 2.0) -> void:
	var full := text
	if not subtitle.is_empty():
		full += "\n" + subtitle
	title_label.text = full
	title_label.visible = true
	if duration > 0.0 and not _fast:
		_title_timer.start(duration)
	else:
		_title_timer.stop()


func snapshot() -> Dictionary:
	var hud_visibility := {}
	for node in _collect_hud_nodes():
		if node is CanvasLayer:
			hud_visibility[node] = node.visible
	return {
		"hud": hud_visibility,
		"fade": fade.modulate.a,
		"letterbox": letterbox.visible,
	}


func restore(data: Dictionary) -> void:
	var hud_visibility: Dictionary = data.get("hud", {})
	for node in hud_visibility:
		if is_instance_valid(node) and node is CanvasLayer:
			node.visible = bool(hud_visibility[node])
	fade.modulate.a = float(data.get("fade", 0.0))
	letterbox.visible = bool(data.get("letterbox", false))
	if not letterbox.visible:
		letterbox.modulate.a = 0.0


func set_hud_visible(on: bool) -> void:
	for node in _collect_hud_nodes():
		if node is CanvasLayer:
			node.visible = on


func _collect_hud_nodes() -> Array[Node]:
	var result: Array[Node] = []
	for node in get_tree().get_nodes_in_group(&"gameplay_hud"):
		if node not in result:
			result.append(node)
	var scene := get_tree().current_scene
	if scene != null:
		for node in scene.find_children("*", "GameplayHud", true, false):
			if node not in result:
				result.append(node)
	return result


func _build_ui() -> void:
	fade = ColorRect.new()
	fade.name = "Fade"
	fade.color = Color(0.0, 0.0, 0.0, 1.0)
	fade.modulate.a = 0.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	letterbox = Control.new()
	letterbox.name = "Letterbox"
	letterbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(letterbox)
	letterbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	letterbox.visible = false

	var top := ColorRect.new()
	top.color = Color.BLACK
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.anchor_right = 1.0
	top.offset_bottom = 80.0
	letterbox.add_child(top)

	var bottom := ColorRect.new()
	bottom.color = Color.BLACK
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.anchor_top = 1.0
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -80.0
	letterbox.add_child(bottom)

	subtitles = SUBTITLES_SCENE.instantiate() as SubtitleUI
	subtitles.name = "CutsceneSubtitles"
	add_child(subtitles)

	dialogue_runner = DialogueRunner.new()
	dialogue_runner.name = "CutsceneDialogueRunner"
	dialogue_runner.subtitles = subtitles
	add_child(dialogue_runner)

	title_label = Label.new()
	title_label.name = "Title"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override(&"font_size", 34)
	title_label.add_theme_color_override(&"font_color", Color(0.94, 0.88, 0.72))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.visible = false
	add_child(title_label)
	title_label.set_anchors_preset(Control.PRESET_CENTER)
	title_label.offset_left = -420.0
	title_label.offset_top = -90.0
	title_label.offset_right = 420.0
	title_label.offset_bottom = 90.0

	hint_label = Label.new()
	hint_label.name = "Hint"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override(&"font_size", 18)
	hint_label.add_theme_color_override(&"font_color", Color(0.92, 0.9, 0.84))
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.visible = false
	add_child(hint_label)
	hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint_label.offset_left = -420.0
	hint_label.offset_top = 24.0
	hint_label.offset_right = 420.0
	hint_label.offset_bottom = 70.0

	skip_label = Label.new()
	skip_label.name = "SkipLabel"
	skip_label.text = "Удерживайте Backspace — пропустить"
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_label.add_theme_font_size_override(&"font_size", 16)
	skip_label.add_theme_color_override(&"font_color", Color(0.92, 0.9, 0.84))
	skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_label.visible = false
	add_child(skip_label)
	skip_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_label.offset_left = -430.0
	skip_label.offset_top = -52.0
	skip_label.offset_right = -24.0
	skip_label.offset_bottom = -20.0

	skip_progress = ProgressBar.new()
	skip_progress.name = "SkipProgress"
	skip_progress.show_percentage = false
	skip_progress.max_value = 1.0
	skip_progress.value = 0.0
	skip_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_progress.visible = false
	add_child(skip_progress)
	skip_progress.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_progress.offset_left = -260.0
	skip_progress.offset_top = -18.0
	skip_progress.offset_right = -24.0
	skip_progress.offset_bottom = -10.0

	_hint_timer = Timer.new()
	_hint_timer.one_shot = true
	_hint_timer.timeout.connect(_on_hint_timeout)
	add_child(_hint_timer)

	_title_timer = Timer.new()
	_title_timer.one_shot = true
	_title_timer.timeout.connect(_on_title_timeout)
	add_child(_title_timer)


func _on_hint_timeout() -> void:
	hint_label.visible = false


func _on_title_timeout() -> void:
	title_label.visible = false
