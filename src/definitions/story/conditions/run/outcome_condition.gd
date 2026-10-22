class_name OutcomeCondition
extends RunCondition
## How the run ended: lost or won, an ending chosen at the bottom of the Well, how long it lasted
## (`max_seconds` 0: no bound), on which difficulties (empty: any; DifficultyDef ids).

enum Outcome { ANY, DEATH, VICTORY }

@export var outcome: Outcome = Outcome.DEATH
## An ending in particular (EndingDef id) for a victory; empty: any (or none).
@export var ending: StringName = &""
@export var min_seconds: float = 0.0
@export var max_seconds: float = 0.0
@export var difficulties: Array[StringName] = []


func met(facts: RunFacts) -> bool:
	if (outcome == Outcome.DEATH and facts.won) or (outcome == Outcome.VICTORY and not facts.won):
		return false
	if ending != &"" and facts.ending != ending:
		return false
	if facts.seconds < min_seconds or (max_seconds > 0.0 and facts.seconds > max_seconds):
		return false
	return difficulties.is_empty() or difficulties.has(facts.difficulty_id)
