class_name EndingCondition
extends ProgressCondition
## The hero chose this ending at the bottom of the Well, the last time he chose one
## (Profile.ending: an EndingDef id). What the Vigil-Keeper says after it.

@export var ending: StringName


func is_met(_subject: Resource = null) -> bool:
	return ending != &"" and Profile.ending == ending


func describe(_subject: Resource = null) -> String:
	return ""
