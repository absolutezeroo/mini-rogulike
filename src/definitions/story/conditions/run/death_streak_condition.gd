class_name DeathStreakCondition
extends RunCondition
## The last `count` runs (this one too: the history keeps it first) all ended in death, each
## between `min_depth` and `max_depth` (0: no bound): dying early again and again, or always in
## the same act. Reads Profile.history (the last runs, newest first).

@export_range(1, 20) var count: int = 3
@export var min_depth: int = 0
@export var max_depth: int = 0


func met(_facts: RunFacts) -> bool:
	if Profile.history.size() < count:
		return false
	for i in count:
		var entry: Dictionary = Profile.history[i]
		var depth := int(entry.get("depth", 0))
		if bool(entry.get("won", false)):
			return false
		if (min_depth > 0 and depth < min_depth) or (max_depth > 0 and depth > max_depth):
			return false
	return true
