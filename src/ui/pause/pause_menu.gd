class_name PauseMenu
extends Control
## Pause, in the game's skin (RpgDialog): resume, options, the bestiary (attacks and challenges
## of the monsters met), save and quit (Continue on the title screen), or give up the run; each
## button says what it does. Below, what gold and souls are for. The options and the bestiary
## open over it (instanced in the scene).

signal resume_requested
signal quit_requested
signal abandon_requested

const ABANDON_TEXT := "Give up the run"  # i18n
const CONFIRM_TEXT := "Really? Tap again"  # i18n
const CONFIRM_TEXT_BUTTONS := "Really? Press again"  # i18n
const ABANDON_NOTE := "Ends this run now. You keep the souls earned so far."  # i18n
const CONFIRM_NOTE := "Tap again to end the run. Anything else to cancel."  # i18n
const CONFIRM_NOTE_BUTTONS := "Press again to end the run. Anything else to cancel."  # i18n
const BUTTON_SIZE := Vector2(300, 58)
const NOTE_WIDTH := 380.0

## Set by the game (the bestiary needs it).
var content: ContentDB

var _dialog: RpgDialog
var _abandon_note: Label
var _named: Array[Node] = []

@onready var _options: OptionsPanel = %OptionsPanel
@onready var _codex: CodexPanel = %CodexPanel
var _confirm: Button


func _ready() -> void:
	hide()
	_build()
	_confirm = %AbandonButton


func open() -> void:
	_confirm.text = tr(ABANDON_TEXT)
	_abandon_note.text = tr(ABANDON_NOTE)
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


func _build() -> void:
	_dialog = RpgDialog.new(tr("Paused"), 0.0, 0.75)
	add_child(_dialog)
	move_child(_dialog, 0)  # under the options and the bestiary
	var resume := _row(tr("Resume"), "ResumeButton", tr("Back to the fight."), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		resume_requested.emit())
	resume.add_theme_font_size_override("font_size", Fonts.TITLE)
	PromptGlyph.badge(resume, &"pause")  # Escape or Start resumes too
	_row(tr("Options"), "OptionsButton", tr("Sound, music, button size, effects."), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		_options.open())
	_row(tr("Bestiary"), "BestiaryButton", tr("The monsters you have met: how they attack and how to beat them."), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		if content:
			_codex.open(content, CodexPanel.Tab.BESTIARY))
	_row(tr("Save and quit"), "QuitButton", tr("Your run is saved: pick Continue on the title screen."), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		quit_requested.emit())
	# Giving up takes two taps, so it never happens by accident.
	var give_up := _row(tr(ABANDON_TEXT), "AbandonButton", tr(ABANDON_NOTE), _on_abandon)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		give_up.add_theme_color_override(state, Color(0.55, 0.06, 0.06))
	_abandon_note = _dialog.body.get_child(_dialog.body.get_child_count() - 1).get_child(1) as Label

	# What the two currencies are for.
	var money: Dictionary = RpgWindow.section(tr("Gold and souls"))
	money.column.add_child(UiParts.text(tr("Gold: only for this run. Spend it at the merchant and the forge; it is lost when the run ends."), Fonts.BODY, UiSkin.TEXT, BUTTON_SIZE.x + NOTE_WIDTH))
	money.column.add_child(UiParts.text(tr("Souls: kept between runs. Spend them at the Shrine (title screen) on upgrades for every run."), Fonts.BODY, UiSkin.TEXT, BUTTON_SIZE.x + NOTE_WIDTH))
	_dialog.body.add_child(money.box)
	for node in _named:
		node.owner = self
		node.unique_name_in_owner = true


func _on_abandon() -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	if _confirm.text == tr(ABANDON_TEXT):
		_confirm.text = Prompts.pick(CONFIRM_TEXT, CONFIRM_TEXT_BUTTONS)
		_abandon_note.text = Prompts.pick(CONFIRM_NOTE, CONFIRM_NOTE_BUTTONS)
	else:
		abandon_requested.emit()


## A button and what it does, beside it.
func _row(text: String, node_name: String, note: String, action: Callable) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_dialog.body.add_child(row)
	var button := UiParts.button(text, action, BUTTON_SIZE, Fonts.BODY)
	button.name = node_name
	row.add_child(button)
	_named.append(button)
	var words := UiParts.text(note, Fonts.BODY, UiSkin.DIM, NOTE_WIDTH)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	return button
