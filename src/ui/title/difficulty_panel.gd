class_name DifficultyPanel
extends Control
## "Choose a difficulty", shown when pressing Play. Locked difficulties show how to unlock them.

signal chosen(difficulty: DifficultyDef)

const CARD_SCENE: PackedScene = preload("res://src/ui/title/difficulty_card.tscn")

@onready var _cards: HBoxContainer = %DifficultyCards


func _ready() -> void:
	hide()
	%BackButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		hide())


func open(difficulties: Array[DifficultyDef]) -> void:
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
