class_name HardshipDeed
extends DeedCondition
## The warden fell on a hard enough run: one of `difficulties` (empty: any) at ascension
## `min_ascension` or more.

## Difficulty ids allowed ("hard", "nightmare"); empty: any.
@export var difficulties: Array[StringName] = []
@export var min_ascension: int = 0


func achieved(kill: Dictionary) -> bool:
	var difficulty := StringName(kill.get("difficulty", &""))
	if not difficulties.is_empty() and not difficulties.has(difficulty):
		return false
	return int(kill.get("ascension", 0)) >= min_ascension
