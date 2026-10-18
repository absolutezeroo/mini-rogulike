class_name StatusSet
extends RefCounted
## Damage over time on an actor (burn, poison...). Each status has an id:
## applying the same id again refreshes it instead of stacking a second copy.


class Dot:
	var id: StringName
	var damage: int
	var interval: float
	var time_left: float
	var next_tick: float
	var source: Actor
	var color: Color


var _dots: Array[Dot] = []


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


func has(id: StringName) -> bool:
	return _dots.any(func(dot: Dot) -> bool: return dot.id == id)


func is_empty() -> bool:
	return _dots.is_empty()


## Tint of the strongest active status (for the actor's body), or transparent.
func tint() -> Color:
	return _dots[0].color if not _dots.is_empty() else Color.TRANSPARENT


func clear() -> void:
	_dots.clear()


func tick(owner: Actor, delta: float) -> void:
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
