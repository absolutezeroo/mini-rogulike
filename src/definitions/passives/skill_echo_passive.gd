class_name SkillEchoPassive
extends Passive
## Using a skill may leave it ready again at once (chance per stack).

@export_range(0.0, 1.0) var chance_per_stack: float = 0.15
@export var color: Color = Color("b388eb")


func on_skill_used(owner: Actor, skill: SkillDef, perk: PerkSet.Entry) -> void:
	if randf() >= chance_per_stack * perk.stacks:
		return
	owner.skills.reset_cooldown(skill)
	owner.world.spawn_floating_text(owner.head_position(), "ECHO", color)
