class_name PixelMotes
extends CPUParticles2D
## Ambient motes on the art's grid (ash falling under a blood moon...). A CPUParticles2D only by
## type: an ambience's particles slot holds one (Ambience follows the camera with it), and its
## own settings in the scene (amount, lifetime, emission rectangle, direction, spread, gravity,
## initial velocity) say how the motes move. But the engine's particles draw at any size, angle
## and sub-pixel place; these are simulated here and drawn as whole art pixels at grid places,
## in `element`'s ramp, fading in and out by dithering (docs/vfx.md). A flake tumbles by turning
## between a 2x1, a 1x1 and a 1x2 shape instead of rotating.

## Its colors (the ramp's darker steps: ambient stays muted).
@export var element: VfxElementDef
## Ramp positions (0 = core, 1 = edge) the motes take, one picked per mote.
@export var shades := PackedFloat32Array([0.66, 1.0, 1.0])
## Sideways sway, world units per second.
@export var sway: float = 8.0

var _motes: Array[Dictionary] = []  # {at, velocity, age, life, shade, seed}
## Where the motes are drawn: a child canvas (the particles node's own canvas item belongs to
## the engine's particle drawing).
var _canvas: Node2D


func _ready() -> void:
	emitting = false  # the engine draws nothing: the motes are drawn below
	_canvas = Node2D.new()
	_canvas.use_parent_material = true  # unshaded like the node: ash shows in the dark
	_canvas.draw.connect(_draw_motes)
	add_child(_canvas)


## The motes, already falling when the floor shows (once the ambience has put us on the view).
func _seed() -> void:
	var count := amount / 2 if Settings.fewer_effects else amount
	for i in count:
		var mote := _spawn()
		mote.age = randf() * mote.life  # already falling when the floor shows
		mote.at += mote.velocity * mote.age + gravity * mote.age * mote.age * 0.5
		_motes.append(mote)


func _spawn() -> Dictionary:
	var extents := emission_rect_extents
	var angle := direction.angle() + deg_to_rad(randf_range(-spread, spread))
	return {
		at = global_position + Vector2(randf_range(-extents.x, extents.x), randf_range(-extents.y, extents.y)),
		velocity = Vector2.from_angle(angle) * randf_range(initial_velocity_min, initial_velocity_max),
		age = 0.0,
		life = lifetime * randf_range(0.7, 1.0),
		shade = shades[randi() % maxi(shades.size(), 1)] if not shades.is_empty() else 1.0,
		seed = randf() * TAU,
	}


func _process(delta: float) -> void:
	if _motes.is_empty():
		_seed()
	var extents := emission_rect_extents
	for i in _motes.size():
		var mote: Dictionary = _motes[i]
		mote.age += delta
		mote.velocity += gravity * delta
		mote.at += (mote.velocity + Vector2(sin(mote.age * 1.3 + mote.seed) * sway, 0.0)) * delta
		# The view moved: what falls off one side comes back on the other.
		var offset: Vector2 = mote.at - global_position
		mote.at = global_position + Vector2(wrapf(offset.x, -extents.x, extents.x), wrapf(offset.y, -extents.y, extents.y))
		if mote.age >= mote.life:
			_motes[i] = _spawn()
	_canvas.queue_redraw()


func _draw_motes() -> void:
	if element == null:
		return
	for mote in _motes:
		var t: float = mote.age / mote.life
		# In over the first 15% of its life, out over the last 20%, by dithering.
		var fade := minf(t / 0.15, 1.0) * minf((1.0 - t) / 0.2, 1.0)
		var cell := PixelDraw.cell_of(mote.at)
		if not PixelDraw.dither(cell, fade):
			continue
		var color := element.shade(mote.shade)
		var at: Vector2 = PixelDraw.snap(mote.at) - global_position
		match int(mote.age * 4.0 + mote.seed) % 4:
			0:
				_canvas.draw_rect(Rect2(at, Vector2(PixelDraw.PX * 2.0, PixelDraw.PX)), color)
			2:
				_canvas.draw_rect(Rect2(at, Vector2(PixelDraw.PX, PixelDraw.PX * 2.0)), color)
			_:
				_canvas.draw_rect(Rect2(at, Vector2.ONE * PixelDraw.PX), color)
