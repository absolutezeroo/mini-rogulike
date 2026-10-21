class_name AbyssDoor
extends Area2D
## The Dawn Breach: the way out of the Deeps (AbyssDef), a doorway torn in the dark with daylight
## behind it, standing upright among the actors. Drawn by hand on the art's grid in the holy
## element's ramp: an arch taller than the hero, its heart near white, the colors stepping down to
## a dark torn rim that crackles a pixel each frame; shafts of light leak from its top, motes of
## light drift down around it, and the daylight spills out of it onto the floor in front (holy's
## language: rays, glints, slow motes). It glows (GlowHalo) and lights the cave around it from far (a
## LightSource), so it can be found in the dark. Emits `reached` when the hero steps into it.

signal reached

## Its size, world units (on the art's grid): the rift stands this tall above its foot.
const HEIGHT := 72.0
const HALF_WIDTH := 16.0
## The crackling rim and the motes, frames per second (hand-animated look).
const FPS := 10.0
const MOTES := 8
## The tear's sideways jag, art pixels per row (fixed: the rift's shape, not its flicker).
const JAG: Array[int] = [0, 1, 1, 0, 0, -1, 0, 0, 1, 0, 0, 0, -1, -1, 0, 0, 1, 1, 0, 0, 0, -1, 0, 0, 0, 1, 0, 0, -1, 0, 0, 0, 1, 1, 0, 0]
## The light it throws: the pale white of daylight, not the Deeps' embers.
const DAYLIGHT := Color(1.0, 0.97, 0.9)

## How bright it lights the floor around it (AbyssDef.door_light).
var light_level := 13

var _time := 0.0
var _frame := -1
var _pool: Node2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitorable = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(HALF_WIDTH * 2.0 + 8.0, 22.0)
	shape.shape = box
	shape.position = Vector2(0, -6)
	add_child(shape)
	body_entered.connect(_on_body_entered)
	# Upright among the actors (sorted by its foot), lit by its own light.
	VfxLayer.apply(self, VfxLayer.Layer.STANDING)
	var holy := VfxElementDef.named(&"holy")
	# Its own light first (daylight white), so the halo adds none of its own.
	var light := LightSource.new()
	light.color = DAYLIGHT
	light.level = light_level
	light.position = Vector2(0, -8)
	add_child(light)
	GlowHalo.attach(self, holy, 18.0, Vector2(0, -HEIGHT * 0.5), GlowHalo.Pulse.BREATHE, light_level)
	# The pool of light at its foot, flat on the floor (under the hero's feet).
	_pool = Pool.new()
	VfxLayer.apply(_pool, VfxLayer.Layer.GROUND)
	add_child(_pool)


func _process(delta: float) -> void:
	_time += delta
	var frame := floori(_time * FPS)
	if frame != _frame:
		_frame = frame
		queue_redraw()
		_pool.queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not (body as Player).is_dead:
		reached.emit()


## A number from 0 to 1 that changes each frame for each row (the edge's crackle), stable within
## a frame.
func _flicker(row: int, salt: int) -> float:
	var h := hash(Vector3i(row, _frame, salt))
	return float(h & 0xffff) / 65535.0


func _draw() -> void:
	var holy := VfxElementDef.named(&"holy")
	var rows := roundi(HEIGHT / PixelDraw.PX)
	var widest := roundi(HALF_WIDTH / PixelDraw.PX)
	var arch := widest  # the top's rows: a round arch
	for row in rows:
		var y := row - rows  # art pixels, the foot at 0
		var half := widest
		if row < arch:
			var up := float(arch - row) - 0.5
			half = maxi(1, roundi(sqrt(maxf(float(widest * widest) - up * up, 0.0))))
		# The torn rim: each side jags on its own (the shape), and crackles (each frame).
		var left := half + JAG[row % JAG.size()] + (1 if _flicker(row, 1) > 0.85 else 0)
		var right := half + JAG[(row + 11) % JAG.size()] + (1 if _flicker(row, 2) > 0.85 else 0)
		for x in range(-left - 1, right + 1):
			var cell := Vector2i(x, y)
			if x == -left - 1 or x == right:
				if _flicker(row * 7 + x, 3) > 0.2:
					PixelDraw.cell(self, cell, holy.edge())
				continue
			var across := absf(x + 0.5) / (left if x < 0 else right)  # 0 in the middle, 1 at the rim
			var step := 0.0
			if across > 0.8:
				step = 0.75
			elif across > 0.6:
				step = 0.5
			elif across > 0.32:
				step = 0.25
			PixelDraw.cell(self, cell, holy.shade(step))
	# Shafts leaking out of its top, coming and going.
	for shaft in 3:
		var x := (shaft - 1) * 3
		var reach := 3 + roundi(_flicker(shaft, 7) * 6.0)
		for i in reach:
			var top := Vector2i(x, -rows - 1 - i)
			if PixelDraw.dither(top, 1.0 - float(i) / reach):
				PixelDraw.cell(self, top, holy.shade(0.25 + 0.5 * float(i) / reach))
	# Motes of light drifting down around it, dithering out near the floor.
	for i in MOTES:
		var speed := 6.0 + (i % 3) * 3.0
		var fall := fmod(_time * speed + i * 37.0, HEIGHT + 12.0)
		var side := (HALF_WIDTH + 5.0 + (i % 4) * 4.0) * (1.0 if i % 2 == 0 else -1.0)
		var at := Vector2(side + sin(_time * 1.3 + i) * 2.0, -HEIGHT - 6.0 + fall)
		if PixelDraw.dither(PixelDraw.cell_of(at), 1.0 - fall / (HEIGHT + 12.0)):
			if i % 3 == 0:
				PixelDraw.bit(self, VfxElementDef.Bit.GLINT, at, 1, holy.core())
			else:
				PixelDraw.pixel(self, at, holy.shade(0.25 + 0.25 * (i % 3)))


## The light it throws on the floor at its foot (flat, under the hero's feet): a dithered oval in
## holy's mid steps and rays fanning out from the rift, breathing slowly.
class Pool extends Node2D:
	func _draw() -> void:
		var holy := VfxElementDef.named(&"holy")
		var door := get_parent() as AbyssDoor
		var time := door._time if door else 0.0
		var beat := 0.08 * sin(time * 2.4)
		# The daylight spilling out of the doorway onto the floor in front of it: rows of light
		# widening as they come out, fading by dithering.
		var rows := 22
		for row in rows:
			var t := float(row) / rows
			var half := HALF_WIDTH / PixelDraw.PX + 1.0 + t * 9.0
			var fade := (0.95 + beat) * (1.0 - t)
			var color := holy.shade(0.25 if t < 0.2 else (0.5 if t < 0.55 else 0.75))
			for x in range(-roundi(half), roundi(half) + 1):
				var cell := Vector2i(x, row)
				var edge_fade := fade * (1.0 - smoothstep(half - 3.0, half + 0.5, absf(x)))
				if PixelDraw.dither(cell, edge_fade):
					PixelDraw.cell(self, cell, color)
