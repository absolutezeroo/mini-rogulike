class_name SkillTomeDef
extends ItemDef
## A tome that teaches a skill. Using it puts the skill in the "learned" slot (the last
## skill button), replacing the previous one: any weapon can be paired with any spell.

@export var skill: SkillDef


func get_type_label() -> String:
	return "Skill tome"


func get_details() -> String:
	if skill == null:
		return description
	var text := "Teaches %s (cooldown %.1f s)." % [skill.display_name, skill.cooldown]
	if not skill.description.is_empty():
		text += "\n" + skill.description
	return text
