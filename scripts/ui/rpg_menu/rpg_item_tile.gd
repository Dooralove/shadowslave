class_name RpgItemTile
extends Button
## Карточка предмета в сетке. Визуальные состояния и сигнал выбора, без логики данных.

signal item_chosen(item_id: StringName)

@onready var icon_rect: TextureRect = %Icon
@onready var icon_panel: PanelContainer = %IconPanel
@onready var name_label: Label = %NameLabel
@onready var rarity_label: Label = %RarityLabel
@onready var quantity_label: Label = %QuantityLabel
@onready var equipped_label: Label = %EquippedLabel
@onready var new_label: Label = %NewLabel
@onready var rarity_strip: ColorRect = %RarityStrip

var item: RpgDemoItem
var selected := false


func _ready() -> void:
	pressed.connect(_on_pressed)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func setup(data: RpgDemoItem) -> void:
	item = data
	if item == null:
		return

	icon_rect.texture = item.icon
	icon_rect.visible = item.icon != null
	name_label.text = item.display_name
	rarity_label.text = RpgMenuTheme.rarity_title(item.rarity)
	rarity_label.add_theme_color_override("font_color", RpgMenuTheme.rarity_color(item.rarity))
	rarity_strip.color = RpgMenuTheme.rarity_color(item.rarity)
	quantity_label.text = "×%d" % item.quantity if item.quantity > 1 else "1"
	equipped_label.visible = item.equipped
	new_label.visible = item.is_new
	tooltip_text = "%s\n%s · %s\nКоличество: %d" % [
		item.display_name,
		RpgMenuTheme.category_title(item.category),
		RpgMenuTheme.rarity_title(item.rarity),
		item.quantity,
	]
	queue_redraw()


func set_selected(value: bool) -> void:
	selected = value
	button_pressed = value
	queue_redraw()


func _on_pressed() -> void:
	if item != null:
		item_chosen.emit(item.id)


func _draw() -> void:
	if item == null:
		return

	if selected:
		var color := RpgMenuTheme.BRONZE_BRIGHT
		var inset := 4.0
		var length := 13.0
		var segments := [
			[Vector2(inset, inset + length), Vector2(inset, inset), Vector2(inset + length, inset)],
			[Vector2(size.x - inset - length, inset), Vector2(size.x - inset, inset), Vector2(size.x - inset, inset + length)],
			[Vector2(inset, size.y - inset - length), Vector2(inset, size.y - inset), Vector2(inset + length, size.y - inset)],
			[Vector2(size.x - inset - length, size.y - inset), Vector2(size.x - inset, size.y - inset), Vector2(size.x - inset, size.y - inset - length)],
		]
		for segment in segments:
			draw_polyline(PackedVector2Array(segment), color, 1.4, true)

	if has_focus():
		draw_circle(Vector2(size.x - 9.0, 9.0), 2.0, RpgMenuTheme.BRONZE_BRIGHT)
