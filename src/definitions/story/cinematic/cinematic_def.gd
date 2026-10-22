class_name CinematicDef
extends Resource
## A short scene played over the frozen world (the game paused, the hero out of reach): a list
## of steps run in order by a CinematicDirector (letterbox, camera, an animation, a name, lines
## narrated...), and the tuning they share. The boss meetings use two (NarrativeDef); an NPC's
## scene or the final fight can be built from the same steps. In data/story/cinematics/.

@export var steps: Array[CinematicStep] = []

@export_group("Letterbox")
## Each black bar's height, as a share of the screen's (the bottom one grows to hold the text).
@export_range(0.0, 0.3, 0.01) var letterbox_height: float = 0.12

@export_group("Text")
## Letters a second as a line is written (0: the whole line fades in at once).
@export var chars_per_second: float = 55.0
## A line fades in over this long when it isn't typed.
@export var fade_time: float = 0.35
## Reading time once a line is written: this much, plus `hold_per_char` per letter.
@export var line_hold: float = 0.6
@export var hold_per_char: float = 0.035

@export_group("Skip")
## Taps in the first moments are ignored (a thumb lifted from the joystick).
@export var tap_grace: float = 0.35
## The first tap writes everything out at once; the next one ends the scene. False: any tap ends it.
@export var tap_completes_first: bool = true


## How long a written line is left to be read.
func read_time(text: String) -> float:
	return line_hold + hold_per_char * text.length()
