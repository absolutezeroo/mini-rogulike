class_name CrackedWall
extends Prop
## The way into a secret room (SecretRoom): a crack in a wall, a prop standing in the rock.
## The tells, subtle but learnable: dark fissures on the stone, a few chips fallen at its foot, a
## faint draft of dust motes drifting out, a whisper when the hero is close (SecretRoom). Any hit
## of the hero (a blow, a shot, a skill) or a blast breaks it; monsters' blows don't (they would
## give the secret away). Its PropDef (DungeonConfig.cracked_wall): its hits, sound, debris color.

## Toward the room it is seen from (Vector2.DOWN: a crack on a cliff face). Set before it enters
## the tree.
var facing := Vector2.DOWN

## The fissures, in art pixels (2 screen pixels each): deterministic for its place.
var _pixels: Array[Vector2] = []
var _pebbles: Array[Vector3] = []
var _motes: CPUParticles2D

## One art pixel, in world pixels (the art is drawn at 2x).
const PIXEL := 2.0
## The particles' material: one art pixel per mote, on the grid (pixel_particles.gdshader).
const PIXEL_MOTES: Material = preload("res://src/vfx/particles/pixel_particles_motes.tres")


func _ready() -> void:
	super._ready()
	add_to_group("cracked_walls")
	# The whole wall cell, and a little in front of it: shots and blows coming from the room
	# hit the crack before the rock behind it.
	var foot := Vector2(def.footprint) * SIZE
	var shape := ($CollisionShape2D as CollisionShape2D).shape as RectangleShape2D
	shape.size = foot + facing.abs() * 8.0
	($CollisionShape2D as CollisionShape2D).position = facing * 4.0
	_build_cracks()
	_motes = _make_motes()
	add_child(_motes)


## Only the hero breaks it, or a blast from no one (a chest's trap...).
func take_hit(hit: HitInfo) -> void:
	if hit and is_instance_valid(hit.source) and not hit.source is Player:
		return
	super.take_hit(hit)


## Where it is seen from (the floor in front of it): the tutorial looks at it from there, the
## rock in between would hide it.
func sight_point() -> Vector2:
	return global_position + facing * (SIZE * 0.5 + 10.0)


## Jagged fissures from near the middle, walked pixel by pixel.
func _build_cracks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_position.round()))
	var half := Vector2(def.footprint) * SIZE * 0.5 - Vector2(3, 3)
	for branch in 3 + 2 * def.footprint.x * def.footprint.y:
		var point := Vector2(rng.randi_range(-3, 3), rng.randi_range(-4, 1)) * PIXEL
		var heading := Vector2.from_angle(rng.randf_range(0.0, TAU))
		for step in rng.randi_range(7, 12):
			_pixels.append(point.snapped(Vector2(PIXEL, PIXEL)))
			heading = heading.rotated(rng.randf_range(-0.8, 0.8))
			point += heading * PIXEL
			point = point.clamp(-half, half)
	var across := facing.orthogonal()
	for i in 3:
		var along := rng.randf_range(-0.4, 0.4) * SIZE * maxf(def.footprint.x, def.footprint.y)
		var at := across * along + facing * (SIZE * 0.5 + rng.randf_range(2.0, 7.0))
		_pebbles.append(Vector3(at.x, at.y, rng.randf_range(1.0, 2.0)))


## A slow draft out of the crack: a few pale motes drifting out into the room.
func _make_motes() -> CPUParticles2D:
	var motes := CPUParticles2D.new()
	motes.amount = 6
	motes.lifetime = 2.6
	motes.position = facing * SIZE * 0.3
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = (Vector2.ONE - facing.abs()) * SIZE * 0.35 * maxf(def.footprint.x, def.footprint.y) + Vector2(3, 3)
	motes.direction = facing
	motes.spread = 35.0
	motes.gravity = Vector2(0, 4)
	motes.initial_velocity_min = 4.0
	motes.initial_velocity_max = 12.0
	# One art pixel each, on the grid, fading by fewer of them (pixel_particles).
	motes.material = PIXEL_MOTES
	motes.scale_amount_min = 2.0
	motes.scale_amount_max = 2.0
	var fade := Gradient.new()
	fade.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.3, 0.7, 0.85])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.1)])
	motes.color_ramp = fade
	motes.color = Color(def.debris_color.lightened(0.45), 1.0)
	return motes


func _draw() -> void:
	if def == null:
		return
	var offset := Vector2(sin(_shake * 120.0) * 2.0, 0) if _shake > 0.0 else Vector2.ZERO
	var dark := Color(0.04, 0.03, 0.05, 0.9)
	var rim := Color(def.debris_color.lightened(0.5), 0.55)
	for pixel in _pixels:
		draw_rect(Rect2(pixel + offset + Vector2(PIXEL, PIXEL) * 0.5, Vector2(PIXEL, PIXEL)), rim)
	for pixel in _pixels:
		draw_rect(Rect2(pixel + offset - Vector2(PIXEL, PIXEL) * 0.5, Vector2(PIXEL, PIXEL)), dark)
	# A few chips fallen at its foot.
	for pebble in _pebbles:
		draw_rect(Rect2(Vector2(pebble.x, pebble.y).snapped(Vector2(PIXEL, PIXEL)), Vector2.ONE * PIXEL * roundf(pebble.z)), Color(def.debris_color.darkened(0.15), 0.95))
	# Each hit it took opens a darker split down its middle.
	var damage := 1.0 - float(_hits_left) / maxf(def.hits, 1.0)
	if damage > 0.0:
		var length := SIZE * 0.8 * damage
		var split := Rect2(Vector2(-PIXEL * 1.5, -length * 0.5), Vector2(PIXEL * 3.0, length)) if facing.y != 0.0 else Rect2(Vector2(-length * 0.5, -PIXEL * 1.5), Vector2(length, PIXEL * 3.0))
		draw_rect(Rect2(split.position + offset, split.size), dark)
