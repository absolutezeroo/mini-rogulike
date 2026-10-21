class_name LevelUpVfx
extends Node2D
## A level up's moment in the world: soft rings of golden light widening on the ground around
## the hero, one after another, and a pale column of light rising over him, for about a second
## and a half. Added onto what is under it and drawn over the floor's light, so it shines in the
## dark as in a bright room. It follows him (a child of his) and never stops the fight: the perk
## choice itself waits behind the HUD's perk button.

const LIFETIME := 1.5
const RINGS := 3
## Seconds between two rings.
const RING_GAP := 0.22
## Seconds a ring takes to widen and fade.
const RING_TIME := 0.9
const COLOR := Color(1.0, 0.8, 0.38)

var _age := 0.0


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


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var fade := 1.0 - ease(t, 2.4)
	# The column of light: brightest at the feet, gone at its top, quick to rise.
	var height := 78.0 * ease(minf(t * 3.0, 1.0), 0.3)
	var bands := 8
	for i in bands:
		var band := float(i) / bands
		var width := 26.0 * (1.0 - band * 0.55)
		var rect := Rect2(-width * 0.5, 6.0 - height * (band + 1.0 / bands), width, height / bands + 1.0)
		draw_rect(rect, Color(COLOR, 0.2 * fade * (1.0 - band)))
	# Rings on the ground, one after the other.
	draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.45))
	for i in RINGS:
		var ring_t := (_age - i * RING_GAP) / RING_TIME
		if ring_t <= 0.0 or ring_t >= 1.0:
			continue
		var radius := lerpf(10.0, 58.0, ease(ring_t, 0.4))
		var alpha := 1.0 - ease(ring_t, 1.6)
		draw_circle(Vector2.ZERO, radius, Color(COLOR, 0.14 * alpha))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(COLOR.lightened(0.25), 0.8 * alpha), 3.0)
		draw_arc(Vector2.ZERO, radius - 5.0, 0.0, TAU, 48, Color(COLOR, 0.35 * alpha), 2.0)
