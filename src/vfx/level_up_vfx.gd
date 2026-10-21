class_name LevelUpVfx
extends Node2D
## A level up's moment in the world: rings of golden light (the holy element's ramp, stepped on
## the art's grid) widening on the ground around the hero, one after another, and a pale column
## of light rising over him in dithered bands, for about a second and a half. Added onto what is
## under it and drawn over the floor's light, so it shines in the dark as in a bright room. It
## follows him (a child of his) and never stops the fight: the perk choice itself waits behind
## the HUD's perk button.

const LIFETIME := 1.5
const RINGS := 3
## Seconds between two rings.
const RING_GAP := 0.22
## Seconds a ring takes to widen and fade.
const RING_TIME := 0.9
## Glints rising through the column.
const GLINTS := 4

var _age := 0.0
## The rings, on the floor under every body (VfxLayer.GROUND); the column stays in the air.
var _rings: Node2D


static func attach(actor: Node2D) -> void:
	var vfx := LevelUpVfx.new()
	actor.add_child(vfx)


func _ready() -> void:
	z_as_relative = false
	z_index = LightField.Z + 1  # light: over the floor's darkness
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = add
	_rings = Node2D.new()
	VfxLayer.apply(_rings, VfxLayer.Layer.GROUND)
	_rings.use_parent_material = true
	_rings.draw.connect(_draw_rings)
	add_child(_rings)
	# Under the floor's light, the rings are lit by a flash of the same gold.
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


func _draw() -> void:
	var holy := VfxElementDef.named(&"holy")
	var t := _age / LIFETIME
	var fade := 1.0 - ease(t, 2.4)
	# The column of light: densest at the feet, gone at its top, quick to rise; the ramp's
	# darker steps (it is added onto the picture), dithered on the art's grid.
	var height := 78.0 * ease(minf(t * 3.0, 1.0), 0.3)
	var bands := 8
	for i in bands:
		var band := float(i) / bands
		var half := PixelDraw.snap_length(13.0 * (1.0 - band * 0.55))
		var top := PixelDraw.snap(Vector2(0, 6.0 - height * (band + 1.0 / bands))).y
		var rows := maxi(roundi(height / bands / PixelDraw.PX), 1)
		for row in rows:
			for x in range(-roundi(half / PixelDraw.PX), roundi(half / PixelDraw.PX)):
				var cell := Vector2i(x, roundi(top / PixelDraw.PX) + row)
				if PixelDraw.dither(cell, 0.5 * fade * (1.0 - band)):
					PixelDraw.cell(self, cell, holy.shade(0.75))
	# Holy's 4-point glints rising through the column, one after the other.
	for i in GLINTS:
		var glint_t := (_age - i * 0.12) / 0.7
		if glint_t <= 0.0 or glint_t >= 1.0:
			continue
		var at := Vector2((-8.0 if i % 2 == 0 else 7.0) + i * 2.0 - 4.0, -6.0 - 60.0 * glint_t)
		var size := 2 if glint_t < 0.5 else 1
		PixelDraw.bit(self, VfxElementDef.Bit.GLINT, at, size, holy.shade(0.25 + glint_t * 0.5), Vector2.UP, holy.core() if glint_t < 0.4 else Color.TRANSPARENT)


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
