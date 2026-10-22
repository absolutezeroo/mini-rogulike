class_name AllCondition
extends ProgressCondition
## Several conditions at once, kept as one resource so many texts can share it: one way to "the
## keeper's name may be said" is the Nameless Effigy slain and a first victory
## (data/story/conditions/keeper_named.tres, an AnyCondition).

@export var conditions: Array[ProgressCondition] = []
## Plain words for the whole (optional). Empty: the unmet parts, one per line.
@export var text: String = ""


func is_met(subject: Resource = null) -> bool:
	return ProgressCondition.all_met(conditions, subject)


func describe(subject: Resource = null) -> String:
	if not text.is_empty():
		return tr(text)
	return "\n".join(ProgressCondition.describe_unmet(conditions, subject))


func deeds() -> Array[DeedCondition]:
	var result: Array[DeedCondition] = []
	for condition in conditions:
		if condition:
			result.append_array(condition.deeds())
	return result


## `condition` is this one or inside it (the reveal check of the tests).
func contains(condition: ProgressCondition) -> bool:
	for inner in conditions:
		if inner == condition or (inner is AllCondition and (inner as AllCondition).contains(condition)):
			return true
		if inner is AnyCondition and (inner as AnyCondition).contains(condition):
			return true
	return false
