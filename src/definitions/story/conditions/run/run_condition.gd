class_name RunCondition
extends ProgressCondition
## A condition on the run that just ended (its RunFacts, the `subject` of the dialogue's
## conditions: the Vigil-Keeper's tale and advice). Not met without facts (at the shrine, on a
## keeper's panel). Subclass it and override met(); describe() stays empty (no codex lock).


func is_met(subject: Resource = null) -> bool:
	return subject is RunFacts and met(subject as RunFacts)


## The run described by `facts` is so.
func met(_facts: RunFacts) -> bool:
	return true
