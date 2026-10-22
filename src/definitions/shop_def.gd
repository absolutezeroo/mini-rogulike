class_name ShopDef
extends Resource
## The merchant met on some floors: what they sell, how much, and how they look.
## Prices: the item's `value` x its rarity (ItemRarity.VALUE) x `price_multiplier`, a bit more each floor.

@export var display_name: String = "Merchant"
## One is said when the shop opens.
@export_multiline var greetings: PackedStringArray = []
## What he says as his shop opens, his past told over the runs (Dialogues); nothing open: one of
## the greetings.
@export var dialogue: DialogueDef
## Body (first frame of a 16x16 sheet, drawn at 2x) and the face shown in the shop.
@export var sprite_sheet: Texture2D
@export var portrait: Texture2D

@export_group("Stock")
@export_range(0, 8) var equipment_count: int = 3
@export_range(0, 8) var consumable_count: int = 2
@export_range(0.0, 1.0) var tome_chance: float = 0.5
## Quality of the equipment for sale (see LootRoller): better than what lies around.
@export var quality: float = 2.0

@export_group("Prices")
@export var price_multiplier: float = 1.0
@export var price_per_depth: float = 0.08
## Part of the price paid back when selling.
@export_range(0.0, 1.0) var sell_ratio: float = 0.35
## Rerolling the stock (what isn't locked): this much the first time at a merchant, `growth`
## more each next time (back to the start at the next merchant). Grows with depth like prices.
@export var reroll_cost: int = 10
@export var reroll_cost_growth: int = 8


## `extra`: the difficulty's price multiplier.
func buy_price(item: ItemDef, depth: int, extra: float = 1.0) -> int:
	var rarity := (item as EquipmentDef).rarity if item is EquipmentDef else ItemRarity.COMMON
	var value := item.value * ItemRarity.VALUE[rarity]
	var equipment := item as EquipmentDef
	if equipment:
		for rune in equipment.runes:
			value += rune.value if rune else 0  # what is set in it is worth something too
	return maxi(1, roundi(value * price_multiplier * extra * (1.0 + price_per_depth * (depth - 1))))


## Gold for the next reroll of a stock, after `done` rerolls at this merchant.
func reroll_price(done: int, depth: int, extra: float = 1.0) -> int:
	return maxi(1, roundi((reroll_cost + reroll_cost_growth * done) * extra * (1.0 + price_per_depth * (depth - 1))))


## What the merchant pays (never touched by the difficulty).
func sell_price(item: ItemDef, depth: int) -> int:
	return maxi(1, roundi(buy_price(item, depth) * sell_ratio)) if item.value > 0 else 0


## The line said as the shop opens now, translated: his dialogue's, else a greeting.
func opening_line() -> String:
	var spoken := Dialogues.say(dialogue) if dialogue else null
	return spoken.text() if spoken else tr(random_greeting())


func random_greeting() -> String:
	return greetings[randi() % greetings.size()] if not greetings.is_empty() else ""
