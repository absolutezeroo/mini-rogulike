class_name DismantleRules
extends Resource
## Breaking gear down for gold, anywhere, from the bag (`data/items/dismantle.tres`): what a full
## bag is for when no merchant is near. Only equipment: potions, runes, tomes and keys never.
##
## Gold: the item's `value` x its rarity (ItemRarity.VALUE) x `gold_share`, plus `gold_per_level`
## of that for each item level above 1, plus `gold_share` of the runes set in it. Always less than
## the merchant pays for it (ShopDef.sell_price: value x rarity x price_multiplier x sell_ratio,
## growing with depth), so carrying gear to him stays worth it and dismantling is never a trick.

## Share of the item's worth (value x rarity) paid in gold.
@export_range(0.0, 1.0, 0.01) var gold_share: float = 0.15
## How much more an item gives per item level above 1 (0.2 = +20% per level).
@export var gold_per_level: float = 0.2
## From this rarity up (ItemRarity: 2 = Rare), breaking a piece down asks a second press first
## ("Sure? +40 gold"); plainer pieces go at once, so a bag of junk empties fast with a gamepad.
## A piece with runes set in it always asks (they break with it).
@export_range(0, 3) var confirm_rarity: int = ItemRarity.RARE


static func can_dismantle(item: ItemDef) -> bool:
	return item is EquipmentDef


## Does breaking `item` down ask a second press first? (A rare piece, or one with runes set.)
func needs_confirm(item: ItemDef) -> bool:
	var equipment := item as EquipmentDef
	if equipment == null:
		return false
	return equipment.rarity >= confirm_rarity or not equipment.runes.is_empty()


## Gold for breaking `item` down (0 if it can't be).
func gold_for(item: ItemDef) -> int:
	var equipment := item as EquipmentDef
	if equipment == null:
		return 0
	var worth := equipment.value * ItemRarity.VALUE[equipment.rarity] * (1.0 + gold_per_level * (equipment.item_level - 1))
	for rune in equipment.runes:
		worth += rune.value if rune else 0
	return maxi(1, roundi(worth * gold_share))
