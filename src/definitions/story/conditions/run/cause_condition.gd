class_name CauseCondition
extends RunCondition
## How the hero died, one of `causes` (RunFacts.CAUSES: "monster", "shockwave", "trap", "fall",
## "burn", "poison", "cold", "heat", "quicksand", "blast", "altar", "giving_up", "unknown").

@export var causes: Array[StringName] = []


func met(facts: RunFacts) -> bool:
	return causes.has(facts.cause)
