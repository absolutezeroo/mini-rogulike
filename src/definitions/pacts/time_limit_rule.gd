class_name TimeLimitRule
extends PactRule
## Slay every foe of the room before the knell: a countdown from the moment the door seals.
## Deeper floors send more foes per wave (PactDef.foes_per_wave()), so the time grows too.

## Seconds on the first floor...
@export_range(5.0, 300.0, 1.0) var seconds := 30.0
## ...and this many more for every floor below the first.
@export_range(0.0, 10.0, 0.5) var seconds_per_depth := 2.0

var time_left := 0.0


## The whole countdown at `depth`, in seconds.
func limit(depth: int) -> float:
	return seconds + seconds_per_depth * (depth - 1)


func describe(player: Player) -> String:
	return tr("Slay every foe within %d seconds of the door sealing.") % roundi(limit(_depth_of(player)))


func status_text() -> String:
	if is_broken:
		return tr("The knell has tolled")
	return tr("%d s left") % ceili(time_left)


func _on_begin() -> void:
	time_left = limit(_depth_of(_player))


func tick(delta: float) -> void:
	if is_broken:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		_break()


static func _depth_of(player: Player) -> int:
	return player.world.depth if player and player.world else 1
