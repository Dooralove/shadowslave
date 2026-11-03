extends SceneTree
## Диагностика: поддерживает ли системный шрифт кириллицу и как выглядит строка.


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var theme := RpgMenuTheme.build()
	var font: Font = theme.default_font
	print("FONT=", font.get_font_name() if font != null else "<null>")
	for ch in ["О", "т", "п", "и", "т", "ь", "Р", "Ã"]:
		var code: int = ch.unicode_at(0)
		print("CHAR=", ch, " code=", code, " has=", font.has_char(code) if font != null else false)
	print("PROMPT=", "E — Отпить")
	quit()
