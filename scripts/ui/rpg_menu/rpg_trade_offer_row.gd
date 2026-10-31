class_name RpgTradeOfferRow
extends Button
## Строка демонстрационной витрины. Только отображает лот и сообщает о выборе;
## покупка выполняется экраном витрины через RpgDemoSession.

signal offer_chosen(offer_id: StringName)

@onready var icon_panel: PanelContainer = %IconPanel
@onready var icon_rect: TextureRect = %Icon
@onready var category_rarity: Label = %CategoryRarity
@onready var item_name: Label = %ItemName
@onready var stock: Label = %Stock
@onready var price: Label = %Price
@onready var price_unit: Label = %PriceUnit
@onready var open_mark: Label = %OpenMark

var offer: RpgDemoTradeOffer


func _ready() -> void:
	pressed.connect(_on_pressed)
	custom_minimum_size.y = 100.0


func setup(data: RpgDemoTradeOffer, selected: bool, affordable: bool) -> void:
	offer = data
	if offer == null or offer.item == null:
		return

	var item := offer.item
	icon_rect.texture = item.icon
	icon_rect.visible = item.icon != null
	category_rarity.text = "%s · %s" % [
		RpgMenuTheme.category_title(item.category),
		RpgMenuTheme.rarity_title(item.rarity),
	]
	category_rarity.add_theme_color_override("font_color", RpgMenuTheme.rarity_color(item.rarity))
	item_name.text = item.display_name
	stock.text = "В НАЛИЧИИ: %d" % offer.stock if offer.stock > 0 else "РАСПРОДАНО"
	stock.add_theme_color_override(
		"font_color",
		RpgMenuTheme.MUTED if offer.stock > 0 else RpgMenuTheme.RUST
	)
	price.text = str(offer.price)
	price.add_theme_color_override(
		"font_color",
		RpgMenuTheme.BRONZE_BRIGHT if affordable and offer.stock > 0 else RpgMenuTheme.DIM
	)
	price_unit.add_theme_color_override(
		"font_color",
		RpgMenuTheme.BRONZE_DIM if affordable and offer.stock > 0 else RpgMenuTheme.DIM
	)
	button_pressed = selected
	tooltip_text = "%s\nЦена: %d демо-монет · Запас: %d\nНажмите, чтобы открыть лот." % [
		item.display_name,
		offer.price,
		offer.stock,
	]
	queue_redraw()


func _on_pressed() -> void:
	if offer != null:
		offer_chosen.emit(offer.id)
