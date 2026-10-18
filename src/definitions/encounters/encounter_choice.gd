class_name EncounterChoice
extends Resource
## One option of an encounter: what it costs, and what may come of it (one outcome is drawn
## by weight).

const GOLD_COST_PER_DEPTH := 0.2

@export var label: String = "Accept"
## Gold paid (a bit more each floor, see cost_in_gold()).
@export var gold_cost: int = 0
## Part of the hero's max HP given away for the rest of the run.
@export_range(0.0, 0.9, 0.01) var max_hp_cost: float = 0.0
@export var outcomes: Array[EncounterOutcome] = []


func cost_in_gold(depth: int) -> int:
	return roundi(gold_cost * (1.0 + GOLD_COST_PER_DEPTH * (depth - 1)))


func max_hp_lost(player: Player) -> int:
	return roundi(player.base_stats.max_hp * max_hp_cost)


## Button text with its price, e.g. "Pay 36 gold".
func describe(player: Player, depth: int) -> String:
	var parts := PackedStringArray([label])
	if gold_cost > 0:
		parts.append("(%d gold)" % cost_in_gold(depth))
	if max_hp_cost > 0.0:
		parts.append("(-%d max HP)" % max_hp_lost(player))
	return " ".join(parts)


func can_afford(player: Player, depth: int) -> bool:
	return player.gold >= cost_in_gold(depth) and player.base_stats.max_hp - max_hp_lost(player) >= 10


func pick_outcome(rng: RandomNumberGenerator) -> EncounterOutcome:
	var weights := PackedInt32Array()
	for outcome in outcomes:
		weights.append(outcome.weight)
	return RandomUtils.pick_weighted(outcomes, weights, rng)
