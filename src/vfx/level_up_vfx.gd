class_name LevelUpVfx
extends Node2D
## A level up's moment in the world: rings of golden light (the holy element's ramp, stepped on
## the art's grid) widening on the ground around the hero, one after another, and a pale column
## of light standing around him in dithered bands, for about a second and a half. It follows him
## (on his body) and never stops the fight: the perk choice itself waits behind the HUD's perk
## button.
##
## Three layers, so the hero stays in plain sight (docs/vfx.md 2b): the rings lie flat on the
## floor under every body (GROUND); the column stands behind his body (VfxLayer.on_body: its
## middle is hidden by him, its sides and top shine around him); in front only a few glints rise
## at his sides, never over him, and they shine over the floor's light.

const LIFETIME := 1.5
const RINGS := 3
## Seconds between two rings.
const RING_GAP := 0.22
## Seconds a ring takes to widen and fade.
const RING_TIME := 0.9
## Glints rising at the hero's sides, in front of him.
const GLINTS := 4
## How far out to the sides the front glints rise: clear of the hero's body.
const GLINT_SIDE := 20.0

var _age := 0.0
## The rings, on the floor under every body (VfxLayer.GROUND).
var _rings: Node2D
## The glints in front of him, over the floor's light (AIR).
var _glints: Node2D


static func attach(actor: Node2D) -> void:
	VfxLayer.on_body(actor, LevelUpVfx.new(), true)


func _ready() -> void:
	# The column: light added onto what is behind him (it is drawn behind his body).
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = add
	_rings = Node2D.new()
	VfxLayer.apply(_rings, VfxLayer.Layer.GROUND)
	_rings.use_parent_material = true
	_rings.draw.connect(_draw_rings)
	add_child(_rings)
	_glints = Node2D.new()
	VfxLayer.apply(_glints, VfxLayer.Layer.AIR)
	_glints.z_index = LightField.Z + 1  # light: over the floor's darkness
	_glints.use_parent_material = true
	_glints.draw.connect(_draw_glints)
	add_child(_glints)
	# Under the floor's light, the rings and the column are lit by a flash of the same gold.
	var actor := get_parent() as Actor
	if actor and actor.world:
		actor.world.flash_light(actor.global_position, VfxElementDef.named(&"holy").color(), 220.0)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()
	_rings.queue_redraw()
	_glints.queue_redraw()


## The column of light, behind the body: shafts of light one art pixel wide rising from the
## floor around him, each its own height (the middle ones the tallest and brightest), quick to
## rise; light added onto what is behind him in the ramp's darker steps. A shaft is solid at its
## foot and breaks into dashes further and further apart toward its top, and lifts off the
## floor as it dies (a Bayer-dithered column, or whole rows across it, read as a screen door or
## scanlines: docs/vfx.md, section 10's lesson).
const SHAFTS: Array[Vector2i] = [Vector2i(-7, 22), Vector2i(-5, 30), Vector2i(-3, 36), Vector2i(-1, 42), Vector2i(1, 40), Vector2i(3, 34), Vector2i(5, 28), Vector2i(7, 20)]


func _draw() -> void:
	var holy := VfxElementDef.named(&"holy")
	var t := _age / LIFETIME
	var rise := ease(minf(t * 3.0, 1.0), 0.3)
	var dying := clampf((t - 0.4) / 0.6, 0.0, 1.0)
	var foot := roundi(4.0 / PixelDraw.PX)
	for i in SHAFTS.size():
		var shaft := SHAFTS[i]
		var tall := roundi(shaft.y * rise)
		var solid := tall / 3
		var bright := absi(shaft.x) <= 1
		# Dying, it lifts off the floor: its foot climbs up the shaft.
		var row := roundi(tall * dying)
		var gap := 1
		while row < tall:
			PixelDraw.cell(self, Vector2i(shaft.x, foot - row), holy.shade(0.5 if bright and row < solid else 0.75))
			if row >= solid:
				gap += 1  # dashes further and further apart
				row += gap
			else:
				row += 1
	# Holy's 4-point glints rising up the column, seen through it above his head.
	for i in 2:
		var glint_t := (_age - 0.2 - i * 0.25) / 0.8
		if glint_t <= 0.0 or glint_t >= 1.0:
			continue
		var at := Vector2(-4.0 + i * 8.0, -40.0 - 40.0 * glint_t)
		PixelDraw.bit(self, VfxElementDef.Bit.GLINT, at, 1, holy.shade(0.25 + glint_t * 0.5), Vector2.UP)


## In front of him: a few glints rising at his sides, one after the other, clear of his body.
func _draw_glints() -> void:
	var holy := VfxElementDef.named(&"holy")
	for i in GLINTS:
		var glint_t := (_age - i * 0.12) / 0.7
		if glint_t <= 0.0 or glint_t >= 1.0:
			continue
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector2(side * (GLINT_SIDE + (i / 2) * 4.0), -6.0 - 52.0 * glint_t)
		var size := 2 if glint_t < 0.5 else 1
		PixelDraw.bit(_glints, VfxElementDef.Bit.GLINT, at, size, holy.shade(0.25 + glint_t * 0.5), Vector2.UP, holy.core() if glint_t < 0.4 else Color.TRANSPARENT)


## Rings on the ground, one after the other: a bright rim, a dimmer one inside.
func _draw_rings() -> void:
	var holy := VfxElementDef.named(&"holy")
	for i in RINGS:
		var ring_t := (_age - i * RING_GAP) / RING_TIME
		if ring_t <= 0.0 or ring_t >= 1.0:
			continue
		var radius := lerpf(10.0, 58.0, ease(ring_t, 0.4))
		var alpha := 1.0 - ease(ring_t, 1.6)
		PixelDraw.ring(_rings, Vector2(0, 6), radius, holy.shade(0.25 if ring_t < 0.3 else 0.5), 1, alpha, 0.45)
		PixelDraw.ring(_rings, Vector2(0, 6), radius - 5.0, holy.shade(0.75), 1, alpha * 0.6, 0.45)
