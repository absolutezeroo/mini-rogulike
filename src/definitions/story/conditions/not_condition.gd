class_name NotCondition
extends ProgressCondition
## The other way round: met while `condition` is not. The Vigil-Keeper's lines of denial wait
## for nothing but stop once the keeper is named (not keeper_named.tres).

@export var condition: ProgressCondition


func is_met(subject: Resource = null) -> bool:
	return condition != null and not condition.is_met(subject)


func describe(_subject: Resource = null) -> String:
	return ""
