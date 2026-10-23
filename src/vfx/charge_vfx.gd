class_name ChargeVfx
extends Node2D
## The hero's charge on show (Player.charge), in the charged attack's element (steel for a plain
## blade, frost for the Frost Staff...), on the art's grid (docs/vfx.md):
##
## - a gauge on the ground around his feet (GROUND, under every body): a flat ring of twelve
##   steps lighting up one after the other as the charge fills, a dark track for the rest; full,
##   it flashes in the element's core for three frames, then beats (whole steps, under three
##   times a second) until the button is let go;
## - his weapon's glow in hand: motes of the element drawn into the weapon, a core growing at
##   the hand, full a bright core that beats with the gauge. On his body (VfxLayer.on_body):
##   behind it when he faces north, in front when he faces us; small, at the hand, never over
##   his body.
##
## Let go (or cancelled), it dithers away in a few frames. Asleep while there is no charge.

## The gauge's radius around the feet (flattened on the floor), in world units.
const RING_RADIUS := 18.0
## Steps of the gauge.
const STEPS := 12
## The full flash: three frames.
const FLASH_TIME := 0.05
## Beats a second once full (under three flashes a second, docs/vfx.md 2).
const BEAT := 2.5
## Seconds it takes to dither away when the charge ends.
const FADE_TIME := 0.15
const MOTES := 5
## The weapon's glow: this far beyond the hand along the aim (the weapon's head).
const GLOW_REACH := 4.0

var player: Player
var _ring: Node2D
var _ratio := 0.0
var _full := false
var _full_time := 0.0
var _fade := 0.0
var _time := 0.0
var _element: VfxElementDef


static func attach(hero: Player) -> ChargeVfx:
	var vfx := ChargeVfx.new()
	vfx.player = hero
	VfxLayer.on_body(hero, vfx, false)
	return vfx


func _ready() -> void:
	_ring = Node2D.new()
	VfxLayer.apply(_ring, VfxLayer.Layer.GROUND)
	_ring.draw.connect(_draw_gauge)
	add_child(_ring)
	visible = false


func _process(delta: float) -> void:
	if not Vfx.shown:
		return  # a simulation: nothing to see (Vfx.shown)
	if player == null or not is_instance_valid(player):
		return
	_time += delta
	var charge := player.charge
	var weapon := player.get_weapon()
	if charge.is_charging() and weapon and weapon.charged and not player.is_dead:
		_element = weapon.charged.element_for(weapon)
		_ratio = charge.ratio
		_full = charge.is_full()
		_full_time = charge.full_time
		_fade = 1.0
		visible = true
	elif visible:
		_fade -= delta / FADE_TIME
		if _fade <= 0.0:
			visible = false
			return
	else:
		return
	# The glow is on the weapon: behind his body when he faces north, in front otherwise.
	VfxLayer.set_behind(self, VfxLayer.goes_behind(_hand_aim()))
	queue_redraw()
	_ring.queue_redraw()


## Where the glow sits: on a blade held in the body's pose (the nearest of the four directions,
## like the blow it will unleash: Blow), where the shot will leave the hand for a ranged weapon
## (shots fly at the exact aim).
func _hand_aim() -> Vector2:
	var aim := player.facing if player.facing != Vector2.ZERO else Vector2.DOWN
	return Blow.of_weapon(player.global_position, aim, player.get_weapon()).facing


## Whether the gauge is on screen (the tests read it).
func is_showing() -> bool:
	return visible and _fade > 0.0


## The step of the gauge lit last (0..STEPS).
func lit_steps() -> int:
	return STEPS if _full else floori(_ratio * STEPS)


func _beat_on() -> bool:
	return _full and fmod(_full_time * BEAT, 1.0) < 0.5


func _draw_gauge() -> void:
	if _element == null:
		return
	var feet := Vector2(0, player._feet_y())
	var cells := int(TAU * RING_RADIUS / PixelDraw.PX)
	var lit := lit_steps()
	var flash := _full and _full_time < FLASH_TIME
	for i in cells:
		var turn := float(i) / cells  # 0 at the top, clockwise
		var step := floori(turn * STEPS)
		# A gap of one art pixel between the steps, so they read as steps.
		if floori((float(i) + 1.0) / cells * STEPS) != step:
			continue
		var at := feet + Vector2(sin(turn * TAU), -cos(turn * TAU) * 0.5) * RING_RADIUS
		var cell := PixelDraw.cell_of(at)
		if not PixelDraw.dither(cell, _fade):
			continue
		var color: Color
		if flash:
			color = _element.core()
		elif step < lit:
			color = _element.core() if _beat_on() else _element.shade(0.25 if step == lit - 1 else 0.5)
		else:
			if not PixelDraw.dither(cell, 0.5):
				continue  # the dark track: half its pixels
			color = _element.edge()
		if flash or step < lit:
			# A lit step sits on a pixel of the element's dark edge: it reads on a bright floor
			# (steel's pale grey on the garden's grass, gold on the desert's sand).
			PixelDraw.cell(_ring, cell + Vector2i(0, 1), _element.edge())
		PixelDraw.cell(_ring, cell, color)


func _draw() -> void:
	if _element == null:
		return
	var aim := _hand_aim()
	var hand := player.hand_point(aim) - player.global_position + aim * GLOW_REACH
	# Motes of the element drawn into the weapon, closer and brighter as they come.
	for i in MOTES:
		var phase := fmod(_time * 1.6 + float(i) / MOTES, 1.0)
		var angle := TAU * i / MOTES + _time * 0.8
		var at := hand + Vector2.from_angle(angle) * lerpf(16.0, 3.0, phase)
		if not PixelDraw.dither(PixelDraw.cell_of(at), _fade * (0.4 + phase * 0.6)):
			continue
		PixelDraw.bit(self, _element.bit, at, 1, _element.shade(0.75 - phase * 0.5), at.direction_to(hand))
	# The core at the hand: a pixel, two as it fills, the element's core and a rim once full.
	if not PixelDraw.dither(PixelDraw.cell_of(hand), _fade):
		return
	if _full:
		var bright := _full_time < FLASH_TIME or _beat_on()
		PixelDraw.bit(self, _element.bit, hand, 2, _element.core() if bright else _element.shade(0.25), aim, _element.core())
		if bright:
			PixelDraw.ring(self, hand, PixelDraw.PX * 3.0, _element.shade(0.5), 1, _fade)
	else:
		PixelDraw.bit(self, _element.bit, hand, 2 if _ratio >= 0.5 else 1, _element.shade(0.5 - _ratio * 0.25), aim)
