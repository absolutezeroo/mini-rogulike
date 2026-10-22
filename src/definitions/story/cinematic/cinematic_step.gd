class_name CinematicStep
extends Resource
## One step of a CinematicDef: bars sliding in, the camera easing to someone, an animation, a
## name, lines narrated... Subclass it for a new kind (src/definitions/story/cinematic/steps/):
## override play(), which uses the director's stage (its camera, its subject, its view, the
## story it tells) and waits with `await director.wait(seconds)` so a tap can hurry or end it.

## Runs even once the player ended the scene (the camera coming back, the bars leaving), quickly.
@export var always_run: bool = false


## Plays the step; returns when it is done (or hurried, or the scene ended).
func play(_director: CinematicDirector) -> void:
	pass
