class_name RigAnimations
extends RefCounted
## Which of a body's animations plays (ActorRig): sheets are drawn per direction, so a base name
## (`walk`) is played turned (`walk_left`) when the frames have it, else as it is; and how long
## one lasts. The turned names are made once (no name built every frame: docs/performance.md).

## Turned animation names (`walk` + `left` -> `walk_left`), by base then direction.
static var _directed: Dictionary[StringName, Dictionary] = {}


## `base` turned to `direction` if `frames` have it, else `base`, else &"" (none).
static func pick(frames: SpriteFrames, base: StringName, direction: StringName) -> StringName:
	if frames == null:
		return &""
	if not _directed.has(base):
		_directed[base] = {}
	var by_direction := _directed[base]
	var directed: StringName = by_direction.get(direction, &"")
	if directed == &"":
		directed = StringName(String(base) + "_" + String(direction))
		by_direction[direction] = directed
	if frames.has_animation(directed):
		return directed
	if frames.has_animation(base):
		return base
	return &""


## Seconds `animation` of `frames` lasts at its own speed.
static func length(frames: SpriteFrames, animation: StringName) -> float:
	var total := 0.0
	for i in frames.get_frame_count(animation):
		total += frames.get_frame_duration(animation, i)
	return total / maxf(frames.get_animation_speed(animation), 0.001)
