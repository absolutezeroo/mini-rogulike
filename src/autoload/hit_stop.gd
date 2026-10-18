extends Node
## Hit stop (autoload "HitStop"): freezes the game for a few frames on impacts,
## which makes hits feel much heavier. Calls overlap: the longest freeze wins.

const FROZEN_TIME_SCALE := 0.05

var enabled := true
var _remaining := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func freeze(duration: float) -> void:
	if not enabled or duration <= 0.0:
		return
	_remaining = maxf(_remaining, duration)
	Engine.time_scale = FROZEN_TIME_SCALE


func reset() -> void:
	_remaining = 0.0
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	# delta is scaled by the time scale: convert back to real time.
	_remaining -= delta / maxf(Engine.time_scale, 0.001)
	if _remaining <= 0.0:
		reset()
