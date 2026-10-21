extends GutTest
## Экран рун Санни: канонические значения статуса (гл. 2) и их отображение.

const SHEET := "res://resources/spell/sunny_status.tres"
const UI_SCENE := "res://scenes/ui/prologue_ui.tscn"


func test_canonical_values() -> void:
	var sheet := load(SHEET) as StatusSheet
	assert_eq(sheet.name_rune, "Sunless")
	assert_eq(sheet.rank, "Aspirant")
	assert_eq(sheet.soul_core, "Dormant")
	assert_eq(Array(sheet.attributes), ["Fated", "Mark of Divinity", "Child of Shadows"])
	assert_eq(sheet.aspect, "Temple Slave")
	assert_false(sheet.aspect_description.is_empty())


func test_rune_screen_rows() -> void:
	var ui := (load(UI_SCENE) as PackedScene).instantiate() as PrologueUI
	add_child_autofree(ui)
	ui.rune_status.fill(load(SHEET))
	var rows := ui.rune_status.row_texts()
	assert_has(rows, "Имя: Sunless")
	assert_has(rows, "Ранг: Aspirant")
	assert_has(rows, "Ядро души: Dormant")
	assert_has(rows, "Атрибуты: [Fated], [Mark of Divinity], [Child of Shadows]")
	assert_has(rows, "Аспект: [Temple Slave]")


func test_present_and_close() -> void:
	var ui := (load(UI_SCENE) as PackedScene).instantiate() as PrologueUI
	add_child_autofree(ui)
	watch_signals(ui.rune_status)
	ui.rune_status.present(load(SHEET))
	assert_true(ui.rune_status.visible)
	assert_true(ui.rune_status.showing)
	ui.rune_status.close()
	assert_false(ui.rune_status.visible)
	assert_signal_emitted(ui.rune_status, "closed")


func test_ui_starts_clean_except_black_screen() -> void:
	var ui := (load(UI_SCENE) as PackedScene).instantiate() as PrologueUI
	add_child_autofree(ui)
	assert_false(ui.rune_status.visible)
	assert_false(ui.spell_message.visible)
	assert_false(ui.end_card.visible)
	assert_false(ui.hint.visible)
	assert_eq(ui.fade.color.a, 1.0, "срез открывается из темноты")
