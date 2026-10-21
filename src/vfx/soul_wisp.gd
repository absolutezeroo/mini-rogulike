class_name SoulWisp
extends Node2D
## A soul set free by a kill: it rises out of the body, then flies into the hero's lantern
## (Events.soul_gathered when it gets there). Drawn unshaded so it shows in the dark.

const RISE_TIME := 0.35
const SPEED := 520.0
const LIFETIME := 3.0
const TRAIL_LENGTH := 7

var _target: Node2D
var _velocity := Vector2.ZERO
var _age := 0.0
var _trail: Array[Vector2] = []


static func create(at: Vector2, target: Node2D) -> SoulWisp:
	var wisp := SoulWisp.new()
	wisp.position = at
	wisp._target = target
	wisp._velocity = Vector2(randf_range(-70.0, 70.0), randf_range(-150.0, -90.0))
	wisp.z_index = 5
	var glow := CanvasItemMaterial.new()
	glow.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	wisp.material = glow
	return wisp


func _process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(_target) or _age > LIFETIME:
		queue_free()
		return
	var goal := _target.global_position + Vector2(0, -18)
	if _age < RISE_TIME:
		_velocity = _velocity.move_toward(Vector2.ZERO, 260.0 * delta)
	else:
		var speed := SPEED * minf(1.0, 0.3 + (_age - RISE_TIME) * 2.5)
		_velocity = _velocity.lerp(global_position.direction_to(goal) * speed, minf(1.0, 8.0 * delta))
	_trail.append(global_position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.pop_front()
	global_position += _velocity * delta
	queue_redraw()
	if _age > RISE_TIME and global_position.distance_to(goal) < 14.0:
		Sfx.play_world(Sfx.bank.soul, global_position, -12.0)
		Events.soul_gathered.emit()
		queue_free()


## On the art's grid in the spirit element's ramp: a trail of pixels going down the ramp, a
## dithered glow that breathes by whole pixels, the body, a bright heart.
func _draw() -> void:
	var spirit := VfxElementDef.named(&"spirit")
	for i in _trail.size():
		var t := float(i + 1) / (_trail.size() + 1)
		var local := _trail[i] - global_position
		if PixelDraw.dither(PixelDraw.cell_of(local), t):
			PixelDraw.pixel(self, local, spirit.shade(1.0 - t * 0.6), 2 if t > 0.7 else 1)
	var beat := PixelDraw.PX if fmod(_age * 6.0, 1.0) < 0.5 else 0.0
	PixelDraw.disc(self, Vector2.ZERO, 8.0 + beat, spirit.shade(0.75), 0.35)
	PixelDraw.disc(self, Vector2.ZERO, 4.0, spirit.color())
	PixelDraw.pixel(self, Vector2(-2, -2), spirit.core(), 2)
