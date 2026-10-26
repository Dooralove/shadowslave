class_name RpgTradeItemRow
extends Button
## Компактная строка списка торговли: товар скупщика или предмет игрока.
## Только отображает запись и сообщает о выборе; сделки выполняет экран.

signal row_chosen(item_id: StringName, source: StringName)

@onready var icon_panel: PanelContainer = %IconPanel
@onready var icon_rect: TextureRect = %Icon
@onready var category_rarity: Label = %CategoryRarity
@onready var item_name: Label = %ItemName
@onready var availability: Label = %Availability
@onready var price: Label = %Price
@onready var price_unit: Label = %PriceUnit

var item: RpgDemoItem
var source: StringName = &"shop"


func _ready() -> void:
	pressed.connect(_on_pressed)
	custom_minimum_size.y = 64.0


func setup(
	data: RpgDemoItem,
	unit_price: int,
	availability_text: String,
	selected: bool,
	row_source: StringName
) -> void:
	item = data
	source = row_source
	if item == null:
		return

	icon_rect.texture = item.icon
	icon_rect.visible = item.icon != null
	icon_panel.visible = item.icon != null
	category_rarity.text = "%s · %s" % [
		RpgMenuTheme.category_title(item.category),
		RpgMenuTheme.rarity_title(item.rarity),
	]
	category_rarity.add_theme_color_override("font_color", RpgMenuTheme.rarity_color(item.rarity))
	item_name.text = item.display_name
	availability.text = availability_text
	availability.add_theme_color_override(
		"font_color",
		RpgMenuTheme.MUTED if unit_price >= 0 else RpgMenuTheme.RUST
	)
	price.text = str(unit_price) if unit_price >= 0 else "—"
	price.add_theme_color_override(
		"font_color",
		RpgMenuTheme.BRONZE_BRIGHT if unit_price >= 0 else RpgMenuTheme.DIM
	)
	price_unit.text = "DEMO-МОНЕТ" if unit_price >= 0 else "НЕ ПРОДАЁТСЯ"
	price_unit.add_theme_color_override(
		"font_color",
		RpgMenuTheme.BRONZE_DIM if unit_price >= 0 else RpgMenuTheme.DIM
	)
	button_pressed = selected
	tooltip_text = "%s\n%s · %s" % [
		item.display_name,
		availability_text,
		("Цена: %d DEMO-МОНЕТ" % unit_price) if unit_price >= 0 else "Продажа недоступна",
	]


func _on_pressed() -> void:
	if item != null:
		row_chosen.emit(item.id, source)
