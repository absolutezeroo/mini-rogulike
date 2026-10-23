class_name SwingVfx
extends Node2D
## A blade's blow (see swing.gdshader): a crescent sweeping the weapon's arc at its reach, a
## spin all around, or a streak for thrusts. Quick, then it dissolves. Its colors are the steps
## of the blow's element (steel, `physical`, for a plain blade); an enemy's carries a warning
## rim (docs/vfx.md: the danger language). The node is never turned: the shader turns the shape
## and keeps its pixels on the world's grid.
##
## An element's blow is made of it, not tinted (docs/vfx.md, "Elemental attacks"): the shader
## breaks its edge into the element's matter (`matter_of`: flame tongues, ice crystals, drips,
## a fork of lightning...) and a SwingMatter beside it sheds the element's bits as the head
## passes (and a few of a `second` element the weapon carries).

const SHADER := preload("res://assets/shaders/swing.gdshader")
const FADE_TIME := 0.09
## A thrust's streak starts this far out, at the hand: never across the wielder's own body.
const THRUST_START := 12.0
## The warning rim of an enemy's blow (the telegraphs' red).
const DANGER := Color(1.0, 0.3, 0.24)

var _duration := 0.12
var _delay := 0.0
var _age := 0.0
var _extent := 40.0
var _look: ShaderMaterial
## Its element (steel for a plain blade) and what it sheds (null: nothing).
var element: VfxElementDef
var matter: SwingMatter


## At `at`, toward `aim`. `reach` in world units from the center, `arc_degrees` of the swing
## (thrust: a streak instead), in `look_element`'s ramp (steel when null); `danger` for an enemy's.
static func create(at: Vector2, aim: Vector2, reach: float, arc_degrees: float, thrust: bool, look_element: VfxElementDef, duration: float, danger: bool = false, second: VfxElementDef = null) -> SwingVfx:
	var look := SlashDef.new()
	look.shape = SlashDef.Shape.THRUST if thrust else SlashDef.Shape.CRESCENT
	look.arc_degrees = clampf(arc_degrees, 60.0, 340.0)
	look.thickness = clampf(reach * (0.35 if thrust else 0.5), 8.0, 26.0)
	look.trail = 0.9 if thrust else 0.75
	look.duration = clampf(duration, 0.07, 0.2)
	return SwingVfx._make(look, at, aim, reach, look_element, danger, 0, second)


## The blow `look` (SlashDef) at `at` toward `aim`, its edge at `reach` (times its
## `reach_scale`), spawned into `world`: one node per stroke, plus its finisher. `second`: a
## second element the weapon carries (a few bits of it). `steady`: the blow is struck in the
## body's four directions (Blow), so a thrust's jitter moves it sideways instead of turning it
## off the cardinal (a flurry's stabs stay straight, never twice in the same place).
static func slash(world: World, look: SlashDef, at: Vector2, aim: Vector2, reach: float, look_element: VfxElementDef = null, danger: bool = false, second: VfxElementDef = null, steady: bool = false) -> void:
	if look.jitter_degrees > 0.0:
		var turn := deg_to_rad(randf_range(-look.jitter_degrees, look.jitter_degrees))
		if steady and look.shape == SlashDef.Shape.THRUST:
			at += aim.normalized().orthogonal() * sin(turn) * reach * look.reach_scale * 0.5
		else:
			aim = aim.rotated(turn)
	for stroke in look.strokes:
		world.spawn_vfx(SwingVfx._make(look, at, aim, reach, look_element, danger, stroke, second if stroke == 0 else null))
	if look.finisher:
		var end := at + aim.normalized() * reach * look.reach_scale * (1.0 if look.shape == SlashDef.Shape.THRUST else 0.7)
		world.spawn_vfx(SheetVfx.play(look.finisher, end, aim, SwingVfx._element_or_steel(look_element)))


static func _make(look: SlashDef, at: Vector2, aim: Vector2, reach: float, look_element: VfxElementDef, danger: bool, stroke: int, second: VfxElementDef = null) -> SwingVfx:
	var vfx := SwingVfx.new()
	vfx.position = PixelDraw.snap(at)
	# A blade's arc, at the blow's height, over the bodies. The hero's toward the north (we see
	# his back) sorts with the bodies from its middle, just above his feet: behind him, over
	# whoever stands further north (docs/vfx.md 2b: his own effects never hide him).
	var behind := not danger and look.shape != SlashDef.Shape.SPIN and VfxLayer.goes_behind(aim)
	VfxLayer.apply(vfx, VfxLayer.Layer.STANDING if behind else VfxLayer.Layer.AIR)
	vfx._duration = maxf(look.duration, 0.05)
	vfx._delay = stroke * look.duration * 0.35
	# A second stroke runs inside the first, a little thinner.
	var edge := maxf(reach * look.reach_scale - stroke * look.thickness * 0.8, 8.0)
	var thickness := look.thickness * (1.0 - stroke * 0.2)
	vfx._extent = edge + 16.0  # room for the matter off its edge (tongues, crystals, drips)
	var shader_look := ShaderMaterial.new()
	shader_look.shader = SHADER
	shader_look.set_shader_parameter("radius", edge)
	shader_look.set_shader_parameter("thickness", thickness)
	shader_look.set_shader_parameter("aim", aim.angle())
	shader_look.set_shader_parameter("mode", 1 if look.shape == SlashDef.Shape.THRUST else 0)
	shader_look.set_shader_parameter("inner", minf(THRUST_START, edge * 0.4) if look.shape == SlashDef.Shape.THRUST else 0.0)
	shader_look.set_shader_parameter("trail", look.trail)
	var arc := look.arc_degrees
	if look.shape == SlashDef.Shape.SPIN:
		arc = maxf(arc, 360.0)
	shader_look.set_shader_parameter("arc", deg_to_rad(arc))
	var ramp := SwingVfx._element_or_steel(look_element)
	shader_look.set_shader_parameter("core", ramp.shade(0.0))
	shader_look.set_shader_parameter("light", ramp.shade(0.34))
	shader_look.set_shader_parameter("body", ramp.shade(0.67))
	shader_look.set_shader_parameter("edge", ramp.shade(1.0))
	shader_look.set_shader_parameter("danger", DANGER if danger else Color.TRANSPARENT)
	shader_look.set_shader_parameter("progress", 0.0)
	shader_look.set_shader_parameter("matter", SwingVfx.matter_of(look_element))
	shader_look.set_shader_parameter("seed", randf() * 64.0)
	shader_look.set_shader_parameter("emissive", ramp.emissive)
	vfx.element = ramp
	if behind and stroke == 0:
		# Behind him it is under the floor's light: a shining element lights itself (fire keeps
		# its yellows, frost its cyan), steel takes the room's light like his body.
		VfxLayer.light_up(vfx, look_element, edge)
	vfx._look = shader_look
	vfx.material = shader_look
	vfx.visible = vfx._delay <= 0.0
	# What it sheds (the first stroke only: a second one runs inside it).
	if stroke == 0:
		var thrust := look.shape == SlashDef.Shape.THRUST
		var inner := minf(THRUST_START, edge * 0.4) if thrust else 0.0
		vfx.matter = SwingMatter.create(vfx.position, aim, edge, thickness, deg_to_rad(arc), thrust, inner, vfx._duration, vfx._delay, look_element, second)
		if vfx.matter:
			VfxLayer.apply(vfx.matter, VfxLayer.of(vfx))
	return vfx


## The matter the shader breaks an element's edge into (swing.gdshader `matter`), from the
## shape of its bits, so a new element looks like itself for free: 0 steel (and no element).
static func matter_of(look_element: VfxElementDef) -> int:
	if look_element == null or look_element.id == &"physical":
		return 0
	match look_element.bit:
		VfxElementDef.Bit.TEARDROP:
			return 1  # fire: flame tongues
		VfxElementDef.Bit.DIAMOND, VfxElementDef.Bit.SHARD:
			return 2  # frost: ice crystals
		VfxElementDef.Bit.RING:
			return 3  # poison: drips
		VfxElementDef.Bit.FORK:
			return 4  # storm: a fork running through it
		VfxElementDef.Bit.GLINT:
			return 5  # holy: glints and rays
		VfxElementDef.Bit.MOTE:
			return 6  # shadow, spirit: smoke and wisps
		VfxElementDef.Bit.RUNE:
			return 7  # arcane: runes riding it
		VfxElementDef.Bit.DROP:
			return 8  # blood, water: droplets flung off
	return 9  # earth (and other matter): crumbling blocks


## `look_element`, or steel for a plain blade.
static func _element_or_steel(look_element: VfxElementDef) -> VfxElementDef:
	return look_element if look_element else VfxElementDef.named(&"physical")


func _ready() -> void:
	# Its bits are a sibling on the same layer: they outlive the arc.
	if matter and get_parent():
		get_parent().add_child.call_deferred(matter)


func _notification(what: int) -> void:
	# Never shown (freed before it was spawned): its bits go with it.
	if what == NOTIFICATION_PREDELETE and matter and is_instance_valid(matter) and matter.get_parent() == null:
		matter.free()


func _process(delta: float) -> void:
	_age += delta
	_look.set_shader_parameter("time", _age)
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
