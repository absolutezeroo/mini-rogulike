class_name SwingMatter
extends Node2D
## What an elemental blow sheds (docs/vfx.md, "Elemental attacks"): bits of its element born on
## the swing's edge as its head passes, then going the element's way (fire's embers and licks
## rising, frost's chips falling, poison's bubbles sinking and drips falling, storm's forks
## jumping off, blood flung on arcs, holy's glints drifting down, shadow's motes drawn in,
## arcane's runes orbiting), down its ramp, dithered out. A second element the weapon carries
## adds a few bits of its own. Steel sheds nothing: its arc is enough.
##
## Drawn by hand on the art's grid (PixelDraw.bit), on the swing's own layer (behind the hero
## when he strikes north: docs/vfx.md 2b).

## Seconds a bit lives (fire's licks live less, embers more).
const LIFE := 0.4
## Bits for a swing of 60 world units of edge; more for a longer edge, at most MOST.
const PER_60 := 5
const MOST := 14
## Bits of the second element, for every PER_SECOND of the first.
const PER_SECOND := 3

var _bits: Array[Dictionary] = []
var _age := 0.0
var _life := LIFE


## The matter of a blow from `at` toward `aim`: a crescent of `arc` radians at `radius` (its
## edge `thickness` thick), or a thrust (`thrust`) from `inner` to `radius`, its head taking
## `duration` seconds after `delay`. In `element`, a few bits of `second`. Null when there is
## nothing to shed (steel, or no element).
static func create(at: Vector2, aim: Vector2, radius: float, thickness: float, arc: float, thrust: bool, inner: float, duration: float, delay: float, element: VfxElementDef, second: VfxElementDef = null) -> SwingMatter:
	if not sheds(element) and not sheds(second):
		return null
	var matter := SwingMatter.new()
	matter.position = PixelDraw.snap(at)
	var edge_length := (radius - inner) if thrust else arc * radius
	var count := clampi(roundi(edge_length / 60.0 * PER_60), 3, MOST)
	if Settings.fewer_effects:
		count = maxi(2, int(count / 2.0))
	if sheds(element):
		for i in count:
			matter._add(element, aim, radius, thickness, arc, thrust, inner, duration, delay, i, count)
	if sheds(second):
		var extra := maxi(1, int(count / float(PER_SECOND)))
		for i in extra:
			matter._add(second, aim, radius, thickness, arc, thrust, inner, duration, delay, i, extra)
	var emissive := (element != null and element.emissive) or (second != null and second.emissive)
	matter.material = FxLook.sprite(emissive)
	return matter


## Whether `element` sheds bits off a blow (any element but steel).
static func sheds(element: VfxElementDef) -> bool:
	return element != null and element.id != &"physical"


func _add(element: VfxElementDef, aim: Vector2, radius: float, thickness: float, arc: float, thrust: bool, inner: float, duration: float, delay: float, index: int, count: int) -> void:
	# Where along the blow (0 tail .. 1 head), spread evenly with a little jitter, and when the
	# head passes there (the head moves as 1 - (1 - t)^3).
	var u := clampf((index + randf_range(0.15, 0.85)) / count, 0.0, 1.0)
	var born := delay + duration * (1.0 - pow(1.0 - u, 1.0 / 3.0))
	var from: Vector2
	var out: Vector2  # away from the blow
	if thrust:
		var side := 1.0 if randf() < 0.5 else -1.0
		out = aim.orthogonal() * side
		from = aim * lerpf(inner, radius, u) + out * randf_range(0.0, thickness * 0.4)
	else:
		var angle := aim.angle() - arc * 0.5 + arc * u
		out = Vector2.from_angle(angle)
		from = out * (radius - randf() * thickness * 0.5)
	var bit := {
		"element": element, "from": from, "born": born, "life": _life_of(element, index),
		"size": 1, "velocity": Vector2.ZERO, "gravity": 0.0, "shape": element.bit, "phase": randf() * TAU,
	}
	match element.motion:
		VfxElementDef.Motion.RISE:
			# Embers and licks going up, swaying; the first few are licks (bigger, shorter).
			bit.velocity = out * randf_range(4.0, 14.0) + Vector2(randf_range(-8.0, 8.0), -randf_range(40.0, 75.0))
			bit.size = 2 if index % 3 == 0 else 1
		VfxElementDef.Motion.FALL:
			if element.bit == VfxElementDef.Bit.DROP:
				# Drops flung on arcs (blood, water).
				bit.velocity = out * randf_range(40.0, 80.0) + Vector2(0, -randf_range(20.0, 45.0))
				bit.gravity = 320.0
			elif element.bit == VfxElementDef.Bit.GLINT:
				bit.velocity = out * randf_range(4.0, 10.0) + Vector2(0, randf_range(8.0, 18.0))  # light drifting down
			else:
				bit.velocity = out * randf_range(10.0, 30.0) + Vector2(0, -randf_range(0.0, 20.0))
				bit.gravity = 240.0  # chips, chunks
			bit.size = 2 if index % 4 == 0 else 1
		VfxElementDef.Motion.SINK:
			# Poison: every other one a drip falling, the rest bubbles welling out and sinking.
			if index % 2 == 0:
				bit.shape = VfxElementDef.Bit.DROP
				bit.velocity = Vector2(0, randf_range(10.0, 25.0))
				bit.gravity = 160.0
			else:
				bit.velocity = out * randf_range(10.0, 22.0)
				bit.gravity = 30.0
				bit.size = 1 + index % 2
		VfxElementDef.Motion.OUTWARD:
			bit.velocity = out * randf_range(70.0, 120.0)  # forks jumping off
			bit.size = 2 if index % 2 == 0 else 1
		VfxElementDef.Motion.CONVERGE:
			bit.velocity = -out * randf_range(20.0, 40.0)  # drawn back in toward the wielder
			bit.size = 2 if index % 3 == 0 else 1
		VfxElementDef.Motion.ORBIT:
			bit.velocity = out * randf_range(6.0, 14.0)  # a slow drift, the orbit is drawn
			bit.size = 2 if index % 3 == 0 else 1
		_:
			bit.velocity = out * randf_range(4.0, 10.0)
	_bits.append(bit)
	_life = maxf(_life, born + bit.life)


## Fire's licks are short and its embers long; storm's forks are a blink.
static func _life_of(element: VfxElementDef, index: int) -> float:
	match element.motion:
		VfxElementDef.Motion.RISE:
			return 0.22 if index % 3 == 0 else randf_range(0.38, 0.5)
		VfxElementDef.Motion.OUTWARD:
			return randf_range(0.12, 0.2)
		VfxElementDef.Motion.SINK:
			return randf_range(0.35, 0.5)
	return randf_range(0.3, 0.42)


## The bits on show (the tests count them).
func bit_count(of_element: VfxElementDef = null) -> int:
	if of_element == null:
		return _bits.size()
	return _bits.filter(func(b: Dictionary) -> bool: return b.element == of_element).size()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for bit in _bits:
		var age: float = _age - bit.born
		var life: float = bit.life
		if age < 0.0 or age >= life:
			continue
		var t := age / life
		var element: VfxElementDef = bit.element
		var velocity: Vector2 = bit.velocity
		var at: Vector2 = bit.from + velocity * age + Vector2(0, 0.5 * bit.gravity * age * age)
		var direction := velocity + Vector2(0, bit.gravity * age)
		if element.motion == VfxElementDef.Motion.RISE:
			at.x += sin(bit.phase + age * 18.0) * 2.0  # embers sway
			direction = Vector2.UP
		elif element.motion == VfxElementDef.Motion.ORBIT:
			at += Vector2.from_angle(bit.phase + age * 14.0) * 4.0  # runes turn
		# Born bright, down the ramp, dithered out in the last third (whole pixels only).
		if not PixelDraw.dither(PixelDraw.cell_of(at), clampf((1.0 - t) * 3.0, 0.0, 1.0)):
			continue
		# Storm's forks flicker: a frame off now and then.
		if element.bit == VfxElementDef.Bit.FORK and int(age * 30.0) % 3 == 2:
			continue
		var size: int = bit.size if t < 0.6 else 1
		if bit.shape == VfxElementDef.Bit.TEARDROP:
			size = 1  # a lick: two pixels up (a bigger teardrop is a plus: holy's glint)
		var color := element.shade(0.15 + t * 0.85)
		var heart := element.core() if t < 0.25 and size > 1 else Color.TRANSPARENT
		PixelDraw.bit(self, bit.shape, at, size, color, direction if direction != Vector2.ZERO else Vector2.UP, heart)
