extends Node
## Global signal bus (autoload "Events").
## Gameplay code emits, UI listens: neither side needs a reference to the other.

signal message_logged(text: String, color: Color)
signal depth_changed(depth: int)
signal monster_killed(monster: Monster)
## The player entered a boss arena and the fight began.
signal boss_started(boss: Monster)
## The boss of the floor died: the arena opens and the stairs appear.
signal boss_defeated(boss: Monster)
## The hero walked into an ambush room: the exits closed, monsters are coming.
signal ambush_started(room: AmbushRoom)
## Every wave of the ambush is dead: the exits open.
signal ambush_cleared(room: AmbushRoom)


func log_message(text: String, color: Color = Color.WHITE) -> void:
	message_logged.emit(text, color)
