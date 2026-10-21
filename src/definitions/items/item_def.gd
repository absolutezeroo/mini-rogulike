class_name ItemDef
extends ContentDef
## Base class for anything the player can carry.


## Merchant price before rarity and depth (see ShopDef). 0 = can't be sold.
@export var value: int = 20


func get_type_label() -> String:
	return tr("Item")


## Two items with the same key are the same thing and stack in the bag (one place, "x2"). A plain
## item is its .tres; rolled equipment has its own key (EquipmentDef).
func stack_key() -> String:
	return resource_path if not resource_path.is_empty() else "#%d" % get_instance_id()


## Color of the item's name in menus: its rarity for found equipment, light otherwise.
func rarity_color() -> Color:
	return ItemRarity.COLORS[ItemRarity.COMMON]


## Text shown in the inventory details panel.
func get_details() -> String:
	return tr(description)
