class_name CheatDeathPassive
extends Passive
## Survives a killing blow, once per stack for the whole run.

@export_range(0.0, 1.0) var heal_ratio: float = 0.5
## The share of max Health it brings back during a boss fight instead (a second life, not a
## second full fight: two feathers must not carry a hero who only stands and hits).
@export_range(0.0, 1.0) var boss_fight_heal_ratio: float = 0.5
@export var color: Color = Palette.GOLD


func prevent_death(owner: Actor, perk: PerkSet.Entry) -> bool:
	var used: int = perk.memory.get(&"used", 0)
	if used >= perk.stacks:
		return false
	perk.memory[&"used"] = used + 1
	var ratio := boss_fight_heal_ratio if owner.world and owner.world.is_boss_fight() else heal_ratio
	owner.hp = maxi(1, roundi(owner.get_max_hp() * ratio))
	owner.health_changed.emit(owner.hp, owner.get_max_hp())
	owner.world.spawn_floating_text(owner.head_position(), tr(perk.perk.display_name).to_upper(), color)
	Vfx.magic(owner.world, owner.global_position, color)
	Combat.damage_area(owner.world, owner, owner.global_position, 110.0, owner.get_power(), 320.0, true)
	return true
