class_name RpgDemoSession
extends RefCounted
## Состояние демонстрационного меню: копия каталога, фильтры, выбор,
## экипировка и локальные покупки. Не знает об узлах UI и не трогает игру.

signal changed

const CATEGORY_ALL := -1

var catalog: RpgDemoCatalog
var items: Array[RpgDemoItem] = []
var offers: Array[RpgDemoTradeOffer] = []
var demo_coins := 0
var selected_item_id: StringName = &""
var active_category := CATEGORY_ALL
var search_text := ""
var only_new := false


func initialize(data: RpgDemoCatalog) -> void:
	catalog = data
	items.clear()
	offers.clear()
	demo_coins = 0
	selected_item_id = &""
	active_category = CATEGORY_ALL
	search_text = ""
	only_new = false

	if catalog == null:
		push_error("RpgDemoSession: не передан демонстрационный каталог")
		return

	for entry in catalog.items:
		if entry is RpgDemoItem:
			items.append((entry as RpgDemoItem).duplicate(true) as RpgDemoItem)
		else:
			push_warning("RpgDemoSession: в items пропущена запись не-RpgDemoItem")

	for entry in catalog.trade_offers:
		if entry is RpgDemoTradeOffer:
			offers.append((entry as RpgDemoTradeOffer).duplicate(true) as RpgDemoTradeOffer)
		else:
			push_warning("RpgDemoSession: в trade_offers пропущена запись не-RpgDemoTradeOffer")

	demo_coins = catalog.starting_demo_coins
	select_first_visible()


func set_category(category: int) -> void:
	active_category = category
	_ensure_selection()


func set_search(text: String) -> void:
	search_text = text
	_ensure_selection()


func set_only_new(enabled: bool) -> void:
	only_new = enabled
	_ensure_selection()


func get_visible_items() -> Array[RpgDemoItem]:
	var result: Array[RpgDemoItem] = []
	var needle := search_text.strip_edges().to_lower()
	for item in items:
		if item == null:
			continue
		if active_category != CATEGORY_ALL and item.category != active_category:
			continue
		if only_new and not item.is_new:
			continue
		if not needle.is_empty() and item.display_name.to_lower().find(needle) < 0:
			continue
		result.append(item)
	return result


func get_item(item_id: StringName) -> RpgDemoItem:
	for item in items:
		if item != null and item.id == item_id:
			return item
	return null


func get_selected_item() -> RpgDemoItem:
	return get_item(selected_item_id)


func select_item(item_id: StringName) -> bool:
	if get_item(item_id) == null:
		return false
	selected_item_id = item_id
	return true


func select_first_visible() -> void:
	var visible := get_visible_items()
	selected_item_id = visible[0].id if not visible.is_empty() else &""


func find_equipped(slot: StringName) -> RpgDemoItem:
	for item in items:
		if item != null and item.equipped and item.equip_slot == slot:
			return item
	return null


func count_category(category: int) -> int:
	var count := 0
	for item in items:
		if item != null and (category == CATEGORY_ALL or item.category == category):
			count += 1
	return count


func total_weight() -> float:
	var total := 0.0
	for item in items:
		if item != null:
			total += item.stack_weight()
	return total


func can_equip(item: RpgDemoItem) -> bool:
	return item != null and item.is_gear()


func can_use(item: RpgDemoItem) -> bool:
	return item != null and item.category == RpgDemoItem.Category.CONSUMABLE and item.quantity > 0


func can_drop(item: RpgDemoItem) -> bool:
	return (
		item != null
		and not item.equipped
		and item.category != RpgDemoItem.Category.STORY
		and item.quantity > 0
	)


func equip_item(item: RpgDemoItem) -> bool:
	if not can_equip(item):
		return false
	for other in items:
		if other != null and other != item and other.equip_slot == item.equip_slot:
			other.equipped = false
	item.equipped = true
	changed.emit()
	return true


func unequip_item(item: RpgDemoItem) -> bool:
	if item == null or not item.equipped:
		return false
	item.equipped = false
	changed.emit()
	return true


func consume_item(item: RpgDemoItem) -> bool:
	if not can_use(item):
		return false
	item.quantity -= 1
	if item.quantity <= 0:
		_remove_item(item)
	changed.emit()
	return true


func drop_item(item: RpgDemoItem) -> bool:
	if not can_drop(item):
		return false
	item.quantity -= 1
	if item.quantity <= 0:
		_remove_item(item)
	changed.emit()
	return true


func buy_offer(offer: RpgDemoTradeOffer) -> bool:
	return buy_offer_quantity(offer, 1)


func buy_offer_quantity(offer: RpgDemoTradeOffer, quantity: int) -> bool:
	if quantity <= 0:
		return false
	if offer == null or offer.item == null or offer.price < 0:
		return false
	if offer.stock < quantity:
		return false
	var total := offer.price * quantity
	if total < 0 or demo_coins < total:
		return false

	demo_coins -= total
	offer.stock -= quantity

	var owned := get_item(offer.item.id)
	if owned != null:
		owned.quantity += quantity
		owned.is_new = true
	else:
		var added := offer.item.duplicate(true) as RpgDemoItem
		added.quantity = quantity
		added.equipped = false
		added.is_new = true
		items.append(added)

	changed.emit()
	return true


func can_sell_item(item: RpgDemoItem, quantity: int) -> bool:
	if item == null or quantity <= 0 or item.demo_price < 0:
		return false
	var owned := get_item(item.id)
	return owned != null and owned.quantity >= quantity


func sell_item(item: RpgDemoItem, quantity: int) -> bool:
	if not can_sell_item(item, quantity):
		return false
	var owned := get_item(item.id)
	var total := owned.demo_price * quantity
	if total < 0:
		return false

	owned.quantity -= quantity
	demo_coins += total
	if owned.quantity <= 0:
		_remove_item(owned)
	changed.emit()
	return true



func _remove_item(item: RpgDemoItem) -> void:
	items.erase(item)
	if selected_item_id == item.id:
		select_first_visible()


func _ensure_selection() -> void:
	var visible := get_visible_items()
	var still_visible := false
	for item in visible:
		if item.id == selected_item_id:
			still_visible = true
			break
	if not still_visible:
		selected_item_id = visible[0].id if not visible.is_empty() else &""
