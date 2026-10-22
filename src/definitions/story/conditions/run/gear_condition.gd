class_name GearCondition
extends RunCondition
## What the hero carried as he fell: healing potions still unused (at least `potions_at_least`),
## and his armor (at most `armor_at_most` pieces worn: 0 for none; -1: not asked).

@export var potions_at_least: int = 0
@export var armor_at_most: int = -1


func met(facts: RunFacts) -> bool:
	if facts.potions_left < potions_at_least:
		return false
	return armor_at_most < 0 or facts.armor_worn <= armor_at_most
