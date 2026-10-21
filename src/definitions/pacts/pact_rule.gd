class_name PactRule
extends Resource
## The hard rule of a pact (PactDef), and how it is watched during the fight of its room.
## Each kind of rule is a subclass: it says the rule in plain words, listens to the hero while
## the fight lasts and calls _break() the moment the rule is broken. The pact room (PactRoom)
## watches a copy of the rule (duplicate()), so the data file never holds a fight's state.

## The rule was broken (once per fight).
signal broken

var is_broken := false
var _player: Player


## The rule in plain words, with its numbers ("Take no hit until the last foe falls.").
func describe(_player_now: Player) -> String:
	return ""


## Short words for the HUD while the fight lasts ("Untouched", "18 s left").
func status_text() -> String:
	return ""


## The fight begins: start listening to the hero.
func begin(player: Player) -> void:
	_player = player
	_on_begin()


## Every physics frame of the fight (timers).
func tick(_delta: float) -> void:
	pass


## The last foe fell (or the fight stopped): stop listening.
func finish() -> void:
	_on_finish()
	_player = null


func _on_begin() -> void:
	pass


func _on_finish() -> void:
	pass


func _break() -> void:
	if is_broken:
		return
	is_broken = true
	broken.emit()
