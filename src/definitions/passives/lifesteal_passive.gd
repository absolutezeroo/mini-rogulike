class_name LifestealPassive
extends Passive
## Heals the owner for part of the damage they deal.

@export_range(0.0, 2.0, 0.05) var ratio_per_stack: float = 0.5


func on_hit_dealt(owner: Actor, _target: Actor, _hit: HitInfo, damage: int, perk: PerkSet.Entry) -> void:
	var healed := owner.heal(roundi(damage * ratio_per_stack * perk.stacks))
	if healed > 0:
		owner.world.spawn_floating_text(owner.head_position(), "+%d" % healed, Palette.HEAL)
