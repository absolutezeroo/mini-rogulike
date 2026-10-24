class_name BodySketch
extends RefCounted
## What an actor draws on its own canvas under its rig (Actor._draw()): its shadow, and a plain
## body when it has no sprite (a disc in its color with a point toward where it faces, and its
## glyph).


## The shadow under the feet (`feet_y` below the actor's origin): a flat oval of art pixels.
static func shadow(canvas: CanvasItem, feet_y: float, radius: float) -> void:
	PixelDraw.disc(canvas, Vector2(0, feet_y - 1.0), radius, Color(0, 0, 0, 0.35), 1.0, 0.4)


## A body with no sprite: a disc of `radius` in `color`, pointing along `facing`, `glyph` on it.
static func draw(canvas: CanvasItem, radius: float, color: Color, facing: Vector2, glyph: String) -> void:
	canvas.draw_circle(Vector2.ZERO, radius, color)
	canvas.draw_circle(Vector2.ZERO, radius, color.darkened(0.4), false, 2.0)
	var tip := facing * (radius + 6.0)
	var side := facing.orthogonal() * 4.0
	canvas.draw_colored_polygon(PackedVector2Array([tip, facing * radius + side, facing * radius - side]), color.lightened(0.3))
	if not glyph.is_empty():
		Fonts.draw(canvas, Vector2(0, 4), glyph, Fonts.BODY, color.darkened(0.7), 0.5, Color.TRANSPARENT)
