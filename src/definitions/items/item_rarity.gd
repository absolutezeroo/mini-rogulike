class_name ItemRarity
## How good a piece of found equipment is. Common items are the plain .tres;
## better ones are rolled copies with random affixes (see LootRoller, ItemAffixDef).

enum { COMMON, MAGIC, RARE, EPIC }

const NAMES: Array[String] = ["Common", "Magic", "Rare", "Epic"]  # i18n
const COLORS: Array[Color] = [Color(0.92, 0.9, 0.86), Color("5ea8ff"), Palette.GOLD, Color("c77dff")]
## Random affixes on the item.
const AFFIX_COUNT: Array[int] = [0, 1, 2, 3]
## Multiplies a weapon's damage and the item's own stat bonuses.
const POWER: Array[float] = [1.0, 1.1, 1.2, 1.35]
## Multiplies the price at the merchant.
const VALUE: Array[float] = [1.0, 1.8, 3.0, 5.0]
## Rune sockets of a weapon of this rarity (see RuneDef, Forge).
const SOCKETS: Array[int] = [1, 1, 2, 3]
## How each rarity shows (on the ground, in a slot, worn): data/items/rarity_looks.tres.
const LOOKS_PATH := "res://data/items/rarity_looks.tres"

static var _looks: RarityLookSet


## The look of `rarity` (RarityLookDef), Common's for anything out of range.
static func look(rarity: int) -> RarityLookDef:
	if _looks == null:
		_looks = load(LOOKS_PATH) as RarityLookSet
	if _looks == null or _looks.looks.is_empty():
		return null
	return _looks.looks[clampi(rarity, 0, _looks.looks.size() - 1)]


## The rarity of `item`: found equipment's own, Common for everything else.
static func of(item: ItemDef) -> int:
	var equipment := item as EquipmentDef
	return equipment.rarity if equipment else COMMON
