class_name GameCamera
extends Camera2D
## Follows the player (as its child) and adds screen shake, and kicks: a short push along a
## direction that springs back (the weight of a blow, a shot's recoil), apart from the shake.
## Both scale with the Screen shake option.

const MAX_OFFSET := 10.0
const DECAY := 2.5
## Kicks add up to this many pixels, and come back this fast (per second, exponential).
const MAX_KICK := 10.0
const KICK_RETURN := 18.0

var _trauma := 0.0
var _kick := Vector2.ZERO


func _ready() -> void:
	# Anything can shake the screen without knowing about the hero (Events.screen_shake).
	Events.screen_shake.connect(shake)
	Events.camera_kick.connect(kick)


## Pushes the view `pixels` along `direction`; it springs back.
func kick(direction: Vector2, pixels: float) -> void:
	if direction == Vector2.ZERO:
		return
	_kick = (_kick + direction.normalized() * pixels * Settings.screen_shake).limit_length(MAX_KICK)


## Where the kick has the view right now (pixels).
func kick_offset() -> Vector2:
	return _kick


## amount: 0..1. Shakes add up but are capped.
func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount * Settings.screen_shake, 1.0)
	# Big shakes (hits taken, explosions, bosses) buzz the phone too.
	if amount >= 0.2:
		Settings.vibrate(amount)


func _process(delta: float) -> void:
	# Real time: a hit stop must not hold the view pushed.
	var real := HitStop.real_delta(delta)
	_kick = _kick * exp(-KICK_RETURN * real)
	if _kick.length() < 0.1:
		_kick = Vector2.ZERO
	if _trauma <= 0.0:
		offset = _kick.round()
		return
	_trauma = maxf(_trauma - DECAY * delta, 0.0)
	var strength := _trauma * _trauma
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * MAX_OFFSET * strength + _kick.round()
