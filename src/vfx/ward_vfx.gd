class_name WardVfx
extends RefCounted
## The ward round an actor (AllyEffect: damage soaked up before Health), drawn on the canvas it
## is given: the actor's own (Actor._draw()) or, for a monster, its overlay over the body
## (MonsterOverlay). In the spirit element's language, on the art's grid: a hollow shell (a
## sparse dithered inside, a rim that flickers by whole pixels, gaps running around it), a glint
## circling, and small pale flames licking up off its top (docs/vfx.md: no smooth circle, no
## translucent fill).


## A shimmering bubble round a body of `radius`, centred on its feet (the canvas' origin).
static func draw(canvas: CanvasItem, radius: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var spirit := VfxElementDef.named(&"spirit")
	var center := Vector2(0, -radius * 0.7)
	var size := PixelDraw.snap_length(radius + 9.0)
	PixelDraw.disc(canvas, center, size - PixelDraw.PX, spirit.shade(0.75), 0.12)
	# The rim, its gaps turning: a hollow ring, not a solid bubble.
	var cells := int(TAU * size / PixelDraw.PX)
	var turn := int(t * 10.0)
	for i in cells:
		if (i + turn) % 9 < 2:
			continue
		var at := center + Vector2.from_angle(TAU * i / cells) * size
		PixelDraw.pixel(canvas, at - Vector2.ONE, spirit.shade(0.5) if (i + turn) % 9 != 2 else spirit.shade(0.25))
	for i in 3:
		PixelDraw.pixel(canvas, center + Vector2.from_angle(t * 2.5 + i * 0.18) * size - Vector2.ONE, spirit.core())
	# Pale flames licking up off its top, rising and going down the ramp.
	for i in 3:
		var life := fmod(t * 1.6 + i * 0.37, 1.0)
		var x := (i - 1) * size * 0.45 + sin(t * 5.0 + i * 2.0) * PixelDraw.PX
		var top := center + Vector2(x, -sqrt(maxf(size * size - x * x, 0.0)) - life * 10.0)
		PixelDraw.pixel(canvas, top, spirit.shade(0.25 + life * 0.75))
		if life < 0.5:
			PixelDraw.pixel(canvas, top + Vector2(0, PixelDraw.PX), spirit.shade(0.5))
