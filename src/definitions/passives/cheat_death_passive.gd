class_name CheatDeathPassive
extends Passive
## Survives a killing blow, once per stack for the whole run.

@export_range(0.0, 1.0) var heal_ratio: float = 0.5
@export var color: Color = Color("ffd166")


func prevent_death(owner: Actor, perk: PerkSet.Entry) -> bool:
	var used: int = perk.memory.get(&"used", 0)
	if used >= perk.stacks:
		return false
	perk.memory[&"used"] = used + 1
	owner.hp = maxi(1, roundi(owner.get_max_hp() * heal_ratio))
	owner.health_changed.emit(owner.hp, owner.get_max_hp())
	owner.world.spawn_floating_text(owner.head_position(), perk.perk.display_name.to_upper(), color)
	Vfx.magic(owner.world, owner.global_position, color)
	Combat.damage_area(owner.world, owner, owner.global_position, 110.0, owner.get_power(), 320.0, true)
	return true
