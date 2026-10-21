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

var _extent := 60.0
var _look: ShaderMaterial


func _init() -> void:
	_look = ShaderMaterial.new()
	_look.shader = SHADER
	material = _look
	visible = false


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
## has one, the lanes of its shots, the line of its dash, the circle of its area. Returns false
## (and hides) for a skill with nothing to warn about (a summon, a heal). `position` is moved to
## an area pushed forward along the aim.
func show_skill(skill: SkillDef, angle: float, progress: float, body_radius: float = 0.0) -> bool:
	position = Vector2.ZERO
	if skill.telegraph_radius > 0.0:
		show_shape(Shape.CIRCLE, skill.telegraph_radius, angle, progress)
		return true
	var first: Effect = skill.effects[0] if not skill.effects.is_empty() else null
	if first is ProjectileEffect:
		var shot := first as ProjectileEffect
		var length := minf(shot.max_distance, LANE_LENGTH)
		var aim := angle + deg_to_rad(shot.angle_offset)
		if shot.count <= 1 or shot.spread_degrees <= 0.0:
			show_shape(Shape.LINE, length, aim, progress, 0.0, LANE_WIDTH)
		else:
			show_lanes(length, aim, progress, shot.count, shot.spread_degrees, body_radius)
		return true
	if first is DashStrikeEffect:
		var dash := first as DashStrikeEffect
		show_shape(Shape.LINE, dash.distance, angle, progress, 0.0, maxf(dash.width, LANE_WIDTH))
		return true
	if first is DamageAreaEffect:
		var area := first as DamageAreaEffect
		position = Vector2.from_angle(angle) * area.offset
		show_shape(Shape.CIRCLE, area.radius, angle, progress)
		return true
	visible = false
	return false


func _draw() -> void:
	draw_rect(Rect2(-Vector2.ONE * _extent, Vector2.ONE * _extent * 2.0), Color.WHITE)
