class_name SustainMeter
extends RefCounted
## One actor's healing from "per hit" and "per kill" sources (see Actor.sustain_heal()):
## - fractions add up and are paid in whole points (8% of a 7-damage hit is 0.56, not 1);
## - with SustainRules (the hero), every source draws from one budget that refills at a set
##   share of the max health per second (slower during a boss fight).
## Nothing is banked at full health.

## Healing owed but not paid yet (less than one point).
var pending := 0.0
## Health the rules still allow right now (filled on first use).
var budget := 0.0
var _last_time := -1.0


## Whole points to heal now for `amount` asked by a source (may be fractional).
## `missing`: max health minus health. `now`: game time in seconds.
func take(amount: float, max_hp: int, missing: int, now: float, rules: SustainRules = null, boss_fight: bool = false) -> int:
	if rules:
		_refill(max_hp, now, rules, boss_fight)
	if amount <= 0.0 or max_hp <= 0:
		return 0
	if missing <= 0:
		pending = 0.0
		return 0
	var allowed := minf(amount, budget) if rules else amount
	if rules:
		budget -= allowed
	pending += allowed
	var whole := floori(pending + 0.0001)
	pending = maxf(pending - whole, 0.0)
	if whole > missing:
		# Topped up: what didn't fit goes back to the budget, nothing is kept for later.
		if rules:
			budget += whole - missing
		whole = missing
		pending = 0.0
	return whole


func _refill(max_hp: int, now: float, rules: SustainRules, boss_fight: bool) -> void:
	var capacity := rules.capacity(max_hp)
	if _last_time < 0.0:
		budget = capacity
	else:
		budget = minf(capacity, budget + rules.refill_per_second(max_hp, boss_fight) * maxf(now - _last_time, 0.0))
	_last_time = now
