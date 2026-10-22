class_name AnyCondition
extends ProgressCondition
## One of several ways there, kept as one resource so many texts can share it: "the keeper's
## name may be said" once the Nameless Effigy is slain and a run won, or once the hero has met
## him at the bottom of the Well (data/story/conditions/keeper_named.tres).

@export var conditions: Array[ProgressCondition] = []
## Plain words for the whole (the codex's lock). Empty: the first way still open.
@export var text: String = ""


func is_met(subject: Resource = null) -> bool:
	for condition in conditions:
		if condition and condition.is_met(subject):
			return true
	return false


func describe(subject: Resource = null) -> String:
	if not text.is_empty():
		return tr(text)
	for condition in conditions:
		if condition and not condition.is_met(subject):
			return condition.describe(subject)
	return ""


func deeds() -> Array[DeedCondition]:
	var result: Array[DeedCondition] = []
	for condition in conditions:
		if condition:
			result.append_array(condition.deeds())
	return result


## `condition` is one of its ways, or inside one (the reveal check of the tests).
func contains(condition: ProgressCondition) -> bool:
	for inner in conditions:
		if inner == condition:
			return true
		if inner is AllCondition and (inner as AllCondition).contains(condition):
			return true
		if inner is AnyCondition and (inner as AnyCondition).contains(condition):
			return true
	return false
