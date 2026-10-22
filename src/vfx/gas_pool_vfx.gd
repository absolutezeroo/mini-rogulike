class_name GasPoolVfx
extends Node2D
## A nova of an element that lies on the ground as one pool of its matter (VfxElementDef.pool:
## poison's gas: Spore Cloud, Toxic Bloom, a Venomous burst), rather than a ring of pieces that
## read as lumps, or bushes on grass. gas_pool.gdshader draws it on the world's grid: it wells
## out to `radius` in the first eighth of its life, its rim where the area ends, lies churning,
## then sinks and thins away; bubbles of the element (`pool_bubble`) swell and pop in it. On the
## ground (VfxLayer.GROUND): under every actor, never over the hero's feet (docs/vfx.md 2b).

const SHADER := preload("res://assets/shaders/gas_pool.gdshader")
## Seconds it lies there: wells out, churns, sinks (a little longer for a wide one).
const LIFE := Vector2(0.85, 1.2)
## One bubble per this many world units of radius (at least 2, at most 10).
const BUBBLE_EVERY := 12.0

var element: VfxElementDef
var radius := 40.0
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
	var extent := radius + PixelDraw.PX * 2.0
	draw_rect(Rect2(-Vector2.ONE * extent, Vector2.ONE * extent * 2.0), Color.WHITE)


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
