class_name ShockwaveVfx
extends Node2D
## A ripple running through the picture around a blast: a SHOCK stamp (DistortionStamp) the
## screen pass draws (screen.gdshader), pushing the picture outward by whole art pixels with a
## faint bright crest. It reads the screen through the one screen pass, never by itself.

const LIFETIME := 0.4
## The old ripple pushed by screen pixels; the screen pass pushes by art pixels (3 on screen).
const ART_PIXELS_PER_STRENGTH := 0.4

var _reach := 100.0
var _strength := 6.0
var _age := 0.0
var _stamp: DistortionStamp


static func create(at: Vector2, reach: float, strength: float = 6.0) -> ShockwaveVfx:
	var vfx := ShockwaveVfx.new()
	vfx.position = at
	vfx._reach = reach
	vfx._strength = strength
	vfx._stamp = DistortionStamp.attach(vfx, DistortionStamp.Kind.SHOCK, reach, strength * ART_PIXELS_PER_STRENGTH)
	return vfx


func _ready() -> void:
	_process(0.0)


func _process(delta: float) -> void:
	_age += delta
	var t := _age / LIFETIME
	if t >= 1.0:
		queue_free()
		return
	_stamp.ring = _reach * (1.0 - pow(1.0 - t, 2.0))
	_stamp.ring_width = 10.0 + 14.0 * t
	_stamp.strength = _strength * ART_PIXELS_PER_STRENGTH * (1.0 - t)
	_stamp.left = 1.0 - t
