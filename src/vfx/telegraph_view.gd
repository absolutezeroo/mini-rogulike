class_name TelegraphView
extends Node2D
## Draws a monster's attack warning with telegraph.gdshader: an area, a cone, a line, or the
## lanes of a fan or a ring of shots, filling up as the attack comes. Hidden when there is
## nothing to warn about. Never turned: the shader points the shape and keeps its pixels on the
## world's grid.

enum Shape { CIRCLE, CONE, LINE, LANES }

const SHADER := preload("res://assets/shaders/telegraph.gdshader")
## How far the lanes of a ring or fan of shots reach: enough to read the gaps, not the room.
const LANE_LENGTH := 150.0
## Width of a lane (a shot's path, a little wider than the shot).
const LANE_WIDTH := 8.0
## The danger colors every threat on the floor shares (telegraph.gdshader's `color` and its
## edge's light; CellWarning): the red, and the pale red its rim turns as the hit comes.
const DANGER := Color(1.0, 0.22, 0.2)
const DANGER_EDGE := Color(1.0, 0.85, 0.8)

var _extent := 60.0
var _look: ShaderMaterial
## Its red light on the floor: a warning flat under the actors still reads in a dark room.
var _light: LightSource


func _init() -> void:
	_look = ShaderMaterial.new()
	_look.shader = SHADER
	_look.set_shader_parameter("color", DANGER)
	material = _look
	visible = false
	# On the floor, under whoever stands in it (docs/vfx.md, "Layers").
	VfxLayer.apply(self, VfxLayer.Layer.GROUND)


## A red light on the floor while it shows (a monster's warning in the world; the codex's
## preview has no floor light to add to).
func add_light() -> void:
	_light = LightSource.new()
	_light.color = Color(1.0, 0.3, 0.24)
	_light.level = 3
	_light.relative = true
	_light.moves = true
	add_child(_light)


## `angle`: where it points (cones and lines). `progress`: 0 when it starts, 1 when it lands.
func show_shape(shape: Shape, radius: float, angle: float, progress: float, half_angle: float = 0.0, width: float = 10.0) -> void:
	visible = true
	_extent = radius + 4.0
	_look.set_shader_parameter("shape", shape)
	_look.set_shader_parameter("radius", radius)
	_look.set_shader_parameter("aim", angle)
	_look.set_shader_parameter("half_angle", half_angle)
	_look.set_shader_parameter("line_width", width)
	_look.set_shader_parameter("progress", progress)
	queue_redraw()


## The lanes of `lanes` shots fanned over `spread_degrees` (360: a ring) around `angle`,
## starting `inner` out from the caster.
func show_lanes(radius: float, angle: float, progress: float, lanes: int, spread_degrees: float, inner: float = 0.0, width: float = LANE_WIDTH) -> void:
	_look.set_shader_parameter("lanes", maxi(lanes, 1))
	_look.set_shader_parameter("spread", deg_to_rad(spread_degrees) if spread_degrees < 360.0 else TAU)
	_look.set_shader_parameter("inner", inner)
	show_shape(Shape.LANES, radius, angle, progress, 0.0, width)


## The warning of `skill` cast toward `angle` by a body of `body_radius`: its own radius when it
## has one, else what its first effect shows (Effect.show_warning(): the lanes of its shots, the
## line of its dash, the circle of its area). Returns false
## (and hides) for a skill with nothing to warn about (a summon, a heal). `position` is moved to
## an area pushed forward along the aim.
func show_skill(skill: SkillDef, angle: float, progress: float, body_radius: float = 0.0) -> bool:
	position = Vector2.ZERO
	if skill.telegraph_radius > 0.0:
		show_shape(Shape.CIRCLE, skill.telegraph_radius, angle, progress)
		return true
	var first: Effect = skill.effects[0] if not skill.effects.is_empty() else null
	if first and first.show_warning(self, angle, progress, body_radius):
		return true
	visible = false
	return false


func _draw() -> void:
	draw_rect(Rect2(-Vector2.ONE * _extent, Vector2.ONE * _extent * 2.0), Color.WHITE)
