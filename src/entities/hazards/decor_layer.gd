class_name DecorLayer
extends Node2D
## Little pieces of decor drawn at 2x (grass, flowers, logs, stones...): [texture, offset] each.
## Nothing to collide with. Plants (`sway`) move in a light breeze and bend away from whoever
## walks through them; everything else is drawn once.

const BEND := 0.55  ## how far a plant leans when someone walks through it (skew)
const REACH := Vector2(18.0, 12.0)  ## how close someone must be to bend it

var pieces: Array = []
## Plants: they sway, and bend when walked through (needs `world`).
var sway := false
var world: World

var _time := 0.0
var _lean := PackedFloat32Array()


func _ready() -> void:
	set_process(sway)


func _process(delta: float) -> void:
	_time += delta
	if _lean.size() != pieces.size():
		_lean.resize(pieces.size())
	var actors: Array[Actor] = world.get_actors() if world and is_instance_valid(world) else []
	for i in pieces.size():
		var foot := _foot(pieces[i])
		var push := 0.0
		for actor in actors:
			var offset := foot - actor.global_position
			if absf(offset.x) < REACH.x and absf(offset.y) < REACH.y:
				push += signf(offset.x) * (1.0 - absf(offset.x) / REACH.x) * BEND
		_lean[i] = lerpf(_lean[i], clampf(push, -BEND, BEND), minf(delta * 10.0, 1.0))
	queue_redraw()


func _draw() -> void:
	for i in pieces.size():
		var piece: Array = pieces[i]
		var texture: Texture2D = piece[0]
		var size := texture.get_size() * 2.0
		if not sway:
			draw_texture_rect(texture, Rect2(piece[1] - size * 0.5, size), false)
			continue
		# Leaning from the foot: a breeze (out of step from plant to plant) plus who walks by.
		var foot := _foot(piece)
		var breeze := sin(_time * 1.7 + foot.x * 0.05 + foot.y * 0.031) * 0.08
		var lean := breeze + (_lean[i] if i < _lean.size() else 0.0)
		draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE, -lean, foot))
		draw_texture_rect(texture, Rect2(Vector2(-size.x * 0.5, -size.y), size), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)


static func _foot(piece: Array) -> Vector2:
	var texture: Texture2D = piece[0]
	return piece[1] + Vector2(0, texture.get_height())  # the bottom of the piece (drawn at 2x)
