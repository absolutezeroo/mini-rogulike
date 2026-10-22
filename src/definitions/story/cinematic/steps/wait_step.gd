class_name WaitStep
extends CinematicStep
## A held breath: nothing moves for a moment.

@export var seconds: float = 0.4


func play(director: CinematicDirector) -> void:
	await director.wait(seconds)
