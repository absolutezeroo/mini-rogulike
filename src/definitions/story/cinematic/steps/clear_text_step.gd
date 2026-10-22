class_name ClearTextStep
extends CinematicStep
## The name and the lines fade out of the bars (the bars stay).

@export var time: float = 0.3


func play(director: CinematicDirector) -> void:
	director.view.clear_text(time)
	await director.wait(time, always_run)
