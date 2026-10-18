class_name GameOverPanel
extends Control
## End of a run: death, or victory over the last boss (then you may keep going: endless mode).

signal restart_requested
signal continue_requested
signal title_requested

const DEATH_COLOR := Color(1, 0.42, 0.42)
const VICTORY_COLOR := Color(1, 0.82, 0.4)

@onready var _title: Label = %Title
@onready var _summary: Label = %Summary
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	hide()
	%RestartButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		restart_requested.emit())
	%TitleButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		title_requested.emit())
	_continue_button.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		hide()
		continue_requested.emit())


func show_result(summary: String) -> void:
	_show("You died", DEATH_COLOR, summary, false)


func show_victory(summary: String) -> void:
	_show("Victory!", VICTORY_COLOR, summary, true)


func _show(title: String, color: Color, summary: String, can_continue: bool) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_summary.text = summary
	_continue_button.visible = can_continue
	%RestartButton.text = "New run" if can_continue else "Try again"
	show()
