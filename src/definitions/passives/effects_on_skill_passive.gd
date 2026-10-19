class_name EffectsOnSkillPassive
extends Passive
## Using a skill also does these (a ring of arcane bolts, a blast...), aimed where the owner faces.

@export var effects: Array[Effect] = []


func on_skill_used(owner: Actor, _skill: SkillDef, _perk: PerkSet.Entry) -> void:
	Effect.apply_all(effects, owner, owner.facing)
