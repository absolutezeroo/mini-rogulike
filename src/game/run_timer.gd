class_name RunTimer
extends Node
## Counts the run's in-game time (RunState.time) for speedrunners, and shows it on the HUD.
## Real seconds (hit stops and slow motion don't slow it down), menus included (the bag, the shop,
## a perk choice: deciding is part of the run), but not the pause menu, a floor loading or its
## title cards: the Game says when it counts (`is_counting`).

## A frame never adds more than this (the app coming back from the background...).
const MAX_STEP := 0.25

var run: RunState
var hud: Hud
var is_counting := func() -> bool: return true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the bag and the shop pause the game, not the clock


func _process(delta: float) -> void:
	if run == null:
		return
	if is_counting.call():
		run.time += minf(HitStop.real_delta(delta), MAX_STEP)
	if hud:
		hud.show_run_time(run.run_time(), run.finish_time >= 0.0)
