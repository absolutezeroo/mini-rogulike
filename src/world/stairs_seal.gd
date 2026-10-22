class_name StairsSeal
extends RefCounted
## The stairs of a normal floor stay sealed until the hero has slain enough of the floor's
## monsters (DungeonConfig.seal_share): no running past everything to the way down. Every kill
## on the floor counts, ambush waves and summons too. When only a few are left, the minimap
## shows where the remaining monsters are (`reveals_monsters`). Boss floors have no seal (the
## stairs only appear once the boss is dead).
## One seal lives as long as the World; `reset` starts it over on every floor.

## A kill counted (or the seal reset for a new floor).
signal changed
## Enough kills: the stairs open.
signal broken

## Kills the floor asks for (0: open from the start).
var needed := 0
var kills := 0
## The minimap shows the monsters left once this few kills are missing.
var reveal_left := 0


## A new floor holding `monsters`: it asks for `share` of them, `most` at most (0: no limit).
func reset(monsters: int, share: float, reveal: int, most: int = 0) -> void:
	needed = ceili(monsters * clampf(share, 0.0, 1.0))
	if most > 0:
		needed = mini(needed, most)
	kills = 0
	reveal_left = reveal
	changed.emit()


## No seal on this floor (boss floors).
func clear() -> void:
	reset(0, 0.0, 0)


func is_sealed() -> bool:
	return kills < needed


## Kills still owed.
func left() -> int:
	return maxi(needed - kills, 0)


func reveals_monsters() -> bool:
	return is_sealed() and left() <= reveal_left


## One more monster slain. True if that broke the seal.
func add_kill() -> bool:
	if not is_sealed():
		return false
	kills += 1
	changed.emit()
	if is_sealed():
		return false
	broken.emit()
	return true


## A floor picked up again from a save: the kills made on it before quitting count again (the
## counter used to start over at 0). Opens the seal if they were enough.
func restore(saved_kills: int) -> void:
	if needed <= 0 or saved_kills <= 0:
		return
	kills = mini(saved_kills, needed)
	changed.emit()
	if not is_sealed():
		broken.emit()


## Debug: open at once.
func break_now() -> void:
	if is_sealed():
		kills = needed
		changed.emit()
		broken.emit()
