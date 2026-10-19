class_name PauseMenu
extends Control
## Pause: resume, options, the bestiary (attacks and challenges of the monsters met), save and
## quit (Continue on the title screen), or give up the run.

signal resume_requested
signal quit_requested
signal abandon_requested

const ABANDON_TEXT := "Give up the run"
const CONFIRM_TEXT := "Really? Tap again"

## Set by the game (the bestiary needs it).
var content: ContentDB

@onready var _options: OptionsPanel = %OptionsPanel
@onready var _codex: CodexPanel = %CodexPanel
@onready var _confirm: Button = %AbandonButton


func _ready() -> void:
	hide()
	%ResumeButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		resume_requested.emit())
	%OptionsButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		_options.open())
	%BestiaryButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		if content:
			_codex.open(content, CodexPanel.Tab.BESTIARY))
	%QuitButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		quit_requested.emit())
	# Giving up takes two taps, so it never happens by accident.
	_confirm.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		if _confirm.text == ABANDON_TEXT:
			_confirm.text = CONFIRM_TEXT
		else:
			abandon_requested.emit())


func open() -> void:
	_confirm.text = ABANDON_TEXT
	_options.hide()
	_codex.hide()
	show()


## Back button / Escape: closes the options first, then the menu.
func back() -> void:
	if _options.visible:
		_options.close()
	elif _codex.visible:
		_codex.back()
	else:
		resume_requested.emit()
