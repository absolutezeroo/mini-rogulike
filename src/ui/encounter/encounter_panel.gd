class_name EncounterPanel
extends Control
## The question an encounter asks: its text, one button per choice (with its price), and Leave.
## After a choice, what happened, then Continue. The game is paused while it is open.

signal closed

var _encounter: Encounter
var _player: Player

@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _text: Label = %Text
@onready var _choices: VBoxContainer = %Choices


func _ready() -> void:
	hide()


func open(encounter: Encounter, player: Player) -> void:
	_encounter = encounter
	_player = player
	_icon.texture = encounter.def.icon
	_icon.modulate = encounter.def.icon_tint
	_title.text = encounter.def.display_name
	_title.add_theme_color_override("font_color", encounter.def.color.lightened(0.2))
	_text.text = encounter.def.description
	_text.remove_theme_color_override("font_color")
	_clear()
	var depth := player.world.depth
	for i in encounter.def.choices.size():
		var choice := encounter.def.choices[i]
		var button := _button(choice.describe(player, depth), _choose.bind(i))
		button.disabled = not choice.can_afford(player, depth)
	_button(encounter.def.leave_label, close)
	show()


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	closed.emit()


func _choose(index: int) -> void:
	var outcome := _encounter.resolve(index, _player)
	if outcome == null:
		return
	Sfx.play_ui(Sfx.bank.perk_chosen)
	_text.text = outcome.text
	_text.add_theme_color_override("font_color", outcome.color)
	_clear()
	_button("Continue", close)


func _clear() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(420, 58)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	_choices.add_child(button)
	return button
