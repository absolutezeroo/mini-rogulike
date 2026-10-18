class_name HealOnSkillPassive
extends Passive
## Heals the owner every time they use a skill.

@export var heal_per_stack: int = 3
## Quick skills (the roll) don't count.
@export var min_cooldown: float = 3.0


func on_skill_used(owner: Actor, skill: SkillDef, perk: PerkSet.Entry) -> void:
	if skill.cooldown < min_cooldown:
		return
	var healed := owner.heal(heal_per_stack * perk.stacks)
	if healed > 0:
		owner.world.spawn_floating_text(owner.head_position(), "+%d" % healed, Color("6ee787"))
