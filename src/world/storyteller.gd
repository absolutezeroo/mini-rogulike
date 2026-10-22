class_name Storyteller
extends Node
## What the World asks when the hero walks into a warden's arena, before it wakes (BossArena):
## to tell its story, or not. The Game's BossMeeting is one (a cinematic); a World without one
## starts the fight at once. Kept apart from the Game so the World never depends on it.


## The hero met `boss` in its arena (`risen`: a next form, just risen from the fallen one). May
## take a while (a cinematic, the game paused): the arena waits for it. Returns true if the boss
## already woke on screen (its intro animation played).
func meet(_boss: Monster, _risen := false) -> bool:
	return false
