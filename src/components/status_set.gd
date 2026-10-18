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
var _slow := 0.0
var _slow_time := 0.0


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


## Keeps the strongest slow; refreshes its duration.
func apply_slow(amount: float, duration: float) -> void:
	_slow = maxf(_slow, clampf(amount, 0.0, 0.9))
	_slow_time = maxf(_slow_time, duration)


## Multiplier for the move speed (1 = not slowed).
func speed_multiplier() -> float:
	return 1.0 - _slow if _slow_time > 0.0 else 1.0


func is_slowed() -> bool:
	return _slow_time > 0.0


func has(id: StringName) -> bool:
	return _dots.any(func(dot: Dot) -> bool: return dot.id == id)


func is_empty() -> bool:
	return _dots.is_empty() and _slow_time <= 0.0


## Tint of the strongest active status (for the actor's body), or transparent.
func tint() -> Color:
	if not _dots.is_empty():
		return _dots[0].color
	return SLOW_COLOR if is_slowed() else Color.TRANSPARENT


func clear() -> void:
	_dots.clear()
	_slow_time = 0.0


func tick(owner: Actor, delta: float) -> void:
	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow = 0.0
	for dot in _dots.duplicate():
		dot.time_left -= delta
		dot.next_tick -= delta
		if dot.next_tick <= 0.0:
			dot.next_tick += dot.interval
			var source: Actor = dot.source if is_instance_valid(dot.source) else null
			owner.take_hit(Combat.make_secondary_hit(source, dot.damage))
			if owner.is_dead:
				_dots.clear()
				return
		if dot.time_left <= 0.0:
			_dots.erase(dot)
