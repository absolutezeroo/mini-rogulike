class_name AnimationStep
extends CinematicStep
## The subject plays one of its animations while the world stands still (a warden's "intro",
## waking up). Nothing happens if it has none.

@export var animation: StringName = &"intro"
## Waits at most this long for it.
@export var max_time: float = 1.6


func play(director: CinematicDirector) -> void:
	var length := director.play_subject_animation(animation)
	if length > 0.0:
		await director.wait(minf(length, max_time))
