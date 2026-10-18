class_name HealOnKillPassive
extends Passive
## Heals the owner every time they kill an enemy.

@export var heal_per_stack: int = 2


func on_kill(owner: Actor, _victim: Actor, perk: PerkSet.Entry) -> void:
	var healed := owner.heal(heal_per_stack * perk.stacks)
	if healed > 0:
		owner.world.spawn_floating_text(owner.head_position(), "+%d" % healed, Color("6ee787"))
