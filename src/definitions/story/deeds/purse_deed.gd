class_name PurseDeed
extends DeedCondition
## The hero carried at most `max_gold` gold when the warden fell (the gold king, met with an
## empty purse).

@export var max_gold: int = 0


func achieved(kill: Dictionary) -> bool:
	return int(kill.get("gold", 0)) <= max_gold
