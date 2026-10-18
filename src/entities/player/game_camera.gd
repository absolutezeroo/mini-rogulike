class_name GameCamera
extends Camera2D
## Follows the player (as its child) and adds screen shake.

const MAX_OFFSET := 10.0
const DECAY := 2.5

var _trauma := 0.0


## amount: 0..1. Shakes add up but are capped.
func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount * Settings.screen_shake, 1.0)
	# Big shakes (hits taken, explosions, bosses) buzz the phone too.
	if amount >= 0.2:
		Settings.vibrate(amount)


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		return
	_trauma = maxf(_trauma - DECAY * delta, 0.0)
	var strength := _trauma * _trauma
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * MAX_OFFSET * strength
