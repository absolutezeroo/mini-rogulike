class_name PlaceCondition
extends RunCondition
## Where the run ended: on a floor between `min_depth` and `max_depth` (0: no bound), and in a
## place apart or not (the Deeps, the hidden floor, the bottom of the Well, a cursed floor, after
## the trial of the Threshold was lost, or a plain floor of an act).

enum Where { ANYWHERE, DEEPS, HIDDEN_FLOOR, FINALE, CURSED_FLOOR, THRESHOLD_LOST, ON_A_FLOOR }

@export var min_depth: int = 0
@export var max_depth: int = 0
@export var where: Where = Where.ANYWHERE
## A curse in particular (CurseDef id), with `where` CURSED_FLOOR; empty: any.
@export var curse_id: StringName = &""


func met(facts: RunFacts) -> bool:
	if min_depth > 0 and facts.depth < min_depth:
		return false
	if max_depth > 0 and facts.depth > max_depth:
		return false
	match where:
		Where.DEEPS:
			return facts.in_deeps
		Where.HIDDEN_FLOOR:
			return facts.hidden_floor
		Where.FINALE:
			return facts.finale
		Where.CURSED_FLOOR:
			return facts.curse_id != &"" and (curse_id == &"" or facts.curse_id == curse_id) and not facts.in_deeps
		Where.THRESHOLD_LOST:
			return facts.threshold_lost
		Where.ON_A_FLOOR:
			return not facts.in_deeps and not facts.hidden_floor and not facts.finale
	return true
