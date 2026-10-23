class_name StatBlock
extends Resource
## A bundle of stats. Used for base stats, equipment bonuses, level-up gains, perks and buffs.

@export var max_hp: int = 0
@export var attack: int = 0
@export var defense: int = 0
@export var move_speed: float = 0.0
@export_range(0.0, 1.0, 0.01) var crit_chance: float = 0.0
## Faster attacks: 0.2 = attacks recover 20% faster (weapon cooldown / 1.2).
@export_range(-0.5, 3.0, 0.01) var attack_speed: float = 0.0
## Stronger skills: 0.15 = skills deal 15% more damage.
@export_range(-0.5, 5.0, 0.01) var skill_power: float = 0.0
## Shorter skill cooldowns: 0.1 = 10% shorter (capped at 60% in total).
@export_range(0.0, 0.6, 0.01) var cooldown_reduction: float = 0.0


## Returns a new block with both blocks added together. Neither block is modified.
func plus(other: StatBlock) -> StatBlock:
	var result := StatBlock.new()
	result.max_hp = max_hp + other.max_hp
	result.attack = attack + other.attack
	result.defense = defense + other.defense
	result.move_speed = move_speed + other.move_speed
	result.crit_chance = crit_chance + other.crit_chance
	result.attack_speed = attack_speed + other.attack_speed
	result.skill_power = skill_power + other.skill_power
	result.cooldown_reduction = cooldown_reduction + other.cooldown_reduction
	return result


## Returns a new block with every stat multiplied by `count` (stacked perks).
func times(count: int) -> StatBlock:
	var result := StatBlock.new()
	result.max_hp = max_hp * count
	result.attack = attack * count
	result.defense = defense * count
	result.move_speed = move_speed * count
	result.crit_chance = crit_chance * count
	result.attack_speed = attack_speed * count
	result.skill_power = skill_power * count
	result.cooldown_reduction = cooldown_reduction * count
	return result


## Returns a new block with every stat multiplied by `factor` (ints rounded, at least the sign kept).
func scaled(factor: float) -> StatBlock:
	var result := StatBlock.new()
	result.max_hp = _scale_int(max_hp, factor)
	result.attack = _scale_int(attack, factor)
	result.defense = _scale_int(defense, factor)
	result.move_speed = move_speed * factor
	result.crit_chance = crit_chance * factor
	result.attack_speed = attack_speed * factor
	result.skill_power = skill_power * factor
	result.cooldown_reduction = cooldown_reduction * factor
	return result


static func _scale_int(value: int, factor: float) -> int:
	return roundi(value * factor) if value != 0 else 0


## The stats as a Dictionary (for save files).
func to_dict() -> Dictionary:
	var data := {}
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			data[property.name] = get(property.name)
	return data


static func from_dict(data: Dictionary) -> StatBlock:
	var block := StatBlock.new()
	for key: String in data:
		if key in block:
			var value: Variant = data[key]
			if typeof(block.get(key)) == TYPE_INT:
				block.set(key, int(value))
			else:
				block.set(key, float(value))
	return block


## Human readable bonuses, e.g. "+2 ATK  +1 DEF".
## In plain words, the same everywhere (cards, shop, bag, shrine): "+3 damage, +1 armor".
func describe() -> String:
	var parts := PackedStringArray()
	if max_hp != 0:
		parts.append(tr("%+d max health") % max_hp)
	if attack != 0:
		parts.append(tr("%+d damage") % attack)
	if defense != 0:
		parts.append(tr("%+d armor") % defense)
	if not is_zero_approx(move_speed):
		parts.append(tr("%+d move speed") % roundi(move_speed))
	if not is_zero_approx(crit_chance):
		parts.append(tr("%+d%% critical hit chance") % roundi(crit_chance * 100.0))
	if not is_zero_approx(attack_speed):
		parts.append(tr("%+d%% attack speed") % roundi(attack_speed * 100.0))
	if not is_zero_approx(skill_power):
		parts.append(tr("%+d%% skill damage") % roundi(skill_power * 100.0))
	if not is_zero_approx(cooldown_reduction):
		parts.append(tr("skills recharge %d%% faster") % roundi(cooldown_reduction * 100.0))
	return ", ".join(parts)
