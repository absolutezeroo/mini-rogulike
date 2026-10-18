extends Node
## Global signal bus (autoload "Events").
## Gameplay code emits, UI listens: neither side needs a reference to the other.

signal message_logged(text: String, color: Color)
signal depth_changed(depth: int)
signal monster_killed(monster: Monster)


func log_message(text: String, color: Color = Color.WHITE) -> void:
	message_logged.emit(text, color)
