class_name BeamVfx
extends Node2D
## A beam between two points, in art pixels. Plain (a mender healing an ally...): a thin beam
## of light in the ramp of its color (VfxElementDef.or_color), thinning out and going down the
## ramp, dithering away (never an alpha fade). With an element (chain lightning: storm): a jagged fork
## on the grid that flickers like the storm's sheets: it strikes, goes off but for its
## afterglow, strikes again along a new path, then breaks into segments going down the ramp.

const LIFETIME := 0.35
## Seconds of each phase of a forked beam: strike, off, strike again, then breaking.
const STRIKE := 0.1
const OFF := 0.15
const RESTRIKE := 0.24
## World units between two knees of the fork, and how far a knee may stray from the line.
const KNEE_GAP := 14.0
const KNEE_SPREAD := 7.0

var element: VfxElementDef
var _to := Vector2.ZERO
var _color := Color.WHITE
var _age := 0.0
var _knees := PackedVector2Array()
var _branches: Array[PackedVector2Array] = []
var _strikes := 0


static func create(from: Vector2, to: Vector2, color: Color, of_element: VfxElementDef = null) -> BeamVfx:
	var vfx := BeamVfx.new()
	vfx.position = PixelDraw.snap(from)
	vfx._to = to - vfx.position
	vfx._color = color
	vfx.element = of_element
	vfx.z_index = 6
	VfxLayer.apply(vfx, VfxLayer.Layer.AIR)  # a beam between bodies, at chest height
	var look := CanvasItemMaterial.new()
	look.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	if of_element == null:
		look.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	vfx.material = look
	if of_element:
		vfx._fork()
	return vfx


## A new jagged path from here to the end, and a branch or two off it.
func _fork() -> void:
	_knees.clear()
	_branches.clear()
	var length := _to.length()
	var count := maxi(roundi(length / KNEE_GAP), 1)
	var side := _to.normalized().orthogonal()
	var turn := 1.0 if randf() < 0.5 else -1.0
	_knees.append(Vector2.ZERO)
	for i in range(1, count):
		turn = -turn if randf() < 0.75 else turn
		_knees.append(PixelDraw.snap(_to * (float(i) / count) + side * turn * randf_range(KNEE_SPREAD * 0.35, KNEE_SPREAD)))
	_knees.append(PixelDraw.snap(_to))
	for i in mini(2, _knees.size() - 2):
		var knee := _knees[1 + randi() % (_knees.size() - 2)]
		var out := _to.normalized().rotated(randf_range(0.5, 0.9) * (1.0 if randf() < 0.5 else -1.0)) * randf_range(10.0, 16.0)
		var mid := PixelDraw.snap(knee + out * 0.5 + out.orthogonal() * randf_range(-0.25, 0.25))
		_branches.append(PackedVector2Array([knee, mid, PixelDraw.snap(knee + out)]))


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	# The second strike takes a new path, as lightning does.
	if element and _strikes == 0 and _age >= OFF:
		_strikes = 1
		_fork()
	queue_redraw()


func _draw() -> void:
	if element:
		_draw_fork()
		return
	var t := _age / LIFETIME
	var look := VfxElementDef.or_color(null, _color)
	var color := look.shade(t)  # core first, then down its ramp
	var origin := PixelDraw.cell_of(position)
	var steps := maxi(int(_to.length() / 4.0), 1)
	for i in steps + 1:
		var wobble := Vector2(0, roundf(sin(i * 0.9 + _age * 30.0)) * PixelDraw.PX)
		var at := PixelDraw.snap(_to * float(i) / steps + wobble)
		var size := PixelDraw.PX * (2.0 if t < 0.5 else 1.0)
		var corner := PixelDraw.snap(at - Vector2.ONE * size * 0.5)
		# Whole for its first half, then dithering out.
		if PixelDraw.dither(origin + PixelDraw.cell_of(corner), clampf((1.0 - t) * 2.0, 0.0, 1.0)):
			draw_rect(Rect2(corner, Vector2.ONE * size), color)


func _draw_fork() -> void:
	if _age < STRIKE:
		# The strike: a white channel in a pale glow, its branches, the dark rim around.
		_path(_knees, element.shade(0.75), 3)
		for branch in _branches:
			_path(branch, element.shade(0.5), 1)
		_path(_knees, element.shade(0.25), 2)
		_path(_knees, element.core(), 1)
	elif _age < OFF:
		# Off: only the afterglow of the channel.
		_path(_knees, element.shade(0.75), 1, 0.5)
	elif _age < RESTRIKE:
		# The second strike, thinner, along its new path.
		_path(_knees, element.edge(), 2)
		_path(_knees, element.shade(0.25), 1)
		for branch in _branches.slice(0, 1):
			_path(branch, element.shade(0.5), 1)
	else:
		# Breaking: what is left of it, dithering out down the ramp.
		var t := (_age - RESTRIKE) / (LIFETIME - RESTRIKE)
		_path(_knees, element.shade(0.5 + t * 0.5), 1, 0.7 * (1.0 - t))


func _path(points: PackedVector2Array, color: Color, thickness_px: int, fade: float = 1.0) -> void:
	for i in points.size() - 1:
		PixelDraw.line(self, points[i], points[i + 1], color, thickness_px, fade)
