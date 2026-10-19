class_name ShopPanel
extends Control
## The merchant's shop: what they sell (rolled equipment, potions, maybe a tome) and what
## you can sell them from your bag. The game is paused while it is open.

signal closed

const ICON_SIZE := Vector2(40, 40)

var _merchant: Merchant
var _player: Player

@onready var _name: Label = %MerchantName
@onready var _greeting: Label = %Greeting
@onready var _portrait: TextureRect = %Portrait
@onready var _gold: Label = %Gold
@onready var _for_sale: VBoxContainer = %ForSale
@onready var _bag: VBoxContainer = %Bag


func _ready() -> void:
	hide()
	%CloseButton.pressed.connect(close)


func open(merchant: Merchant, player: Player) -> void:
	_merchant = merchant
	_player = player
	_name.text = merchant.def.display_name
	_greeting.text = merchant.def.random_greeting()
	_portrait.texture = merchant.def.portrait
	_refresh()
	show()


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory")):
		get_viewport().set_input_as_handled()
		close()


func _refresh() -> void:
	_gold.text = "Gold %d" % _player.gold
	for list: VBoxContainer in [_for_sale, _bag]:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
	for i in _merchant.stock.size():
		var entry: Dictionary = _merchant.stock[i]
		var can_buy: bool = _player.gold >= entry.price and _player.can_store(entry.item)
		_for_sale.add_child(_row(entry.item, "%d gold" % entry.price, can_buy, _buy.bind(i)))
	if _merchant.stock.is_empty():
		_for_sale.add_child(_note("Sold out!"))
	for i in Belt.SLOTS:
		var belt_item := _player.belt.item_at(i)
		if belt_item:
			var label := "%s  x%d" % [belt_item.display_name, _player.belt.count_at(i)]
			_bag.add_child(_row(belt_item, "Sell %d" % _merchant.def.sell_price(belt_item, _player.world.depth), true, _sell.bind(belt_item, true), label))
	for entry in _player.inventory.grouped():
		var item: ItemDef = entry.item
		var price := _merchant.def.sell_price(item, _player.world.depth)
		var label := item.display_name + ("  x%d" % entry.count if entry.count > 1 else "")
		_bag.add_child(_row(item, "Sell %d" % price, price > 0, _sell.bind(item), label))
	if _player.inventory.items.is_empty() and _player.belt.is_empty():
		_bag.add_child(_note("Your bag is empty."))


func _buy(index: int) -> void:
	if _merchant.sell_to(_player, index):
		_refresh()


func _sell(item: ItemDef, from_belt := false) -> void:
	if _merchant.buy_from(_player, item, from_belt):
		_refresh()


func _row(item: ItemDef, price_text: String, enabled: bool, action: Callable, label := "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.modulate = item.icon_tint
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	var name_label := Label.new()
	name_label.text = label if not label.is_empty() else item.display_name
	name_label.add_theme_color_override("font_color", item.rarity_color())
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = 120
	text.add_child(name_label)
	var details := Label.new()
	details.text = _short_details(item)
	details.add_theme_font_size_override("font_size", 13)
	details.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	details.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details.custom_minimum_size.x = 120
	text.add_child(details)
	row.add_child(text)
	var button := Button.new()
	button.text = price_text
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(120, 48)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(action)
	row.add_child(button)
	return row


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	return label


## One line: the type, and the stats for equipment.
func _short_details(item: ItemDef) -> String:
	var equipment := item as EquipmentDef
	if equipment and equipment.bonuses:
		var stats := equipment.bonuses.describe()
		if item is WeaponDef:
			stats = ("%d dmg  " % (item as WeaponDef).damage) + stats
		return item.get_type_label() + ("  -  " + stats if not stats.is_empty() else "")
	if item is WeaponDef:
		return "%s  -  %d dmg" % [item.get_type_label(), (item as WeaponDef).damage]
	return item.get_type_label()
