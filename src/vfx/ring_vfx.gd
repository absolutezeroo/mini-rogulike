class_name RingVfx
extends Node2D
## An expanding ring on the art's grid: warnings, waves, pulses. A stepped ring of whole art
## pixels in the element's ramp (bright while it opens, then its darker steps), with a few of
## the element's bits on its rim, dithering away instead of fading. No smooth circle, no
## translucent fill (docs/vfx.md). A plain color makes a plain ring (warnings).

const LIFETIME := 0.36

var element: VfxElementDef
var _radius := 40.0
var _age := 0.0
## The ring's own color (warnings) when it has no element.
var _plain := false
var _rim: Array[float] = []  # angles of the bits on the rim


static func create(at: Vector2, radius: float, color: Color, of_element: VfxElementDef = null) -> RingVfx:
	var vfx := RingVfx.new()
	vfx.position = PixelDraw.snap(at)
	vfx._radius = radius
	vfx._plain = of_element == null
	vfx.element = VfxElementDef.or_color(of_element, color)
	VfxLayer.apply(vfx, VfxLayer.Layer.GROUND)  # a ring on the floor, under whoever stands in it
	if of_element:
		for i in clampi(roundi(radius / 14.0), 4, 14):
			vfx._rim.append(TAU * i / clampi(roundi(radius / 14.0), 4, 14) + randf_range(-0.2, 0.2))
	return vfx


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	# Opens fast (most of it in the first quarter), then thins and dithers out.
	var radius := _radius * lerpf(0.35, 1.0, 1.0 - pow(1.0 - minf(t * 2.2, 1.0), 3.0))
	var fade := 1.0 - maxf(t - 0.4, 0.0) / 0.6
	var thick := 2 if t < 0.5 else 1
	PixelDraw.ring(self, Vector2.ZERO, radius + PixelDraw.PX, element.edge(), 1, fade)
	PixelDraw.ring(self, Vector2.ZERO, radius, element.shade(0.0 if t < 0.12 else 0.35 + t * 0.4), thick, fade)
	for angle in _rim:
		var at := Vector2.from_angle(angle) * radius
		if PixelDraw.dither(PixelDraw.cell_of(at), fade):
			PixelDraw.bit(self, element.bit, at, 2 if t < 0.5 else 1, element.shade(0.3 + t * 0.6), Vector2.from_angle(angle), element.core() if t < 0.3 else Color.TRANSPARENT)
