class_name PerkChoicePanel
extends Control
## "Choose 1 of 3": shown on level up (perks) and after a boss (relics).
## The game pauses while it is open. Tap a card, or use the arrows and confirm on a keyboard or gamepad.

signal chosen(perk: PerkDef)

const CARD_SCENE: PackedScene = preload("res://src/ui/perk_choice/perk_card.tscn")
## Cards ignore input for a moment, so a player mashing attack doesn't pick by accident.
const INPUT_DELAY := 0.45

var _perks: Array[PerkDef] = []
var _open_count := 0

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _cards: HBoxContainer = %Cards


func _ready() -> void:
	hide()


func open(title: String, subtitle: String, perks: Array[PerkDef], owned: PerkSet) -> void:
	_perks = perks
	_title.text = title
	_subtitle.text = subtitle
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for i in perks.size():
		var card := CARD_SCENE.instantiate() as PerkCard
		_cards.add_child(card)
		card.show_perk(perks[i], owned.stacks_of(perks[i]))
		card.disabled = true
		card.pressed.connect(choose.bind(i))
		card.modulate.a = 0.0
		var tween := card.create_tween()
		tween.tween_interval(0.08 * i)
		tween.tween_property(card, "modulate:a", 1.0, 0.2)
	show()
	Sfx.play_ui(Sfx.bank.ui_open)
	_open_count += 1
	var this_open := _open_count
	await get_tree().create_timer(INPUT_DELAY, true).timeout
	if not visible or this_open != _open_count:
		return  # already closed, or reopened with other cards
	for card: PerkCard in _cards.get_children():
		card.disabled = false
	if _cards.get_child_count() > 0:
		(_cards.get_child(0) as Control).grab_focus()


func get_offered() -> Array[PerkDef]:
	return _perks


func choose(index: int) -> void:
	if not visible or index < 0 or index >= _perks.size():
		return
	var perk := _perks[index]
	hide()
	Sfx.play_ui(Sfx.bank.perk_chosen)
	chosen.emit(perk)
