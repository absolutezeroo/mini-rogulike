class_name ShockwaveVfx
extends Node2D
## A ripple running through the picture around a blast (see shockwave.gdshader).

const SHADER := preload("res://assets/shaders/shockwave.gdshader")
const LIFETIME := 0.4

var _reach := 100.0
var _strength := 6.0
var _age := 0.0
var _look: ShaderMaterial


static func create(at: Vector2, reach: float, strength: float = 6.0) -> ShockwaveVfx:
	var vfx := ShockwaveVfx.new()
	vfx.position = at
	vfx.z_index = 20  # over everything on the floor
	vfx._reach = reach
	vfx._strength = strength
	vfx._look = ShaderMaterial.new()
	vfx._look.shader = SHADER
	vfx.material = vfx._look
	return vfx


func _process(delta: float) -> void:
	_age += delta
	var t := _age / LIFETIME
	if t >= 1.0:
		queue_free()
		return
	_look.set_shader_parameter("radius", _reach * (1.0 - pow(1.0 - t, 2.0)))
	_look.set_shader_parameter("width", 10.0 + 14.0 * t)
	_look.set_shader_parameter("strength", _strength * (1.0 - t))
	queue_redraw()


func _draw() -> void:
	var extent := _reach + 30.0
	draw_rect(Rect2(-Vector2.ONE * extent, Vector2.ONE * extent * 2.0), Color.WHITE)
