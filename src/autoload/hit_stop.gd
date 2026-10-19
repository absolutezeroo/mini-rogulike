extends Node
## Hit stop (autoload "HitStop"): freezes the game for a few frames on impacts,
## which makes hits feel much heavier. Calls overlap: the longest freeze wins.
## Also slow motion (`slow`): a strong kill slows the world for a moment. A freeze wins over it.
##
## Hits land during physics, after this frame's delta was already scaled by the time scale in
## effect when the frame began: real time is the delta divided by *that* scale (`real_delta`),
## never by the one just set.

const FROZEN_TIME_SCALE := 0.05

var enabled := true
var _remaining := 0.0
var _slow_remaining := 0.0
var _slow_scale := 1.0
## The time scale this frame's deltas were scaled with (set at the end of each frame).
var _applied_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100  # before everyone who asks for real_delta()


## Real seconds behind a `delta` of this frame (whatever the hit stop or slow motion).
func real_delta(delta: float) -> float:
	return delta / maxf(_applied_scale, 0.001)


func freeze(duration: float) -> void:
	if not enabled or duration <= 0.0:
		return
	_remaining = maxf(_remaining, duration)
	Engine.time_scale = FROZEN_TIME_SCALE


## The world runs at `time_scale` for `duration` real seconds.
func slow(duration: float, time_scale: float) -> void:
	if not enabled or duration <= 0.0:
		return
	_slow_scale = minf(_slow_scale, time_scale) if _slow_remaining > 0.0 else time_scale
	_slow_remaining = maxf(_slow_remaining, duration)
	if _remaining <= 0.0:
		Engine.time_scale = _slow_scale


func reset() -> void:
	_remaining = 0.0
	_slow_remaining = 0.0
	_slow_scale = 1.0
	Engine.time_scale = 1.0
	_applied_scale = 1.0


func _process(delta: float) -> void:
	var real := real_delta(delta)
	if _remaining > 0.0:
		_remaining -= real
		if _remaining <= 0.0:
			_remaining = 0.0
			Engine.time_scale = _slow_scale if _slow_remaining > 0.0 else 1.0
	elif _slow_remaining > 0.0:
		_slow_remaining -= real
		if _slow_remaining <= 0.0:
			_slow_remaining = 0.0
			_slow_scale = 1.0
			Engine.time_scale = 1.0
	_applied_scale = Engine.time_scale
