class_name PactPanel
extends Control
## A pact door's offer (PactRoom), in the game's skin (RpgDialog). Built in code.
## Its name on the ribbon, the stele and its lore line; then three cards side by side, before
## anything is sworn: the rule in plain words (and that the door seals until every foe falls),
## what keeping it brings (in green) and what breaking it costs (in red, with the numbers for
## this hero). Swear opens the door (the fight starts once the hero walks in); Leave walks
## away (the door waits). The game is paused while it is open.

signal closed

const WIDTH := 980.0
const CARD_WIDTH := 290.0

var _pact: PactRoom
var _player: Player

var _dialog: RpgDialog
var _icon: TextureRect
var _lore: Label
var _rule: Label
var _seal_note: Label
var _elites: Label
var _reward: Label
var _cost: Label
var _swear: Button
## Built nodes reachable as %Name once the panel is built.
var _named := ExposedNodes.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()


func open(pact: PactRoom, player: Player) -> void:
	_pact = pact
	_player = player
	var def := pact.def
	_dialog.set_title(tr(def.display_name), def.color.lightened(0.3))
	_icon.texture = def.icon
	_icon.modulate = def.icon_tint
	_lore.text = tr(def.description)
	_rule.text = def.rule_text(player)
	if def.waves > 1:
		_seal_note.text = tr("The door seals behind you until every foe is slain: %d waves.") % def.waves
	else:
		_seal_note.text = tr("The door seals behind you until every foe is slain.")
	_elites.text = tr("Every foe is an elite.")
	_elites.visible = def.elite_share >= 1.0
	_reward.text = tr("A relic: choose 1 of %d strong perks, as after a boss.") % def.relic_choices
	var lost := def.max_hp_lost(player)
	_cost.text = tr("You lose %d max Health for the rest of the run (%d left), and the relic.") % [lost, maxi(1, player.get_max_hp() - lost)]
	show()


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	closed.emit()


## The hero swears: the door opens.
func swear() -> void:
	if _pact and is_instance_valid(_pact):
		_pact.accept()
		Sfx.play_ui(Sfx.bank.perk_chosen)
	hide()
	closed.emit()


# --- Building -----------------------------------------------------------------------

func _build() -> void:
	_dialog = RpgDialog.new("", WIDTH, 0.8)
	add_child(_dialog)
	_dialog.title_label.name = "Title"
	_named.add(_dialog.title_label)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	_dialog.body.add_child(top)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(72, 72)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.name = "Icon"
	_named.add(_icon)
	top.add_child(_icon)
	_lore = UiParts.text("", Fonts.BODY, UiSkin.TEXT, WIDTH - 160)
	_lore.name = "Lore"
	_lore.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_named.add(_lore)
	top.add_child(_lore)

	var cards := HBoxContainer.new()
	cards.name = "Cards"
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 14)
	_named.add(cards)
	_dialog.body.add_child(cards)
	var rule_card := _card(cards, tr("The rule"))
	_rule = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	_rule.name = "Rule"
	_named.add(_rule)
	rule_card.add_child(_rule)
	_elites = UiSkin.label("", Fonts.BODY, UiSkin.GOLD, true)
	_elites.name = "Elites"
	_named.add(_elites)
	rule_card.add_child(_elites)
	_seal_note = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	_seal_note.name = "SealNote"
	_named.add(_seal_note)
	rule_card.add_child(_seal_note)
	var kept_card := _card(cards, tr("Kept"))
	_reward = UiSkin.label("", Fonts.BODY, UiSkin.GOOD, true)
	_reward.name = "Reward"
	_named.add(_reward)
	kept_card.add_child(_reward)
	var broken_card := _card(cards, tr("Broken"))
	_cost = UiSkin.label("", Fonts.BODY, UiSkin.BAD, true)
	_cost.name = "Cost"
	_named.add(_cost)
	broken_card.add_child(_cost)
	broken_card.add_child(UiSkin.label(tr("The fight goes on: the door opens once the waves are slain."), Fonts.BODY, UiSkin.DIM, true))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	_dialog.body.add_child(buttons)
	_swear = UiParts.button(tr("Swear the pact"), swear, Vector2(320, 60), Fonts.BODY)
	_swear.name = "SwearButton"
	_named.add(_swear)
	buttons.add_child(_swear)
	var leave := UiParts.button(tr("Leave"), close, Vector2(200, 60), Fonts.BODY)
	PromptGlyph.badge(leave, &"ui_cancel", PromptGlyph.Place.INSIDE)  # Back leaves too
	leave.name = "LeaveButton"
	_named.add(leave)
	buttons.add_child(leave)
	var note := UiSkin.label(tr("Nothing happens. You can come back later."), Fonts.BODY, UiSkin.DIM)
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.add_child(note)
	_named.expose_to(self)


## A card of the offer: a dark inset with its gold heading; returns the column to fill.
func _card(row: HBoxContainer, heading: String) -> VBoxContainer:
	var card: Dictionary = RpgWindow.section(heading)
	var box := card.box as Control
	box.custom_minimum_size.x = CARD_WIDTH
	box.size_flags_vertical = Control.SIZE_FILL
	row.add_child(box)
	(card.title as Label).add_theme_font_size_override("font_size", Fonts.BODY)
	return card.column as VBoxContainer

