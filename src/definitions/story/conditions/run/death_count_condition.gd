class_name DeathCountCondition
extends RunCondition
## The same monster has killed the hero at least `at_least` times, this death counted
## (Profile.deaths_by): `monster_id`, or empty for whatever killed him this time.

@export var monster_id: StringName = &""
@export_range(1, 999) var at_least: int = 3


func met(facts: RunFacts) -> bool:
	var id := monster_id if monster_id != &"" else facts.killer_id
	return id != &"" and Profile.deaths_to(id) >= at_least
