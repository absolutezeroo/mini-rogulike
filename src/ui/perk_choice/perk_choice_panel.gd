class_name PerkChoicePanel
extends Control
## "Choose 1 of 3": shown on level up (perks) and after a boss (relics), in the game's skin
## (RpgDialog, cards on dark wood). Built in code. The game pauses while it is open.
## Tap a card, or use the arrows and confirm on a keyboard or gamepad.
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
## Under Reroll and Banish: what they do.
var _tools_note: Label

var _dialog: RpgDialog
var _title: Label
var _subtitle: Label
var _cards: HBoxContainer
var _tools: HBoxContainer
var _reroll: Button
var _banish: Button
var _card_box: StyleBoxTexture
var _card_hot: StyleBoxTexture


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()
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
		_skin_card(card)
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
	_tools_note.visible = _reroll.visible
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
	_subtitle.text = "Tap the perk to banish: it won't be offered again this run" if _banishing else _subtitle_text
	_subtitle.add_theme_color_override("font_color", BANISH_TINT if _banishing else UiSkin.TEXT)
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


# --- Building -----------------------------------------------------------------------

func _build() -> void:
	_dialog = RpgDialog.new("Level up!")
	add_child(_dialog)
	_title = _dialog.title_label
	_title.name = "Title"
	_subtitle = UiSkin.label("Choose an upgrade", 20, UiSkin.TEXT)
	_subtitle.name = "Subtitle"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog.body.add_child(_subtitle)
	_rule = UiParts.text("Every perk belongs to a family. Hold 3 different perks of one family to awaken its bonus.", 15, UiSkin.DIM, 900)
	_rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog.body.add_child(_rule)
	_cards = HBoxContainer.new()
	_cards.name = "Cards"
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 24)
	_dialog.body.add_child(_cards)
	_tools = HBoxContainer.new()
	_tools.name = "Tools"
	_tools.alignment = BoxContainer.ALIGNMENT_CENTER
	_tools.add_theme_constant_override("separation", 24)
	_dialog.body.add_child(_tools)
	_reroll = UiParts.button("Reroll (1)", Callable(), Vector2(220, 54), 18)
	_reroll.name = "RerollButton"
	_reroll.icon = load("res://assets/ui/icons/reroll.png")
	_tools.add_child(_reroll)
	_banish = UiParts.button("Banish (1)", Callable(), Vector2(220, 54), 18)
	_banish.name = "BanishButton"
	_banish.icon = load("res://assets/ui/icons/banish.png")
	_tools.add_child(_banish)
	_tools_note = UiParts.text("Reroll: 3 new perks to choose from.   Banish: removes a perk from this run's offers (tap Banish, then the card).", 15, UiSkin.DIM, 900)
	_tools_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog.body.add_child(_tools_note)
	for node: Node in [_title, _subtitle, _cards, _tools, _reroll, _banish]:
		node.owner = self
		node.unique_name_in_owner = true
	# The cards on dark wood; lighter under the finger.
	_card_box = UiSkin.inset()
	_card_hot = UiSkin.inset()
	_card_hot.modulate_color = Color(1.45, 1.3, 1.15)


func _skin_card(card: PerkCard) -> void:
	for state in ["normal", "disabled"]:
		card.add_theme_stylebox_override(state, _card_box)
	for state in ["hover", "pressed", "focus", "hover_pressed"]:
		card.add_theme_stylebox_override(state, _card_hot)
