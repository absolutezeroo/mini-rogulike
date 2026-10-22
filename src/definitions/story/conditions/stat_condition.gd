class_name StatCondition
extends ProgressCondition
## A counter of the profile reached (Profile.stat_value): runs, victories, the deepest floor...
## "Act III reached" is the deepest floor at its first depth. The `text` says it in plain words
## for the codex, with %d for the number ("Reach floor %d", "Win a run").

## A Profile.stat_value key: "deepest" (deepest floor on any difficulty), "all_wins" (runs won on
## any difficulty), "runs", "bosses", "victories", "best_depth", "species", "secrets",
## "hidden_bosses", "fragments" (all found)...
@export var stat: String = "deepest"
@export var at_least: int = 1
## Plain words, %d = `at_least` (optional): "Reach floor %d".
@export var text: String = ""


func is_met(_subject: Resource = null) -> bool:
	return Profile.stat_value(stat) >= at_least


func describe(_subject: Resource = null) -> String:
	if text.is_empty():
		return ""
	return tr(text) % at_least if "%d" in text else tr(text)
