class_name EquipmentDef
extends ItemDef
## An item worn in an equipment slot. Its stat bonuses apply while equipped.

enum Slot { WEAPON, HEAD, BODY }

const SLOT_NAMES := {
	Slot.WEAPON: "Weapon",  # i18n
	Slot.HEAD: "Head",  # i18n
	Slot.BODY: "Body",  # i18n
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
## Rolled copies made apart (each drop is its own resource) stack when they are the same item:
## same base item, rarity, item level, affixes (in order: they make the name) and set runes. That
## is exactly what a saved run keeps of it (LootRoller.to_data), so equal keys come back equal.
func stack_key() -> String:
	if not is_rolled():
		return super.stack_key()
	return base_item.stack_key() + "|" + JSON.stringify(LootRoller.to_data(self))


func socket_count() -> int:
	return ItemRarity.SOCKETS[rarity] if slot == Slot.WEAPON else 0


func free_sockets() -> int:
	return socket_count() - runes.size()


func rarity_color() -> Color:
	return ItemRarity.COLORS[rarity] if rarity > ItemRarity.COMMON else super.rarity_color()


func get_type_label() -> String:
	if rarity > ItemRarity.COMMON:
		return rarity_words(rarity, tr(SLOT_NAMES[slot]))
	return tr(SLOT_NAMES[slot])


## "Rare weapon" ("Arme rare"): a rarity and a kind of item (already translated).
static func rarity_words(item_rarity: int, kind: String) -> String:
	var rarity_name := TranslationServer.tr(ItemRarity.NAMES[item_rarity])
	return TranslationServer.tr("{rarity} {kind_lower}").format({
		"rarity": rarity_name, "rarity_lower": rarity_name.to_lower(),
		"kind": kind, "kind_lower": kind.to_lower() })


func get_details() -> String:
	var text := tr(base_item.description if base_item else description)
	text = tr("Item level %d (as strong as floor %d)") % [item_level, item_level] + "\n" + text
	if bonuses:
		var bonus_text := bonuses.describe()
		if not bonus_text.is_empty():
			text += "\n" + bonus_text
	for affix in affixes:
		if affix and not affix.description.is_empty():
			text += "\n" + tr(affix.description)
	for rune in runes:
		if rune:
			text += "\n" + tr("%s: %s") % [tr(rune.display_name), tr(rune.description)]
	if free_sockets() > 0:
		text += "\n" + (tr("%d empty rune sockets") if free_sockets() > 1 else tr("%d empty rune socket")) % free_sockets()
	return text
