class_name LightFlash
extends LightSource
## A burst of light that fades out step by step (explosions, big impacts).

const DURATION := 0.35

var _peak := 0
var _time := 0.0


func _init() -> void:
	moves = true
	relative = true


## `size`: how far it reaches, in pixels.
func setup(flash_color: Color, size: float) -> void:
	color = flash_color
	_peak = clampi(roundi(size / 40.0), 1, LightField.MAX_LEVEL)
	level = _peak


func _process(delta: float) -> void:
	_time += delta
	var left := 1.0 - _time / DURATION
	if left <= 0.0:
		queue_free()
		return
	level = ceili(_peak * left)
