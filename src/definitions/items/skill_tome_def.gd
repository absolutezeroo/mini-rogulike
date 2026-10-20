class_name SkillTomeDef
extends ItemDef
## A tome that teaches a skill. Using it puts the skill in the "learned" slot (the last
## skill button), replacing the previous one: any weapon can be paired with any spell.

@export var skill: SkillDef


func get_type_label() -> String:
	return tr("Skill tome")


func get_details() -> String:
	if skill == null:
		return tr(description)
	var text := tr("Teaches %s (cooldown %.1f s).") % [tr(skill.display_name), skill.cooldown]
	if not skill.description.is_empty():
		text += "\n" + tr(skill.description)
	return text
