class_name RpgTradeScreen
extends Control
## Отдельный DEMO-экран торговли. Показывает товары скупщика и локальный
## инвентарь, считает покупку/продажу и работает только с RpgDemoSession.
## Игровая валюта, сохранения и сюжет не подключены.

signal feedback_requested(text: String, tone: StringName)
signal navigate_requested(section: StringName)

const ROW_SCENE := preload("res://scenes/ui/rpg_menu/trade_item_row.tscn")
const SOURCE_SHOP := &"shop"
const SOURCE_INVENTORY := &"inventory"
const MAX_QUANTITY := 99

@onready var merchant_name: Label = %MerchantName
@onready var merchant_note: Label = %MerchantNote
@onready var wallet_value: Label = %WalletValue
@onready var wallet_footer: Label = %WalletFooter
@onready var shop_count: Label = %ShopCount
@onready var player_count: Label = %PlayerCount
@onready var header_stats: Label = %HeaderStats
@onready var shop_count_badge: Label = %ShopCountBadge
@onready var player_count_badge: Label = %PlayerCountBadge
@onready var shop_list: VBoxContainer = %ShopList
@onready var player_list: VBoxContainer = %PlayerList
@onready var return_button: Button = %ReturnButton
@onready var detail_scroll: ScrollContainer = %DetailScroll
@onready var empty_detail: Control = %EmptyDetail
@onready var detail_source: Label = %DetailSource
@onready var detail_icon: TextureRect = %DetailIcon
@onready var detail_icon_panel: PanelContainer = %DetailIconPanel
@onready var detail_category: Label = %DetailCategory
@onready var detail_title: Label = %DetailTitle
@onready var detail_rarity: Label = %DetailRarity
@onready var detail_description: Label = %DetailDescription
@onready var detail_flavor: Label = %DetailFlavor
@onready var stats_section: Control = %StatsSection
@onready var stats_rows: VBoxContainer = %StatsRows
@onready var properties_section: Control = %PropertiesSection
@onready var properties_rows: VBoxContainer = %PropertiesRows
@onready var trade_panel: Control = %TradePanel
@onready var qty_minus: Button = %QtyMinus
@onready var qty_value: Label = %QtyValue
@onready var qty_plus: Button = %QtyPlus
@onready var buy_line: Label = %BuyLine
@onready var sell_line: Label = %SellLine
@onready var buy_button: Button = %BuyButton
@onready var sell_button: Button = %SellButton
@onready var trade_hint: Label = %TradeHint

var session: RpgDemoSession
var selected_item_id: StringName = &""
var selected_source: StringName = SOURCE_SHOP
var quantity := 1

var _shop_rows: Array = []
var _player_rows: Array = []
var _last_selection_key := &""


func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)
	qty_minus.pressed.connect(_on_qty_minus)
	qty_plus.pressed.connect(_on_qty_plus)
	buy_button.pressed.connect(_on_buy_pressed)
	sell_button.pressed.connect(_on_sell_pressed)


func setup(data: RpgDemoSession) -> void:
	if session != null and session.changed.is_connected(_on_session_changed):
		session.changed.disconnect(_on_session_changed)
	session = data
	if session == null:
		return
	session.changed.connect(_on_session_changed)
	selected_item_id = &""
	selected_source = SOURCE_SHOP
	quantity = 1
	_ensure_selection()
	refresh()


func refresh() -> void:
	if session == null:
		return
	_ensure_selection()
	_refresh_summary()
	_rebuild_shop_rows()
	_rebuild_player_rows()
	_refresh_details()


func _refresh_summary() -> void:
	wallet_value.text = str(session.demo_coins)
	wallet_footer.text = "ТОЛЬКО В ТЕКУЩЕЙ DEMO-СЕССИИ"
	shop_count.text = "ЛОТОВ У ТОРГОВЦА: %d" % session.offers.size()
	player_count.text = "ПРЕДМЕТОВ У ВАС: %d" % session.items.size()
	shop_count_badge.text = str(session.offers.size())
	player_count_badge.text = str(session.items.size())
	header_stats.text = "%d ЛОТА · %d ПРЕДМЕТОВ" % [session.offers.size(), session.items.size()]
	var catalog := session.catalog
	merchant_name.text = catalog.merchant_name if catalog != null else "Скупщик"
	merchant_note.text = catalog.merchant_note if catalog != null else ""


func _ensure_selection() -> void:
	if session == null:
		return
	var offer := _selected_offer()
	var owned := session.get_item(selected_item_id)
	var shop_valid := offer != null
	var inventory_valid := owned != null

	if selected_source == SOURCE_SHOP and not shop_valid:
		if inventory_valid:
			selected_source = SOURCE_INVENTORY
		else:
			_select_fallback()
		return
	if selected_source == SOURCE_INVENTORY and not inventory_valid:
		if shop_valid:
			selected_source = SOURCE_SHOP
		else:
			_select_fallback()
		return
	if selected_item_id.is_empty() or (not shop_valid and not inventory_valid):
		_select_fallback()


func _select_fallback() -> void:
	quantity = 1
	if not session.offers.is_empty() and session.offers[0].item != null:
		selected_item_id = session.offers[0].item.id
		selected_source = SOURCE_SHOP
		return
	if not session.items.is_empty():
		selected_item_id = session.items[0].id
		selected_source = SOURCE_INVENTORY
		return
	selected_item_id = &""
	selected_source = SOURCE_SHOP


func _rebuild_shop_rows() -> void:
	_clear_rows(shop_list)
	_shop_rows.clear()
	for offer in session.offers:
		if offer == null or offer.item == null:
			continue
		var row = ROW_SCENE.instantiate()
		shop_list.add_child(row)
		var availability := (
			"В НАЛИЧИИ: %d" % offer.stock if offer.stock > 0 else "РАСПРОДАНО"
		)
		row.setup(
			offer.item,
			offer.price,
			availability,
			selected_source == SOURCE_SHOP and selected_item_id == offer.item.id,
			SOURCE_SHOP
		)
		row.row_chosen.connect(_on_row_chosen)
		_shop_rows.append(row)


func _rebuild_player_rows() -> void:
	_clear_rows(player_list)
	_player_rows.clear()
	for item in session.items:
		if item == null or item.quantity <= 0:
			continue
		var row = ROW_SCENE.instantiate()
		player_list.add_child(row)
		var availability := "У ВАС: %d" % item.quantity
		if item.demo_price < 0:
			availability = "НЕ ПРОДАЁТСЯ · DEMO"
		row.setup(
			item,
			item.demo_price,
			availability,
			selected_source == SOURCE_INVENTORY and selected_item_id == item.id,
			SOURCE_INVENTORY
		)
		row.row_chosen.connect(_on_row_chosen)
		_player_rows.append(row)


func _refresh_details() -> void:
	var item := _selected_item()
	if item == null:
		detail_scroll.visible = false
		empty_detail.visible = true
		trade_panel.visible = false
		_last_selection_key = &""
		return

	detail_scroll.visible = true
	empty_detail.visible = false
	trade_panel.visible = true
	detail_source.text = (
		"ВЫБРАНО У ТОРГОВЦА · DEMO"
		if selected_source == SOURCE_SHOP
		else "ВЫБРАНО В ИНВЕНТАРЕ · DEMO"
	)
	detail_icon.texture = item.icon
	detail_icon.visible = item.icon != null
	detail_icon_panel.visible = item.icon != null
	var category_text := RpgMenuTheme.category_title(item.category)
	var slot_text := (
		RpgMenuTheme.slot_title(item.equip_slot) if not item.equip_slot.is_empty() else "БЕЗ СЛОТА"
	)
	detail_category.text = (
		category_text if category_text == slot_text else "%s · %s" % [category_text, slot_text]
	)
	detail_title.text = item.display_name
	detail_rarity.text = RpgMenuTheme.rarity_title(item.rarity)
	detail_rarity.add_theme_color_override("font_color", RpgMenuTheme.rarity_color(item.rarity))
	detail_description.text = item.description
	detail_flavor.text = "«%s»" % item.flavor if not item.flavor.is_empty() else ""
	detail_flavor.visible = not item.flavor.is_empty()

	_fill_stats(item)
	_fill_properties(item)
	_refresh_trade(item)

	var selection_key := StringName("%s:%s" % [selected_source, selected_item_id])
	if _last_selection_key != selection_key:
		detail_scroll.scroll_vertical = 0
		_last_selection_key = selection_key


func _fill_stats(item: RpgDemoItem) -> void:
	_clear_rows(stats_rows)
	var rows := 0
	for entry in item.stats:
		if not entry is RpgDemoStat:
			continue
		var stat := entry as RpgDemoStat
		if rows > 0:
			var divider := ColorRect.new()
			divider.custom_minimum_size = Vector2(0, 1)
			divider.color = Color(0.2, 0.195, 0.18, 0.38)
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_rows.add_child(divider)
		_add_stat_row(stat.label, stat.value)
		rows += 1
	stats_section.visible = rows > 0


func _add_stat_row(label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	stats_rows.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.theme_type_variation = &"MutedLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.theme_type_variation = &"BodyLabel"
	value.add_theme_font_size_override("font_size", 13)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value)


func _fill_properties(item: RpgDemoItem) -> void:
	_clear_rows(properties_rows)
	for property_text in item.properties:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 7)
		properties_rows.add_child(row)

		var marker := Label.new()
		marker.text = "◆"
		marker.theme_type_variation = &"TinyMutedLabel"
		marker.add_theme_color_override("font_color", RpgMenuTheme.BRONZE_DIM)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(marker)

		var label := Label.new()
		label.text = property_text
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.theme_type_variation = &"MutedLabel"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
	properties_section.visible = not item.properties.is_empty()


func _refresh_trade(item: RpgDemoItem) -> void:
	quantity = clampi(quantity, 1, MAX_QUANTITY)
	qty_value.text = str(quantity)

	var offer := _selected_offer()
	var owned := session.get_item(item.id)
	var buy_total := offer.price * quantity if offer != null else -1
	var sell_total := owned.demo_price * quantity if owned != null else -1

	if offer == null:
		buy_line.text = "НЕТ В ПРОДАЖЕ"
	elif offer.stock <= 0:
		buy_line.text = "РАСПРОДАНО"
	elif offer.price < 0:
		buy_line.text = "ЦЕНА НЕ НАЗНАЧЕНА"
	else:
		buy_line.text = "%d × %d = %d · В НАЛИЧИИ %d" % [
			offer.price,
			quantity,
			buy_total,
			offer.stock,
		]

	if owned == null:
		sell_line.text = "НЕТ В ИНВЕНТАРЕ"
	elif owned.demo_price < 0:
		sell_line.text = "НЕ ПРОДАЁТСЯ"
	else:
		sell_line.text = "%d × %d = %d · У ВАС %d" % [
			owned.demo_price,
			quantity,
			sell_total,
			owned.quantity,
		]

	var can_buy := (
		offer != null
		and offer.stock >= quantity
		and offer.price >= 0
		and buy_total >= 0
		and session.demo_coins >= buy_total
	)
	var can_sell := (
		owned != null
		and owned.demo_price >= 0
		and owned.quantity >= quantity
	)

	_apply_action_button(
		buy_button,
		"КУПИТЬ",
		buy_total,
		can_buy,
		selected_source == SOURCE_SHOP,
		"Купить: %d × %d = %d DEMO-МОНЕТ." % [offer.price, quantity, buy_total] if offer != null else "Товар отсутствует в продаже."
	)
	_apply_action_button(
		sell_button,
		"ПРОДАТЬ",
		sell_total,
		can_sell,
		selected_source == SOURCE_INVENTORY,
		"Продать: %d × %d = %d DEMO-МОНЕТ." % [owned.demo_price, quantity, sell_total] if owned != null else "Предмета нет в инвентаре."
	)

	trade_hint.add_theme_color_override("font_color", RpgMenuTheme.MUTED)
	if selected_source == SOURCE_SHOP:
		if offer == null:
			trade_hint.text = "Торговец не продаёт этот предмет."
			trade_hint.add_theme_color_override("font_color", RpgMenuTheme.RUST)
		elif offer.stock <= 0:
			trade_hint.text = "Лот распродан в этой DEMO-сессии."
			trade_hint.add_theme_color_override("font_color", RpgMenuTheme.RUST)
		elif offer.stock < quantity:
			trade_hint.text = "В наличии только %d. Уменьшите количество." % offer.stock
			trade_hint.add_theme_color_override("font_color", RpgMenuTheme.RUST)
		elif session.demo_coins < buy_total:
			trade_hint.text = "Не хватает %d DEMO-МОНЕТ: нужно %d, в кошельке %d." % [
				buy_total - session.demo_coins,
				buy_total,
				session.demo_coins,
			]
			trade_hint.add_theme_color_override("font_color", RpgMenuTheme.RUST)
		else:
			trade_hint.text = "Покупка спишет %d DEMO-МОНЕТ и добавит %d шт." % [
				buy_total,
				quantity,
			]
	else:
		if owned == null:
			trade_hint.text = "Предмет отсутствует в DEMO-инвентаре."
			trade_hint.add_theme_color_override("font_color", RpgMenuTheme.RUST)
		elif owned.demo_price < 0:
			trade_hint.text = "Сюжетные заглушки нельзя продать в DEMO."
			trade_hint.add_theme_color_override("font_color", RpgMenuTheme.RUST)
		elif owned.quantity < quantity:
			trade_hint.text = "У вас только %d шт. Уменьшите количество." % owned.quantity
			trade_hint.add_theme_color_override("font_color", RpgMenuTheme.RUST)
		else:
			trade_hint.text = "Продажа зачислит %d DEMO-МОНЕТ и изымет %d шт." % [
				sell_total,
				quantity,
			]


func _apply_action_button(
	button: Button,
	base_text: String,
	total: int,
	available: bool,
	primary: bool,
	tooltip: String
) -> void:
	if available:
		button.text = "%s · %d" % [base_text, total]
		button.theme_type_variation = &"PrimaryButton" if primary else &"SecondaryButton"
		button.tooltip_text = tooltip
	else:
		button.text = base_text
		button.theme_type_variation = &"UnavailableActionButton"
		button.tooltip_text = tooltip


func _selected_offer() -> RpgDemoTradeOffer:
	for offer in session.offers:
		if offer != null and offer.item != null and offer.item.id == selected_item_id:
			return offer
	return null


func _selected_item() -> RpgDemoItem:
	var owned := session.get_item(selected_item_id)
	if owned != null:
		return owned
	var offer := _selected_offer()
	return offer.item if offer != null else null


func _on_row_chosen(item_id: StringName, source: StringName) -> void:
	selected_item_id = item_id
	selected_source = source
	quantity = 1
	refresh()
	var item := _selected_item()
	if item != null:
		feedback_requested.emit(
			"Выбран %s: %s." % ["товар" if source == SOURCE_SHOP else "предмет", item.display_name],
			&"info"
		)


func _on_qty_minus() -> void:
	quantity = maxi(1, quantity - 1)
	_refresh_trade(_selected_item())


func _on_qty_plus() -> void:
	quantity = mini(MAX_QUANTITY, quantity + 1)
	_refresh_trade(_selected_item())


func _on_buy_pressed() -> void:
	var item := _selected_item()
	var offer := _selected_offer()
	if item == null or offer == null:
		_warn("Торговец не продаёт выбранный предмет.")
		return
	if offer.stock < quantity:
		_warn("В наличии только %d шт. Уменьшите количество." % offer.stock)
		return
	var total := offer.price * quantity
	if total > session.demo_coins:
		_warn(
			"Недостаточно DEMO-МОНЕТ: нужно %d, в кошельке %d." % [
				total,
				session.demo_coins,
			]
		)
		return
	if session.buy_offer_quantity(offer, quantity):
		feedback_requested.emit(
			"Куплено: %s ×%d. Списано %d DEMO-МОНЕТ, остаток — %d." % [
				item.display_name,
				quantity,
				total,
				session.demo_coins,
			],
			&"success"
		)


func _on_sell_pressed() -> void:
	var item := session.get_item(selected_item_id)
	if item == null:
		_warn("Предмет отсутствует в DEMO-инвентаре.")
		return
	if item.demo_price < 0:
		_warn("Этот предмет нельзя продать в DEMO.")
		return
	if item.quantity < quantity:
		_warn("У вас только %d шт. Уменьшите количество." % item.quantity)
		return
	var total := item.demo_price * quantity
	if session.sell_item(item, quantity):
		feedback_requested.emit(
			"Продано: %s ×%d. Получено %d DEMO-МОНЕТ, баланс — %d." % [
				item.display_name,
				quantity,
				total,
				session.demo_coins,
			],
			&"success"
		)


func _on_return_pressed() -> void:
	navigate_requested.emit(&"inventory")


func _on_session_changed() -> void:
	refresh()


func _warn(text: String) -> void:
	feedback_requested.emit(text, &"warning")


func _clear_rows(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
