extends Node
## Hit stop (autoload "HitStop"): freezes the game for a few frames on impacts,
## which makes hits feel much heavier. Calls overlap: the longest freeze wins.
## Also slow motion (`slow`): a strong kill slows the world for a moment. A freeze wins over it.

const FROZEN_TIME_SCALE := 0.05

var enabled := true
var _remaining := 0.0
var _slow_remaining := 0.0
var _slow_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func freeze(duration: float) -> void:
	if not enabled or duration <= 0.0:
		return
	_remaining = maxf(_remaining, duration)
	Engine.time_scale = FROZEN_TIME_SCALE


## The world runs at `time_scale` for `duration` real seconds.
func slow(duration: float, time_scale: float) -> void:
	if not enabled or duration <= 0.0:
		return
	_slow_remaining = maxf(_slow_remaining, duration)
	_slow_scale = minf(_slow_scale, time_scale) if _slow_remaining > 0.0 and _slow_scale < 1.0 else time_scale
	if _remaining <= 0.0:
		Engine.time_scale = _slow_scale


func reset() -> void:
	_remaining = 0.0
	_slow_remaining = 0.0
	_slow_scale = 1.0
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if _remaining <= 0.0 and _slow_remaining <= 0.0:
		return
	# delta is scaled by the time scale: convert back to real time.
	var real := delta / maxf(Engine.time_scale, 0.001)
	if _remaining > 0.0:
		_remaining -= real
		if _remaining > 0.0:
			return
		_remaining = 0.0
	else:
		_slow_remaining -= real
	if _slow_remaining > 0.0:
		Engine.time_scale = _slow_scale
	else:
		reset()
