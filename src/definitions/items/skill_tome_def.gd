class_name SkillTomeDef
extends ItemDef
## A tome that teaches a skill. Using it puts the skill in the "learned" slot (the last
## skill button), replacing the previous one: any weapon can be paired with any spell.

@export var skill: SkillDef


## Read from the bag: it is gone, its skill learned (the last skill button).
func use_from_bag(player: Player) -> void:
	player.inventory.remove(self)
	player.learn_skill(skill)


func get_type_label() -> String:
	return tr("Skill tome")


func get_details() -> String:
	if skill == null:
		return tr(description)
	var text := tr("Teaches %s (cooldown %.1f s).") % [tr(skill.display_name), skill.cooldown]
	# The tome's own line (what book it is, then how reading works) above what it teaches.
	if not description.is_empty():
		text = tr(description) + "\n" + text
	if not skill.description.is_empty():
		text += "\n" + tr(skill.description)
	return text
