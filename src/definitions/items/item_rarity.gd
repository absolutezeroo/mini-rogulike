class_name ItemRarity
## How good a piece of found equipment is. Common items are the plain .tres;
## better ones are rolled copies with random affixes (see LootRoller, ItemAffixDef).

enum { COMMON, MAGIC, RARE, EPIC }

const NAMES: Array[String] = ["Common", "Magic", "Rare", "Epic"]
const COLORS: Array[Color] = [Color(0.92, 0.9, 0.86), Color("5ea8ff"), Color("ffd166"), Color("c77dff")]
## Random affixes on the item.
const AFFIX_COUNT: Array[int] = [0, 1, 2, 3]
## Multiplies a weapon's damage and the item's own stat bonuses.
const POWER: Array[float] = [1.0, 1.1, 1.2, 1.35]
## Multiplies the price at the merchant.
const VALUE: Array[float] = [1.0, 1.8, 3.0, 5.0]
