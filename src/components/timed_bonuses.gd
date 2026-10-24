class_name TimedBonuses
extends RefCounted
## Stat bonuses that last a while (elixirs, war cries, a boss phase's rush: Actor.timed_bonuses):
## the same bonus again refreshes its time instead of stacking. The Actor adds them to its stats
## (add_to()) and asks again when one starts or runs out (add(), tick() return true).


## A stat bonus for a while.
class TimedBonus:
	var stats: StatBlock
	var time_left := 0.0


var _bonuses: Array[TimedBonus] = []


## `bonus` for `duration` seconds. True when it is new (the stats change); the same one again
## only lasts longer.
func add(bonus: StatBlock, duration: float) -> bool:
	for active in _bonuses:
		if active.stats == bonus:
			active.time_left = maxf(active.time_left, duration)
			return false
	var timed := TimedBonus.new()
	timed.stats = bonus
	timed.time_left = duration
	_bonuses.append(timed)
	return true


## Time passes. True when one ran out (the stats change).
func tick(delta: float) -> bool:
	if _bonuses.is_empty():
		return false
	var expired := false
	for bonus in _bonuses:
		bonus.time_left -= delta
		expired = expired or bonus.time_left <= 0.0
	if expired:
		_bonuses = _bonuses.filter(func(b: TimedBonus) -> bool: return b.time_left > 0.0)
	return expired


## `total` plus every bonus on now.
func add_to(total: StatBlock) -> StatBlock:
	for bonus in _bonuses:
		total = total.plus(bonus.stats)
	return total


## All gone at once (the balance tools start every fight clean).
func clear() -> void:
	_bonuses.clear()
