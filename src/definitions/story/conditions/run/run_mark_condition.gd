class_name RunMarkCondition
extends RunCondition
## The run did, or never did, something (RunState.marks, as MarkDeed reads them): "drank" (a
## healing potion), "rolled", "bought", "cursed", "oath", "secret", "encounter:<id>"...

@export var mark: StringName
## True: it did. False: it never did (a run that never drank).
@export var present: bool = true


func met(facts: RunFacts) -> bool:
	return facts.has_mark(String(mark)) == present
