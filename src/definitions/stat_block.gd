class_name StatBlock
extends Resource
## A bundle of stats. Used for base stats, equipment bonuses, level-up gains and buffs.

@export var max_hp: int = 0
@export var attack: int = 0
@export var defense: int = 0
@export var move_speed: float = 0.0
@export_range(0.0, 1.0, 0.01) var crit_chance: float = 0.0


## Returns a new block with both blocks added together. Neither block is modified.
func plus(other: StatBlock) -> StatBlock:
	var result := StatBlock.new()
	result.max_hp = max_hp + other.max_hp
	result.attack = attack + other.attack
	result.defense = defense + other.defense
	result.move_speed = move_speed + other.move_speed
	result.crit_chance = crit_chance + other.crit_chance
	return result


## Human readable bonuses, e.g. "+2 ATK  +1 DEF".
func describe() -> String:
	var parts := PackedStringArray()
	if max_hp != 0:
		parts.append("%+d HP" % max_hp)
	if attack != 0:
		parts.append("%+d ATK" % attack)
	if defense != 0:
		parts.append("%+d DEF" % defense)
	if not is_zero_approx(move_speed):
		parts.append("%+d SPD" % roundi(move_speed))
	if not is_zero_approx(crit_chance):
		parts.append("%+d%% CRIT" % roundi(crit_chance * 100.0))
	return "  ".join(parts)
