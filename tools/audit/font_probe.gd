extends SceneTree
## Read-only кириллический аудит шрифтов UI/диалогов/подсказок.
##
## Проверяет каждый вес из RpgMenuTheme, fallback Godot, шрифт Label3D и
## засечный шрифт карты. Возвращает exit code 1, если хотя бы в одном весе нет
## русского глифа. Запуск:
##   godot --headless --path . -s tools/audit/font_probe.gd

const REQUIRED := "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя«»—–…"

var _checked := {}
var _fail := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	print("FONT_AUDIT fallback=", ThemeDB.fallback_font.get_font_name())
	_check(&"ThemeDB.fallback_font", ThemeDB.fallback_font)

	var theme := RpgMenuTheme.build()
	_check(&"RpgMenuTheme.default_font", theme.default_font)
	for type in theme.get_type_list():
		for item in theme.get_font_list(type):
			var font := theme.get_font(item, type)
			if font == null:
				continue
			var id := font.get_instance_id()
			if _checked.has(id):
				continue
			_check(StringName("%s/%s" % [type, item]), font)

	for spacing in [0, 2]:
		_check(StringName("MapPaint.serif_font(%d)" % spacing), MapPaint.serif_font(spacing))

	# Label3D по умолчанию не хранит Font в свойстве font и рисует через
	# встроенный fallback Godot; проверяем именно его.
	var label3d := Label3D.new()
	var label_font: Font = label3d.font if label3d.font != null else ThemeDB.fallback_font
	_check(&"Label3D.default", label_font)
	label3d.free()

	print("FONT_AUDIT_RESULT checked=", _checked.size(), " fail=", _fail)
	quit(0 if _fail == 0 else 1)


func _check(label: StringName, font: Font) -> void:
	if font == null:
		print("FONT_AUDIT_FAIL ", label, " font=<null>")
		_fail += 1
		return
	var missing := ""
	for i in REQUIRED.length():
		var code := REQUIRED.unicode_at(i)
		if not font.has_char(code):
			missing += REQUIRED[i]
	if missing.is_empty():
		print("FONT_AUDIT_OK ", label, " name=", font.get_font_name())
	else:
		print("FONT_AUDIT_FAIL ", label, " name=", font.get_font_name(), " missing=", missing)
		_fail += 1
	_checked[font.get_instance_id()] = true
