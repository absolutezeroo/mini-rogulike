class_name StatusSet
extends RefCounted
## Statuses on an actor: damage over time (burn, poison...) and slows.
## Applying the same damage-over-time id again refreshes it instead of stacking a second copy.


class Dot:
	var id: StringName
	var damage: int
	var interval: float
	var time_left: float
	var next_tick: float
	var source: Actor
	var color: Color


const SLOW_COLOR := Color("8ecae6")

var _dots: Array[Dot] = []
## Slows by source (a frost hit, the cold, quicksand...): source -> [amount, seconds left].
## The strongest active one counts; each runs out on its own.
var _slows := {}


## Deals `damage` every `interval` seconds for `duration` seconds.
func apply_dot(id: StringName, damage: int, interval: float, duration: float, source: Actor, color: Color) -> void:
	for dot in _dots:
		if dot.id == id:
			dot.damage = maxi(dot.damage, damage)
			dot.time_left = maxf(dot.time_left, duration)
			dot.source = source
			return
	var dot := Dot.new()
	dot.id = id
	dot.damage = damage
	dot.interval = maxf(interval, 0.05)
	dot.time_left = duration
	dot.next_tick = dot.interval
	dot.source = source
	dot.color = color
	_dots.append(dot)


## Slows by `amount` for `duration` seconds. `source` keeps different slows apart: things that
## re-apply every frame (cold, quicksand) don't stretch a frost hit forever.
func apply_slow(amount: float, duration: float, source: StringName = &"hit") -> void:
	amount = clampf(amount, 0.0, 0.9)
	var current: Array = _slows.get(source, [0.0, 0.0])
	if source == &"hit":
		# Hits: the strongest one, the longest one.
		_slows[source] = [maxf(current[0], amount), maxf(current[1], duration)]
	else:
		_slows[source] = [amount, duration]


## Multiplier for the move speed (1 = not slowed).
func speed_multiplier() -> float:
	var slow := 0.0
	for source in _slows:
		slow = maxf(slow, _slows[source][0])
	return 1.0 - slow


func is_slowed() -> bool:
	return not _slows.is_empty()


func has(id: StringName) -> bool:
	return _dots.any(func(dot: Dot) -> bool: return dot.id == id)


func is_empty() -> bool:
	return _dots.is_empty() and _slows.is_empty()


## Tint of the strongest active status (for the actor's body), or transparent.
func tint() -> Color:
	if not _dots.is_empty():
		return _dots[0].color
	return SLOW_COLOR if is_slowed() else Color.TRANSPARENT


func clear() -> void:
	_dots.clear()
	_slows.clear()


func tick(owner: Actor, delta: float) -> void:
	for source in _slows.keys():
		_slows[source][1] -= delta
		if _slows[source][1] <= 0.0:
			_slows.erase(source)
	for dot in _dots.duplicate():
		dot.time_left -= delta
		dot.next_tick -= delta
		if dot.next_tick <= 0.0:
			dot.next_tick += dot.interval
			var source: Actor = dot.source if is_instance_valid(dot.source) else null
			owner.take_hit(Combat.make_tick(source, dot.damage))
			if owner.is_dead:
				_dots.clear()
				return
		if dot.time_left <= 0.0:
			_dots.erase(dot)
