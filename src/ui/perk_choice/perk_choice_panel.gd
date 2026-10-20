class_name PerkChoicePanel
extends Control
## "Choose 1 of 3": shown on level up (perks) and after a boss (relics).
## The game pauses while it is open. Tap a card, or use the arrows and confirm on a keyboard or gamepad.
## Under the cards: Reroll (three new cards) and Banish (tap Banish, then a card: that perk is
## gone for the run and another takes its place), while the run has charges left (RunState).
## The panel only asks (`reroll_requested`, `banish_requested`); the game decides and calls
## show_cards() with what replaces them.

signal chosen(perk: PerkDef)
signal reroll_requested
signal banish_requested(index: int)

const CARD_SCENE: PackedScene = preload("res://src/ui/perk_choice/perk_card.tscn")
## Cards ignore input for a moment, so a player mashing attack doesn't pick by accident.
const INPUT_DELAY := 0.45
const BANISH_TINT := Color(1.0, 0.55, 0.55)

var _perks: Array[PerkDef] = []
var _owned: PerkSet
var _open_count := 0
var _subtitle_text := ""
## Banish armed: the next tapped card is banished instead of taken.
var _banishing := false
var _rerolls := 0
var _banishes := 0
## Under the subtitle: what the families are, in one line (when a card has one).
var _rule: Label

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _cards: HBoxContainer = %Cards
@onready var _reroll: Button = %RerollButton
@onready var _banish: Button = %BanishButton


func _ready() -> void:
	hide()
	_rule = Label.new()
	_rule.text = "Every perk belongs to a family. Hold 3 different perks of one family to awaken its bonus."
	_rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rule.custom_minimum_size = Vector2(900, 0)
	_rule.add_theme_font_size_override("font_size", 15)
	_rule.add_theme_color_override("font_color", Color(1, 0.92, 0.8, 0.8))
	_rule.add_theme_color_override("font_outline_color", Color.BLACK)
	_rule.add_theme_constant_override("outline_size", 4)
	_subtitle.add_sibling(_rule)
	_reroll.pressed.connect(func() -> void:
		if _rerolls > 0 and visible:
			_set_banishing(false)
			reroll_requested.emit())
	_banish.pressed.connect(func() -> void: _set_banishing(not _banishing))


func open(title: String, subtitle: String, perks: Array[PerkDef], owned: PerkSet, rerolls: int = 0, banishes: int = 0) -> void:
	_title.text = title
	_subtitle_text = subtitle
	_owned = owned
	_banishing = false
	set_charges(rerolls, banishes)
	show_cards(perks, true)
	show()
	Sfx.play_ui(Sfx.bank.ui_open)
	_open_count += 1
	var this_open := _open_count
	await get_tree().create_timer(INPUT_DELAY, true).timeout
	if not visible or this_open != _open_count:
		return  # already closed, or reopened with other cards
	for card: PerkCard in _cards.get_children():
		card.disabled = false
	# Keyboard and gamepad only: on a touch screen it would look like a picked card.
	if _cards.get_child_count() > 0 and not DisplayServer.is_touchscreen_available():
		(_cards.get_child(0) as Control).grab_focus()


## Puts these cards on the table (a reroll, a banished card replaced...).
## `waiting`: they ignore taps for a moment (a fresh offer).
func show_cards(perks: Array[PerkDef], waiting: bool = false) -> void:
	_perks = perks
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for i in perks.size():
		var card := CARD_SCENE.instantiate() as PerkCard
		_cards.add_child(card)
		card.show_perk(perks[i], _owned)
		card.disabled = waiting
		card.pressed.connect(_on_card_pressed.bind(i))
		card.modulate.a = 0.0
		var tween := card.create_tween()
		tween.tween_interval(0.08 * i)
		tween.tween_property(card, "modulate:a", 1.0, 0.2)
	_rule.visible = perks.any(func(perk: PerkDef) -> bool: return not perk.synergies.is_empty())
	_set_banishing(false)


## Rerolls and banishes left (the buttons hide when the run has none at all).
func set_charges(rerolls: int, banishes: int) -> void:
	_rerolls = rerolls
	_banishes = banishes
	_reroll.text = "Reroll (%d)" % rerolls
	_reroll.disabled = rerolls <= 0
	_banish.disabled = banishes <= 0
	_reroll.visible = rerolls > 0 or banishes > 0
	_banish.visible = _reroll.visible
	_refresh_banish()


func get_offered() -> Array[PerkDef]:
	return _perks


func is_banishing() -> bool:
	return _banishing


func _set_banishing(on: bool) -> void:
	_banishing = on and _banishes > 0
	_refresh_banish()


func _refresh_banish() -> void:
	if _banish == null:
		return
	_banish.text = "Cancel" if _banishing else "Banish (%d)" % _banishes
	_subtitle.text = "Tap a perk to banish it for this run" if _banishing else _subtitle_text
	for card: PerkCard in _cards.get_children():
		card.self_modulate = BANISH_TINT if _banishing else Color.WHITE


func _on_card_pressed(index: int) -> void:
	if _banishing:
		_set_banishing(false)
		if index >= 0 and index < _perks.size():
			Sfx.play_ui(Sfx.bank.ui_close)
			banish_requested.emit(index)
		return
	choose(index)


func choose(index: int) -> void:
	if not visible or index < 0 or index >= _perks.size():
		return
	var perk := _perks[index]
	hide()
	Sfx.play_ui(Sfx.bank.perk_chosen)
	chosen.emit(perk)
