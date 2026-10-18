class_name ItemDef
extends ContentDef
## Base class for anything the player can carry.


## Merchant price before rarity and depth (see ShopDef). 0 = can't be sold.
@export var value: int = 20


func get_type_label() -> String:
	return "Item"


## Color of the item's name in menus: its rarity for found equipment, light otherwise.
func rarity_color() -> Color:
	return ItemRarity.COLORS[ItemRarity.COMMON]


## Text shown in the inventory details panel.
func get_details() -> String:
	return description
