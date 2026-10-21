class_name SwingVfx
extends Node2D
## A blade's blow (see swing.gdshader): a crescent sweeping the weapon's arc at its reach, a
## spin all around, or a streak for thrusts. Quick, then it dissolves. Its colors are the steps
## of the blow's element (steel, `physical`, for a plain blade); an enemy's carries a warning
## rim (docs/vfx.md: the danger language). The node is never turned: the shader turns the shape
## and keeps its pixels on the world's grid.

const SHADER := preload("res://assets/shaders/swing.gdshader")
const FADE_TIME := 0.09
## The warning rim of an enemy's blow (the telegraphs' red).
const DANGER := Color(1.0, 0.3, 0.24)

var _duration := 0.12
var _delay := 0.0
var _age := 0.0
var _extent := 40.0
var _look: ShaderMaterial


## At `at`, toward `aim`. `reach` in world units from the center, `arc_degrees` of the swing
## (thrust: a streak instead), in `element`'s ramp (steel when null); `danger` for an enemy's.
static func create(at: Vector2, aim: Vector2, reach: float, arc_degrees: float, thrust: bool, element: VfxElementDef, duration: float, danger: bool = false) -> SwingVfx:
	var look := SlashDef.new()
	look.shape = SlashDef.Shape.THRUST if thrust else SlashDef.Shape.CRESCENT
	look.arc_degrees = clampf(arc_degrees, 60.0, 340.0)
	look.thickness = clampf(reach * (0.35 if thrust else 0.5), 8.0, 26.0)
	look.trail = 0.9 if thrust else 0.75
	look.duration = clampf(duration, 0.07, 0.2)
	return SwingVfx._make(look, at, aim, reach, element, danger, 0)


## The blow `look` (SlashDef) at `at` toward `aim`, its edge at `reach` (times its
## `reach_scale`), spawned into `world`: one node per stroke, plus its finisher.
static func slash(world: World, look: SlashDef, at: Vector2, aim: Vector2, reach: float, element: VfxElementDef = null, danger: bool = false) -> void:
	if look.jitter_degrees > 0.0:
		aim = aim.rotated(deg_to_rad(randf_range(-look.jitter_degrees, look.jitter_degrees)))
	for stroke in look.strokes:
		world.spawn_vfx(SwingVfx._make(look, at, aim, reach, element, danger, stroke))
	if look.finisher:
		var end := at + aim.normalized() * reach * look.reach_scale * (1.0 if look.shape == SlashDef.Shape.THRUST else 0.7)
		world.spawn_vfx(SheetVfx.play(look.finisher, end, aim, SwingVfx._element_or_steel(element)))


static func _make(look: SlashDef, at: Vector2, aim: Vector2, reach: float, element: VfxElementDef, danger: bool, stroke: int) -> SwingVfx:
	var vfx := SwingVfx.new()
	vfx.position = PixelDraw.snap(at)
	VfxLayer.apply(vfx, VfxLayer.Layer.AIR)  # a blade's arc, at the blow's height
	vfx._duration = maxf(look.duration, 0.05)
	vfx._delay = stroke * look.duration * 0.35
	# A second stroke runs inside the first, a little thinner.
	var edge := maxf(reach * look.reach_scale - stroke * look.thickness * 0.8, 8.0)
	var thickness := look.thickness * (1.0 - stroke * 0.2)
	vfx._extent = edge + 8.0
	var shader_look := ShaderMaterial.new()
	shader_look.shader = SHADER
	shader_look.set_shader_parameter("radius", edge)
	shader_look.set_shader_parameter("thickness", thickness)
	shader_look.set_shader_parameter("aim", aim.angle())
	shader_look.set_shader_parameter("mode", 1 if look.shape == SlashDef.Shape.THRUST else 0)
	shader_look.set_shader_parameter("trail", look.trail)
	var arc := look.arc_degrees
	if look.shape == SlashDef.Shape.SPIN:
		arc = maxf(arc, 360.0)
	shader_look.set_shader_parameter("arc", deg_to_rad(arc))
	var ramp := SwingVfx._element_or_steel(element)
	shader_look.set_shader_parameter("core", ramp.shade(0.0))
	shader_look.set_shader_parameter("light", ramp.shade(0.34))
	shader_look.set_shader_parameter("body", ramp.shade(0.67))
	shader_look.set_shader_parameter("edge", ramp.shade(1.0))
	shader_look.set_shader_parameter("danger", DANGER if danger else Color.TRANSPARENT)
	shader_look.set_shader_parameter("progress", 0.0)
	vfx._look = shader_look
	vfx.material = shader_look
	vfx.visible = vfx._delay <= 0.0
	return vfx


## `element`, or steel for a plain blade.
static func _element_or_steel(element: VfxElementDef) -> VfxElementDef:
	return element if element else VfxElementDef.named(&"physical")


func _process(delta: float) -> void:
	_age += delta
	var age := _age - _delay
	if age < 0.0:
		return
	visible = true
	var t := clampf(age / _duration, 0.0, 1.0)
	_look.set_shader_parameter("progress", 1.0 - pow(1.0 - t, 3.0))  # fast, then easing in
	_look.set_shader_parameter("fade", clampf((age - _duration) / FADE_TIME, 0.0, 1.0))
	if age >= _duration + FADE_TIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-Vector2.ONE * _extent, Vector2.ONE * _extent * 2.0), Color.WHITE)
