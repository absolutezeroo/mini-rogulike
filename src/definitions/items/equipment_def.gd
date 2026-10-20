class_name EquipmentDef
extends ItemDef
## An item worn in an equipment slot. Its stat bonuses apply while equipped.

enum Slot { WEAPON, HEAD, BODY }

const SLOT_NAMES := {
	Slot.WEAPON: "Weapon",
	Slot.HEAD: "Head",
	Slot.BODY: "Body",
}

@export var slot: Slot = Slot.BODY
@export var bonuses: StatBlock

## Rolled copies only (see LootRoller): the plain item it was made from, its rarity, its affixes.
## Kept by duplicate() (storage only, never edited by hand).
@export_storage var base_item: EquipmentDef
@export_storage var rarity: int = ItemRarity.COMMON
@export_storage var affixes: Array[ItemAffixDef] = []
## Weapons: the runes set in it at a forge (as many as socket_count()).
@export_storage var runes: Array[RuneDef] = []
## The floor it was found or bought on: its power, fixed for good (see ItemLevelRules).
@export_storage var item_level: int = 1


func is_rolled() -> bool:
	return base_item != null


## Rune sockets: weapons only, 1 to 3 by rarity.
func socket_count() -> int:
	return ItemRarity.SOCKETS[rarity] if slot == Slot.WEAPON else 0


func free_sockets() -> int:
	return socket_count() - runes.size()


func rarity_color() -> Color:
	return ItemRarity.COLORS[rarity] if rarity > ItemRarity.COMMON else super.rarity_color()


func get_type_label() -> String:
	if rarity > ItemRarity.COMMON:
		return "%s %s" % [ItemRarity.NAMES[rarity], SLOT_NAMES[slot].to_lower()]
	return SLOT_NAMES[slot]


func get_details() -> String:
	var text := base_item.description if base_item else description
	text = "Item level %d (as strong as floor %d)\n%s" % [item_level, item_level, text]
	if bonuses:
		var bonus_text := bonuses.describe()
		if not bonus_text.is_empty():
			text += "\n" + bonus_text
	for affix in affixes:
		if affix and not affix.description.is_empty():
			text += "\n" + affix.description
	for rune in runes:
		if rune:
			text += "\n%s: %s" % [rune.display_name, rune.description]
	if free_sockets() > 0:
		text += "\n%d empty rune socket%s" % [free_sockets(), "s" if free_sockets() > 1 else ""]
	return text
