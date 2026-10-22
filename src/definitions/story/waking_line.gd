class_name WakingLine
extends Resource
## What a warden says as it wakes, when the hero carries some memory of it (a fragment found, a
## deed done): its own words, shown in quotes « ... » before the chapter. The last open one of
## a chronicle is the one it says; told once in full, then it is what the short version recalls.

## Unique in its chronicle (saved as told: never rename).
@export var id: StringName
## One or two short sentences, the warden speaking (French in « »).
@export var line: String = ""
@export var conditions: Array[ProgressCondition] = []


func is_open(boss: BossDef) -> bool:
	return ProgressCondition.all_met(conditions, boss)


func deeds() -> Array[DeedCondition]:
	var result: Array[DeedCondition] = []
	for condition in conditions:
		if condition:
			result.append_array(condition.deeds())
	return result
