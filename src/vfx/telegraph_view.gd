class_name TelegraphView
extends Node2D
## Draws a monster's attack warning with telegraph.gdshader: an area, a cone or a line, filling
## up as the attack comes. Hidden when there is nothing to warn about.

enum Shape { CIRCLE, CONE, LINE }

const SHADER := preload("res://assets/shaders/telegraph.gdshader")

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
	rotation = angle
	_extent = radius + 4.0
	_look.set_shader_parameter("shape", shape)
	_look.set_shader_parameter("radius", radius)
	_look.set_shader_parameter("half_angle", half_angle)
	_look.set_shader_parameter("line_width", width)
	_look.set_shader_parameter("progress", progress)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-Vector2.ONE * _extent, Vector2.ONE * _extent * 2.0), Color.WHITE)
