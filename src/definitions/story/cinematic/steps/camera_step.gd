class_name CameraStep
extends CinematicStep
## The camera eases to the subject (the warden) or back to the hero.

enum Target { SUBJECT, HERO }

@export var target: Target = Target.SUBJECT
@export var time: float = 0.8
## Where the subject sits on screen: this far above the middle (world pixels), so the text at
## the bottom never covers it.
@export var lift: float = 36.0


func play(director: CinematicDirector) -> void:
	var seconds := time * (0.4 if director.ended else 1.0)
	if target == Target.SUBJECT:
		if not director.has_subject():
			return
		director.move_camera(director.subject.global_position + Vector2(0, lift), seconds)
	else:
		director.camera_home(seconds)
	await director.wait(seconds, always_run)
