class_name LetterboxStep
extends CinematicStep
## The black bars slide in (or out), the HUD out of the way: the world becomes a stage.

## True: in. False: out (and the text with them).
@export var show: bool = true
@export var time: float = 0.45


func play(director: CinematicDirector) -> void:
	var seconds := time * (0.5 if director.ended else 1.0)
	director.view.set_letterbox(show, seconds, director.def.letterbox_height)
	await director.wait(seconds, always_run)
