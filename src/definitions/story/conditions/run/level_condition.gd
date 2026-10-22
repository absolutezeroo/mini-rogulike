class_name LevelCondition
extends RunCondition
## The hero's level against his depth: behind (a hero who ran for the stairs), or ahead. The
## level expected on a floor is `base + per_floor x depth` (the balance's expected builds: about
## 6 at Act I's warden, 9 at Act II's, 11 at Act III's, 13 at Act IV's; data/balance/builds/).

@export var base: float = 3.0
@export var per_floor: float = 0.9
## Met when the level is at least this many levels under what is expected (negative: over it).
@export var behind_by: int = 3


func met(facts: RunFacts) -> bool:
	return float(facts.level + behind_by) <= expected(facts.depth)


func expected(depth: int) -> float:
	return base + per_floor * depth
