class_name DifficultyPanel
extends Control
## "Choose a difficulty", shown when pressing Play. Locked difficulties show how to unlock them.
## Once Nightmare has been won, its ascension level (+1, +2...) is picked here too.

signal chosen(difficulty: DifficultyDef)

const SHOWN_TWISTS := 3
const CARD_SCENE: PackedScene = preload("res://src/ui/title/difficulty_card.tscn")

@onready var _cards: HBoxContainer = %DifficultyCards
@onready var _ascension_row: Control = %AscensionRow
@onready var _ascension_text: Label = %AscensionText

var _ascensions: Array[AscensionDef] = []


func _ready() -> void:
	hide()
	%BackButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		hide())
	%AscensionMinus.pressed.connect(func() -> void: _change_ascension(-1))
	%AscensionPlus.pressed.connect(func() -> void: _change_ascension(1))


func open(difficulties: Array[DifficultyDef], ascensions: Array[AscensionDef] = []) -> void:
	_ascensions = ascensions
	_refresh_ascension()
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	var focus: Control = null
	for def in difficulties:
		var card := CARD_SCENE.instantiate() as DifficultyCard
		_cards.add_child(card)
		card.show_difficulty(def, Profile.is_unlocked(def), def.id == Profile.difficulty)
		card.pressed.connect(func() -> void: choose(def))
		if def.id == Profile.difficulty and not card.disabled:
			focus = card
	show()
	if focus:
		focus.grab_focus()


func choose(def: DifficultyDef) -> void:
	if not Profile.is_unlocked(def):
		return
	Profile.select_difficulty(def)
	hide()
	chosen.emit(def)


func _change_ascension(step: int) -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	Profile.select_ascension(Profile.ascension + step)
	_refresh_ascension()


## Shown once Nightmare was won: the level, and every twist up to it.
func _refresh_ascension() -> void:
	var open_levels := mini(Profile.ascension_unlocked, _ascensions.size())
	_ascension_row.visible = open_levels > 0
	_ascension_text.visible = open_levels > 0
	if open_levels <= 0:
		return
	var level := mini(Profile.ascension, open_levels)
	(%AscensionLevel as Label).text = "+%d" % level
	(%AscensionMinus as Button).disabled = level <= 0
	(%AscensionPlus as Button).disabled = level >= open_levels
	# The last three twists (the list would not fit on a phone), the others summed up.
	var twists := PackedStringArray()
	if level > SHOWN_TWISTS:
		twists.append("...and the %d twists before." % (level - SHOWN_TWISTS))
	for i in range(maxi(level - SHOWN_TWISTS, 0), level):
		twists.append("+%d %s: %s" % [i + 1, _ascensions[i].title, _ascensions[i].description])
	_ascension_text.text = "\n".join(twists) if not twists.is_empty() else "Win Nightmare +%d to open the next level." % level
