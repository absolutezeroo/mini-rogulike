class_name LootShine
extends Node2D
## What tells loot apart on the floor, by its rarity (RarityLookDef, docs/vfx.md "Rarity and
## runes"): Common lies plain; Magic catches the light (a glint runs over it, ItemPickup); Rare
## pulses gold (a ring breathing out on the floor, a small light); Epic burns (a purple aura on
## the floor, motes rising, a halo, a light, and a short pillar of light seen across the room).
## Each part is a child, on its layer: the floor's parts GROUND, the pillar STANDING (it hides
## and is hidden like a body), the motes AIR. Fewer effects keeps what tells the rarity (the
## pillar, the aura, the ring) and drops the motes, the halo and the pillar's climbing light.

enum Part {
	## A ring pulsing out on the floor every `pulse_every` seconds.
	PULSE,
	## Two stepped ovals breathing under it.
	AURA,
	## The pillar of light standing on it.
	BEAM,
	## Motes rising around it.
	MOTES,
}

## The look of the item's rarity (or, for a rune, of its element: `element` alone).
var look: RarityLookDef
var element: VfxElementDef
var part := Part.PULSE
var _clock := 0.0
var _frame := -1
var _motes: Array[Vector3] = []  # x, y (art pixels), age 0..1
var _seed := 0.0


## Adds `look`'s parts to `pickup` (none for Common). `icon_at` is the icon's middle.
static func dress(pickup: Node2D, rarity_look: RarityLookDef, icon_at: Vector2) -> void:
	if rarity_look == null:
		return
	var fewer := Settings.fewer_effects
	if rarity_look.pulse_every > 0.0:
		_add(pickup, rarity_look, Part.PULSE, VfxLayer.Layer.GROUND)
	if rarity_look.aura:
		_add(pickup, rarity_look, Part.AURA, VfxLayer.Layer.GROUND)
	if rarity_look.pillar > 0:
		_add(pickup, rarity_look, Part.BEAM, VfxLayer.Layer.STANDING).show_behind_parent = true
	if rarity_look.motes > 0 and not fewer:
		_add(pickup, rarity_look, Part.MOTES, VfxLayer.Layer.AIR)
	if rarity_look.halo and not fewer:
		var halo := GlowHalo.attach(pickup, rarity_look.element, 8.0, icon_at)
		if halo:
			halo.name = "Halo"
	if rarity_look.light_level > 0:
		GlowHalo.light(pickup, rarity_look.color(), rarity_look.light_level)


static func _add(pickup: Node2D, rarity_look: RarityLookDef, which: Part, layer: VfxLayer.Layer) -> LootShine:
	var shine := LootShine.new()
	shine.look = rarity_look
	shine.element = rarity_look.element
	shine.part = which
	shine.name = Part.keys()[which].capitalize()
	shine._seed = randf() * 10.0
	shine._clock = randf() * 2.0
	VfxLayer.apply(shine, layer)
	pickup.add_child(shine)
	return shine


func _process(delta: float) -> void:
	_clock += delta
	# Whole frames at 12 per second: redrawn only when one passes (the hand-animated pace).
	var frame := floori(_clock * 12.0)
	if frame == _frame:
		return
	var steps := frame - _frame if _frame >= 0 else 1
	_frame = frame
	if part == Part.MOTES:
		_move_motes(steps)
	queue_redraw()


func _draw() -> void:
	match part:
		Part.PULSE:
			_draw_pulse()
		Part.AURA:
			_draw_aura()
		Part.BEAM:
			_draw_beam()
		Part.MOTES:
			_draw_motes()


## A ring of its color lying under it, and another running out from it and breaking up, then a
## pause: a pulse of gold on the floor.
func _draw_pulse() -> void:
	var center := Vector2(0, 6)
	# Its color, outlined by its dark edge so it still reads on a bright floor (gold on sand).
	PixelDraw.ring(self, center, 22.0, element.edge(), 1, 1.0, 0.5)
	PixelDraw.ring(self, center, 20.0, element.shade(0.5), 1, 1.0, 0.5)
	var period := maxf(look.pulse_every, 0.5)
	var t := fmod(_clock, period) / 0.6
	if t < 1.0:
		# Solid while it runs (its color, then darker), breaking into pixels at the end.
		var radius := 20.0 + t * 16.0
		PixelDraw.ring(self, center, radius, element.shade(0.25 if t < 0.4 else 0.5), 1, 1.0 if t < 0.7 else (1.0 - t) / 0.3, 0.5)


## A band of its darker step on the floor around it, its edge a step brighter, a checker only on
## its outer rim (a flat stepped glow, never a screen door), breathing by an art pixel.
func _draw_aura() -> void:
	var center := Vector2(0, 6)
	var radius := 20.0 + (2.0 if (_frame / 5) % 2 == 0 else 0.0)
	PixelDraw.ring(self, center, radius, element.shade(0.75), 3, 1.0, 0.5)
	PixelDraw.ring(self, center, radius, element.shade(0.5), 1, 1.0, 0.5)
	PixelDraw.ring(self, center, radius + 2.0, element.shade(0.75), 1, 0.5, 0.5)


## A pillar of light rooted on the item: a near-white core, its color either side, wider at the
## foot; its upper half breaks into dashes further and further apart and thins to the core, so it
## fades without a screen door of dithered pixels; a brighter stretch climbs it now and then.
func _draw_beam() -> void:
	var height := look.pillar
	var climb := -1
	if not Settings.fewer_effects:
		climb = (_frame * 2) % (height + 30)
	for row in height:
		var up := float(row) / height
		if up > 0.45:
			var gap := 6 if up < 0.6 else (4 if up < 0.75 else (3 if up < 0.9 else 2))
			if row % gap == 0:
				continue
		var lit := climb >= 0 and absi(row - climb) <= 1
		var half := 2 if up < 0.12 else (1 if up < 0.75 else 0)
		if lit:
			half = mini(half + 1, 2)
		var y := -6 - row  # art pixels above the item's middle
		for x in range(-half, half + 1):
			var side := absi(x)
			var step := 0.0 if side == 0 else (0.25 if side == 1 else 0.5)
			if lit:
				step = maxf(step - 0.25, 0.0)
			PixelDraw.cell(self, Vector2i(x, y), element.shade(step))


## Motes rising around it, slow, going up the ramp and dithering out.
func _move_motes(steps: int) -> void:
	for i in _motes.size():
		var m := _motes[i]
		m.y -= steps * 0.5
		m.z += steps / 20.0
		if (_frame + i) % 6 == 0:
			m.x += 1.0 if sin(_seed + i + _frame * 0.3) > 0.0 else -1.0
		_motes[i] = m
	_motes = _motes.filter(func(m: Vector3) -> bool: return m.z < 1.0)
	while _motes.size() < look.motes and randf() < 0.3:
		_motes.append(Vector3(randi_range(-6, 6), randi_range(-4, 2), 0.0))


func _draw_motes() -> void:
	for m in _motes:
		var cell := Vector2i(floori(m.x), floori(m.y))
		if m.z > 0.7 and not PixelDraw.dither(cell, (1.0 - m.z) / 0.3):
			continue
		PixelDraw.bit(self, element.bit, Vector2(cell) * PixelDraw.PX, 1, element.shade(0.1 + m.z * 0.6), Vector2.UP)
