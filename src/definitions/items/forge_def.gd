class_name ForgeDef
extends Resource
## The smith's forge, met on some floors (DungeonConfig.forge, forge_chance): runes go into the
## worn weapon's sockets there for free; taking one back out, intact, costs gold.

@export var display_name: String = "Smith"
@export var portrait: Texture2D
## The smith's 4-direction sheet (16x16 frames, facing down in the first column).
@export var sprite_sheet: Texture2D
@export var anvil: Texture2D
@export var greetings: PackedStringArray = []
@export_group("Prices")
## Gold to take a rune out of a weapon, plus this much per floor of depth.
@export var removal_price: int = 25
@export var removal_price_per_depth: float = 4.0


func random_greeting() -> String:
	return greetings[randi() % greetings.size()] if not greetings.is_empty() else ""


## What taking a rune out costs at `depth` (times the difficulty's shop prices).
func removal_cost(depth: int, prices: float = 1.0) -> int:
	return maxi(1, roundi((removal_price + removal_price_per_depth * (depth - 1)) * prices))
