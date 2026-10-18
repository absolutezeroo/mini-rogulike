class_name GameOverPanel
extends Control
## Shown when the player dies.

signal restart_requested

@onready var _summary: Label = %Summary


func _ready() -> void:
	hide()
	%RestartButton.pressed.connect(func() -> void: restart_requested.emit())


func show_result(depth: int, level: int, kills: int) -> void:
	_summary.text = "Reached depth %d at level %d\n%d monsters slain" % [depth, level, kills]
	show()
