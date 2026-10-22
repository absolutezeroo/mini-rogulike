class_name KillerCondition
extends RunCondition
## What killed the hero: one of `monster_ids` (empty: any monster), and of a kind (a boss, not a
## boss, an elite, a monster fighting from afar or up close). A death without a monster (a trap,
## a fall) is never met.

enum Kind { ANY, BOSS, NOT_BOSS, ELITE, RANGED, MELEE }

@export var monster_ids: Array[StringName] = []
@export var kind: Kind = Kind.ANY


func met(facts: RunFacts) -> bool:
	if facts.killer_id == &"":
		return false
	if not monster_ids.is_empty() and not monster_ids.has(facts.killer_id):
		return false
	match kind:
		Kind.BOSS:
			return facts.killer_boss
		Kind.NOT_BOSS:
			return not facts.killer_boss
		Kind.ELITE:
			return facts.killer_elite
		Kind.RANGED:
			return facts.killer_ranged and not facts.killer_boss
		Kind.MELEE:
			return not facts.killer_ranged and not facts.killer_boss
	return true
