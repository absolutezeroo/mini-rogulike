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


func is_rolled() -> bool:
	return base_item != null


func rarity_color() -> Color:
	return ItemRarity.COLORS[rarity] if rarity > ItemRarity.COMMON else super.rarity_color()


func get_type_label() -> String:
	if rarity > ItemRarity.COMMON:
		return "%s %s" % [ItemRarity.NAMES[rarity], SLOT_NAMES[slot].to_lower()]
	return SLOT_NAMES[slot]


func get_details() -> String:
	var text := base_item.description if base_item else description
	if bonuses:
		var bonus_text := bonuses.describe()
		if not bonus_text.is_empty():
			text += "\n" + bonus_text
	for affix in affixes:
		if affix and not affix.description.is_empty():
			text += "\n" + affix.description
	return text
