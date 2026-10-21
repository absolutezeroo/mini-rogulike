class_name BloodDrainVfx
extends Node2D
## Blood drawn out of a victim into whoever drinks it (a vampiric elite, the Leech Rune,
## Vampirism, Bloodlust): a few drops spurt out of the wound, hang a moment, then fly into the
## drinker and are gone. In the blood element's ramp and drops, on the art's grid, a pixel of
## trail each (docs/vfx.md). Cheap: a handful of drops, one node.

const LIFETIME := 0.9
## Seconds the drops are thrown out before they turn toward the drinker.
const SPURT_TIME := 0.18
const SPEED := 420.0

var _target: Node2D
var _drops: Array[Dictionary] = []  # {at, velocity, size, gone}
var _age := 0.0


## `count` drops out of `from` (a world position) flying into `target`.
static func create(from: Vector2, target: Node2D, count: int = 3) -> BloodDrainVfx:
	var vfx := BloodDrainVfx.new()
	vfx._target = target
	vfx.z_index = 6
	VfxLayer.apply(vfx, VfxLayer.Layer.AIR)  # drops in flight, over the bodies
	for i in count:
		var spread := Vector2.from_angle(-PI * 0.5 + randf_range(-1.1, 1.1))
		vfx._drops.append({ at = from + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 2.0)), velocity = spread * randf_range(60.0, 110.0), size = 2 if i == 0 else 1, gone = false, trail = from })
	return vfx


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME or not is_instance_valid(_target):
		queue_free()
		return
	var goal := _target.global_position + Vector2(0, -12)
	var alive := false
	for drop in _drops:
		if drop.gone:
			continue
		alive = true
		drop.trail = drop.at
		if _age < SPURT_TIME:
			drop.velocity += Vector2(0, 260.0) * delta  # thrown out, falling back
		else:
			var speed := SPEED * minf(1.0, (_age - SPURT_TIME) * 4.0 + 0.3)
			drop.velocity = drop.velocity.lerp((goal - drop.at).normalized() * speed, minf(1.0, 10.0 * delta))
		drop.at += drop.velocity * delta
		if _age > SPURT_TIME and drop.at.distance_to(goal) < 8.0:
			drop.gone = true
	if not alive:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var blood := VfxElementDef.named(&"blood")
	for drop in _drops:
		if drop.gone:
			continue
		var at: Vector2 = drop.at - global_position
		var trail: Vector2 = drop.trail - global_position
		PixelDraw.pixel(self, trail, blood.shade(0.66))
		PixelDraw.bit(self, VfxElementDef.Bit.DROP, at, drop.size, blood.color(), drop.velocity, blood.core() if _age < SPURT_TIME else Color.TRANSPARENT)
