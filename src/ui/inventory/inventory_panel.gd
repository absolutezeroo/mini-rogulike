class_name InventoryPanel
extends Control
## Bag screen: equipped items, carried items, details and actions. Pauses the game while open.

signal closed

const NO_SLOT := -1

var _player: Player
var _selected_item: ItemDef
var _selected_slot := NO_SLOT

@onready var _slot_buttons := {
	EquipmentDef.Slot.WEAPON: %WeaponSlot as Button,
	EquipmentDef.Slot.HEAD: %HeadSlot as Button,
	EquipmentDef.Slot.BODY: %BodySlot as Button,
}
@onready var _stats_label: Label = %StatsLabel
@onready var _bag_title: Label = %BagTitle
@onready var _item_grid: GridContainer = %ItemGrid
@onready var _item_name: Label = %ItemName
@onready var _item_type: Label = %ItemType
@onready var _item_details: Label = %ItemDetails
@onready var _use_button: Button = %UseButton
@onready var _drop_button: Button = %DropButton


func _ready() -> void:
	hide()
	%CloseButton.pressed.connect(close)
	_use_button.pressed.connect(_on_use_pressed)
	_drop_button.pressed.connect(_on_drop_pressed)
	for slot in _slot_buttons:
		_slot_buttons[slot].pressed.connect(_select_slot.bind(slot))


func open(player: Player) -> void:
	_player = player
	_clear_selection()
	_refresh()
	show()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close()


# --- Display -----------------------------------------------------------------

func _refresh() -> void:
	for slot in _slot_buttons:
		var item := _player.equipment.get_item(slot)
		var button: Button = _slot_buttons[slot]
		button.text = "%s: %s" % [EquipmentDef.SLOT_NAMES[slot], item.display_name if item else "-"]
		button.add_theme_color_override("font_color", item.color if item else Color(0.6, 0.6, 0.6))

	var stats := _player.get_stats()
	_stats_label.text = "Level %d\nHP %d / %d\nPower %d   DEF %d\nSpeed %d   Crit %d%%" % [
		_player.level, _player.hp, _player.get_max_hp(), _player.get_power(),
		stats.defense, roundi(stats.move_speed), roundi(stats.crit_chance * 100.0)]

	var inventory := _player.inventory
	_bag_title.text = "Bag (%d / %d)" % [inventory.items.size(), inventory.capacity]
	for child in _item_grid.get_children():
		child.queue_free()
	for entry in inventory.grouped():
		var item: ItemDef = entry.item
		var button := Button.new()
		button.text = "%s  %s%s" % [item.glyph, item.display_name, "  x%d" % entry.count if entry.count > 1 else ""]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_color_override("font_color", item.color)
		button.pressed.connect(_select_item.bind(item))
		_item_grid.add_child(button)

	_refresh_details()


func _refresh_details() -> void:
	var item: ItemDef = _selected_item
	if _selected_slot != NO_SLOT:
		item = _player.equipment.get_item(_selected_slot)
	_use_button.visible = item != null
	_drop_button.visible = item != null and _selected_slot == NO_SLOT
	if item == null:
		_item_name.text = "Select an item"
		_item_type.text = ""
		_item_details.text = ""
		return
	_item_name.text = item.display_name
	_item_name.add_theme_color_override("font_color", item.color)
	_item_type.text = item.get_type_label()
	_item_details.text = item.get_details()
	if _selected_slot != NO_SLOT:
		_use_button.text = "Unequip"
	elif item is EquipmentDef:
		_use_button.text = "Equip"
	else:
		_use_button.text = "Use"


# --- Selection & actions -----------------------------------------------------

func _select_item(item: ItemDef) -> void:
	_selected_item = item
	_selected_slot = NO_SLOT
	_refresh_details()


func _select_slot(slot: EquipmentDef.Slot) -> void:
	_selected_item = null
	_selected_slot = slot
	_refresh_details()


func _clear_selection() -> void:
	_selected_item = null
	_selected_slot = NO_SLOT


func _on_use_pressed() -> void:
	if _selected_slot != NO_SLOT:
		_player.unequip(_selected_slot)
		_clear_selection()
	elif _selected_item:
		_player.use_item(_selected_item)
		if not _player.inventory.items.has(_selected_item):
			_clear_selection()
	_refresh()


func _on_drop_pressed() -> void:
	if _selected_item:
		_player.drop_item(_selected_item)
		if not _player.inventory.items.has(_selected_item):
			_clear_selection()
	_refresh()
