class_name ImpactVfx
extends Node2D
## The flash of a hit, in the hitting element's language (docs/vfx.md): a 2-frame flash at
## full strength (no fade-in: a hit has no anticipation), then a few of the element's bits
## thrown away from the blow (ice chips falling, embers rising, sparks...) going down its ramp
## and dithering out. A plain blow (no element) throws short streaks along it instead. Bigger
## on critical hits. All on the art's grid.

const LIFETIME := 0.24
## The flash: two frames at 60 fps.
const FLASH_TIME := 0.034

var element: VfxElementDef
var _direction := Vector2.RIGHT
var _big := false
## Only the bits (a hit's sparks in what the target is made of, under the blow's own flash).
var _bits_only := false
var _age := 0.0
var _bits: Array[Dictionary] = []  # {from: Vector2, velocity: Vector2, size: int, life: float}
var _streaks: Array[Vector2] = []


## A hit at `at` along `direction` (from the attacker toward the target). `color` is used by
## blows without an element.
static func create(at: Vector2, direction: Vector2, color: Color, big: bool = false, of_element: VfxElementDef = null) -> ImpactVfx:
	var vfx := ImpactVfx.new()
	vfx.position = PixelDraw.snap(at)
	vfx.z_index = 6
	VfxLayer.apply(vfx, VfxLayer.Layer.AIR)
	vfx._direction = direction.normalized() if direction != Vector2.ZERO else Vector2.from_angle(randf() * TAU)
	vfx._big = big
	vfx.element = of_element
	vfx._spawn(color)
	vfx.material = FxLook.sprite(of_element != null and of_element.emissive)
	return vfx


## The bits a blow knocks out of what it hits (ImpactMaterialDef.sparks_element: blood drops,
## bone chips, slime, sparks off armor...), without a flash: the blow's own ImpactVfx has it.
static func sparks(at: Vector2, direction: Vector2, material: VfxElementDef, big: bool = false) -> ImpactVfx:
	var vfx := ImpactVfx.new()
	vfx.position = PixelDraw.snap(at)
	vfx.z_index = 6
	VfxLayer.apply(vfx, VfxLayer.Layer.AIR)
	vfx._direction = direction.normalized() if direction != Vector2.ZERO else Vector2.UP
	vfx._big = big
	vfx._bits_only = true
	vfx.element = material
	vfx._spawn(Color.WHITE)
	return vfx


func _spawn(color: Color) -> void:
	if element == null:
		# A plain blow: two or three streaks thrown along it, uneven.
		element = VfxElementDef.or_color(null, color)
		for i in 3 if _big else 2:
			_streaks.append(_direction.rotated(randf_range(-0.6, 0.6)) * randf_range(10.0, 16.0) * (1.4 if _big else 1.0))
		return
	var count := 6 if _big else 4
	for i in count:
		var angle := randf_range(-1.1, 1.1)
		var speed := randf_range(60.0, 130.0) * (1.3 if _big else 1.0)
		var velocity := _direction.rotated(angle) * speed
		match element.motion:
			VfxElementDef.Motion.RISE:
				velocity.y -= 40.0
			VfxElementDef.Motion.CONVERGE:
				velocity *= -0.5
		_bits.append({ from = Vector2.ZERO, velocity = velocity, size = 2 if i < 2 or _big else 1, life = LIFETIME * randf_range(0.7, 1.0) })


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	# The flash: the core color, full strength for two frames, then the ramp's next step.
	var flash := 3 if _big else 2
	if _bits_only:
		pass
	elif _age < FLASH_TIME:
		PixelDraw.disc(self, Vector2.ZERO, PixelDraw.PX * flash, element.core())
	elif t < 0.35:
		PixelDraw.ring(self, Vector2.ZERO, PixelDraw.PX * (flash + 1), element.shade(0.5), 1, 1.0 - t)
	for streak in _streaks:
		var length := 1.0 - t
		PixelDraw.line(self, streak * (0.3 + t), streak * (0.3 + t + length * 0.6), element.shade(t * 1.4), 1, 1.0 - t * t)
	for bit in _bits:
		var life: float = bit.life
		if _age >= life:
			continue
		var bt := _age / life
		var velocity: Vector2 = bit.velocity
		var at := velocity * _age
		match element.motion:
			VfxElementDef.Motion.FALL, VfxElementDef.Motion.SINK:
				at.y += 260.0 * _age * _age
			VfxElementDef.Motion.RISE:
				at.y -= 120.0 * _age * _age
		var size: int = bit.size if bt < 0.6 else 1
		var color := element.shade(0.15 + bt * 0.85)
		if PixelDraw.dither(PixelDraw.cell_of(at), 1.0 - maxf(bt - 0.7, 0.0) / 0.3):
			PixelDraw.bit(self, element.bit, at, size, color, velocity, element.core() if bt < 0.25 else Color.TRANSPARENT)
