class_name GasPoolVfx
extends Node2D
## A nova of an element that lies on the ground as one pool of its matter (VfxElementDef.pool:
## poison's gas: Spore Cloud, Toxic Bloom, a Venomous burst), rather than a ring of pieces that
## read as lumps, or bushes on grass. gas_pool.gdshader draws it on the world's grid: it wells
## out to `radius` in the first eighth of its life, its rim where the area ends, lies churning,
## then sinks and thins away; bubbles of the element (`pool_bubble`) swell and pop in it. On the
## ground (VfxLayer.GROUND): under every actor, never over the hero's feet (docs/vfx.md 2b).
## The same gas lies along a trail (`along_line`: a dash leaving poison behind it) or a sweep
## (`along_arc`: an arc of the area in front), welling out from one end to the other, instead of
## a row of standing lumps (ComposedVfx's pieces, which read as bushes).

const SHADER := preload("res://assets/shaders/gas_pool.gdshader")
## Seconds it lies there: wells out, churns, sinks (a little longer for a wide one).
const LIFE := Vector2(0.85, 1.2)
## One bubble per this many world units of radius (at least 2, at most 10).
const BUBBLE_EVERY := 12.0
## How far a trail's gas reaches either side of its line (a dash's width, give or take).
const TRAIL_REACH := 9.0
## An arc's gas: its spine at this share of the area's radius, reaching this share either side
## (the band ComposedVfx.arc's two rows of pieces covered), over this angle either side of
## facing (radians).
const ARC_SPINE := 0.72
const ARC_REACH := 0.26
const ARC_HALF := deg_to_rad(80.0)

var element: VfxElementDef
## How far the gas reaches: from the centre for a disc, from its line or arc otherwise.
var radius := 40.0
## The quad the shader fills, around the node.
var _extent := Rect2()
var _life := 1.0
var _age := 0.0
var _look: ShaderMaterial
var _bubbles: Node2D
var _spots: Array[Dictionary] = []  # {at, delay}


static func create(at: Vector2, of_radius: float, of_element: VfxElementDef) -> GasPoolVfx:
	var vfx := GasPoolVfx.new()
	vfx.element = of_element
	vfx.radius = maxf(of_radius, 8.0)
	vfx.position = PixelDraw.snap(at)
	vfx._life = clampf(LIFE.x + of_radius / 400.0, LIFE.x, LIFE.y)
	vfx._extent = Rect2(-Vector2.ONE, Vector2.ONE * 2.0).grow(vfx.radius + PixelDraw.PX * 2.0 - 1.0)
	VfxLayer.apply(vfx, VfxLayer.Layer.GROUND)
	var look := ShaderMaterial.new()
	look.shader = SHADER
	look.set_shader_parameter("ramp", FxLook.five(of_element))
	look.set_shader_parameter("residue", of_element.residue if of_element.residue.a > 0.0 else of_element.shade(0.75))
	look.set_shader_parameter("radius", vfx.radius)
	look.set_shader_parameter("seed", randf() * 50.0)
	look.set_shader_parameter("emissive", of_element.emissive)
	vfx._look = look
	vfx.material = look
	VfxLayer.light_up(vfx, of_element, vfx.radius)
	if of_element.pool_bubble and of_element.pool_bubble.texture:
		# Bubbles welling up here and there, early ones first, on a node of their own (drawn
		# plain, over the gas).
		vfx._bubbles = Node2D.new()
		vfx._bubbles.material = FxLook.sprite(of_element.emissive)
		vfx._bubbles.draw.connect(vfx._draw_bubbles)
		vfx.add_child(vfx._bubbles)
		var count := clampi(roundi(vfx.radius / BUBBLE_EVERY), 2, 10)
		for i in count:
			var where := Vector2.from_angle(randf() * TAU) * vfx.radius * sqrt(randf_range(0.04, 0.6))
			vfx._spots.append({ at = PixelDraw.snap(where), delay = randf_range(0.08, vfx._life * 0.5) })
	return vfx


## The gas left along the line from `from` to `to` (a dash through poison), welling out from
## `from` over `duration` seconds.
static func along_line(from: Vector2, to: Vector2, of_element: VfxElementDef, duration: float = 0.15) -> GasPoolVfx:
	var vfx := create((from + to) * 0.5, TRAIL_REACH, of_element)
	var half := PixelDraw.snap((to - from) * 0.5)
	var look := vfx.material as ShaderMaterial
	look.set_shader_parameter("shape", 1)
	look.set_shader_parameter("axis", half)
	vfx._spread(duration)
	vfx._extent = Rect2(-half.abs(), half.abs() * 2.0).grow(vfx.radius + PixelDraw.PX * 2.0)
	vfx._spots.clear()
	for i in clampi(roundi(half.length() * 2.0 / (BUBBLE_EVERY * 2.5)), 1, 8):
		var t := randf()
		var where := -half + half * 2.0 * t + Vector2.from_angle(randf() * TAU) * vfx.radius * 0.4
		vfx._spots.append({ at = PixelDraw.snap(where), delay = duration * t + randf_range(0.08, vfx._life * 0.35) })
	return vfx


## The gas swept across the front of a circle of `of_radius` around `at`, facing `facing` (an
## area struck in front: the arc ComposedVfx.arc lays its pieces on), welling out from one side to
## the other over `sweep` seconds.
static func along_arc(at: Vector2, of_radius: float, facing: Vector2, of_element: VfxElementDef, sweep: float = 0.12) -> GasPoolVfx:
	var vfx := create(at, maxf(of_radius * ARC_REACH, TRAIL_REACH), of_element)
	var spine := of_radius * ARC_SPINE
	var from := facing.angle() - ARC_HALF
	var look := vfx.material as ShaderMaterial
	look.set_shader_parameter("shape", 2)
	look.set_shader_parameter("arc_radius", spine)
	look.set_shader_parameter("arc_from", from)
	look.set_shader_parameter("arc_span", ARC_HALF * 2.0)
	vfx._spread(sweep)
	vfx._extent = Rect2(-Vector2.ONE, Vector2.ONE * 2.0).grow(spine + vfx.radius + PixelDraw.PX * 2.0 - 1.0)
	vfx._spots.clear()
	for i in clampi(roundi(spine * ARC_HALF * 2.0 / (BUBBLE_EVERY * 2.5)), 2, 8):
		var t := randf()
		var where := Vector2.from_angle(from + ARC_HALF * 2.0 * t) * (spine + randf_range(-0.4, 0.4) * vfx.radius)
		vfx._spots.append({ at = PixelDraw.snap(where), delay = sweep * t + randf_range(0.08, vfx._life * 0.35) })
	return vfx


## Its far end wells out `seconds` after its start: that much longer it lies there.
func _spread(seconds: float) -> void:
	_life += seconds
	(material as ShaderMaterial).set_shader_parameter("sweep", clampf(seconds / _life, 0.0, 0.8))


## The share of its life gone (0 .. 1), for the tests.
func progress() -> float:
	return clampf(_age / _life, 0.0, 1.0)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	_look.set_shader_parameter("progress", _age / _life)
	if _bubbles:
		_bubbles.queue_redraw()


func _draw() -> void:
	# The quad the shader fills (it discards outside the pool).
	draw_rect(_extent, Color.WHITE)


func _draw_bubbles() -> void:
	var sheet := element.pool_bubble
	for spot in _spots:
		var local: float = _age - spot.delay
		if local < 0.0:
			continue
		var frame := int(local * sheet.fps)
		if frame >= sheet.frame_count():
			continue
		PixelDraw.sheet(_bubbles, sheet, frame, spot.at, Vector2.RIGHT, element)
