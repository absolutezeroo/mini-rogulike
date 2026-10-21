class_name BlastVfx
extends Node2D
## A burst of energy in an element's ramp (see blast.gdshader): explosions (a ball of fire for
## fire, a cloud of dust for earth...), magic shots bursting on a wall or a body when their
## element has no impact sheet of its own.

const SHADER := preload("res://assets/shaders/blast.gdshader")

var _radius := 40.0
var _life := 0.5
var _age := 0.0
var _look: ShaderMaterial


static func create(at: Vector2, radius: float, element: VfxElementDef) -> BlastVfx:
	var vfx := BlastVfx.new()
	vfx.position = PixelDraw.snap(at)
	vfx.z_index = 6
	VfxLayer.apply(vfx, VfxLayer.Layer.AIR)  # a burst: over the actors
	vfx._radius = radius
	vfx._life = clampf(0.3 + radius / 220.0, 0.3, 0.75)
	var look := ShaderMaterial.new()
	look.shader = SHADER
	look.set_shader_parameter("radius", radius)
	# Four bands from the ramp: its core, its next step, its body, its edge.
	var ramp := element.ramp
	var last := ramp.size() - 1
	look.set_shader_parameter("core", ramp[0])
	look.set_shader_parameter("light", ramp[mini(1, last)])
	look.set_shader_parameter("body", ramp[mini(3 if ramp.size() >= 5 else 2, last)])
	look.set_shader_parameter("rim", ramp[last])
	look.set_shader_parameter("residue", element.residue)
	look.set_shader_parameter("seed", randf() * 100.0)
	vfx._look = look
	vfx.material = look  # unshaded: the burst is its own light
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
