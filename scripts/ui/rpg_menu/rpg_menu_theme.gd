class_name RpgMenuTheme
extends RefCounted
## Единая визуальная тема прототипа RPG-меню.
##
## Стили и палитра собраны в одном месте, чтобы сцены описывали композицию,
## а не дублировали десятки StyleBox. Системные шрифты используются с
## фолбэком Godot; сторонние файлы шрифтов в проект не добавляются.

const BG := Color(0.043, 0.047, 0.051)
const BG_DEEP := Color(0.025, 0.027, 0.029)
const PANEL := Color(0.075, 0.082, 0.086, 0.94)
const PANEL_RAISED := Color(0.098, 0.106, 0.11, 0.94)
const LINE := Color(0.208, 0.2, 0.184, 0.85)
const LINE_SOFT := Color(0.145, 0.149, 0.141, 0.9)
const TEXT := Color(0.867, 0.843, 0.792)
const TEXT_BRIGHT := Color(0.941, 0.918, 0.867)
const MUTED := Color(0.569, 0.545, 0.502)
const DIM := Color(0.384, 0.369, 0.337)
const BRONZE := Color(0.702, 0.545, 0.345)
const BRONZE_BRIGHT := Color(0.816, 0.659, 0.435)
const BRONZE_DIM := Color(0.435, 0.341, 0.231)
const RUST := Color(0.612, 0.404, 0.345)
const SUCCESS := Color(0.69, 0.64, 0.49)
const RARITY_COMMON := Color(0.62, 0.6, 0.55)
const RARITY_NOTABLE := Color(0.69, 0.65, 0.5)
const RARITY_RARE := Color(0.57, 0.63, 0.65)
const RARITY_UNIQUE := Color(0.78, 0.63, 0.39)

static var _display_font: Font
static var _body_font: Font
static var _body_bold_font: Font
static var _micro_font: Font
static var _spaced_font: Font


static func build() -> Theme:
	_ensure_fonts()

	var theme := Theme.new()
	theme.default_font = _body_font
	theme.default_font_size = 15
	theme.set_color(&"font_color", &"Label", TEXT)
	theme.set_color(&"font_shadow_color", &"Label", Color(0, 0, 0, 0.6))
	theme.set_constant(&"shadow_offset_x", &"Label", 0)
	theme.set_constant(&"shadow_offset_y", &"Label", 1)
	theme.set_color(&"default_color", &"RichTextLabel", TEXT)
	theme.set_font(&"normal_font", &"RichTextLabel", _body_font)
	theme.set_font_size(&"normal_font_size", &"RichTextLabel", 15)

	_add_label_variations(theme)
	_add_button_variations(theme)
	_add_input_and_panels(theme)
	_add_scroll_and_tooltip(theme)
	return theme


static func apply_to(control: Control) -> void:
	control.theme = build()


static func rarity_color(rarity: int) -> Color:
	match rarity:
		RpgDemoItem.Rarity.NOTABLE:
			return RARITY_NOTABLE
		RpgDemoItem.Rarity.RARE:
			return RARITY_RARE
		RpgDemoItem.Rarity.UNIQUE:
			return RARITY_UNIQUE
		_:
			return RARITY_COMMON


static func rarity_title(rarity: int) -> String:
	match rarity:
		RpgDemoItem.Rarity.NOTABLE:
			return "ПРИМЕЧАТЕЛЬНЫЙ"
		RpgDemoItem.Rarity.RARE:
			return "РЕДКИЙ"
		RpgDemoItem.Rarity.UNIQUE:
			return "УНИКАЛЬНЫЙ"
		_:
			return "ОБЫЧНЫЙ"


static func category_title(category: int) -> String:
	match category:
		RpgDemoItem.Category.WEAPON:
			return "ОРУЖИЕ"
		RpgDemoItem.Category.ARMOR:
			return "ЭКИПИРОВКА"
		RpgDemoItem.Category.CONSUMABLE:
			return "РАСХОДНИКИ"
		RpgDemoItem.Category.RESOURCE:
			return "РЕСУРСЫ"
		RpgDemoItem.Category.STORY:
			return "СЮЖЕТНЫЕ"
		_:
			return "ВСЕ ПРЕДМЕТЫ"


static func slot_title(slot: StringName) -> String:
	match slot:
		&"weapon":
			return "ОРУЖИЕ"
		&"chest":
			return "ДОСПЕХ"
		&"cloak":
			return "ПЛАЩ"
		&"hands":
			return "ПЕРЧАТКИ"
		&"feet":
			return "ОБУВЬ"
		&"accessory":
			return "АКСЕССУАР"
		_:
			return "СЛОТ"


static func _ensure_fonts() -> void:
	if _display_font != null:
		return

	_display_font = SystemFont.new()
	(_display_font as SystemFont).font_names = PackedStringArray([
		"Palatino Linotype", "Book Antiqua", "Georgia", "Noto Serif"
	])
	(_display_font as SystemFont).allow_system_fallback = true

	_body_font = SystemFont.new()
	(_body_font as SystemFont).font_names = PackedStringArray([
		"Segoe UI", "Candara", "Noto Sans"
	])
	(_body_font as SystemFont).allow_system_fallback = true

	_body_bold_font = SystemFont.new()
	(_body_bold_font as SystemFont).font_names = PackedStringArray([
		"Segoe UI Semibold", "Segoe UI", "Candara"
	])
	(_body_bold_font as SystemFont).font_weight = 600
	(_body_bold_font as SystemFont).allow_system_fallback = true

	_micro_font = SystemFont.new()
	(_micro_font as SystemFont).font_names = PackedStringArray([
		"Segoe UI", "Candara", "Noto Sans"
	])
	(_micro_font as SystemFont).allow_system_fallback = true

	var spaced := FontVariation.new()
	spaced.base_font = _body_bold_font
	spaced.spacing_glyph = 2
	_spaced_font = spaced


static func _add_label_variations(theme: Theme) -> void:
	theme.set_type_variation(&"BrandLabel", &"Label")
	theme.set_font(&"font", &"BrandLabel", _display_font)
	theme.set_font_size(&"font_size", &"BrandLabel", 62)
	theme.set_color(&"font_color", &"BrandLabel", TEXT_BRIGHT)
	theme.set_constant(&"outline_size", &"BrandLabel", 0)

	theme.set_type_variation(&"ScreenTitle", &"Label")
	theme.set_font(&"font", &"ScreenTitle", _display_font)
	theme.set_font_size(&"font_size", &"ScreenTitle", 36)
	theme.set_color(&"font_color", &"ScreenTitle", TEXT_BRIGHT)

	theme.set_type_variation(&"ScreenTitleSmall", &"Label")
	theme.set_font(&"font", &"ScreenTitleSmall", _display_font)
	theme.set_font_size(&"font_size", &"ScreenTitleSmall", 28)
	theme.set_color(&"font_color", &"ScreenTitleSmall", TEXT_BRIGHT)

	theme.set_type_variation(&"DisplayValue", &"Label")
	theme.set_font(&"font", &"DisplayValue", _display_font)
	theme.set_font_size(&"font_size", &"DisplayValue", 22)
	theme.set_color(&"font_color", &"DisplayValue", TEXT_BRIGHT)

	theme.set_type_variation(&"SectionLabel", &"Label")
	theme.set_font(&"font", &"SectionLabel", _spaced_font)
	theme.set_font_size(&"font_size", &"SectionLabel", 13)
	theme.set_color(&"font_color", &"SectionLabel", BRONZE)

	theme.set_type_variation(&"OverlineLabel", &"Label")
	theme.set_font(&"font", &"OverlineLabel", _spaced_font)
	theme.set_font_size(&"font_size", &"OverlineLabel", 11)
	theme.set_color(&"font_color", &"OverlineLabel", MUTED)

	theme.set_type_variation(&"MicroLabel", &"Label")
	theme.set_font(&"font", &"MicroLabel", _micro_font)
	theme.set_font_size(&"font_size", &"MicroLabel", 11)
	theme.set_color(&"font_color", &"MicroLabel", MUTED)

	theme.set_type_variation(&"BodyLabel", &"Label")
	theme.set_font(&"font", &"BodyLabel", _body_font)
	theme.set_font_size(&"font_size", &"BodyLabel", 15)
	theme.set_color(&"font_color", &"BodyLabel", TEXT)

	theme.set_type_variation(&"BodyLargeLabel", &"Label")
	theme.set_font(&"font", &"BodyLargeLabel", _body_font)
	theme.set_font_size(&"font_size", &"BodyLargeLabel", 17)
	theme.set_color(&"font_color", &"BodyLargeLabel", Color(0.8, 0.78, 0.73))

	theme.set_type_variation(&"MutedLabel", &"Label")
	theme.set_font(&"font", &"MutedLabel", _body_font)
	theme.set_font_size(&"font_size", &"MutedLabel", 13)
	theme.set_color(&"font_color", &"MutedLabel", MUTED)

	theme.set_type_variation(&"TinyMutedLabel", &"Label")
	theme.set_font(&"font", &"TinyMutedLabel", _micro_font)
	theme.set_font_size(&"font_size", &"TinyMutedLabel", 10)
	theme.set_color(&"font_color", &"TinyMutedLabel", DIM)

	theme.set_type_variation(&"BronzeLabel", &"Label")
	theme.set_font(&"font", &"BronzeLabel", _body_bold_font)
	theme.set_font_size(&"font_size", &"BronzeLabel", 12)
	theme.set_color(&"font_color", &"BronzeLabel", BRONZE_BRIGHT)

	theme.set_type_variation(&"WarningLabel", &"Label")
	theme.set_font(&"font", &"WarningLabel", _body_font)
	theme.set_font_size(&"font_size", &"WarningLabel", 12)
	theme.set_color(&"font_color", &"WarningLabel", RUST)

	theme.set_type_variation(&"DraftLabel", &"Label")
	theme.set_font(&"font", &"DraftLabel", _spaced_font)
	theme.set_font_size(&"font_size", &"DraftLabel", 13)
	theme.set_color(&"font_color", &"DraftLabel", BRONZE_BRIGHT)


static func _add_button_variations(theme: Theme) -> void:
	var nav_normal := _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 14.0, 12.0)
	nav_normal.border_width_bottom = 2
	nav_normal.border_color = Color.TRANSPARENT
	var nav_hover := _box(Color(0.16, 0.15, 0.13, 0.18), BRONZE_DIM, 0, 14.0, 12.0)
	nav_hover.border_width_bottom = 1
	var nav_pressed := _box(Color(0.16, 0.14, 0.1, 0.18), BRONZE, 0, 14.0, 12.0)
	nav_pressed.border_width_bottom = 2
	var nav_focus := _box(Color(0.16, 0.14, 0.1, 0.08), BRONZE_DIM, 0, 14.0, 12.0)
	nav_focus.border_width_bottom = 1
	theme.set_type_variation(&"NavButton", &"Button")
	theme.set_font(&"font", &"NavButton", _body_bold_font)
	theme.set_font_size(&"font_size", &"NavButton", 13)
	theme.set_color(&"font_color", &"NavButton", MUTED)
	theme.set_color(&"font_hover_color", &"NavButton", TEXT_BRIGHT)
	theme.set_color(&"font_pressed_color", &"NavButton", BRONZE_BRIGHT)
	theme.set_color(&"font_focus_color", &"NavButton", TEXT)
	theme.set_stylebox(&"normal", &"NavButton", nav_normal)
	theme.set_stylebox(&"hover", &"NavButton", nav_hover)
	theme.set_stylebox(&"pressed", &"NavButton", nav_pressed)
	theme.set_stylebox(&"hover_pressed", &"NavButton", nav_pressed)
	theme.set_stylebox(&"focus", &"NavButton", nav_focus)

	var trade := _box(Color(0.1, 0.09, 0.075, 0.55), BRONZE_DIM, 1, 15.0, 9.0)
	var trade_hover := _box(Color(0.22, 0.18, 0.11, 0.38), BRONZE, 1, 15.0, 9.0)
	var trade_pressed := _box(Color(0.25, 0.2, 0.12, 0.48), BRONZE_BRIGHT, 1, 15.0, 9.0)
	theme.set_type_variation(&"TradeButton", &"Button")
	theme.set_font(&"font", &"TradeButton", _body_bold_font)
	theme.set_font_size(&"font_size", &"TradeButton", 12)
	theme.set_color(&"font_color", &"TradeButton", BRONZE_BRIGHT)
	theme.set_color(&"font_hover_color", &"TradeButton", TEXT_BRIGHT)
	theme.set_color(&"font_pressed_color", &"TradeButton", TEXT_BRIGHT)
	theme.set_stylebox(&"normal", &"TradeButton", trade)
	theme.set_stylebox(&"hover", &"TradeButton", trade_hover)
	theme.set_stylebox(&"pressed", &"TradeButton", trade_pressed)
	theme.set_stylebox(&"hover_pressed", &"TradeButton", trade_pressed)
	theme.set_stylebox(&"focus", &"TradeButton", _focus_box())

	var primary := _box(Color(0.25, 0.19, 0.11, 0.65), BRONZE_DIM, 1, 18.0, 11.0)
	var primary_hover := _box(Color(0.34, 0.25, 0.14, 0.7), BRONZE, 1, 18.0, 11.0)
	var primary_pressed := _box(Color(0.4, 0.3, 0.16, 0.75), BRONZE_BRIGHT, 1, 18.0, 11.0)
	theme.set_type_variation(&"PrimaryButton", &"Button")
	theme.set_font(&"font", &"PrimaryButton", _body_bold_font)
	theme.set_font_size(&"font_size", &"PrimaryButton", 12)
	theme.set_color(&"font_color", &"PrimaryButton", BRONZE_BRIGHT)
	theme.set_color(&"font_hover_color", &"PrimaryButton", TEXT_BRIGHT)
	theme.set_color(&"font_pressed_color", &"PrimaryButton", TEXT_BRIGHT)
	theme.set_stylebox(&"normal", &"PrimaryButton", primary)
	theme.set_stylebox(&"hover", &"PrimaryButton", primary_hover)
	theme.set_stylebox(&"pressed", &"PrimaryButton", primary_pressed)
	theme.set_stylebox(&"hover_pressed", &"PrimaryButton", primary_pressed)
	theme.set_stylebox(&"focus", &"PrimaryButton", _focus_box())

	var secondary := _box(Color(0.08, 0.085, 0.085, 0.45), LINE_SOFT, 1, 18.0, 11.0)
	var secondary_hover := _box(Color(0.13, 0.135, 0.13, 0.72), BRONZE_DIM, 1, 18.0, 11.0)
	theme.set_type_variation(&"SecondaryButton", &"Button")
	theme.set_font(&"font", &"SecondaryButton", _body_font)
	theme.set_font_size(&"font_size", &"SecondaryButton", 12)
	theme.set_color(&"font_color", &"SecondaryButton", TEXT)
	theme.set_color(&"font_hover_color", &"SecondaryButton", TEXT_BRIGHT)
	theme.set_color(&"font_pressed_color", &"SecondaryButton", BRONZE_BRIGHT)
	theme.set_stylebox(&"normal", &"SecondaryButton", secondary)
	theme.set_stylebox(&"hover", &"SecondaryButton", secondary_hover)
	theme.set_stylebox(&"pressed", &"SecondaryButton", secondary_hover)
	theme.set_stylebox(&"hover_pressed", &"SecondaryButton", secondary_hover)
	theme.set_stylebox(&"focus", &"SecondaryButton", _focus_box())

	var unavailable := _box(Color(0.06, 0.065, 0.065, 0.35), Color(0.24, 0.19, 0.17, 0.65), 1, 18.0, 11.0)
	var unavailable_hover := _box(Color(0.12, 0.09, 0.08, 0.45), Color(0.45, 0.3, 0.25, 0.7), 1, 18.0, 11.0)
	theme.set_type_variation(&"UnavailableActionButton", &"Button")
	theme.set_font(&"font", &"UnavailableActionButton", _body_font)
	theme.set_font_size(&"font_size", &"UnavailableActionButton", 12)
	theme.set_color(&"font_color", &"UnavailableActionButton", DIM)
	theme.set_color(&"font_hover_color", &"UnavailableActionButton", RUST)
	theme.set_color(&"font_pressed_color", &"UnavailableActionButton", RUST)
	theme.set_stylebox(&"normal", &"UnavailableActionButton", unavailable)
	theme.set_stylebox(&"hover", &"UnavailableActionButton", unavailable_hover)
	theme.set_stylebox(&"pressed", &"UnavailableActionButton", unavailable_hover)
	theme.set_stylebox(&"hover_pressed", &"UnavailableActionButton", unavailable_hover)
	theme.set_stylebox(&"focus", &"UnavailableActionButton", _focus_box())

	var danger := _box(Color.TRANSPARENT, Color(0.28, 0.19, 0.16, 0.7), 1, 18.0, 11.0)
	var danger_hover := _box(Color(0.18, 0.09, 0.07, 0.4), Color(0.5, 0.28, 0.22, 0.8), 1, 18.0, 11.0)
	theme.set_type_variation(&"DangerButton", &"Button")
	theme.set_font(&"font", &"DangerButton", _body_font)
	theme.set_font_size(&"font_size", &"DangerButton", 12)
	theme.set_color(&"font_color", &"DangerButton", Color(0.65, 0.45, 0.39))
	theme.set_color(&"font_hover_color", &"DangerButton", Color(0.82, 0.6, 0.52))
	theme.set_stylebox(&"normal", &"DangerButton", danger)
	theme.set_stylebox(&"hover", &"DangerButton", danger_hover)
	theme.set_stylebox(&"pressed", &"DangerButton", danger_hover)
	theme.set_stylebox(&"hover_pressed", &"DangerButton", danger_hover)
	theme.set_stylebox(&"focus", &"DangerButton", _focus_box())

	var chip := _box(Color.TRANSPARENT, LINE_SOFT, 1, 11.0, 6.0)
	var chip_hover := _box(Color(0.16, 0.14, 0.1, 0.25), BRONZE_DIM, 1, 11.0, 6.0)
	var chip_pressed := _box(Color(0.22, 0.18, 0.11, 0.4), BRONZE, 1, 11.0, 6.0)
	theme.set_type_variation(&"ChipButton", &"Button")
	theme.set_font(&"font", &"ChipButton", _micro_font)
	theme.set_font_size(&"font_size", &"ChipButton", 10)
	theme.set_color(&"font_color", &"ChipButton", MUTED)
	theme.set_color(&"font_hover_color", &"ChipButton", TEXT_BRIGHT)
	theme.set_color(&"font_pressed_color", &"ChipButton", BRONZE_BRIGHT)
	theme.set_stylebox(&"normal", &"ChipButton", chip)
	theme.set_stylebox(&"hover", &"ChipButton", chip_hover)
	theme.set_stylebox(&"pressed", &"ChipButton", chip_pressed)
	theme.set_stylebox(&"hover_pressed", &"ChipButton", chip_pressed)
	theme.set_stylebox(&"focus", &"ChipButton", _focus_box())

	var category_normal := _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 12.0, 10.0)
	category_normal.border_width_left = 2
	var category_hover := _box(Color(0.14, 0.135, 0.12, 0.25), BRONZE_DIM, 0, 12.0, 10.0)
	category_hover.border_width_left = 2
	var category_pressed := _box(Color(0.2, 0.16, 0.1, 0.35), BRONZE, 0, 12.0, 10.0)
	category_pressed.border_width_left = 2
	theme.set_type_variation(&"CategoryButton", &"Button")
	theme.set_font(&"font", &"CategoryButton", _body_font)
	theme.set_font_size(&"font_size", &"CategoryButton", 11)
	theme.set_color(&"font_color", &"CategoryButton", MUTED)
	theme.set_color(&"font_hover_color", &"CategoryButton", TEXT_BRIGHT)
	theme.set_color(&"font_pressed_color", &"CategoryButton", TEXT_BRIGHT)
	theme.set_stylebox(&"normal", &"CategoryButton", category_normal)
	theme.set_stylebox(&"hover", &"CategoryButton", category_hover)
	theme.set_stylebox(&"pressed", &"CategoryButton", category_pressed)
	theme.set_stylebox(&"hover_pressed", &"CategoryButton", category_pressed)
	theme.set_stylebox(&"focus", &"CategoryButton", _focus_box())

	var list_normal := _box(Color(0.07, 0.075, 0.078, 0.7), LINE_SOFT, 1, 12.0, 10.0)
	var list_hover := _box(Color(0.12, 0.12, 0.11, 0.85), BRONZE_DIM, 1, 12.0, 10.0)
	var list_pressed := _box(Color(0.18, 0.15, 0.1, 0.6), BRONZE, 1, 12.0, 10.0)
	theme.set_type_variation(&"ListButton", &"Button")
	theme.set_font(&"font", &"ListButton", _body_font)
	theme.set_font_size(&"font_size", &"ListButton", 12)
	theme.set_color(&"font_color", &"ListButton", TEXT)
	theme.set_color(&"font_hover_color", &"ListButton", TEXT_BRIGHT)
	theme.set_color(&"font_pressed_color", &"ListButton", TEXT_BRIGHT)
	theme.set_stylebox(&"normal", &"ListButton", list_normal)
	theme.set_stylebox(&"hover", &"ListButton", list_hover)
	theme.set_stylebox(&"pressed", &"ListButton", list_pressed)
	theme.set_stylebox(&"hover_pressed", &"ListButton", list_pressed)
	theme.set_stylebox(&"focus", &"ListButton", _focus_box())

	var tile_normal := _box(Color(0.065, 0.07, 0.073, 0.78), LINE_SOFT, 1, 0.0, 0.0)
	var tile_hover := _box(Color(0.11, 0.11, 0.105, 0.9), BRONZE_DIM, 1, 0.0, 0.0)
	var tile_pressed := _box(Color(0.15, 0.13, 0.1, 0.9), BRONZE, 1, 0.0, 0.0)
	theme.set_type_variation(&"ItemTile", &"Button")
	theme.set_stylebox(&"normal", &"ItemTile", tile_normal)
	theme.set_stylebox(&"hover", &"ItemTile", tile_hover)
	theme.set_stylebox(&"pressed", &"ItemTile", tile_pressed)
	theme.set_stylebox(&"hover_pressed", &"ItemTile", tile_pressed)
	theme.set_stylebox(&"focus", &"ItemTile", _focus_box())
	theme.set_color(&"font_color", &"ItemTile", TEXT)

	var slot_normal := _box(Color(0.052, 0.057, 0.06, 0.8), LINE_SOFT, 1, 12.0, 10.0)
	slot_normal.border_width_left = 2
	var slot_hover := _box(Color(0.1, 0.1, 0.095, 0.92), BRONZE_DIM, 1, 12.0, 10.0)
	slot_hover.border_width_left = 2
	var slot_pressed := _box(Color(0.14, 0.12, 0.085, 0.95), BRONZE, 1, 12.0, 10.0)
	slot_pressed.border_width_left = 2
	theme.set_type_variation(&"SlotButton", &"Button")
	theme.set_font(&"font", &"SlotButton", _body_font)
	theme.set_font_size(&"font_size", &"SlotButton", 12)
	theme.set_color(&"font_color", &"SlotButton", TEXT)
	theme.set_color(&"font_hover_color", &"SlotButton", TEXT_BRIGHT)
	theme.set_stylebox(&"normal", &"SlotButton", slot_normal)
	theme.set_stylebox(&"hover", &"SlotButton", slot_hover)
	theme.set_stylebox(&"pressed", &"SlotButton", slot_pressed)
	theme.set_stylebox(&"hover_pressed", &"SlotButton", slot_pressed)
	theme.set_stylebox(&"focus", &"SlotButton", _focus_box())

	var offer_normal := _box(Color(0.055, 0.06, 0.063, 0.76), LINE_SOFT, 1, 12.0, 10.0)
	offer_normal.border_width_left = 2
	var offer_hover := _box(Color(0.105, 0.1, 0.09, 0.9), BRONZE_DIM, 1, 12.0, 10.0)
	offer_hover.border_width_left = 2
	var offer_pressed := _box(Color(0.16, 0.13, 0.085, 0.92), BRONZE, 1, 12.0, 10.0)
	offer_pressed.border_width_left = 2
	theme.set_type_variation(&"OfferRow", &"Button")
	theme.set_font(&"font", &"OfferRow", _body_font)
	theme.set_font_size(&"font_size", &"OfferRow", 12)
	theme.set_color(&"font_color", &"OfferRow", TEXT)
	theme.set_color(&"font_hover_color", &"OfferRow", TEXT_BRIGHT)
	theme.set_stylebox(&"normal", &"OfferRow", offer_normal)
	theme.set_stylebox(&"hover", &"OfferRow", offer_hover)
	theme.set_stylebox(&"pressed", &"OfferRow", offer_pressed)
	theme.set_stylebox(&"hover_pressed", &"OfferRow", offer_pressed)
	theme.set_stylebox(&"focus", &"OfferRow", _focus_box())


static func _add_input_and_panels(theme: Theme) -> void:
	var edit_normal := _box(Color(0.035, 0.038, 0.04, 0.85), LINE_SOFT, 1, 11.0, 8.0)
	var edit_focus := _box(Color(0.05, 0.052, 0.05, 0.95), BRONZE_DIM, 1, 11.0, 8.0)
	theme.set_stylebox(&"normal", &"LineEdit", edit_normal)
	theme.set_stylebox(&"focus", &"LineEdit", edit_focus)
	theme.set_stylebox(&"read_only", &"LineEdit", edit_normal)
	theme.set_font(&"font", &"LineEdit", _body_font)
	theme.set_font_size(&"font_size", &"LineEdit", 13)
	theme.set_color(&"font_color", &"LineEdit", TEXT)
	theme.set_color(&"font_placeholder_color", &"LineEdit", DIM)
	theme.set_color(&"caret_color", &"LineEdit", BRONZE_BRIGHT)
	theme.set_color(&"selection_color", &"LineEdit", Color(0.7, 0.55, 0.35, 0.28))

	theme.set_type_variation(&"RpgPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"RpgPanel", _box(PANEL, LINE_SOFT, 1, 18.0, 16.0))

	theme.set_type_variation(&"SubPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"SubPanel", _box(Color(0.055, 0.06, 0.063, 0.74), LINE_SOFT, 1, 13.0, 11.0))

	theme.set_type_variation(&"DeepPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"DeepPanel", _box(Color(0.03, 0.033, 0.035, 0.92), LINE_SOFT, 1, 18.0, 16.0))

	theme.set_type_variation(&"ChromePanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"ChromePanel", _box(Color.TRANSPARENT, BRONZE_DIM, 1, 22.0, 18.0))

	theme.set_stylebox(&"panel", &"PanelContainer", _box(PANEL, LINE_SOFT, 1, 16.0, 14.0))

	var bar_bg := _box(Color(0.04, 0.043, 0.045, 0.9), LINE_SOFT, 1, 0.0, 0.0)
	bar_bg.corner_radius_top_left = 1
	bar_bg.corner_radius_top_right = 1
	bar_bg.corner_radius_bottom_left = 1
	bar_bg.corner_radius_bottom_right = 1
	var bar_fill := _box(Color(0.52, 0.4, 0.25, 0.85), Color.TRANSPARENT, 0, 0.0, 0.0)
	bar_fill.corner_radius_top_left = 1
	bar_fill.corner_radius_top_right = 1
	bar_fill.corner_radius_bottom_left = 1
	bar_fill.corner_radius_bottom_right = 1
	theme.set_stylebox(&"background", &"ProgressBar", bar_bg)
	theme.set_stylebox(&"fill", &"ProgressBar", bar_fill)
	theme.set_font_size(&"font_size", &"ProgressBar", 1)


static func _add_scroll_and_tooltip(theme: Theme) -> void:
	var grabber := _box(Color(0.38, 0.33, 0.26, 0.7), Color.TRANSPARENT, 0, 0.0, 0.0)
	grabber.corner_radius_top_left = 3
	grabber.corner_radius_top_right = 3
	grabber.corner_radius_bottom_left = 3
	grabber.corner_radius_bottom_right = 3
	var grabber_hover := _box(Color(0.6, 0.47, 0.3, 0.85), Color.TRANSPARENT, 0, 0.0, 0.0)
	grabber_hover.corner_radius_top_left = 3
	grabber_hover.corner_radius_top_right = 3
	grabber_hover.corner_radius_bottom_left = 3
	grabber_hover.corner_radius_bottom_right = 3
	var track := _box(Color(0.05, 0.052, 0.054, 0.45), Color.TRANSPARENT, 0, 0.0, 0.0)
	# Без ненулевых content margins полоса прокрутки получает ширину 0 и не видна.
	track.content_margin_left = 4.0
	track.content_margin_right = 4.0
	track.content_margin_top = 4.0
	track.content_margin_bottom = 4.0
	for type_name in [&"VScrollBar", &"HScrollBar"]:
		theme.set_stylebox(&"scroll", type_name, track)
		theme.set_stylebox(&"grabber", type_name, grabber)
		theme.set_stylebox(&"grabber_highlight", type_name, grabber_hover)
		theme.set_stylebox(&"grabber_pressed", type_name, grabber_hover)

	theme.set_stylebox(&"panel", &"TooltipPanel", _box(Color(0.035, 0.038, 0.04, 0.97), BRONZE_DIM, 1, 10.0, 8.0))
	theme.set_font(&"font", &"TooltipLabel", _body_font)
	theme.set_font_size(&"font_size", &"TooltipLabel", 12)
	theme.set_color(&"font_color", &"TooltipLabel", TEXT)


static func _focus_box() -> StyleBoxFlat:
	var box := _box(Color.TRANSPARENT, Color(0.75, 0.58, 0.36, 0.9), 1, 0.0, 0.0)
	box.draw_center = false
	box.expand_margin_left = 1.0
	box.expand_margin_top = 1.0
	box.expand_margin_right = 1.0
	box.expand_margin_bottom = 1.0
	return box


static func _box(
	bg: Color,
	border: Color,
	border_width: int,
	margin_x: float,
	margin_y: float
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 2
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	return box
