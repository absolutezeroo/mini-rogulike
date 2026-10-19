class_name SwingVfx
extends Node2D
## A weapon's swing (see swing.gdshader): a crescent sweeping the weapon's arc at its reach, or
## a streak for thrusts. Quick, then it dissolves.

const SHADER := preload("res://assets/shaders/swing.gdshader")
const FADE_TIME := 0.09

var _duration := 0.12
var _age := 0.0
var _extent := 40.0
var _look: ShaderMaterial


## At `at`, toward `aim`. `reach` in world pixels from the center, `arc_degrees` of the swing
## (thrust: a streak instead), in `color`.
static func create(at: Vector2, aim: Vector2, reach: float, arc_degrees: float, thrust: bool, color: Color, duration: float) -> SwingVfx:
	var vfx := SwingVfx.new()
	vfx.position = at
	vfx.rotation = aim.angle()
	vfx.z_index = 5
	vfx._duration = clampf(duration, 0.07, 0.2)
	vfx._extent = reach + 8.0
	var look := ShaderMaterial.new()
	look.shader = SHADER
	look.set_shader_parameter("radius", reach)
	look.set_shader_parameter("thickness", clampf(reach * (0.35 if thrust else 0.5), 8.0, 26.0))
	look.set_shader_parameter("arc", deg_to_rad(clampf(arc_degrees, 60.0, 340.0)))
	look.set_shader_parameter("mode", 1 if thrust else 0)
	look.set_shader_parameter("trail", 0.9 if thrust else 0.75)
	look.set_shader_parameter("color", color)
	look.set_shader_parameter("core", Color(1, 1, 1, minf(color.a + 0.1, 1.0)))
	vfx._look = look
	vfx.material = look
	return vfx


func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / _duration, 0.0, 1.0)
	_look.set_shader_parameter("progress", 1.0 - pow(1.0 - t, 3.0))  # fast, then easing in
	_look.set_shader_parameter("fade", clampf((_age - _duration) / FADE_TIME, 0.0, 1.0))
	if _age >= _duration + FADE_TIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-Vector2.ONE * _extent, Vector2.ONE * _extent * 2.0), Color.WHITE)
