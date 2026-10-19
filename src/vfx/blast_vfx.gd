class_name BlastVfx
extends Node2D
## A ball of fire (see blast.gdshader): explosions, fireballs bursting on a wall or a body.

const SHADER := preload("res://assets/shaders/blast.gdshader")

var _radius := 40.0
var _life := 0.5
var _age := 0.0
var _look: ShaderMaterial


static func create(at: Vector2, radius: float, tint: Color = Color(1.0, 0.45, 0.15)) -> BlastVfx:
	var vfx := BlastVfx.new()
	vfx.position = at
	vfx.z_index = 6
	vfx._radius = radius
	vfx._life = clampf(0.3 + radius / 220.0, 0.3, 0.75)
	var look := ShaderMaterial.new()
	look.shader = SHADER
	look.set_shader_parameter("radius", radius)
	look.set_shader_parameter("tint", Color(tint, 1.0))
	look.set_shader_parameter("seed", randf() * 100.0)
	vfx._look = look
	vfx.material = look  # unshaded: the fire is its own light
	return vfx


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	_look.set_shader_parameter("progress", _age / _life)
	queue_redraw()


func _draw() -> void:
	var extent := _radius * 1.2
	draw_rect(Rect2(-Vector2.ONE * extent, Vector2.ONE * extent * 2.0), Color.WHITE)
